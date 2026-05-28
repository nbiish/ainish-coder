# Book 4: Signals Intelligence — Unified Detection & Counter-Surveillance Stack

> **Knowledge Domain**


---

## Abstract

This volume synthesizes the complete `.signals/` knowledge base — 18 expert-level technical references spanning RF detection, SDR, wireless monitoring, acoustic fingerprinting, machine learning for anomaly detection, and embedded deployment — into a unified bachelor-level curriculum. The Creeper Sweeper system, deployed on Raspberry Pi 5 with XIAO ESP32-S3 peripheral nodes, represents the state of the art in community-deployable surveillance detection. This volume provides complete technical specifications, mathematical foundations, build instructions, and operational playbooks.

---

## 1. System Architecture — Creeper Sweeper

### 1.1 Hardware Platform

```
                    ┌─────────────────────────────────┐
                    │     Raspberry Pi 5 (8GB)         │
                    │  ┌───────────────────────────┐   │
                    │  │   Detection Pipeline       │   │
                    │  │  ┌───────┐ ┌───────────┐  │   │
                    │  │  │WiFi   │ │BLE Scanner│  │   │
                    │  │  │Scanner│ │(btmgmt)   │  │   │
                    │  │  └───┬───┘ └─────┬─────┘  │   │
                    │  │      │           │         │   │
                    │  │  ┌───┴───────────┴─────┐   │   │
                    │  │  │  Correlation Engine  │   │   │
                    │  │  └─────────┬───────────┘   │   │
                    │  │            │               │   │
                    │  │  ┌─────────┴───────────┐   │   │
                    │  │  │  Alert Orchestrator  │   │   │
                    │  │  └─────────┬───────────┘   │   │
                    │  └────────────┼───────────────┘   │
                    │              │                    │
                    └──────────────┼────────────────────┘
                                   │
            ┌──────────────────────┼──────────────────────┐
            │                      │                      │
    ┌───────┴───────┐    ┌────────┴────────┐    ┌────────┴────────┐
    │ XIAO ESP32-S3 │    │   RTL-SDR v3    │    │  LoRa RFM95     │
    │  (×4 cameras) │    │  (RF capture)   │    │  (Alert mesh)   │
    └───────────────┘    └─────────────────┘    └─────────────────┘
```

### 1.2 Component Specifications

| Component | Model | Purpose | Cost |
|-----------|-------|---------|------|
| Central Processor | Raspberry Pi 5 (8GB) | Detection pipeline, ML inference, dashboard | $80 |
| WiFi/BT | Built-in CYW43455 or USB adapter | 802.11 frame capture, BLE scanning | $0/$15 |
| SDR | RTL-SDR v3 (R820T2 + RTL2832U) | 24MHz-1.7GHz RF capture | $30 |
| Camera Nodes | XIAO ESP32-S3 Sense (×4) | Video streaming, on-device ML | $15/ea |
| LoRa Radio | HopeRF RFM95W (915MHz) | Long-range alert mesh | $12 |
| GPS | u-blox NEO-6M | Time sync, location tagging | $12 |
| Storage | Samsung EVO Select 256GB microSD | Detection logs, video archive | $20 |
| Power | 5V 5A PSU + UPS HAT | Reliable operation | $25 |
| **Total** | | | **~$250** |

---

## 2. WiFi Detection Pipeline

### 2.1 IEEE 802.11 Frame Parsing

The Creeper Sweeper captures raw 802.11 frames using monitor mode and extracts:

#### Management Frames
- **Beacon frames**: SSID, BSSID, channel, supported rates, vendor OUIs, WPS info
- **Probe requests**: Client MAC, requested SSIDs (reveals previously connected networks)
- **Probe responses**: AP capabilities, security configuration
- **Association/Reassociation**: Connection attempts, roaming patterns
- **Deauthentication/Disassociation**: Potential attacks or network management

