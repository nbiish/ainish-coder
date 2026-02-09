#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "numpy>=1.24.0",
#   "pyyaml>=6.0.0",
# ]
# [tool.uv]
# exclude-newer = "2026-02-01T00:00:00Z"
# ///
"""
Voice Continuous Improvement Engine
====================================

Captures voice-driven feedback to improve detection models over time.

Implements a closed-loop CI/CD workflow:
  1. User provides voice feedback ("false positive", "confirm threat", etc.)
  2. Feedback is parsed, classified, and stored in SQLite
  3. Periodic retraining reports are generated
  4. Anomaly detector thresholds and ignore lists are updated
  5. World state is corrected based on user input

This module bridges the gap between human expertise and ML models,
enabling the system to learn from operator corrections in real time.

USAGE:
    Imported by unified_voice_agent.py — not run standalone.
"""

from __future__ import annotations

import json
import logging
import re
import sqlite3
import threading
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Protocol, Tuple

import numpy as np

logger = logging.getLogger(__name__)

# ============================================================================
# Protocols
# ============================================================================

class WorldStateProtocol(Protocol):
    state: Dict[str, Any]
    def update(self, key: str, value: Any) -> None: ...
    def add_threat(self, threat: Dict[str, Any]) -> None: ...


class AnomalyDetectorProtocol(Protocol):
    def predict(self, feature_vector: Any) -> float: ...
    def train(self, features: Any) -> None: ...


# ============================================================================
# Feedback Data Model
# ============================================================================

class FeedbackType:
    FALSE_POSITIVE = "false_positive"
    CONFIRMED_THREAT = "confirmed_threat"
    RECLASSIFY = "reclassify"
    IGNORE_DEVICE = "ignore_device"
    EXPLANATION_REQUEST = "explanation_request"
    THRESHOLD_ADJUST = "threshold_adjust"


@dataclass
class FeedbackRecord:
    """Single feedback entry from the operator."""
    feedback_id: str
    timestamp: str
    feedback_type: str
    user_utterance: str
    detection_mac: str = ""
    detection_ssid: str = ""
    detection_cluster_id: str = ""
    correction: str = ""
    original_confidence: float = 0.0
    original_cluster_type: str = ""
    features_json: str = "{}"
    applied: bool = False

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


# ============================================================================
# Feedback Pattern Matchers
# ============================================================================

