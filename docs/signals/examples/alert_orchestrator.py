#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "requests>=2.28.0",
#   "pyyaml>=6.0.0",
# ]
# [tool.uv]
# exclude-newer = "2026-02-01T00:00:00Z"
# ///
"""
Alert Orchestrator — Proactive Detection Alert System
=====================================================

Translates correlation engine outputs and Kismet detections into
prioritized, deduplicated voice alerts with cooldown management.

Designed to run as a background thread inside the unified voice agent,
continuously monitoring for:
  - New high-confidence correlation clusters
  - Surveillance device SSIDs (FLOCK, RAVEN, PENGUIN)
  - ML anomaly score threshold breaches
  - Convergence state changes

USAGE:
    Imported by unified_voice_agent.py — not run standalone.
"""

from __future__ import annotations

import hashlib
import json
import logging
import threading
import time
from collections import deque
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from enum import IntEnum
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Protocol

import requests

logger = logging.getLogger(__name__)

# ============================================================================
# Alert Data Model
# ============================================================================

class AlertPriority(IntEnum):
    """Lower value = higher priority."""
    CRITICAL = 1
    HIGH = 2
    MEDIUM = 3
    LOW = 4
    INFO = 5


@dataclass
class Alert:
    """Immutable alert record."""
    alert_id: str
    alert_type: str
    priority: AlertPriority
    message: str
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    cluster_id: Optional[str] = None
    mac: Optional[str] = None
    ssid: Optional[str] = None
    confidence: float = 0.0
    metadata: Dict[str, Any] = field(default_factory=dict)
    acknowledged: bool = False

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["priority"] = int(self.priority)
        return d


# ============================================================================
# Protocols for dependency injection
# ============================================================================

class CorrelatorProtocol(Protocol):
    """Interface the orchestrator expects from a correlation engine."""
    clusters: Dict[str, Dict[str, Any]]

    def rssi_tolerance_info(self) -> Dict[str, Any]: ...


class KismetClientProtocol(Protocol):
    """Interface the orchestrator expects from a Kismet client."""

    def get_devices(self, phy: str = "wifi") -> List[Dict[str, Any]]: ...
    def get_alerts(self) -> List[Dict[str, Any]]: ...


class AnomalyDetectorProtocol(Protocol):
    """Interface the orchestrator expects from an anomaly detector."""

    def predict(self, feature_vector: Any) -> float: ...


class SpeechOutputProtocol(Protocol):
    """Interface the orchestrator expects for voice output."""

    def speak(self, text: str) -> None: ...


# ============================================================================
# Surveillance Pattern Database
# ============================================================================

SURVEILLANCE_PATTERNS: List[Dict[str, Any]] = [
    {"pattern": "FLOCK", "type": "ALPR Camera", "priority": AlertPriority.CRITICAL},
    {"pattern": "RAVEN", "type": "Acoustic Sensor", "priority": AlertPriority.CRITICAL},
    {"pattern": "PENGUIN", "type": "Surveillance Camera", "priority": AlertPriority.HIGH},
    {"pattern": "FS EXT", "type": "Flock Extender", "priority": AlertPriority.HIGH},
    {"pattern": "SHOTSPOT", "type": "Gunshot Sensor", "priority": AlertPriority.CRITICAL},
    {"pattern": "PIGVISION", "type": "Surveillance System", "priority": AlertPriority.HIGH},
]

CLUSTER_TYPE_PRIORITY: Dict[str, AlertPriority] = {
    "pnl_match": AlertPriority.HIGH,
    "cross_linked": AlertPriority.MEDIUM,
    "pnl_cross_vendor": AlertPriority.MEDIUM,
    "manufacturer_rssi": AlertPriority.LOW,
    "bt_name": AlertPriority.LOW,
    "manufacturer": AlertPriority.INFO,
    "pnl_overlap": AlertPriority.LOW,
    "bt_rssi": AlertPriority.INFO,
    "randomised": AlertPriority.INFO,
}


# ============================================================================
# Alert Orchestrator
# ============================================================================