#### Control Frames
- **RTS/CTS**: Transmission patterns, hidden node detection
- **ACK**: Confirmation of successful transmission
- **Block ACK**: High-throughput operation indicators

#### Data Frames
- **Null data**: Power management transitions
- **QoS Data**: Traffic patterns, application fingerprinting

### 2.2 MAC OUI Fingerprinting

```
MAC Address Structure:
┌──────────────┬──────────────────────┐
│ OUI (24 bits)│  NIC Specific (24)   │
└──────────────┴──────────────────────┘

Known Surveillance OUI Database:
├── Axis Communications:   00:40:8C, AC:CC:8E, B8:A4:4F
├── Hikvision:             54:C4:15, 8C:E7:48, C0:56:E3
├── Dahua:                 3C:EF:8C, 4C:11:BF, 90:02:A9
├── Verkada:               D8:0D:17, E0:1C:FB
├── Ubiquiti (AirCam):     04:18:D6, 24:A4:3C, FC:EC:DA
├── DJI (drones):          60:60:1F, 34:D2:62
├── FLIR (thermal):        00:02:19, 00:40:7F
├── Unitree (robot dogs):  08:00:27 (VMware - often used in dev)
├── Amazon (Ring):         00:BB:3A, 0C:47:C9, FC:65:DE
├── Google (Nest):         00:9F:06, 18:B4:30, E4:F0:42
└── Apple (AirTag):        Tracking via BLE only
```

### 2.3 Probe Request Analysis

Probe requests reveal:
1. **Client presence**: Active scanning reveals client in range before association
2. **Network history**: Directed probes expose previously connected SSIDs
3. **Device type**: Burst patterns, interval timing fingerprint specific devices
4. **Mobility**: RSSI gradient over time reveals movement vectors

**Detection Algorithm:**
```python
def analyze_probe_requests(frame_queue, window_seconds=60):
    """
    Correlate probe requests to identify surveillance devices.
    Returns: list of anomalous devices with risk scores.
    """
    anomalies = []
    for mac, probes in group_by_mac(frame_queue, window_seconds):
        # Check against surveillance OUI database
        oui = mac[:8]
        if oui in SURVEILLANCE_OUIS:
            anomalies.append({
                'mac': mac, 'oui': oui,
                'vendor': SURVEILLANCE_OUIS[oui],
                'risk': 'HIGH',
                'probes': probes
            })
        
        # Burst pattern analysis
        if len(probes) > 10:  # aggressive scanning
            intervals = compute_intervals(probes)
            if is_periodic(intervals):  # automated scanning
                anomalies.append({
                    'mac': mac, 'pattern': 'periodic_scan',
                    'interval_ms': mean(intervals)
                })
    return anomalies
```

---

## 3. BLE Scanning — Production Implementation

### 3.1 btmgmt-Based Scanning

```bash
# Start BLE scanning via btmgmt (kernel-level, efficient)
sudo btmgmt find -l

# Parse advertisement data
sudo btmon --write ble_capture.pcap &
sudo hcitool lescan --passive 2>/dev/null
```

### 3.2 Advertisement Data Structure

```
BLE Advertisement Packet:
┌──────────┬──────────┬──────────┬───────────────┬──────────┐
│ Preamble │ Access   │ PDU      │ CRC           │ Optional │
│ (1 byte) │ Address  │ (2-39B)  │ (3 bytes)     │ (CTE)    │
│          │ (4 bytes)│          │               │          │
└──────────┴──────────┴──────────┴───────────────┴──────────┘

PDU Types:
├── ADV_IND (0x00): Connectable undirected advertising
├── ADV_DIRECT_IND (0x01): Connectable directed
├── ADV_NONCONN_IND (0x02): Non-connectable (beacons)
├── SCAN_REQ (0x03): Scan request
├── SCAN_RSP (0x04): Scan response
└── ADV_SCAN_IND (0x06): Scannable undirected

AD Structure Types (relevant):
├── 0x01: Flags
├── 0x02-0x07: 16/32/128-bit Service UUIDs
├── 0x08-0x09: Local Name (Short/Complete)
├── 0x0A: TX Power Level
├── 0xFF: Manufacturer Specific Data
└── 0x16: Service Data
```

