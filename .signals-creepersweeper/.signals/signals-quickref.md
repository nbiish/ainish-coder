# Signals Quick Reference Card

> **Consolidated Cheat Sheet for RF Surveillance Detection**
>
> Fast lookup for critical UUIDs, MAC OUIs, SSIDs, commands, and detection pipelines.

---

## Target Device Fingerprints

### WiFi SSID Patterns

| Pattern | Device | Threat Level |
|---------|--------|--------------|
| `FLOCK*` | Flock Safety ALPR Camera | 🔴 95 |
| `PENGUIN*` | Penguin Camera | 🔴 90 |
| `FS_*` | Flock Safety Extended Battery | 🟡 85 |
| `PIGVISION*` | Pigvision System | 🟡 80 |

### MAC OUI Prefixes (Surveillance)

| OUI Prefix | Manufacturer/Device | BLE/WiFi |
|------------|-------------------|----------|
| `58:8e:81:*` | Flock Safety Battery | BLE |
| `00:1A:79:*` | Flock Network Equipment | WiFi |
| `B8:27:EB:*` | Raspberry Pi (common in surveillance) | WiFi |
| `DC:A6:32:*` | Raspberry Pi 4 | WiFi |

### BLE Service UUIDs (Raven/ShotSpotter)

| UUID Prefix | Service | Data Type |
|-------------|---------|-----------|
| `0x3100` / `0x3101-3102` | GPS Module | Lat/Lon (float) |
| `0x3200` / `0x3203-3205` | Power Management | Battery %, State |
| `0x3300` / `0x3304` | Cellular | LTE RSSI |
| `0x3400` / `0x3403` | Audio | Upload Count |
| `0x3500` | Device Info | Serial, Firmware |

---

## Detection Pipelines

### WiFi Detection Flow

```
Enable Promiscuous Mode
        ↓
Register Packet Callback
        ↓
Set Channel (1/6/11 rotation)
        ↓
    Packet Received?
        ↓ Yes
Validate Frame Type (MGMT)
        ↓
Extract: MAC (Addr2), SSID
        ↓
Match OUI or SSID Pattern?
        ↓ Yes
    🚨 DETECTION ALERT
```

### BLE Detection Flow (ESP32 / NimBLE)

```
Init NimBLE Stack
        ↓
Configure Scan (Active, 100ms)
        ↓
Start Scanning
        ↓
    onResult Callback
        ↓
Extract: MAC, Name, Service UUIDs
        ↓
Match MAC/Name/Raven UUID?
        ↓ Yes
    🚨 DETECTION ALERT
```

### BLE Detection Flow (Raspberry Pi / btmgmt — Production)

```
Kill orphaned btmgmt (sudo killall -q btmgmt)
        ↓
Wait 0.3s (kernel releases HCI)
        ↓
script -qc "sudo btmgmt --index 1 find -l" /dev/null
        ↓
Parse: regex extract MAC, type, RSSI, flags, name
        ↓
bt_tracker.update() → persist to bt_devices.json
        ↓
fingerprint_db.record(device_type="bluetooth")
        ↓
tracker.update(phy="ble") → Tier 1/2/3 alerts
        ↓
tri_engine.add_observation(signal_type="ble")
        ↓
SignalCorrelator → WiFi↔BLE clustering
        ↓
    🚨 DETECTION ALERT (if tier > 0)
```

### Unified Pipeline (WiFi + BT → Alerts + Correlation)

```
┌─ iw wlan1 scan ──────────┐     ┌─ fingerprint_db ─┐
│                           ├────→│ signal profiling  │
│                           │     └────────┬──────────┘
│ btmgmt find -l            │              ▼
│ (via script -qc)  ────────┘     ┌─ tracker ────────┐
│                                 │ persistence >30s  │
│                                 │ Tier 1/2/3 alerts │
│                                 └────────┬──────────┘
│                                          ▼
│                                 ┌─ tri_engine ──────┐
│                                 │ GPS + RSSI → pos  │
│                                 └────────┬──────────┘
│                                          ▼
│                                 ┌─ Correlator ──────┐
│                                 │ WiFi↔BLE clusters │
│                                 └───────────────────┘
```