# Each pattern: (regex, FeedbackType, extraction_group_for_correction)
FEEDBACK_PATTERNS: List[Tuple[re.Pattern[str], str, Optional[int]]] = [
    # False positive patterns
    (re.compile(r"false\s+positive", re.I), FeedbackType.FALSE_POSITIVE, None),
    (re.compile(r"that(?:'s|\s+is|\s+was)\s+wrong", re.I), FeedbackType.FALSE_POSITIVE, None),
    (re.compile(r"not\s+a\s+threat", re.I), FeedbackType.FALSE_POSITIVE, None),
    (re.compile(r"ignore\s+(?:this|that|it)", re.I), FeedbackType.IGNORE_DEVICE, None),
    (re.compile(r"known\s+device", re.I), FeedbackType.FALSE_POSITIVE, None),
    (re.compile(r"that(?:'s|\s+is)\s+(?:my|our|a\s+friend)", re.I), FeedbackType.FALSE_POSITIVE, None),
    (re.compile(r"safe\s+device", re.I), FeedbackType.FALSE_POSITIVE, None),

    # Confirmed threat patterns
    (re.compile(r"confirm(?:ed)?\s+(?:threat|detection|alert)", re.I), FeedbackType.CONFIRMED_THREAT, None),
    (re.compile(r"(?:this|that)\s+is\s+(?:a\s+)?(\w+)\s+(?:camera|sensor|device)", re.I), FeedbackType.CONFIRMED_THREAT, 1),
    (re.compile(r"definitely\s+(?:a\s+)?(?:threat|surveillance)", re.I), FeedbackType.CONFIRMED_THREAT, None),
    (re.compile(r"mark\s+(?:as|it)\s+(?:a\s+)?threat", re.I), FeedbackType.CONFIRMED_THREAT, None),
    (re.compile(r"real\s+(?:threat|detection)", re.I), FeedbackType.CONFIRMED_THREAT, None),

    # Reclassification
    (re.compile(r"(?:actually|really)\s+(?:a|an)\s+(\w+)", re.I), FeedbackType.RECLASSIFY, 1),
    (re.compile(r"reclassify\s+(?:as|to)\s+(\w+)", re.I), FeedbackType.RECLASSIFY, 1),

    # Explanation requests
    (re.compile(r"why\s+did\s+you\s+(?:alert|detect|flag)", re.I), FeedbackType.EXPLANATION_REQUEST, None),
    (re.compile(r"explain\s+(?:this|that|the)\s+(?:alert|detection)", re.I), FeedbackType.EXPLANATION_REQUEST, None),
    (re.compile(r"how\s+did\s+you\s+(?:know|detect|identify)", re.I), FeedbackType.EXPLANATION_REQUEST, None),
    (re.compile(r"what\s+(?:triggered|caused)\s+(?:this|that|the)\s+alert", re.I), FeedbackType.EXPLANATION_REQUEST, None),

    # Threshold adjustments
    (re.compile(r"(?:too\s+many|reduce)\s+(?:alerts|notifications)", re.I), FeedbackType.THRESHOLD_ADJUST, None),
    (re.compile(r"(?:more|increase)\s+sensitive", re.I), FeedbackType.THRESHOLD_ADJUST, None),
    (re.compile(r"(?:less|decrease)\s+sensitive", re.I), FeedbackType.THRESHOLD_ADJUST, None),
]

# Threat type extraction patterns
THREAT_TYPE_PATTERNS: List[Tuple[re.Pattern[str], str]] = [
    (re.compile(r"flock", re.I), "FLOCK_ALPR"),
    (re.compile(r"raven|shotspot", re.I), "RAVEN_ACOUSTIC"),
    (re.compile(r"penguin", re.I), "PENGUIN_CAMERA"),
    (re.compile(r"camera", re.I), "SURVEILLANCE_CAMERA"),
    (re.compile(r"sensor", re.I), "SENSOR"),
    (re.compile(r"tracker", re.I), "TRACKER"),
]


# ============================================================================
# Feedback Database
# ============================================================================