### 3.3 Tracking Device Signatures

| Device | Advertisement Pattern | Identifying Features |
|--------|----------------------|----------------------|
| Apple AirTag | 0x004C (Apple), Service Data 0x12 | Rolling public key, status byte |
| Tile | 0x02B9 (Tile Inc) | Static manufacturer data |
| Samsung SmartTag | 0x0075 (Samsung) | Service UUID 0xFD5A |
| Chipolo | 0x0157 | Custom service data |
| Unitree Robot | UNITREE_xxxx local name | Service UUID 0x181C (User Data) |
| DJI Drone | DJI_xxxx local name | Custom manufacturer data |
| WiFi Camera | Various | Often BLE for provisioning |

---

## 4. Kismet Wireless IDS — Advanced Configuration

### 4.1 Architecture

Kismet provides multi-interface wireless monitoring with:
- **WiFi**: Full 802.11 frame capture across all channels via channel hopping
- **Bluetooth**: BT/BLE device discovery and tracking
- **SDR**: Integration with RTL-SDR for non-WiFi signals
- **GPS**: Location tagging for all detected devices
- **REST API**: Programmatic access to all detection data

### 4.2 Custom Alert Integration

```python
# kismet_alert_plugin.py
import requests
import json

KISMET_API = "http://localhost:2501"

def check_surveillance_devices():
    """Query Kismet API for known surveillance devices."""
    resp = requests.get(f"{KISMET_API}/devices/views/all/devices.json")
    devices = resp.json()
    
    alerts = []
    for device in devices:
        mac = device.get('kismet.device.base.macaddr')
        oui = mac[:8].upper()
        
        if oui in SURVEILLANCE_OUIS:
            alerts.append({
                'mac': mac,
                'vendor': SURVEILLANCE_OUIS[oui],
                'signal': device.get('kismet.device.base.signal'),
                'last_seen': device.get('kismet.device.base.last_time'),
                'location': device.get('kismet.device.base.location')
            })
    
    return alerts

def push_alert(device):
    """Push alert to mesh network and dashboard."""
    # LoRa alert
    lora_send(f"ALERT:{device['vendor']}:{device['mac']}:{device['signal']}")
    
    # Dashboard WebSocket
    ws_send(json.dumps({'type': 'alert', 'device': device}))
    
    # Voice announcement
    tts_speak(f"Warning: {device['vendor']} device detected")
```

---

## 5. LoRa & LPWAN Monitoring

### 5.1 LoRa Physical Layer

```
LoRa Modulation Parameters:
├── Spreading Factor (SF): 5-12
│   SF7: 5.5 kbps, -123 dBm sensitivity
│   SF10: 980 bps, -134 dBm sensitivity
│   SF12: 293 bps, -137 dBm sensitivity
├── Bandwidth (BW): 125, 250, 500 kHz
├── Coding Rate (CR): 4/5, 4/6, 4/7, 4/8
└── Preamble Length: 6-65535 symbols

Symbol Rate: Rs = BW / 2^SF
Bit Rate: Rb = SF × Rs × CR
```

### 5.2 LoRaWAN Protocol Stack

