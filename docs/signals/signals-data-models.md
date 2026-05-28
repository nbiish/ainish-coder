# Data Models, Persistence & API Reference

> **Complete reference for all data structures, JSON persistence formats,
> REST API endpoints, WebSocket events, and data lifecycle.**
>
> **Companion documents**:
> - [Architecture](signals-architecture.md) — System design, pipeline flow
> - [Correlation Engine](signals-correlation-engine.md) — Algorithm details

---

## Table of Contents

1. [Data Directory Layout](#1-data-directory-layout)
2. [Atomic Write Pattern](#2-atomic-write-pattern)
3. [Core Data Classes](#3-core-data-classes)
4. [Persistence Schemas](#4-persistence-schemas)
5. [REST API Reference](#5-rest-api-reference)
6. [WebSocket Events](#6-websocket-events)
7. [Bounded Collections](#7-bounded-collections)
8. [Data Lifecycle](#8-data-lifecycle)
9. [Cache Busting Strategy](#9-cache-busting-strategy)

---

## 1. Data Directory Layout

```
~/.local/share/creeper-sweeper/
├── alert_history.json          # Tiered alert log
├── bt_devices.json             # BLE device tracker state
├── fingerprints.json           # Device fingerprint database
├── gps_log.json                # GPS track log
├── ignore_list.json            # Ignore rules (MAC/OUI/SSID/name)
├── pnl_profiles.json           # PNL fingerprint profiles
├── settings.json               # Runtime settings (persisted)
├── signal_correlations.json    # Correlation engine state
├── ssid_groups.json            # SSID group tracker state
├── triangulation.json          # Triangulation engine state
├── watchlist.json              # Watch alert entries
└── logs/
    └── webapp.log              # Application log
```

---

## 2. Atomic Write Pattern

All JSON files use POSIX atomic write to prevent corruption on crash:

```python
def _save(data: Any, path: Path) -> None:
    """Atomic write: tmp file → rename (atomic on same filesystem)."""
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2, default=str))
    tmp.rename(path)  # Atomic replace on POSIX
```

Benefits:
- No partial writes (readers see old or new, never corrupt)
- Power-loss safe on ext4 with `data=ordered` (default)
- No file locking needed

---

## 3. Core Data Classes

### Detection (dataclass)

The central data structure — represents one observed device.

```python
@dataclass
class Detection:
    mac: str                    # "AA:BB:CC:DD:EE:FF"
    ssid: str                   # Network name or ""
    device_name: str            # Advertised name
    manufacturer: str           # OUI manufacturer lookup
    signal: int                 # RSSI in dBm
    channel: int                # WiFi channel number
    frequency: int              # MHz
    phy: str                    # "wifi" or "ble"
    first_seen: str             # ISO 8601 timestamp
    last_seen: str              # ISO 8601 timestamp
    persist_seconds: float      # Seconds since first_seen
    packets: int                # Packet count
    probed_ssids: list[str]     # List of probed SSIDs
    is_surveillance: bool       # Matched surveillance database
    surveillance_reason: str    # Match reason
    is_ignored: bool            # In ignore list
    friendly_name: str          # User-assigned name
    connected_ssid: str         # Associated network
    latitude: float             # GPS latitude
    longitude: float            # GPS longitude
    location_label: str         # "lat, lon" string
    location_source: str        # "gps" or ""
    has_location: bool          # GPS valid at time of detection
    addr_type_label: str        # "global_unique", "local_admin", etc.
    trackability: str           # "permanent", "session", "low", "none"
    directed_probes: list[str]  # Directed-only probed SSIDs
    pnl_hash: str               # PNL fingerprint hash
```

### BTDevice (dataclass)

```python
@dataclass
class BTDevice:
    mac: str                    # "AA:BB:CC:DD:EE:FF"
    name: str                   # Advertised BLE name
    rssi: int                   # Signal strength
    addr_type: str              # "LE Public", "LE Random", "BR/EDR"
    flags: str                  # BLE flags hex
    first_seen: float           # Unix timestamp
    last_seen: float            # Unix timestamp
    rssi_history: list[int]     # Recent RSSI values (max 50)
```

### GPSFix (dataclass)

```python
@dataclass
class GPSFix:
    valid: bool                 # Fix acquired
    latitude: float             # Decimal degrees
    longitude: float            # Decimal degrees
    altitude: float             # Meters ASL
    speed: float                # Knots
    heading: float              # Degrees true
    satellites: int             # Visible satellites
    hdop: float                 # Horizontal dilution
    fix_quality: str            # "NoFix", "GPS", "DGPS"
    timestamp: str              # ISO 8601
```

### SignalObservation (dataclass)

```python
@dataclass
class SignalObservation:
    node_id: str                # "pi-local" or ESP32 node ID
    mac: str                    # Observed device MAC
    rssi: int                   # Signal strength
    signal_type: str            # "wifi" or "ble"
    node_latitude: float        # Observer latitude
    node_longitude: float       # Observer longitude
    node_altitude: float        # Observer altitude
    timestamp: float            # Unix timestamp
```

### TriangulationResult (dataclass)

```python
@dataclass
class TriangulationResult:
    mac: str                    # Target device
    estimated_latitude: float   # Computed position
    estimated_longitude: float  # Computed position
    confidence: float           # 0.0-1.0
    num_nodes: int              # Contributing nodes
    num_observations: int       # Total observations used
    timestamp: float            # Computation time
```

---

## 4. Persistence Schemas

### settings.json

```json
{
  "scan_interval": 3,
  "persist_threshold": 5,
  "min_rssi": -127,
  "sound_enabled": true,
  "popup_enabled": true,
  "alert_cooldown": 60,
  "bt_scan_duration": 8
}
```

These 7 fields are persisted on each `POST /api/settings` call.
Values override `.env` defaults at startup.

### ignore_list.json

```json
{
  "macs": ["AA:BB:CC:DD:EE:FF", "11:22:33:44:55:66"],
  "ouis": ["B8:27:EB", "DC:A6:32"],
  "ssids": ["DIRECT-*", "HP-Print-*"],
  "device_names": ["Chromecast-*", "Google-Home-*"]
}
```

SSID and device_name patterns support fnmatch wildcards (`*`, `?`, `[seq]`).

### fingerprints.json

```json
{
  "version": 1,
  "device_count": 142,
  "devices": [
    {
      "mac": "AA:BB:CC:DD:EE:FF",
      "friendly_name": "Mom's iPhone",
      "notes": "Usually arrives 5pm",
      "device_type": "wifi",
      "device_name": "iPhone",
      "manufacturer": "Apple, Inc.",
      "first_seen": "2026-01-15T10:30:00",
      "last_seen": "2026-02-08T14:22:00",
      "sighting_count": 847,
      "tags": ["family", "trusted"],
      "confidence": 95,
      "sightings": [
        {
          "timestamp": "2026-02-08T14:22:00",
          "rssi": -52,
          "ssid": "HomeWiFi",
          "channel": 6,
          "latitude": 42.3601,
          "longitude": -71.0589
        }
      ]
    }
  ]
}
```

### alert_history.json

```json
[
  {
    "timestamp": "2026-02-08T14:22:00",
    "tier": 3,
    "tier_label": "SURVEILLANCE",
    "mac": "58:8E:81:AB:CD:EF",
    "display_name": "Flock Safety Camera",
    "signal": -45,
    "surveillance_reason": "OUI 58:8E:81 matches Flock Safety",
    "connected_ssid": "FLOCK-1234",
    "latitude": 42.3601,
    "longitude": -71.0589,
    "location_label": "42.360100, -71.058900"
  }
]
```

### ssid_groups.json

```json
{
  "HomeWiFi": {
    "macs": ["AA:BB:CC:DD:EE:01", "AA:BB:CC:DD:EE:02"],
    "channels": [6],
    "frequencies": [2437],
    "phy_types": ["wifi"],
    "signal_min": -72,
    "signal_max": -38,
    "first_seen": "2026-01-15T10:30:00",
    "last_seen": "2026-02-08T14:22:00",
    "similar_ssids": [],
    "event_log": [
      {
        "timestamp": "2026-02-08T14:22:00",
        "event": "new_mac",
        "mac": "AA:BB:CC:DD:EE:02"
      }
    ]
  }
}
```

### bt_devices.json

```json
{
  "AA:BB:CC:DD:EE:FF": {
    "mac": "AA:BB:CC:DD:EE:FF",
    "name": "EF-R350956",
    "rssi": -52,
    "addr_type": "LE Random",
    "flags": "0x0006",
    "first_seen": 1707400000.0,
    "last_seen": 1707400120.0,
    "rssi_history": [-52, -55, -48, -52]
  }
}
```

### gps_log.json

```json
[
  {
    "latitude": 42.3601,
    "longitude": -71.0589,
    "altitude": 15.2,
    "speed": 0.0,
    "heading": 180.0,
    "satellites": 9,
    "hdop": 1.2,
    "timestamp": 1707400000.0,
    "timestamp_str": "2026-02-08T14:22:00"
  }
]
```

### pnl_profiles.json

```json
{
  "AA:BB:CC:DD:EE:FF": {
    "mac": "AA:BB:CC:DD:EE:FF",
    "directed_ssids": ["HomeWiFi", "CoffeeShop", "Work-5G"],
    "broadcast_ssids": [],
    "pnl_hash": "a3f7b2c1e9d4f083",
    "mac_address_type": "local_admin",
    "probe_count": 47,
    "first_seen": "2026-01-15T10:30:00",
    "last_seen": "2026-02-08T14:22:00"
  }
}
```

### signal_correlations.json

```json
{
  "clusters": [
    {
      "id": "mfr-Apple-rssi-0",
      "cluster_type": "manufacturer_rssi",
      "grouping_reason": "Manufacturer: Apple, Inc. → RSSI band (median -52)",
      "macs": ["AA:BB:CC:DD:EE:01", "CC:DD:EE:FF:00:11", "AA:BB:CC:DD:EE:02"],
      "addr_types": ["wifi", "wifi", "ble"],
      "pnl_match": false,
      "label": "John's Devices",
      "identified": true,
      "confidence": 0.82,
      "member_count": 3
    },
    {
      "id": "xlink-0",
      "cluster_type": "wifi_bt_crosslink",
      "grouping_reason": "WiFi↔BT cross-link (OUI:0.35 + RSSI:0.25 + Name:0.30 = 0.90)",
      "macs": ["AA:BB:CC:DD:EE:01", "CC:DD:EE:FF:00:11"],
      "addr_types": ["wifi", "ble"],
      "pnl_match": false,
      "label": null,
      "identified": false,
      "confidence": 0.90,
      "member_count": 2
    }
  ],
  "identifications": {
    "mfr-Apple-rssi-0": "John's Devices"
  },
  "step": 36,
  "rssi_tolerance_wifi": 1.0,
  "rssi_tolerance_bt": 5.0
}
```

#### Cluster Type Prefixes

| Prefix | `cluster_type` | Phase |
|--------|---------------|-------|
| `mfr-` | `manufacturer_rssi` | 1 — Manufacturer + RSSI band |
| `pnl-` | `pnl_cluster` | 2 — PNL Jaccard similarity |
| `rand-` | `random_mac_ssid` | 3 — Randomized MAC + shared SSID |
| `btn-` | `bt_name_group` | 4b — BT name prefix rule |
| `btr-` | `bt_rssi_band` | 4b — BT RSSI band sub-cluster |
| `xlink-` | `wifi_bt_crosslink` | 5 — WiFi↔BT cross-link |
| `pnlxv-` | `pnl_cross_vendor` | 6 — Cross-vendor PNL merge |
```

### watchlist.json

```json
[
  {
    "id": "watch-1707400000-abc",
    "label": "Mom is home",
    "match_type": "friendly_name",
    "match_value": "Mom's iPhone",
    "cooldown": 300,
    "sound": true,
    "popup": true,
    "enabled": true,
    "last_fired": null
  }
]
```

#### Watch Match Types (7)

| `match_type` | Description | Example |
|-------------|-------------|----------|
| `mac` | Exact MAC address | `AA:BB:CC:DD:EE:FF` |
| `oui` | OUI prefix match | `AA:BB:CC` |
| `friendly_name` | Assigned name match | `Mom's iPhone` |
| `device_name` | Advertised name match | `iPhone` |
| `ssid` | Connected SSID match | `HomeWiFi` |
| `manufacturer` | Manufacturer match | `Apple, Inc.` |
| `pnl_hash` | PNL fingerprint hash | `a3f7b2c1e9d4f083` |

### triangulation.json

```json
{
  "nodes": {
    "pi-local": {
      "node_id": "pi-local",
      "latitude": 42.3601,
      "longitude": -71.0589,
      "last_seen": 1707400000.0,
      "capabilities": ["wifi", "ble"],
      "online": true
    }
  },
  "observations": {
    "AA:BB:CC:DD:EE:FF": [
      {
        "node_id": "pi-local",
        "mac": "AA:BB:CC:DD:EE:FF",
        "rssi": -52,
        "signal_type": "wifi",
        "node_latitude": 42.3601,
        "node_longitude": -71.0589,
        "timestamp": 1707400000.0
      }
    ]
  },
  "results": {
    "AA:BB:CC:DD:EE:FF": {
      "mac": "AA:BB:CC:DD:EE:FF",
      "estimated_latitude": 42.3605,
      "estimated_longitude": -71.0585,
      "confidence": 0.72,
      "num_nodes": 3,
      "num_observations": 12,
      "timestamp": 1707400000.0
    }
  }
}
```

---

## 5. REST API Reference

### Authentication

All endpoints require HTTP Basic Auth:
```
Authorization: Basic base64(username:password)
```

Credentials from `.env`: `CREEPER_ADMIN_USER` / `CREEPER_ADMIN_PASSWORD`.

### System

| Method | Path | Response |
|--------|------|----------|
| GET | `/api/status` | System status (scanner, Kismet, GPS, BT, PNL, triangulation, fingerprint count) |
| GET | `/api/detections` | `[Detection, ...]` — all active detections |

### Ignore List

| Method | Path | Body | Response |
|--------|------|------|----------|
| GET | `/api/ignore` | — | `{macs, ouis, ssids, device_names}` |
| POST | `/api/ignore/mac` | `{value: "AA:BB:CC:DD:EE:FF"}` | `{ok: true}` |
| DELETE | `/api/ignore/mac` | `{value: "AA:BB:CC:DD:EE:FF"}` | `{ok: true}` |
| POST | `/api/ignore/oui` | `{value: "AA:BB:CC"}` | `{ok: true}` |
| DELETE | `/api/ignore/oui` | `{value: "AA:BB:CC"}` | `{ok: true}` |
| POST | `/api/ignore/ssid` | `{value: "DIRECT-*"}` | `{ok: true}` |
| DELETE | `/api/ignore/ssid` | `{value: "DIRECT-*"}` | `{ok: true}` |
| POST | `/api/ignore/device_name` | `{value: "Chromecast-*"}` | `{ok: true}` |
| DELETE | `/api/ignore/device_name` | `{value: "Chromecast-*"}` | `{ok: true}` |

### Devices (Fingerprints)

| Method | Path | Body / Params | Response |
|--------|------|---------------|----------|
| GET | `/api/devices` | — | `[DeviceFingerprint, ...]` |
| GET | `/api/devices/named` | — | Named devices only |
| GET | `/api/devices/search?q=term` | — | Search by MAC/name/SSID |
| GET | `/api/devices/<mac>` | — | Full detail: sightings, PNL, location, address type |
| POST | `/api/devices/<mac>/name` | `{name, notes}` | `{ok: true, name, notes}` |
| DELETE | `/api/devices/<mac>/name` | — | `{ok: true}` |

### SSID Groups

| Method | Path | Response |
|--------|------|----------|
| GET | `/api/groups` | All groups with stats |
| GET | `/api/groups/<ssid>` | Detailed group: per-MAC table, event log |

### Alerts

| Method | Path | Params | Response |
|--------|------|--------|----------|
| GET | `/api/alerts` | `?limit=N` | Alert history (newest first) |
| DELETE | `/api/alerts` | — | Clear all history |

### Settings

| Method | Path | Body | Response |
|--------|------|------|----------|
| GET | `/api/settings` | — | `{scan_interval, persist_threshold, min_rssi, sound_enabled, popup_enabled}` |
| POST | `/api/settings` | `{scan_interval?, persist_threshold?, min_rssi?, sound_enabled?, popup_enabled?}` | Updated settings |

### GPS

| Method | Path | Params | Response |
|--------|------|--------|----------|
| GET | `/api/gps` | — | Current GPSFix |
| GET | `/api/gps/log` | `?limit=N` | GPS track entries |

### Bluetooth

| Method | Path | Response |
|--------|------|----------|
| GET | `/api/bluetooth` | All BLE devices with address classification |

### Triangulation

| Method | Path | Body | Response |
|--------|------|------|----------|
| POST | `/api/triangulation/node` | `{node_id, latitude, longitude, capabilities}` | `{ok: true}` |
| GET | `/api/triangulation/nodes` | — | All registered nodes |
| POST | `/api/triangulation/observation` | `{node_id, mac, rssi, signal_type, lat, lon}` | `{ok: true}` |
| GET | `/api/triangulation/<mac>` | — | TriangulationResult |
| GET | `/api/triangulation/observations/<mac>` | — | Recent observations |

### Correlations

| Method | Path | Body | Response |
|--------|------|------|----------|
| GET | `/api/correlations` | — | Clusters + RSSI convergence state |
| POST | `/api/correlations/identify` | `{cluster_id, name}` | Identify + ignore all MACs/SSIDs |
| POST | `/api/correlations/rename` | `{cluster_id, name}` | Rename only |
| POST | `/api/correlations/recompute` | — | Force full recomputation |

### Watch Alerts

| Method | Path | Body | Response |
|--------|------|------|----------|
| GET | `/api/watchlist` | — | `[WatchEntry, ...]` |
| POST | `/api/watchlist` | `{label, match_type, match_value, cooldown?, sound?, popup?}` | Created entry |
| PUT/PATCH | `/api/watchlist/<id>` | `{enabled?, label?, match_type?, match_value?, cooldown?, sound?, popup?}` | Updated entry |
| DELETE | `/api/watchlist/<id>` | — | `{ok: true}` |

### CSV Export/Import

| Method | Path | Body | Response |
|--------|------|------|----------|
| GET | `/api/export/detections.csv` | — | CSV file download |
| POST | `/api/import/csv` | Multipart form: file | Import result stats |

---

## 6. WebSocket Events

### Server → Client

| Event | Payload | Trigger |
|-------|---------|---------|
| `detections` | `[Detection, ...]` | Every scan cycle |
| `alert` | `{tier: int, detection: Detection, timestamp: str}` | New/persist/surveillance alert |
| `watch_alert` | `{label, match_type, match_value, detection, sound, popup}` | Watch list match |
| `bt_devices` | `[BTDevice, ...]` | Every scan cycle |
| `gps_fix` | `GPSFix` | Every scan cycle |
| `ignore_updated` | `{macs, ouis, ssids, device_names}` | Ignore list modified |
| `settings_updated` | `{scan_interval, persist_threshold, min_rssi, ...}` | Settings saved |
| `device_named` | `{mac, name}` | Friendly name set/removed |
| `correlation_identified` | `{cluster_id, name, ...}` | Cluster identified/renamed |
| `watchlist_updated` | `[WatchEntry, ...]` | Watchlist modified |

### Client → Server

| Event | Payload | Purpose |
|-------|---------|---------|
| `request_scan` | — | Force immediate scan cycle |

---

## 7. Bounded Collections

All in-memory collections are capped to prevent unbounded memory growth:

| Collection | Max Size | Eviction |
|------------|----------|----------|
| Fingerprint DB | 5,000 devices | Oldest evicted |
| Alert history | 1,000 entries | Oldest dropped |
| PNL profiles | 2,000 profiles | Stale (>7d) pruned |
| BT device tracker | 500 devices | Stale (>600s) pruned |
| GPS log | 5,000 entries | Oldest dropped |
| Tracked MACs (triangulation) | 1,000 | Oldest evicted |
| Observations per MAC | 100 | Oldest dropped (deque) |
| Sightings per device | 200 | Oldest dropped (ring buffer) |
| RSSI history per BT device | 50 | Oldest dropped |
| SSIDs per PNL profile | 50 | Oldest dropped |

---

## 8. Data Lifecycle

### Detection Lifecycle

```
First seen              Persist                   Stale
  │                       │                        │
  ▼                       ▼                        ▼
Tier 1 alert ──→ Tier 2 alert ──→ Active ──→ Pruned from tracker
  │                       │           │              │
  └── FingerprintDB ──────┴───────────┘              │
       persists indefinitely                         │
       (up to 5000 devices)                          │
                                                     │
                                        TrackerDevice removed
                                        (> 60s since last_seen)
```

### Fingerprint Lifecycle

```
New device → record_sighting() → sighting ring buffer
  │
  ├── User names it → friendly_name set → persisted
  ├── Alert generated → alert_history
  ├── PNL built → pnl_profiles
  ├── Correlated → signal_correlations (cluster)
  └── Ignored → ignore_list (removed from active alerts)
```

### Save Cycle

Every ~60 seconds, the scanner thread persists all databases:

```python
def _save_all_databases():
    ignore_list.save()           # ignore_list.json
    fingerprint_db.save()        # fingerprints.json
    alert_history.save()         # alert_history.json
    ssid_groups.save()           # ssid_groups.json
    gps_reader.save_log()        # gps_log.json
    bt_tracker.save()            # bt_devices.json
    tri_engine.save()            # triangulation.json
    pnl_engine.save()            # pnl_profiles.json
    correlator.save()            # signal_correlations.json
    watch_list.save()            # watchlist.json
    # settings.json saved on POST only
```

---

## 9. Cache Busting Strategy

Static files (CSS, JS) are served with a version query parameter:

```html
<link rel="stylesheet" href="/static/style.css?v=8">
<script src="/static/app.js?v=8"></script>
```

The version is set in `app.py`:
```python
app.config["VERSION"] = "8"
```

Increment on any static file change → forces browser to reload.

---

*signals-data-models v2.0 | 2026-02-08 | Creeper Sweeper*
*Updated: Multi-dimensional cluster schema, 9 cluster types, 7 watch match types, 7 settings fields*
