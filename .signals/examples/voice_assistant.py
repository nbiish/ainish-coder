#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "llama-cpp-python>=0.2.0",
#   "sounddevice>=0.4.0",
#   "numpy>=1.24.0",
#   "requests>=2.28.0",
# ]
# [tool.uv]
# exclude-newer = "2026-02-01T00:00:00Z"
# ///
"""
Signals Voice Assistant - UV Portable Script

A voice-enabled assistant for signals detection education and Kismet control.
Uses: Liquid LFM 2.5 (LLM), optional NVIDIA Parakeet V3 (STT), optional PocketTTS

USAGE:
    # Run directly with uv (auto-installs dependencies)
    uv run voice_assistant.py

    # Text mode (no audio hardware needed)
    uv run voice_assistant.py --text-mode

    # With custom model path
    uv run voice_assistant.py --model ./models/lfm25.gguf

REQUIREMENTS:
    - uv (install: curl -LsSf https://astral.sh/uv/install.sh | sh)
    - GGUF model file (download from huggingface.co/liquid/LFM-2.5-1.2B-Instruct-GGUF)

OPTIONAL (for full voice mode):
    - NeMo toolkit: pip install nemo_toolkit[asr]
    - PocketTTS: pip install pocket-tts

Environment Variables:
    KISMET_API_KEY - API key for Kismet REST API
    LLM_MODEL_PATH - Path to GGUF model (default: ./models/lfm25.gguf)
"""

from __future__ import annotations

import os
import sys
import queue
import threading
import time
from dataclasses import dataclass, field
from typing import Optional, Callable, Generator

import numpy as np
import sounddevice as sd

# Conditional imports with graceful fallbacks
try:
    from llama_cpp import Llama
    HAS_LLAMA = True
except ImportError:
    HAS_LLAMA = False

try:
    import nemo.collections.asr as nemo_asr
    HAS_NEMO = True
except ImportError:
    HAS_NEMO = False

try:
    from pocket_tts import PocketTTS
    HAS_TTS = True
except ImportError:
    HAS_TTS = False

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False


# ============================================================================
# Configuration
# ============================================================================

@dataclass
class Config:
    """Voice assistant configuration"""
    llm_model_path: str = "./models/lfm25/lfm-2.5-1.2b-instruct-q4_k_m.gguf"
    kismet_host: str = "localhost"
    kismet_port: int = 2501
    kismet_api_key: str = ""
    sample_rate_input: int = 16000
    sample_rate_output: int = 24000
    listen_duration: float = 5.0
    n_threads: int = 4
    n_ctx: int = 4096
    max_tokens: int = 150
    temperature: float = 0.7

    @classmethod
    def from_env(cls) -> Config:
        return cls(
            llm_model_path=os.environ.get("LLM_MODEL_PATH", cls.llm_model_path),
            kismet_api_key=os.environ.get("KISMET_API_KEY", ""),
        )


# ============================================================================
# Kismet Client
# ============================================================================

class KismetClient:
    """REST client for Kismet wireless monitoring"""
    
    def __init__(self, host: str = "localhost", port: int = 2501, api_key: str = ""):
        self.base_url = f"http://{host}:{port}"
        self.headers = {"KISMET": api_key} if api_key else {}
    
    def _get(self, endpoint: str) -> dict:
        if not HAS_REQUESTS:
            return {}
        try:
            resp = requests.get(f"{self.base_url}{endpoint}", 
                              headers=self.headers, timeout=5)
            resp.raise_for_status()
            return resp.json()
        except Exception:
            return {}
    
    def get_devices(self, phy: str = "wifi") -> list:
        if phy == "wifi":
            return self._get("/devices/views/phydot11_accesspoints/devices.json") or []
        return self._get("/devices/all_devices.json") or []
    
    def search_ssid(self, pattern: str) -> list:
        import re
        devices = self.get_devices("wifi")
        regex = re.compile(pattern, re.IGNORECASE)
        return [d for d in devices if regex.search(d.get("kismet.device.base.name", ""))]
    
    def get_alerts(self) -> list:
        return self._get("/alerts/all_alerts.json") or []
    
    def get_context(self) -> str:
        parts = []
        devices = self.get_devices("wifi")
        if devices:
            parts.append(f"Tracking {len(devices)} WiFi devices.")
        surveillance = self.search_ssid("FLOCK|PENGUIN|RAVEN")
        if surveillance:
            parts.append(f"⚠️ {len(surveillance)} surveillance devices!")
        return " ".join(parts) if parts else "Kismet not connected."


