# OSA Research & Brainstorm Plan: Signals Examples 2.0

**Objective**: Upgrade `memory_agent.py` and `voice_assistant.py` to state-of-the-art (SOTA) status by integrating deep technical knowledge from the `signals-*.md` suite and adopting OSA (Orchestrated System of Agents) principles.

## 1. Analysis of Current State

| Component | Current Capabilities | Gaps vs. SOTA Docs |
|-----------|----------------------|--------------------|
| **Memory Agent** | - Basic RAG (Agno/LanceDB)<br>- Simple rule-based detection<br>- Kismet integration | - Lacks ML-based anomaly detection (Isolation Forest)<br>- No LoRa/LPWAN awareness<br>- Limited behavioral profiling<br>- No persistent "World State" (OSA pattern) |
| **Voice Assistant** | - STT/TTS (Parakeet/PocketTTS)<br>- Basic Q&A<br>- Kismet context | - No acoustic surveillance detection (FFT/Impulse)<br>- No control over LoRa/SDR hardware<br>- Limited interactive drills/training |

## 2. Target Architecture (OSA Framework)

We will evolve the examples into a cohesive **Signals Intelligence Swarm**:

```mermaid
graph TD
    User((User)) <--> Voice[Voice Assistant<br>(Interface Agent)]
    Voice <--> Memory[Memory Agent<br>(Knowledge & State)]
    
    subgraph "OSA Swarm"
        Memory <--> Detect[Detection Engine<br>(ML/Anomaly)]
        Memory <--> LoRa[LoRa/SDR Agent<br>(Spectrum Analysis)]
        Memory <--> Acoustic[Acoustic Agent<br>(Audio Forensics)]
    end
    
    Detect --> Kismet[(Kismet)]
    Acoustic --> Mic[Microphone]
    LoRa --> SDR[RTL-SDR/ESP32]
```

## 3. Implementation Plan

### Phase 1: Knowledge & Core Logic (The "Memory" Upgrade)
- **Goal**: Make `memory_agent.py` the central "brain" (Gemini-like role).
- **Tasks**:
    1.  **Enhanced RAG**: Optimize chunking for `signals-*.md` (e.g., preserve tables and code blocks).
    2.  **World State**: Implement `MEMORY.toon` style state tracking for active threats.
    3.  **ML Integration**: Add `sklearn` Isolation Forest for behavioral anomaly detection (as described in `signals-ml-detection.md`).

### Phase 2: Sensory Expansion (The "Voice" Upgrade)
- **Goal**: Upgrade `voice_assistant.py` to be a multi-modal sensor interface.
- **Tasks**:
    1.  **Acoustic Module**: Implement the FFT/Impulse detection logic from `signals-acoustic.md` (using `numpy`/`scipy`).
    2.  **Voice Commands**: Add controls for "Start LoRa Scan", "Analyze Audio", "Report Threats".

### Phase 3: Hardware Abstraction
- **Goal**: Simulate hardware if not present.
- **Tasks**:
    1.  **Mock Interfaces**: Create mock classes for `LoRaScanner` and `I2SMicrophone` so the code runs on a laptop but is ready for ESP32/SDR.

## 4. Specific Technical Improvements

### A. ML Anomaly Detection (`signals-ml-detection.md`)
Implement `FeatureExtractor` class:
- Inputs: RSSI, Packet Interval, Channel Hopping.
- Model: `IsolationForest` (unsupervised).
- Output: Anomaly Score (0.0-1.0).

### B. Acoustic Fingerprinting (`signals-acoustic.md`)
Implement `AudioAnalyzer` class:
- Features: RMS Energy, ZCR (Zero-Crossing Rate), FFT Spectrum.
- Detection: Gunshot impulse (high energy, short duration) vs. Voice.

### C. LoRa/Meshtastic Decoding (`signals-lora-lpwan.md`)
Implement `LoRaPacketParser` class:
- Structure: Parse Headers, Sync Words (0x2B for Meshtastic).
- Fingerprint: Identify Meshtastic vs. LoRaWAN vs. Proprietary.

## 5. Next Steps
1.  **Refactor `memory_agent.py`** to include `FeatureExtractor` and improved `KnowledgeBase`.
2.  **Refactor `voice_assistant.py`** to include `AudioAnalyzer`.
3.  **Verify** against the "Expert Technical Reference" standards.
