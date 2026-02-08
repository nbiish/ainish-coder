# Signal Correlation Engine — Algorithm Deep Dive

> **Complete technical reference for the multi-dimensional clustering engine,
> exponential RSSI convergence, 9 cluster types, WiFi↔BT cross-linking,
> and PNL fingerprint matching.**
>
> This is the core algorithm that links WiFi and BLE observations from the
> same physical device — even when the device uses MAC randomization.
>
> **Implementation**: `SignalCorrelator` class in `webapp/app.py` (L1408–L2390)
>
> **Last updated**: 2026-02-08 — Major rewrite from union-find to multi-dimensional clustering

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Architecture Overview](#2-architecture-overview)
3. [Class Constants & Configuration](#3-class-constants--configuration)
4. [RSSI Gap Convergence](#4-rssi-gap-convergence)
5. [Phase 1: Unified Device Profiles](#5-phase-1-unified-device-profiles)
6. [Phase 2: Manufacturer/OUI Grouping + RSSI Sub-Clustering](#6-phase-2-manufactureroui-grouping--rssi-sub-clustering)
7. [Phase 3: PNL Fingerprint Grouping (Randomised WiFi)](#7-phase-3-pnl-fingerprint-grouping-randomised-wifi)
8. [Phase 3b: BT Device Grouping](#8-phase-3b-bt-device-grouping)
9. [Phase 4: WiFi↔BT Cross-Link Merging](#9-phase-4-wifibt-cross-link-merging)
10. [Phase 5: Cross-Vendor PNL Merging](#10-phase-5-cross-vendor-pnl-merging)
11. [Phase 6: Finalization — Scoring, Identification, Persistence](#11-phase-6-finalization--scoring-identification-persistence)
12. [9 Cluster Types](#12-9-cluster-types)
13. [Cluster ID Naming Convention](#13-cluster-id-naming-convention)
14. [Confidence Scoring](#14-confidence-scoring)
15. [WiFi↔BT Cross-Link Scoring Detail](#15-wifibt-cross-link-scoring-detail)
16. [PNL Jaccard Clustering Detail](#16-pnl-jaccard-clustering-detail)
17. [RSSI Band Sub-Clustering Detail](#17-rssi-band-sub-clustering-detail)
18. [Cluster Metadata & Evidence Links](#18-cluster-metadata--evidence-links)
19. [Cluster Identification & Naming](#19-cluster-identification--naming)
20. [Persistence & State Management](#20-persistence--state-management)
21. [Recomputation Strategy](#21-recomputation-strategy)
22. [Performance Characteristics](#22-performance-characteristics)
23. [Convergence Timeline](#23-convergence-timeline)
24. [Tuning Guide](#24-tuning-guide)
25. [Deprecated: Union-Find (Pre-2026-02-08)](#25-deprecated-union-find-pre-2026-02-08)

---

## 1. Problem Statement

A single physical device (e.g., a phone) may present **multiple identities**:

| Radio | MAC | Name | Example |
|-------|-----|------|---------|
| WiFi (probing) | `AA:BB:CC:DD:EE:01` | — | Randomized MAC probe |
| WiFi (connected) | `AA:BB:CC:DD:EE:02` | "iPhone-John" | Different random MAC |
| BLE | `CC:DD:EE:FF:00:11` | "John's AirPods" | BLE address |
| BLE (rotated) | `CC:DD:EE:FF:00:22` | "John's AirPods" | Rotated BLE address |

The correlation engine must link these 4 observations into a single cluster
representing "John's device(s)."

### Why This is Hard

1. **MAC randomization** — iOS/Android rotate MACs per SSID and over time
2. **Cross-protocol** — WiFi and BLE use different address spaces and formats
3. **No shared identifier** — No guaranteed common field between WiFi and BLE
4. **Privacy features** — Modern OSes actively try to prevent this linking
5. **Environmental noise** — Many devices share similar RSSI, channels, timing

### Our Approach: Multi-Dimensional Clustering

Instead of pairwise scoring (the old union-find approach), we use
**independent dimensional grouping** with **post-hoc merges**:

```
Phase 1: Build unified profiles (WiFi + BT)
Phase 2: Group by OUI vendor → RSSI sub-cluster within vendor
Phase 3: Group randomised WiFi by PNL fingerprint
Phase 3b: Group BT by name → RSSI sub-cluster unnamed
Phase 4: Cross-link WiFi clusters ↔ BT clusters
Phase 5: Merge across vendors via shared PNL hash
Phase 6: Score confidence, preserve identifications, persist
```

This produces **9 distinct cluster types** (see §12) rather than
one homogeneous type.

---

## 2. Architecture Overview

```
Inputs:                              Outputs:
┌──────────────┐                     ┌──────────────────────────┐
│ WiFi Devices │──┐                  │ ~315 typed clusters      │
│ (iw/Kismet)  │  │                  │ with confidence scores,  │
└──────────────┘  │    ┌──────────┐  │ evidence links, PNL      │
                  ├───→│correlate()├─→│ summaries, addr types,   │
┌──────────────┐  │    └──────────┘  │ RSSI summaries, alerts,  │
│ BT Devices   │──┘                  │ and identification state │
│ (btmgmt)     │                     └──────────────────────────┘
└──────────────┘
        ↕
  ┌──────────────┐
  │ PNL Engine   │ ← Jaccard similarity, PNL hashes
  └──────────────┘
        ↕
  ┌──────────────┐
  │ Fingerprint  │ ← Sighting history, names, SSIDs
  │ Database     │
  └──────────────┘
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Multi-dimensional, not pairwise** | $O(n)$ per dimension vs $O(n^2)$ pairwise |
| **9 typed clusters** | Each type carries semantic meaning for the UI |
| **Exponential convergence** | Smooth tightening without oscillation artifacts |
| **BT gets +4 dBm offset** | BLE RSSI is inherently noisier than WiFi |
| **Cross-link as merge** | WiFi↔BT pairs fuse entire clusters, not just pairs |
| **PNL as strongest signal** | Probe list fingerprint is quasi-unique per device |

---

## 3. Class Constants & Configuration

```python
class SignalCorrelator:
    # ── Persistence ─────────────────────────────────────────
    CORRELATION_FILE_NAME: str = "signal_correlations.json"

    # ── RSSI Gap Convergence ────────────────────────────────
    RSSI_GAP_INITIAL: float = 20.0   # Starting gap (permissive)
    RSSI_GAP_TARGET:  float = 1.0    # Target gap (very tight — 1 dBm)
    RSSI_GAP_DECAY:   float = 0.92   # Exponential decay per step

    # ── Cross-Protocol Thresholds ───────────────────────────
    WIFI_BT_LINK_THRESHOLD:       float = 0.50  # WiFi↔BT merge score
    CROSS_VENDOR_PNL_THRESHOLD:   float = 0.70  # Cross-vendor PNL Jaccard
```

### Instance State

```python
self.path: Path                              # Persistence file path
self._lock: threading.Lock                   # Thread safety
self.clusters: dict[str, dict[str, Any]]     # Cluster ID → cluster metadata
self._correlation_step: int                  # Monotonically incrementing
self._pnl_engine: Any                        # Reference to PNL Engine
self._rssi_profiles: dict[str, list[float]]  # RSSI history per cluster
```

---

## 4. RSSI Gap Convergence

### Formula

$$\text{gap}(n) = T + (I - T) \cdot D^n$$

$$= 1.0 + 19.0 \times 0.92^n$$

| Symbol | Constant | Value | Meaning |
|--------|----------|-------|---------|
| $I$ | `RSSI_GAP_INITIAL` | 20.0 dBm | Starting tolerance (permissive) |
| $T$ | `RSSI_GAP_TARGET` | 1.0 dBm | Final tolerance (very tight) |
| $D$ | `RSSI_GAP_DECAY` | 0.92 | Decay rate per step |
| $n$ | `_correlation_step` | 0, 1, 2, … | Incremented each recompute |

### Implementation

```python
@property
def rssi_gap(self) -> float:
    n = self._correlation_step
    amplitude = self.RSSI_GAP_INITIAL - self.RSSI_GAP_TARGET   # 19.0
    return self.RSSI_GAP_TARGET + amplitude * (self.RSSI_GAP_DECAY ** n)
```

### WiFi vs BT Tolerance

| Protocol | Band Clustering Gap | Cross-Link Tolerance |
|----------|-------------------|---------------------|
| **WiFi** | `gap` | `gap` |
| **BT** | `gap + 4` | `gap + 4` |

BLE RSSI is inherently noisier (±5–10 dBm vs ±3–5 dBm for WiFi) due to
shorter advertising intervals, multipath effects, and measurement frequency
differences. The +4 dBm offset compensates.

### Convergence Visualization

```
RSSI Gap (dBm)
   20 │ ●                                       WiFi gap
      │  ●                                      BT gap = WiFi + 4
   18 │   ●
      │    ●
   16 │     ●
      │      ●●
   14 │        ●●
      │          ●●
   12 │            ●●
      │              ●●●
   10 │                 ●●●
      │                    ●●●●
    8 │                        ●●●●●
      │                             ●●●●●●
    6 │ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ← BT target (5 dBm)
      │                                    ●●●●●●●●
    4 │                                             ●●●●●●●●●
      │
    2 │                                                       ●●●●●●
    1 │ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ← WiFi target (1 dBm)
      └───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───→
          0   5  10  15  20  25  30  35  40  45  50   step
```

### Convergence State Reporting

```python
def rssi_tolerance_info(self) -> dict[str, Any]:
    return {
        "step":                 n,
        "rssi_gap_dbm":         round(gap, 1),      # Current WiFi gap
        "rssi_gap_target_dbm":  1.0,                 # WiFi target
        "rssi_gap_initial_dbm": 20.0,
        "wifi_tolerance_dbm":   round(gap, 1),
        "bt_tolerance_dbm":     round(gap + 4, 1),   # BT = WiFi + 4
        "wifi_target_dbm":      1.0,
        "bt_target_dbm":        5.0,                  # 1.0 + 4
        "initial_dbm":          20.0,
        "decay_factor":         0.92,
        "wifi_envelope_dbm":    round(envelope, 1),
        "bt_envelope_dbm":      round(envelope, 1),
        "converged":            envelope < 1.0,
        "convergence_pct":      round(pct, 0),
    }
```

**Converged** when envelope < 1.0 dBm → solving $19 \times 0.92^n < 1.0$:

$$n > \frac{\ln(1/19)}{\ln(0.92)} \approx 35.3$$

→ **Converges at step 36** (~36 minutes at 60s/step).

---

## 5. Phase 1: Unified Device Profiles

**Lines**: L1558–L1632

Every WiFi and BT device is normalized into a flat **profile dict**:

```python
profile = {
    "mac":          "AA:BB:CC:DD:EE:FF",
    "type":         "wifi" | "bt",
    "oui":          "AA:BB:CC",         # First 3 octets
    "is_random":    True | False,       # LA bit check
    "rssi_median":  -67.0,              # Median of RSSI history
    "name":         "iPhone-John",      # Device/friendly name
    "pnl_hash":     "a3f7b2c1e9d4f083", # PNL fingerprint hash
    "pnl_ssids":    ["HomeWiFi", ...],  # Directed probe SSIDs
    "ssids":        ["network1", ...],  # All probed SSIDs
    "manufacturer": "Apple, Inc.",
    "device_name":  "iPhone 15",
    "sightings":    142,
}
```

### MAC Randomization Detection

```python
@staticmethod
def _is_random_mac(mac: str) -> bool:
    first_octet = int(mac.split(":")[0], 16)
    return bool(first_octet & 0x02)  # LA bit set = randomized
```

### RSSI Median Calculation

```python
@staticmethod
def _median(vals: list[float]) -> float:
    s = sorted(vals)
    n = len(s)
    if n == 0: return 0.0
    if n % 2: return s[n // 2]
    return (s[n // 2 - 1] + s[n // 2]) / 2
```

---

## 6. Phase 2: Manufacturer/OUI Grouping + RSSI Sub-Clustering

**Lines**: L1641–L1679

### Algorithm

1. **Separate** devices into `non_random` (real OUI) and `random` (LA bit set)
2. **Group** non-random by OUI prefix (first 3 octets)
3. **Sub-cluster** each OUI group by RSSI using `_rssi_band_cluster()`

```
All Devices
    ├── Non-Random (real OUI)
    │   ├── OUI "04:21:44" (Harman)
    │   │   ├── RSSI band 1: [-42 dBm]  → manufacturer cluster
    │   │   └── RSSI band 2: [-78 dBm]  → manufacturer_rssi cluster
    │   ├── OUI "B8:27:EB" (Raspberry Pi)
    │   │   └── RSSI band 1: [-55, -57] → manufacturer cluster
    │   └── ...
    └── Random (LA bit set)
        ├── random_wifi → Phase 3
        └── random_bt   → Phase 3b
```

### Cluster Type Assignment

| Scenario | Cluster Type |
|----------|-------------|
| Single RSSI band for OUI group | `"manufacturer"` |
| Multiple RSSI bands for same OUI | `"manufacturer_rssi"` |

### Why RSSI Sub-Clustering Within Vendor?

Two Apple devices from the same OUI can be at very different distances.
Without RSSI banding, they'd be incorrectly merged into one cluster.
As the gap tightens (20 → 1 dBm), even devices with 2 dBm difference
get separated.

---

## 7. Phase 3: PNL Fingerprint Grouping (Randomised WiFi)

**Lines**: L1681–L1726

Randomised WiFi MACs can't be grouped by OUI (the OUI is fake). Instead,
use the **Preferred Network List (PNL)** fingerprint:

### Step 1: Exact PNL Hash Match

Devices with identical PNL hashes (SHA-256 of sorted directed SSIDs) are
almost certainly the same physical device using different randomized MACs.

```python
pnl_groups = defaultdict(list)
for dev in random_wifi:
    if dev["pnl_hash"]:
        pnl_groups[dev["pnl_hash"]].append(dev)
```

→ Cluster type: `"pnl_match"`

### Step 2: PNL Jaccard Overlap

Remaining devices compared using Jaccard similarity on directed SSID sets.
Groups with Jaccard ≥ 0.50 are clustered:

$$J(A, B) = \frac{|\text{SSIDs}_A \cap \text{SSIDs}_B|}{|\text{SSIDs}_A \cup \text{SSIDs}_B|}$$

→ Cluster type: `"pnl_overlap"`

### Step 3: Singletons

Remaining randomised MACs with no PNL match become singleton clusters.

→ Cluster type: `"randomised"`

---

## 8. Phase 3b: BT Device Grouping

**Lines**: L1728–L1766

BLE devices don't probe SSIDs, so PNL doesn't apply. Instead:

### Step 1: Name-Based Grouping

BLE devices advertising the same name are grouped:

```python
bt_name_groups = defaultdict(list)
for dev in random_bt:
    if dev["name"]:
        bt_name_groups[dev["name"].lower()].append(dev)
```

→ Cluster type: `"bt_name"`

### Step 2: Unnamed BT RSSI Sub-Clustering

Unnamed random BT devices grouped by RSSI band using `gap + 4` dBm:

```python
bands = self._rssi_band_cluster(unnamed_bt, gap + 4)
```

→ Cluster type: `"bt_rssi"`

---

## 9. Phase 4: WiFi↔BT Cross-Link Merging

**Lines**: L1769 → `_cross_link_wifi_bt()` at L1907–L2008

### Goal

Merge a WiFi cluster with a BT cluster if they likely represent the same
physical device (e.g., a phone's WiFi radio and its BLE advertisements).

### Cross-Link Score Components

| Signal | Weight | Algorithm |
|--------|--------|-----------|
| **OUI match** | 0.35 | Both clusters share at least one non-random OUI prefix |
| **RSSI proximity** | 0.25 | $1 - |\Delta_{\text{RSSI}}| / (\text{gap} + 4)$ (clamped ≥ 0) |
| **Name match** | 0.30 | `SequenceMatcher.ratio() ≥ 0.80` on any name pair |

### Merge Decision

```python
score = oui_score * 0.35 + rssi_score * 0.25 + name_score * 0.30
if score >= WIFI_BT_LINK_THRESHOLD:  # 0.50
    merged_cluster = wifi_cluster ∪ bt_cluster
```

→ Cluster type: `"cross_linked"`

---

## 10. Phase 5: Cross-Vendor PNL Merging

**Lines**: L1772 → `_cross_vendor_merge()` at L2010

### Goal

Merge clusters from different OUI vendors if they share an identical PNL
hash or exact name — indicating the same user with multiple devices from
different manufacturers.

### Merge Conditions

1. **Identical PNL hash** across clusters → Jaccard ≥ `CROSS_VENDOR_PNL_THRESHOLD` (0.70)
2. **Exact name match** (case-insensitive) across clusters

→ Cluster type: `"pnl_cross_vendor"`

---

## 11. Phase 6: Finalization — Scoring, Identification, Persistence

**Lines**: L1775–L1818

1. **Score confidence** — Each cluster gets a confidence value (see §14)
2. **Preserve identifications** — Previously identified/renamed clusters
   retain their labels across recomputation
3. **Update RSSI profiles** — Track RSSI centroid history per cluster
4. **Increment step** — `_correlation_step += 1`
5. **Save to disk** — Atomic JSON write

---

## 12. 9 Cluster Types

| Type | Created In | Source Signal | Meaning |
|------|-----------|---------------|---------|
| `manufacturer` | Phase 2 | OUI + RSSI | Same vendor, single RSSI band |
| `manufacturer_rssi` | Phase 2 | OUI + RSSI | Same vendor, distinct RSSI bands |
| `pnl_match` | Phase 3 | PNL hash | Identical probe fingerprint (near-certain same device) |
| `pnl_overlap` | Phase 3 | PNL Jaccard | Overlapping but not identical probe lists |
| `randomised` | Phase 3 | None | Singleton randomised MAC (no match) |
| `bt_name` | Phase 3b | BLE name | Multiple BT MACs with same advertised name |
| `bt_rssi` | Phase 3b | RSSI band | Unnamed random BT grouped by signal proximity |
| `cross_linked` | Phase 4 | WiFi↔BT score | WiFi cluster merged with BT cluster |
| `pnl_cross_vendor` | Phase 5 | PNL hash | Different vendor clusters with same fingerprint |

---

## 13. Cluster ID Naming Convention

| Prefix | Meaning | Example |
|--------|---------|---------|
| `mfr-` | Manufacturer/OUI cluster | `mfr-04:21:44:BB:12:2B` |
| `pnl-` | PNL exact hash match | `pnl-a3f7b2c1e9d4f083` |
| `pnlj-` | PNL Jaccard overlap | `pnlj-E2:CF:61:F7:4E:16` |
| `rand-` | Randomised singleton | `rand-33:42:05:69:AE:8B` |
| `btn-` | BT name group | `btn-johns-airpods` |
| `btr-` | BT RSSI band | `btr-CC:DD:EE:FF:00:11` |
| `xlink-` | Cross-linked WiFi↔BT | `xlink-mfr-04:21:44-btn-jbl` |
| `pnlxv-` | PNL cross-vendor merge | `pnlxv-a3f7b2c1e9d4f083` |

---

## 14. Confidence Scoring

**Lines**: L2238–L2278

### Singletons

Fixed confidence: **0.15** (low — single observation, no corroboration).

### Multi-Member Clusters

$$\text{confidence} = \min\left(1.0,\; \bar{s} \cdot 0.4 + s_{\max} \cdot 0.2 + \beta_{\text{type}} + \beta_{\text{rssi}}\right)$$

Where:
- $\bar{s}$ = average intra-cluster link score (from `_score_pair`)
- $s_{\max}$ = maximum link score
- $\beta_{\text{type}}$ = cluster type bonus
- $\beta_{\text{rssi}} = 0.15 \times (1 - \min(\text{spread}, 30) / 30)$

### Type Bonuses

| Cluster Type | Bonus $\beta_{\text{type}}$ | Rationale |
|-------------|--------------------------|-----------|
| `pnl_match` | 0.25 | Strongest evidence (identical fingerprint) |
| `pnl_cross_vendor` | 0.20 | Cross-vendor same fingerprint |
| `pnl_overlap` | 0.15 | Partial fingerprint match |
| `cross_linked` | 0.10 | WiFi↔BT multi-signal match |
| `manufacturer_rssi` | 0.10 | OUI + distance correlation |
| `bt_name` | 0.10 | Name-based grouping |
| `manufacturer` | 0.05 | OUI only (many false positives possible) |
| `bt_rssi` | 0.05 | RSSI only (weak signal) |
| `randomised` | 0.00 | No evidence (singleton) |

---

## 15. WiFi↔BT Cross-Link Scoring Detail

**Lines**: L1920–L2008

### Score Function

```python
def _compute_wifi_bt_score(wifi_cluster, bt_cluster, rssi_gap):
    score = 0.0
    reasons = []

    # OUI match (0.35) — any non-random OUI shared
    wifi_ouis = {m["oui"] for m in wifi_cluster if not m["is_random"]}
    bt_ouis = {m["oui"] for m in bt_cluster if not m["is_random"]}
    if wifi_ouis & bt_ouis:
        score += 0.35
        reasons.append("shared_oui")

    # RSSI proximity (0.25)
    wifi_rssi = median([m["rssi_median"] for m in wifi_cluster])
    bt_rssi = median([m["rssi_median"] for m in bt_cluster])
    delta = abs(wifi_rssi - bt_rssi)
    bt_tolerance = rssi_gap + 4
    if delta < bt_tolerance:
        score += 0.25 * (1 - delta / bt_tolerance)
        reasons.append(f"rssi_Δ{delta:.0f}")

    # Name match (0.30) — SequenceMatcher ≥ 0.80
    for wm in wifi_cluster:
        for bm in bt_cluster:
            if wm["name"] and bm["name"]:
                ratio = SequenceMatcher(None, wm["name"].lower(),
                                             bm["name"].lower()).ratio()
                if ratio >= 0.80:
                    score += 0.30
                    reasons.append("name_match")
                    break

    return score, reasons
```

---

## 16. PNL Jaccard Clustering Detail

**Lines**: L1860–L1905

### Algorithm

```python
@staticmethod
def _pnl_jaccard_cluster(devices, pnl_engine, threshold=0.50):
    grouped, ungrouped = [], list(devices)
    while ungrouped:
        seed = ungrouped.pop(0)
        group = [seed]
        remaining = []
        for dev in ungrouped:
            jaccard = pnl_engine.compute_pnl_similarity(
                seed["mac"], dev["mac"])
            if jaccard >= threshold:
                group.append(dev)
            else:
                remaining.append(dev)
        if len(group) > 1:
            grouped.append(group)
        else:
            ungrouped = remaining
    return grouped, ungrouped
```

### Jaccard Similarity

$$J(A, B) = \frac{|A \cap B|}{|A \cup B|}$$

Where $A$, $B$ are sets of **directed-only** SSIDs. Directed probes are
more reliable than broadcast/wildcard probes because they indicate networks
the device has **actually joined**.

---

## 17. RSSI Band Sub-Clustering Detail

**Lines**: L1835–L1858

### Algorithm

```python
@staticmethod
def _rssi_band_cluster(devices: list[dict], gap: float) -> list[list[dict]]:
    if not devices:
        return []
    sorted_devs = sorted(devices, key=lambda d: d["rssi_median"])
    bands = [[sorted_devs[0]]]
    for dev in sorted_devs[1:]:
        if abs(dev["rssi_median"] - bands[-1][-1]["rssi_median"]) > gap:
            bands.append([dev])
        else:
            bands[-1].append(dev)
    return bands
```

### Example at Different Convergence Steps

Devices at [-42, -45, -67, -70, -78]:

**Step 0 (gap = 20.0 dBm)**:
```
All in one band: [-78, -70, -67, -45, -42]  (max gap = 22, but sequential < 20)
→ 1 cluster
```

**Step 10 (gap = 8.3 dBm)**:
```
Band 1: [-78, -70, -67]  ← sequential gaps 8, 3 (both ≤ 8.3)
Band 2: [-45, -42]       ← 22 dBm gap from -67
→ 2 clusters
```

**Step 36 (gap = 1.0 dBm — converged)**:
```
Band 1: [-78]    ← 8 dBm from next
Band 2: [-70]    ← 3 dBm from next
Band 3: [-67]    ← 22 dBm from next
Band 4: [-45]    ← 3 dBm from next
Band 5: [-42]
→ 5 singleton clusters
```

---

## 18. Cluster Metadata & Evidence Links

**Lines**: L2096–L2189

Each cluster is a rich metadata object:

```json
{
    "cluster_id":       "mfr-04:21:44:BB:12:2B",
    "cluster_type":     "manufacturer",
    "label":            "JBL Charge 4",
    "grouping_reason":  "Vendor: 04:21:44 (Harman)",
    "identified":       false,
    "confidence":       0.59,
    "member_count":     2,
    "total_members":    2,
    "members":          [],
    "links":            [],
    "all_macs":         ["04:21:44:BB:12:2B"],
    "wifi_macs":        [],
    "bt_macs":          [],
    "ssids":            [],
    "probed_ssids":     [],
    "total_sightings":  764,
    "alert_count":      48,
    "alerts":           [],
    "all_ignored":      false,
    "ignored_count":    0,
    "rssi_summary":     {"avg": -42.0, "max": -42.0, "min": -42.0, "spread": 0.0},
    "addr_types":       {"cluster_trackability": "high", "has_public_address": true},
    "pnl_match":        {"has_pnl_match": false}
}
```

### Evidence Links

Each link records **why** two cluster members are correlated:

```json
{
    "from": "04:21:44:BB:12:2B",
    "to":   "04:21:44:BB:12:2C",
    "score": 0.82,
    "reasons": ["same_oui", "rssi_Δ3", "same_manufacturer"]
}
```

---

## 19. Cluster Identification & Naming

### Via API

| Action | Method | Path | Effect |
|--------|--------|------|--------|
| Identify | POST | `/api/correlations/identify` | Set label + add all MACs to ignore |
| Rename | POST | `/api/correlations/rename` | Set label only |
| Un-identify | POST | `/api/correlations/unidentify` | Remove from ignore + clear label |
| Recompute | POST | `/api/correlations/recompute` | Full re-run, returns `{"ok": true, "clusters": N}` |

---

## 20. Persistence & State Management

### File: `signal_correlations.json`

```json
{
    "clusters": {},
    "step": 36,
    "rssi_profiles": {}
}
```

### Survival Across Restarts

| State | Persisted | Behavior on Restart |
|-------|-----------|-------------------|
| Clusters | ✅ | Restored — no data loss |
| Correlation step | ✅ | Continues from saved step |
| RSSI profiles | ✅ | Centroid history preserved |
| Identifications | ✅ (in cluster dict) | Names/labels preserved |
| Evidence links | Recomputed | Regenerated on first `correlate()` |

---

## 21. Recomputation Strategy

### Triggered By

1. **Periodic** — Every ~60s during housekeeping in scanner_thread
2. **Manual** — `POST /api/correlations/recompute`
3. **On restart** — Loaded from persistence, first recompute on next cycle

### Full Cycle

```
1. Gather all WiFi devices from fingerprint_db + tracker
2. Gather all BT devices from bt_tracker
3. Phase 1: Build unified profiles
4. Phase 2: Manufacturer/OUI → RSSI sub-cluster
5. Phase 3: PNL fingerprint grouping (random WiFi)
6. Phase 3b: BT name grouping + RSSI sub-cluster (random BT)
7. Phase 4: WiFi↔BT cross-link merging
8. Phase 5: Cross-vendor PNL merging
9. Phase 6: Score confidence, preserve identifications
10. Increment convergence step
11. Emit cluster updates via SocketIO
12. Save to signal_correlations.json
```

---

## 22. Performance Characteristics

| Metric | Value |
|--------|-------|
| Typical device count | 50–200 WiFi + 20–50 BT |
| Clusters produced | 300–400 (mostly singletons) |
| Phase 2 complexity | $O(n)$ — linear group/sort |
| Phase 3 (PNL) | $O(k^2)$ for $k$ randomised MACs |
| Phase 4 (cross-link) | $O(w \times b)$ for $w$ WiFi, $b$ BT clusters |
| Phase 5 (cross-vendor) | filtered by PNL hash → effectively $O(c)$ |
| Wall time on Pi 5 | 100–500ms |
| Memory | ~2MB for cluster dict + profiles |

---

## 23. Convergence Timeline

| Step | Time (~) | WiFi Gap | BT Gap | State |
|------|----------|----------|--------|-------|
| 0 | 0 min | 20.0 dBm | 24.0 dBm | Initial (permissive) |
| 3 | 3 min | 15.8 dBm | 19.8 dBm | Early narrowing |
| 5 | 5 min | 13.1 dBm | 17.1 dBm | Narrowing |
| 10 | 10 min | 8.3 dBm | 12.3 dBm | Moderate |
| 15 | 15 min | 5.5 dBm | 9.5 dBm | Tightening |
| 20 | 20 min | 3.5 dBm | 7.5 dBm | Near-target |
| 25 | 25 min | 2.3 dBm | 6.3 dBm | Close |
| 30 | 30 min | 1.6 dBm | 5.6 dBm | Near-converged |
| 36 | 36 min | 1.0 dBm | 5.0 dBm | **Converged** ✓ |
| 50+ | 50+ min | ~1.0 dBm | ~5.0 dBm | At target |

---

## 24. Tuning Guide

### RSSI Gap Parameters

| Parameter | Increase → | Decrease → |
|-----------|-----------|-----------|
| `RSSI_GAP_INITIAL` | More permissive start | Tighter from start |
| `RSSI_GAP_TARGET` | Looser final grouping | More clusters at convergence |
| `RSSI_GAP_DECAY` | Slower convergence | Faster convergence |

### Cross-Protocol Thresholds

| Parameter | Increase → | Decrease → |
|-----------|-----------|-----------|
| `WIFI_BT_LINK_THRESHOLD` | Fewer WiFi↔BT merges | More aggressive merges |
| `CROSS_VENDOR_PNL_THRESHOLD` | Fewer cross-vendor merges | More linking |

### Troubleshooting

| Symptom | Likely Cause | Solution |
|---------|-------------|---------|
| Everything in one cluster | Target too loose | Lower `RSSI_GAP_TARGET` |
| Too many singletons | Target too tight | Raise `RSSI_GAP_TARGET` |
| WiFi and BT never link | Threshold too high | Lower `WIFI_BT_LINK_THRESHOLD` |
| Wrong cross-vendor merges | PNL threshold too low | Raise `CROSS_VENDOR_PNL_THRESHOLD` |

---

## 25. Deprecated: Union-Find (Pre-2026-02-08)

The previous engine (commit `ce7b49d` and earlier) used **pairwise 7-signal
scoring** with **union-find clustering** and **damped oscillatory convergence**.

### Why It Was Replaced

1. **Single mega-cluster** — With 87 dBm RSSI tolerance and OUI-only grouping,
   200+ devices collapsed into 1 cluster
2. **$O(n^2)$ scaling** — Pairwise scoring of all MAC pairs (~20,000 pairs)
3. **No semantic types** — All clusters looked the same
4. **Oscillation confusion** — The $|\cos(n\theta)|$ term caused periodic
   relaxation that un-split previously separated clusters

### Old 7-Signal Weights (for reference)

| Signal | Weight | Status |
|--------|--------|--------|
| OUI Match | 0.10 | Replaced by Phase 2 OUI grouping |
| Probe SSID | 0.15 | Replaced by Phase 3 PNL clustering |
| PNL Fingerprint | 0.25 | Replaced by Phase 3 exact hash match |
| Temporal Proximity | 0.10 | Removed (too noisy) |
| RSSI Proximity | 0.25 | Replaced by RSSI band sub-clustering |
| Name Similarity | 0.10 | Used in Phase 4 cross-linking |
| Address Type | 0.05 | Used in cluster metadata |

The `_score_pair` method still uses a subset of these for intra-cluster
evidence scoring (confidence calculation), but they no longer drive
the primary clustering.

---

*signals-correlation-engine v2.0 | 2026-02-08 | Creeper Sweeper*
*Major rewrite: union-find → multi-dimensional clustering*