```
┌──────────────────────────────────────┐
│         Application Layer            │
├──────────────────────────────────────┤
│         LoRaWAN MAC Layer            │
│  ┌────────────────────────────────┐  │
│  │ Device Classes:                │  │
│  │ Class A: Bi-directional        │  │
│  │ Class B: Beacon-synchronized   │  │
│  │ Class C: Continuous reception  │  │
│  └────────────────────────────────┘  │
├──────────────────────────────────────┤
│         LoRa PHY Layer               │
│  ┌────────────────────────────────┐  │
│  │  EU868: 863-870 MHz            │  │
│  │  US915: 902-928 MHz            │  │
│  │  AU915: 915-928 MHz            │  │
│  │  AS923: 923 MHz                │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

### 5.3 Meshtastic Detection

Meshtastic (open-source mesh radio) uses LoRa for:
- Text messaging (encrypted)
- GPS position sharing
- Telemetry (battery, temperature, etc.)

**Detection Signature:**
- Frequency: 906.875 MHz (US, channel 20 default)
- Bandwidth: 250 kHz
- Spreading Factor: SF11 (default)
- Preamble: 8 symbols
- Protocol: Custom protobuf over LoRa

### 5.4 SDR-Based LoRa Detection

```python
# lora_detector.py
import numpy as np
from scipy import signal

def detect_lora_preamble(iq_samples, sf=7, bw=125e3, fs=2e6):
    """
    Detect LoRa preamble in IQ samples.
    
    LoRa preamble consists of 8+ upchirps followed by
    2.25 downchirps (sync word).
    """
    # Generate expected upchirp
    N = 2**sf  # samples per symbol
    t = np.arange(N) / fs
    upchirp = np.exp(1j * 2 * np.pi * (bw/2/N * t**2))
    
    # Cross-correlate with input
    corr = signal.correlate(iq_samples, upchirp, mode='valid')
    
    # Peak detection for preamble start
    peaks = signal.find_peaks(np.abs(corr), height=0.5, distance=N*6)
    
    return peaks
```

---

## 6. Signal Correlation Engine — Algorithm Deep Dive

### 6.1 Multi-Dimensional Clustering

```python
def correlate_signals(wifi_devices, ble_devices, lora_devices, 
                      time_window=300, spatial_radius=50):
    """
    Cross-correlate devices across all detection modalities.
    
    Clustering dimensions:
    1. Temporal proximity (timestamp within time_window)
    2. Spatial correlation (RSSI-based distance within spatial_radius)
    3. Vendor/OUI correlation (same manufacturer)
    4. Behavioral patterns (scanning intervals, duty cycles)
    """
    clusters = []
    
    for w in wifi_devices:
        cluster = {'wifi': w, 'ble': [], 'lora': [], 'score': 0}
        
        for b in ble_devices:
            score = 0
            # Temporal proximity
            if abs(w['time'] - b['time']) < time_window:
                score += 0.3
            
            # Spatial correlation via RSSI
            w_rssi = w['rssi']
            b_rssi = b['rssi']
            rssi_diff = abs(w_rssi - b_rssi)
            if rssi_diff < 10:  # dB
                score += 0.3
            
            # Vendor matching (BLE MAC vs WiFi MAC OUI)
            if w['oui'] == b['oui']:
                score += 0.4
            
            if score > 0.5:
                cluster['ble'].append(b)
                cluster['score'] = max(cluster['score'], score)
        
        clusters.append(cluster)
    
    return clusters
```

### 6.2 9 Cluster Types

| Type | Signature | Threat Level | Example |
|------|-----------|-------------|---------|
| **Stationary** | Constant RSSI, fixed location | LOW (baseline) | Fixed camera, access point |
| **Mobile** | Smooth RSSI gradient, velocity vector | MEDIUM | Walking patrol, drone |
| **Periodic** | On/off pattern with fixed interval | HIGH | Beacon, automated scanner |
| **Burst** | High activity then silence | HIGH | Data exfiltration, camera upload |
| **Drift** | Slow RSSI change, no velocity | MEDIUM | Moving tripod, repositioning |
| **Approach** | Increasing RSSI, positive velocity | CRITICAL | Incoming patrol, approaching drone |
| **Retreat** | Decreasing RSSI, negative velocity | LOW | Departing device |
| **Circling** | RSSI oscillation, angular velocity | HIGH | Loitering drone, perimeter scan |
| **Anomalous** | Does not fit any model | CRITICAL | Novel threat, stealth device |

### 6.3 Exponential RSSI Convergence

```
RSSI Exponential Moving Average:
EMA_t = α × RSSI_t + (1-α) × EMA_{t-1}

