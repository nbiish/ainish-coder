#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pyyaml>=6.0.0",
# ]
# [tool.uv]
# exclude-newer = "2026-02-01T00:00:00Z"
# ///
"""
Correlation Context Injector
============================

Builds rich, structured context strings from the correlation engine,
world state, Kismet, and alert history for injection into LLM prompts.

The context injector ensures the voice agent's LLM has full situational
awareness of:
  - Active device clusters (all 9 types)
  - Convergence state and RSSI tolerance
  - Surveillance threat status
  - Recent alert activity
  - Behavioral patterns (stationary vs. mobile)

USAGE:
    Imported by unified_voice_agent.py — not run standalone.
"""

from __future__ import annotations

import logging
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


class AlertOrchestratorProtocol(Protocol):
    def get_recent_alerts(self, limit: int = 10) -> List[Dict[str, Any]]: ...
    def get_alert_summary(self) -> str: ...


class KismetClientProtocol(Protocol):
    def get_devices(self, phy: str = "wifi") -> List[Dict[str, Any]]: ...
    def get_context(self) -> str: ...


# ============================================================================
# Cluster Type Descriptions (maps to signals-correlation-engine.md §12)
# ============================================================================

CLUSTER_TYPE_INFO: Dict[str, Dict[str, str]] = {
    "manufacturer": {
        "label": "Vendor-Grouped",
        "desc": "Same OUI manufacturer, single RSSI band",
        "significance": "low",
    },
    "manufacturer_rssi": {
        "label": "Vendor+Distance",
        "desc": "Same vendor, distinct RSSI bands (different distances)",
        "significance": "medium",
    },
    "pnl_match": {
        "label": "Fingerprint Match",
        "desc": "Identical probe network list — near-certain same device",
        "significance": "high",
    },
    "pnl_overlap": {
        "label": "Partial Fingerprint",
        "desc": "Overlapping but not identical probe lists",
        "significance": "medium",
    },
    "randomised": {
        "label": "Randomized Singleton",
        "desc": "Randomized MAC with no cluster match",
        "significance": "low",
    },
    "bt_name": {
        "label": "BT Name Group",
        "desc": "Multiple BT MACs with same advertised name",
        "significance": "medium",
    },
    "bt_rssi": {
        "label": "BT Signal Group",
        "desc": "Unnamed random BT grouped by signal proximity",
        "significance": "low",
    },
    "cross_linked": {
        "label": "Cross-Protocol",
        "desc": "WiFi cluster merged with BT cluster (same physical device)",
        "significance": "high",
    },
    "pnl_cross_vendor": {
        "label": "Cross-Vendor",
        "desc": "Different vendor clusters with same fingerprint (same user, multiple devices)",
        "significance": "high",
    },
}


# ============================================================================
# Correlation Context Injector
# ============================================================================

