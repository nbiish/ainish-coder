# Signals Detection: Expert Technical Reference

> **Beyond Expert-Level Guide to WiFi & BLE Surveillance Device Detection**
>
> This document synthesizes knowledge from the DEFLOCK/Flocker codebase with comprehensive research on RF signal detection, IEEE 802.11 frame parsing, BLE advertisement scanning, and device fingerprinting techniques.
>
> **Companion documents**:
> - [Signals Quick Reference](signals-quickref.md) — Consolidated cheat sheet
> - [Signals Kismet](signals-kismet.md) — Advanced Kismet configuration & API
> - [Signals Voice Assistant](signals-voice-assistant.md) — LFM 2.5 + Parakeet + PocketTTS
> - [Signals Memory Agent](signals-memory-agent.md) — Agno + SQLite + LanceDB persistence
> - [Signals Acoustic Detection](signals-acoustic.md) — Audio surveillance & ShotSpotter
> - [Signals LoRa & LPWAN](signals-lora-lpwan.md) — LoRa/LoRaWAN/Meshtastic
> - [Signals ML Detection](signals-ml-detection.md) — Machine learning anomaly detection
> - [Signals ESP32-S3 Camera](signals-xiao-esp32s3.md) — Camera integration & WiFi field tests
> - [Signals Image/Video](signals-security-image-video.md) — Camera streaming & processing

---

## Table of Contents

