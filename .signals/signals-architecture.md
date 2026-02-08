# Creeper Sweeper — System Architecture & Detection Pipeline

> **Complete system architecture of the Raspberry Pi surveillance device detector.**
>
> Covers the full detection pipeline from RF capture through alert generation,
> correlation clustering, and real-time dashboard delivery.
>
> **Companion documents**:
> - [Correlation Engine](signals-correlation-engine.md) — 7-signal scoring, convergence, clustering
> - [Webapp API](signals-webapp-api.md) — REST endpoints, WebSocket events
> - [Data Models](signals-data-models.md) — Persistence formats, schemas
> - [Deployment](signals-deployment.md) — Setup, systemd, CI/CD
> - [BT Implementation](signals-bt-implementation.md) — btmgmt PTY fix

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Process Architecture](#2-process-architecture)
3. [Detection Pipeline](#3-detection-pipeline)
4. [WiFi Detection Path](#4-wifi-detection-path)
5. [Bluetooth Detection Path](#5-bluetooth-detection-path)
6. [GPS Integration](#6-gps-integration)
7. [Triangulation Engine](#7-triangulation-engine)
8. [PNL Fingerprinting Engine](#8-pnl-fingerprinting-engine)
9. [Signal Correlation Engine](#9-signal-correlation-engine)
10. [Alert System](#10-alert-system)
11. [Watch Alert System](#11-watch-alert-system)
12. [Data Persistence Layer](#12-data-persistence-layer)
13. [Real-Time Dashboard Delivery](#13-real-time-dashboard-delivery)
14. [Threading Model](#14-threading-model)
15. [Security Model](#15-security-model)

---

## 1. System Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         CREEPER SWEEPER                                   │
│                    Surveillance Device Detector                           │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐   │
│  │   Kismet /   │  │  btmgmt     │  │   gpsd /    │  │  ESP32 Tri-  │   │
│  │  iw scan     │  │  BLE scan   │  │  serial GPS │  │  angulation  │   │
│  │  (wlan1)     │  │  (hci1)     │  │  (ttyACM0)  │  │  Nodes       │   │
│  └──────┬───────┘  └──────┬──────┘  └──────┬──────┘  └──────┬───────┘  │
│         │                  │                │                 │           │
│         ▼                  ▼                ▼                 ▼           │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │                    scanner_thread (app.py)                        │    │
│  │                                                                   │    │
│  │  ┌──────────────────────────────────────────────────────────┐    │    │
│  │  │ Per-Detection Processing Pipeline                         │    │    │
│  │  │                                                           │    │    │
│  │  │  IgnoreList → Surveillance Match → FingerprintDB.record  │    │    │
│  │  │  → PNLEngine.record_probe → SSIDGroupTracker.record      │    │    │
│  │  │  → DetectionTracker.update → AlertHistory.add            │    │    │
│  │  │  → TriangulationEngine.add_observation                   │    │    │
│  │  │  → WatchList.check → SignalCorrelator feeds              │    │    │
│  │  └──────────────────────────────────────────────────────────┘    │    │
│  │                                                                   │    │
│  │  ┌───────────────────────────────┐  ┌────────────────────────┐   │    │
│  │  │ Periodic Housekeeping (~60s)  │  │  SocketIO Emission     │   │    │
│  │  │ • Save all databases          │  │  • detections          │   │    │
│  │  │ • Prune stale entries         │  │  • alert / watch_alert │   │    │
│  │  │ • Recompute correlations      │  │  • bt_devices          │   │    │
│  │  │ • Advance convergence step    │  │  • gps_fix             │   │    │
│  │  └───────────────────────────────┘  └────────────────────────┘   │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │                    Flask + SocketIO Server                        │    │
│  │  • HTTP Basic Auth on all routes                                  │    │
│  │  • ~35 REST API endpoints                                         │    │
│  │  • 11 WebSocket events                                            │    │
│  │  • Eventlet async mode                                            │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │              Browser Dashboard (Vanilla JS + Socket.IO)           │    │
│  │  9 tabs · 4 modals · Live analyzer sidebar · Web Audio alerts    │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
```

### Design Principles

| Principle | Implementation |
|-----------|---------------|
| **Zero external DB** | All state persisted to JSON files with atomic writes |
| **Single process** | Flask + background threads (no message queue, no separate workers) |
| **Real-time first** | SocketIO pushes every scan cycle (3s default) |
| **Cross-protocol** | WiFi and BLE flow through identical pipeline stages |
| **Graceful degradation** | Kismet offline → iw fallback; GPS offline → no location; BT offline → WiFi only |

---

## 2. Process Architecture

### Thread Model

| Thread | Class / Function | Lifecycle | Interval |
|--------|-----------------|-----------|----------|
| **Main** | Flask + SocketIO | Process lifetime | Event-driven |
| **scanner_thread** | `_scanner_thread()` | `daemon=True`, started at `/` first request | `SCAN_INTERVAL` (3s) |
| **bt_scanner** | `BTScanner(Thread)` | `daemon=True`, started by scanner_thread | `BT_SCAN_INTERVAL` (10s) |
| **gps_reader** | `GPSReader(Thread)` | `daemon=True`, started at app init | Continuous (1s poll) |

### Startup Sequence

```
1. load .env (python-dotenv)
2. Initialize Flask app + SocketIO
3. Load persistent state:
   ├── _load_settings()  → settings.json
   ├── IgnoreList()       → ignore_list.json
   ├── FingerprintDB()    → fingerprints.json
   ├── AlertHistory()     → alert_history.json
   ├── SSIDGroupTracker() → ssid_groups.json
   ├── GPSReader()        → starts GPS thread
   ├── DetectionTracker()
   ├── BTScanner()        → (not started yet)
   ├── TriangulationEngine() → triangulation.json
   ├── PNLEngine()        → pnl_profiles.json
   ├── SignalCorrelator() → signal_correlations.json
   └── WatchList()        → watchlist.json
4. Register Flask routes + SocketIO handlers
5. app.run() with eventlet
6. On first HTTP request to /:
   └── scanner_thread starts (daemon)
       └── BTScanner.start() (daemon)
```

---

## 3. Detection Pipeline

The scanner thread runs a continuous loop. Each iteration:

```python
while not _stop_event.is_set():
    cycle_start = time.time()

    # ─── WiFi Detection ────────────────────────────────────────
    wifi_devices = _fetch_wifi_devices()     # Kismet or iw scan
    for dev in wifi_devices:
        _process_detection(dev, phy="wifi")  # Full pipeline

    # ─── Bluetooth Detection ───────────────────────────────────
    bt_active = bt_tracker.get_active(since_seconds=120)
    for bt_dev in bt_active:
        _process_detection(bt_dev, phy="ble")  # Same pipeline

    # ─── GPS ───────────────────────────────────────────────────
    current_fix = gps_reader.get_fix()
    # GPS data attached to each detection during processing

    # ─── Emit to Dashboard ─────────────────────────────────────
    socketio.emit("detections", all_detections)
    socketio.emit("bt_devices", bt_active)
    socketio.emit("gps_fix", current_fix)

    # ─── Periodic Housekeeping (every ~60s) ────────────────────
    if time.time() - last_save > 60:
        _save_all_databases()
        correlator.recompute()
        correlator._advance_convergence()
        _prune_stale()

    # ─── Pace to scan interval ─────────────────────────────────
    elapsed = time.time() - cycle_start
    sleep(max(0, SCAN_INTERVAL - elapsed))
```

### Per-Detection Processing (`_process_detection`)

```
Input: {mac, signal, ssid, device_name, manufacturer, channel, ...}
  │
  ├─ 1. IgnoreList check
  │     → if ignored: mark is_ignored=True, skip alerts
  │
  ├─ 2. Surveillance pattern matching
  │     → OUI prefix match against surveillance_oui.toml
  │     → SSID/name regex match
  │     → Set is_surveillance=True, surveillance_reason
  │
  ├─ 3. FingerprintDB.record()
  │     → Create/update DeviceFingerprint
  │     → Append sighting to ring buffer (max 200)
  │     → Apply friendly name if set
  │
  ├─ 4. PNLEngine processing (WiFi only)
  │     → For each probed_ssid: record_probe(mac, ssid)
  │     → Classify probe type: broadcast / directed / wildcard
  │     → Classify MAC: global_unique / local_admin
  │     → Update PNL hash (SHA-256 of sorted directed SSIDs)
  │
  ├─ 5. SSIDGroupTracker.record_detection()
  │     → Group MAC by SSID with channel/signal stats
  │     → Build event log per group
  │
  ├─ 6. DetectionTracker.update()
  │     → Track first_seen, compute persist_seconds
  │     → Determine alert tier:
  │        New (not seen) → Tier 1
  │        Persist > threshold → Tier 2
  │        Surveillance match → Tier 3
  │     → Return Detection with alert_tier set
  │
  ├─ 7. AlertHistory.add() (if tier > 0)
  │     → Dedup by MAC cooldown
  │     → Append to bounded history (max 1000)
  │     → SocketIO emit("alert", {tier, detection, timestamp})
  │
  ├─ 8. TriangulationEngine.add_observation()
  │     → If GPS valid: create SignalObservation
  │     → Feed into multilateration solver
  │
  ├─ 9. WatchList check → _check_watch_alerts(det_dict)
  │     → Match against all enabled watch entries
  │     → 7 match types: mac, ssid, device_name, friendly_name,
  │       manufacturer, group, correlation
  │     → Respect per-entry cooldown
  │     → SocketIO emit("watch_alert", {...})
  │     → Add Tier 4 alert to history
  │
  └─ 10. Feed into SignalCorrelator
        → Accumulate in _observations for next recompute cycle
```

---

## 4. WiFi Detection Path

### Primary: Kismet REST API

```python
try:
    response = httpx.get(
        f"http://{KISMET_HOST}:{KISMET_PORT}/devices/all_devices.json",
        auth=(KISMET_USERNAME, KISMET_PASSWORD),
        timeout=10,
    )
    devices = response.json()
except:
    devices = _fallback_iw_scan()
```

**Kismet fields extracted**:
- `kismet.device.base.macaddr` → MAC
- `kismet.device.base.name` → device_name
- `kismet.device.base.signal.last_signal` → RSSI
- `kismet.device.base.channel` → channel
- `kismet.device.base.frequency` → frequency
- `kismet.device.base.phyname` → phy type
- `dot11.device.probed_ssid_map` → probed SSIDs  
- `dot11.device.last_beaconed_ssid` → SSID
- `kismet.device.base.manuf` → manufacturer

### Fallback: `iw dev scan`

```bash
sudo iw wlan1 scan
```

Parsed via regex for: BSSID, SSID, signal, channel, frequency.

### Connected SSID Detection

For each detection, the scanner also checks if the device is associated
to a network (useful for identifying "connected" vs "probing" devices):

```python
connected = _detect_connected_ssid(detection)
```

---

## 5. Bluetooth Detection Path

> See [signals-bt-implementation.md](signals-bt-implementation.md) for the
> complete btmgmt PTY fix story.

### Scan Execution

```python
class BTScanner(Thread):
    def run(self):
        while not self._stop_event.is_set():
            devices = self.scan_once()
            self._tracker.update_batch(devices)
            self._stop_event.wait(BT_SCAN_INTERVAL)

    def scan_once(self):
        self._kill_stale_btmgmt()  # Kill orphans
        cmd = f"sudo {BTMGMT_PATH} --index {BT_HCI_INDEX} find -l"
        result = subprocess.run(
            ["script", "-qc", cmd, "/dev/null"],
            capture_output=True, text=True,
            timeout=BT_SCAN_DURATION + 10,
        )
        return parse_btmgmt_output(result.stdout)
```

### BLE Address Classification

```python
def classify_bt_address(mac: str) -> dict:
    """Classify BLE address type from MSB analysis."""
    first_octet = int(mac.split(":")[0], 16)

    if first_octet & 0xC0 == 0xC0:
        return {"type": "random_static", "trackability": "session"}
    elif first_octet & 0xC0 == 0x40:
        return {"type": "resolvable_private", "trackability": "low"}
    elif first_octet & 0xC0 == 0x00:
        if first_octet & 0x02:  # LA bit
            return {"type": "non_resolvable_private", "trackability": "none"}
        else:
            return {"type": "public", "trackability": "permanent"}
    else:
        return {"type": "br_edr", "trackability": "permanent"}
```

### Integration into Full Pipeline

**Before** (broken): BT devices only visible in bt_tracker → BT tab.
**After** (working): BT devices flow through fingerprint_db → tracker → alerts → triangulation → correlation.

```
BT scan → bt_tracker.update_batch()
       → bt_tracker.get_active(since_seconds=120)
       → For each active BT device:
           fingerprint_db.record(device_type="bluetooth")
           tracker.update(phy="ble")
           → Tier 1/2/3 alerts
           tri_engine.add_observation(signal_type="ble")
           _check_watch_alerts(det)
       → correlator receives BT observations for WiFi↔BLE linking
```

---

## 6. GPS Integration

### Dual-Mode GPS Source

```
┌──────────────────┐     ┌──────────────────┐
│  gpsd (preferred) │     │  Serial NMEA     │
│  JSON stream over │     │  /dev/ttyACM0    │
│  localhost:2947   │     │  9600 baud       │
└────────┬─────────┘     └────────┬─────────┘
         │                        │
         ▼                        ▼
    GPSReader thread (continuous 1s poll)
         │
         ▼
    GPSFix dataclass:
    ├── valid: bool
    ├── latitude, longitude: float
    ├── altitude: float
    ├── speed, heading: float
    ├── satellites: int
    ├── hdop: float
    ├── fix_quality: str
    └── timestamp: str
```

### NMEA Parsing

Two sentence types supported:
- **$GPGGA** — Position fix (lat, lon, altitude, satellites, HDOP, fix quality)
- **$GPRMC** — Position + velocity (lat, lon, speed, heading, date/time)

### GPS → Detection Enrichment

Each detection gains:
```python
detection.latitude = current_fix.latitude
detection.longitude = current_fix.longitude
detection.location_label = f"{lat:.6f}, {lon:.6f}"
detection.location_source = "gps"
detection.has_location = True
```

---

## 7. Triangulation Engine

### Architecture

Multi-node RSSI-based geolocation using weighted least-squares.

```
ESP32 Node A ──┐
  (RSSI obs)   │
               ├──→ TriangulationEngine
ESP32 Node B ──┤    ├── rssi_to_distance()
  (RSSI obs)   │    ├── haversine_m()
               │    └── trilaterate()
Pi Local ──────┘         ├── 2 nodes → weighted midpoint
  (RSSI + GPS)           └── ≥3 nodes → WLS pseudo-inverse
```

### Log-Distance Path Loss Model

$$d = 10^{(\text{RSSI}_{\text{ref}} - \text{RSSI}) / (10n)}$$

| Parameter | Value | Source |
|-----------|-------|--------|
| RSSI_ref | -40 dBm | Calibrated at 1m |
| n | 3.0 | Indoor/wooded path-loss exponent |

### Multilateration (≥3 nodes)

Linearize circles around each node, solve via pseudo-inverse:

$$\mathbf{x} = (\mathbf{A}^T \mathbf{W} \mathbf{A})^{-1} \mathbf{A}^T \mathbf{W} \mathbf{b}$$

Where $\mathbf{W} = \text{diag}(1/d_i^2)$ — inverse square distance weighting.

---

## 8. PNL Fingerprinting Engine

### Preferred Network List Fingerprinting

Every WiFi device periodically sends probe requests for known networks.
The set of directed probes forms a unique **fingerprint** of the device
independent of its MAC address.

```
Device probes for: "HomeWiFi", "CoffeeShop", "Work-5G"
                         ↓
PNL Hash = SHA-256(sorted(["CoffeeShop", "HomeWiFi", "Work-5G"]))[:16]
                         ↓
"a3f7b2c1e9d4f083"
```

### Probe Classification

| Type | Detection | Example |
|------|-----------|---------|
| `DIRECTED` | Non-empty SSID, not broadcast | "HomeWiFi" |
| `BROADCAST` | Empty SSID or wildcard | "" |
| `WILDCARD` | Null SSID bytes | \x00\x00 |

### MAC Address Classification

**WiFi MAC** — Check LA bit (bit 1 of first octet):
- `0` → `global_unique` (IEEE assigned OUI, highly trackable)
- `1` → `local_admin` (randomized, rotates periodically)

**BLE Address** — MSB analysis of first octet:
- `0xC0` mask → `random_static` (session-stable, changes on power cycle)
- `0x40` mask → `resolvable_private` (rotates, IRK-resolvable)
- `0x00` mask with no LA → `public` (permanent, IEEE-assigned)
- Others → `non_resolvable_private` (rotates, not resolvable)

### PNL Similarity (Jaccard Index)

$$J(A, B) = \frac{|A \cap B|}{|A \cup B|}$$

Where $A$ and $B$ are sets of directed SSIDs for two MAC addresses.

Match threshold: $J \geq 0.60$ (default).

### Match Groups

Devices with identical PNL hashes are grouped — these are almost certainly
the same physical device using different MAC addresses (randomization).

---

## 9. Signal Correlation Engine

> See [signals-correlation-engine.md](signals-correlation-engine.md) for
> comprehensive algorithm documentation.

### Summary

The `SignalCorrelator` (L1408–L2390 in `app.py`) uses **multi-dimensional
clustering** across 6 phases to link WiFi and BLE observations:

| Phase | Algorithm | Cluster Types Produced |
|-------|-----------|------------------------|
| 2 | OUI grouping → RSSI band sub-clustering | `manufacturer`, `manufacturer_rssi` |
| 3 | PNL hash match → Jaccard overlap | `pnl_match`, `pnl_overlap`, `randomised` |
| 3b | BT name grouping → RSSI sub-clustering | `bt_name`, `bt_rssi` |
| 4 | WiFi↔BT cross-link (OUI+RSSI+name score ≥ 0.50) | `cross_linked` |
| 5 | Cross-vendor PNL merge (Jaccard ≥ 0.70) | `pnl_cross_vendor` |

RSSI tolerance uses **exponential convergence** (no oscillation):
$$\text{gap}(n) = 1.0 + 19.0 \times 0.92^n$$

- WiFi target: **1.0 dBm** · BT target: **5.0 dBm** (WiFi + 4)
- Converges at step 36 (~36 minutes)
- 9 distinct cluster types with semantic meaning
- ~315 clusters from ~250 devices in production

---

## 10. Alert System

### 4-Tier Alert Model

| Tier | Label | Trigger | Color | Sound |
|------|-------|---------|-------|-------|
| 1 | `NEW_DEVICE` | Unknown device first seen | Blue | 660Hz sine beep (0.3s) |
| 2 | `PERSIST` | Device persists > threshold | Orange | Double 880Hz beeps |
| 3 | `SURVEILLANCE` | Known surveillance pattern | Red | 440→1200Hz sawtooth sweep |
| 4 | `WATCH_ALERT` | Watch list match | Green | C5-E5-G5 arpeggio chime |

### Alert Deduplication

- Per-MAC cooldown (configurable, default 60s)
- Persist alerts fire once per threshold crossing
- Watch alerts respect per-entry cooldown (default 300s)
- Alert history bounded to 1000 entries

### Web Audio Generation

All alert sounds are synthesized client-side using the Web Audio API — no
audio files needed:

```javascript
// Tier 3 example: sawtooth siren sweep
const osc = audioCtx.createOscillator();
osc.type = "sawtooth";
osc.frequency.setValueAtTime(440, now);
osc.frequency.linearRampToValueAtTime(1200, now + 0.8);
```

---

## 11. Watch Alert System

Named alerts triggered when specific devices/groups/correlations are detected.

### Match Types (7)

| Type | Field Checked | Use Case |
|------|---------------|----------|
| `mac` | Detection MAC address | Specific device tracking |
| `ssid` | SSID or probed SSIDs | Network tracking |
| `device_name` | BLE/WiFi advertised name | Named device tracking |
| `friendly_name` | User-assigned name | Friendly device tracking |
| `manufacturer` | OUI manufacturer | Vendor-class tracking |
| `group` | SSID group name | SSID group arrival |
| `correlation` | Cluster label | Correlated device cluster |

### Matching Logic

```python
def _check_watch_alerts(det_dict: dict) -> None:
    for entry in watch_list.get_enabled():
        match_type = entry["match_type"]
        match_value = entry["match_value"].lower()

        matched = False
        if match_type == "mac":
            matched = det_dict.get("mac", "").lower() == match_value
        elif match_type == "friendly_name":
            matched = match_value in det_dict.get("friendly_name", "").lower()
        elif match_type == "correlation":
            matched = det_dict["mac"] in _watch_corr_labels.get(match_value, set())
        # ... (other types)

        if matched and entry.cooldown_elapsed():
            socketio.emit("watch_alert", {...})
            alert_history.add(tier=4, ...)
            entry.update_last_fired()
```

---

## 12. Data Persistence Layer

### Atomic Write Pattern

All persistent data uses the **atomic write** pattern to prevent corruption:

```python
def _save(data: dict, path: Path) -> None:
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2, default=str))
    tmp.rename(path)  # Atomic on POSIX
```

### Persistent Files

| File | Update Frequency | Max Size |
|------|-----------------|----------|
| `settings.json` | On user change | ~200B |
| `ignore_list.json` | On user change | ~10KB |
| `fingerprints.json` | Every 60s | ~500KB (5000 devices) |
| `alert_history.json` | Every 60s | ~200KB (1000 entries) |
| `ssid_groups.json` | Every 60s | ~100KB |
| `bt_devices.json` | Every 60s | ~150KB (500 devices) |
| `gps_log.json` | Every 60s | ~500KB (5000 entries) |
| `pnl_profiles.json` | Every 60s | ~300KB (2000 profiles) |
| `triangulation.json` | Every 60s | ~200KB |
| `signal_correlations.json` | Every 60s | ~100KB |
| `watchlist.json` | On user change | ~5KB |

All files stored in `DATA_DIR` (default `~/.local/share/creeper-sweeper/`).

---

## 13. Real-Time Dashboard Delivery

### SocketIO Transport

```
scanner_thread ──emit──→ SocketIO server ──push──→ Browser
                         (eventlet async)          (Socket.IO 4.7.5)
```

### Event Flow Per Scan Cycle

```
Every SCAN_INTERVAL (3s):
  ├── emit("detections", [Detection, ...])     # All active
  ├── emit("bt_devices", [BTDevice, ...])      # BLE devices
  ├── emit("gps_fix", GPSFix)                  # Current position
  ├── emit("alert", {tier, detection})          # If triggered
  └── emit("watch_alert", {label, ...})         # If watch matched

On user actions:
  ├── emit("ignore_updated", {...})             # Ignore list changed
  ├── emit("settings_updated", {...})           # Settings saved
  ├── emit("device_named", {mac, name})         # Name set/removed
  ├── emit("correlation_identified", {...})     # Cluster identified
  └── emit("watchlist_updated", [...])          # Watchlist modified
```

---

## 14. Threading Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    Process: Flask + eventlet                      │
│                                                                   │
│  Main Thread (eventlet)                                          │
│  ├── Flask request handling                                      │
│  ├── SocketIO event dispatch                                     │
│  └── Route handlers (API endpoints)                              │
│                                                                   │
│  scanner_thread (daemon)                                         │
│  ├── WiFi scan loop (Kismet/iw)                                 │
│  ├── BT device integration                                       │
│  ├── GPS fix attachment                                          │
│  ├── Pipeline processing per detection                           │
│  ├── SocketIO emission                                           │
│  └── Periodic save/recompute                                     │
│                                                                   │
│  BTScanner thread (daemon)                                       │
│  ├── btmgmt scan_once() every 10s                               │
│  ├── parse_btmgmt_output()                                       │
│  └── bt_tracker.update_batch()                                   │
│                                                                   │
│  GPSReader thread (daemon)                                       │
│  ├── gpsd JSON stream (preferred)                                │
│  ├── or serial NMEA (/dev/ttyACM0)                              │
│  └── Update GPSFix (RLock protected)                             │
│                                                                   │
│  Shared State (protected by eventlet green threads + RLock):     │
│  ├── fingerprint_db, tracker, ignore_list, alert_history         │
│  ├── ssid_groups, bt_tracker, gps_reader                         │
│  ├── tri_engine, pnl_engine, correlator, watch_list              │
│  └── _settings dict                                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 15. Security Model

| Layer | Implementation |
|-------|---------------|
| **Authentication** | HTTP Basic Auth on all Flask routes (`_require_login()` before_request) |
| **Credentials** | Environment variables only — `CREEPER_ADMIN_USER`, `CREEPER_ADMIN_PASSWORD` |
| **Secret keys** | `SecretStr` (Pydantic) for passwords, `secrets.token_hex(32)` for Flask secret |
| **Input validation** | Pydantic models, regex validation, `isprintable()` filtering |
| **Bounded collections** | All in-memory collections capped (5000 fingerprints, 500 BT, 2000 PNL, 1000 alerts, 5000 GPS) |
| **File integrity** | Atomic writes (tmp → rename) on POSIX |
| **Webhook signing** | HMAC-SHA256 (`X-Signature-256` header) |
| **Systemd hardening** | `ProtectSystem=full`, `PrivateTmp=true`, `AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW` |
| **Network** | Bind to `0.0.0.0:5000` (LAN only — no TLS, assumes trusted network or VPN) |

---

*signals-architecture v2.0 | 2026-02-08 | Creeper Sweeper*
*Updated: multi-dimensional clustering, 9 cluster types, exponential convergence*
