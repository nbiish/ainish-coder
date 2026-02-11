# Deployment, Setup & Orchestration Guide

> **Complete guide to deploying Creeper Sweeper on a Raspberry Pi 5,
> including hardware setup, systemd services, deploy automation,
> diagnostics, CI/CD, and troubleshooting.**
>
> **Companion documents**:
> - [Hardware](signals-hardware.md) — USB auto-detection, driver setup
> - [BT Implementation](signals-bt-implementation.md) — btmgmt PTY fix
> - [Architecture](signals-architecture.md) — System design

---

## Table of Contents

1. [Target Platform](#1-target-platform)
2. [Hardware Stack](#2-hardware-stack)
3. [Initial Pi Setup](#3-initial-pi-setup)
4. [Software Installation](#4-software-installation)
5. [Environment Configuration](#5-environment-configuration)
6. [Systemd Service Architecture](#6-systemd-service-architecture)
7. [Deployment Automation](#7-deployment-automation)
8. [GPS & gpsd Configuration](#8-gps--gpsd-configuration)
9. [Bluetooth Firmware & HCI](#9-bluetooth-firmware--hci)
10. [WiFi Monitor Mode](#10-wifi-monitor-mode)
11. [Kismet Integration](#11-kismet-integration)
12. [Log Management](#12-log-management)
13. [Diagnostics & Health Checks](#13-diagnostics--health-checks)
14. [Troubleshooting Playbook](#14-troubleshooting-playbook)
15. [CI/CD Pipeline](#15-cicd-pipeline)
16. [Development Workflow](#16-development-workflow)
17. [Backup & Recovery](#17-backup--recovery)
18. [Network & Security](#18-network--security)

---

## 1. Target Platform

| Component | Specification |
|-----------|--------------|
| Board | Raspberry Pi 5 (4GB+ RAM) |
| OS | Raspberry Pi OS (Debian Bookworm) |
| Python | ≥ 3.11 |
| Power | 5V/5A USB-C (official Pi 5 PSU) |
| Storage | 32GB+ microSD (64GB recommended) |
| Network | Onboard WiFi (wlan0) for LAN connectivity |

---

## 2. Hardware Stack

| Role | Device | USB VID:PID | Interface | Driver |
|------|--------|-------------|-----------|--------|
| WiFi Scanner | Panda PAU0B (MT7610U) | `0e8d:7610` | wlan1 (monitor mode) | mt76x0u |
| WiFi Network | BCM43455 (onboard) | — | wlan0 | brcmfmac |
| BT Scanner | Hakimonoe RTL8761BU | `0bda:a728` | hci1 | btusb, btrtl |
| BT System | BCM4345C0 (onboard) | — | hci0 | — |
| GPS | U-blox 7 USB | `1546:01a7` | /dev/ttyACM0 → /dev/gps0 | cdc_acm |

### USB Power Budget

The Pi 5 provides 1.6A total across all USB ports (can be increased with
`usb_max_current_enable=1` in `config.txt` to 3A with the official PSU).

| Device | Current Draw |
|--------|-------------|
| MT7610U (WiFi) | ~300mA (USB 3.0 required) |
| RTL8761BU (BT) | ~50mA |
| U-blox 7 (GPS) | ~50mA |
| **Total** | **~400mA** ✅ |

---

## 3. Initial Pi Setup

### Raspberry Pi Imager Configuration

1. Flash Raspberry Pi OS Lite (64-bit) using Raspberry Pi Imager
2. Enable SSH in imager settings
3. Set hostname, username, password
4. Configure WiFi (home network SSID/password)

### First Boot

```bash
# SSH into Pi
ssh <user>@<hostname>.local

# Update system
sudo apt update && sudo apt full-upgrade -y

# Install core dependencies
sudo apt install -y \
    python3-dev python3-pip python3-venv \
    gpsd gpsd-clients \
    bluetooth bluez btmgmt \
    iw wireless-tools \
    git usbutils \
    libffi-dev libssl-dev

# Set timezone
sudo timedatectl set-timezone America/New_York
sudo timedatectl set-ntp true

# Add user to required groups
sudo usermod -aG dialout,bluetooth,netdev $USER
```

### USB adapter verification

```bash
# List USB devices
lsusb

# Expected output includes:
# Bus 001 Device 003: ID 0e8d:7610 MediaTek Inc.
# Bus 001 Device 004: ID 0bda:a728 Realtek Semiconductor Corp.
# Bus 001 Device 005: ID 1546:01a7 U-Blox AG

# Verify WiFi
iw dev
# Should show wlan0 (onboard) and wlan1 (USB)

# Verify BT
hciconfig -a
# Should show hci0 (onboard) and hci1 (USB)

# Verify GPS
ls -la /dev/ttyACM*
# Should show /dev/ttyACM0
```

---

## 4. Software Installation

### From Repository

```bash
cd ~
git clone <repository-url> creeper-sweeper
cd creeper-sweeper

# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install package (editable mode for development)
pip install -e .
```

### Via install.sh

```bash
cd ~/creeper-sweeper
bash install.sh
```

This script:
1. Creates `.venv` if not present
2. Activates and runs `pip install -e .`
3. Creates `~/bin/creeper-sweeper` and `~/bin/creeper-sweeper-gui` wrappers
4. Installs `.desktop` launcher for Pi desktop
5. Optionally configures mDNS/Avahi

### Verify Installation

```bash
# CLI available?
creeper-sweeper --help

# Hardware detection
creeper-sweeper hw-detect

# Start dashboard locally (for testing)
creeper-sweeper webapp --host 0.0.0.0 --port 5000
```

---

## 5. Environment Configuration

### `.env` File (Complete Reference)

```bash
# === Network / Identity ===
PI_HOSTNAME=creeper-sweeper
PI_USER=pi
WIFI_SSID=YourNetworkSSID
WIFI_PASSWORD=YourNetworkPassword

# === Kismet ===
KISMET_USERNAME=kismet
KISMET_PASSWORD=your-kismet-password
KISMET_HOST=localhost
KISMET_PORT=2501

# === Web Dashboard ===
CREEPER_SECRET_KEY=<secrets.token_hex(32)>
CREEPER_ADMIN_USER=admin
CREEPER_ADMIN_PASSWORD=<strong-password>
CREEPER_HOST=0.0.0.0
CREEPER_PORT=5000
CREEPER_LOG_LEVEL=INFO

# === WiFi Interfaces ===
WIFI_IFACE_NETWORK=wlan0
WIFI_IFACE_MONITOR=wlan1

# === Detection Thresholds ===
CREEPER_PERSIST_THRESHOLD=5          # Seconds for Tier 2 alert
CREEPER_SCAN_INTERVAL=3              # WiFi scan cycle (seconds)
CREEPER_MIN_RSSI=-127                # -127 = no limit
CREEPER_ALERT_COOLDOWN=60            # Per-MAC cooldown (seconds)

# === Alert Channels ===
CREEPER_ALERT_CONSOLE=true
CREEPER_ALERT_SOUND=true
CREEPER_ALERT_LOG=true
CREEPER_ALERT_WEBHOOK=false
CREEPER_WEBHOOK_URL=
CREEPER_WEBHOOK_SECRET=

# === Timezone ===
TZ=America/New_York
CREEPER_TIMEZONE=America/New_York

# === GPS ===
GPS_DEVICE=/dev/ttyACM0
GPS_BAUD=9600
GPS_USE_GPSD=true
GPSD_HOST=127.0.0.1
GPSD_PORT=2947
GPS_LOG_INTERVAL=10
MAX_GPS_LOG_ENTRIES=5000

# === Bluetooth ===
BT_HCI_INDEX=1
BT_SCAN_DURATION=8
BT_SCAN_INTERVAL=10
MAX_BT_DEVICES=500
MAX_BT_RSSI_HISTORY=50
BT_STALE_TIMEOUT=600
BTMGMT_PATH=/usr/bin/btmgmt

# === Triangulation ===
TRIANGULATION_WINDOW=30
MAX_OBSERVATIONS_PER_MAC=100
MAX_TRACKED_MACS=1000
RSSI_REF=-40
PATH_LOSS_EXP=3.0
```

### Settings Persistence

Runtime settings (scan_interval, persist_threshold, min_rssi, sound_enabled,
popup_enabled) are persisted to `DATA_DIR/settings.json` and loaded on startup.
Values from settings.json override .env defaults.

---

## 6. Systemd Service Architecture

### Template Unit (supports per-user instances)

```ini
# /etc/systemd/system/creeper-sweeper-webapp@.service
[Unit]
Description=Creeper Sweeper Web Dashboard (%i)
After=network-online.target bluetooth.target gpsd.service
Wants=network-online.target bluetooth.target

[Service]
Type=simple
User=%i
WorkingDirectory=/home/%i/creeper-sweeper
EnvironmentFile=/home/%i/creeper-sweeper/.env
ExecStart=/home/%i/creeper-sweeper/.venv/bin/creeper-sweeper webapp \
    --host 0.0.0.0 --port 5000 --no-browser
Restart=on-failure
RestartSec=5

# Security hardening
ProtectSystem=full
PrivateTmp=true
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW

[Install]
WantedBy=multi-user.target
```

### Service Management

```bash
# Enable (persists across reboots)
sudo systemctl enable creeper-sweeper-webapp@<user>

# Start/Stop/Restart
sudo systemctl start creeper-sweeper-webapp@<user>
sudo systemctl stop creeper-sweeper-webapp@<user>
sudo systemctl restart creeper-sweeper-webapp@<user>

# Status
sudo systemctl status creeper-sweeper-webapp@<user>

# Live logs
journalctl -u creeper-sweeper-webapp@<user> -f

# Logs since last boot
journalctl -u creeper-sweeper-webapp@<user> -b
```

### Service Dependencies

```
gpsd.service ←── bluetooth.target ←── network-online.target
                                          │
                                          ▼
                              creeper-sweeper-webapp@user
                                          │
                                          ▼
                              Flask (0.0.0.0:5000)
                              ├── scanner_thread
                              ├── BTScanner thread
                              └── GPSReader thread
```

---

## 7. Deployment Automation

### deploy.sh (9-Step Process)

```bash
bash webapp/deploy.sh <pi-host> <pi-user>
# Defaults:
#   PI_HOST=subsonic-detection3-sizable.local
#   PI_USER=pedicure-recognize-stress7
# Example:
bash webapp/deploy.sh 192.168.1.243 pedicure-recognize-stress7
```

#### Step 0: Timezone & NTP

```bash
sudo timedatectl set-timezone "${TARGET_TZ}"
sudo timedatectl set-ntp true
```

#### Step 0.5: Hardware — gpsd, udev, Bluetooth firmware

- Install gpsd if missing
- Configure `/etc/default/gpsd` for U-blox7
- Create udev rules for stable device names (`/dev/gps0`)
- Add user to `dialout` group
- Check Realtek BT firmware presence

#### Step 1: Create Remote Directories

```
~/creeper-sweeper/
├── webapp/
│   ├── static/
│   └── templates/
└── src/
    └── creeper_sweeper/
        └── data/
```

#### Step 2: SCP Webapp Files

```
app.py, bt_scanner.py, pnl_engine.py, gps_reader.py, triangulation.py,
mac_breakdown.py, phy_fingerprint.py, oui_lookup.json
requirements.txt, static/* (including oui_db.json), templates/*
```

#### Step 3: SCP Config + Source Package

```
.env, pyproject.toml
src/creeper_sweeper/*.py, src/creeper_sweeper/data/*
```

The full `src/creeper_sweeper/` package is now deployed alongside the
webapp, including the surveillance OUI database (`data/surveillance_oui.toml`)
and all CLI/detector modules.

#### Step 4: Install Systemd Templates

```
creeper-sweeper-webapp@.service
creeper-sweeper-detector@.service
```

#### Step 5: `pip install -e .`

Editable install of the full package within the Pi's `.venv`.

#### Step 6: Enable Services

```bash
sudo systemctl daemon-reload
sudo systemctl enable creeper-sweeper-webapp@<user>
mkdir -p ~/.local/share/creeper-sweeper/logs
```

#### Step 7: Restart (Ordered)

```bash
sudo systemctl restart gpsd
sleep 1
sudo systemctl restart creeper-sweeper-webapp@<user>
```

### Quick Redeploy (Files Only)

For rapid iteration during development:

```bash
PI="pi@192.168.1.243"
scp webapp/app.py "$PI":~/creeper-sweeper/webapp/
scp webapp/static/* "$PI":~/creeper-sweeper/webapp/static/
ssh "$PI" 'sudo fuser -k 5000/tcp; sleep 1; sudo systemctl restart creeper-sweeper-webapp@pi'
```

---

## 8. GPS & gpsd Configuration

### gpsd Setup

```bash
# /etc/default/gpsd
START_DAEMON="true"
USBAUTO="true"
DEVICES="/dev/ttyACM0"
GPSD_OPTIONS="-n -b"
GPSD_SOCKET="/var/run/gpsd.sock"
```

- `-n` — Don't wait for client connection before polling
- `-b` — Broken-device-safety mode for USB GPS

### udev Rule (Stable Symlink)

```
# /etc/udev/rules.d/99-creeper-sweeper.rules
SUBSYSTEM=="tty", ATTRS{idVendor}=="1546", ATTRS{idProduct}=="01a7", \
    SYMLINK+="gps0", GROUP="dialout", MODE="0660"
```

### Verify GPS

```bash
# Check gpsd is running
systemctl status gpsd

# Stream GPS data
gpspipe -w -n 5

# Check fix quality
cgps -s

# Python test
python3 -c "
import socket, json
s = socket.socket()
s.connect(('127.0.0.1', 2947))
s.send(b'?WATCH={\"enable\":true,\"json\":true}\n')
for _ in range(10):
    data = s.recv(4096).decode()
    for line in data.strip().split('\n'):
        obj = json.loads(line)
        if obj.get('class') == 'TPV':
            print(f'Fix: {obj.get(\"lat\")}, {obj.get(\"lon\")}')
"
```

---

## 9. Bluetooth Firmware & HCI

### Realtek RTL8761B Firmware

```bash
# Check firmware presence
ls -la /lib/firmware/rtl_bt/rtl8761b_fw.bin

# If missing, install from linux-firmware
sudo apt install firmware-realtek
# or download manually:
# https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git
```

### HCI Verification

```bash
# List adapters
hciconfig -a

# Check USB adapter (hci1)
btmgmt --index 1 info

# Expected: "current settings: powered le"

# Manual BLE scan test
sudo btmgmt --index 1 find -l
# Should produce device lines within 8 seconds
```

### Common HCI Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `hci1` not found | Firmware missing | Install `firmware-realtek` |
| `hci1` DOWN | Not powered | `sudo hciconfig hci1 up` |
| `hci1` stuck discovering | Orphaned btmgmt | `sudo killall btmgmt; sleep 1` |
| 0 devices found | PTY buffer issue | Use `script -qc` wrapper |
| Permission denied | Missing capabilities | Run with `sudo` or CAP_NET_ADMIN |

---

## 10. WiFi Monitor Mode

### MediaTek MT7610U (Panda PAU0B)

```bash
# Check interface exists
iw dev
# Should show wlan1 (type managed)

# Enable monitor mode
sudo ip link set wlan1 down
sudo iw dev wlan1 set type monitor
sudo ip link set wlan1 up

# Verify
iw dev wlan1 info
# Should show: type monitor
```

### Monitor Mode Detection (Hardware Module)

The `hardware.py` module auto-detects monitor mode capability:

```bash
# Check if adapter supports monitor
iw phy phy1 info | grep "* monitor"
```

### Channel Hopping

For comprehensive coverage, hop across non-overlapping channels:

```bash
for ch in 1 6 11; do
    sudo iw dev wlan1 set channel $ch
    sleep 0.5
done
```

---

## 11. Kismet Integration

### Kismet as Primary WiFi Source

```bash
# Install Kismet
sudo apt install kismet

# Start with monitor interface
kismet -c wlan1:type=linuxwifi

# Or via systemd
sudo systemctl enable kismet
sudo systemctl start kismet
```

### Kismet REST API Access

```python
# app.py uses httpx to query Kismet
response = httpx.get(
    "http://localhost:2501/devices/all_devices.json",
    auth=("kismet", "<password>"),
    timeout=10,
)
```

### Fallback Without Kismet

If Kismet is unavailable, the scanner falls back to:

```bash
sudo iw wlan1 scan
```

Parsed via regex for BSSID, SSID, signal, channel, frequency.

---

## 12. Log Management

### Application Log

```
~/.local/share/creeper-sweeper/logs/webapp.log
```

Structured logging with timestamps, levels, and context.

### Systemd Journal

```bash
# Full service log
journalctl -u creeper-sweeper-webapp@<user> --no-pager

# Recent (last 5 minutes)
journalctl -u creeper-sweeper-webapp@<user> --since "5 min ago"

# Filter by priority
journalctl -u creeper-sweeper-webapp@<user> -p err

# Follow (live)
journalctl -u creeper-sweeper-webapp@<user> -f
```

### Log Rotation

- Application log: Not rotated automatically (bounded by alerts = 1000 max)
- systemd journal: System rotation policy applies
- GPS log: Bounded to `MAX_GPS_LOG_ENTRIES` (5000)

---

## 13. Diagnostics & Health Checks

### API Health Check

```bash
# System status
curl -s -u admin:<password> http://<pi>:5000/api/status | python3 -m json.tool

# Expected fields:
# scanner_running, kismet_connected, gps_valid, bluetooth.enabled,
# active_detections, fingerprint_count, triangulation.node_count
```

### Hardware Health

```bash
# GPS
gpspipe -w -n 3 | grep TPV

# Bluetooth
pgrep -la btmgmt          # Check for orphans
hciconfig hci1             # Check adapter state
sudo btmgmt --index 1 info # Check powered/LE state

# WiFi
iw dev wlan1 info          # Check interface state
iw dev wlan1 scan dump | head -20  # Quick scan test

# USB
lsusb                      # All USB devices
dmesg | tail -20           # Recent USB events
```

### Process Health

```bash
# Service status
sudo systemctl is-active creeper-sweeper-webapp@<user>

# Port binding
sudo fuser 5000/tcp

# Memory usage
ps aux | grep app.py

# Thread count
ls /proc/$(pgrep -f "app.py")/task/ | wc -l
```

### Data Health

```bash
# Check data directory
ls -la ~/.local/share/creeper-sweeper/

# File sizes (detect corruption)
du -sh ~/.local/share/creeper-sweeper/*.json

# Validate JSON
for f in ~/.local/share/creeper-sweeper/*.json; do
    python3 -c "import json; json.load(open('$f'))" && echo "$f: OK" || echo "$f: CORRUPT"
done
```

---

## 14. Troubleshooting Playbook

### Port 5000 Occupied

```bash
sudo fuser -k 5000/tcp
sleep 1
sudo systemctl restart creeper-sweeper-webapp@<user>
```

### BT Scan Returns 0 Devices

```bash
# 1. Kill orphans
sudo killall -9 btmgmt; sleep 1

# 2. Verify HCI up
hciconfig hci1

# 3. Manual test (SSH has PTY)
sudo btmgmt --index 1 find -l

# 4. Test script wrapper (simulates systemd)
script -qc "sudo btmgmt --index 1 find -l" /dev/null | head -20

# 5. Nuclear reset
sudo hciconfig hci1 reset
```

### GPS Not Reading

```bash
# 1. Check device exists
ls -la /dev/ttyACM0

# 2. Check gpsd
systemctl status gpsd

# 3. Direct serial test
sudo cat /dev/ttyACM0 | head -5
# Should show NMEA sentences ($GPGGA, $GPRMC, etc.)

# 4. Restart gpsd
sudo systemctl restart gpsd
```

### Service Won't Start

```bash
# Check journal
sudo journalctl -u creeper-sweeper-webapp@<user> -n 30 --no-pager

# Common issues:
# - Port 5000 occupied → fuser -k 5000/tcp
# - Python import error → check .venv/bin/python -c "from webapp.app import ..."
# - .env missing → scp .env to Pi
# - Permission denied → check AmbientCapabilities in service file
```

### Dashboard Showing Stale Data

```bash
# Check cache version (should match app.py VERSION)
curl -s http://<pi>:5000/ | grep 'v='

# Force browser cache clear:
# Ctrl+Shift+R in browser, or update VERSION in app.py
```

### Correlation Shows 0 Clusters

```bash
# 1. Check fingerprint count
curl -s -u admin:<pw> http://<pi>:5000/api/devices | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'Devices: {len(d)}')
bt = [x for x in d if x.get('device_type') == 'bluetooth']
print(f'BT devices: {len(bt)}')
"

# 2. Force recompute
curl -s -X POST -u admin:<pw> http://<pi>:5000/api/correlations/recompute

# 3. Check result
curl -s -u admin:<pw> http://<pi>:5000/api/correlations | python3 -m json.tool
```

---

## 15. CI/CD Pipeline

### Local Development

```bash
# Lint
ruff check src/ webapp/ tests/

# Type check
mypy src/creeper_sweeper/

# Unit tests
pytest tests/ -v --tb=short

# Coverage
pytest tests/ --cov=creeper_sweeper --cov-report=html
```

### Pre-Commit Checks

```bash
# Format
ruff format src/ webapp/ tests/

# Lint (fix auto-fixable)
ruff check --fix src/ webapp/ tests/

# Type check (strict)
mypy src/creeper_sweeper/ --strict
```

### Tool Configuration (`pyproject.toml`)

```toml
[tool.ruff]
target-version = "py311"
line-length = 100

[tool.ruff.lint]
select = ["E", "W", "F", "I", "B", "C4", "UP", "S", "SIM"]
ignore = ["E501", "S101"]

[tool.mypy]
python_version = "3.11"
strict = true

[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
```

### Deploy Pipeline

```
1. Local: edit code
2. Local: ruff check + mypy + pytest
3. Local: git commit (conventional commits)
4. Local: bash webapp/deploy.sh <pi-host> <pi-user>
5. Remote: pip install -e . (on Pi)
6. Remote: systemd restart
7. Remote: verify via /api/status
8. Local: git push
```

### Git Commit Convention

```
<type>(<scope>): <description>

Types: feat | fix | docs | refactor | test | chore | perf | ci
Scopes: webapp | bluetooth | gps | correlation | frontend | deploy
```

---

## 16. Development Workflow

### Rapid Iteration (Files Only)

```bash
# Edit locally → SCP → restart
scp webapp/app.py pi@<host>:~/creeper-sweeper/webapp/
ssh pi@<host> 'sudo fuser -k 5000/tcp; sleep 1; sudo systemctl restart creeper-sweeper-webapp@pi'
```

### Full Deployment

```bash
bash webapp/deploy.sh <host> <user>
```

### Testing on Pi

```bash
# SSH into Pi
ssh pi@<host>

# Test BT scanner directly
cd ~/creeper-sweeper/webapp
python3 -c "from bt_scanner import BTScanner, parse_btmgmt_output; print('OK')"

# Test app import
cd ~/creeper-sweeper
.venv/bin/python -c "import webapp.app; print('OK')"

# Run manually (for debugging)
cd ~/creeper-sweeper
.venv/bin/creeper-sweeper webapp --host 0.0.0.0 --port 5000
```

---

## 17. Backup & Recovery

### Data Backup

```bash
# Backup all persistent data
ssh pi@<host> 'tar czf /tmp/creeper-data-$(date +%Y%m%d).tar.gz \
    ~/.local/share/creeper-sweeper/'
scp pi@<host>:/tmp/creeper-data-*.tar.gz ./backups/
```

### Data Restore

```bash
scp ./backups/creeper-data-20260208.tar.gz pi@<host>:/tmp/
ssh pi@<host> 'cd ~ && tar xzf /tmp/creeper-data-20260208.tar.gz'
ssh pi@<host> 'sudo systemctl restart creeper-sweeper-webapp@pi'
```

### Factory Reset (Keep Config)

```bash
ssh pi@<host> 'rm -f ~/.local/share/creeper-sweeper/*.json'
ssh pi@<host> 'sudo systemctl restart creeper-sweeper-webapp@pi'
```

---

## 18. Network & Security

### Firewall (if UFW enabled)

```bash
sudo ufw allow 5000/tcp comment "Creeper Sweeper Dashboard"
sudo ufw allow 2501/tcp comment "Kismet REST API"
sudo ufw allow 2947/tcp comment "gpsd"
```

### Access Control

- Dashboard: HTTP Basic Auth (credentials in `.env`)
- Kismet: Separate credentials (in `.env`)
- SSH: Key-based recommended
- No TLS by default — assumes trusted LAN or VPN overlay

### Secrets Management

| Secret | Storage | Access |
|--------|---------|--------|
| Dashboard password | `.env` → `CREEPER_ADMIN_PASSWORD` | `os.environ` |
| Flask secret key | `.env` → `CREEPER_SECRET_KEY` | `os.environ` |
| Kismet password | `.env` → `KISMET_PASSWORD` | `os.environ` |
| WiFi password | `.env` → `WIFI_PASSWORD` | Deploy script only |
| Webhook secret | `.env` → `CREEPER_WEBHOOK_SECRET` | `SecretStr` (Pydantic) |

---

*signals-deployment v2.0 | 2026-02-08 | Creeper Sweeper*
*Updated: 9-step deploy.sh, src package deployment, MAC breakdown + OUI DB, default host/user*