# ============================================================================
# LLM Engine
# ============================================================================

SYSTEM_PROMPT = """You are a signals detection expert assistant. Help users:
- Understand surveillance tech (FLOCK cameras, Raven/ShotSpotter sensors)
- Configure Kismet wireless monitoring
- Analyze WiFi, BLE, LoRa signals
- Interpret RSSI: -30dBm=<1m, -50dBm=3-5m, -70dBm=10-20m, -85dBm=30-50m

Be concise (2-3 sentences). Key facts:
- FLOCK: SSID "FLOCK-XXXXX", MAC 58:8E:81
- Raven: BLE UUID 0x3100-0x3500
- Kismet: port 2501, REST API"""


class LLMEngine:
    """Liquid LFM 2.5 GGUF inference via llama.cpp"""
    
    def __init__(self, config: Config):
        self.config = config
        self.llm: Optional[Llama] = None
        self.messages: list[dict] = [{"role": "system", "content": SYSTEM_PROMPT}]
        
        if HAS_LLAMA and os.path.exists(config.llm_model_path):
            print(f"Loading LLM: {config.llm_model_path}")
            self.llm = Llama(
                model_path=config.llm_model_path,
                n_ctx=config.n_ctx,
                n_threads=config.n_threads,
                n_gpu_layers=0,
                verbose=False
            )
            print("✓ LLM loaded")
        else:
            print("⚠ LLM not found, using fallback responses")
    
    def generate(self, user_input: str, context: str = "") -> str:
        full_input = f"[{context}]\n{user_input}" if context else user_input
        self.messages.append({"role": "user", "content": full_input})
        
        if self.llm:
            result = self.llm.create_chat_completion(
                messages=self.messages,
                max_tokens=self.config.max_tokens,
                temperature=self.config.temperature
            )
            response = result["choices"][0]["message"]["content"]
        else:
            response = self._fallback(user_input)
        
        self.messages.append({"role": "assistant", "content": response})
        if len(self.messages) > 20:
            self.messages = self.messages[:1] + self.messages[-10:]
        return response
    
    def _fallback(self, text: str) -> str:
        t = text.lower()
        if "flock" in t:
            return "FLOCK cameras are ALPR surveillance devices. SSID: FLOCK-XXXXX, MAC: 58:8E:81."
        if "raven" in t or "shotspotter" in t:
            return "Raven/ShotSpotter are acoustic sensors with BLE UUIDs 0x3100-0x3500."
        if "rssi" in t:
            return "RSSI strength: -30dBm=<1m, -50dBm=3-5m, -70dBm=10-20m, -85dBm=30-50m."
        if "kismet" in t:
            return "Kismet: 'kismet -c wlan0mon', web UI at localhost:2501."
        return "I'm a signals detection assistant. Ask about FLOCK, Raven, RSSI, or Kismet."


# ============================================================================
# Audio I/O
# ============================================================================

class AudioCapture:
    """Microphone capture"""
    
    def __init__(self, sample_rate: int = 16000):
        self.sample_rate = sample_rate
        self.audio_queue: queue.Queue = queue.Queue()
        self.is_listening = False
    
    def _callback(self, indata, frames, time_info, status):
        if self.is_listening:
            self.audio_queue.put(indata.copy())
    
    def listen(self, duration: float) -> np.ndarray:
        print("🎤 Listening...")
        self.is_listening = True
        while not self.audio_queue.empty():
            self.audio_queue.get()
        
        try:
            with sd.InputStream(samplerate=self.sample_rate, channels=1,
                               dtype=np.float32, callback=self._callback):
                sd.sleep(int(duration * 1000))
        except Exception as e:
            print(f"Audio error: {e}")
            return np.array([])
        
        self.is_listening = False
        chunks = []
        while not self.audio_queue.empty():
            chunks.append(self.audio_queue.get())
        return np.concatenate(chunks).flatten() if chunks else np.array([])