---

## Key Commands

### Raspberry Pi Production Commands

```bash
# WiFi scan (production)
sudo iw wlan1 scan

# BT scan (production — MUST use script -qc under systemd)
script -qc "sudo /usr/bin/btmgmt --index 1 find -l" /dev/null

# Kill stale btmgmt (before each scan)
sudo killall -q btmgmt

# Check HCI state
hciconfig hci1
btmgmt --index 1 info

# Service management
sudo systemctl restart creeper-sweeper-webapp@<user>
journalctl -u creeper-sweeper-webapp@<user> -f

# Check for orphaned btmgmt
pgrep -la btmgmt

# Reset HCI (nuclear option)
sudo hciconfig hci1 reset

# Free occupied port after crash
sudo fuser -k 5000/tcp
```

### Linux Monitor Mode

```bash
# Enable monitor mode
sudo airmon-ng start wlan0
# or
sudo iw dev wlan0 set type monitor && sudo ip link set wlan0 up

# Set channel
sudo iw dev wlan0mon set channel 6

# Channel hopping (all 2.4GHz)
for ch in 1 2 3 4 5 6 7 8 9 10 11; do
  sudo iw dev wlan0mon set channel $ch
  sleep 0.1
done
```

### Kismet

```bash
# Start with WiFi source
kismet -c wlan0mon

# REST API query devices
curl http://localhost:2501/devices/all_devices.json

# Custom alert
kismet_server --override 'alert=FLOCK:ssidregex="FLOCK.*"'
```

### Scapy (Python)

```python
from scapy.all import *

# Basic WiFi sniff
sniff(iface="wlan0mon", filter="type mgt", prn=handler)

# SSID extraction
ssid = pkt[Dot11Elt].info.decode('utf-8', errors='ignore')
bssid = pkt[Dot11].addr3
rssi = pkt[RadioTap].dBm_AntSignal
```

### RTL-SDR / rtl_433

```bash
# ISM band monitor (433 MHz)
rtl_433 -F json

# Specific frequency
rtl_433 -f 915000000 -F json

# Output to file
rtl_433 -F json -F log:detections.json
```

### Airodump-ng

```bash
# Passive scan to CSV
airodump-ng --output-format csv -w scan wlan0mon

# Filter specific channel
airodump-ng -c 6 wlan0mon
```

---

## Hardware Pin Maps

### ESP32-S3 (Heltec WiFi LoRa 32 V3)

| Function | GPIO |
|----------|------|
| LoRa NSS | 8 |
| LoRa SCK | 9 |
| LoRa MOSI | 10 |
| LoRa MISO | 11 |
| LoRa RST | 12 |
| LoRa BUSY | 13 |
| LoRa DIO1 | 14 |
| OLED SDA | 17 |
| OLED SCL | 18 |
| OLED RST | 21 |
| Vext | 36 |

### INMP441 Microphone to ESP32

| INMP441 | GPIO |
|---------|------|
| SD (Data) | 4 |
| WS (LRCLK) | 5 |
| SCK (BCLK) | 6 |
| L/R | GND |

### OV2640 Camera (XIAO ESP32-S3 Sense)

| Function | GPIO |
|----------|------|
| PWDN | -1 (NC) |
| RESET | -1 (NC) |
| XCLK | 10 |
| SIOD | 40 |
| SIOC | 39 |
| Y9-Y2 | 48,11,12,14,16,18,17,15 |
| VSYNC | 38 |
| HREF | 47 |
| PCLK | 13 |

---

## Frequency Reference

### 2.4 GHz WiFi (Non-Overlapping)

