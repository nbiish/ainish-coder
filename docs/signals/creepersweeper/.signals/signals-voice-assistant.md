# Signals Voice Assistant: Expert Technical Reference

> **Beyond Expert-Level Guide to Voice-Enabled Signals Education & Detection**
>
> Part of the **signals detection** knowledge base — integrating Liquid LFM 2.5, NVIDIA Parakeet V3, and PocketTTS for low-CPU voice interaction.
>
> **Companion documents**: [Signals Kismet](signals-kismet.md) — Wireless monitoring | [Signals Detection](signals.md) — WiFi/BLE

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Liquid LFM 2.5 Integration](#2-liquid-lfm-25-integration)
3. [NVIDIA Parakeet V3 (STT)](#3-nvidia-parakeet-v3-stt)
4. [PocketTTS (Text-to-Speech)](#4-pockettts-text-to-speech)
5. [Voice Pipeline Implementation](#5-voice-pipeline-implementation)
6. [Kismet Voice Commands](#6-kismet-voice-commands)
7. [System Prompts & Domain Knowledge](#7-system-prompts--domain-knowledge)
8. [Hardware Setup](#8-hardware-setup)
9. [Deployment](#9-deployment)

---

## 1. Architecture Overview

### 1.1 Voice Pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│                   Voice-Enabled Signals Assistant                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌──────────────┐                                                  │
│   │  Microphone  │                                                  │
│   │  (USB/I2S)   │                                                  │
│   └──────┬───────┘                                                  │
│          │ Audio (16kHz, 16-bit)                                    │
│          ▼                                                          │
│   ┌────────────────────────────────────────┐                       │
│   │     NVIDIA Parakeet TDT 0.6B v3        │                       │
│   │  - 600M parameters                     │                       │
│   │  - 98% accuracy on clear audio         │                       │
│   │  - Automatic punctuation/timestamps    │                       │
│   └──────────────────┬─────────────────────┘                       │
│                      │ Text                                         │
│                      ▼                                              │
│   ┌────────────────────────────────────────┐   ┌─────────────────┐ │
│   │       Liquid LFM 2.5-1.2B-Instruct     │◄──│   Kismet API    │ │
│   │  - GGUF format (llama.cpp)             │   │   (Context)     │ │
│   │  - <2GB memory                         │   └─────────────────┘ │
│   │  - Signals domain knowledge            │                       │
│   │  - Tool calling for Kismet             │                       │
│   └──────────────────┬─────────────────────┘                       │
│                      │ Response text                                │
│                      ▼                                              │
│   ┌────────────────────────────────────────┐                       │
│   │         PocketTTS (Kyutai Labs)        │                       │
│   │  - 100M parameters                     │                       │
│   │  - CPU-only real-time synthesis        │                       │
│   │  - ~25sec for typical response         │                       │
│   └──────────────────┬─────────────────────┘                       │
│                      │ Audio                                        │
│                      ▼                                              │
│   ┌──────────────┐                                                  │
│   │   Speaker    │                                                  │
│   └──────────────┘                                                  │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Summary

| Component | Model | Parameters | Runtime | Memory |
|-----------|-------|------------|---------|--------|
| **STT** | Parakeet TDT 0.6B v3 | 600M | NeMo/ONNX | ~2GB |
| **LLM** | Liquid LFM 2.5-1.2B-Instruct | 1.2B | llama.cpp | <2GB |
| **TTS** | PocketTTS | 100M | CPU | <500MB |
| **Total** | - | ~1.9B | - | <4.5GB |

---

## 2. Liquid LFM 2.5 Integration

### 2.1 Model Download

```bash
# Install Hugging Face CLI
pip install huggingface_hub

# Download GGUF model
huggingface-cli download liquid/LFM-2.5-1.2B-Instruct-GGUF \
  --include "*.gguf" \
  --local-dir ./models/lfm25

# Available quantizations:
# - Q4_K_M (~700MB) - Best balance
# - Q5_K_M (~850MB) - Higher quality
# - Q8_0 (~1.2GB) - Near full precision
```

### 2.2 llama.cpp Setup

```bash
# Clone and build llama.cpp
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp

# Build with optimizations
# macOS (Metal)
make LLAMA_METAL=1 -j

# Linux (CPU only)
make -j

# Linux (CUDA)
make LLAMA_CUDA=1 -j

# Linux (Vulkan - AMD)
make LLAMA_VULKAN=1 -j
```

### 2.3 Python Binding

```bash
pip install llama-cpp-python

# With Metal (macOS)
CMAKE_ARGS="-DLLAMA_METAL=on" pip install llama-cpp-python

# With CUDA
CMAKE_ARGS="-DLLAMA_CUDA=on" pip install llama-cpp-python
```

### 2.4 Basic Inference

```python
from llama_cpp import Llama

# Load model
llm = Llama(
    model_path="./models/lfm25/lfm-2.5-1.2b-instruct-q4_k_m.gguf",
    n_ctx=4096,      # Context window
    n_threads=4,     # CPU threads
    n_gpu_layers=0,  # 0 for CPU-only, -1 for all on GPU
    verbose=False
)

# Chat completion
response = llm.create_chat_completion(
    messages=[
        {"role": "system", "content": "You are a signals detection expert."},
        {"role": "user", "content": "What is a FLOCK camera?"}
    ],
    max_tokens=256,
    temperature=0.7
)

print(response["choices"][0]["message"]["content"])
```

### 2.5 Streaming Response

```python
def stream_response(llm, messages):
    """Stream response tokens for real-time TTS"""
    stream = llm.create_chat_completion(
        messages=messages,
        max_tokens=256,
        temperature=0.7,
        stream=True
    )
    
    current_sentence = ""
    for chunk in stream:
        delta = chunk["choices"][0].get("delta", {})
        content = delta.get("content", "")
        current_sentence += content
        
        # Yield complete sentences for TTS
        if any(current_sentence.endswith(p) for p in [". ", "! ", "? ", "\n"]):
            yield current_sentence.strip()
            current_sentence = ""
    
    if current_sentence.strip():
        yield current_sentence.strip()
```

---

## 3. NVIDIA Parakeet V3 (STT)

### 3.1 Installation

```bash
# Install NeMo toolkit
pip install nemo_toolkit[asr]

# Or minimal install
pip install nvidia-nemo-asr
```

### 3.2 Model Loading

```python
import nemo.collections.asr as nemo_asr

# Load Parakeet TDT 0.6B v3
model = nemo_asr.models.ASRModel.from_pretrained("nvidia/parakeet-tdt-0.6b-v3")

# Move to GPU if available
import torch
if torch.cuda.is_available():
    model = model.cuda()
model.eval()
```

### 3.3 File Transcription

```python
def transcribe_file(model, audio_path: str) -> str:
    """Transcribe audio file with word timestamps"""
    result = model.transcribe([audio_path], timestamps=True)
    return result[0]

# Usage
text = transcribe_file(model, "recording.wav")
print(text)
```

### 3.4 Real-Time Streaming

```python
import sounddevice as sd
import numpy as np
import queue
import threading

class RealtimeSTT:
    def __init__(self, model, sample_rate=16000, chunk_duration=3.0):
        self.model = model
        self.sample_rate = sample_rate
        self.chunk_size = int(sample_rate * chunk_duration)
        self.audio_queue = queue.Queue()
        self.is_running = False
    
    def audio_callback(self, indata, frames, time, status):
        if status:
            print(f"Audio status: {status}")
        self.audio_queue.put(indata.copy())
    
    def transcribe_loop(self, callback):
        buffer = np.array([], dtype=np.float32)
        
        while self.is_running:
            try:
                chunk = self.audio_queue.get(timeout=1.0)
                buffer = np.append(buffer, chunk.flatten())
                
                if len(buffer) >= self.chunk_size:
                    # Transcribe buffer
                    audio_tensor = np.array([buffer[:self.chunk_size]])
                    result = self.model.transcribe(audio_tensor)
                    
                    if result[0].strip():
                        callback(result[0])
                    
                    # Keep overlap for context
                    buffer = buffer[self.chunk_size // 2:]
            except queue.Empty:
                continue
    
    def start(self, callback):
        self.is_running = True
        
        # Start audio stream
        self.stream = sd.InputStream(
            samplerate=self.sample_rate,
            channels=1,
            dtype=np.float32,
            callback=self.audio_callback,
            blocksize=1024
        )
        self.stream.start()
        
        # Start transcription thread
        self.transcribe_thread = threading.Thread(
            target=self.transcribe_loop, args=(callback,)
        )
        self.transcribe_thread.start()
    
    def stop(self):
        self.is_running = False
        self.stream.stop()
        self.stream.close()
        self.transcribe_thread.join()

# Usage
def on_transcription(text):
    print(f"Heard: {text}")

stt = RealtimeSTT(model)
stt.start(on_transcription)
# ... run for a while ...
stt.stop()
```

### 3.5 ONNX Optimization (Lower Latency)

```python
# Export to ONNX for faster CPU inference
model.export("parakeet_v3.onnx")

# Use ONNX Runtime
import onnxruntime as ort

session = ort.InferenceSession(
    "parakeet_v3.onnx",
    providers=['CPUExecutionProvider']
)

def transcribe_onnx(audio_array):
    inputs = {"audio_signal": audio_array}
    outputs = session.run(None, inputs)
    return decode_output(outputs[0])
```

---

## 4. PocketTTS (Text-to-Speech)

### 4.1 Installation

```bash
# Install from Hugging Face
pip install pocket-tts

# Or from source
git clone https://huggingface.co/spaces/kyutai/pocket-tts
cd pocket-tts
pip install -e .
```

### 4.2 Basic Usage

```python
from pocket_tts import PocketTTS

# Initialize
tts = PocketTTS()

# Generate speech
audio = tts.synthesize("Hello, I detected a FLOCK camera nearby.")

# Save to file
tts.save(audio, "output.wav")
```

### 4.3 Real-Time Playback

```python
import sounddevice as sd
import numpy as np

class VoiceOutput:
    def __init__(self, sample_rate=24000):
        self.tts = PocketTTS()
        self.sample_rate = sample_rate
    
    def speak(self, text: str):
        """Synthesize and play audio immediately"""
        audio = self.tts.synthesize(text)
        
        # Play audio
        sd.play(audio, self.sample_rate)
        sd.wait()
    
    def speak_async(self, text: str):
        """Non-blocking speech"""
        import threading
        thread = threading.Thread(target=self.speak, args=(text,))
        thread.start()
        return thread

# Usage
voice = VoiceOutput()
voice.speak("Surveillance device detected on channel 6.")
```

### 4.4 Streaming TTS for Long Responses

```python
class StreamingTTS:
    def __init__(self):
        self.tts = PocketTTS()
        self.sample_rate = 24000
        self.audio_buffer = []
    
    def synthesize_sentence(self, sentence: str):
        """Synthesize one sentence"""
        return self.tts.synthesize(sentence)
    
    def play_stream(self, sentences):
        """Play sentences as they're synthesized"""
        for sentence in sentences:
            audio = self.synthesize_sentence(sentence)
            sd.play(audio, self.sample_rate)
            sd.wait()

# Usage with LLM streaming
streaming_tts = StreamingTTS()
sentences = stream_response(llm, messages)  # From LLM section
streaming_tts.play_stream(sentences)
```

---

## 5. Voice Pipeline Implementation

### 5.1 Complete Voice Assistant

```python
#!/usr/bin/env python3
"""Voice-Enabled Signals Assistant"""

import os
import queue
import threading
import numpy as np
import sounddevice as sd
from llama_cpp import Llama
import nemo.collections.asr as nemo_asr
from pocket_tts import PocketTTS

class SignalsVoiceAssistant:
    def __init__(self, llm_path: str, kismet_api_key: str = ""):
        print("Loading models...")
        
        # Load LLM
        self.llm = Llama(
            model_path=llm_path,
            n_ctx=4096,
            n_threads=4,
            n_gpu_layers=0,
            verbose=False
        )
        
        # Load STT
        self.stt = nemo_asr.models.ASRModel.from_pretrained(
            "nvidia/parakeet-tdt-0.6b-v3"
        )
        
        # Load TTS
        self.tts = PocketTTS()
        
        # Kismet client (optional)
        self.kismet_api_key = kismet_api_key
        
        # Audio settings
        self.sample_rate = 16000
        self.audio_queue = queue.Queue()
        self.is_listening = False
        
        # Conversation history
        self.messages = [
            {"role": "system", "content": self._get_system_prompt()}
        ]
        
        print("Voice assistant ready!")
    
    def _get_system_prompt(self) -> str:
        return """You are a signals detection expert assistant. You help users:
- Understand surveillance technologies (Flock cameras, Raven sensors, etc.)
- Configure and use Kismet wireless monitoring
- Detect and analyze WiFi, BLE, and LoRa signals
- Interpret RSSI values and estimate device distances

Be concise in your responses (2-3 sentences max) since they will be spoken aloud.
Use technical terms but explain them briefly when first mentioned.

Key facts:
- FLOCK cameras are ALPR devices, often with SSID "FLOCK-XXXXX"
- Raven sensors (ShotSpotter) use BLE with UUID prefix 0x3100-0x3500
- RSSI of -50 dBm means very close (~3-5m), -80 dBm is far (~30-50m)
- Kismet runs on port 2501 with REST API"""
    
    def _audio_callback(self, indata, frames, time, status):
        if self.is_listening:
            self.audio_queue.put(indata.copy())
    
    def listen(self, duration: float = 5.0) -> str:
        """Listen for user speech and transcribe"""
        print("Listening...")
        self.is_listening = True
        audio_data = []
        
        with sd.InputStream(samplerate=self.sample_rate, channels=1,
                           dtype=np.float32, callback=self._audio_callback):
            sd.sleep(int(duration * 1000))
        
        self.is_listening = False
        
        # Collect audio
        while not self.audio_queue.empty():
            audio_data.append(self.audio_queue.get())
        
        if not audio_data:
            return ""
        
        # Transcribe
        audio_array = np.concatenate(audio_data).flatten()
        result = self.stt.transcribe([audio_array])
        text = result[0] if result else ""
        print(f"You said: {text}")
        return text
    
    def think(self, user_input: str) -> str:
        """Generate response using LLM"""
        self.messages.append({"role": "user", "content": user_input})
        
        response = self.llm.create_chat_completion(
            messages=self.messages,
            max_tokens=150,  # Keep responses short for speech
            temperature=0.7
        )
        
        assistant_message = response["choices"][0]["message"]["content"]
        self.messages.append({"role": "assistant", "content": assistant_message})
        
        return assistant_message
    
    def speak(self, text: str):
        """Synthesize and play response"""
        print(f"Assistant: {text}")
        audio = self.tts.synthesize(text)
        sd.play(audio, 24000)
        sd.wait()
    
    def run_conversation(self):
        """Main conversation loop"""
        self.speak("Hello! I'm your signals detection assistant. Ask me anything about WiFi, BLE, or surveillance detection.")
        
        while True:
            user_input = self.listen(duration=5.0)
            
            if not user_input.strip():
                continue
            
            if "goodbye" in user_input.lower() or "exit" in user_input.lower():
                self.speak("Goodbye! Stay vigilant.")
                break
            
            response = self.think(user_input)
            self.speak(response)

if __name__ == "__main__":
    assistant = SignalsVoiceAssistant(
        llm_path="./models/lfm25/lfm-2.5-1.2b-instruct-q4_k_m.gguf",
        kismet_api_key=os.environ.get("KISMET_API_KEY", "")
    )
    assistant.run_conversation()
```

### 5.2 Wake Word Detection (Optional)

```python
# Using Porcupine for wake word
import pvporcupine
import struct

class WakeWordDetector:
    def __init__(self, keyword="hey signals"):
        self.porcupine = pvporcupine.create(
            access_key="YOUR_PICOVOICE_KEY",
            keywords=[keyword]
        )
        self.sample_rate = self.porcupine.sample_rate
        self.frame_length = self.porcupine.frame_length
    
    def detect(self, audio_callback):
        """Listen for wake word, then call callback"""
        with sd.InputStream(samplerate=self.sample_rate, channels=1,
                           dtype=np.int16, blocksize=self.frame_length) as stream:
            while True:
                audio_frame, _ = stream.read(self.frame_length)
                pcm = struct.unpack_from("h" * self.frame_length, audio_frame)
                
                keyword_index = self.porcupine.process(pcm)
                if keyword_index >= 0:
                    audio_callback()
                    break
```

---

## 6. Kismet Voice Commands

### 6.1 Tool Calling Integration

```python
KISMET_TOOLS = [
    {
        "name": "kismet_get_devices",
        "description": "Get list of detected WiFi/BLE devices",
        "parameters": {"phy": {"type": "string", "enum": ["wifi", "ble", "all"]}}
    },
    {
        "name": "kismet_search_ssid",
        "description": "Search for devices by SSID pattern",
        "parameters": {"pattern": {"type": "string"}}
    },
    {
        "name": "kismet_get_alerts",
        "description": "Get recent security alerts",
        "parameters": {}
    }
]

def execute_tool(tool_name: str, params: dict, kismet_client) -> str:
    if tool_name == "kismet_get_devices":
        devices = kismet_client.get_devices(params.get("phy", "wifi"))
        return f"Found {len(devices)} devices"
    
    elif tool_name == "kismet_search_ssid":
        matches = kismet_client.search_ssid(params["pattern"])
        if matches:
            return f"Found {len(matches)} matching devices: " + \
                   ", ".join(d["kismet.device.base.name"] for d in matches[:3])
        return "No matching devices found"
    
    elif tool_name == "kismet_get_alerts":
        alerts = kismet_client.get_alerts()
        if alerts:
            return f"{len(alerts)} alerts. Most recent: {alerts[0].get('type', 'Unknown')}"
        return "No alerts"
    
    return "Unknown command"
```

### 6.2 Voice Command Examples

| Voice Command | Parsed Intent | Action |
|---------------|---------------|--------|
| "Are there any FLOCK cameras nearby?" | search_ssid("FLOCK") | API call + response |
| "How many devices are connected?" | get_devices("wifi") | API call + count |
| "Any security alerts?" | get_alerts() | API call + summary |
| "Start scanning channel 6" | add_source(channel=6) | Start Kismet source |

---

## 7. System Prompts & Domain Knowledge

### 7.1 Signals Expert Prompt

```python
SIGNALS_SYSTEM_PROMPT = """You are an expert signals detection assistant with deep knowledge of:

## Surveillance Devices
- FLOCK Safety ALPR cameras (SSID: FLOCK-XXXXX, MAC: 58:8E:81:*)
- Raven/ShotSpotter acoustic sensors (BLE UUID: 0x3100-0x3500)
- Penguin cameras and Pigvision systems

## Detection Techniques
- WiFi promiscuous mode and 802.11 frame analysis
- BLE advertisement scanning with NimBLE
- LoRa monitoring on 915MHz ISM band
- Kismet wireless IDS configuration

## Signal Analysis
- RSSI interpretation: -30dBm = <1m, -50dBm = 3-5m, -70dBm = 10-20m, -85dBm = 30-50m
- Path loss model: Distance = 10^((TxPower - RSSI) / (10 * n))
- 2.4GHz non-overlapping channels: 1, 6, 11

## Best Practices
- Use monitor mode for passive detection
- Enable Kismet IDS with channel locking
- Check MAC OUI prefixes for device identification

Keep responses concise (2-3 sentences) for voice output.
When asked about technical details, give the key fact first, then explain."""
```

### 7.2 Context Injection from Kismet

```python
def get_context_from_kismet(kismet_client) -> str:
    """Build context string from current Kismet state"""
    context_parts = []
    
    # Current device count
    devices = kismet_client.get_devices("wifi")
    context_parts.append(f"Currently tracking {len(devices)} WiFi devices.")
    
    # Check for surveillance devices
    surveillance = kismet_client.search_ssid("FLOCK|PENGUIN|RAVEN")
    if surveillance:
        context_parts.append(
            f"⚠️ {len(surveillance)} surveillance devices detected!"
        )
    
    # Recent alerts
    alerts = kismet_client.get_alerts()
    if alerts:
        context_parts.append(f"{len(alerts)} security alerts active.")
    
    return " ".join(context_parts)
```

---

## 8. Hardware Setup

### 8.1 Raspberry Pi 5 (8GB)

```bash
# Install dependencies
sudo apt update
sudo apt install -y python3-pip portaudio19-dev libsndfile1

# Audio setup
sudo apt install -y pulseaudio pulseaudio-utils
pulseaudio --start

# Check microphone
arecord -l

# Install Python packages
pip install sounddevice numpy
pip install llama-cpp-python
pip install nemo_toolkit[asr]
pip install pocket-tts
```

### 8.2 macOS (Apple Silicon)

```bash
# Install with Homebrew
brew install portaudio libsndfile

# llama.cpp with Metal
CMAKE_ARGS="-DLLAMA_METAL=on" pip install llama-cpp-python

# Other packages
pip install sounddevice numpy
pip install nemo_toolkit[asr]
pip install pocket-tts
```

### 8.3 USB Microphone Configuration

```python
# List audio devices
import sounddevice as sd
print(sd.query_devices())

# Select specific device
sd.default.device = (1, 3)  # (input_device_id, output_device_id)
```

---

## 9. Deployment

### 9.1 Systemd Service

```ini
# /etc/systemd/system/signals-voice.service
[Unit]
Description=Signals Voice Assistant
After=network.target kismet.service

[Service]
Type=simple
User=pi
Environment=KISMET_API_KEY=your_key_here
WorkingDirectory=/home/pi/signals-assistant
ExecStart=/home/pi/signals-assistant/venv/bin/python voice_assistant.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 9.2 Docker Deployment

```dockerfile
FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    portaudio19-dev libsndfile1 gcc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "voice_assistant.py"]
```

---

## Quick Reference Card

### Model Downloads

| Model | Command |
|-------|---------|
| LFM 2.5 | `huggingface-cli download liquid/LFM-2.5-1.2B-Instruct-GGUF` |
| Parakeet | Auto-downloads via NeMo |
| PocketTTS | `pip install pocket-tts` |

### Key Python Imports

```python
from llama_cpp import Llama
import nemo.collections.asr as nemo_asr
from pocket_tts import PocketTTS
import sounddevice as sd
```

### Memory Requirements

| Device | RAM | Storage |
|--------|-----|---------|
| Raspberry Pi 5 | 8GB | 10GB |
| Mac M1/M2 | 8GB | 10GB |
| Linux x86_64 | 8GB | 10GB |

---

## Resources & References

### Model Sources
- **Liquid LFM 2.5**: https://huggingface.co/liquid/LFM-2.5-1.2B-Instruct-GGUF
- **Parakeet v3**: https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3
- **PocketTTS**: https://huggingface.co/kyutai/pocket-tts

### Libraries
- **llama.cpp**: https://github.com/ggerganov/llama.cpp
- **llama-cpp-python**: https://github.com/abetlen/llama-cpp-python
- **NVIDIA NeMo**: https://github.com/NVIDIA/NeMo
- **sounddevice**: https://python-sounddevice.readthedocs.io

---

*Document Version: 1.0 | Created: 2026-02-06 | Part of ainish-coder signals detection suite*
