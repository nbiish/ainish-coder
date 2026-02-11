# MAC Address Breakdown & OUI Vendor Database

> **Complete reference for MAC address structural analysis, OUI vendor identification,
> and the 56,887-entry manufacturer database integrated into Creeper Sweeper.**
>
> **Added:** Phase 12, February 11, 2026
>
> **Companion documents**:
> - [Frontend](signals-frontend.md) — Dashboard rendering, modal system
> - [Data Models](signals-data-models.md) — API endpoints, JSON schemas
> - [Architecture](signals-architecture.md) — Backend pipeline

---

## Table of Contents

1. [MAC Address Structure](#1-mac-address-structure)
2. [OUI Vendor Database](#2-oui-vendor-database)
3. [Backend Engine](#3-backend-engine)
4. [Frontend Rendering](#4-frontend-rendering)
5. [API Endpoints](#5-api-endpoints)
6. [Randomization Detection](#6-randomization-detection)
7. [Educational Value](#7-educational-value)
8. [CI/CD Database Pipeline](#8-cicd-database-pipeline)
9. [Improvement Roadmap](#9-improvement-roadmap)

---

## 1. MAC Address Structure

A MAC (Media Access Control) address is a 48-bit (6-byte) hardware identifier
assigned to network interfaces. Understanding its structure is fundamental to
device identification and surveillance detection.

### 1.1 Byte Layout

```
┌─────────────────────────── OUI (Organizationally Unique Identifier) ─────┐
│                                                                           │
│   Byte 0          Byte 1          Byte 2          Byte 3    Byte 4    Byte 5
│ ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌────────┐ ┌────────┐ ┌────────┐
│ │ D4       │   │ F9       │   │ 8D       │   │ 01     │ │ 2A     │ │ B7     │
│ └──────────┘   └──────────┘   └──────────┘   └────────┘ └────────┘ └────────┘
│                                                │                            │
└────────────────────────────────────────────────┼────────────────────────────┘
                                                 │
                                   NIC-Specific (Device Serial) ──────────────┘
```

- **OUI (Bytes 0–2):** Assigned by IEEE to manufacturers. Lookup reveals vendor.
- **NIC (Bytes 3–5):** Assigned by the manufacturer to individual devices. Sequential or random.

### 1.2 First Octet Bit Fields

The first byte contains two critical flags in its least-significant bits:

```
Bit:  7   6   5   4   3   2   1   0
      │   │   │   │   │   │   │   └── I/G Bit (Individual/Group)
      │   │   │   │   │   │   └────── U/L Bit (Universal/Local)
      └───┴───┴───┴───┴───┴────────── Upper 6 bits of OUI
```

| Bit | Name | Value=0 | Value=1 |
|-----|------|---------|---------|
| **Bit 0** | I/G (Individual/Group) | Unicast — single host | Multicast — group address |
| **Bit 1** | U/L (Universal/Local) | Universally Administered (UAA) — IEEE assigned | Locally Administered (LAA) — likely randomized |

### 1.3 Significance for Surveillance Detection

| Address Type | I/G | U/L | Meaning | Tracking Risk |
|-------------|-----|-----|---------|---------------|
| Standard vendor MAC | 0 | 0 | Real hardware address from manufacturer | **High** — permanent, trackable |
| Randomized MAC | 0 | 1 | Device OS rotates address for privacy | **Low** — changes frequently |
| Multicast | 1 | 0 | Group address (not a real device) | N/A |
| Broadcast | 1 | 1 | ff:ff:ff:ff:ff:ff | N/A |

**Key insight:** Modern iOS (14+), Android (10+), and Windows (10+) randomize MAC
addresses by default. The U/L bit = 1 is the telltale sign. These devices will NOT
match any OUI vendor lookup because the OUI is fabricated.

---

## 2. OUI Vendor Database

### 2.1 Database Sources

Creeper Sweeper merges two comprehensive OUI databases:

| Source | Entries | Update Frequency | Coverage |
|--------|---------|-------------------|----------|
| **maclookup.app** | 56,878 | Community, frequent | Broadest — includes MA-L, MA-M, MA-S, CID, IAB |
| **IEEE MA-L** | 38,893 | Official IEEE, monthly | Authoritative — only MA-L (24-bit OUI) |
| **Merged Total** | **56,887** | Manual via `build_oui_db.py` | Deduplicated, maclookup.app preferred |

### 2.2 Block Types

IEEE assigns OUI blocks in different sizes:

| Block Type | Prefix Length | Block Size | Typical Assignee |
|-----------|--------------|------------|-------------------|
| **MA-L** (MAC Address Large) | 24-bit (3 bytes) | 16.7M addresses | Major manufacturers (Apple, Intel, Samsung) |
| **MA-M** (MAC Address Medium) | 28-bit (3.5 bytes) | 1M addresses | Mid-size companies |
| **MA-S** (MAC Address Small) | 36-bit (4.5 bytes) | 4,096 addresses | Small companies, IoT devices |
| **CID** (Company ID) | 24-bit | N/A (not for network) | Internal use, not globally unique |
| **IAB** (Individual Address Block) | 36-bit | 4,096 addresses | Deprecated, replaced by MA-S |

### 2.3 Database Statistics (Current Build)

```json
{
  "total_entries": 56887,
  "block_types": {
    "MA-L": 38920,
    "MA-S": 6894,
    "MA-M": 6248,
    "IAB": 4578,
    "CID": 212,
    "": 35
  },
  "loaded": true
}
```

### 2.4 Vendor Categories

The engine maps 60+ vendors to functional categories with icons:

| Category | Icon | Example Vendors |
|----------|------|-----------------|
| Smartphone | 📱 | Apple, Samsung, Google, OnePlus, Xiaomi, Huawei |
| Networking | 🌐 | Cisco, TP-Link, Netgear, Ubiquiti, Aruba, Juniper |
| Computing | 💻 | Intel, Dell, HP, Lenovo, Microsoft, ASUSTek |
| IoT / Smart Home | 🏠 | Amazon (Echo), Sonos, Ring, Nest, Philips Hue |
| Automotive | 🚗 | Tesla, BMW, Ford, Harman, Continental |
| Industrial | 🏭 | Siemens, Honeywell, ABB, Schneider Electric |
| Surveillance | 🔍 | Hikvision, Dahua, Axis, Flock Safety |
| Gaming | 🎮 | Nintendo, Sony (PlayStation), Microsoft (Xbox) |
| Wearable | ⌚ | Fitbit, Garmin |
| Audio | 🔊 | Bose, Sonos, JBL |

---

## 3. Backend Engine

### 3.1 Module: `webapp/mac_breakdown.py` (340 lines)

```python
# Primary function — full structural analysis
def mac_breakdown(mac: str) -> dict:
    """Return comprehensive MAC address breakdown.
    
    Returns dict with: mac, oui, nic, octets[], ig_bit, ul_bit,
    is_randomized, vendor, vendor_found, vendor_private,
    block_type, category, category_icon, tracking_risk, 
    tracking_label, randomization_note, first_octet_binary,
    ig_detail, ig_label, ul_detail, ul_label, matched_prefix,
    block_type_description, valid
    """

# Vendor lookup only
def lookup_oui(mac: str) -> dict | None:
    """Look up vendor for a MAC address OUI prefix."""

# Database statistics
def get_oui_db_stats() -> dict:
    """Return OUI database statistics (total, block types, loaded status)."""
```

### 3.2 Lazy Loading Pattern

The OUI database (5.5MB JSON) is loaded once on first use:

```python
_oui_db: dict | None = None

def _load_oui_db() -> dict:
    global _oui_db
    if _oui_db is not None:
        return _oui_db
    # Try webapp/oui_lookup.json first, fall back to webapp/static/oui_db.json
    for path in [Path(__file__).parent / "oui_lookup.json",
                 Path(__file__).parent / "static" / "oui_db.json"]:
        if path.exists():
            _oui_db = json.loads(path.read_text())
            return _oui_db
    _oui_db = {}
    return _oui_db
```

### 3.3 Integration with Device API

The `/api/devices/<mac>` endpoint enriches every response:

```python
# In api_device_detail():
from mac_breakdown import mac_breakdown
breakdown = mac_breakdown(mac)
fp["mac_breakdown"] = breakdown
```

---

## 4. Frontend Rendering

### 4.1 OUI Database Loading

On page init, `loadOuiDatabase()` fetches the client-side DB:

```javascript
function loadOuiDatabase() {
    fetch("/static/oui_db.json")
        .then(r => { if (!r.ok) throw new Error(r.status); return r.json(); })
        .then(db => {
            window._ouiDB = db;
            console.log(`[OUI] Loaded ${Object.keys(db).length} vendor entries`);
        })
        .catch(e => console.warn("[OUI] Could not load vendor database:", e));
}
```

### 4.2 MAC Breakdown Panel

`renderMacBreakdownPanel(bd)` generates a collapsible panel inside every device modal:

1. **Octet Diagram** — 6 colored blocks (OUI in teal, NIC in purple) with hex, binary, and label
2. **Vendor Card** — Icon, vendor name, block type badge, category, private registration badge
3. **Bit-Field Table** — Full address, OUI, NIC, first octet binary, I/G bit, U/L bit with badges
4. **Randomization Note** — Warning if MAC is locally administered (privacy rotation)
5. **Tracking Risk** — Color-coded indicator (danger=high, success=low, info=unknown)

### 4.3 Vendor Badges on Ignore List

Each MAC in the ignore list shows:
- Vendor name badge (looked up from `window._ouiDB`)
- Clickable `(i)` info button that opens the device modal for full breakdown
- "Randomized" indicator for locally-administered addresses

### 4.4 CSS Classes (163 new lines)

| Class | Purpose |
|-------|---------|
| `.mac-breakdown-panel` | Collapsible container |
| `.mac-breakdown-diagram` | Flexbox octet row |
| `.mac-octet` | Individual byte block |
| `.mac-octet-oui` | OUI bytes (teal accent) |
| `.mac-octet-nic` | NIC bytes (purple accent) |
| `.mac-breakdown-vendor` | Vendor info card |
| `.mac-vendor-randomized` | Randomized MAC styling |
| `.mac-vendor-unknown` | Unknown vendor styling |
| `.mac-randomization-note` | Warning note box |
| `.mac-tracking-risk` | Tracking risk indicator |
| `.mac-tracking-danger` | High risk (red) |
| `.mac-tracking-success` | Low risk (green) |
| `.mac-info-btn` | Round info button on ignore list |
| `.ignore-vendor-badge` | Vendor badge on ignore list MACs |

---

## 5. API Endpoints

### 5.1 Full MAC Breakdown

```
GET /api/mac/<mac>/breakdown
```

Returns comprehensive structural analysis:

```json
{
  "mac": "D4:F9:8D:01:2A:B7",
  "oui": "D4:F9:8D",
  "nic": "01:2A:B7",
  "valid": true,
  "is_randomized": false,
  "vendor": "Intel Corporate",
  "vendor_found": true,
  "vendor_private": false,
  "block_type": "MA-L",
  "block_type_description": "MAC Address Block Large (MA-L) — 24-bit OUI ...",
  "category": "Computing",
  "category_icon": "💻",
  "tracking_risk": "high",
  "tracking_label": "Permanent hardware MAC — highly trackable across networks",
  "ig_bit": 0,
  "ig_label": "Unicast",
  "ig_detail": "Bit 0 = 0 → Individual/Unicast address (single host)",
  "ul_bit": 0,
  "ul_label": "Universally Administered (UAA)",
  "ul_detail": "Bit 1 = 0 → Universally administered — assigned by IEEE to manufacturer",
  "first_octet_binary": "11010100",
  "octets": [
    {"index": 0, "hex": "D4", "binary": "11010100", "decimal": 212, "role": "OUI (Manufacturer)", "notes": "I/G=0 (Unicast), U/L=0 (Universal)"},
    {"index": 1, "hex": "F9", "binary": "11111001", "decimal": 249, "role": "OUI (Manufacturer)", "notes": ""},
    {"index": 2, "hex": "8D", "binary": "10001101", "decimal": 141, "role": "OUI (Manufacturer)", "notes": ""},
    {"index": 3, "hex": "01", "binary": "00000001", "decimal": 1, "role": "NIC-Specific (Device)", "notes": "First device-specific byte"},
    {"index": 4, "hex": "2A", "binary": "00101010", "decimal": 42, "role": "NIC-Specific (Device)", "notes": ""},
    {"index": 5, "hex": "B7", "binary": "10110111", "decimal": 183, "role": "NIC-Specific (Device)", "notes": "Last byte — often sequential from manufacturer"}
  ]
}
```

### 5.2 OUI Vendor Lookup

```
GET /api/oui/<prefix>
```

Quick vendor lookup for a 3-byte prefix:

```json
{
  "prefix": "D4:F9:8D",
  "vendor": "Intel Corporate",
  "block_type": "MA-L",
  "private": false
}
```

### 5.3 Database Statistics

```
GET /api/oui/stats
```

```json
{
  "loaded": true,
  "total_entries": 56887,
  "block_types": {"MA-L": 38920, "MA-S": 6894, "MA-M": 6248, "IAB": 4578, "CID": 212, "": 35}
}
```

---

## 6. Randomization Detection

### 6.1 How Modern Devices Randomize

Starting with iOS 14 (2020), Android 10 (2019), and Windows 10 (2020), devices
randomize their MAC addresses when:

- **Scanning** for Wi-Fi networks (probe requests)
- **Connecting** to untrusted networks (per-network random MAC)
- **Bluetooth LE** advertising (LE Random addresses)

The randomized MAC always has **U/L bit = 1** (bit 1 of first octet), making it
detectable by examining a single bit.

### 6.2 Detection Logic

```python
first_byte = int(mac_parts[0], 16)
ul_bit = (first_byte >> 1) & 1
is_randomized = ul_bit == 1
```

### 6.3 Implications for Surveillance Detection

| Scenario | Impact |
|----------|--------|
| Randomized MAC detected | Device is hiding identity — OUI lookup meaningless |
| Same device seen with multiple random MACs | Only PHY fingerprinting (techniques 6-9) can correlate |
| Surveillance device using real MAC | OUI lookup reveals Flock Safety, Hikvision, etc. |
| Surveillance device randomizing | Must rely on SSID patterns, signal analysis, behavior |

---

## 7. Educational Value

### 7.1 Learning Objectives

The MAC breakdown feature serves as an **interactive teaching tool** for:

1. **IEEE 802 addressing** — Understanding the OUI/NIC split, bit fields, and block types
2. **Privacy technology** — How and why MAC randomization works (U/L bit)
3. **Device identification** — Using vendor lookup to identify unknown devices
4. **Network forensics** — Tracking risk assessment, multicast vs unicast
5. **Manufacturer ecosystems** — Understanding which companies make which devices
6. **Surveillance detection** — Recognizing surveillance vendor OUIs vs consumer devices

### 7.2 Practical Workflow for Device Identification

```
1. Open Creeper Sweeper dashboard
2. See unknown device in Detections tab
3. Click "Info" button → Device Modal opens
4. Scroll to "MAC Address Breakdown" panel
5. Check if MAC is randomized (U/L bit = 1)
   ├── YES → Device is privacy-rotating, check signal pattern instead
   └── NO → Read vendor name and category
6. Decide: Add to ignore list (trusted) or investigate further
7. Vendor badges on Ignore List help verify existing trusted devices
```

### 7.3 What You Learn from Each Device

| Breakdown Field | What It Teaches |
|----------------|-----------------|
| OUI prefix | Who manufactured the network chip |
| Block type | How large the manufacturer is (MA-L = big, MA-S = small/IoT) |
| I/G bit | Whether it's a real device or a multicast/broadcast |
| U/L bit | Whether the address is real (trackable) or randomized (private) |
| Category | What kind of device it likely is (phone, router, camera, etc.) |
| Tracking risk | How easily this device can be followed across networks |
| Randomization note | Why OUI lookup fails for privacy-rotating devices |

### 7.4 Building Intuition

Over time, regular use of MAC breakdown develops:

- **Pattern recognition:** "Most of my home devices are Apple/Samsung/Google"
- **Anomaly detection:** "This Intel OUI on a device with no SSID is unusual"
- **Privacy awareness:** "70% of detected devices use randomized MACs"
- **Threat assessment:** "Flock Safety OUI = surveillance camera"

---

## 8. CI/CD Database Pipeline

### 8.1 Build Script

`scripts/build_oui_db.py` (96 lines) merges upstream sources:

```bash
# Rebuild OUI databases from downloaded sources
python3 scripts/build_oui_db.py
```

**Input files** (not committed — CI/CD build artifacts):
- `ci_cd_datasets/mac_vendors_full.json` — maclookup.app dump
- `ci_cd_datasets/ieee_oui_mal.csv` — IEEE MA-L CSV

**Output files** (committed):
- `webapp/oui_lookup.json` — Backend lookup (5.5MB, 56,887 entries)
- `webapp/static/oui_db.json` — Frontend compact (4.4MB, 56,887 entries)

### 8.2 Update Workflow

```
1. Download latest maclookup.app JSON export
2. Download latest IEEE MA-L CSV from standards.ieee.org
3. Place in ci_cd_datasets/
4. Run: python3 scripts/build_oui_db.py
5. Verify: python3 -c "import json; d=json.load(open('webapp/oui_lookup.json')); print(len(d))"
6. Deploy: bash webapp/deploy.sh
```

### 8.3 Database Format

**Backend** (`oui_lookup.json`):
```json
{
  "D4:F9:8D": {"vendor": "Intel Corporate", "block_type": "MA-L", "private": false},
  "00:17:F2": {"vendor": "Apple, Inc.", "block_type": "MA-L", "private": false}
}
```

**Frontend** (`oui_db.json` — compact):
```json
{
  "D4:F9:8D": {"v": "Intel Corporate", "b": "MA-L", "p": false, "u": "D4:F9:8D"},
  "00:17:F2": {"v": "Apple, Inc.", "b": "MA-L", "p": false, "u": "00:17:F2"}
}
```

---

## 9. Improvement Roadmap

### 9.1 Near-Term Enhancements

| Enhancement | Impact | Effort |
|-------------|--------|--------|
| Interactive MAC tutorial in Reference tab | High educational value | Medium |
| Vendor distribution pie chart on Home Network | Visual understanding | Low |
| Automated OUI DB refresh (cron + build_oui_db.py) | Always up-to-date | Low |
| Batch MAC breakdown for correlation clusters | Identify all members at once | Medium |
| MAC privacy score in device cards (not just modal) | Quick scanning | Low |

### 9.2 Educational Extensions

| Extension | Learning Goal |
|-----------|---------------|
| "What is this device?" AI assistant | Natural-language device identification |
| Guided identification walkthrough | Step-by-step tutorial for new users |
| Surveillance detection confidence scoring | Understand how each technique contributes |
| Export annotated reports | Review learnings offline |
| Quiz mode in Reference tab | Test understanding of MAC structure |
| Comparison view (two MACs side-by-side) | Learn to spot differences |

### 9.3 Database Improvements

| Improvement | Benefit |
|-------------|---------|
| Add IEEE MA-M and MA-S registries | Cover more IoT/small vendor OUIs |
| Add Wireshark community DB as third source | Even broader coverage |
| Add BT SIG Company IDs | Map 16-bit BLE Company IDs to manufacturers |
| Add device model inference | Go beyond vendor → guess specific product model |
| Version the OUI DB with timestamps | Track freshness, auto-alert on stale data |

---

*signals-mac-breakdown v1.0 | 2026-02-11 | Creeper Sweeper Phase 12*