| Channel | Frequency | Recommended |
|---------|-----------|-------------|
| 1 | 2412 MHz | ✅ |
| 6 | 2437 MHz | ✅ |
| 11 | 2462 MHz | ✅ |

### LoRa US915

| Use | Frequencies |
|-----|-------------|
| Uplink (125kHz) | 902.3 - 914.9 MHz |
| Uplink (500kHz) | 903.0 - 914.2 MHz |
| Downlink | 923.3 - 927.5 MHz |
| Meshtastic Default | 906.875 MHz |

### ISM Bands (RTL-SDR)

| Band | Region | Common Use |
|------|--------|------------|
| 315 MHz | US | Car remotes |
| 433.92 MHz | EU/US | Sensors, doorbells |
| 868 MHz | EU | LoRa, zigbee |
| 915 MHz | US | LoRa |

---

## Threat Scoring

### FLOCK-ER Meter Weights

| Factor | Weight | Description |
|--------|--------|-------------|
| Device Type Match | +25 | Known surveillance OUI/SSID |
| BLE Raven UUID | +30 | Raven service detected |
| Signal Strength | +5 | RSSI > -50 dBm (close) |
| Signal Strength | -10 | RSSI < -80 dBm (far) |
| Behavioral Anomaly | +15 | ML anomaly score > 0.7 |
| Timing Regularity | +10 | Regular beacon intervals |

### Threat Levels

| Score | Level | Action |
|-------|-------|--------|
| 90-100 | 🔴 Critical | Immediate alert |
| 70-89 | 🟡 High | Log + investigate |
| 50-69 | 🟢 Medium | Monitor |
| <50 | ⚪ Low | Baseline |

---

## RSSI Distance Estimation

```
Distance (m) ≈ 10^((TxPower - RSSI) / (10 * n))

n = path loss exponent:
  - 2.0: Free space
  - 2.5: Light indoor
  - 3.0: Dense indoor
  - 4.0: Heavy obstruction
```

| RSSI | Approx. Distance |
|------|------------------|
| -30 dBm | <1 m |
| -50 dBm | 3-5 m |
| -70 dBm | 10-20 m |
| -85 dBm | 30-50 m |
| -95 dBm | 50-100 m |

---

## Python Quick Snippets

### WiFi Surveillance Detector (Scapy)

```python
from scapy.all import *
SUSPICIOUS = ['FLOCK', 'RAVEN', 'PENGUIN']

def handler(pkt):
    if pkt.haslayer(Dot11Beacon):
        ssid = pkt[Dot11Elt].info.decode('utf-8', errors='ignore')
        if any(p in ssid.upper() for p in SUSPICIOUS):
            print(f"🚨 {ssid} ({pkt[Dot11].addr3})")

sniff(iface="wlan0mon", filter="type mgt subtype beacon", prn=handler)
```

### BLE Scanner (bleak)

```python
import asyncio
from bleak import BleakScanner

RAVEN_PREFIX = "00003"

async def scan():
    async for dev, adv in BleakScanner.find_device_by_filter(
        lambda d, a: any(str(u).startswith(RAVEN_PREFIX) for u in a.service_uuids or []),
        timeout=30
    ):
        print(f"🚨 Raven: {dev.address}")

asyncio.run(scan())
```

### btmgmt BLE Scanner (Raspberry Pi — Production)

```python
import re, subprocess

_DEV_RE = re.compile(
    r"hci\d+\s+dev_found:\s+(?P<mac>[0-9A-Fa-f:]{17})\s+"
    r"type\s+(?P<type>\S+(?:\s+\S+)?)\s+"
    r"rssi\s+(?P<rssi>-?\d+)\s+flags\s+(?P<flags>0x[0-9A-Fa-f]+)"
)

def bt_scan(hci_index=1, duration=8):
    # Kill orphans first
    subprocess.run(["sudo", "killall", "-q", "btmgmt"],
                   capture_output=True, timeout=3)
    # MUST use script -qc for PTY under systemd
    cmd = f"sudo /usr/bin/btmgmt --index {hci_index} find -l"
    r = subprocess.run(["script", "-qc", cmd, "/dev/null"],
                       capture_output=True, text=True, timeout=duration+10)
    devices = []
    for m in _DEV_RE.finditer(r.stdout):
        devices.append({
            "mac": m.group("mac").upper(),
            "type": m.group("type"),
            "rssi": int(m.group("rssi")),
        })
    return devices
```

