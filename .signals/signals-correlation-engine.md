# Signal Correlation Engine — Algorithm Deep Dive

> **Complete technical reference for the 7-signal weighted correlation engine,
> damped oscillatory RSSI convergence, union-find clustering, and PNL
> fingerprint matching.**
>
> This is the core algorithm that links WiFi and BLE observations from the
> same physical device — even when the device uses MAC randomization.
>
> **Implementation**: `SignalCorrelator` class in `webapp/app.py`

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [7-Signal Scoring Model](#2-7-signal-scoring-model)
3. [Signal 1: OUI Vendor Match](#3-signal-1-oui-vendor-match)
4. [Signal 2: Probe SSID Overlap](#4-signal-2-probe-ssid-overlap)
5. [Signal 3: PNL Fingerprint Similarity](#5-signal-3-pnl-fingerprint-similarity)
6. [Signal 4: Temporal Proximity](#6-signal-4-temporal-proximity)
7. [Signal 5: RSSI Proximity with Damped Oscillatory Convergence](#7-signal-5-rssi-proximity-with-damped-oscillatory-convergence)
8. [Signal 6: Name Similarity](#8-signal-6-name-similarity)
9. [Signal 7: Address Type Matching](#9-signal-7-address-type-matching)
10. [Union-Find Clustering](#10-union-find-clustering)
11. [Convergence Dynamics](#11-convergence-dynamics)
12. [Cluster Identification & Naming](#12-cluster-identification--naming)
13. [Cross-Protocol Correlation (WiFi ↔ BLE)](#13-cross-protocol-correlation-wifi--ble)
14. [Tuning & Threshold Selection](#14-tuning--threshold-selection)
15. [Persistence & State Management](#15-persistence--state-management)
16. [Recomputation Strategy](#16-recomputation-strategy)

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
3. **No shared identifier** — There's no guaranteed common field between WiFi and BLE
4. **Privacy features** — Modern OSes actively try to prevent exactly this kind of linking
5. **Environmental noise** — Many devices in proximity share similar RSSI, channels, timing

### Our Approach

Use **multiple weak signals** that individually are insufficient but
collectively create a strong correlation:

```
Individual signal: 60% confident
7 signals combined: 95%+ confident (when all agree)
```

---

## 2. 7-Signal Scoring Model

### Weighted Sum Formula

$$\text{Score}(A, B) = \sum_{i=1}^{7} w_i \cdot s_i(A, B)$$

Where each signal $s_i \in [0, 1]$ and weights $w_i$ sum to 1.0:

| # | Signal | Weight $w_i$ | Rationale |
|---|--------|-------------|-----------|
| 1 | OUI Vendor Match | 0.10 | Same manufacturer = weak link |
| 2 | Probe SSID Overlap | 0.15 | Shared known networks = moderate |
| 3 | PNL Fingerprint | 0.25 | Unique network fingerprint = strong |
| 4 | Temporal Proximity | 0.10 | Co-occurrence = weak (many devices overlap) |
| 5 | RSSI Proximity | 0.25 | Same distance = strong (with convergence) |
| 6 | Name Similarity | 0.10 | String matching on names = moderate |
| 7 | Address Type | 0.05 | Same type = very weak |

### Why These Weights?

- **PNL (0.25)** and **RSSI (0.25)** are strongest because they're hardest to
  fake and most specific. A device's probe list is unique; its distance to
  the sensor is unique.
- **OUI (0.10)** and **Temporal (0.10)** are weakest because many devices
  share the same vendor, and many devices are present simultaneously.
- **Name (0.10)** is moderate — helpful when present but often empty.
- **Address Type (0.05)** is minimal — useful for BLE but low specificity.

---

## 3. Signal 1: OUI Vendor Match

### Algorithm

```python
def _oui_match_score(self, mac_a: str, mac_b: str) -> float:
    oui_a = mac_a[:8].upper()  # "AA:BB:CC"
    oui_b = mac_b[:8].upper()
    return 1.0 if oui_a == oui_b else 0.0
```

### Interpretation

| Scenario | Score | Reasoning |
|----------|-------|-----------|
| Same OUI (Apple:Apple) | 1.0 | Same manufacturer, possible same device |
| Different OUI | 0.0 | Different manufacturers unlikely same device |
| Cross-protocol same vendor | 1.0 | WiFi and BLE from same chipset vendor |

### Limitations

- Apple alone has ~200 OUI prefixes. Many devices share OUIs.
- MAC randomization uses locally-administered addresses (LA bit set) which
  don't have real OUIs.
- WiFi and BLE on the same phone often use **different** chipsets with
  different OUIs.

---

## 4. Signal 2: Probe SSID Overlap

### Algorithm

Jaccard similarity of probed SSID sets:

$$s_{\text{probe}} = \frac{|\text{SSIDs}_A \cap \text{SSIDs}_B|}{|\text{SSIDs}_A \cup \text{SSIDs}_B|}$$

```python
def _probe_overlap_score(self, mac_a: str, mac_b: str) -> float:
    ssids_a = set(self._get_probed_ssids(mac_a))
    ssids_b = set(self._get_probed_ssids(mac_b))
    if not ssids_a or not ssids_b:
        return 0.0
    intersection = ssids_a & ssids_b
    union = ssids_a | ssids_b
    return len(intersection) / len(union) if union else 0.0
```

### Interpretation

| Overlap | Score | Meaning |
|---------|-------|---------|
| Identical SSID sets | 1.0 | Almost certainly same device |
| 3 of 5 shared | 0.6 | Strong correlation |
| 1 of 10 shared | 0.1 | Weak — could be neighbors |
| No overlap | 0.0 | No evidence of link |

### Strengths

- Probe lists are **highly device-specific** — the combination of
  networks a device has joined is quasi-unique.
- Even with MAC randomization, probed SSIDs leak the device's identity.
- Effective even cross-protocol when BLE device names contain SSID hints.

---

## 5. Signal 3: PNL Fingerprint Similarity

### Algorithm

Uses the PNL Engine's Jaccard similarity on **directed-only** probes
(ignoring broadcast and wildcard probes):

```python
def _pnl_similarity_score(self, mac_a: str, mac_b: str) -> float:
    similarity = pnl_engine.compute_pnl_similarity(mac_a, mac_b)
    return similarity  # Already 0.0-1.0
```

### PNL Hash

```python
pnl_hash = sha256("|".join(sorted(directed_ssids))).hexdigest()[:16]
```

If `pnl_hash_a == pnl_hash_b`, the devices have **identical** directed
probe sets — extremely strong evidence of same device.

### Why Separate from Probe Overlap?

| Feature | Probe Overlap (Signal 2) | PNL Similarity (Signal 3) |
|---------|--------------------------|---------------------------|
| SSIDs used | All probed SSIDs | Directed probes only |
| Algorithm | Raw Jaccard | PNL engine Jaccard + hash |
| Strength | Moderate (includes noise) | Strong (targeted only) |
| Cross-MAC | Per-MAC comparison | Per-MAC + group matching |

Directed probes are more intentional — they indicate networks the device
has **actually joined**, not just heard. This makes PNL a stronger signal.

---

## 6. Signal 4: Temporal Proximity

### Algorithm

Measures whether two MACs are seen within the same time window:

```python
def _temporal_proximity_score(self, mac_a: str, mac_b: str) -> float:
    range_a = (self._first_seen(mac_a), self._last_seen(mac_a))
    range_b = (self._first_seen(mac_b), self._last_seen(mac_b))

    overlap_start = max(range_a[0], range_b[0])
    overlap_end = min(range_a[1], range_b[1])

    if overlap_start > overlap_end:
        return 0.0  # No temporal overlap

    overlap_duration = overlap_end - overlap_start
    total_duration = max(range_a[1], range_b[1]) - min(range_a[0], range_b[0])
    return overlap_duration / total_duration if total_duration > 0 else 0.0
```

### Interpretation

| Scenario | Score | Meaning |
|----------|-------|---------|
| Perfect overlap (same arrival/departure) | 1.0 | Strong co-location |
| 80% overlap | 0.8 | Likely same visit window |
| Small overlap | 0.1-0.3 | Could be coincidence |
| No overlap | 0.0 | Different time periods |

---

## 7. Signal 5: RSSI Proximity with Damped Oscillatory Convergence

### Core Concept

If two observations come from the same physical device, they should have
**similar RSSI** values (same distance to the sensor). The tolerance for
"similar" **tightens over time** as the system accumulates observations.

### Damped Oscillatory Tolerance Function

$$\Delta(n) = \Delta_{\text{target}} + (\Delta_0 - \Delta_{\text{target}}) \cdot r^n \cdot |\cos(n \cdot \theta)|$$

| Parameter | WiFi Value | BT Value | Meaning |
|-----------|-----------|----------|---------|
| $\Delta_0$ | 25 dBm | 35 dBm | Initial tolerance (permissive) |
| $\Delta_{\text{target}}$ | 8 dBm | 12 dBm | Final tolerance (strict) |
| $r$ | 0.85 | 0.85 | Decay rate per step |
| $\theta$ | 0.7 | 0.7 | Oscillation frequency |
| $n$ | step counter | step counter | Incremented each recompute |

### Convergence Visualization

```
Tolerance (dBm)
   35 │ ●
      │  ●
   30 │   ○        ← BT (wider tolerance)
      │    ○
   25 │ ●   ○
      │  ●   ○  ●
   20 │   ●   ○  ○
      │        ●  ○
   15 │    ←───●───○──── oscillatory decay
      │           ●
   12 │ ─ ─ ─ ─ ─ ─ ─ ─ ← BT target
      │              ●
   10 │               ●
    8 │ ─ ─ ─ ─ ─ ─ ─ ─ ← WiFi target
      └───┬───┬───┬───┬──→ recompute step (n)
          5  10  15  20
```

### Why Oscillatory (not purely exponential)?

The $|\cos(n \cdot \theta)|$ term creates **periodic relaxation** of the
tolerance. This is intentional:

1. **Prevents premature lock-in** — If the tolerance only shrinks, early
   errors become permanent (a mismatched pair that barely passed at step 5
   can never be reconsidered).
2. **Allows re-evaluation** — Periodic relaxation lets the engine reconsider
   borderline pairs. As the overall trend converges, only **true matches**
   will consistently score above the relaxing threshold.
3. **Models real RSSI variance** — WiFi/BLE signal strength fluctuates due
   to multipath, interference, and movement. An oscillating tolerance better
   models this real-world behavior than a monotonic decay.

### RSSI Score Calculation

```python
def _rssi_proximity_score(self, rssi_a: int, rssi_b: int) -> float:
    delta = abs(rssi_a - rssi_b)
    tolerance = self._damped_tolerance(
        self._step,
        target=self._rssi_tolerance_wifi,  # 8 or 12
        initial=25,  # or 35 for BT
        decay=0.85,
        theta=0.7,
    )
    if delta <= tolerance:
        return 1.0 - (delta / tolerance)  # Linear decay within tolerance
    return 0.0
```

---

## 8. Signal 6: Name Similarity

### Algorithm

```python
def _name_similarity_score(self, mac_a: str, mac_b: str) -> float:
    name_a = self._get_name(mac_a)  # friendly_name or device_name
    name_b = self._get_name(mac_b)

    if not name_a or not name_b:
        return 0.0

    # Exact match
    if name_a.lower() == name_b.lower():
        return 1.0

    # Substring containment
    if name_a.lower() in name_b.lower() or name_b.lower() in name_a.lower():
        return 0.7

    # Common prefix (e.g., "John's iPhone" and "John's AirPods")
    common = os.path.commonprefix([name_a.lower(), name_b.lower()])
    if len(common) > 3:
        return 0.5 * len(common) / max(len(name_a), len(name_b))

    return 0.0
```

### Use Cases

| Pair | Score | Reasoning |
|------|-------|-----------|
| "John's iPhone" / "JOHN'S IPHONE" | 1.0 | Case-insensitive exact |
| "John's iPhone" / "John's AirPods" | ~0.35 | Common prefix "John's " |
| "iPhone" / "John's iPhone" | 0.7 | Substring |
| "" / "iPhone" | 0.0 | One missing |

---

## 9. Signal 7: Address Type Matching

### Algorithm

```python
def _address_type_score(self, mac_a: str, mac_b: str) -> float:
    type_a = self._classify_address(mac_a)
    type_b = self._classify_address(mac_b)
    return 1.0 if type_a == type_b else 0.0
```

### Address Types

| Type | Trackability | Score when matched |
|------|-------------|-------------------|
| `global_unique` | Permanent | 1.0 |
| `local_admin` | Rotating | 1.0 |
| `random_static` | Session | 1.0 |
| `public` (BLE) | Permanent | 1.0 |
| Mismatched types | — | 0.0 |

### Rationale

Devices from the same user tend to use similar address strategies. A person
with an iPhone generates `local_admin` WiFi MACs and `resolvable_private`
BLE addresses. If two observations both show `local_admin`, it's a tiny
positive signal.

---

## 10. Union-Find Clustering

### Algorithm

After scoring all MAC pairs, build clusters using union-find (disjoint set):

```python
def build_clusters(self, threshold: float = 0.5) -> list[set]:
    parent = {mac: mac for mac in all_macs}
    rank = {mac: 0 for mac in all_macs}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]  # Path compression
            x = parent[x]
        return x

    def union(x, y):
        rx, ry = find(x), find(y)
        if rx == ry: return
        if rank[rx] < rank[ry]: rx, ry = ry, rx
        parent[ry] = rx
        if rank[rx] == rank[ry]: rank[rx] += 1

    # Merge all pairs above threshold
    for (mac_a, mac_b), score in self._links.items():
        if score >= threshold:
            union(mac_a, mac_b)

    # Extract clusters
    clusters = defaultdict(set)
    for mac in all_macs:
        clusters[find(mac)].add(mac)

    return [c for c in clusters.values() if len(c) > 1]
```

### Complexity

- **Time**: $O(n^2 \cdot k)$ for $n$ MACs and $k$ signals per pair (amortized near-linear with path compression)
- **Space**: $O(n^2)$ for the pairwise score cache (`_links`)

### Cluster Properties

Each cluster object contains:
```json
{
  "id": "cluster-abc123",
  "macs": ["AA:BB:CC:DD:EE:01", "CC:DD:EE:FF:00:11", ...],
  "label": "John's Phone",
  "identified": true,
  "scores": {"AA:BB → CC:DD": 0.82, ...},
  "first_seen": "2026-02-07T10:30:00",
  "last_seen": "2026-02-08T14:22:00",
  "signal_types": {"wifi": 2, "ble": 1}
}
```

---

## 11. Convergence Dynamics

### Step Advancement

```python
def _advance_convergence(self):
    self._step += 1
    self._rssi_tolerance_wifi = self._damped_tolerance(
        self._step, target=8, initial=25, decay=0.85, theta=0.7
    )
    self._rssi_tolerance_bt = self._damped_tolerance(
        self._step, target=12, initial=35, decay=0.85, theta=0.7
    )
```

Called once per housekeeping cycle (~60 seconds).

### Convergence Timeline

| Step | Time (~) | WiFi Tolerance | BT Tolerance | State |
|------|----------|---------------|--------------|-------|
| 0 | 0 min | 25.0 dBm | 35.0 dBm | Exploratory |
| 5 | 5 min | ~16.5 dBm | ~24.5 dBm | Narrowing |
| 10 | 10 min | ~12.2 dBm | ~18.8 dBm | Converging |
| 20 | 20 min | ~9.0 dBm | ~13.5 dBm | Near-target |
| 30 | 30 min | ~8.2 dBm | ~12.3 dBm | Stabilized |
| 50+ | 50+ min | ~8.0 dBm | ~12.0 dBm | At target |

### Why BT Has Wider Tolerance Than WiFi

| Factor | WiFi | BLE |
|--------|------|-----|
| Advertising regularity | High (beacons every 100ms) | Moderate (100-1000ms) |
| RSSI stability | ±3-5 dBm | ±5-10 dBm |
| Multipath effects | Moderate | Higher (shorter wavelength effects on 2.4GHz advertising) |
| Measurement frequency | Every 3s (scan interval) | Every 10s (BT interval) |

BLE RSSI is inherently noisier → wider tolerance needed.

---

## 12. Cluster Identification & Naming

### Via API: Identify Cluster

```http
POST /api/correlations/identify
Content-Type: application/json

{
  "cluster_id": "cluster-abc123",
  "name": "John's Devices"
}
```

This does three things:
1. Sets cluster label to "John's Devices"
2. Adds all cluster MACs to the ignore list
3. Adds all cluster SSIDs to the ignore list

### Via API: Rename Cluster (No Ignore)

```http
POST /api/correlations/rename
Content-Type: application/json

{
  "cluster_id": "cluster-abc123",
  "name": "Guest - Room 3"
}
```

Only sets label — does not modify the ignore list.

### Force Recompute

```http
POST /api/correlations/recompute
```

Resets all scores, re-evaluates all pairs, rebuilds clusters. Useful after
significant changes (new devices, new ignore rules, new names).

---

## 13. Cross-Protocol Correlation (WiFi ↔ BLE)

### Challenge

WiFi and BLE use fundamentally different address spaces and radio parameters.
How does the correlator link them?

### Signals That Work Cross-Protocol

| Signal | WiFi→WiFi | BLE→BLE | WiFi→BLE |
|--------|-----------|---------|----------|
| OUI Match | ✅ | ✅ | ⚠️ (often different chipsets) |
| Probe SSID | ✅ | ❌ (BLE doesn't probe SSIDs) | ❌ |
| PNL | ✅ | ❌ | ❌ |
| Temporal | ✅ | ✅ | ✅ (key cross-protocol signal) |
| RSSI | ✅ | ✅ | ✅ (same distance = same RSSI trend) |
| Name | ✅ | ✅ | ✅ ("John's iPhone" / "John's AirPods") |
| Address Type | ⚠️ | ⚠️ | ⚠️ (different classification schemes) |

### Cross-Protocol Linking Strategy

For WiFi↔BLE, the effective signals are:
1. **Temporal proximity** (0.10) — strongest cross-protocol signal
2. **RSSI proximity** (0.25) — same device = same distance
3. **Name similarity** (0.10) — owner naming patterns

Combined weight: 0.45 out of 1.0, meaning WiFi↔BLE pairs need very strong
scores on these 3 signals to exceed the 0.5 threshold.

This is intentional — cross-protocol correlations should require stronger
evidence than same-protocol ones.

---

## 14. Tuning & Threshold Selection

### Cluster Threshold

Default: **0.50** (halfway through 0-1 score range).

| Threshold | Effect | Risk |
|-----------|--------|------|
| 0.30 | More clusters, more merging | False positives (unrelated devices merged) |
| 0.50 | Balanced (default) | Moderate false positive/negative rate |
| 0.70 | Fewer, higher-confidence clusters | Misses legitimate correlations |
| 0.90 | Only near-certain matches | Almost no cross-protocol linking |

### Weight Adjustment Guidelines

| Change | Effect |
|--------|--------|
| Increase PNL weight | Better same-device detection, worse cross-protocol |
| Increase temporal weight | Better for dynamic environments (people coming/going) |
| Increase RSSI weight | Better for static environments, worse with multipath |
| Increase name weight | Better when devices have user-assigned names |

---

## 15. Persistence & State Management

### Persisted State (`signal_correlations.json`)

```json
{
  "links": {
    "AA:BB:CC:DD:EE:01|CC:DD:EE:FF:00:11": 0.78
  },
  "clusters": [
    {
      "id": "cluster-abc123",
      "macs": ["AA:BB:CC:DD:EE:01", "CC:DD:EE:FF:00:11"],
      "label": "John's Devices",
      "identified": true
    }
  ],
  "identifications": {
    "cluster-abc123": "John's Devices"
  },
  "step": 42,
  "rssi_tolerance_wifi": 8.3,
  "rssi_tolerance_bt": 12.5
}
```

### Survival Across Restarts

- Pairwise scores (`_links`) are persisted
- Cluster assignments are persisted
- Convergence step is persisted → continues from where it left off
- Identifications (names) are persisted
- RSSI tolerances are persisted → no regression on restart

---

## 16. Recomputation Strategy

### Triggered By

1. **Periodic** — Every ~60s during housekeeping
2. **Manual** — `POST /api/correlations/recompute`
3. **On restart** — Loaded from persistence, no recompute needed

### Recompute Cycle

```
1. Gather all known MACs from fingerprint_db + bt_tracker
2. For each pair (A, B):
   a. Compute 7 signal scores
   b. Weighted sum → composite score
   c. Store in _links dict
3. Run union-find clustering on _links ≥ threshold
4. Merge with existing identifications (preserve names)
5. Advance convergence step
6. Emit cluster updates via SocketIO
7. Save to signal_correlations.json
```

### Performance Characteristics

| Metric | Value |
|--------|-------|
| Typical MAC count | 50-200 |
| Pairs evaluated | ~5,000-20,000 |
| Signals per pair | 7 |
| Total computations | ~35,000-140,000 |
| Wall time on Pi 5 | 200-800ms |
| Memory overhead | ~2MB for links dict |

---

*signals-correlation-engine v1.0 | 2026-02 | Creeper Sweeper*