class SpeechIO:
    """STT and TTS wrappers with fallbacks"""
    
    def __init__(self, sample_rate_in: int = 16000, sample_rate_out: int = 24000):
        self.sr_in = sample_rate_in
        self.sr_out = sample_rate_out
        self.stt_model = None
        self.tts_engine = None
        
        if HAS_NEMO:
            print("Loading Parakeet STT...")
            self.stt_model = nemo_asr.models.ASRModel.from_pretrained(
                "nvidia/parakeet-tdt-0.6b-v3"
            )
            print("✓ STT loaded")
        
        if HAS_TTS:
            print("Loading PocketTTS...")
            self.tts_engine = PocketTTS()
            print("✓ TTS loaded")
    
    def transcribe(self, audio: np.ndarray) -> str:
        if self.stt_model and len(audio) > 0:
            result = self.stt_model.transcribe([audio])
            return result[0] if result else ""
        return input("You (text): ").strip()
    
    def speak(self, text: str):
        print(f"🔊 {text}")
        if self.tts_engine:
            audio = self.tts_engine.synthesize(text)
            sd.play(audio, self.sr_out)
            sd.wait()


# ============================================================================
# Voice Assistant
# ============================================================================

class SignalsAssistant:
    """Main voice assistant"""
    
    def __init__(self, config: Optional[Config] = None):
        self.config = config or Config.from_env()
        print("=" * 50)
        print("🛰️  Signals Voice Assistant")
        print("=" * 50)
        
        self.kismet = KismetClient(
            self.config.kismet_host,
            self.config.kismet_port,
            self.config.kismet_api_key
        )
        self.llm = LLMEngine(self.config)
        self.audio = AudioCapture(self.config.sample_rate_input)
        self.speech = SpeechIO(self.config.sample_rate_input, self.config.sample_rate_output)
        print("=" * 50)
    
    def process_turn(self) -> bool:
        audio = self.audio.listen(self.config.listen_duration)
        if len(audio) == 0:
            return True
        
        text = self.speech.transcribe(audio)
        if not text.strip():
            return True
        
        print(f"👤 {text}")
        
        if any(cmd in text.lower() for cmd in ["goodbye", "exit", "quit"]):
            self.speech.speak("Goodbye!")
            return False
        
        response = self.llm.generate(text, self.kismet.get_context())
        self.speech.speak(response)
        return True
    
    def run(self):
        self.speech.speak("Hello! I'm your signals assistant.")
        try:
            while self.process_turn():
                pass
        except KeyboardInterrupt:
            print("\nInterrupted")


class TextAssistant:
    """Text-only mode"""
    
    def __init__(self, config: Optional[Config] = None):
        self.config = config or Config.from_env()
        self.llm = LLMEngine(self.config)
        self.kismet = KismetClient(
            self.config.kismet_host,
            self.config.kismet_port,
            self.config.kismet_api_key
        )
    
    def run(self):
        print("=" * 50)
        print("🛰️  Signals Assistant (Text Mode)")
        print("Type 'quit' to exit")
        print("=" * 50)
        
        while True:
            try:
                user = input("\n👤 You: ").strip()
                if not user:
                    continue
                if user.lower() in ["quit", "exit", "q"]:
                    print("Goodbye!")
                    break
                response = self.llm.generate(user, self.kismet.get_context())
                print(f"\n🔊 {response}")
            except (KeyboardInterrupt, EOFError):
                print("\nGoodbye!")
                break


# ============================================================================
# Main
# ============================================================================

def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description="🛰️ Signals Voice Assistant - UV Portable Script",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
EXAMPLES:
    uv run voice_assistant.py --text-mode
    uv run voice_assistant.py --model ./lfm25.gguf
        """
    )
    parser.add_argument("--text-mode", action="store_true",
                       help="Text-only mode (no audio)")
    parser.add_argument("--model", type=str,
                       help="Path to GGUF model file")
    args = parser.parse_args()
    
    config = Config.from_env()
    if args.model:
        config.llm_model_path = args.model
    
    assistant = TextAssistant(config) if args.text_mode else SignalsAssistant(config)
    assistant.run()


if __name__ == "__main__":
    main()