class CorrelationContextInjector:
    """
    Builds structured context from all signals subsystems for LLM injection.

    Context is formatted as concise natural language suitable for both
    system prompt injection and voice readback.
    """

    def __init__(
        self,
        correlator: Optional[CorrelatorProtocol] = None,
        world_state: Optional[WorldStateProtocol] = None,
        alert_orchestrator: Optional[AlertOrchestratorProtocol] = None,
        kismet: Optional[KismetClientProtocol] = None,
    ):
        self.correlator = correlator
        self.world_state = world_state
        self.alert_orchestrator = alert_orchestrator
        self.kismet = kismet

    # ------------------------------------------------------------------
    # Full Context (for LLM system prompt injection)
    # ------------------------------------------------------------------

    def build_full_context(self) -> str:
        """
        Build comprehensive context string for LLM prompt injection.

        Returns a multi-section context covering all subsystems.
        """
        sections: List[str] = []

        sections.append(self._correlation_summary())
        sections.append(self._convergence_summary())
        sections.append(self._surveillance_summary())
        sections.append(self._world_state_summary())
        sections.append(self._alert_summary())
        sections.append(self._kismet_summary())

        # Filter empty sections
        sections = [s for s in sections if s]
        return "\n".join(sections)

    # ------------------------------------------------------------------
    # Short Context (for voice status readback)
    # ------------------------------------------------------------------

    def build_voice_context(self) -> str:
        """
        Build concise context suitable for voice delivery (~3-5 sentences).
        """
        parts: List[str] = []

        # Cluster count
        cluster_stats = self._get_cluster_stats()
        if cluster_stats["total"] > 0:
            parts.append(
                f"Tracking {cluster_stats['total']} device clusters, "
                f"{cluster_stats['high_confidence']} high-confidence."
            )

        # Surveillance
        surv_count = cluster_stats.get("surveillance_related", 0)
        if surv_count > 0:
            parts.append(f"{surv_count} surveillance-related clusters active.")

        # Cross-linked
        xlink = cluster_stats.get("cross_linked", 0)
        if xlink > 0:
            parts.append(f"{xlink} cross-protocol devices identified.")

        # Convergence
        conv = self._get_convergence_info()
        if conv:
            if conv.get("converged"):
                parts.append("Correlation engine converged.")
            else:
                pct = conv.get("convergence_pct", 0)
                parts.append(f"Correlation {pct:.0f}% converged.")

        # World state threats
        threats = self._get_threat_count()
        if threats > 0:
            parts.append(f"{threats} logged threats in world state.")

        if not parts:
            parts.append("No active monitoring data available.")

        return " ".join(parts)

    # ------------------------------------------------------------------
    # Section Builders
    # ------------------------------------------------------------------

    def _correlation_summary(self) -> str:
        """Summarize correlation engine cluster state."""
        stats = self._get_cluster_stats()
        if stats["total"] == 0:
            return "[CORRELATION] No clusters available."

        lines = [f"[CORRELATION] {stats['total']} clusters:"]

        for ctype, info in CLUSTER_TYPE_INFO.items():
            count = stats["by_type"].get(ctype, 0)
            if count > 0:
                lines.append(f"  - {info['label']}: {count} ({info['desc']})")

        lines.append(
            f"  High-confidence (>0.7): {stats['high_confidence']} | "
            f"Surveillance-related: {stats['surveillance_related']} | "
            f"Cross-linked: {stats['cross_linked']}"
        )

        return "\n".join(lines)

    def _convergence_summary(self) -> str:
        """Summarize RSSI convergence state."""
        info = self._get_convergence_info()
        if not info:
            return ""

        step = info.get("step", 0)
        pct = info.get("convergence_pct", 0)
        wifi_gap = info.get("rssi_gap_dbm", 0)
        bt_gap = info.get("bt_tolerance_dbm", 0)
        converged = info.get("converged", False)

        if converged:
            return (
                f"[CONVERGENCE] Fully converged at step {step}. "
                f"WiFi tolerance: {wifi_gap:.1f} dBm, BT tolerance: {bt_gap:.1f} dBm."
            )
        return (
            f"[CONVERGENCE] Step {step}, {pct:.0f}% converged. "
            f"WiFi gap: {wifi_gap:.1f} dBm (target 1.0), "
            f"BT gap: {bt_gap:.1f} dBm (target 5.0)."
        )

    def _surveillance_summary(self) -> str:
        """Summarize surveillance-specific detections."""
        if self.correlator is None:
            return ""

        clusters = getattr(self.correlator, "clusters", {})
        surveillance_clusters: List[Dict[str, Any]] = []

        patterns = ["FLOCK", "RAVEN", "PENGUIN", "FS EXT", "SHOTSPOT", "PIGVISION"]
        for cluster in clusters.values():
            ssids = cluster.get("ssids", []) + cluster.get("probed_ssids", [])
            ssid_str = " ".join(ssids).upper()
            if any(p in ssid_str for p in patterns):
                surveillance_clusters.append(cluster)

        if not surveillance_clusters:
            return "[SURVEILLANCE] No surveillance devices detected."

        lines = [f"[SURVEILLANCE] {len(surveillance_clusters)} surveillance clusters:"]
        for sc in surveillance_clusters[:5]:
            label = sc.get("label", sc.get("cluster_id", "unknown"))
            conf = sc.get("confidence", 0)
            rssi_info = sc.get("rssi_summary", {})
            avg_rssi = rssi_info.get("avg", 0)
            lines.append(f"  - {label}: confidence {conf:.0%}, avg RSSI {avg_rssi:.0f} dBm")

        return "\n".join(lines)

    def _world_state_summary(self) -> str:
        """Summarize OSA world state."""
        if self.world_state is None:
            return ""

        state = getattr(self.world_state, "state", {})
        threats = state.get("threats", [])
        status = state.get("status", "unknown")
        env = state.get("environment", "unknown")
        last_update = state.get("last_update", "never")

        parts = [f"[WORLD STATE] Status: {status}, Environment: {env}."]
        if threats:
            parts.append(f"  Active threats: {len(threats)}.")
            for t in threats[:3]:
                mac = t.get("mac", "?")
                ssid = t.get("ssid", "?")
                score = t.get("score", 0)
                parts.append(f"  - {ssid} ({mac}) score={score:.2f}")
        else:
            parts.append("  No active threats logged.")

        parts.append(f"  Last updated: {last_update}")
        return "\n".join(parts)

    def _alert_summary(self) -> str:
        """Summarize recent alerts."""
        if self.alert_orchestrator is None:
            return ""

        summary = self.alert_orchestrator.get_alert_summary()
        recent = self.alert_orchestrator.get_recent_alerts(limit=3)

        lines = [f"[ALERTS] {summary}"]
        if recent:
            lines.append("  Recent:")
            for a in recent:
                prio = a.get("priority", 5)
                msg = a.get("message", "")[:80]
                lines.append(f"  - [P{prio}] {msg}")

        return "\n".join(lines)

    def _kismet_summary(self) -> str:
        """Summarize Kismet connection status."""
        if self.kismet is None:
            return "[KISMET] Not configured."

        try:
            status = self.kismet.get_context()
        except Exception:
            status = "Kismet: Error"

        return f"[KISMET] {status}"

    # ------------------------------------------------------------------
    # Data Accessors
    # ------------------------------------------------------------------

    def _get_cluster_stats(self) -> Dict[str, Any]:
        """Compute cluster statistics from the correlation engine."""
        if self.correlator is None:
            return {
                "total": 0, "high_confidence": 0,
                "surveillance_related": 0, "cross_linked": 0,
                "by_type": {},
            }

        clusters = getattr(self.correlator, "clusters", {})
        by_type: Dict[str, int] = {}
        high_conf = 0
        surv = 0
        xlink = 0

        patterns = ["FLOCK", "RAVEN", "PENGUIN", "FS EXT", "SHOTSPOT"]

        for cluster in clusters.values():
            ctype = cluster.get("cluster_type", "unknown")
            by_type[ctype] = by_type.get(ctype, 0) + 1

            if cluster.get("confidence", 0) > 0.7:
                high_conf += 1

            if ctype == "cross_linked":
                xlink += 1

            ssids = cluster.get("ssids", []) + cluster.get("probed_ssids", [])
            ssid_str = " ".join(ssids).upper()
            if any(p in ssid_str for p in patterns):
                surv += 1

        return {
            "total": len(clusters),
            "high_confidence": high_conf,
            "surveillance_related": surv,
            "cross_linked": xlink,
            "by_type": by_type,
        }

    def _get_convergence_info(self) -> Optional[Dict[str, Any]]:
        """Get convergence info from the correlation engine."""
        if self.correlator is None:
            return None
        try:
            return self.correlator.rssi_tolerance_info()
        except Exception:
            return None

    def _get_threat_count(self) -> int:
        """Get active threat count from world state."""
        if self.world_state is None:
            return 0
        state = getattr(self.world_state, "state", {})
        return len(state.get("threats", []))

    # ------------------------------------------------------------------
    # Specialized Context Builders
    # ------------------------------------------------------------------

    def build_query_context(self, user_query: str) -> str:
        """
        Build context tailored to a specific user query.

        Analyzes the query for keywords and includes only relevant sections.
        """
        query_lower = user_query.lower()
        sections: List[str] = []

        # Always include basic status
        sections.append(self.build_voice_context())

        # Keyword-triggered deep context
        if any(kw in query_lower for kw in ["cluster", "correlat", "group", "link"]):
            sections.append(self._correlation_summary())
            sections.append(self._convergence_summary())

        if any(kw in query_lower for kw in ["surveil", "flock", "raven", "camera", "threat"]):
            sections.append(self._surveillance_summary())
            sections.append(self._world_state_summary())

        if any(kw in query_lower for kw in ["alert", "warn", "notif"]):
            sections.append(self._alert_summary())

        if any(kw in query_lower for kw in ["kismet", "wifi", "ble", "bluetooth", "device"]):
            sections.append(self._kismet_summary())

        if any(kw in query_lower for kw in ["converge", "rssi", "tolerance", "gap"]):
            sections.append(self._convergence_summary())

        return "\n".join(s for s in sections if s)

    def build_cluster_detail(self, cluster_id: str) -> str:
        """Build detailed context for a specific cluster."""
        if self.correlator is None:
            return "Correlation engine not available."

        clusters = getattr(self.correlator, "clusters", {})
        cluster = clusters.get(cluster_id)
        if not cluster:
            return f"Cluster {cluster_id} not found."

        ctype = cluster.get("cluster_type", "unknown")
        info = CLUSTER_TYPE_INFO.get(ctype, {"label": ctype, "desc": "Unknown type"})

        lines = [
            f"Cluster: {cluster.get('label', cluster_id)}",
            f"Type: {info['label']} — {info['desc']}",
            f"Confidence: {cluster.get('confidence', 0):.0%}",
            f"Members: {cluster.get('member_count', 0)}",
        ]

        rssi = cluster.get("rssi_summary", {})
        if rssi:
            lines.append(
                f"Signal: avg {rssi.get('avg', 0):.0f} dBm, "
                f"spread {rssi.get('spread', 0):.0f} dBm"
            )

        ssids = cluster.get("ssids", [])
        if ssids:
            lines.append(f"Networks: {', '.join(ssids[:5])}")

        addr = cluster.get("addr_types", {})
        if addr:
            lines.append(f"Trackability: {addr.get('cluster_trackability', 'unknown')}")

        pnl = cluster.get("pnl_match", {})
        if pnl.get("has_pnl_match"):
            lines.append("PNL fingerprint match: Yes")

        return "\n".join(lines)
