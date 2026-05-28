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
Voice Insight Engine
====================

Generates proactive, voice-ready insights from correlation data,
anomaly detection results, and historical patterns.

Insight categories:
  - Device Ecosystem: cluster composition, vendor diversity, cross-linking
  - Security Posture: MAC randomization effectiveness, PNL trackability
  - Behavioral Patterns: stationary vs. mobile, dwell time, signal stability
  - Temporal Trends: new devices, departures, recurring visitors
  - Threat Assessment: surveillance density, anomaly trends

Each insight is a concise, spoken-language sentence suitable for TTS.

USAGE:
    Imported by unified_voice_agent.py — not run standalone.
"""

from __future__ import annotations

import logging
import math
from collections import Counter
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Protocol

logger = logging.getLogger(__name__)

# ============================================================================
# Protocols
# ============================================================================

class CorrelatorProtocol(Protocol):
    clusters: Dict[str, Dict[str, Any]]
    def rssi_tolerance_info(self) -> Dict[str, Any]: ...


class WorldStateProtocol(Protocol):
    state: Dict[str, Any]


class FeedbackDBProtocol(Protocol):
    def get_feedback(self, days: int = 7, feedback_type: str = "") -> List[Dict[str, Any]]: ...


# ============================================================================
# Insight Data Model
# ============================================================================

class InsightCategory:
    ECOSYSTEM = "ecosystem"
    SECURITY = "security"
    BEHAVIORAL = "behavioral"
    TEMPORAL = "temporal"
    THREAT = "threat"


class Insight:
    """Single insight with category, priority, and voice text."""

    __slots__ = ("category", "priority", "text", "detail")

    def __init__(self, category: str, priority: int, text: str, detail: str = ""):
        self.category = category
        self.priority = priority  # 1 = most important
        self.text = text
        self.detail = detail

    def __repr__(self) -> str:
        return f"Insight({self.category}, P{self.priority}, {self.text[:50]}...)"


# ============================================================================
# Voice Insight Engine
# ============================================================================

class VoiceInsightEngine:
    """
    Analyzes correlation engine state and generates voice-ready insights.

    Call get_insights() for a prioritized list, or get_insights_for_topic()
    for topic-filtered results.
    """

    def __init__(
        self,
        correlator: Optional[CorrelatorProtocol] = None,
        world_state: Optional[WorldStateProtocol] = None,
        feedback_db: Optional[FeedbackDBProtocol] = None,
    ):
        self.correlator = correlator
        self.world_state = world_state
        self.feedback_db = feedback_db

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def get_insights(self, max_count: int = 5) -> List[Insight]:
        """
        Generate all available insights, sorted by priority.

        Returns at most max_count insights.
        """
        all_insights: List[Insight] = []

        all_insights.extend(self._ecosystem_insights())
        all_insights.extend(self._security_insights())
        all_insights.extend(self._behavioral_insights())
        all_insights.extend(self._temporal_insights())
        all_insights.extend(self._threat_insights())

        all_insights.sort(key=lambda i: i.priority)
        return all_insights[:max_count]

    def get_insights_for_topic(self, topic: str, max_count: int = 3) -> List[Insight]:
        """Get insights filtered by topic keyword."""
        topic_lower = topic.lower()

        category_map = {
            InsightCategory.ECOSYSTEM: ["device", "ecosystem", "cluster", "vendor", "manufacturer"],
            InsightCategory.SECURITY: ["security", "privacy", "random", "track", "fingerprint", "pnl"],
            InsightCategory.BEHAVIORAL: ["behavior", "pattern", "mobile", "stationary", "signal", "rssi"],
            InsightCategory.TEMPORAL: ["time", "temporal", "new", "trend", "history", "visitor"],
            InsightCategory.THREAT: ["threat", "surveillance", "flock", "raven", "anomaly", "danger"],
        }

        matched_categories: set[str] = set()
        for cat, keywords in category_map.items():
            if any(kw in topic_lower for kw in keywords):
                matched_categories.add(cat)

        if not matched_categories:
            return self.get_insights(max_count)

        all_insights = self.get_insights(max_count=50)
        filtered = [i for i in all_insights if i.category in matched_categories]
        return filtered[:max_count]

    def get_voice_briefing(self) -> str:
        """
        Generate a comprehensive voice briefing (~30 seconds of speech).

        Combines the top insights into a coherent narrative.
        """
        insights = self.get_insights(max_count=4)
        if not insights:
            return "No insights available. The system needs more data to generate analysis."

        parts = ["Here's your signals briefing."]
        for insight in insights:
            parts.append(insight.text)

        return " ".join(parts)

    # ------------------------------------------------------------------
    # Ecosystem Insights
    # ------------------------------------------------------------------

    def _ecosystem_insights(self) -> List[Insight]:
        """Insights about the device ecosystem composition."""
        clusters = self._get_clusters()
        if not clusters:
            return []

        insights: List[Insight] = []

        # Cross-vendor clusters (same user, multiple device brands)
        pnl_xv = [c for c in clusters.values() if c.get("cluster_type") == "pnl_cross_vendor"]
        if pnl_xv:
            insights.append(Insight(
                InsightCategory.ECOSYSTEM, 2,
                f"Identified {len(pnl_xv)} users carrying devices from multiple manufacturers. "
                "Their network fingerprints match across different vendor hardware.",
                detail=f"pnl_cross_vendor clusters: {len(pnl_xv)}",
            ))

        # Cross-linked WiFi+BT devices
        xlinked = [c for c in clusters.values() if c.get("cluster_type") == "cross_linked"]
        if xlinked:
            total_members = sum(c.get("member_count", 0) for c in xlinked)
            insights.append(Insight(
                InsightCategory.ECOSYSTEM, 3,
                f"{len(xlinked)} devices have been cross-linked between WiFi and Bluetooth, "
                f"covering {total_members} total radio identities. "
                "These are confirmed multi-radio physical devices.",
            ))

        # BT name groups
        bt_names = [c for c in clusters.values() if c.get("cluster_type") == "bt_name"]
        if bt_names:
            named_count = sum(c.get("member_count", 0) for c in bt_names)
            insights.append(Insight(
                InsightCategory.ECOSYSTEM, 4,
                f"{named_count} Bluetooth devices are broadcasting identifiable names across "
                f"{len(bt_names)} name groups. Named devices are easier to track persistently.",
            ))

        # Vendor diversity
        vendor_counts = self._count_vendors(clusters)
        if len(vendor_counts) >= 3:
            top_vendors = vendor_counts.most_common(3)
            vendor_str = ", ".join(f"{v[0]} ({v[1]})" for v in top_vendors)
            insights.append(Insight(
                InsightCategory.ECOSYSTEM, 5,
                f"Device ecosystem spans {len(vendor_counts)} vendors. "
                f"Top manufacturers: {vendor_str}.",
            ))

        # Cluster type distribution
        type_counts = Counter(c.get("cluster_type", "unknown") for c in clusters.values())
        singleton_count = type_counts.get("randomised", 0)
        grouped_count = len(clusters) - singleton_count
        if len(clusters) > 10:
            pct_grouped = grouped_count / len(clusters) * 100
            insights.append(Insight(
                InsightCategory.ECOSYSTEM, 6,
                f"Of {len(clusters)} total clusters, {grouped_count} ({pct_grouped:.0f}%) "
                f"are grouped and {singleton_count} are uncorrelated singletons.",
            ))

        return insights

    # ------------------------------------------------------------------
    # Security Insights
    # ------------------------------------------------------------------

    def _security_insights(self) -> List[Insight]:
        """Insights about privacy and security posture of detected devices."""
        clusters = self._get_clusters()
        if not clusters:
            return []

        insights: List[Insight] = []

        # MAC randomization effectiveness
        randomised = [c for c in clusters.values() if c.get("cluster_type") == "randomised"]
        pnl_matched = [c for c in clusters.values() if c.get("cluster_type") in ("pnl_match", "pnl_overlap")]

        if randomised and pnl_matched:
            insights.append(Insight(
                InsightCategory.SECURITY, 1,
                f"Despite MAC randomization, {len(pnl_matched)} device groups were correlated "
                "by their network probe fingerprints. These devices are trackable through "
                "their preferred network lists, even with random MACs.",
            ))
        elif len(randomised) > 10 and not pnl_matched:
            insights.append(Insight(
                InsightCategory.SECURITY, 3,
                f"{len(randomised)} randomized MAC addresses remain uncorrelated. "
                "Devices are effectively using MAC privacy features.",
            ))

        # Trackability analysis
        high_track = 0
        low_track = 0
        for c in clusters.values():
            addr = c.get("addr_types", {})
            trackability = addr.get("cluster_trackability", "")
            if trackability == "high":
                high_track += 1
            elif trackability in ("low", "none"):
                low_track += 1

        if high_track > 0:
            insights.append(Insight(
                InsightCategory.SECURITY, 2,
                f"{high_track} device clusters have high trackability due to permanent "
                "MAC addresses. These devices can be persistently identified across sessions.",
            ))

        # PNL fingerprint uniqueness
        pnl_exact = [c for c in clusters.values() if c.get("cluster_type") == "pnl_match"]
        if pnl_exact:
            insights.append(Insight(
                InsightCategory.SECURITY, 2,
                f"{len(pnl_exact)} devices share identical probe fingerprints, "
                "confirming they are the same physical device using different MAC addresses. "
                "PNL fingerprinting defeats MAC randomization for these devices.",
            ))

        return insights

    # ------------------------------------------------------------------
    # Behavioral Insights
    # ------------------------------------------------------------------

    def _behavioral_insights(self) -> List[Insight]:
        """Insights about device behavior patterns."""
        clusters = self._get_clusters()
        if not clusters:
            return []

        insights: List[Insight] = []

        # RSSI spread analysis (stationary vs. mobile)
        spreads: List[float] = []
        for c in clusters.values():
            rssi = c.get("rssi_summary", {})
            spread = rssi.get("spread", 0)
            if spread > 0:
                spreads.append(spread)

        if spreads:
            avg_spread = sum(spreads) / len(spreads)
            high_spread = sum(1 for s in spreads if s > 15)
            low_spread = sum(1 for s in spreads if s <= 5)

            if avg_spread > 15:
                insights.append(Insight(
                    InsightCategory.BEHAVIORAL, 3,
                    f"Average signal variation is {avg_spread:.1f} dBm across {len(spreads)} clusters. "
                    f"{high_spread} clusters show high variation, suggesting mobile devices "
                    "or a multipath-rich environment.",
                ))
            elif avg_spread <= 5:
                insights.append(Insight(
                    InsightCategory.BEHAVIORAL, 4,
                    f"Signal patterns are very stable with {avg_spread:.1f} dBm average variation. "
                    f"{low_spread} clusters show minimal movement. "
                    "Most devices appear stationary.",
                ))
            else:
                insights.append(Insight(
                    InsightCategory.BEHAVIORAL, 5,
                    f"Mixed mobility pattern: {avg_spread:.1f} dBm average signal variation. "
                    f"{high_spread} mobile clusters, {low_spread} stationary.",
                ))

        # Signal strength distribution (proximity analysis)
        rssi_values: List[float] = []
        for c in clusters.values():
            rssi = c.get("rssi_summary", {})
            avg = rssi.get("avg", 0)
            if avg < 0:
                rssi_values.append(avg)

        if rssi_values:
            very_close = sum(1 for r in rssi_values if r > -50)
            close = sum(1 for r in rssi_values if -70 < r <= -50)
            far = sum(1 for r in rssi_values if r <= -70)

            if very_close > 0:
                insights.append(Insight(
                    InsightCategory.BEHAVIORAL, 3,
                    f"Proximity analysis: {very_close} clusters within 5 meters, "
                    f"{close} at 5-20 meters, {far} beyond 20 meters.",
                ))

        # Sighting density
        sighting_counts: List[int] = []
        for c in clusters.values():
            sightings = c.get("total_sightings", 0)
            if sightings > 0:
                sighting_counts.append(sightings)

        if sighting_counts:
            max_sightings = max(sighting_counts)
            avg_sightings = sum(sighting_counts) / len(sighting_counts)
            persistent = sum(1 for s in sighting_counts if s > avg_sightings * 2)

            if persistent > 0:
                insights.append(Insight(
                    InsightCategory.BEHAVIORAL, 4,
                    f"{persistent} device clusters show persistent presence with above-average "
                    f"sighting counts. Most active cluster has {max_sightings} sightings.",
                ))

        return insights

    # ------------------------------------------------------------------
    # Temporal Insights
    # ------------------------------------------------------------------

    def _temporal_insights(self) -> List[Insight]:
        """Insights about temporal patterns and trends."""
        clusters = self._get_clusters()
        if not clusters:
            return []

        insights: List[Insight] = []

        # Convergence progress insight
        conv = self._get_convergence_info()
        if conv:
            step = conv.get("step", 0)
            pct = conv.get("convergence_pct", 0)
            converged = conv.get("converged", False)

            if converged:
                insights.append(Insight(
                    InsightCategory.TEMPORAL, 5,
                    f"The correlation engine has fully converged after {step} steps. "
                    "Cluster boundaries are now at maximum precision. "
                    "New devices will be classified with high accuracy.",
                ))
            elif step > 0:
                remaining_steps = max(0, 36 - step)
                remaining_min = remaining_steps  # ~1 step/min
                insights.append(Insight(
                    InsightCategory.TEMPORAL, 6,
                    f"Correlation engine is {pct:.0f}% converged at step {step}. "
                    f"Approximately {remaining_min} minutes until full convergence. "
                    "Cluster precision is still improving.",
                ))

        # Alert count from world state
        if self.world_state is not None:
            threats = self.world_state.state.get("threats", [])
            if threats:
                insights.append(Insight(
                    InsightCategory.TEMPORAL, 3,
                    f"World state contains {len(threats)} logged threats from this session. "
                    "Review with 'status' command for details.",
                ))

        return insights

    # ------------------------------------------------------------------
    # Threat Insights
    # ------------------------------------------------------------------

    def _threat_insights(self) -> List[Insight]:
        """Insights about surveillance threats and anomalies."""
        clusters = self._get_clusters()
        if not clusters:
            return []

        insights: List[Insight] = []

        # Surveillance device density
        surv_patterns = ["FLOCK", "RAVEN", "PENGUIN", "FS EXT", "SHOTSPOT", "PIGVISION"]
        surveillance_clusters: List[Dict[str, Any]] = []

        for c in clusters.values():
            ssids = c.get("ssids", []) + c.get("probed_ssids", [])
            ssid_str = " ".join(ssids).upper()
            if any(p in ssid_str for p in surv_patterns):
                surveillance_clusters.append(c)

        if surveillance_clusters:
            # Categorize by type
            type_counts: Dict[str, int] = {}
            for sc in surveillance_clusters:
                ssids = sc.get("ssids", []) + sc.get("probed_ssids", [])
                ssid_str = " ".join(ssids).upper()
                for pattern in surv_patterns:
                    if pattern in ssid_str:
                        type_counts[pattern] = type_counts.get(pattern, 0) + 1
                        break

            type_str = ", ".join(f"{k}: {v}" for k, v in type_counts.items())
            insights.append(Insight(
                InsightCategory.THREAT, 1,
                f"{len(surveillance_clusters)} surveillance device clusters detected. "
                f"Breakdown: {type_str}. "
                "Exercise caution in this area.",
            ))

            # Closest surveillance device
            closest_rssi = -999
            closest_ssid = ""
            for sc in surveillance_clusters:
                rssi = sc.get("rssi_summary", {}).get("avg", -999)
                if rssi > closest_rssi:
                    closest_rssi = rssi
                    closest_ssid = ", ".join(sc.get("ssids", [])[:1]) or "unknown"

            if closest_rssi > -999:
                # Rough distance estimate: d = 10^((TxPower - RSSI) / (10 * n))
                # Assume TxPower = -30 dBm, n = 2.5
                try:
                    distance = 10 ** ((-30 - closest_rssi) / (10 * 2.5))
                    insights.append(Insight(
                        InsightCategory.THREAT, 1,
                        f"Nearest surveillance device '{closest_ssid}' at approximately "
                        f"{distance:.0f} meters (signal {closest_rssi} dBm).",
                    ))
                except (ValueError, OverflowError):
                    pass

        elif len(clusters) > 20:
            insights.append(Insight(
                InsightCategory.THREAT, 6,
                "No known surveillance device patterns detected in the current scan. "
                f"Monitoring {len(clusters)} device clusters.",
            ))

        # High-alert clusters
        high_alert_clusters = [
            c for c in clusters.values()
            if c.get("alert_count", 0) > 10
        ]
        if high_alert_clusters:
            insights.append(Insight(
                InsightCategory.THREAT, 2,
                f"{len(high_alert_clusters)} device clusters have elevated alert counts. "
                "These may warrant closer investigation.",
            ))

        # Feedback-informed threat assessment
        if self.feedback_db is not None:
            try:
                confirmed = self.feedback_db.get_feedback(days=1, feedback_type="confirmed_threat")
                if confirmed:
                    insights.append(Insight(
                        InsightCategory.THREAT, 2,
                        f"{len(confirmed)} threats were operator-confirmed in the last 24 hours. "
                        "The threat database has been updated accordingly.",
                    ))
            except Exception:
                pass

        return insights

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _get_clusters(self) -> Dict[str, Dict[str, Any]]:
        if self.correlator is None:
            return {}
        return getattr(self.correlator, "clusters", {})

    def _get_convergence_info(self) -> Optional[Dict[str, Any]]:
        if self.correlator is None:
            return None
        try:
            return self.correlator.rssi_tolerance_info()
        except Exception:
            return None

    @staticmethod
    def _count_vendors(clusters: Dict[str, Dict[str, Any]]) -> Counter:
        """Count device vendors across all clusters."""
        vendors: Counter = Counter()
        for c in clusters.values():
            members = c.get("members", [])
            for m in members:
                mfr = m.get("manufacturer", "")
                if mfr and mfr != "Unknown":
                    vendors[mfr] += 1
        return vendors