1. [RF Signal Fundamentals](#1-rf-signal-fundamentals)
2. [WiFi Promiscuous Mode Detection](#2-wifi-promiscuous-mode-detection)
3. [BLE Advertisement Scanning](#3-ble-advertisement-scanning)
4. [Device Fingerprinting](#4-device-fingerprinting)
5. [Signal Analysis & Ranging](#5-signal-analysis--ranging)
6. [Detection Targets Reference](#6-detection-targets-reference)
7. [ESP32-S3 Hardware Considerations](#7-esp32-s3-hardware-considerations)
8. [Code Patterns & Best Practices](#8-code-patterns--best-practices)
9. [Kismet Wireless Monitoring](#9-kismet-wireless-monitoring)
10. [Linux Monitor Mode & Channel Control](#10-linux-monitor-mode--channel-control)
11. [Scapy Python Packet Analysis](#11-scapy-python-packet-analysis)
12. [RTL-SDR & ISM Band Monitoring](#12-rtl-sdr--ism-band-monitoring)
13. [Wardriving Tools & Integration](#13-wardriving-tools--integration)

---

## 1. RF Signal Fundamentals

### 1.1 WiFi 2.4GHz Spectrum

The 2.4GHz ISM band provides 13 channels (14 in some regions) with 5MHz spacing. Key characteristics for surveillance detection:

| Property | Value | Detection Impact |
|----------|-------|------------------|
| **Frequency Range** | 2.400–2.4835 GHz | Longer range, better wall penetration than 5GHz |
| **Channel Width** | 20MHz (standard) | Adjacent channel interference possible |
| **Overlapping Channels** | 1, 6, 11 are non-overlapping | Target devices often use these |
| **Typical Range** | 50-100m outdoors | Detection range limited by receiver sensitivity |

### 1.2 BLE Advertising Channels

BLE uses three dedicated advertising channels to minimize WiFi interference:

| Channel | Frequency | WiFi Relationship |
|---------|-----------|-------------------|
| **37** | 2.402 GHz | Below WiFi Ch1 |
| **38** | 2.426 GHz | Between WiFi Ch6-7 |
| **39** | 2.480 GHz | Above WiFi Ch14 |

**Advertising Interval**: Surveillance devices typically advertise every 100-1000ms, enabling passive detection without active connections.

### 1.3 Protocol Coexistence

ESP32-S3 handles WiFi and BLE via time-division multiplexing:

- **Shared Radio**: Single 2.4GHz radio services both protocols
- **Arbitration**: ESP-IDF's coexistence layer prioritizes traffic
- **Recommendation**: Stagger WiFi channel hops and BLE scans to minimize conflicts

---

## 2. WiFi Promiscuous Mode Detection

### 2.1 ESP-IDF Promiscuous Mode APIs

Enable packet capture without association to any network:

```c
#include "esp_wifi.h"

// Enable promiscuous mode
esp_wifi_set_promiscuous(true);

// Register packet callback
esp_wifi_set_promiscuous_rx_cb(wifi_sniffer_callback);

// Filter to management frames only (probes + beacons)
wifi_promiscuous_filter_t filter = {
    .filter_mask = WIFI_PROMISCUOUS_FILTER_MASK_MGMT
};
esp_wifi_set_promiscuous_filter(&filter);
```

**Key Functions**:

| Function | Purpose |
|----------|---------|
| `esp_wifi_set_promiscuous(bool)` | Enable/disable monitor mode |
| `esp_wifi_set_promiscuous_rx_cb()` | Register packet handler |
| `esp_wifi_set_promiscuous_filter()` | Filter packet types (MGMT/DATA/CTRL) |
| `esp_wifi_set_channel(ch, WIFI_SECOND_CHAN_NONE)` | Set monitoring channel |

### 2.2 IEEE 802.11 Management Frame Structure

#### MAC Header (24 bytes base)

```
┌──────────────────────────────────────────────────────────────────┐
│ Frame Control │ Duration │ Addr1 (DA) │ Addr2 (SA) │ Addr3 (BSSID) │ Seq │
│    2 bytes    │  2 bytes │  6 bytes   │  6 bytes   │   6 bytes     │ 2B  │
└──────────────────────────────────────────────────────────────────┘
         ↓
   Subtypes: 0x04 = Probe Request
             0x08 = Beacon
```

**Address 2 (Source Address)**: The MAC address of the transmitting device—**critical for OUI-based detection**.

Extract source MAC from offset 10-15 (0-indexed):
```c
const uint8_t *src_mac = &packet_payload[10];
char mac_str[18];
snprintf(mac_str, sizeof(mac_str), "%02x:%02x:%02x:%02x:%02x:%02x",
         src_mac[0], src_mac[1], src_mac[2],
         src_mac[3], src_mac[4], src_mac[5]);
```

#### Frame Body: Probe Request vs Beacon

**Probe Request** (subtype 0x04):
- Sent by devices searching for networks
- Contains SSID the device is seeking (or wildcard)
- Body starts immediately with tagged parameters

**Beacon** (subtype 0x08):
- Broadcast by APs/devices advertising networks
- **12-byte fixed parameters** precede tagged parameters:

```
┌─────────────────────────────────────────────────────────────────┐
│ Timestamp │ Beacon Interval │ Capability │ Tagged Parameters...│
│  8 bytes  │     2 bytes     │   2 bytes  │     (SSID, etc.)    │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 SSID Extraction Algorithm

Tagged parameters use **TLV (Type-Length-Value)** format:

| Element ID | Length | Value |
|------------|--------|-------|
| 1 byte | 1 byte | Variable |

**SSID Element ID = 0**

```c
// For beacons: skip 12-byte fixed parameters
const uint8_t *tagged_params = frame_body + 12;  
int remaining = frame_body_len - 12;

// For probe requests: start immediately
// const uint8_t *tagged_params = frame_body;

// Parse SSID (ID=0)
if (remaining > 2 && tagged_params[0] == 0) {
    uint8_t ssid_len = tagged_params[1];
    if (ssid_len <= 32 && ssid_len < remaining - 2) {
        memcpy(ssid, &tagged_params[2], ssid_len);
        ssid[ssid_len] = '\0';
    }
}
```

### 2.4 Channel Hopping Strategy

Surveillance devices may operate on any channel. Systematic hopping ensures coverage:

| Profile | Hop Interval | Use Case | Trade-off |
|---------|--------------|----------|-----------|
| **HIGHWAY** | 50ms | High-speed (60+ mph) | May miss weak signals |
| **URBAN** | 100ms | City driving | Balanced |
| **SWEEP** | 250ms | Stationary/parking | Maximum sensitivity |

**Full 2.4GHz sweep time**: `hop_interval × 13 channels`
- HIGHWAY: 650ms
- URBAN: 1.3s  
- SWEEP: 3.25s

```c
void hopChannel() {
    static uint8_t currentChannel = 1;
    currentChannel = (currentChannel % 13) + 1;
    esp_wifi_set_channel(currentChannel, WIFI_SECOND_CHAN_NONE);
}
```

### 2.5 Security: ISR-Safe Packet Handling

Promiscuous callbacks execute in **interrupt context**. Critical requirements:

```c
void IRAM_ATTR wifi_sniffer_callback(void *buf, wifi_promiscuous_pkt_type_t type) {
    // 1. Validate immediately
    if (type != WIFI_PKT_MGMT) return;
    if (!buf) return;
    
    const wifi_promiscuous_pkt_t *pkt = (wifi_promiscuous_pkt_t *)buf;
    
    // 2. Bounds check before access
    if (pkt->rx_ctrl.sig_len < 24) return;  // Min header size
    if (pkt->rx_ctrl.sig_len > 2500) return; // Max reasonable
    
    // 3. Minimize processing - queue for main loop if complex
    // 4. No heap allocation (malloc/new)
    // 5. No blocking calls (Serial.print in some versions)
}
```

**IRAM_ATTR**: Places function in RAM for faster ISR execution.

---

## 3. BLE Advertisement Scanning

### 3.1 NimBLE Library Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Code                        │
├─────────────────────────────────────────────────────────────┤
│   NimBLEDevice   │   NimBLEScan   │  NimBLEAdvertisedDevice │
├─────────────────────────────────────────────────────────────┤
│                    NimBLE Host Stack                        │
├─────────────────────────────────────────────────────────────┤
│                 ESP32 BLE Controller                        │
└─────────────────────────────────────────────────────────────┘
```

**Initialization Pattern**:
```cpp
#include <NimBLEDevice.h>

NimBLEDevice::init("");
NimBLEScan* pScan = NimBLEDevice::getScan();
pScan->setAdvertisedDeviceCallbacks(new MyCallbacks());
pScan->setActiveScan(true);   // Request scan response
pScan->setInterval(50);       // 50ms between scans
pScan->setWindow(50);         // 50ms scan window (100% duty)
pScan->start(1, false);       // 1 second scan, don't clear results
```

### 3.2 BLE Advertisement Packet Structure

Advertisements contain **AD (Advertising Data) structures**:

| AD Type | Name | Detection Use |
|---------|------|---------------|
| `0x01` | Flags | Device capabilities |
| `0x02/0x03` | Incomplete/Complete 16-bit UUIDs | Standard services |
| `0x06/0x07` | Incomplete/Complete 128-bit UUIDs | **Raven fingerprinting** |
| `0x08/0x09` | Short/Complete Local Name | **Device name matching** |
| `0xFF` | Manufacturer Specific | Vendor data |

### 3.3 Scan Parameter Optimization

**Duty Cycle = Window / Interval × 100%**

| Profile | Interval | Window | Duty | Power | Detection |
|---------|----------|--------|------|-------|-----------|
| Aggressive | 50ms | 50ms | 100% | High | Maximum |
| Balanced | 50ms | 30ms | 60% | Medium | Good |
| Power-save | 100ms | 30ms | 30% | Low | Reduced |

```cpp
// Profile-based configuration
const ScanProfileConfig profiles[] = {
    { "HIGHWAY", 50, 50 },   // 100% duty, catch fast-moving devices
    { "URBAN",   50, 50 },   // 100% duty, balanced
    { "SWEEP",   50, 30 }    // 60% duty, energy saving
};
```

### 3.4 Active vs Passive Scanning

| Mode | Behavior | Advantage | Disadvantage |
|------|----------|-----------|--------------|
| **Passive** | Listen only | Stealthy, low power | Limited data (31 bytes max) |
| **Active** | Send SCAN_REQ | Gets SCAN_RSP with more data | Detectable, uses airtime |

**Recommendation**: Use active scanning—surveillance devices aren't typically monitoring for scanners.

### 3.5 MAC Address Types in BLE

| Type | Format | Persistence | Detection Impact |
|------|--------|-------------|------------------|
| **Public** | IEEE OUI-based | Permanent | Reliable fingerprinting |
| **Static Random** | Bit 47:46 = 11 | Per-power-cycle | Semi-reliable |
| **Private Resolvable** | Bit 47:46 = 01 | Rotating | Difficult to track |
| **Private Non-Resolvable** | Bit 47:46 = 00 | Rotating | Cannot track |

Surveillance devices typically use **public** or **static random** addresses for reliability.

---

## 4. Device Fingerprinting

### 4.1 MAC OUI Vendor Identification

The **Organizationally Unique Identifier (OUI)** comprises the first 3 bytes of a MAC address:

```
MAC Address: 58:8e:81:xx:xx:xx
             ├─────────┤
                 OUI → "FS Ext Battery" device manufacturer
```

**Known Flock Safety OUI Prefixes** (from codebase analysis):

```c
static const char* mac_prefixes[] = {
    // FS Ext Battery (BLE beacons)
    "58:8e:81", "58:8e:87", "cc:cc:cc", "ec:1b:bd", "90:35:ea",
    "04:0d:84", "f0:82:c0", "1c:34:f1", "38:5b:44", "94:34:69",
    "b4:e3:f9", "90:35:86",
    
    // Flock WiFi devices
    "70:c9:4e", "3c:91:80", "d8:f3:bc", "80:30:49", "14:5a:fc",
    "74:4c:a1", "08:3a:88", "9c:2f:9d", "94:08:53", "e4:aa:ea",
    // ... (17K+ patterns in detection_patterns.h)
};
```

**Matching Algorithm**:
```c
bool checkMacPrefix(const uint8_t* mac) {
    char macStr[9];
    snprintf(macStr, sizeof(macStr), "%02x:%02x:%02x", 
             mac[0], mac[1], mac[2]);
    
    for (int i = 0; i < MAC_PREFIX_COUNT && i < MAX_ITERATIONS; i++) {
        if (strncasecmp(macStr, mac_prefixes[i], 8) == 0) {
            return true;
        }
    }
    return false;
}
```

### 4.2 SSID Pattern Matching

Flock Safety and related devices use identifiable SSID patterns:

| Pattern | Device Type | Protocol |
|---------|-------------|----------|
| `FLOCK*` | Flock Safety ALPR | WiFi |
| `FS Ext Battery` | Extended Battery Module | WiFi/BLE |
| `Penguin*` | Penguin surveillance | WiFi/BLE |
| `Pigvision*` | Pigvision systems | WiFi |
| `Raven*` | ShotSpotter gunshot detector | BLE |

```c
bool checkSsidPattern(const char* ssid) {
    static const char* patterns[] = {
        "FLOCK", "Flock", "flock",
        "FS Ext Battery", "FS+Ext+Battery",
        "Penguin", "Pigvision"
    };
    
    for (int i = 0; i < PATTERN_COUNT; i++) {
        if (strcasestr(ssid, patterns[i])) {
            return true;
        }
    }
    return false;
}
```

### 4.3 BLE Service UUID Fingerprinting (Raven/ShotSpotter)

The most reliable Raven detection method—matching advertised BLE service UUIDs:

#### Raven Service UUID Reference

| Service UUID | Description | Firmware | Detection Priority |
|--------------|-------------|----------|-------------------|
| `00003100-0000-1000-8000-00805f9b34fb` | GPS Location | 1.2.0+ | **HIGH** (unique) |
| `00003200-0000-1000-8000-00805f9b34fb` | Power/Battery | 1.2.0+ | HIGH |
| `00003300-0000-1000-8000-00805f9b34fb` | Network Status | 1.2.0+ | HIGH |
| `00003400-0000-1000-8000-00805f9b34fb` | Upload Stats | 1.2.0+ | MEDIUM |
| `00003500-0000-1000-8000-00805f9b34fb` | Error/Failure | 1.2.0+ | MEDIUM |
| `0000180a-0000-1000-8000-00805f9b34fb` | Device Info | All | LOW (standard) |
| `00001809-0000-1000-8000-00805f9b34fb` | Health (Legacy) | 1.1.x | MEDIUM |
| `00001819-0000-1000-8000-00805f9b34fb` | Location (Legacy) | 1.1.x | MEDIUM |

#### GATT Characteristics (from raven_configurations.json)

**Firmware 1.3.1 Full Characteristic Set**:

| Service | Characteristic | UUID | Data |
|---------|----------------|------|------|
| GPS (0x3100) | Latitude | 0x3101 | Float |
| GPS (0x3100) | Longitude | 0x3102 | Float |
| GPS (0x3100) | Altitude | 0x3103 | Float |
| Power (0x3200) | Board Temp | 0x3201 | String |
| Power (0x3200) | Battery Voltage | 0x3202 | String |
| Power (0x3200) | Charge Current | 0x3203 | String |
| Power (0x3200) | Solar Voltage | 0x3204 | String |
| Power (0x3200) | Battery State | 0x3205 | String |
| Network (0x3300) | LTE RSSI | 0x3304 | String |
| Network (0x3300) | WiFi SSID | 0x3308 | String |
| Upload (0x3400) | Audio Uploads | 0x3403 | Count |

**UUID Matching Implementation**:
```cpp
bool checkRavenServiceUuid(NimBLEAdvertisedDevice* device) {
    if (!device->haveServiceUUID()) return false;
    
    static const char* raven_uuids[] = {
        "00003100-0000-1000-8000-00805f9b34fb",  // GPS
        "00003200-0000-1000-8000-00805f9b34fb",  // Power
        "00003300-0000-1000-8000-00805f9b34fb",  // Network
        "00003400-0000-1000-8000-00805f9b34fb",  // Upload
        "00003500-0000-1000-8000-00805f9b34fb",  // Error
        "00001809-0000-1000-8000-00805f9b34fb",  // Legacy Health
        "00001819-0000-1000-8000-00805f9b34fb"   // Legacy Location
    };
    
    int serviceCount = min(device->getServiceUUIDCount(), 16);
    for (int i = 0; i < serviceCount; i++) {
        std::string uuid = device->getServiceUUID(i).toString();
        for (int j = 0; j < 7; j++) {
            if (strcasecmp(uuid.c_str(), raven_uuids[j]) == 0) {
                return true;
            }
        }
    }
    return false;
}
```

### 4.4 Firmware Version Detection

Raven firmware version can be inferred from advertised services:

| Services Present | Firmware Version |
|------------------|------------------|
| 0x1809, 0x1819 only | 1.1.x (Legacy) |
| 0x3100, 0x3200, 0x3300 | 1.2.x |
| 0x3100–0x3500 + 0x3205 | 1.3.x (Latest) |

---

## 5. Signal Analysis & Ranging

### 5.1 RSSI Interpretation Scale

**RSSI (Received Signal Strength Indicator)** measures signal power in dBm:

| RSSI Range | Signal Quality | Detection Confidence | Typical Distance |
|------------|----------------|---------------------|------------------|
| **> -50 dBm** | Excellent | Very High | < 3m |
| **-50 to -65 dBm** | Good | High | 3-10m |
| **-65 to -75 dBm** | Fair | Medium | 10-25m |
| **-75 to -85 dBm** | Weak | Low | 25-50m |
| **< -85 dBm** | Poor | Very Low | > 50m |

### 5.2 Path Loss Model for Distance Estimation

The log-distance path loss model:

```
d = 10^((A - RSSI) / (10 × n))
```

Where:
- **d** = Estimated distance (meters)
- **A** = RSSI at 1 meter reference distance (typically -40 to -60 dBm)
- **RSSI** = Measured signal strength (dBm)
- **n** = Path loss exponent

| Environment | Path Loss Exponent (n) |
|-------------|------------------------|
| Free space | 2.0 |
| Open outdoor | 2.0–2.5 |
| Urban outdoor | 2.7–3.5 |
| Indoor (light walls) | 3.0–4.0 |
| Indoor (heavy walls) | 4.0–6.0 |

**Example Calculation**:
```
Given: A = -45 dBm, RSSI = -72 dBm, n = 2.5 (urban)
d = 10^((-45 - (-72)) / (10 × 2.5))
d = 10^(27 / 25)
d = 10^1.08
d ≈ 12 meters
```

### 5.3 RSSI Variability and Filtering

**Expect ±6 dB fluctuation** due to:
- Multipath interference
- Antenna orientation
- Body/vehicle shadowing
- Environmental changes

**Filtering Recommendations**:
```c
#define RSSI_SAMPLES 5

int filterRssi(int newRssi) {
    static int samples[RSSI_SAMPLES];
    static int index = 0;
    
    samples[index] = newRssi;
    index = (index + 1) % RSSI_SAMPLES;
    
    // Running average
    int sum = 0;
    for (int i = 0; i < RSSI_SAMPLES; i++) {
        sum += samples[i];
    }
    return sum / RSSI_SAMPLES;
}
```

### 5.4 Confidence Scoring (FLOCK-ER Meter)

The codebase implements a rolling window confidence meter:

```c
#define ASSURITY_WINDOW_SIZE 12
#define ASSURITY_DECAY_MS 30000

int assurityBuffer[ASSURITY_WINDOW_SIZE];
int assurityLevel = 0;

void recordPositiveDetection(int score) {
    // score: 1-10 based on detection quality
    // FLOCK/RAVEN direct match = 10
    // MAC prefix match = 7
    // Weak signal match = 3
    
    assurityBuffer[index] = constrain(score, 1, 10);
    index = (index + 1) % ASSURITY_WINDOW_SIZE;
    
    // Calculate percentage
    int sum = 0;
    for (int i = 0; i < ASSURITY_WINDOW_SIZE; i++) {
        sum += assurityBuffer[i];
    }
    assurityLevel = (sum * 100) / (ASSURITY_WINDOW_SIZE * 10);
}

const char* getAssurityLabel(int level) {
    if (level >= 75) return "CONFIRMED";
    if (level >= 50) return "LIKELY";
    if (level >= 25) return "POSSIBLE";
    return "SCANNING";
}
```

---

## 6. Detection Targets Reference

### 6.1 Flock Safety ALPR Cameras

**Primary Detection Methods**: WiFi SSID, MAC OUI, BLE device name

| Attribute | Pattern | Priority |
|-----------|---------|----------|
| WiFi SSID | `FLOCK*`, `Flock-*`, `FS_*` | HIGH |
| MAC Prefix | See §4.1 (17K+ patterns) | HIGH |
| BLE Name | `Flock*`, `FLOCK*` | MEDIUM |

**Physical Characteristics**:
- Mounted on poles/streetlights
- Solar-powered variants common
- Cellular backhaul (LTE)

### 6.2 FS Extended Battery

**Primary Detection Methods**: BLE advertisement, WiFi probe

| Attribute | Pattern | Priority |
|-----------|---------|----------|
| BLE Name | `FS Ext Battery`, `FS+Ext+Battery` | **CRITICAL** |
| MAC Prefix | `58:8e:81`, `58:8e:87` | HIGH |
| WiFi SSID | `FS Ext Battery` | HIGH |

**Note**: Extended batteries advertise more frequently than cameras—often the first detected component.

### 6.3 Raven Gunshot Detectors (SoundThinking/ShotSpotter)

**Primary Detection Methods**: BLE Service UUID fingerprinting

| Attribute | Pattern | Priority |
|-----------|---------|----------|
| Service UUID | `00003100-*` (GPS) | **CRITICAL** |
| Service UUID | `00003200-*` (Power) | HIGH |
| BLE Name | `Raven*`, `ShotSpotter*` | MEDIUM |

**Firmware Versions in Field**:
- 1.1.7 (Legacy)
- 1.2.0 (Transitional)
- 1.3.1 (Current)

**Threat Score**: 100 (maximum) due to acoustic surveillance capability.

### 6.4 Penguin Surveillance Devices

| Attribute | Pattern | Priority |
|-----------|---------|----------|
| WiFi SSID | `Penguin*` | HIGH |
| BLE Name | `Penguin*` | HIGH |

### 6.5 Pigvision Systems

| Attribute | Pattern | Priority |
|-----------|---------|----------|
| WiFi SSID | `Pigvision*` | MEDIUM |
| BLE Name | `Pigvision*` | MEDIUM |

---

## 7. ESP32-S3 Hardware Considerations

### 7.1 Heltec WiFi LoRa 32 V3/V4 Specifics

| Component | GPIO | Notes |
|-----------|------|-------|
| OLED SDA | 17 | 128x64 SSD1306 |
| OLED SCL | 18 | I2C clock |
| OLED RST | 21 | Display reset |
| Vext Power | 36 | OLED power control |
| PRG Button | 0 | User/reset button |
| LED | 35 | Status indicator |

**OLED Power Sequence**:
```c
// Enable OLED power
pinMode(VEXT_PIN, OUTPUT);
digitalWrite(VEXT_PIN, LOW);  // Active LOW

// Reset display
pinMode(OLED_RST, OUTPUT);
digitalWrite(OLED_RST, LOW);
delay(50);
digitalWrite(OLED_RST, HIGH);

// Initialize
Wire.begin(OLED_SDA, OLED_SCL);
display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
```

### 7.2 Concurrent WiFi/BLE Operation

ESP32-S3 shares a single radio between protocols:

| Configuration | WiFi Impact | BLE Impact |
|---------------|-------------|------------|
| WiFi Priority | Full throughput | Delayed scans |
| BLE Priority | Missed packets | Full scan rate |
| Balanced | Channel hop during BLE gaps | Scan during WiFi switch |

**Recommended Approach**:
```c
void loop() {
    // 1. WiFi channel hop (fast)
    hopChannel();
    
    // 2. BLE scan during WiFi dwell time
    if (millis() - lastBleScan >= bleScanInterval) {
        pBLEScan->start(1, false);  // 1 second async scan
        lastBleScan = millis();
    }
    
    // 3. Process results
    updateDisplay();
}
```

### 7.3 Hardware Watchdog Timer

JPL Rule 6 compliance—automatic recovery from hangs:

```c
#include "esp_task_wdt.h"

#define WDT_TIMEOUT_SEC 30

void setup() {
    esp_task_wdt_init(WDT_TIMEOUT_SEC, true);  // 30s, panic=true
    esp_task_wdt_add(NULL);  // Add current task
}

void loop() {
    esp_task_wdt_reset();  // Pet the watchdog each iteration
    // ... processing
}
```

### 7.4 NVS Persistent Storage

Retain detection statistics across power cycles:

```c
#include <Preferences.h>

Preferences prefs;

void loadPersistentData() {
    prefs.begin("deflock", true);  // read-only
    totalDetections = prefs.getInt("totalDet", 0);
    flockDetections = prefs.getInt("flockDet", 0);
    ravenDetections = prefs.getInt("ravenDet", 0);
    prefs.end();
}

void savePersistentData() {
    prefs.begin("deflock", false);  // read-write
    prefs.putInt("totalDet", totalDetections);
    prefs.putInt("flockDet", flockDetections);
    prefs.putInt("ravenDet", ravenDetections);
    prefs.end();
}
```

---

## 8. Code Patterns & Best Practices

### 8.1 Deduplication and Rate Limiting

Prevent alert spam while maintaining tracking:

```c
#define DEDUP_CACHE_SIZE 16
#define DEDUP_COOLDOWN_MS 3000

struct DedupEntry {
    char macAddress[18];
    unsigned long lastSeen;
};
static DedupEntry dedupCache[DEDUP_CACHE_SIZE];

bool shouldAlertForDevice(const char* macAddr) {
    unsigned long now = millis();
    
    for (int i = 0; i < DEDUP_CACHE_SIZE; i++) {
        if (strcasecmp(dedupCache[i].macAddress, macAddr) == 0) {
            if (now - dedupCache[i].lastSeen < DEDUP_COOLDOWN_MS) {
                dedupCache[i].lastSeen = now;
                return false;  // Still in cooldown
            }
            dedupCache[i].lastSeen = now;
            return true;  // Cooldown expired
        }
    }
    
    // New device - add to cache
    addToCache(macAddr, now);
    return true;
}
```

### 8.2 Input Sanitization

Prevent buffer overflows and injection:

```c
static void sanitizeString(char* dest, const char* src, size_t maxLen) {
    if (!dest || maxLen == 0) return;
    if (!src) { dest[0] = '\0'; return; }
    
    size_t i = 0, j = 0;
    while (i < maxLen - 1 && src[j] != '\0') {
        // Only printable ASCII
        if (src[j] >= 0x20 && src[j] <= 0x7E) {
            dest[i++] = src[j];
        }
        j++;
    }
    dest[i] = '\0';
}

static int sanitizeRssi(int rssi) {
    return constrain(rssi, -127, 0);
}

static bool isValidMacFormat(const char* mac) {
    if (!mac || strlen(mac) != 17) return false;
    for (int i = 0; i < 17; i++) {
        if (i % 3 == 2) {
            if (mac[i] != ':') return false;
        } else {
            if (!isxdigit(mac[i])) return false;
        }
    }
    return true;
}
```

### 8.3 Bounded Loops (JPL Rule Compliance)

All loops must have static upper bounds:

```c
#define MAX_PATTERN_ITERATIONS 64
#define MAX_SERVICE_UUID_ITERATIONS 16

bool checkMacPrefix(const uint8_t* mac) {
    // Explicit bound prevents runaway iteration
    const int iterLimit = min(MAC_PREFIX_COUNT, MAX_PATTERN_ITERATIONS);
    
    for (int i = 0; i < iterLimit; i++) {
        if (matchesPrefix(mac, mac_prefixes[i])) {
            return true;
        }
    }
    return false;
}
```

### 8.4 Scan Profile System

Configurable profiles for different use cases:

```c
enum ScanProfile { PROFILE_HIGHWAY, PROFILE_URBAN, PROFILE_SWEEP };

struct ScanProfileConfig {
    const char* name;
    const char* shortName;
    int channelHopMs;
    int bleScanDuration;
    int bleScanInterval;
    int bleWindow;  // Duty cycle control
};

static const ScanProfileConfig profiles[] = {
    { "HIGHWAY", "HWY+", 50,  1, 300, 50 },  // 100% BLE duty
    { "URBAN",   "URB~", 100, 1, 500, 50 },  // 100% BLE duty
    { "SWEEP",   "SWP-", 250, 1, 800, 30 }   // 60% BLE duty
};

void applyScanProfile(ScanProfile profile) {
    channelHopInterval = profiles[profile].channelHopMs;
    pBLEScan->setWindow(profiles[profile].bleWindow);
    pBLEScan->setInterval(50);  // Keep interval constant
}
```

### 8.5 Threat Scoring Algorithm

```c
int calculateThreatScore(const char* deviceType, int rssi) {
    int score = 70;  // Base score
    
    // Device type bonuses
    if (strstr(deviceType, "FLOCK")) score = 95;
    else if (strstr(deviceType, "RAVEN")) score = 100;  // Max threat
    else if (strstr(deviceType, "PENGUIN")) score = 90;
    
    // Signal strength adjustment
    if (rssi > -50) score = min(score + 5, 100);  // Very close
    if (rssi < -80) score = max(score - 10, 50);  // Far away
    
    return score;
}
```

---

## Quick Reference Card

### WiFi Detection Pipeline

```
[Start] → Enable Promiscuous → Register Callback → Set Channel
                                     ↓
                              Receive Packet
                                     ↓
                          Validate Frame Type (MGMT)
                                     ↓
                      Extract: Addr2 (MAC), SSID
                                     ↓
                    Match: OUI prefix OR SSID pattern
                                     ↓
                          [DETECTION ALERT]
```

### BLE Detection Pipeline

```
[Start] → Init NimBLE → Configure Scan → Start Scanning
                                ↓
                        onResult Callback
                                ↓
                    Extract: MAC, Name, Service UUIDs
                                ↓
            Match: MAC prefix OR Name pattern OR Raven UUID
                                ↓
                          [DETECTION ALERT]
```

### Critical UUIDs to Remember

| UUID | Device | Type |
|------|--------|------|
| `00003100-*` | Raven GPS | BLE Service |
| `00003200-*` | Raven Power | BLE Service |
| `58:8e:81:*` | FS Battery | MAC OUI |
| `FLOCK*` | Flock Camera | WiFi SSID |

---

## 9. Kismet Wireless Monitoring

Kismet is an **open-source 802.11 wireless network detector, sniffer, and WIDS (Wireless Intrusion Detection System)** that operates in passive mode, making it ideal for surveillance device detection.

### 9.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Kismet Architecture                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌───────────────┐     ┌───────────────┐     ┌───────────────┐     │
│   │ kismet_server │ ←── │ kismet_client │     │    Drones     │     │
│   │  (Core/UI)    │     │   (Web UI)    │     │ (Remote Cap)  │     │
│   └───────────────┘     └───────────────┘     └───────────────┘     │
│          ↑                                           │              │
│          │                                           │              │
│   ┌──────┴──────────────────────────────────────────┴───────┐       │
│   │                    Datasources                           │       │
│   │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐     │       │
│   │  │ WiFi    │  │   BLE   │  │ RTL-SDR │  │ ADSB    │     │       │
│   │  │ Adapter │  │ Adapter │  │  433MHz │  │ Decoder │     │       │
│   │  └─────────┘  └─────────┘  └─────────┘  └─────────┘     │       │
│   └──────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────┘
```

**Components**:
- **kismet_server**: Centralized packet decoding, device tracking, alerting
- **kismet_client**: Web-based UI (default port 2501)
- **Datasources**: Capture interfaces (WiFi, BLE, SDR, etc.)
- **Drones**: Remote capture devices forwarding packets to server

### 9.2 Installation & Basic Setup

```bash
# Ubuntu/Debian
sudo apt-get install kismet kismet-plugins

# Add user to kismet group (avoids sudo for captures)
sudo usermod -aG kismet $USER

# Start Kismet
kismet
```

**Access Web UI**: `http://localhost:2501`

### 9.3 Datasource Configuration

Edit `/etc/kismet/kismet.conf` or pass via CLI:

```bash
# WiFi interface in monitor mode
kismet -c wlan0mon

# Multiple sources
kismet -c wlan0mon -c wlan1mon -c hci0:type=linuxbluetooth

# Remote capture (from drone device)
kismet_cap_linux_wifi --connect 192.168.1.100:3501 --source wlan0mon
```

**kismet.conf datasource examples**:
```ini
# WiFi with channel hopping
source=wlan0mon:name=wifi_monitor,hop=true,hop_rate=5/sec

# Lock to specific channels (surveillance hotspots)
source=wlan1mon:name=fixed_scanner,channels="1,6,11"

# Bluetooth/BLE via HCI
source=hci0:type=linuxbluetooth,name=ble_scanner

# RTL-SDR for 433MHz ISM
source=rtl433-0:type=rtl433,name=ism_scanner
```

### 9.4 Remote Capture (Distributed Scanning)

**Server Configuration** (`kismet.conf`):
```ini
remote_capture_enabled=true
remote_capture_listen=0.0.0.0
remote_capture_port=3501
```

**Drone/Remote Device**:
```bash
# On remote Raspberry Pi with WiFi adapter
kismet_cap_linux_wifi --tcp --connect 192.168.1.10:3501 --source wlan0mon
```

### 9.5 REST API for Automation

Kismet provides a comprehensive REST API for scripting detection systems:

```bash
# Get all devices (JSON)
curl -u admin:password http://localhost:2501/devices/all_devices.json

# Filter by device type
curl http://localhost:2501/devices/by-type/Wi-Fi%20AP/devices.json

# Get device by MAC
curl http://localhost:2501/devices/by-mac/AA:BB:CC:DD:EE:FF/device.json

# Subscribe to alerts
curl http://localhost:2501/alerts/last-time/0/alerts.json
```

**Python Automation Example**:
```python
import requests
import json

KISMET_URL = "http://localhost:2501"
AUTH = ("admin", "password")

def get_all_devices():
    resp = requests.get(f"{KISMET_URL}/devices/all_devices.json", auth=AUTH)
    return resp.json()

def find_flock_devices():
    devices = get_all_devices()
    flock_matches = []
    for dev in devices:
        ssid = dev.get("kismet.device.base.name", "")
        mac = dev.get("kismet.device.base.macaddr", "")
        if "FLOCK" in ssid.upper() or "FS EXT" in ssid.upper():
            flock_matches.append({"mac": mac, "ssid": ssid})
    return flock_matches

# Poll for new detections
for match in find_flock_devices():
    print(f"FLOCK DEVICE: {match['ssid']} - {match['mac']}")
```

### 9.6 Custom Alerts for Surveillance Detection

**kismet_alerts.conf**:
```ini
# Alert on specific SSID patterns
alert=SURVSSID,10/min,5/sec,Surveillance SSID detected

# Alert on OUI prefixes
alert=SURVOUI,10/min,5/sec,Surveillance device OUI detected
```

**kismet_filter.conf** (filter specific MACs/SSIDs):
```ini
# Track these SSIDs
ssid_track=FLOCK,Penguin,Pigvision,FS Ext Battery

# Track these OUI prefixes  
oui_track=58:8E:81,70:C9:4E,3C:91:80
```

### 9.7 Log Formats & Analysis

| Format | Extension | Use |
|--------|-----------|-----|
| **Kismet DB** | `.kismet` | SQLite3, full device/packet data |
| **PCAP-NG** | `.pcapng` | Wireshark-compatible packets |
| **JSON** | `.json` | Device summaries |

**Extract devices from Kismet DB**:
```bash
sqlite3 Kismet-*.kismet "SELECT devmac,type,phyname FROM devices;"
```

**Convert to Wireshark-compatible PCAP**:
```bash
kismetdb-to-pcap --in Kismet-*.kismet --out capture.pcapng
```

---

## 10. Linux Monitor Mode & Channel Control

### 10.1 Enable Monitor Mode with airmon-ng

**airmon-ng** (from Aircrack-ng suite) is the most reliable method:

```bash
# Install Aircrack-ng
sudo apt-get install aircrack-ng

# List wireless interfaces
sudo airmon-ng

# Kill interfering processes (NetworkManager, wpa_supplicant)
sudo airmon-ng check kill

# Start monitor mode (creates wlan0mon)
sudo airmon-ng start wlan0

# Verify
iwconfig wlan0mon
# Mode:Monitor  Frequency:2.437 GHz

# Stop monitor mode
sudo airmon-ng stop wlan0mon
```

### 10.2 Manual Monitor Mode (iw/iwconfig)

When airmon-ng isn't available:

```bash
# Bring interface down
sudo ip link set wlan0 down

# Set monitor mode
sudo iw dev wlan0 set type monitor

# Bring interface up
sudo ip link set wlan0 up

# Verify
iw dev wlan0 info
# type monitor
```

### 10.3 Channel Control with iw

```bash
# Set specific channel
sudo iw dev wlan0mon set channel 6

# Set channel with HT mode (for 802.11n)
sudo iw dev wlan0mon set channel 6 HT20
sudo iw dev wlan0mon set channel 6 HT40+

# Verify current channel
iw dev wlan0mon info | grep channel
```

### 10.4 Automated Channel Hopping Script

```bash
#!/bin/bash
# channel_hopper.sh - Hop through 2.4GHz channels

INTERFACE="wlan0mon"
CHANNELS="1 2 3 4 5 6 7 8 9 10 11 12 13"
HOP_INTERVAL=0.25  # 250ms

while true; do
    for ch in $CHANNELS; do
        iw dev "$INTERFACE" set channel "$ch" 2>/dev/null
        sleep "$HOP_INTERVAL"
    done
done
```

### 10.5 Check Adapter Capabilities

```bash
# Does adapter support monitor mode?
iw list | grep -A 10 "Supported interface modes" | grep monitor

# Supported channels/frequencies
iw list | grep -A 50 "Frequencies:"

# Driver information
ethtool -i wlan0
```

**Recommended Adapters for Monitor Mode**:

| Chipset | Driver | Monitor | Injection | Notes |
|---------|--------|---------|-----------|-------|
| **Atheros AR9271** | ath9k_htc | ✅ | ✅ | ALFA AWUS036NHA |
| **Ralink RT3070** | rt2800usb | ✅ | ✅ | Common, well-supported |
| **Realtek RTL8812AU** | rtl8812au | ✅ | ✅ | 5GHz support |
| **MediaTek MT7612U** | mt76x2u | ✅ | ✅ | Dual-band |

---

## 11. Scapy Python Packet Analysis

Scapy is a powerful Python library for packet crafting and analysis, ideal for building custom surveillance detection scripts.

### 11.1 Installation & Setup

```bash
pip install scapy

# For full 802.11 support
sudo apt-get install tcpdump
```

### 11.2 Basic WiFi Sniffing

```python
#!/usr/bin/env python3
from scapy.all import *

def packet_handler(pkt):
    if pkt.haslayer(Dot11):
        # Extract frame type/subtype
        frame_type = pkt.type
        frame_subtype = pkt.subtype
        
        # Get addresses
        src_mac = pkt.addr2
        dst_mac = pkt.addr1
        bssid = pkt.addr3
        
        print(f"Type: {frame_type}, Subtype: {frame_subtype}")
        print(f"  Src: {src_mac}, Dst: {dst_mac}, BSSID: {bssid}")

# Sniff on monitor interface
sniff(iface="wlan0mon", prn=packet_handler, count=100, store=0)
```

### 11.3 Extract SSIDs from Beacons/Probes

```python
#!/usr/bin/env python3
from scapy.all import *

detected_ssids = set()

def extract_ssid(pkt):
    if pkt.haslayer(Dot11Beacon) or pkt.haslayer(Dot11ProbeResp):
        ssid = pkt[Dot11Elt].info.decode('utf-8', errors='ignore')
        bssid = pkt[Dot11].addr3
        
        if ssid and (bssid, ssid) not in detected_ssids:
            detected_ssids.add((bssid, ssid))
            
            # Check for surveillance patterns
            if any(p in ssid.upper() for p in ['FLOCK', 'PENGUIN', 'FS EXT']):
                print(f"🚨 SURVEILLANCE: {ssid} ({bssid})")
            else:
                print(f"Network: {ssid} ({bssid})")

sniff(iface="wlan0mon", prn=extract_ssid, store=0)
```

### 11.4 BPF Filters for Targeted Capture

```python
# Management frames only (beacons, probes)
sniff(iface="wlan0mon", filter="type mgt", prn=handler)

# Beacons only (subtype 8)
sniff(iface="wlan0mon", filter="type mgt subtype beacon", prn=handler)

# Probe requests (subtype 4)
sniff(iface="wlan0mon", filter="type mgt subtype probe-req", prn=handler)

# Frames from specific BSSID
sniff(iface="wlan0mon", filter="wlan addr2 AA:BB:CC:DD:EE:FF", prn=handler)
```

### 11.5 RadioTap Header Parsing (RSSI)

```python
def get_rssi(pkt):
    if pkt.haslayer(RadioTap):
        # dBm signal strength
        try:
            rssi = pkt[RadioTap].dBm_AntSignal
            return rssi
        except:
            return None
    return None

def handler_with_rssi(pkt):
    if pkt.haslayer(Dot11Beacon):
        ssid = pkt[Dot11Elt].info.decode('utf-8', errors='ignore')
        bssid = pkt[Dot11].addr3
        rssi = get_rssi(pkt)
        print(f"{ssid} ({bssid}) RSSI: {rssi} dBm")

sniff(iface="wlan0mon", filter="type mgt subtype beacon", prn=handler_with_rssi)
```

### 11.6 Save Captures for Wireshark

```python
from scapy.all import *

# Capture and save
packets = sniff(iface="wlan0mon", count=1000)
wrpcap("surveillance_capture.pcap", packets)

# Read existing capture
packets = rdpcap("surveillance_capture.pcap")
for pkt in packets:
    if pkt.haslayer(Dot11Beacon):
        print(pkt.summary())
```

### 11.7 Complete Surveillance Detector Script

```python
#!/usr/bin/env python3
"""Scapy-based surveillance device detector"""

from scapy.all import *
from datetime import datetime
import json

SURVEILLANCE_SSIDS = ["FLOCK", "PENGUIN", "PIGVISION", "FS EXT", "RAVEN"]
SURVEILLANCE_OUIS = ["58:8E:81", "70:C9:4E", "3C:91:80", "D8:F3:BC"]

detections = []

def check_surveillance(ssid, mac):
    # SSID check
    for pattern in SURVEILLANCE_SSIDS:
        if pattern in ssid.upper():
            return True, f"SSID match: {pattern}"
    
    # OUI check
    oui = mac[:8].upper()
    if oui in SURVEILLANCE_OUIS:
        return True, f"OUI match: {oui}"
    
    return False, None

def surveillance_handler(pkt):
    if pkt.haslayer(Dot11Beacon) or pkt.haslayer(Dot11ProbeResp):
        try:
            ssid = pkt[Dot11Elt].info.decode('utf-8', errors='ignore')
            bssid = pkt[Dot11].addr3
            rssi = pkt[RadioTap].dBm_AntSignal if pkt.haslayer(RadioTap) else None
            
            is_surveillance, reason = check_surveillance(ssid, bssid)
            
            if is_surveillance:
                detection = {
                    "timestamp": datetime.now().isoformat(),
                    "ssid": ssid,
                    "bssid": bssid,
                    "rssi": rssi,
                    "reason": reason
                }
                detections.append(detection)
                print(f"🚨 ALERT: {json.dumps(detection)}")
        except Exception as e:
            pass

print("Starting surveillance detection...")
print("Monitoring for: " + ", ".join(SURVEILLANCE_SSIDS))
try:
    sniff(iface="wlan0mon", prn=surveillance_handler, store=0)
except KeyboardInterrupt:
    print(f"\nTotal detections: {len(detections)}")
    with open("detections.json", "w") as f:
        json.dump(detections, f, indent=2)
```

---

## 12. RTL-SDR & ISM Band Monitoring

RTL-SDR dongles enable monitoring of the **433MHz ISM band**, where many IoT devices and some surveillance equipment transmit.

### 12.1 RTL-SDR Hardware

| Dongle | Frequency Range | Notes |
|--------|-----------------|-------|
| **RTL-SDR Blog V3** | 500kHz–1.7GHz | Best sensitivity, bias-T |
| **NooElec NESDR** | 24MHz–1.7GHz | Budget option |
| **Generic RTL2832U** | 24MHz–1.7GHz | Varies by tuner |

### 12.2 rtl_433 Installation

```bash
# Ubuntu/Debian
sudo apt-get install rtl-sdr rtl-433

# macOS
brew install rtl_433

# From source
git clone https://github.com/merbanan/rtl_433.git
cd rtl_433 && mkdir build && cd build
cmake .. && make && sudo make install
```

### 12.3 Basic Usage

```bash
# Start monitoring (auto-detect devices)
rtl_433

# Analyze unknown signals
rtl_433 -a

# JSON output for parsing
rtl_433 -F json

# Specific frequency (433.92 MHz)
rtl_433 -f 433920000

# Multiple frequencies
rtl_433 -f 315000000 -f 433920000 -f 868000000
```

### 12.4 Protocol Decoders

rtl_433 includes 200+ decoders for common devices:

```bash
# List available decoders
rtl_433 -R help

# Enable specific decoders only
rtl_433 -R 40 -R 41    # Oregon Scientific sensors

# Disable specific decoders
rtl_433 -R -40         # Disable decoder 40
```

### 12.5 Custom Signal Analysis

For unknown surveillance devices:

```bash
# Analyze mode - capture and decode unknown signals
rtl_433 -a

# Save raw I/Q data for analysis
rtl_433 -S all         # Save all signals
rtl_433 -S unknown     # Save only unknown signals

# Output saved to g###_###M_###k.cu8 files
```

**Analyze saved signal**:
```bash
# Inspect binary patterns
rtl_433 -r g001_433.92M_250k.cu8 -A

# Decode with specific pulse parameters
rtl_433 -r g001_433.92M_250k.cu8 -X "n=custom,m=OOK_PWM,s=400,l=800,r=1000"
```

### 12.6 Continuous Monitoring Script

```bash
#!/bin/bash
# rtl_monitor.sh - Continuous ISM band monitoring with logging

LOG_DIR="/var/log/rtl_433"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="$LOG_DIR/ism_$TIMESTAMP.json"

rtl_433 -f 433920000 -f 315000000 -F json 2>/dev/null | \
    while read -r line; do
        echo "$line" >> "$LOGFILE"
        
        # Check for surveillance keywords
        if echo "$line" | grep -qi "flock\|raven\|surveillance"; then
            echo "ALERT: $line" | tee -a "$LOG_DIR/alerts.log"
        fi
    done
```

### 12.7 Python Integration

```python
#!/usr/bin/env python3
import subprocess
import json

def monitor_ism_band(callback, frequency=433920000):
    """Monitor ISM band and call callback for each decoded signal"""
    cmd = ["rtl_433", "-f", str(frequency), "-F", "json"]
    
    process = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        text=True, bufsize=1
    )
    
    for line in process.stdout:
        try:
            data = json.loads(line.strip())
            callback(data)
        except json.JSONDecodeError:
            pass

def surveillance_check(data):
    """Check if signal matches surveillance device patterns"""
    model = data.get("model", "").lower()
    if any(p in model for p in ["flock", "raven", "shot"]):
        print(f"🚨 ISM SURVEILLANCE: {data}")
    else:
        print(f"Device: {data.get('model')} - {data.get('id')}")

if __name__ == "__main__":
    monitor_ism_band(surveillance_check)
```

---

## 13. Wardriving Tools & Integration

### 13.1 WiGLE Integration

**WiGLE** (Wireless Geographic Logging Engine) is the premier wardriving database.

**API Setup**:
```bash
# Get API token from wigle.net/account
export WIGLE_API_NAME="your_api_name"
export WIGLE_API_TOKEN="your_api_token"
```

**Query nearby networks**:
```python
import requests

WIGLE_URL = "https://api.wigle.net/api/v2"
AUTH = (WIGLE_API_NAME, WIGLE_API_TOKEN)

def search_networks(lat, lon, radius_km=1):
    """Search WiGLE for networks near coordinates"""
    params = {
        "latrange1": lat - 0.01 * radius_km,
        "latrange2": lat + 0.01 * radius_km,
        "longrange1": lon - 0.01 * radius_km,
        "longrange2": lon + 0.01 * radius_km,
    }
    resp = requests.get(f"{WIGLE_URL}/network/search", params=params, auth=AUTH)
    return resp.json()

def find_surveillance_networks(lat, lon):
    """Find potential surveillance networks in WiGLE database"""
    networks = search_networks(lat, lon)
    for net in networks.get("results", []):
        ssid = net.get("ssid", "")
        if any(p in ssid.upper() for p in ["FLOCK", "PENGUIN", "FS EXT"]):
            print(f"📍 WIGLE HIT: {ssid} at ({net['trilat']}, {net['trilong']})")
```

### 13.2 Aircrack-ng Suite Integration

**airodump-ng** for passive scanning:
```bash
# Start capture with CSV output
sudo airodump-ng wlan0mon --write scan_output --output-format csv

# Target specific channel
sudo airodump-ng wlan0mon -c 6 --bssid AA:BB:CC:DD:EE:FF -w target
```

**Parse airodump-ng CSV**:
```python
import csv

def parse_airodump_csv(filepath):
    """Parse airodump-ng CSV output for surveillance devices"""
    with open(filepath, 'r') as f:
        reader = csv.reader(f)
        
        for row in reader:
            if len(row) < 14:
                continue
            
            bssid = row[0].strip()
            channel = row[3].strip()
            essid = row[13].strip() if len(row) > 13 else ""
            
            if any(p in essid.upper() for p in ["FLOCK", "PENGUIN"]):
                print(f"SURVEILLANCE: {essid} ({bssid}) Ch{channel}")
```

### 13.3 GPSd Integration (Geotagging)

**Start gpsd**:
```bash
sudo apt-get install gpsd gpsd-clients

# USB GPS
sudo gpsd /dev/ttyUSB0 -F /var/run/gpsd.sock

# Phone GPS via Bluetooth
sudo gpsd /dev/rfcomm0
```

**Python GPS client**:
```python
import gps

def get_current_position():
    """Get current GPS coordinates from gpsd"""
    session = gps.gps(mode=gps.WATCH_ENABLE)
    
    for report in session:
        if report['class'] == 'TPV':
            lat = getattr(report, 'lat', None)
            lon = getattr(report, 'lon', None)
            if lat and lon:
                return lat, lon
    return None, None
```

### 13.4 NetHunter Wardriving (Android)

Kali NetHunter provides mobile wardriving with GPS:

```bash
# Enable monitor mode on external adapter
airmon-ng start wlan1

# Start GPS publisher
sudo gpsctl -n /dev/ttyUSB0

# Launch Kismet with GPS and WiFi
kismet -c wlan1mon --use-gpsd-gps
```

### 13.5 Combined Detection Pipeline

```python
#!/usr/bin/env python3
"""Complete wardriving-style surveillance detector"""

import threading
import subprocess
import json
from datetime import datetime
import gps
import sqlite3

class SurveillanceDetector:
    def __init__(self, db_path="detections.db"):
        self.conn = sqlite3.connect(db_path, check_same_thread=False)
        self.setup_database()
        self.gps_position = (None, None)
    
    def setup_database(self):
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS detections (
                id INTEGER PRIMARY KEY,
                timestamp TEXT,
                ssid TEXT,
                bssid TEXT,
                rssi INTEGER,
                latitude REAL,
                longitude REAL,
                detection_type TEXT,
                protocol TEXT
            )
        """)
        self.conn.commit()
    
    def log_detection(self, ssid, bssid, rssi, detection_type, protocol):
        lat, lon = self.gps_position
        self.conn.execute(
            "INSERT INTO detections VALUES (NULL, ?, ?, ?, ?, ?, ?, ?, ?)",
            (datetime.now().isoformat(), ssid, bssid, rssi, 
             lat, lon, detection_type, protocol)
        )
        self.conn.commit()
        print(f"🚨 {protocol}: {ssid} ({bssid}) @ ({lat}, {lon})")
    
    def gps_thread(self):
        session = gps.gps(mode=gps.WATCH_ENABLE)
        for report in session:
            if report['class'] == 'TPV':
                self.gps_position = (
                    getattr(report, 'lat', None),
                    getattr(report, 'lon', None)
                )
    
    def kismet_thread(self, kismet_url="http://localhost:2501"):
        # Poll Kismet REST API
        import requests
        while True:
            try:
                resp = requests.get(f"{kismet_url}/devices/all_devices.json")
                for dev in resp.json():
                    ssid = dev.get("kismet.device.base.name", "")
                    if "FLOCK" in ssid.upper():
                        self.log_detection(ssid, dev.get("kismet.device.base.macaddr"),
                                          None, "FLOCK", "WIFI")
            except:
                pass
            time.sleep(5)
    
    def run(self):
        threads = [
            threading.Thread(target=self.gps_thread, daemon=True),
            threading.Thread(target=self.kismet_thread, daemon=True),
        ]
        for t in threads:
            t.start()
        
        print("Surveillance detector running. Press Ctrl+C to stop.")
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("Shutting down...")

if __name__ == "__main__":
    detector = SurveillanceDetector()
    detector.run()
```

---

## Quick Reference Card

### WiFi Detection Pipeline

```
[Start] → Enable Promiscuous → Register Callback → Set Channel
                                     ↓
                              Receive Packet
                                     ↓
                          Validate Frame Type (MGMT)
                                     ↓
                      Extract: Addr2 (MAC), SSID
                                     ↓
                    Match: OUI prefix OR SSID pattern
                                     ↓
                          [DETECTION ALERT]
```

### BLE Detection Pipeline

```
[Start] → Init NimBLE → Configure Scan → Start Scanning
                                ↓
                        onResult Callback
                                ↓
                    Extract: MAC, Name, Service UUIDs
                                ↓
            Match: MAC prefix OR Name pattern OR Raven UUID
                                ↓
                          [DETECTION ALERT]
```

### Kismet Detection Pipeline

```
[Start] → Configure Datasources → Start kismet_server
                                        ↓
                              Collect from WiFi/BLE/SDR
                                        ↓
                              Query REST API (devices.json)
                                        ↓
                          Filter: SSID/MAC/OUI patterns
                                        ↓
                            Log with GPS coordinates
                                        ↓
                              [DETECTION ALERT]
```

### Critical UUIDs to Remember

| UUID | Device | Type |
|------|--------|------|
| `00003100-*` | Raven GPS | BLE Service |
| `00003200-*` | Raven Power | BLE Service |
| `58:8e:81:*` | FS Battery | MAC OUI |
| `FLOCK*` | Flock Camera | WiFi SSID |

### Key Commands

| Task | Command |
|------|--------|
| Monitor mode | `sudo airmon-ng start wlan0` |
| Set channel | `sudo iw dev wlan0mon set channel 6` |
| Scapy sniff | `sniff(iface="wlan0mon", filter="type mgt")` |
| Kismet start | `kismet -c wlan0mon` |
| RTL-SDR scan | `rtl_433 -F json` |

---

## Production BT/WiFi Scanning on Raspberry Pi 5

> **Lessons learned from production deployment on headless Pi 5 under systemd.**

### WiFi Scanning: `iw wlan1 scan`

WiFi scanning uses the `iw` utility as a Kismet fallback.  Unlike BT
scanning, `iw` works reliably under systemd pipes because it uses direct
netlink sockets (not libc stdio).

```bash
# Production command (from Python subprocess)
sudo iw wlan1 scan

# Output: BSS entries with SSID, frequency, signal, capabilities
# Parsing: regex extraction of BSSID, SSID, signal, channel
```

**WiFi scan cycle:** scan (~2s) → process → wait (SCAN_INTERVAL=3s) → repeat

### BT Scanning: `btmgmt find -l` via `script -qc`

> ⚠️ **btmgmt MUST be wrapped in `script -qc` under systemd.**
> See [signals-bt-implementation.md](signals-bt-implementation.md) for the full explanation.

```bash
# Production command (from Python subprocess)
script -qc "sudo /usr/bin/btmgmt --index 1 find -l" /dev/null

# Pre-scan cleanup (kill orphaned btmgmt holding HCI in discovery mode)
sudo killall -q btmgmt && sleep 0.3
```

**BT scan cycle:** kill orphans → scan (~8s) → parse → wait (BT_SCAN_INTERVAL=10s) → repeat

### Unified Detection Pipeline

Both WiFi and BT devices flow through the same pipeline:

```
WiFi scan (iw) ─────┐
                     ├──→ fingerprint_db.record() → signal profiling + RSSI history
BT scan (btmgmt) ───┘         │
                               ▼
                        tracker.update() → persistence tracking (30s threshold)
                               │
                               ▼
                        Alert Tier 1/2/3 → WebSocket emit
                               │
                               ▼
                        tri_engine.add_observation() → GPS-tagged signal
                               │
                               ▼
                        SignalCorrelator → WiFi↔BLE device clustering
```

**Key insight:** BT devices that are only tracked by `bt_tracker` but not
fed into `fingerprint_db`, `tracker`, `tri_engine`, and `SignalCorrelator`
are invisible to the detection engine.  They appear on the BT tab but
generate no alerts, no fingerprints, and no correlation clusters.

### Alert Tier System

| Tier | Trigger | Cooldown | Example |
|------|---------|----------|---------|
| 1 | New unknown device (WiFi or BT) | 30s | New BLE device `LE Random` |
| 2 | Device persists >30s without ignore | 60s | Same phone seen 5 minutes |
| 3 | Surveillance OUI/SSID match | Immediate | Flock Safety `58:8E:81:*` |

### Verified Production Metrics (Residential Area)

| Metric | Value | Notes |
|--------|-------|-------|
| WiFi devices per scan | 8-15 | Depends on neighbor density |
| BT devices per scan | 15-30 | BLE advertising is pervasive |
| Total fingerprints | 30+ | WiFi + BT combined |
| Active detections | 25-35 | At any given time |
| Correlation clusters | 1-5 | WiFi↔BLE co-located devices |
| BT scan output size | 1.5-3 KB | 0 bytes = PTY buffering problem |

---

## Resources & References

### Companion Documents

- [Signals Quick Reference](signals-quickref.md) — Fast lookup cheat sheet
- [Signals BT Implementation](signals-bt-implementation.md) — btmgmt under systemd, PTY buffering fix, pipeline integration
- [Signals Acoustic Detection](signals-acoustic.md) — ShotSpotter/Raven audio, ESP32 microphones, ML classification
- [Signals LoRa & LPWAN](signals-lora-lpwan.md) — LoRa sniffing, Meshtastic detection, regional frequencies
- [Signals ML Detection](signals-ml-detection.md) — Anomaly detection, TensorFlow Lite on ESP32, behavior profiling
- [Signals ESP32-S3 Camera](signals-xiao-esp32s3.md) — XIAO ESP32-S3 camera, WiFi findings
- [Signals Image/Video](signals-security-image-video.md) — OV2640, MJPEG streaming, NGINX

### Codebase

- **Main Scanner**: `display-clients/esp32s3-heltec-v4/src/main.cpp`
- **Detection Patterns**: `src/detection_patterns.h` (17K+ entries)
- **Raven UUIDs**: `datasets/raven_configurations.json`

### External

- **DeFlock.me**: Crowdsourced ALPR locations and detection patterns
- **IEEE OUI Database**: https://standards-oui.ieee.org
- **ESP-IDF WiFi API**: https://docs.espressif.com/projects/esp-idf/en/stable/esp32s3/api-reference/network/esp_wifi.html
- **NimBLE-Arduino**: https://github.com/h2zero/NimBLE-Arduino
- **Kismet Wireless**: https://www.kismetwireless.net
- **Scapy Documentation**: https://scapy.net
- **rtl_433**: https://github.com/merbanan/rtl_433
- **WiGLE API**: https://api.wigle.net
- **Aircrack-ng**: https://www.aircrack-ng.org

### Research Credits

- **GainSec**: Raven BLE service UUID dataset
- **FoggedLens/deflock**: Detection methodologies
- **colonelpanichacks**: Original flock-you implementation

---

*Document Version: 3.0 | Updated: 2026-02-06 | Based on DEFLOCK v3.2.0-secure | Part of signals detection suite*