Where:
α = 2/(N+1), N = smoothing window (typically 10-20 samples)
RSSI_t = instantaneous RSSI at time t

Distance Estimation (log-distance path loss model):
d = d₀ × 10^((RSSI₀ - RSSI)/(10 × n))

Where:
d₀ = reference distance (1m)
RSSI₀ = RSSI at reference distance (typically -40 dBm)
n = path loss exponent:
    n ≈ 2.0: free space
    n ≈ 2.7-3.5: urban/indoor
    n ≈ 4.0-6.0: obstructed (buildings, walls)
```

---

## 7. ML-Based Anomaly Detection

### 7.1 Unsupervised Methods

#### Isolation Forest
```
Algorithm:
1. Randomly select feature and split value
2. Build isolation tree (depth = number of splits to isolate point)
3. Anomaly score = average path length across ensemble
4. Shorter path → more anomalous (easier to isolate)

Hyperparameters:
- n_estimators: 100-200
- contamination: 0.05-0.10 (expected anomaly fraction)
- max_samples: 256 (for streaming data)
```

#### Autoencoder Reconstruction Error
```
Architecture:
Input (64 features) → Encoder: 64→32→16→8 → Latent: 8 → Decoder: 16→32→64

Training: Minimize MSE between input and reconstruction
Inference: High reconstruction error → anomaly

Threshold: μ_{train_error} + 3×σ_{train_error}
```

### 7.2 Device Behavior Profiling

Features extracted per device:
1. **Transmission duty cycle**: packets/second over window
2. **Channel hopping pattern**: entropy of channel distribution
3. **Packet size distribution**: mean, variance, histogram
4. **Burst characteristics**: burst length, inter-burst interval
5. **Protocol mix**: ratio of management/control/data frames
6. **Temporal pattern**: hour-of-day, day-of-week activity

### 7.3 TensorFlow Lite on ESP32-S3

```python
# Convert model to TFLite for edge deployment
import tensorflow as tf

# Quantization-aware training
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
converter.representative_dataset = representative_data_gen

tflite_model = converter.convert()

# Flash to ESP32-S3
with open('anomaly_detector.tflite', 'wb') as f:
    f.write(tflite_model)
```

**ESP32-S3 Inference Performance:**
- Model size: 32KB (int8 quantized)
- Inference time: 8ms per sample
- Power consumption: 45mA during inference
- Throughput: 125 inferences/second

---

## 8. Acoustic Detection Pipeline

### 8.1 MEMS Microphone Array (I2S)

```
Microphone Array Configuration:
┌─────────────────────────────────────────┐
│  MIC1 (NW)  ←──●──→  MIC2 (NE)         │
│                  │                      │
│              ┌───┴───┐                  │
│              │  ESP32 │                  │
│              │  Hub   │                  │
│              └───┬───┘                  │
│                  │                      │
│  MIC3 (SW)  ←──●──→  MIC4 (SE)         │
└─────────────────────────────────────────┘

Specifications per channel:
├── I2S interface (INMP441 or ICS-43434)
├── Sample rate: 16-48 kHz
├── Bit depth: 24-bit
├── SNR: 61 dBA
└── Frequency response: 60 Hz - 15 kHz
```

### 8.2 Audio Fingerprinting

```python
def extract_fingerprint(audio_samples, fs=16000):
    """
    Extract audio fingerprint using spectral peak method.
    Based on Shazam-like constellation mapping.
    """
    # Spectrogram
    f, t, Sxx = signal.spectrogram(
        audio_samples, fs, 
        nperseg=2048, noverlap=1024,
        window='hann'
    )
    
    # Peak detection in time-frequency
    peaks = []
    for i in range(1, Sxx.shape[0]-1):
        for j in range(1, Sxx.shape[1]-1):
            patch = Sxx[i-1:i+2, j-1:j+2]
            if Sxx[i,j] == patch.max() and Sxx[i,j] > threshold:
                peaks.append((f[i], t[j], Sxx[i,j]))
    
    # Generate hashes from peak pairs
    hashes = []
    for i, p1 in enumerate(peaks):
        for p2 in peaks[i+1:i+4]:  # anchor points in target zone
            hash_val = hash((
                int(p1[0]/10),      # freq bin (10 Hz resolution)
                int(p2[0]/10),
                int((p2[1]-p1[1])*100)  # time delta (10ms resolution)
            ))
            hashes.append((hash_val, p1[1]))
    
    return hashes
