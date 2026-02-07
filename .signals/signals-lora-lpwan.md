# Signals LoRa & LPWAN Monitoring: Expert Technical Reference

> **Beyond Expert-Level Guide to LoRa, LoRaWAN, and Low-Power Wide-Area Network Detection**
>
> Part of the **signals detection** knowledge base — covering LoRa physical layer, LoRaWAN protocol analysis, Meshtastic detection, and sub-GHz ISM band monitoring with SDR.
>
> **Companion documents**: [Signals Detection](signals.md) — WiFi/BLE | [Signals Acoustic](signals-acoustic.md) — audio analysis

---

## Table of Contents

1. [LoRa Fundamentals](#1-lora-fundamentals)
2. [LoRaWAN Protocol Architecture](#2-lorawan-protocol-architecture)
3. [Hardware Platforms](#3-hardware-platforms)
4. [LoRa Packet Sniffing with SDR](#4-lora-packet-sniffing-with-sdr)
5. [Meshtastic Network Detection](#5-meshtastic-network-detection)
6. [ESP32 LoRa Scanner Implementation](#6-esp32-lora-scanner-implementation)
7. [Regional Frequency Plans](#7-regional-frequency-plans)
8. [Detection Signatures & Patterns](#8-detection-signatures--patterns)
9. [Code Patterns & Best Practices](#9-code-patterns--best-practices)

---

## 1. LoRa Fundamentals

### 1.1 Chirp Spread Spectrum (CSS)

LoRa uses **Chirp Spread Spectrum (CSS)** modulation — a spread-spectrum technique where the carrier frequency continuously increases (up-chirp) or decreases (down-chirp) over time.

```
Frequency
    ↑
    │         ╱╲         ╱╲
    │       ╱    ╲     ╱    ╲
    │     ╱        ╲ ╱        ╲
    │   ╱            ╳
    │ ╱                ╲
    └──────────────────────────→ Time
        Up-chirp    Down-chirp
```

**Key Parameters**:

| Parameter | Symbol | Range | Impact |
|-----------|--------|-------|--------|
| **Spreading Factor** | SF | 7-12 | Higher = longer range, lower data rate |
| **Bandwidth** | BW | 125/250/500 kHz | Higher = faster, less range |
| **Coding Rate** | CR | 4/5 to 4/8 | Higher = more FEC overhead |
| **Frequency** | - | Regional ISM bands | Determines legal operation |

### 1.2 Link Budget Calculation

```
Link Budget = Tx Power + Tx Antenna Gain + Rx Antenna Gain - Path Loss - Rx Sensitivity

LoRa Rx Sensitivity (typical):
   SF7:  -123 dBm
   SF10: -132 dBm
   SF12: -137 dBm

Example (SF12, 14 dBm Tx, +2 dBi antennas):
   Link Budget = 14 + 2 + 2 + 137 = 155 dB
   Free-space Range ≈ 15-20 km (line of sight)
   Urban Range ≈ 2-5 km
```

### 1.3 Time on Air Calculator

```python
def lora_time_on_air_ms(payload_bytes, sf=7, bw=125, cr=1, preamble=8):
    """
    Calculate LoRa packet time on air in milliseconds
    
    Args:
        payload_bytes: Payload size in bytes
        sf: Spreading factor (7-12)
        bw: Bandwidth in kHz (125, 250, 500)
        cr: Coding rate denominator - 4 (1=4/5, 2=4/6, 3=4/7, 4=4/8)
        preamble: Preamble symbols (default 8)
    """
    symbol_duration = (2 ** sf) / (bw * 1000)  # seconds
    
    # Preamble time
    preamble_time = (preamble + 4.25) * symbol_duration
    
    # Payload symbols (simplified formula)
    de = 1 if sf >= 11 else 0  # Low data rate optimize
    h = 0  # Header mode (0 = explicit)
    
    payload_symbols = 8 + max(
        math.ceil((8 * payload_bytes - 4 * sf + 28 + 16 - 20 * h) / (4 * (sf - 2 * de))) * (cr + 4),
        0
    )
    
    payload_time = payload_symbols * symbol_duration
    
    return (preamble_time + payload_time) * 1000  # Convert to ms
```

---

## 2. LoRaWAN Protocol Architecture

### 2.1 Network Topology

```
┌─────────────────────────────────────────────────────────────────────┐
│                      LoRaWAN Architecture                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌──────┐  ┌──────┐  ┌──────┐                                     │
│   │ End  │  │ End  │  │ End  │     End Devices (Class A/B/C)        │
│   │Device│  │Device│  │Device│     - Sensors, trackers, meters      │
│   └──┬───┘  └──┬───┘  └──┬───┘                                     │
│      │         │         │        LoRa RF (ISM band)                │
│   ┌──┴─────────┴─────────┴──┐                                       │
│   │                         │                                        │
│   │    ┌────────┐ ┌────────┐│    Gateways                           │
│   │    │Gateway1│ │Gateway2││    - Packet forwarders                │
│   │    └────┬───┘ └───┬────┘│    - Multi-channel (8+ channels)      │
│   │         │         │     │                                        │
│   └─────────┴────┬────┴─────┘                                       │
│                  │               IP Backhaul (Ethernet/Cellular)    │
│           ┌──────▼──────┐                                           │
│           │ Network     │        Network Server                     │
│           │ Server      │        - Deduplication, MAC commands      │
│           └──────┬──────┘        - ADR, key management              │
│                  │                                                   │
│           ┌──────▼──────┐                                           │
│           │ Application │        Application Server                 │
│           │ Server      │        - Business logic, data storage     │
│           └─────────────┘                                           │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Device Classes

| Class | Description | Latency | Power | Use Case |
|-------|-------------|---------|-------|----------|
| **A** | Uplink-initiated, 2 Rx windows after Tx | High (hours) | Lowest | Sensors, meters |
| **B** | Scheduled Rx windows (beacon sync) | Medium (seconds) | Medium | Actuators |
| **C** | Continuous Rx (always listening) | Low (ms) | Highest | Powered devices |

### 2.3 Activation Methods

**OTAA (Over-The-Air Activation)** — Recommended:
```
Device                              Network Server
   │                                      │
   │─────── Join Request ────────────────►│
   │        (DevEUI, AppEUI, DevNonce)    │
   │                                      │
   │◄────── Join Accept ─────────────────│
   │        (DevAddr, NwkSKey, AppSKey)   │
   │                                      │
   │        Session established           │
```

**ABP (Activation By Personalization)** — Pre-provisioned:
- DevAddr, NwkSKey, AppSKey hardcoded at manufacturing
- No join procedure required
- Less secure (keys don't rotate)

### 2.4 Frame Structure

```
┌────────────────────────────────────────────────────────────────────┐
│                         LoRaWAN Frame                               │
├─────────┬───────┬────────┬────────┬─────────┬──────────┬──────────┤
│ Preamble│ PHDR  │ PHDR   │ MHDR   │ MACPay- │ MIC      │          │
│         │       │ CRC    │        │ load    │          │          │
├─────────┼───────┼────────┼────────┼─────────┼──────────┼──────────┤
│ 8 symb  │1 byte │2 bytes │1 byte  │Variable │ 4 bytes  │          │
│         │       │        │        │ 1-255   │          │          │
└─────────┴───────┴────────┴────────┴─────────┴──────────┴──────────┘
                           │
                           ▼
             ┌─────────────────────────────────┐
             │           MACPayload             │
             ├────────┬───────────┬─────────────┤
             │ FHDR   │ FPort     │ FRMPayload  │
             │(7-23B) │ (1 byte)  │ (encrypted) │
             └────────┴───────────┴─────────────┘
```

---

## 3. Hardware Platforms

### 3.1 Heltec WiFi LoRa 32 V3 (ESP32-S3 + SX1262)

| Component | Specification | Detection Relevance |
|-----------|---------------|---------------------|
| **MCU** | ESP32-S3 (dual-core, 240 MHz) | WiFi/BLE scanning + LoRa |
| **LoRa Chip** | Semtech SX1262 | 150 MHz - 960 MHz |
| **Frequency** | 868/915 MHz (regional) | Sub-GHz ISM bands |
| **Tx Power** | Up to +22 dBm | Long range |
| **Rx Sensitivity** | -136 dBm (SF12) | Weak signal detection |
| **OLED** | 0.96" 128x64 SSD1306 | Status display |
| **USB** | Type-C (UART bridge) | Programming, serial |

**Pin Mapping**:

| Function | GPIO | Notes |
|----------|------|-------|
| LoRa NSS | GPIO 8 | SPI chip select |
| LoRa SCK | GPIO 9 | SPI clock |
| LoRa MOSI | GPIO 10 | SPI data out |
| LoRa MISO | GPIO 11 | SPI data in |
| LoRa RST | GPIO 12 | Radio reset |
| LoRa DIO1 | GPIO 14 | Interrupt |
| LoRa BUSY | GPIO 13 | Radio busy |
| OLED SDA | GPIO 17 | I2C data |
| OLED SCL | GPIO 18 | I2C clock |
| OLED RST | GPIO 21 | Display reset |
| Vext | GPIO 36 | OLED power control |

### 3.2 RTL-SDR for LoRa Reception

Any RTL-SDR dongle covering 400-1000 MHz can receive LoRa signals:

| Dongle | Frequency Range | Sample Rate | Detection Use |
|--------|-----------------|-------------|---------------|
| **RTL-SDR Blog V3** | 500 kHz - 1.7 GHz | 2.4 MSPS | Full 868/915 coverage |
| **RTL-SDR Blog V4** | 500 kHz - 1.7 GHz | 2.4 MSPS | Improved sensitivity |
| **HackRF One** | 1 MHz - 6 GHz | 20 MSPS | Wideband capture |

---

## 4. LoRa Packet Sniffing with SDR

### 4.1 gr-lora (GNU Radio LoRa Decoder)

```bash
# Install dependencies
sudo apt-get install gnuradio gnuradio-dev libvolk-dev

# Clone and build gr-lora
git clone https://github.com/rpp0/gr-lora.git
cd gr-lora
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
sudo ldconfig
```

### 4.2 GNU Radio Flowgraph (Python)

```python
#!/usr/bin/env python3
"""LoRa packet sniffer using RTL-SDR and gr-lora"""

from gnuradio import gr, blocks
from gnuradio import analog
import osmosdr
import lora

class LoRaSniffer(gr.top_block):
    def __init__(self, center_freq=915e6, sf=7, bw=125000):
        gr.top_block.__init__(self, "LoRa Sniffer")
        
        # RTL-SDR source
        self.rtlsdr = osmosdr.source(args="numchan=1")
        self.rtlsdr.set_sample_rate(1e6)
        self.rtlsdr.set_center_freq(center_freq)
        self.rtlsdr.set_gain(40)
        
        # LoRa receiver
        self.lora_receiver = lora.lora_receiver(
            samp_rate=1e6,
            center_freq=center_freq,
            channel_list=[0],
            bandwidth=bw,
            sf=sf,
            implicit_header=False,
            reduced_rate=False,
            decimation=1
        )
        
        # Message sink for decoded packets
        self.msg_sink = blocks.message_debug()
        
        # Connections
        self.connect(self.rtlsdr, self.lora_receiver)
        self.msg_connect(self.lora_receiver, "frames", self.msg_sink, "print")

if __name__ == "__main__":
    sniffer = LoRaSniffer(center_freq=915e6, sf=7)
    sniffer.run()
```

### 4.3 LoRa Demodulation with SX1262 (Direct)

Using the LoRa chip itself as a sniffer provides better sensitivity than SDR:

```cpp
#include <RadioLib.h>

// Heltec WiFi LoRa 32 V3 pin mapping
SX1262 radio = new Module(8, 14, 12, 13);

void setup() {
    Serial.begin(115200);
    
    // Initialize LoRa radio
    int state = radio.begin(915.0, 125.0, 7, 5, RADIOLIB_SX126X_SYNC_WORD_PRIVATE, 22, 8, 1.6, false);
    if (state != RADIOLIB_ERR_NONE) {
        Serial.printf("Radio init failed: %d\n", state);
        while (true);
    }
    
    Serial.println("LoRa sniffer started");
    
    // Start continuous receive mode
    radio.startReceive();
}

void loop() {
    // Check for received packet
    if (radio.available()) {
        String data;
        int state = radio.readData(data);
        
        if (state == RADIOLIB_ERR_NONE) {
            Serial.printf("RSSI: %.1f dBm, SNR: %.1f dB\n", 
                          radio.getRSSI(), radio.getSNR());
            Serial.print("Data: ");
            for (int i = 0; i < data.length(); i++) {
                Serial.printf("%02X ", (uint8_t)data[i]);
            }
            Serial.println();
            
            // Check for Meshtastic or surveillance patterns
            analyzePacket((uint8_t*)data.c_str(), data.length());
        }
    }
}
```

---

## 5. Meshtastic Network Detection

### 5.1 Meshtastic Protocol Overview

Meshtastic is an open-source, decentralized mesh network protocol built on LoRa:

| Property | Value | Detection Impact |
|----------|-------|------------------|
| **Frequency** | Regional ISM (e.g., 915 MHz US) | Same as LoRaWAN |
| **Modulation** | LoRa CSS | Standard LoRa detection |
| **Spreading Factor** | 7-12 (configurable) | Affects time on air |
| **Encryption** | AES-256 CTR | Payload encrypted, headers visible |
| **Mesh Routing** | Flooding + addressed | Reveals node topology |

### 5.2 Meshtastic Packet Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                    Meshtastic Packet                             │
├──────────┬──────────┬────────────┬─────────────┬────────────────┤
│ Preamble │ Sync     │ Header     │ Payload     │ CRC            │
│ (LoRa)   │ Word     │            │ (encrypted) │                │
├──────────┼──────────┼────────────┼─────────────┼────────────────┤
│ 8 symbols│ Variable │ 16 bytes   │ Variable    │ 2 bytes        │
└──────────┴──────────┴────────────┴─────────────┴────────────────┘
                      │
                      ▼
        ┌───────────────────────────────────┐
        │         Meshtastic Header          │
        ├────────┬────────┬─────────┬───────┤
        │ Dest   │ Sender │ PacketID│ Flags │
        │ (4B)   │ (4B)   │ (4B)    │ (4B)  │
        └────────┴────────┴─────────┴───────┘
```

### 5.3 Detecting Meshtastic Traffic

```cpp
// Meshtastic uses specific sync words and channel configurations
// Detection focuses on LoRa parameters and timing patterns

#define MESHTASTIC_SYNC_WORD 0x2B  // Private sync word

typedef struct {
    uint32_t dest_id;
    uint32_t sender_id;
    uint32_t packet_id;
    uint32_t flags;
} MeshtasticHeader;

bool detectMeshtastic(uint8_t* packet, size_t len) {
    if (len < sizeof(MeshtasticHeader)) {
        return false;
    }
    
    // Parse header (little-endian)
    MeshtasticHeader* header = (MeshtasticHeader*)packet;
    
    // Meshtastic uses special broadcast addresses
    // 0xFFFFFFFF = broadcast
    // Top byte = node type indicator
    
    uint8_t node_type = (header->sender_id >> 24) & 0xFF;
    
    // Check for valid Meshtastic node ID patterns
    // (This is heuristic-based detection)
    if (header->sender_id != 0 && header->sender_id != 0xFFFFFFFF) {
        Serial.printf("Potential Meshtastic node: %08X\n", header->sender_id);
        return true;
    }
    
    return false;
}
```

---

## 6. ESP32 LoRa Scanner Implementation

### 6.1 Multi-Channel Scanner

```cpp
#include <RadioLib.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// Heltec V3 pins
#define LORA_NSS 8
#define LORA_DIO1 14
#define LORA_RST 12
#define LORA_BUSY 13
#define OLED_SDA 17
#define OLED_SCL 18
#define OLED_RST 21
#define VEXT_PIN 36

SX1262 radio = new Module(LORA_NSS, LORA_DIO1, LORA_RST, LORA_BUSY);
Adafruit_SSD1306 display(128, 64, &Wire, OLED_RST);

// US915 channel frequencies (MHz)
const float US915_CHANNELS[] = {
    903.9, 904.1, 904.3, 904.5, 904.7, 904.9, 905.1, 905.3,  // 0-7
    905.5, 905.7, 905.9, 906.1, 906.3, 906.5, 906.7, 906.9,  // 8-15
    // ... up to 64 uplink + 8 downlink channels
};
#define NUM_CHANNELS 72

// Spreading factors to scan
const int SPREADING_FACTORS[] = {7, 8, 9, 10, 11, 12};
#define NUM_SF 6

// Detection statistics
struct ChannelStats {
    uint32_t packet_count;
    float avg_rssi;
    int last_sf;
    uint32_t last_seen_ms;
};

ChannelStats channel_stats[NUM_CHANNELS] = {0};
uint32_t total_packets = 0;

void setup() {
    Serial.begin(115200);
    
    // Enable OLED power
    pinMode(VEXT_PIN, OUTPUT);
    digitalWrite(VEXT_PIN, LOW);
    
    // Initialize display
    Wire.begin(OLED_SDA, OLED_SCL);
    display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 0);
    display.println("LoRa Scanner");
    display.display();
    
    // Initialize radio
    int state = radio.begin(915.0);
    if (state != RADIOLIB_ERR_NONE) {
        Serial.printf("Radio init failed: %d\n", state);
        display.println("Radio FAIL");
        display.display();
        while (true);
    }
    
    Serial.println("LoRa scanner initialized");
}

void scanChannel(int channel_idx, int sf) {
    float freq = US915_CHANNELS[channel_idx];
    
    radio.setFrequency(freq);
    radio.setSpreadingFactor(sf);
    radio.setBandwidth(125.0);
    radio.setCodingRate(5);
    
    // Listen for 100ms
    radio.startReceive();
    uint32_t start = millis();
    
    while (millis() - start < 100) {
        if (radio.available()) {
            uint8_t buffer[256];
            int len = radio.getPacketLength();
            int state = radio.readData(buffer, len);
            
            if (state == RADIOLIB_ERR_NONE && len > 0) {
                float rssi = radio.getRSSI();
                float snr = radio.getSNR();
                
                // Update statistics
                channel_stats[channel_idx].packet_count++;
                channel_stats[channel_idx].avg_rssi = 
                    (channel_stats[channel_idx].avg_rssi + rssi) / 2;
                channel_stats[channel_idx].last_sf = sf;
                channel_stats[channel_idx].last_seen_ms = millis();
                total_packets++;
                
                // Log detection
                Serial.printf("CH%d (%.1f MHz) SF%d | RSSI: %.1f, SNR: %.1f, Len: %d\n",
                              channel_idx, freq, sf, rssi, snr, len);
                
                // Analyze packet
                analyzeLoraTrafic(buffer, len, channel_idx, sf);
            }
        }
        delay(1);
    }
}

void analyzeLoraTrafic(uint8_t* data, size_t len, int channel, int sf) {
    // Print hex dump
    Serial.print("  Data: ");
    for (size_t i = 0; i < min(len, (size_t)32); i++) {
        Serial.printf("%02X ", data[i]);
    }
    if (len > 32) Serial.print("...");
    Serial.println();
    
    // Check for Meshtastic
    if (detectMeshtastic(data, len)) {
        Serial.println("  [MESHTASTIC DETECTED]");
    }
    
    // Check for LoRaWAN MAC header
    if (len >= 1) {
        uint8_t mhdr = data[0];
        uint8_t mtype = (mhdr >> 5) & 0x07;
        
        const char* mtype_names[] = {
            "Join Request", "Join Accept", "Unconfirmed Up", "Unconfirmed Down",
            "Confirmed Up", "Confirmed Down", "RFU", "Proprietary"
        };
        
        Serial.printf("  LoRaWAN MType: %s\n", mtype_names[mtype]);
    }
}

void updateDisplay() {
    display.clearDisplay();
    display.setCursor(0, 0);
    display.printf("LoRa Scanner\n");
    display.printf("Total: %lu packets\n", total_packets);
    display.printf("\nActive channels:\n");
    
    // Show top 3 active channels
    int shown = 0;
    for (int i = 0; i < NUM_CHANNELS && shown < 3; i++) {
        if (channel_stats[i].packet_count > 0) {
            display.printf("CH%d: %lu (%.0f dBm)\n", 
                          i, channel_stats[i].packet_count,
                          channel_stats[i].avg_rssi);
            shown++;
        }
    }
    
    display.display();
}

void loop() {
    static int current_channel = 0;
    static int current_sf_idx = 0;
    static uint32_t last_display_update = 0;
    
    // Scan current channel with current SF
    scanChannel(current_channel, SPREADING_FACTORS[current_sf_idx]);
    
    // Cycle through channels and SFs
    current_sf_idx++;
    if (current_sf_idx >= NUM_SF) {
        current_sf_idx = 0;
        current_channel = (current_channel + 1) % NUM_CHANNELS;
    }
    
    // Update display every second
    if (millis() - last_display_update > 1000) {
        updateDisplay();
        last_display_update = millis();
    }
}
```

---

## 7. Regional Frequency Plans

### 7.1 Major Regional Plans

| Region | Band (MHz) | Channel Spacing | Duty Cycle | Max EIRP |
|--------|------------|-----------------|------------|----------|
| **US915** | 902-928 | 125 kHz uplink, 500 kHz downlink | No limit | 30 dBm |
| **EU868** | 863-870 | 125 kHz | 0.1-1% | 14-27 dBm |
| **AU915** | 915-928 | Same as US915 | No limit | 30 dBm |
| **AS923** | 923 (varies) | 125/200 kHz | 1% | 14-16 dBm |
| **IN865** | 865-867 | 125 kHz | Varies | 30 dBm |
| **CN470** | 470-510 | 125 kHz | Varies | 17 dBm |

### 7.2 US915 Channel Plan Detail

```
Uplink channels (64 × 125 kHz + 8 × 500 kHz):
┌───────────────────────────────────────────────────────────────────┐
│ 903.0      904.6      906.2      907.8      909.4      911.0     │
│   │──────────│──────────│──────────│──────────│──────────│       │
│   └── 0-7 ──┘└── 8-15 ─┘└── 16-23 ┘└── 24-31 ┘└── 32-39 ┘       │
│                                                                   │
│ 500 kHz channels (8): 903.0, 904.6, 906.2, 907.8...              │
└───────────────────────────────────────────────────────────────────┘

Downlink channels (8 × 500 kHz):
│ 923.3  923.9  924.5  925.1  925.7  926.3  926.9  927.5           │
```

### 7.3 Frequency Scanning Script

```python
#!/usr/bin/env python3
"""Multi-region LoRa frequency scanner"""

FREQUENCY_PLANS = {
    'US915': {
        'uplink_125k': [(902.3 + i * 0.2) for i in range(64)],
        'uplink_500k': [(903.0 + i * 1.6) for i in range(8)],
        'downlink': [(923.3 + i * 0.6) for i in range(8)],
    },
    'EU868': {
        'uplink': [868.1, 868.3, 868.5, 867.1, 867.3, 867.5, 867.7, 867.9],
        'downlink': [869.525],
    },
    'AU915': {
        'uplink_125k': [(915.2 + i * 0.2) for i in range(64)],
        'uplink_500k': [(915.9 + i * 1.6) for i in range(8)],
        'downlink': [(923.3 + i * 0.6) for i in range(8)],
    },
}

def get_all_frequencies(region):
    """Get all frequencies for a region in MHz"""
    plan = FREQUENCY_PLANS.get(region, {})
    freqs = []
    for channel_type, channel_list in plan.items():
        freqs.extend(channel_list)
    return sorted(set(freqs))

# Example usage
for region in ['US915', 'EU868', 'AU915']:
    freqs = get_all_frequencies(region)
    print(f"{region}: {len(freqs)} channels, {min(freqs):.1f} - {max(freqs):.1f} MHz")
```

---

## 8. Detection Signatures & Patterns

### 8.1 Surveillance-Related LoRa Devices

| Device Type | Likely Protocol | Frequency | Detection Indicators |
|-------------|-----------------|-----------|---------------------|
| **Asset Trackers** | LoRaWAN Class A | Regional | Periodic uplink (hourly/daily) |
| **GPS Trackers** | Meshtastic/Proprietary | 915 MHz | GPS coordinates in payload |
| **Sensor Networks** | LoRaWAN | Regional | Regular intervals, small payloads |
| **Mesh Repeaters** | Meshtastic | 915 MHz | High duty cycle, routing headers |

### 8.2 Traffic Pattern Analysis

```cpp
typedef struct {
    float frequency;
    int sf;
    uint32_t packet_count;
    uint32_t first_seen_ms;
    uint32_t last_seen_ms;
    float avg_interval_ms;
    uint16_t avg_payload_len;
} TrafficPattern;

#define MAX_PATTERNS 32
TrafficPattern patterns[MAX_PATTERNS];
int pattern_count = 0;

void analyzeTrafficPattern(float freq, int sf, uint32_t now_ms, uint16_t payload_len) {
    // Find existing pattern or create new
    int idx = -1;
    for (int i = 0; i < pattern_count; i++) {
        if (abs(patterns[i].frequency - freq) < 0.01 && patterns[i].sf == sf) {
            idx = i;
            break;
        }
    }
    
    if (idx < 0 && pattern_count < MAX_PATTERNS) {
        idx = pattern_count++;
        patterns[idx].frequency = freq;
        patterns[idx].sf = sf;
        patterns[idx].packet_count = 0;
        patterns[idx].first_seen_ms = now_ms;
        patterns[idx].avg_interval_ms = 0;
        patterns[idx].avg_payload_len = 0;
    }
    
    if (idx >= 0) {
        TrafficPattern* p = &patterns[idx];
        
        if (p->packet_count > 0) {
            uint32_t interval = now_ms - p->last_seen_ms;
            p->avg_interval_ms = (p->avg_interval_ms + interval) / 2;
        }
        
        p->packet_count++;
        p->last_seen_ms = now_ms;
        p->avg_payload_len = (p->avg_payload_len + payload_len) / 2;
    }
}

void reportPatterns() {
    Serial.println("\n=== Traffic Patterns ===");
    for (int i = 0; i < pattern_count; i++) {
        TrafficPattern* p = &patterns[i];
        if (p->packet_count > 0) {
            Serial.printf("%.2f MHz SF%d: %lu pkts, avg interval %.0f ms, avg len %d\n",
                         p->frequency, p->sf, p->packet_count,
                         p->avg_interval_ms, p->avg_payload_len);
            
            // Flag suspicious patterns
            if (p->avg_interval_ms > 0 && p->avg_interval_ms < 60000) {
                Serial.println("  [!] High frequency transmitter");
            }
            if (p->avg_payload_len > 100) {
                Serial.println("  [!] Large payload device");
            }
        }
    }
}
```

---

## 9. Code Patterns & Best Practices

### 9.1 Channel Hopping with Bounded Iterations

```cpp
#define MAX_CHANNEL_HOP_ITERATIONS 1000
#define CHANNEL_DWELL_MS 50

void channelHopLoop() {
    static int current_channel = 0;
    static uint32_t last_hop = 0;
    int iterations = 0;
    
    while (iterations < MAX_CHANNEL_HOP_ITERATIONS) {
        if (millis() - last_hop >= CHANNEL_DWELL_MS) {
            current_channel = (current_channel + 1) % NUM_CHANNELS;
            setChannel(current_channel);
            last_hop = millis();
        }
        
        // Check for packets on current channel
        if (checkForPacket()) {
            handlePacket();
        }
        
        iterations++;
    }
}
```

### 9.2 NVS Persistent Statistics

```cpp
#include <Preferences.h>

Preferences prefs;

void loadStats() {
    prefs.begin("lora_scan", true);
    total_packets = prefs.getULong("total_pkts", 0);
    prefs.end();
}

void saveStats() {
    prefs.begin("lora_scan", false);
    prefs.putULong("total_pkts", total_packets);
    prefs.end();
}
```

---

## Quick Reference Card

### US915 Key Frequencies

| Use | Frequencies (MHz) |
|-----|-------------------|
| Common uplink | 903.9, 904.1, 904.3 |
| Meshtastic default | 906.875 (CH31) |
| Downlink | 923.3 - 927.5 |

### LoRa Parameters Quick Lookup

| SF | Time on Air (10 bytes) | Range (urban) | Data Rate |
|----|------------------------|---------------|-----------|
| 7 | 36 ms | 2 km | 5.5 kbps |
| 10 | 289 ms | 5 km | 0.98 kbps |
| 12 | 1155 ms | 8 km | 0.29 kbps |

### RadioLib Key Functions

```cpp
// Initialization
radio.begin(frequency_mhz);
radio.setSpreadingFactor(sf);
radio.setBandwidth(bw_khz);

// Reception
radio.startReceive();
radio.available();
radio.readData(buffer, length);
radio.getRSSI();
radio.getSNR();
```

---

## Resources & References

### Hardware
- **Heltec WiFi LoRa 32 V3**: https://heltec.org/project/wifi-lora-32-v3/
- **SX1262 Datasheet**: Semtech (LoRa transceiver)
- **RTL-SDR**: https://www.rtl-sdr.com

### Software
- **RadioLib**: https://github.com/jgromes/RadioLib
- **gr-lora**: https://github.com/rpp0/gr-lora
- **Meshtastic**: https://meshtastic.org

### Protocol Specifications
- **LoRaWAN Specification**: LoRa Alliance
- **Regional Parameters**: RP002-1.0.3 (LoRa Alliance)

---

*Document Version: 1.0 | Created: 2026-02-06 | Part of ainish-coder signals detection suite*
