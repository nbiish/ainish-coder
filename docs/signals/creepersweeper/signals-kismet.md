# Signals Kismet Wireless Monitoring: Expert Technical Reference

> **Beyond Expert-Level Guide to Kismet Wireless Detection & Intrusion Detection**
>
> Part of the **signals detection** knowledge base — covering Kismet architecture, advanced configuration, REST API automation, custom alerts, and integration with surveillance detection pipelines.
>
> **Companion documents**: [Signals Detection](signals.md) — WiFi/BLE | [Signals Voice Assistant](signals-voice-assistant.md) — Voice AI integration

---

## Table of Contents

1. [Kismet Architecture](#1-kismet-architecture)
2. [Installation & Setup](#2-installation--setup)
3. [Data Sources Configuration](#3-data-sources-configuration)
4. [Advanced Configuration](#4-advanced-configuration)
5. [REST API & Automation](#5-rest-api--automation)
6. [Custom Alerts & IDS Rules](#6-custom-alerts--ids-rules)
7. [Remote Capture](#7-remote-capture)
8. [GPS & Logging](#8-gps--logging)
9. [Surveillance Detection Integration](#9-surveillance-detection-integration)
10. [Python Integration](#10-python-integration)

---

## 1. Kismet Architecture

### 1.1 Component Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Kismet Architecture                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌───────────────────────────────────────────────────────────────┐ │
│   │                    kismet_server                               │ │
│   │  - Core packet processing                                      │ │
│   │  - Device tracking (WiFi, BLE, Zigbee, etc.)                  │ │
│   │  - Alert engine                                                │ │
│   │  - Database (SQLite - kismetdb)                               │ │
│   │  - REST API (HTTP/HTTPS on port 2501)                         │ │
│   │  - WebSocket streaming                                         │ │
│   └───────────────────────────┬───────────────────────────────────┘ │
│                               │                                      │
│         ┌─────────────────────┼─────────────────────┐               │
│         │                     │                     │               │
│   ┌─────▼─────┐        ┌──────▼──────┐       ┌─────▼─────┐         │
│   │ Data Src  │        │  Data Src   │       │ Data Src  │         │
│   │  WiFi     │        │    BLE      │       │   SDR     │         │
│   │(wlan0mon) │        │  (hci0)     │       │ (rtl-sdr) │         │
│   └───────────┘        └─────────────┘       └───────────┘         │
│                                                                      │
│   ┌───────────────────────────────────────────────────────────────┐ │
│   │                      Web UI                                    │ │
│   │              http://localhost:2501                             │ │
│   │  - Device browser, alerts dashboard, GPS mapping               │ │
│   └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Key Concepts

| Concept | Description |
|---------|-------------|
| **Data Source** | Hardware interface providing packets (WiFi, BLE, SDR) |
| **Device** | Tracked entity (AP, client, BLE peripheral) |
| **PHY** | Physical layer type (802.11, BT, Zigbee) |
| **kismetdb** | SQLite database storing all captured data |
| **Alert** | Triggered event (anomaly, pattern match) |
| **DPKG** | Device packet group — aggregated device stats |

---

## 2. Installation & Setup

### 2.1 Package Installation

**Debian/Ubuntu/Kali:**
```bash
# Add Kismet repository
wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key | sudo apt-key add -
echo 'deb https://www.kismetwireless.net/repos/apt/release/$(lsb_release -cs) $(lsb_release -cs) main' | sudo tee /etc/apt/sources.list.d/kismet.list

# Install
sudo apt update
sudo apt install kismet

# Add user to kismet group (avoid running as root)
sudo usermod -aG kismet $USER
newgrp kismet
```

**macOS:**
```bash
brew install kismet
```

**From Source:**
```bash
git clone https://www.kismetwireless.net/git/kismet.git
cd kismet
./configure
make -j$(nproc)
sudo make suidinstall
```

### 2.2 Initial Configuration

```bash
# First run - create admin user
kismet

# Web UI prompts for username/password
# Access at http://localhost:2501
```

### 2.3 Directory Structure

| Path | Purpose |
|------|---------|
| `/etc/kismet/` | System configuration |
| `~/.kismet/` | User configuration |
| `~/.kismet/kismet.conf` | User overrides |
| `/var/log/kismet/` | Log files |
| `./Kismet-*.kismet` | Session database (kismetdb) |

---

## 3. Data Sources Configuration

### 3.1 WiFi Data Source

```bash
# Auto-detect and add WiFi in monitor mode
kismet -c wlan0

# With specific options
kismet -c wlan0:name=monitor1,hop=true,hop_rate=5/sec

# Multiple sources
kismet -c wlan0mon -c wlan1mon
```

**Data Source Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `name=X` | interface | Human-readable name |
| `hop=true/false` | true | Channel hopping |
| `hop_rate=N/sec` | 5/sec | Hop frequency |
| `channel=N` | auto | Lock to channel |
| `channels=1,6,11` | all | Specific channels to hop |
| `ht_channels=true` | true | Include HT20/HT40 |
| `vht_channels=true` | true | Include VHT80/160 |

### 3.2 BLE Data Source

```bash
# Linux BLE (requires bluez)
kismet -c hci0:name=bluetooth

# With remote capture helper
kismet_cap_linux_bluetooth --connect localhost:3501 --source hci0
```

### 3.3 RTL-SDR Data Source

```bash
# RTL-433 for ISM band
kismet -c rtl433-0:name=ism_band

# RTL-ADSB for aircraft
kismet -c rtladsb-0:name=adsb
```

### 3.4 Source Configuration in kismet.conf

```conf
# /etc/kismet/kismet.conf or ~/.kismet/kismet.conf

# Primary WiFi source
source=wlan0:name=main_wifi,hop=true,hop_rate=5/sec

# Locked channel for IDS
source=wlan1:name=ids_channel6,hop=false,channel=6

# BLE scanning
source=hci0:name=bluetooth

# RTL-SDR
source=rtl433-0:name=ism_devices
```

---

## 4. Advanced Configuration

### 4.1 Key Configuration Directives

Create `~/.kismet/kismet_site.conf` for overrides:

```conf
# Server settings
server_name=signals-monitor
listen=0.0.0.0:2501

# Logging
log_prefix=/var/log/kismet/
log_types=kismet,pcapng,wiglecsv

# Performance tuning
max_datasources=10
max_devices=50000
device_expiry=86400

# Alert throttling
alert_rate=10/min
alert_burst=50

# GPS (if using gpsd)
gps=gpsd:host=localhost,port=2947

# UI options
httpd_home=/usr/share/kismet/httpd/
httpd_mime_types=/etc/kismet/httpd_mime_types

# API authentication
httpd_auth=true
httpd_session_timeout=7200
```

### 4.2 Memory Optimization

```conf
# Reduce memory for Raspberry Pi
tracker_device_timeout=3600
tracker_max_devices=10000
dot11_fingerprint_cache=false
dot11_keep_eapol=false
dot11_keep_ie_tags=false
```

### 4.3 Channel Hopping Strategies

```conf
# Fast hopping for detection
channel_hop=true
channel_hop_rate=10/sec

# IDS mode - lock to primary channels
channel_hop=false
channel=6

# Custom channel list (2.4 GHz only)
channel_list=1,2,3,4,5,6,7,8,9,10,11
```

---

## 5. REST API & Automation

### 5.1 API Authentication

```bash
# Get API key from first login or config
cat ~/.kismet/kismet_httpd.conf
# api_key=YOUR_API_KEY_HERE

# Or use session cookie
curl -c cookies.txt -b cookies.txt \
  -X POST http://localhost:2501/session/check_login \
  -d "username=admin&password=yourpass"
```

### 5.2 Key API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/system/status.json` | GET | Server status |
| `/devices/all_devices.json` | GET | All tracked devices |
| `/devices/by-key/{key}/device.json` | GET | Single device |
| `/datasource/list_sources.json` | GET | Data source list |
| `/datasource/add_source.cmd` | POST | Add new source |
| `/alerts/all_alerts.json` | GET | All alerts |
| `/gps/location.json` | GET | Current GPS position |
| `/phy/phy80211/ssid_regex/{regex}.json` | GET | SSID search |

### 5.3 API Examples

**Get All WiFi Devices:**
```bash
curl -H "KISMET: YOUR_API_KEY" \
  "http://localhost:2501/devices/views/phydot11_accesspoints/devices.json"
```

**Search for Surveillance SSIDs:**
```bash
curl -H "KISMET: YOUR_API_KEY" \
  "http://localhost:2501/devices/views/phydot11_accesspoints/devices.json" \
  | jq '.[] | select(.["kismet.device.base.name"] | test("FLOCK|PENGUIN"; "i"))'
```

**Add Data Source:**
```bash
curl -H "KISMET: YOUR_API_KEY" \
  -X POST http://localhost:2501/datasource/add_source.cmd \
  -d "definition=wlan1:name=secondary,hop=true"
```

**Subscribe to Device Updates (WebSocket):**
```javascript
const ws = new WebSocket('ws://localhost:2501/eventbus/events.ws');
ws.onopen = () => {
    ws.send(JSON.stringify({
        "SUBSCRIBE": "DEVICE",
        "fields": ["kismet.device.base.macaddr", "kismet.device.base.signal"]
    }));
};
ws.onmessage = (evt) => console.log(JSON.parse(evt.data));
```

### 5.4 Python API Client

```python
import requests
from typing import Optional, List, Dict

class KismetClient:
    def __init__(self, host: str = "localhost", port: int = 2501, api_key: str = ""):
        self.base_url = f"http://{host}:{port}"
        self.headers = {"KISMET": api_key}
    
    def get_status(self) -> Dict:
        return self._get("/system/status.json")
    
    def get_devices(self, phy: Optional[str] = None) -> List[Dict]:
        if phy == "wifi":
            return self._get("/devices/views/phydot11_accesspoints/devices.json")
        elif phy == "bluetooth":
            return self._get("/devices/views/phy-btle/devices.json")
        return self._get("/devices/all_devices.json")
    
    def search_ssid(self, pattern: str) -> List[Dict]:
        devices = self.get_devices("wifi")
        import re
        regex = re.compile(pattern, re.IGNORECASE)
        return [d for d in devices if regex.search(d.get("kismet.device.base.name", ""))]
    
    def get_alerts(self) -> List[Dict]:
        return self._get("/alerts/all_alerts.json")
    
    def get_gps(self) -> Dict:
        return self._get("/gps/location.json")
    
    def add_source(self, definition: str) -> Dict:
        return self._post("/datasource/add_source.cmd", {"definition": definition})
    
    def _get(self, endpoint: str) -> Dict:
        resp = requests.get(f"{self.base_url}{endpoint}", headers=self.headers)
        resp.raise_for_status()
        return resp.json()
    
    def _post(self, endpoint: str, data: Dict) -> Dict:
        resp = requests.post(f"{self.base_url}{endpoint}", headers=self.headers, data=data)
        resp.raise_for_status()
        return resp.json()

# Usage
client = KismetClient(api_key="your_api_key_here")
surveillance = client.search_ssid("FLOCK|PENGUIN|RAVEN")
for device in surveillance:
    print(f"🚨 {device['kismet.device.base.name']} - {device['kismet.device.base.macaddr']}")
```

---

## 6. Custom Alerts & IDS Rules

### 6.1 Built-in Alert Types

| Alert | Description | Surveillance Use |
|-------|-------------|------------------|
| `APSPOOF` | Multiple APs with same SSID | Detect rogue APs |
| `BSSTIMESTAMP` | BSS timestamp anomaly | Detect AP clones |
| `CHANCHANGE` | AP changed channel | Track mobile surveillance |
| `CRYPTCHANGE` | Encryption change | Security monitoring |
| `DEAUTHFLOOD` | Deauth attack | Detect jamming |
| `DISASSOCIATION` | Disassoc flood | Detect jamming |
| `PROBENORESP` | Probe with no response | Hidden AP detection |

### 6.2 Custom Alert Definition

```conf
# ~/.kismet/kismet_site.conf

# Alert on FLOCK SSID pattern
alert=FLOCK:ssidregex="^FLOCK.*":rate=1/min:burst=5

# Alert on FS battery MAC OUI
alert=FSBATTERY:macregex="^58:8E:81.*":rate=1/min:burst=5

# Alert on strong unknown signal (close device)
alert=CLOSEDEVICE:signal_db>-40:rate=10/sec:burst=20
```

### 6.3 IDS Configuration

For intrusion detection, use non-hopping, channel-locked sources:

```conf
# Dedicated IDS source on channel 6
source=wlan1:name=ids_ch6,hop=false,channel=6

# Enable stationary mode (improves IDS accuracy)
gps_connection=none

# Enable all IDS alerts
alertenable=*

# Custom surveillance detection
alert=SURVEILLANCE:ssidregex="FLOCK|PENGUIN|RAVEN|PIGVISION":rate=1/min:burst=10
```

### 6.4 Alert Webhook Integration

```python
#!/usr/bin/env python3
"""Kismet alert webhook handler"""

import requests
import json
from flask import Flask, request

app = Flask(__name__)

SURVEILLANCE_PATTERNS = ["FLOCK", "PENGUIN", "RAVEN", "FS_"]

@app.route('/kismet/alert', methods=['POST'])
def handle_alert():
    alert = request.json
    
    ssid = alert.get("kismet.device.base.name", "")
    mac = alert.get("kismet.device.base.macaddr", "")
    
    for pattern in SURVEILLANCE_PATTERNS:
        if pattern in ssid.upper():
            # High priority alert
            send_notification(f"⚠️ SURVEILLANCE: {ssid} ({mac})")
            return {"status": "alerted"}
    
    return {"status": "ignored"}

def send_notification(message):
    # Send to your notification service
    print(message)
    # requests.post("https://your-webhook.com", json={"text": message})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
```

---

## 7. Remote Capture

### 7.1 Remote Capture Architecture

```
┌──────────────────┐          ┌──────────────────┐
│  Remote Device   │          │  Kismet Server   │
│  (Raspberry Pi)  │   TCP    │  (Main Host)     │
│                  │ ───────► │                  │
│ kismet_cap_*     │  :3501   │  kismet_server   │
│ (capture helper) │          │  (REST API)      │
└──────────────────┘          └──────────────────┘
```

### 7.2 Remote Capture Setup

**On Capture Device:**
```bash
# WiFi remote capture
kismet_cap_linux_wifi --connect kismet-server.local:3501 --source wlan0

# BLE remote capture
kismet_cap_linux_bluetooth --connect kismet-server.local:3501 --source hci0

# With auto-reconnect
kismet_cap_linux_wifi --connect kismet-server.local:3501 \
  --source wlan0 --retry-interval 10
```

**On Server:**
```conf
# kismet_site.conf - allow remote sources
remote_capture_port=3501
remote_capture_allowed=192.168.1.0/24

# Named remote source
source=tcp://capture-pi:3501:name=remote_wifi
```

### 7.3 Systemd Service for Remote Capture

```ini
# /etc/systemd/system/kismet-remote-wifi.service
[Unit]
Description=Kismet Remote WiFi Capture
After=network.target

[Service]
Type=simple
User=kismet
ExecStartPre=/usr/bin/iw dev wlan0 set type monitor
ExecStart=/usr/bin/kismet_cap_linux_wifi \
  --connect kismet-server.local:3501 \
  --source wlan0:name=remote-pi \
  --retry-interval 10
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

---

## 8. GPS & Logging

### 8.1 GPS Configuration

```conf
# Use gpsd
gps=gpsd:host=localhost,port=2947

# Use serial GPS directly
gps=serial:device=/dev/ttyUSB0,baud=9600

# Disable GPS (stationary mode - better for IDS)
gps=none
```

### 8.2 Log Types

| Log Type | Extension | Content |
|----------|-----------|---------|
| `kismet` | `.kismet` | SQLite database (all data) |
| `pcapng` | `.pcapng` | Raw packets (Wireshark) |
| `wiglecsv` | `.csv` | WiGLE upload format |
| `alert` | `.alert.json` | Alert log |

```conf
# Enable specific log types
log_types=kismet,pcapng,wiglecsv,alert

# Log file prefix
log_prefix=/var/log/kismet/scan_

# Rotate logs daily
log_new_file_on_start=true
```

### 8.3 kismetdb Queries

```sql
-- Query devices with surveillance patterns
SELECT 
    devmac,
    type,
    json_extract(device, '$.kismet.device.base.name') as ssid,
    json_extract(device, '$.kismet.device.base.signal.kismet.common.signal.last_signal') as rssi
FROM devices
WHERE json_extract(device, '$.kismet.device.base.name') LIKE '%FLOCK%'
   OR json_extract(device, '$.kismet.device.base.name') LIKE '%PENGUIN%';

-- Get all alerts
SELECT * FROM alerts ORDER BY ts_sec DESC LIMIT 100;

-- Export to CSV
.mode csv
.output surveillance_devices.csv
SELECT * FROM devices WHERE json_extract(device, '$.kismet.device.base.name') LIKE '%FLOCK%';
.output stdout
```

---

## 9. Surveillance Detection Integration

### 9.1 Combined Detection Script

```python
#!/usr/bin/env python3
"""Kismet + Custom Detection Pipeline"""

import time
import re
from kismet_client import KismetClient

SURVEILLANCE_PATTERNS = {
    "FLOCK": {"type": "ALPR Camera", "threat": 95},
    "PENGUIN": {"type": "Surveillance Camera", "threat": 90},
    "RAVEN": {"type": "ShotSpotter", "threat": 100},
    "FS_": {"type": "Flock Battery", "threat": 85},
}

SURVEILLANCE_MACS = {
    "58:8E:81": {"type": "Flock Battery", "threat": 85},
    "00:1A:79": {"type": "Flock Network", "threat": 80},
}

class SurveillanceMonitor:
    def __init__(self, kismet_api_key: str):
        self.kismet = KismetClient(api_key=kismet_api_key)
        self.seen_devices = set()
        self.detections = []
    
    def check_device(self, device: dict) -> dict | None:
        ssid = device.get("kismet.device.base.name", "")
        mac = device.get("kismet.device.base.macaddr", "")
        mac_prefix = mac[:8].upper().replace(":", "")[:6]
        rssi = device.get("kismet.device.base.signal", {}).get(
            "kismet.common.signal.last_signal", -100
        )
        
        # Check SSID patterns
        for pattern, info in SURVEILLANCE_PATTERNS.items():
            if pattern in ssid.upper():
                return {
                    "mac": mac,
                    "ssid": ssid,
                    "rssi": rssi,
                    "type": info["type"],
                    "threat": info["threat"],
                    "match": f"SSID:{pattern}"
                }
        
        # Check MAC OUI
        for oui, info in SURVEILLANCE_MACS.items():
            oui_normalized = oui.replace(":", "")
            if mac_prefix.startswith(oui_normalized):
                return {
                    "mac": mac,
                    "ssid": ssid,
                    "rssi": rssi,
                    "type": info["type"],
                    "threat": info["threat"],
                    "match": f"MAC:{oui}"
                }
        
        return None
    
    def scan(self):
        devices = self.kismet.get_devices("wifi")
        
        for device in devices:
            mac = device.get("kismet.device.base.macaddr", "")
            
            if mac in self.seen_devices:
                continue
            
            detection = self.check_device(device)
            if detection:
                self.seen_devices.add(mac)
                self.detections.append(detection)
                self.alert(detection)
    
    def alert(self, detection: dict):
        print(f"🚨 SURVEILLANCE DETECTED!")
        print(f"   Type: {detection['type']}")
        print(f"   SSID: {detection['ssid']}")
        print(f"   MAC:  {detection['mac']}")
        print(f"   RSSI: {detection['rssi']} dBm")
        print(f"   Threat: {detection['threat']}/100")
        print(f"   Match: {detection['match']}")
    
    def run(self, interval: float = 5.0):
        print("Starting surveillance monitoring...")
        while True:
            try:
                self.scan()
            except Exception as e:
                print(f"Error: {e}")
            time.sleep(interval)

if __name__ == "__main__":
    import os
    api_key = os.environ.get("KISMET_API_KEY", "")
    monitor = SurveillanceMonitor(api_key)
    monitor.run()
```

---

## 10. Python Integration

### 10.1 kismet-python Library

```bash
pip install kismet-rest
```

```python
from kismet_rest import KismetConnector

# Connect
kismet = KismetConnector(host="localhost", port=2501)
kismet.set_login(username="admin", password="yourpass")

# Get devices
for device in kismet.device_summary():
    print(device['kismet.device.base.macaddr'])

# Live event stream
def on_device(device):
    print(f"New device: {device['kismet.device.base.macaddr']}")

kismet.subscribe_device_updates(on_device)
```

### 10.2 WebSocket Streaming

```python
import asyncio
import websockets
import json

async def kismet_stream(api_key: str):
    uri = "ws://localhost:2501/eventbus/events.ws"
    
    async with websockets.connect(uri) as ws:
        # Authenticate
        await ws.send(json.dumps({
            "KISMET": api_key
        }))
        
        # Subscribe to devices
        await ws.send(json.dumps({
            "SUBSCRIBE": "DEVICE",
            "fields": [
                "kismet.device.base.macaddr",
                "kismet.device.base.name",
                "kismet.device.base.signal"
            ]
        }))
        
        # Process events
        async for message in ws:
            data = json.loads(message)
            if data.get("DEVICE"):
                process_device(data["DEVICE"])

def process_device(device: dict):
    ssid = device.get("kismet.device.base.name", "")
    if "FLOCK" in ssid.upper():
        print(f"🚨 FLOCK DETECTED: {ssid}")

asyncio.run(kismet_stream("your_api_key"))
```

---

## Quick Reference Card

### Essential Commands

| Task | Command |
|------|---------|
| Start Kismet | `kismet -c wlan0mon` |
| Add source | `kismet -c wlan1:name=secondary` |
| Lock channel | `kismet -c wlan0:hop=false,channel=6` |
| Remote capture | `kismet_cap_linux_wifi --connect server:3501 --source wlan0` |

### API Quick Reference

| Endpoint | Purpose |
|----------|---------|
| `/system/status.json` | Server status |
| `/devices/all_devices.json` | All devices |
| `/devices/views/phydot11_accesspoints/devices.json` | WiFi APs only |
| `/alerts/all_alerts.json` | All alerts |
| `/gps/location.json` | GPS position |

### Key Directories

| Path | Purpose |
|------|---------|
| `/etc/kismet/` | System config |
| `~/.kismet/` | User config |
| `./Kismet-*.kismet` | Session DB |

---

## Resources & References

### Official
- **Kismet Documentation**: https://www.kismetwireless.net/docs/
- **Kismet REST API**: https://www.kismetwireless.net/docs/api/
- **Kismet GitHub**: https://github.com/kismetwireless/kismet

### Community
- **kismet-python**: https://github.com/kismetwireless/kismet-python
- **Wardriving with Kismet**: https://wigle.net

---

*Document Version: 1.0 | Created: 2026-02-06 | Part of ainish-coder signals detection suite*