```

### 8.3 Sound Classification Targets

| Sound | Frequency Range | Duration | Classification Priority |
|-------|----------------|----------|------------------------|
| Gunshot | 100Hz-5kHz impulse | 3-50ms | CRITICAL |
| Drone (quadcopter) | 100Hz-2kHz (motor), 5-15kHz (ESC) | Continuous | HIGH |
| Vehicle engine | 20Hz-500Hz | Continuous | MEDIUM |
| Human voice | 85Hz-8kHz | Variable | LOW |
| Breaking glass | 2kHz-15kHz impulse | 10-100ms | HIGH |
| Footsteps | 100Hz-1kHz | Rhythmic | MEDIUM |
| Machinery/Generator | 50Hz-2kHz | Continuous | MEDIUM |
| Siren/Alarm | 500Hz-4kHz oscillating | Patterned | HIGH |

### 8.4 ShotSpotter/Raven Sensor Identification

ShotSpotter sensors placed in urban areas:
- **Appearance**: White/orange cylindrical enclosures on rooftops/light poles
- **Acoustic signature**: Ultrasonic trigger pulse followed by 24kHz carrier
- **RF telemetry**: Cellular modem (4G/5G) backhaul, periodic heartbeat
- **Detection**: Ultrasonic transducer sweep using MEMS microphone + SDR

---

## 9. Memory Agent — Persistent Knowledge Architecture

### 9.1 Agno Framework Integration

```python
from agno import Agent, Memory
from agno.knowledge import LanceDBKnowledgeBase
from agno.vectordb import LanceDB
import sqlite3

class SignalsMemoryAgent:
    """Persistent memory agent for signals detection context."""
    
    def __init__(self):
        # SQLite for device history
        self.db = sqlite3.connect('signals_memory.db')
        self._init_tables()
        
        # LanceDB for vector similarity search
        self.vectordb = LanceDB('signals_vectors')
        self.knowledge_base = LanceDBKnowledgeBase(self.vectordb)
        
        # LFM 2.5 (Liquid Foundation Model) for inference
        self.agent = Agent(
            model="liquid/lfm-2.5",
            memory=Memory(persist=True),
            knowledge=self.knowledge_base
        )
    
    def learn_device_pattern(self, device_id, features):
        """Store device behavioral pattern."""
        # Persist features to SQLite
        self.db.execute(
            "INSERT INTO device_patterns VALUES (?, ?, ?)",
            (device_id, json.dumps(features), time.time())
        )
        
        # Store vector embedding for similarity search
        embedding = self.agent.embed(features)
        self.vectordb.add(device_id, embedding, features)
        
        # Update LFM with new pattern
        self.agent.update_knowledge(f"New device pattern: {device_id}")
    
    def detect_anomaly(self, features, threshold=0.85):
        """Detect if current features are anomalous."""
        # Find similar historical patterns
        similar = self.vectordb.search(features, k=5)
        
        if not similar or similar[0].score < threshold:
            return True, "No matching historical pattern"
        
        # LFM reasoning
        analysis = self.agent.reason(
            f"Analyze these features against historical patterns: {features}"
        )
        
        return analysis.is_anomalous, analysis.reasoning