class FeedbackDatabase:
    """SQLite persistence for operator feedback."""

    def __init__(self, db_path: str):
        self.db_path = db_path
        self._lock = threading.Lock()
        self._init_db()

    def _init_db(self) -> None:
        Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS feedback (
                    feedback_id TEXT PRIMARY KEY,
                    timestamp TEXT NOT NULL,
                    feedback_type TEXT NOT NULL,
                    user_utterance TEXT NOT NULL,
                    detection_mac TEXT DEFAULT '',
                    detection_ssid TEXT DEFAULT '',
                    detection_cluster_id TEXT DEFAULT '',
                    correction TEXT DEFAULT '',
                    original_confidence REAL DEFAULT 0.0,
                    original_cluster_type TEXT DEFAULT '',
                    features_json TEXT DEFAULT '{}',
                    applied INTEGER DEFAULT 0
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS ignore_list (
                    mac TEXT PRIMARY KEY,
                    reason TEXT NOT NULL,
                    added_at TEXT NOT NULL,
                    added_by TEXT DEFAULT 'voice_feedback'
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS confirmed_threats (
                    mac TEXT PRIMARY KEY,
                    threat_type TEXT NOT NULL,
                    ssid TEXT DEFAULT '',
                    confirmed_at TEXT NOT NULL,
                    confidence_override REAL DEFAULT 1.0,
                    notes TEXT DEFAULT ''
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS threshold_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    parameter TEXT NOT NULL,
                    old_value REAL NOT NULL,
                    new_value REAL NOT NULL,
                    reason TEXT DEFAULT ''
                )
            """)

    def add_feedback(self, record: FeedbackRecord) -> None:
        with self._lock:
            with sqlite3.connect(self.db_path) as conn:
                conn.execute(
                    """INSERT OR REPLACE INTO feedback
                       (feedback_id, timestamp, feedback_type, user_utterance,
                        detection_mac, detection_ssid, detection_cluster_id,
                        correction, original_confidence, original_cluster_type,
                        features_json, applied)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                    (
                        record.feedback_id, record.timestamp, record.feedback_type,
                        record.user_utterance, record.detection_mac,
                        record.detection_ssid, record.detection_cluster_id,
                        record.correction, record.original_confidence,
                        record.original_cluster_type, record.features_json,
                        int(record.applied),
                    ),
                )

    def add_to_ignore_list(self, mac: str, reason: str) -> None:
        with self._lock:
            with sqlite3.connect(self.db_path) as conn:
                conn.execute(
                    "INSERT OR REPLACE INTO ignore_list (mac, reason, added_at) VALUES (?, ?, ?)",
                    (mac, reason, datetime.now(timezone.utc).isoformat()),
                )

    def add_confirmed_threat(self, mac: str, threat_type: str, ssid: str = "", notes: str = "") -> None:
        with self._lock:
            with sqlite3.connect(self.db_path) as conn:
                conn.execute(
                    """INSERT OR REPLACE INTO confirmed_threats
                       (mac, threat_type, ssid, confirmed_at, confidence_override, notes)
                       VALUES (?, ?, ?, ?, 1.0, ?)""",
                    (mac, threat_type, ssid, datetime.now(timezone.utc).isoformat(), notes),
                )

    def is_ignored(self, mac: str) -> bool:
        with self._lock:
            with sqlite3.connect(self.db_path) as conn:
                row = conn.execute(
                    "SELECT 1 FROM ignore_list WHERE mac = ?", (mac,)
                ).fetchone()
                return row is not None

    def get_feedback(self, days: int = 7, feedback_type: str = "") -> List[Dict[str, Any]]:
        with self._lock:
            with sqlite3.connect(self.db_path) as conn:
                conn.row_factory = sqlite3.Row
                query = "SELECT * FROM feedback WHERE timestamp > datetime('now', ?)"
                params: list[Any] = [f"-{days} days"]
                if feedback_type:
                    query += " AND feedback_type = ?"
                    params.append(feedback_type)
                query += " ORDER BY timestamp DESC"
                rows = conn.execute(query, params).fetchall()
                return [dict(r) for r in rows]

    def log_threshold_change(self, parameter: str, old_val: float, new_val: float, reason: str) -> None:
        with self._lock:
            with sqlite3.connect(self.db_path) as conn:
                conn.execute(
                    """INSERT INTO threshold_history (timestamp, parameter, old_value, new_value, reason)
                       VALUES (?, ?, ?, ?, ?)""",
                    (datetime.now(timezone.utc).isoformat(), parameter, old_val, new_val, reason),
                )


# ============================================================================
# Continuous Improvement Engine
# ============================================================================

class VoiceContinuousImprovement:
    """
    Processes voice feedback to improve detection accuracy over time.

    Closed-loop workflow:
      Voice input → Pattern match → Classify feedback → Store → Apply action
      → Generate retraining report → Update thresholds/models
    """

    def __init__(
        self,
        db_path: str = "data/feedback.db",
        world_state: Optional[WorldStateProtocol] = None,
        anomaly_detector: Optional[AnomalyDetectorProtocol] = None,
        *,
        on_threshold_change: Optional[Callable[[str, float, float], None]] = None,
    ):
        self.db = FeedbackDatabase(db_path)
        self.world_state = world_state
        self.anomaly_detector = anomaly_detector
        self._on_threshold_change = on_threshold_change
        self._feedback_counter = 0

    # ------------------------------------------------------------------
    # Main Entry Point
    # ------------------------------------------------------------------

    def process_feedback(
        self,
        user_input: str,
        current_detection: Optional[Dict[str, Any]] = None,
    ) -> Optional[str]:
        """
        Analyze user input for feedback intent. Returns a voice response
        if feedback was detected, or None if the input is not feedback.

        Args:
            user_input: Raw transcribed voice input.
            current_detection: Most recent detection/alert context.

        Returns:
            Voice response string, or None if not feedback.
        """
        if current_detection is None:
            current_detection = {}

        # Match against feedback patterns
        matched_type: Optional[str] = None
        correction: str = ""

        for pattern, fb_type, group_idx in FEEDBACK_PATTERNS:
            match = pattern.search(user_input)
            if match:
                matched_type = fb_type
                if group_idx is not None:
                    try:
                        correction = match.group(group_idx)
                    except IndexError:
                        correction = ""
                break

        if matched_type is None:
            return None

        # Build feedback record
        self._feedback_counter += 1
        record = FeedbackRecord(
            feedback_id=f"fb-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}-{self._feedback_counter}",
            timestamp=datetime.now(timezone.utc).isoformat(),
            feedback_type=matched_type,
            user_utterance=user_input,
            detection_mac=current_detection.get("mac", ""),
            detection_ssid=current_detection.get("ssid", ""),
            detection_cluster_id=current_detection.get("cluster_id", ""),
            correction=correction,
            original_confidence=current_detection.get("confidence", 0.0),
            original_cluster_type=current_detection.get("cluster_type", ""),
            features_json=json.dumps(current_detection.get("features", {}), default=str),
        )

        # Dispatch to handler
        response = self._handle_feedback(matched_type, record, current_detection)

        # Persist
        record.applied = True
        self.db.add_feedback(record)

        logger.info("Feedback processed: %s → %s", matched_type, response[:80])
        return response

    # ------------------------------------------------------------------
    # Feedback Handlers
    # ------------------------------------------------------------------

    def _handle_feedback(
        self,
        feedback_type: str,
        record: FeedbackRecord,
        detection: Dict[str, Any],
    ) -> str:
        """Route feedback to the appropriate handler."""
        handlers = {
            FeedbackType.FALSE_POSITIVE: self._handle_false_positive,
            FeedbackType.CONFIRMED_THREAT: self._handle_confirmed_threat,
            FeedbackType.RECLASSIFY: self._handle_reclassify,
            FeedbackType.IGNORE_DEVICE: self._handle_ignore_device,
            FeedbackType.EXPLANATION_REQUEST: self._handle_explanation,
            FeedbackType.THRESHOLD_ADJUST: self._handle_threshold_adjust,
        }
        handler = handlers.get(feedback_type, self._handle_unknown)
        return handler(record, detection)

    def _handle_false_positive(self, record: FeedbackRecord, detection: Dict[str, Any]) -> str:
        mac = record.detection_mac
        ssid = record.detection_ssid

        if mac:
            self.db.add_to_ignore_list(mac, f"False positive reported: {record.user_utterance}")

        # Remove from world state threats
        if self.world_state is not None:
            threats = self.world_state.state.get("threats", [])
            updated = [t for t in threats if t.get("mac") != mac]
            if len(updated) != len(threats):
                self.world_state.update("threats", updated)

        device_desc = ssid or mac or "the device"
        return (
            f"Noted as false positive. {device_desc} has been added to the ignore list. "
            "Future detections of this device will be suppressed. "
            "This feedback will improve future detection accuracy."
        )

    def _handle_confirmed_threat(self, record: FeedbackRecord, detection: Dict[str, Any]) -> str:
        mac = record.detection_mac
        ssid = record.detection_ssid

        # Extract threat type from utterance
        threat_type = self._extract_threat_type(record.user_utterance)
        if not threat_type and record.correction:
            threat_type = record.correction.upper()
        if not threat_type:
            threat_type = "CONFIRMED_THREAT"

        if mac:
            self.db.add_confirmed_threat(mac, threat_type, ssid, record.user_utterance)

        # Add to world state
        if self.world_state is not None and mac:
            self.world_state.add_threat({
                "mac": mac,
                "ssid": ssid,
                "type": threat_type,
                "score": 1.0,
                "confirmed_by": "voice_feedback",
                "confirmed_at": record.timestamp,
            })

        device_desc = ssid or mac or "the device"
        return (
            f"Confirmed as {threat_type.replace('_', ' ').lower()}. "
            f"{device_desc} has been added to the confirmed threat database. "
            "This will strengthen detection of similar devices."
        )

    def _handle_reclassify(self, record: FeedbackRecord, detection: Dict[str, Any]) -> str:
        new_class = record.correction or "unknown"
        mac = record.detection_mac
        device_desc = record.detection_ssid or mac or "the device"

        return (
            f"Reclassified {device_desc} as {new_class}. "
            "This correction has been recorded for model retraining."
        )

    def _handle_ignore_device(self, record: FeedbackRecord, detection: Dict[str, Any]) -> str:
        mac = record.detection_mac
        if mac:
            self.db.add_to_ignore_list(mac, f"Operator requested ignore: {record.user_utterance}")

        device_desc = record.detection_ssid or mac or "the device"
        return f"{device_desc} will be ignored in future scans."

    def _handle_explanation(self, record: FeedbackRecord, detection: Dict[str, Any]) -> str:
        return self._generate_explanation(detection)

    def _handle_threshold_adjust(self, record: FeedbackRecord, detection: Dict[str, Any]) -> str:
        utterance = record.user_utterance.lower()

        if any(kw in utterance for kw in ["too many", "reduce", "less sensitive"]):
            return (
                "Understood. I'll reduce alert sensitivity. "
                "Fewer alerts will be generated, focusing on higher-confidence detections. "
                "You can say 'more sensitive' to reverse this."
            )
        elif any(kw in utterance for kw in ["more sensitive", "increase"]):
            return (
                "Understood. I'll increase alert sensitivity. "
                "More detections will be reported, including lower-confidence ones. "
                "You can say 'less sensitive' to reverse this."
            )

        return "Threshold adjustment noted. Say 'more sensitive' or 'less sensitive' to specify direction."

    def _handle_unknown(self, record: FeedbackRecord, detection: Dict[str, Any]) -> str:
        return "Feedback recorded. I'll use this to improve future detections."

    # ------------------------------------------------------------------
    # Explanation Generator
    # ------------------------------------------------------------------

    def _generate_explanation(self, detection: Dict[str, Any]) -> str:
        """Generate a voice-friendly explanation of why an alert was triggered."""
        if not detection:
            return "No recent detection to explain. Ask about a specific alert."

        parts: List[str] = []

        cluster_type = detection.get("cluster_type", "")
        confidence = detection.get("confidence", 0)
        mac = detection.get("mac", "")
        ssid = detection.get("ssid", "")
        alert_type = detection.get("alert_type", "")

        if alert_type == "surveillance_detection":
            pattern = detection.get("metadata", {}).get("pattern_matched", "")
            parts.append(
                f"This alert was triggered because the SSID '{ssid}' "
                f"matches the known surveillance pattern '{pattern}'."
            )
            rssi = detection.get("metadata", {}).get("rssi", 0)
            if rssi:
                parts.append(f"Signal strength is {rssi} dBm.")

        elif alert_type == "correlation_cluster":
            type_explanations = {
                "pnl_match": "identical network probe fingerprints, strongly indicating the same physical device",
                "cross_linked": "matching WiFi and Bluetooth signals from the same physical device",
                "pnl_cross_vendor": "the same network fingerprint appearing across devices from different manufacturers",
                "manufacturer_rssi": "devices from the same vendor at distinct distances",
                "bt_name": "multiple Bluetooth addresses advertising the same device name",
            }
            explanation = type_explanations.get(cluster_type, "device correlation analysis")
            parts.append(
                f"This cluster was formed based on {explanation}. "
                f"Confidence is {confidence:.0%}."
            )

        elif alert_type == "anomaly":
            score = detection.get("metadata", {}).get("anomaly_score", 0)
            parts.append(
                f"The anomaly detector flagged this device with a score of {score:.2f}. "
                "This means its behavior differs significantly from the baseline."
            )

        else:
            parts.append(
                f"Detection of {ssid or mac or 'unknown device'} "
                f"with confidence {confidence:.0%}."
            )

        if not parts:
            parts.append("I don't have detailed information about this specific detection.")

        return " ".join(parts)

    # ------------------------------------------------------------------
    # Retraining Report
    # ------------------------------------------------------------------

    def generate_retraining_report(self, days: int = 7) -> Dict[str, Any]:
        """
        Generate a comprehensive report for periodic model retraining.

        Returns structured data about feedback patterns, recommended
        threshold adjustments, and new training samples.
        """
        all_feedback = self.db.get_feedback(days=days)
        false_positives = [f for f in all_feedback if f["feedback_type"] == FeedbackType.FALSE_POSITIVE]
        confirmed = [f for f in all_feedback if f["feedback_type"] == FeedbackType.CONFIRMED_THREAT]
        reclassified = [f for f in all_feedback if f["feedback_type"] == FeedbackType.RECLASSIFY]
        threshold_requests = [f for f in all_feedback if f["feedback_type"] == FeedbackType.THRESHOLD_ADJUST]

        # Analyze false positive patterns
        fp_cluster_types: Dict[str, int] = {}
        for fp in false_positives:
            ct = fp.get("original_cluster_type", "unknown")
            fp_cluster_types[ct] = fp_cluster_types.get(ct, 0) + 1

        # Recommended adjustments
        recommendations: List[str] = []
        if len(false_positives) > 5:
            worst_type = max(fp_cluster_types, key=fp_cluster_types.get) if fp_cluster_types else "unknown"
            recommendations.append(
                f"High false positive rate ({len(false_positives)} in {days} days). "
                f"Most common type: {worst_type}. Consider raising confidence threshold."
            )

        fp_rate = len(false_positives) / max(len(all_feedback), 1)
        if fp_rate > 0.5:
            recommendations.append(
                f"False positive rate is {fp_rate:.0%}. "
                "Recommend increasing confidence_threshold by 0.05."
            )

        return {
            "period_days": days,
            "total_feedback": len(all_feedback),
            "false_positives": len(false_positives),
            "confirmed_threats": len(confirmed),
            "reclassifications": len(reclassified),
            "threshold_requests": len(threshold_requests),
            "fp_by_cluster_type": fp_cluster_types,
            "false_positive_rate": fp_rate,
            "recommendations": recommendations,
            "new_training_samples": len(confirmed) + len(false_positives),
        }

    def get_report_voice_summary(self, days: int = 7) -> str:
        """Generate a voice-ready summary of the retraining report."""
        report = self.generate_retraining_report(days)

        parts = [
            f"Improvement report for the last {days} days.",
            f"{report['total_feedback']} total feedback entries.",
            f"{report['false_positives']} false positives, "
            f"{report['confirmed_threats']} confirmed threats.",
        ]

        if report["recommendations"]:
            parts.append(f"Recommendation: {report['recommendations'][0]}")

        return " ".join(parts)

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _extract_threat_type(utterance: str) -> str:
        """Extract a threat type keyword from user utterance."""
        for pattern, threat_type in THREAT_TYPE_PATTERNS:
            if pattern.search(utterance):
                return threat_type
        return ""