class AlertOrchestrator:
    """
    Monitors correlation engine, Kismet, and anomaly detector for
    alert-worthy events and delivers them via voice with deduplication
    and cooldown management.
    """

    def __init__(
        self,
        voice: Optional[SpeechOutputProtocol] = None,
        correlator: Optional[CorrelatorProtocol] = None,
        kismet: Optional[KismetClientProtocol] = None,
        anomaly_detector: Optional[AnomalyDetectorProtocol] = None,
        *,
        cooldown_seconds: float = 30.0,
        poll_interval: float = 5.0,
        max_history: int = 500,
        confidence_threshold: float = 0.70,
        anomaly_threshold: float = 0.60,
        persistence_path: Optional[str] = None,
    ):
        self.voice = voice
        self.correlator = correlator
        self.kismet = kismet
        self.anomaly_detector = anomaly_detector

        self.cooldown_seconds = cooldown_seconds
        self.poll_interval = poll_interval
        self.confidence_threshold = confidence_threshold
        self.anomaly_threshold = anomaly_threshold

        # State
        self.alert_history: deque[Alert] = deque(maxlen=max_history)
        self._alerted_cluster_ids: set[str] = set()
        self._alerted_macs: set[str] = set()
        self._last_alert_time: float = 0.0
        self._last_convergence_pct: float = 0.0
        self._lock = threading.Lock()
        self._running = False
        self._thread: Optional[threading.Thread] = None

        # Persistence
        self._persistence_path = Path(persistence_path) if persistence_path else None

        # External listeners
        self._listeners: List[Callable[[Alert], None]] = []

        # Load persisted state
        self._load_state()

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    def start(self) -> None:
        """Start background monitoring thread."""
        if self._running:
            return
        self._running = True
        self._thread = threading.Thread(
            target=self._monitor_loop, daemon=True, name="alert-orchestrator"
        )
        self._thread.start()
        logger.info("AlertOrchestrator started (poll=%.1fs, cooldown=%.1fs)",
                     self.poll_interval, self.cooldown_seconds)

    def stop(self) -> None:
        """Stop background monitoring thread."""
        self._running = False
        if self._thread:
            self._thread.join(timeout=self.poll_interval + 2)
        self._save_state()
        logger.info("AlertOrchestrator stopped")

    def add_listener(self, callback: Callable[[Alert], None]) -> None:
        """Register an external alert listener (e.g., WebSocket emitter)."""
        self._listeners.append(callback)

    # ------------------------------------------------------------------
    # Core Monitor Loop
    # ------------------------------------------------------------------

    def _monitor_loop(self) -> None:
        """Background thread: poll sources and emit alerts."""
        while self._running:
            try:
                alerts: List[Alert] = []

                # 1. Correlation engine cluster changes
                if self.correlator is not None:
                    alerts.extend(self._check_correlation_clusters())
                    alerts.extend(self._check_convergence_state())

                # 2. Kismet surveillance SSID scan
                if self.kismet is not None:
                    alerts.extend(self._check_surveillance_detections())
                    alerts.extend(self._check_kismet_alerts())

                # Sort by priority (lower = more urgent)
                alerts.sort(key=lambda a: a.priority)

                for alert in alerts:
                    self._emit(alert)

            except Exception:
                logger.exception("AlertOrchestrator monitor error")

            time.sleep(self.poll_interval)

    # ------------------------------------------------------------------
    # Detection: Correlation Clusters
    # ------------------------------------------------------------------

    def _check_correlation_clusters(self) -> List[Alert]:
        """Detect new high-confidence clusters from the correlation engine."""
        if self.correlator is None:
            return []

        new_alerts: List[Alert] = []
        clusters = getattr(self.correlator, "clusters", {})

        for cid, cluster in clusters.items():
            if cid in self._alerted_cluster_ids:
                continue

            confidence = cluster.get("confidence", 0.0)
            if confidence < self.confidence_threshold:
                continue

            cluster_type = cluster.get("cluster_type", "unknown")
            priority = CLUSTER_TYPE_PRIORITY.get(cluster_type, AlertPriority.INFO)

            # Only alert on meaningful cluster types
            if priority > AlertPriority.LOW:
                continue

            member_count = cluster.get("member_count", 0)
            label = cluster.get("label", cid)
            ssids = cluster.get("ssids", [])

            message = self._format_cluster_message(
                label, cluster_type, confidence, member_count, ssids
            )

            alert = Alert(
                alert_id=self._make_id("cluster", cid),
                alert_type="correlation_cluster",
                priority=priority,
                message=message,
                cluster_id=cid,
                confidence=confidence,
                metadata={
                    "cluster_type": cluster_type,
                    "member_count": member_count,
                    "ssids": ssids[:5],
                },
            )
            new_alerts.append(alert)
            self._alerted_cluster_ids.add(cid)

        return new_alerts

    def _format_cluster_message(
        self,
        label: str,
        cluster_type: str,
        confidence: float,
        member_count: int,
        ssids: List[str],
    ) -> str:
        """Build a concise, voice-friendly cluster alert message."""
        type_desc = {
            "pnl_match": "fingerprint-matched device group",
            "cross_linked": "cross-protocol linked device",
            "pnl_cross_vendor": "multi-vendor device cluster",
            "manufacturer_rssi": "vendor-grouped device",
            "bt_name": "named Bluetooth device group",
            "pnl_overlap": "partial fingerprint match",
        }.get(cluster_type, "device cluster")

        parts = [
            f"New {type_desc} identified: {label}.",
            f"Confidence {confidence:.0%} with {member_count} members.",
        ]
        if ssids:
            parts.append(f"Networks: {', '.join(ssids[:3])}.")
        return " ".join(parts)

    # ------------------------------------------------------------------
    # Detection: Convergence State
    # ------------------------------------------------------------------

    def _check_convergence_state(self) -> List[Alert]:
        """Alert on convergence milestones (50%, 90%, 100%)."""
        if self.correlator is None:
            return []

        try:
            info = self.correlator.rssi_tolerance_info()
        except Exception:
            return []

        pct = info.get("convergence_pct", 0.0)
        alerts: List[Alert] = []

        milestones = [50.0, 90.0, 100.0]
        for milestone in milestones:
            if self._last_convergence_pct < milestone <= pct:
                converged = info.get("converged", False)
                gap = info.get("rssi_gap_dbm", 0.0)

                if converged:
                    msg = (
                        f"Correlation engine fully converged at step {info.get('step', 0)}. "
                        f"WiFi tolerance is {gap:.1f} dBm. Clusters are now at maximum precision."
                    )
                else:
                    msg = (
                        f"Correlation engine reached {pct:.0f}% convergence. "
                        f"Current WiFi tolerance: {gap:.1f} dBm."
                    )

                alerts.append(Alert(
                    alert_id=self._make_id("convergence", str(milestone)),
                    alert_type="convergence_milestone",
                    priority=AlertPriority.INFO,
                    message=msg,
                    metadata=info,
                ))

        self._last_convergence_pct = pct
        return alerts

    # ------------------------------------------------------------------
    # Detection: Surveillance SSIDs
    # ------------------------------------------------------------------

    def _check_surveillance_detections(self) -> List[Alert]:
        """Scan Kismet devices for known surveillance SSID patterns."""
        if self.kismet is None:
            return []

        alerts: List[Alert] = []
        try:
            devices = self.kismet.get_devices("wifi")
        except Exception:
            return []

        for dev in devices:
            mac = dev.get("kismet.device.base.macaddr", dev.get("mac", ""))
            ssid = dev.get("kismet.device.base.name", dev.get("ssid", ""))
            rssi = dev.get("kismet.device.base.signal", {})
            if isinstance(rssi, dict):
                rssi = rssi.get("kismet.common.signal.last_signal", 0)

            if mac in self._alerted_macs:
                continue

            for pattern_entry in SURVEILLANCE_PATTERNS:
                if pattern_entry["pattern"].upper() in ssid.upper():
                    msg = (
                        f"Surveillance device detected: {pattern_entry['type']}. "
                        f"SSID {ssid}, signal {rssi} dBm."
                    )
                    alerts.append(Alert(
                        alert_id=self._make_id("surveillance", mac),
                        alert_type="surveillance_detection",
                        priority=pattern_entry["priority"],
                        message=msg,
                        mac=mac,
                        ssid=ssid,
                        metadata={
                            "device_type": pattern_entry["type"],
                            "rssi": rssi,
                            "pattern_matched": pattern_entry["pattern"],
                        },
                    ))
                    self._alerted_macs.add(mac)
                    break

        return alerts

    # ------------------------------------------------------------------
    # Detection: Kismet Alerts
    # ------------------------------------------------------------------

    def _check_kismet_alerts(self) -> List[Alert]:
        """Forward Kismet IDS alerts as voice notifications."""
        if self.kismet is None:
            return []

        alerts: List[Alert] = []
        try:
            kismet_alerts = self.kismet.get_alerts()
        except Exception:
            return []

        for ka in kismet_alerts[:5]:
            alert_type = ka.get("type", ka.get("kismet.alert.header", "Unknown"))
            alert_id = self._make_id("kismet_alert", str(ka.get("id", alert_type)))

            if any(a.alert_id == alert_id for a in self.alert_history):
                continue

            msg = f"Kismet alert: {alert_type}."
            text = ka.get("text", ka.get("kismet.alert.text", ""))
            if text:
                msg += f" {text[:80]}"

            alerts.append(Alert(
                alert_id=alert_id,
                alert_type="kismet_ids",
                priority=AlertPriority.MEDIUM,
                message=msg,
                metadata={"kismet_alert_type": alert_type},
            ))

        return alerts

    # ------------------------------------------------------------------
    # Emission & Cooldown
    # ------------------------------------------------------------------

    def _emit(self, alert: Alert) -> None:
        """Emit an alert via voice and listeners, respecting cooldown."""
        with self._lock:
            # Dedup check
            if any(a.alert_id == alert.alert_id for a in self.alert_history):
                return

            # Cooldown: only voice-deliver if enough time has passed
            now = time.time()
            voice_ok = (now - self._last_alert_time) >= self.cooldown_seconds

            self.alert_history.append(alert)

            # Voice delivery
            if voice_ok and self.voice is not None:
                prefix = {
                    AlertPriority.CRITICAL: "Critical alert. ",
                    AlertPriority.HIGH: "Alert. ",
                    AlertPriority.MEDIUM: "Notice. ",
                    AlertPriority.LOW: "",
                    AlertPriority.INFO: "",
                }.get(alert.priority, "")

                try:
                    self.voice.speak(prefix + alert.message)
                    self._last_alert_time = now
                except Exception:
                    logger.exception("Voice delivery failed for alert %s", alert.alert_id)

            # External listeners
            for listener in self._listeners:
                try:
                    listener(alert)
                except Exception:
                    logger.exception("Alert listener error")

            logger.info("Alert emitted: [%s] %s", alert.priority.name, alert.message)

    # ------------------------------------------------------------------
    # Query Interface
    # ------------------------------------------------------------------

    def get_recent_alerts(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Return recent alerts as dicts for LLM context injection."""
        with self._lock:
            recent = list(self.alert_history)[-limit:]
        return [a.to_dict() for a in reversed(recent)]

    def get_alert_summary(self) -> str:
        """Build a voice-ready summary of recent alert activity."""
        with self._lock:
            total = len(self.alert_history)
            if total == 0:
                return "No alerts recorded."

            by_type: Dict[str, int] = {}
            for a in self.alert_history:
                by_type[a.alert_type] = by_type.get(a.alert_type, 0) + 1

        parts = [f"{total} total alerts."]
        for atype, count in sorted(by_type.items(), key=lambda x: -x[1]):
            label = atype.replace("_", " ").title()
            parts.append(f"{count} {label}.")
        return " ".join(parts)

    def acknowledge(self, alert_id: str) -> bool:
        """Mark an alert as acknowledged."""
        with self._lock:
            for a in self.alert_history:
                if a.alert_id == alert_id:
                    a.acknowledged = True
                    return True
        return False

    def reset_for_mac(self, mac: str) -> None:
        """Allow re-alerting on a previously seen MAC."""
        self._alerted_macs.discard(mac)

    def reset_for_cluster(self, cluster_id: str) -> None:
        """Allow re-alerting on a previously seen cluster."""
        self._alerted_cluster_ids.discard(cluster_id)

    # ------------------------------------------------------------------
    # Persistence
    # ------------------------------------------------------------------

    def _save_state(self) -> None:
        """Persist alert state to disk."""
        if self._persistence_path is None:
            return
        try:
            state = {
                "alerted_cluster_ids": list(self._alerted_cluster_ids),
                "alerted_macs": list(self._alerted_macs),
                "last_convergence_pct": self._last_convergence_pct,
                "alert_history": [a.to_dict() for a in self.alert_history],
            }
            tmp = self._persistence_path.with_suffix(".tmp")
            tmp.parent.mkdir(parents=True, exist_ok=True)
            tmp.write_text(json.dumps(state, indent=2, default=str))
            tmp.rename(self._persistence_path)
        except Exception:
            logger.exception("Failed to save alert state")

    def _load_state(self) -> None:
        """Restore alert state from disk."""
        if self._persistence_path is None or not self._persistence_path.exists():
            return
        try:
            data = json.loads(self._persistence_path.read_text())
            self._alerted_cluster_ids = set(data.get("alerted_cluster_ids", []))
            self._alerted_macs = set(data.get("alerted_macs", []))
            self._last_convergence_pct = data.get("last_convergence_pct", 0.0)
            logger.info(
                "Restored alert state: %d clusters, %d MACs tracked",
                len(self._alerted_cluster_ids),
                len(self._alerted_macs),
            )
        except Exception:
            logger.exception("Failed to load alert state")

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _make_id(prefix: str, key: str) -> str:
        """Deterministic alert ID for deduplication."""
        digest = hashlib.sha256(f"{prefix}:{key}".encode()).hexdigest()[:12]
        return f"{prefix}-{digest}"