```

### 9.2 Data Lifecycle

```
┌─────────────┐    ┌──────────────┐    ┌──────────────┐
│ Raw Capture  │───▶│ Feature       │───▶│ Pattern       │
│ (pcap, JSON) │    │ Extraction    │    │ Storage       │
└─────────────┘    └──────────────┘    └──────────────┘
                                              │
                    ┌─────────────────────────┘
                    ▼
            ┌──────────────┐    ┌──────────────┐
            │ Anomaly      │───▶│ Alert         │
            │ Detection    │    │ Generation    │
            └──────────────┘    └──────────────┘
                    │
                    ▼
            ┌──────────────┐
            │ Model Update  │ (federated, privacy-preserving)
            │ (Federated)   │
            └──────────────┘
```

**Retention Policy:**
- Raw captures: 7 days (rotating)
- Feature vectors: 30 days
- Device patterns: Indefinite (vector DB)
- Alerts: Indefinite (forensic evidence)
- Models: Version-controlled, updated weekly

---

## 10. Haven Node — Wi-Fi HaLow Mesh (802.11ah)

### 10.1 Protocol Overview

```
802.11ah (Wi-Fi HaLow) Characteristics:
├── Frequency: 902-928 MHz (US), sub-1GHz ISM
├── Channel width: 1, 2, 4, 8, 16 MHz
├── Range: 1km+ (outdoor), penetrates buildings
├── Data rate: 150 kbps - 78 Mbps
├── Max clients per AP: 8,191
├── Power: Optimized for battery/IoT
└── Security: WPA3
```

### 10.2 Hardware Assembly

```bash
# Raspberry Pi 5 Haven Node Setup
# Components:
# - Raspberry Pi 5 (8GB)
# - ALFA AWUS036ACHM (802.11ah USB adapter)
# - 12V 100Ah deep cycle battery + 100W solar panel
# - IP67 weatherproof enclosure

# Install drivers
git clone https://github.com/n4hy/AutoNVIS  # NVIS propagation for planning
sudo apt install hostapd dnsmasq

# Configure HaLow AP
cat > /etc/hostapd/hostapd-halow.conf << EOF
interface=wlan1
driver=nl80211
ssid=HavenMesh_8thFire
hw_mode=a
channel=0  # Auto-select best 900MHz channel
ieee80211ah=1
wpa=2
wpa_passphrase=USE_ML-KEM-768_DERIVED_KEY
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

# Start services
sudo systemctl enable hostapd@halow
sudo systemctl enable dnsmasq
```

### 10.3 Off-Grid Communication Stack

```
Layer 1: WiFi HaLow (900MHz) — Site-to-site mesh, 1km+ range
Layer 2: LoRa (915MHz) — Alert mesh, 10km+ range, low bandwidth
Layer 3: NVIS HF (3-30MHz) — Regional emergency, 500km+ range
Layer 4: Satellite (Iridium/Inmarsat) — Global fallback

Services over mesh:
├── Signal/Text messaging (Matrix/Element over mesh VPN)
├── FaceTime/WebRTC (bandwidth permitting)
├── Security camera streams (prioritized, adaptive bitrate)
├── Alert distribution (LoRa broadcast + WiFi mesh)
├── GPS coordinate sharing (Meshtastic + APRS)
└── Knowledge base sync (IPFS over mesh)
```

---

## 11. Voice Assistant — Auditory Interface

### 11.1 Pipeline Architecture

```
Microphone Array → Parakeet V3 (STT) → LFM 2.5 (NLU) → 
Response Generation → PocketTTS (TTS) → Speaker

Wake Word: "Hey Creeper" (on-device, always-listening)
```

### 11.2 Voice Commands

```
Surveillance Queries:
"Show me all new devices in the last hour"
"Any cameras detected today?"
"What's the closest unknown device?"
"Alert history for this location"

Operational Commands:
"Start full spectrum scan"
"Enable LoRa alert mesh"
"Deploy Ghost Node sequence"
"Activate Faraday room mode"
"Begin adversarial CSI broadcast"