---

## Companion Documents

| Document | Description |
|----------|-------------|
| [signals.md](signals.md) | Full RF signals reference (WiFi/BLE/SDR) |
| [signals-bt-implementation.md](signals-bt-implementation.md) | **btmgmt under systemd, PTY fix, pipeline integration** |
| [signals-kismet.md](signals-kismet.md) | Kismet architecture and REST API |
| [signals-acoustic.md](signals-acoustic.md) | ShotSpotter/Raven audio detection |
| [signals-lora-lpwan.md](signals-lora-lpwan.md) | LoRa sniffing and Meshtastic |
| [signals-ml-detection.md](signals-ml-detection.md) | ML anomaly detection |

---

### RTL-SDR ISM Monitor

```python
import subprocess, json

def monitor_ism(callback):
    proc = subprocess.Popen(['rtl_433', '-F', 'json'],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    for line in proc.stdout:
        try:
            callback(json.loads(line))
        except: pass

monitor_ism(lambda d: print(d.get('model', 'Unknown')))
```

---

## ESP32 Quick Code

### WiFi Promiscuous Mode

```cpp
void wifi_sniffer_init() {
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    esp_wifi_init(&cfg);
    esp_wifi_set_mode(WIFI_MODE_NULL);
    esp_wifi_start();
    esp_wifi_set_promiscuous(true);
    esp_wifi_set_promiscuous_rx_cb(sniffer_callback);
}
```

### BLE Scan (NimBLE)

```cpp
#include <NimBLEDevice.h>

class ScanCB : public NimBLEAdvertisedDeviceCallbacks {
    void onResult(NimBLEAdvertisedDevice* dev) {
        if (dev->haveServiceUUID() && 
            dev->getServiceUUID().toString().find("00003") != std::string::npos) {
            Serial.printf("Raven: %s\n", dev->getAddress().toString().c_str());
        }
    }
};

void setup() {
    NimBLEDevice::init("");
    auto scan = NimBLEDevice::getScan();
    scan->setAdvertisedDeviceCallbacks(new ScanCB());
    scan->setActiveScan(true);
    scan->start(0);  // Continuous
}
```

---

## Creeper Sweeper Implementation Quick Reference

### Correlation Engine — Multi-Dimensional Clustering (6 Phases)

| Phase | Name | Cluster Type | Key Logic |
|-------|------|--------------|-----------|
| 1 | Manufacturer + RSSI | `mfr-` | Group by OUI vendor → RSSI band sub-cluster (`RSSI_GAP_TARGET`) |
| 2 | PNL Fingerprint | `pnl-` | Jaccard similarity ≥ 0.5 on directed probe SSIDs |
| 3 | Randomized MAC | `rand-` | LA-bit MACs with shared SSIDs → merge |
| 4 | Bluetooth | `btn-`, `btr-` | Name prefix rules + RSSI band sub-clusters |
| 5 | WiFi↔BT Cross-Link | `xlink-` | OUI(0.35) + RSSI(0.25) + Name(0.30) scoring |
| 6 | Cross-Vendor PNL | `pnlxv-` | Same PNL hash or exact name across vendors |

### RSSI Convergence Parameters

