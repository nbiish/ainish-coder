# Bluetooth Scanning — Production Implementation Guide

> **Real-world BLE scanning on Raspberry Pi 5 under systemd using `btmgmt`.**
>
> This document captures hard-won lessons from deploying BT scanning on a
> headless Raspberry Pi 5 running Debian Bookworm.  Every failure mode
> described here was encountered and resolved in production.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Hardware Setup](#2-hardware-setup)
3. [btmgmt Fundamentals](#3-btmgmt-fundamentals)
4. [The PTY Buffering Problem](#4-the-pty-buffering-problem)
5. [The `script -qc` Solution](#5-the-script--qc-solution)
6. [Orphaned Process Management](#6-orphaned-process-management)
7. [Detection Pipeline Integration](#7-detection-pipeline-integration)
8. [Signal Correlation Engine](#8-signal-correlation-engine)
9. [Systemd Service Configuration](#9-systemd-service-configuration)
10. [Troubleshooting Playbook](#10-troubleshooting-playbook)
11. [Configuration Reference](#11-configuration-reference)
12. [Failed Approaches (Anti-Patterns)](#12-failed-approaches-anti-patterns)

---

## 1. Architecture Overview

```
┌────────────────────────────────────────────────────────────────────┐
│                    BT/WiFi Detection Pipeline                       │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐    ┌──────────────────┐    ┌─────────────────┐   │
│  │ WiFi Scanner │    │  BT Scanner      │    │   GPS Reader    │   │
│  │ iw wlan1 scan│    │  btmgmt find -l  │    │   gpsd/serial   │   │
│  └──────┬───────┘    └────────┬─────────┘    └───────┬─────────┘   │
│         │                     │                      │              │
│         ▼                     ▼                      ▼              │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Scanner Thread (app.py)                         │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌──────────────┐    │   │
│  │  │ fingerprint_db│  │    tracker    │  │  tri_engine   │    │   │
│  │  │   .record()   │  │   .update()   │  │ .add_obs()   │    │   │
│  │  └───────────────┘  └───────┬───────┘  └──────────────┘    │   │
│  │                             │                                │   │
│  │                     ┌───────▼───────┐                        │   │
│  │                     │  Alert Tier   │                        │   │
│  │                     │ 1 / 2 / 3    │                        │   │
│  │                     └───────┬───────┘                        │   │
│  │                             │                                │   │
│  │                     ┌───────▼───────┐                        │   │
│  │                     │ Correlation   │                        │   │
│  │                     │ WiFi ↔ BLE    │                        │   │
│  │                     │ clustering    │                        │   │
│  │                     └───────────────┘                        │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│         ┌──────────────────────────────────┐                       │
│         │      WebSocket (Socket.IO)        │                       │
│         │  → detections, alerts, bt_devices │                       │
│         │  → gps_fix, correlation clusters  │                       │
│         └──────────────────────────────────┘                       │
└────────────────────────────────────────────────────────────────────┘
```

**Key insight:** BT devices MUST flow through the same pipeline as WiFi
devices — fingerprinting, alert generation, triangulation, and correlation.
Without this, BT scanning is cosmetic only (visible on the BT tab but
invisible to the detection engine, alert system, and correlation system).

---

## 2. Hardware Setup

### Tested Hardware

| Component | Model | USB ID | Interface | Role |
|-----------|-------|--------|-----------|------|
| BT Primary | Hakimonoe RTL8761BU | `0bda:a728` | `hci1` | BLE scanning |
| BT Fallback | BCM4345C0 (onboard) | — | `hci0` | Not used (limited range) |
| WiFi Scanner | Panda PAU0B (MT7610U) | `0e8d:7610` | `wlan1` | WiFi scanning |
| WiFi Network | BCM43455 (onboard) | — | `wlan0` | Network connectivity |
| GPS | U-blox 7 | `1546:01a7` | `/dev/ttyACM0` | Location tagging |

### Verify BT Adapter

```bash
# List HCI interfaces
hciconfig -a

# Check specific index
btmgmt --index 1 info

# Expected output:
# hci1:   Primary controller
#         addr XX:XX:XX:XX:XX:XX version 10 ...
#         supported settings: ...
#         current settings: powered le ...
```

### USB Power Considerations

The Pi 5 can power all three USB peripherals simultaneously, but ensure:
- Use a 5V/5A power supply (official Pi 5 PSU recommended)
- USB 3.0 ports for the WiFi adapter (MT7610U needs bandwidth)
- Either USB port for BT and GPS (USB 2.0 is sufficient)

---

## 3. btmgmt Fundamentals

`btmgmt` is the BlueZ management tool — lower-level than `bluetoothctl`,
providing direct HCI access for BLE discovery.

### Why btmgmt Over bluetoothctl

| Feature | btmgmt | bluetoothctl |
|---------|--------|--------------|
| Scan speed | Fast (~8s for full sweep) | Slow (needs `scan on`/`sleep`/`scan off`) |
| Output format | Structured, regex-parseable | Human-oriented, inconsistent |
| HCI index selection | `--index N` | Requires `select` command |
| Low-energy find | `find -l` (dedicated) | Mixed with BR/EDR results |
| Scriptability | Single command, exits | Interactive session needed |

### btmgmt Output Format

```
hci1 dev_found: 54:B7:E5:8C:07:F3 type LE Random rssi -52 flags 0x0000
AD flags 0x06
name EF-R350956
hci1 dev_found: XX:XX:XX:XX:XX:XX type LE Public rssi -78 flags 0x0000
```

Each device block starts with `hci\d+ dev_found:` and may have subsequent
lines with `AD flags`, `name`, `UUID`, and other advertising data.

### Parsing Regex

```python
# Device line
_BTMGMT_DEVICE_RE = re.compile(
    r"hci\d+\s+dev_found:\s+"
    r"(?P<mac>[0-9A-Fa-f:]{17})\s+"
    r"type\s+(?P<type>\S+(?:\s+\S+)?)\s+"
    r"rssi\s+(?P<rssi>-?\d+)\s+"
    r"flags\s+(?P<flags>0x[0-9A-Fa-f]+)"
)

# Device name (subsequent line)
_BTMGMT_NAME_RE = re.compile(r"name\s+(.+)")
```

### Address Types

| Type | Meaning | Tracking |
|------|---------|----------|
| `LE Public` | Permanent BLE address | Very linkable — same device across sessions |
| `LE Random` | Randomized BLE address | Changes periodically (MAC randomization) |
| `BR/EDR` | Classic Bluetooth | Usually stable, device-specific |

---

## 4. The PTY Buffering Problem

> **This is the single most important lesson in this document.**

### The Problem

`btmgmt find -l` works perfectly when run from an SSH terminal but produces
**zero bytes of output** when called from Python's `subprocess.run()` under
a systemd service.

### Root Cause

`btmgmt` uses **libc stdio** which **full-buffers stdout when connected to
a pipe** (not a TTY).  Under systemd:

1. Python's `subprocess.run(capture_output=True)` creates pipes for
   stdin/stdout/stderr
2. btmgmt detects stdout is a pipe → switches to full-buffering (4KB-64KB
   blocks)
3. btmgmt runs its BLE discovery scan, collecting device results
4. The output accumulates in btmgmt's internal buffer but is **never
   flushed** because:
   - btmgmt doesn't explicitly flush after each device
   - The buffer never fills completely (typical scan output is 1-3KB)
   - btmgmt may not self-terminate cleanly in pipe mode
5. When the process is killed (by timeout or signal), all buffered output
   is **discarded** — the kernel destroys the process's stdio buffers

### Why It Works via SSH

SSH provides a **pseudo-TTY** (PTY) to the remote shell.  When you type
`sudo btmgmt find -l` in an SSH session:

1. btmgmt's stdout is connected to the PTY (a terminal device)
2. libc detects stdout is a TTY → uses **line-buffering**
3. Each `dev_found:` line is flushed immediately as it's written
4. Output appears in real-time

```
SSH session (works):
  bash ← PTY → btmgmt (stdout = PTY → line-buffered ✅)

systemd service (fails):
  python → subprocess.PIPE → btmgmt (stdout = pipe → full-buffered ❌)
```

### Verification

You can verify this by checking `/proc/<PID>/fd/1`:

```bash
# Under SSH (TTY):
ls -la /proc/$(pgrep btmgmt)/fd/1
# → /dev/pts/0 (PTY device)

# Under systemd (pipe):
ls -la /proc/$(pgrep btmgmt)/fd/1
# → pipe:[12345] (anonymous pipe)
```

---

## 5. The `script -qc` Solution

### How It Works

The `script(1)` utility is designed to record terminal sessions.  It creates
a **real pseudo-TTY** and connects the child process's stdin/stdout to it.

```bash
script -qc "sudo btmgmt --index 1 find -l" /dev/null
```

- `-q` — quiet mode (suppress `Script started` / `Script done` messages)
- `-c "command"` — run command instead of interactive shell
- `/dev/null` — discard the typescript file (we capture stdout directly)

### Why This Works

```
Python subprocess.run(["script", "-qc", btmgmt_cmd, "/dev/null"])
        ↓
    script(1) creates PTY pair
        ↓
    script forks → child gets PTY as stdin/stdout/stderr
        ↓
    child runs: sudo btmgmt --index 1 find -l
        ↓
    btmgmt sees stdout = /dev/pts/N (a TTY!)
        ↓
    btmgmt uses line-buffering → output flows immediately
        ↓
    script reads from PTY master → writes to its stdout (the pipe back to Python)
        ↓
    Python captures output via subprocess.PIPE ✅
```

### Python Implementation

```python
def scan_once(self) -> list[dict[str, Any]]:
    """Execute a single BLE scan."""
    # Kill orphaned btmgmt first
    self._kill_stale_btmgmt()

    btmgmt_cmd = f"sudo {BTMGMT_PATH} --index {BT_HCI_INDEX} find -l"

    result = subprocess.run(
        ["script", "-qc", btmgmt_cmd, "/dev/null"],
        capture_output=True,
        text=True,
        timeout=BT_SCAN_DURATION + 10,
    )

    devices = parse_btmgmt_output(result.stdout)
    return devices
```

### Performance

| Metric | Value |
|--------|-------|
| Typical scan duration | 6-8 seconds |
| Output size | 1.5-3 KB (20-30 devices) |
| Devices found | 15-30 in residential area |
| CPU overhead | Negligible (<1% on Pi 5) |
| Memory | ~3 MB (btmgmt + script) |

---

## 6. Orphaned Process Management

### The Problem

When btmgmt is killed mid-scan (by timeout, Python, SIGTERM), it can leave
the HCI controller in **discovery mode**.  Subsequent btmgmt invocations
then hang silently — they try to start discovery but the controller is
already scanning.

Additionally, `btmgmt stop-find` **also hangs** without a TTY (same
buffering problem), so you can't use it for cleanup.

### The Solution

Kill all btmgmt processes before each scan:

```python
@staticmethod
def _kill_stale_btmgmt() -> None:
    """Kill any orphaned btmgmt processes blocking HCI."""
    try:
        subprocess.run(
            ["sudo", "killall", "-q", "btmgmt"],
            capture_output=True, timeout=3,
        )
        time.sleep(0.3)  # Give kernel time to release HCI
    except Exception:
        pass
```

The 0.3s sleep is **critical** — the kernel needs time to:
1. Terminate the process
2. Release the HCI interface from discovery mode
3. Reset the controller state

Without this sleep, the next `btmgmt find -l` may fail silently.

### Monitoring for Orphans

```bash
# Check for running btmgmt processes
pgrep -la btmgmt

# Check HCI state
btmgmt --index 1 info | grep -i "current settings"
# Should show: powered le
# NOT: powered le discovering (stuck in discovery mode)

# Nuclear option: reset HCI
sudo hciconfig hci1 reset
```

---

## 7. Detection Pipeline Integration

### Before (Broken)

```
WiFi scan → fingerprint_db → tracker → alerts → triangulation → correlation
BT scan → bt_tracker → bt_devices emit → (nothing else)  ❌
```

BT devices were visible on the dashboard's BT tab but invisible to:
- Fingerprint database (no RSSI history, no profiling)
- Alert system (no tier 1/2/3 alerts for BT devices)
- Triangulation engine (no GPS-tagged BT observations)
- Correlation engine (no WiFi↔BT linking)

### After (Working)

```
WiFi scan → fingerprint_db → tracker → alerts → triangulation → correlation
BT scan → bt_tracker → fingerprint_db → tracker → alerts → triangulation → correlation  ✅
```

### Integration Code (scanner_thread in app.py)

```python
# Get active BT devices (seen in last 120 seconds)
bt_active = bt_tracker.get_active(since_seconds=120)

for bt_dev in bt_active:
    bt_mac = bt_dev.get("mac", "")
    bt_name = bt_dev.get("name", "")
    bt_rssi = bt_dev.get("rssi", -100)

    # 1. Fingerprint BT devices alongside WiFi
    fingerprint_db.record(
        bt_mac,
        rssi=bt_rssi,
        device_type="bluetooth",
        device_name=bt_name,
        manufacturer=bt_dev.get("manufacturer", ""),
    )

    # 2. Feed into detection tracker for alert generation
    alert_det = tracker.update(
        mac=bt_mac,
        signal=bt_rssi,
        device_type="bluetooth",
        device_name=bt_name,
        phy="ble",
    )

    # 3. Generate alerts if warranted
    if alert_det and alert_det.alert_tier > 0:
        socketio.emit("alert", {
            "tier": alert_det.alert_tier,
            "detection": alert_det.to_dict(),
            "timestamp": now_local().isoformat(),
        })

    # 4. Feed into triangulation with GPS
    if current_fix.valid:
        tri_engine.add_observation(SignalObservation(
            node_id="pi-local",
            mac=bt_mac,
            rssi=bt_rssi,
            signal_type="ble",
            node_latitude=current_fix.latitude,
            node_longitude=current_fix.longitude,
            node_altitude=current_fix.altitude,
        ))

# 5. Emit BT data to dashboard
socketio.emit("bt_devices", bt_active)
```

### Correlation: WiFi ↔ BLE Linking

The correlation engine links WiFi and BLE observations from the same
physical device by analyzing:

1. **Temporal co-occurrence** — WiFi and BLE MACs seen at the same time
2. **RSSI similarity** — Devices at similar signal strength (same distance)
3. **BT address type bonus** — `LE Public` addresses are highly linkable
4. **Behavioral patterns** — Same appearance/disappearance timing
5. **Vendor analysis** — OUI matching across WiFi and BLE MACs

A cluster score above the threshold produces a **correlation cluster**
visible on the Correlation tab.

---

## 8. Signal Correlation Engine

### Architecture

The `SignalCorrelator` class in `app.py` maintains:
- A `_fingerprint_db` reference for device history
- A `_tracker` reference for active detections
- A `_tri_engine` reference for location data
- A time-windowed observation buffer

### Correlation Factors

| Factor | Weight | Description |
|--------|--------|-------------|
| Temporal overlap | High | WiFi + BLE seen within same scan window |
| RSSI proximity | Medium | Signal strengths within 15 dBm |
| BT public address | Bonus | LE Public = stable, highly linkable |
| Vendor match | Medium | Same OUI prefix across WiFi/BLE |
| Movement pattern | High | Appear/disappear together |

### Cluster Output

Each cluster contains:
- List of associated MACs (WiFi + BLE)
- Confidence score (0-100)
- Device labels from fingerprint names
- First/last seen timestamps
- Signal type breakdown

---

## 9. Systemd Service Configuration

### Service File

```ini
# /etc/systemd/system/creeper-sweeper-webapp@.service
[Unit]
Description=Creeper Sweeper Web Dashboard
After=network-online.target bluetooth.target
Wants=network-online.target bluetooth.target

[Service]
Type=simple
User=%i
WorkingDirectory=/home/%i/creeper-sweeper/webapp
EnvironmentFile=/home/%i/creeper-sweeper/.env
ExecStart=/home/%i/creeper-sweeper/.venv/bin/python app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### Critical Environment Variables

```bash
# .env
BT_HCI_INDEX=1              # RTL8761BU = hci1
BT_SCAN_DURATION=8           # Seconds per scan
BT_SCAN_INTERVAL=10          # Seconds between scans
BT_STALE_TIMEOUT=600         # Remove devices not seen for 10min
BTMGMT_PATH=/usr/bin/btmgmt  # Full path required under systemd
SCAN_INTERVAL=3              # WiFi scan interval (seconds)
WIFI_IFACE=wlan1             # WiFi scanner interface
```

### Service Management

```bash
# Start/stop/restart
sudo systemctl restart creeper-sweeper-webapp@<user>

# View logs (live)
journalctl -u creeper-sweeper-webapp@<user> -f

# View BT-specific logs
journalctl -u creeper-sweeper-webapp@<user> | grep -i "bt\|bluetooth\|btmgmt"

# Check status
sudo systemctl status creeper-sweeper-webapp@<user>
```

---

## 10. Troubleshooting Playbook

### BT Scan Returns 0 Devices

```bash
# 1. Check for orphaned btmgmt processes
pgrep -la btmgmt
# If found:
sudo killall -9 btmgmt
sleep 1

# 2. Verify HCI is up
hciconfig hci1
# Should show: UP RUNNING

# 3. Manual scan test (from SSH — has TTY)
sudo btmgmt --index 1 find -l
# Should output device lines within 8 seconds

# 4. Test script wrapper (simulates systemd environment)
script -qc "sudo btmgmt --index 1 find -l" /dev/null | head -20
# Should show same devices

# 5. Check btmgmt binary path
which btmgmt  # /usr/bin/btmgmt

# 6. Check permissions
sudo btmgmt --index 1 info
# Must work — btmgmt needs CAP_NET_ADMIN (provided by sudo)
```

### BT Scan Times Out

```bash
# Likely cause: HCI stuck in discovery mode
# 1. Kill all btmgmt
sudo killall -9 btmgmt
sleep 1

# 2. Reset HCI
sudo hciconfig hci1 reset
sleep 2

# 3. Power cycle USB (if needed)
sudo uhubctl -l 1-1 -a cycle  # Requires uhubctl

# 4. Restart service
sudo systemctl restart creeper-sweeper-webapp@<user>
```

### BT Devices Not Appearing in Detections/Alerts

Check the scanner_thread integration in `app.py`:
- Is `bt_tracker.get_active()` returning devices?
- Is the fingerprint_db.record() call happening?
- Is the tracker.update() call happening?
- Check logs: `grep "BT ALERT\|BT tracker" webapp.log`

### Correlation Shows 0 Clusters

1. Verify BT devices are flowing into the pipeline (not just bt_tracker)
2. Check fingerprint count: `/api/devices` should show BT + WiFi devices
3. Verify detection count: `/api/detections` should include `device_type="bluetooth"`
4. Run manual recompute: click "Recompute" on Correlation tab

### Port 5000 Occupied After Service Crash

```bash
sudo fuser -k 5000/tcp
sleep 1
sudo systemctl restart creeper-sweeper-webapp@<user>
```

---

## 11. Configuration Reference

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BT_HCI_INDEX` | `1` | HCI adapter index for scanning |
| `BT_SCAN_DURATION` | `8` | Seconds per BLE scan |
| `BT_SCAN_INTERVAL` | `10` | Seconds between scans |
| `BT_STALE_TIMEOUT` | `600` | Remove unseen devices after N seconds |
| `MAX_BT_DEVICES` | `500` | Cap on tracked BT devices |
| `MAX_BT_RSSI_HISTORY` | `50` | RSSI history entries per device |
| `BTMGMT_PATH` | `/usr/bin/btmgmt` | Path to btmgmt binary |
| `SCAN_INTERVAL` | `3` | WiFi scan interval (seconds) |
| `WIFI_IFACE` | `wlan1` | WiFi scanner interface |

### File Locations

| File | Path | Purpose |
|------|------|---------|
| BT device DB | `~/.local/share/creeper-sweeper/bt_devices.json` | Persisted BT tracker state |
| Fingerprints | `~/.local/share/creeper-sweeper/fingerprints.json` | WiFi + BT fingerprint database |
| Alert history | `~/.local/share/creeper-sweeper/alert_history.json` | All alert tiers |
| Triangulation | `~/.local/share/creeper-sweeper/triangulation.json` | GPS-tagged signal observations |
| Correlation | Computed in memory, cached | WiFi↔BLE device clusters |
| Service logs | `~/.local/share/creeper-sweeper/logs/webapp.log` | Application log file |
| systemd logs | `journalctl -u creeper-sweeper-webapp@<user>` | Service stdout/stderr |

### Scan Timing

```
WiFi:  ──scan(~2s)──wait(3s)──scan──wait──scan──
BT:    ──scan(~8s)──────wait(10s)──────scan──────
GPS:   ──poll(1s)──poll──poll──poll──poll──poll───
Save:  ──────────────────────save(~60s)──────────
Corr:  ──────────────────────compute(~60s)───────
```

---

## 12. Failed Approaches (Anti-Patterns)

These approaches were tested and **do not work** for btmgmt under systemd.
Documenting them here to prevent future engineers from re-discovering the
same dead ends.

### ❌ subprocess.run() with capture_output (direct)

```python
# FAILS: btmgmt full-buffers stdout to pipe, outputs 0 bytes
result = subprocess.run(
    ["sudo", "btmgmt", "--index", "1", "find", "-l"],
    capture_output=True, text=True, timeout=18,
)
# result.stdout = "" (empty)
```

### ❌ timeout wrapper

```python
# FAILS: timeout kills btmgmt with SIGTERM, all buffered output is lost
result = subprocess.run(
    ["timeout", "15", "sudo", "btmgmt", "--index", "1", "find", "-l"],
    capture_output=True, text=True,
)
# rc=124 (timeout killed it), stdout = "" (buffer discarded)
```

### ❌ stdbuf -oL (line-buffer forcing)

```python
# FAILS: stdbuf wraps libc but btmgmt may use raw write() or internal buffering
result = subprocess.run(
    ["stdbuf", "-oL", "sudo", "btmgmt", "--index", "1", "find", "-l"],
    capture_output=True, text=True, timeout=18,
)
# stdout = "" (stdbuf doesn't affect btmgmt's actual behavior)
```

### ❌ Python pty.openpty()

```python
# FAILS: sudo intercepts fd inheritance — btmgmt still gets pipes
import pty, os
master_fd, slave_fd = pty.openpty()
proc = subprocess.Popen(
    ["sudo", "btmgmt", "--index", "1", "find", "-l"],
    stdout=slave_fd, stderr=slave_fd, stdin=slave_fd,
)
os.close(slave_fd)
# sudo drops the PTY fds → btmgmt gets pipes → 0 bytes
```

### ❌ btmgmt without sudo

```bash
# FAILS: btmgmt requires CAP_NET_ADMIN
btmgmt --index 1 find -l
# Error: "Permission Denied"
```

### ❌ btmgmt stop-find (for cleanup)

```bash
# FAILS: stop-find itself hangs without a TTY (same buffering problem)
sudo btmgmt --index 1 stop-find  # hangs indefinitely under systemd
```

### ✅ Working: script -qc

```python
# WORKS: script(1) creates a real PTY for the entire sudo+btmgmt chain
result = subprocess.run(
    ["script", "-qc", "sudo /usr/bin/btmgmt --index 1 find -l", "/dev/null"],
    capture_output=True, text=True, timeout=18,
)
# stdout = full device output (1.5-3KB, 15-30 devices)
```

---

## Key Takeaways

1. **Always use `script -qc` for btmgmt under systemd** — no other wrapper
   reliably provides a PTY through the sudo chain

2. **Always kill stale btmgmt before scanning** — orphaned processes lock
   the HCI controller in discovery mode

3. **Feed BT into the FULL detection pipeline** — fingerprinting, alert
   tracking, triangulation, and correlation.  Without this, BT data is
   invisible to the detection engine

4. **Test under systemd, not just SSH** — SSH provides a TTY that masks the
   buffering problem.  Always verify behavior through the actual service

5. **Log output size, not just device count** — `0B output` is the telltale
   sign of the PTY buffering problem vs. genuinely finding 0 devices

---

*signals-bt-implementation v1.0 | 2025-07 | Creeper Sweeper*