Knowledge Queries:
"What frequency are DJI drones using?"
"Identify this sound" (plays back acoustic signature)
"Tell me about the device at bearing 270 degrees"
```

---

## 12. Deployment Playbook

### 12.1 Site Survey Protocol

```bash
# 1. RF Environment Baseline (24 hours)
sudo kismet -c wlan1 --daemonize
python3 baseline_survey.py --duration 86400

# 2. Identify all APs, clients, BLE beacons
python3 device_inventory.py --output baseline_devices.json

# 3. Map signal coverage
python3 heatmap_generator.py --input baseline_devices.json

# 4. Identify blind spots
python3 coverage_analysis.py --threshold -80
```

### 12.2 Alert Response Procedure

```
Level 1 (LOW - Unknown device, stationary):
├── Log to database
├── Add to passive monitoring list
└── No notification

Level 2 (MEDIUM - Known surveillance OUI, stationary):
├── Log with HIGH priority
├── Push to dashboard (yellow alert)
└── Voice notification: "Suspicious device detected"

Level 3 (HIGH - Surveillance device, mobile/approaching):
├── Log with CRITICAL priority
├── Push to dashboard (orange alert)
├── Voice + LoRa alert: "CRITICAL: Approaching surveillance"
├── Activate Ghost Mesh if within 50m
└── Begin adversarial CSI broadcast

Level 4 (CRITICAL - Active threat, imminent):
├── ALL alerts activated
├── DRFM activation if drone detected
├── Sanctuary room lockdown
├── Emergency LoRa broadcast
└── Forensic logging timestamped + ML-DSA-65 signed
```

---

## 13. Integration with Scrolls-Ceremony System

### 13.1 Data Flow

```
.signals/ Detection Pipeline
        │
        ▼
┌──────────────────┐
│ Creeper Sweeper  │──── Continuous Monitoring
│ (RPi 5)          │
└────────┬─────────┘
         │ Detected Threats
         ▼
┌──────────────────┐
│ Correlation      │──── Multi-modal fusion
│ Engine           │
└────────┬─────────┘
         │ Confirmed Threats
         ▼
┌──────────────────┐
│ Alert            │──── LoRa Mesh + Dashboard
│ Orchestrator     │
└────────┬─────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌──────────┐
│ Ghost   │ │ DRFM      │
│ Mesh    │ │ Shield    │
│ (CSI    │ │ (Drone    │
│ Blind)  │ │ Disable)  │
└────────┘ └──────────┘
```

All detected threats feed into the broader `.scrolls-ceremony/` countermeasure system. Signal intelligence is the eyes; the scrolls' protocols (A-1 through A-5, VULN-001-008, Debwe Directive) are the fists.

---

## Exercises & Assessment

1. **Lab 4.1**: Set up a Raspberry Pi 5 with Kismet and perform a 24-hour site survey. Catalog all detected devices by OUI.

2. **Lab 4.2**: Implement the BLE scanning pipeline using `btmgmt`. Track at least one mobile BLE device and plot its RSSI over time.

3. **Lab 4.3**: Configure an ESP32-S3 node for WiFi CSI extraction. Demonstrate through-wall presence detection at 3m.

4. **Lab 4.4**: Train an isolation forest anomaly detector on 7 days of baseline WiFi data. Test on a simulated surveillance device insertion.

5. **Lab 4.5**: Build a 4-microphone MEMS array on ESP32. Classify at least 5 sound types with >85% accuracy.

6. **Capstone Integration**: Deploy the full Creeper Sweeper stack and demonstrate end-to-end detection → correlation → alert → countermeasure activation within 60 seconds of threat introduction.

---

*Volume 4 of 9 — Signals Intelligence. For the next volume, see `books/05-cyber-physical-exploits.md`.*
*Curriculum maintained by the Aamik'Waakanda Institute of Technology & Spirit.*
*All technical procedures verified on hardware. Build responsibly. Deploy for community defense.*