| Param | Value |
|-------|-------|
| Formula | $\text{gap}(n) = 1.0 + 19.0 \times 0.92^n$ |
| WiFi target | 1.0 dBm (`RSSI_GAP_TARGET`) |
| BT target | 5.0 dBm (`RSSI_GAP_TARGET + 4`) |
| Decay rate | 0.92 |
| Start gap | 20.0 dBm |
| Converges at | Step 36 (~36 minutes) |

> **Pure exponential** — no oscillation, monotonically decreasing.

### Alert Tiers

| Tier | Name | Sound | Auto-Dismiss |
|------|------|-------|------|
| 1 | NEW_DEVICE | 660Hz sine, 0.3s | 5s |
| 2 | PERSIST | Double 880Hz, 0.2s ea | 5s |
| 3 | SURVEILLANCE | Sawtooth siren 440→1200Hz | Manual |
| 4 | WATCH_ALERT | C5-E5-G5 arpeggio | 5s |

### Watch Alert Match Types (7)

| Type | Matches Against |
|------|-----------------|
| `mac` | detection.mac (exact) |
| `oui` | detection.mac[:8] (OUI prefix) |
| `friendly_name` | detection.friendly_name (substring) |
| `device_name` | detection.device_name (substring) |
| `ssid` | detection.ssid (substring) |
| `manufacturer` | detection.manufacturer (substring) |
| `pnl_hash` | detection.pnl_hash (exact) |

### Persistence Files

| File | Purpose |
|------|---------|
| `~/.local/share/creeper-sweeper/fingerprints.json` | Device fingerprint database |
| `~/.local/share/creeper-sweeper/ignore_list.json` | 4-pane: MAC, OUI, SSID, device_name |
| `~/.local/share/creeper-sweeper/watchlist.json` | Named watch alert configs (7 match types) |
| `~/.local/share/creeper-sweeper/settings.json` | Scan params, audio, thresholds (7 fields) |
| `~/.local/share/creeper-sweeper/signal_correlations.json` | Multi-dimensional cluster state |
| `~/.local/share/creeper-sweeper/pnl_profiles.json` | PNL fingerprint profiles |
| `~/.local/share/creeper-sweeper/bt_devices.json` | Bluetooth device state |
| `~/.local/share/creeper-sweeper/gps_log.json` | GPS coordinate track log |
| `~/.local/share/creeper-sweeper/alert_history.json` | Tiered alert history |
| `~/.local/share/creeper-sweeper/ssid_groups.json` | SSID group tracker |
| `~/.local/share/creeper-sweeper/triangulation.json` | Multi-node position results |

### Deploy Command

```bash
bash webapp/deploy.sh <PI_IP> <HOSTNAME>
# e.g. bash webapp/deploy.sh 192.168.1.243 pedicure-recognize-stress7
```

### Companion Documents — Implementation

| Document | Coverage |
|----------|----------|
| [Architecture](signals-architecture.md) | System design, pipeline, threading |
| [Correlation Engine](signals-correlation-engine.md) | Scoring, convergence, clustering |
| [Data Models](signals-data-models.md) | Schemas, REST API, WebSocket events |
| [Deployment](signals-deployment.md) | Pi setup, systemd, CI/CD |
| [Frontend](signals-frontend.md) | Tabs, modals, audio, rendering |
| [BT Implementation](signals-bt-implementation.md) | btmgmt PTY, HCI lifecycle |

---

## Resources

| Resource | URL |
|----------|-----|
| ESP-IDF WiFi | docs.espressif.com/projects/esp-idf |
| NimBLE-Arduino | github.com/h2zero/NimBLE-Arduino |
| Kismet | kismetwireless.net |
| Scapy | scapy.net |
| rtl_433 | github.com/merbanan/rtl_433 |
| WiGLE | wigle.net |
| IEEE OUI | standards-oui.ieee.org |
| DeFlock.me | deflock.me |

---

*Quick Reference v3.0 | 2026-02-08 | Creeper Sweeper*
*Updated: Multi-dimensional clustering, pure exponential convergence, 7 watch types, correct persistence paths*
