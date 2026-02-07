#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "llama-cpp-python>=0.2.0",
#   "sounddevice>=0.4.0",
#   "numpy>=1.24.0",
#   "scipy>=1.10.0",
#   "requests>=2.28.0",
#   "pyyaml>=6.0.0",
# ]
# [tool.uv]
# exclude-newer = "2026-02-01T00:00:00Z"
# ///
"""
Signals Voice Assistant - OSA Enabled
=====================================

A voice-enabled interface for the Signals Intelligence Swarm.
Upgraded with:
- Acoustic Forensics (FFT/Impulse Detection)
- LoRa/SDR Command Control
- OSA World State Integration

USAGE:
    uv run voice_assistant.py
    uv run voice_assistant.py --text-mode

"""

from __future__ import annotations

import os
import sys
import queue
import time
import yaml
import threading
import numpy as np
from dataclasses import dataclass
from typing import Optional, List, Dict
from pathlib import Path

# Audio/Signal Processing
import sounddevice as sd
from scipy.fft import fft, fftfreq

# Conditional Imports
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
    toon_path: str = "data/MEMORY.toon"
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
# Acoustic Forensics
# ============================================================================

class AudioAnalyzer:
    """Performs FFT and Impulse detection on audio samples"""
    
    def __init__(self, sample_rate: int):
        self.sample_rate = sample_rate
        
    def analyze(self, audio: np.ndarray) -> Dict:
        """Analyze audio chunk for surveillance signatures"""
        if len(audio) == 0:
            return {"status": "silent"}
            
        # 1. Impulse Detection (Gunshot/Click)
        # Simple energy threshold
        rms = np.sqrt(np.mean(audio**2))
        peak = np.max(np.abs(audio))
        crest_factor = peak / (rms + 1e-9)
        
        # 2. FFT Spectrum
        N = len(audio)
        yf = fft(audio)
        xf = fftfreq(N, 1 / self.sample_rate)
        
        # Get magnitude of positive frequencies
        idx = slice(0, N//2)
        freqs = xf[idx]
        mags = np.abs(yf[idx])
        
        # Band Energy
        low_band = np.sum(mags[(freqs >= 20) & (freqs < 300)])
        mid_band = np.sum(mags[(freqs >= 300) & (freqs < 2000)])
        high_band = np.sum(mags[(freqs >= 2000) & (freqs < 8000)])
        
        # Classification Logic
        classification = "Ambient"
        if crest_factor > 10.0 and high_band > low_band:
            classification = "Impulse (Click/Snap)"
        elif mid_band > (low_band + high_band) * 2:
            classification = "Voice Activity"
            
        return {
            "rms": float(rms),
            "crest_factor": float(crest_factor),
            "classification": classification,
            "bands": {
                "low": float(low_band),
                "mid": float(mid_band),
                "high": float(high_band)
            }
        }

# ============================================================================
# Hardware Abstraction (LoRa/SDR)
# ============================================================================

class LoRaController:
    """Simulates control of LoRa/SDR hardware"""
    
    def scan(self) -> str:
        # Simulate a scan result based on signals-lora-lpwan.md
        import random
        threats = []
        if random.random() < 0.3:
            threats.append("Meshtastic Node (User ID: !12345678)")
        
        if threats:
            return f"LoRa Scan Complete. Detected: {', '.join(threats)}"
        return "LoRa Scan Complete. No signals detected in 915 MHz band."

# ============================================================================
# LLM Engine & Kismet
# ============================================================================

SYSTEM_PROMPT = """You are the Signals Voice Assistant.
Control hardware (LoRa, Mic) and explain surveillance threats.
Use short, spoken-style responses.

Commands you can execute:
- "scan lora": Checks 915MHz band.
- "listen": Analyzes audio spectrum.
- "status": Checks global threat state.
"""

class LLMEngine:
    def __init__(self, config: Config):
        self.config = config
        self.llm = None
        self.messages = [{"role": "system", "content": SYSTEM_PROMPT}]
        
        if HAS_LLAMA and os.path.exists(config.llm_model_path):
            print(f"Loading LLM: {config.llm_model_path}")
            self.llm = Llama(
                model_path=config.llm_model_path,
                n_ctx=config.n_ctx,
                n_threads=config.n_threads,
                verbose=False
            )

    def generate(self, user_input: str, context: str = "") -> str:
        prompt = f"[{context}]\nUser: {user_input}"
        self.messages.append({"role": "user", "content": prompt})
        
        if self.llm:
            res = self.llm.create_chat_completion(
                messages=self.messages,
                max_tokens=self.config.max_tokens,
                temperature=self.config.temperature
            )
            text = res["choices"][0]["message"]["content"]
        else:
            text = self._fallback(user_input)
            
        self.messages.append({"role": "assistant", "content": text})
        return text

    def _fallback(self, text: str) -> str:
        if "lora" in text.lower(): return "Scanning LoRa band."
        if "listen" in text.lower(): return "Listening for acoustic signatures."
        return "I am the signals assistant."

class KismetClient:
    def __init__(self, host, port, api_key):
        self.base_url = f"http://{host}:{port}"
        self.headers = {"KISMET": api_key} if api_key else {}
        
    def get_context(self) -> str:
        if not HAS_REQUESTS: return "Kismet: Offline"
        try:
            r = requests.get(f"{self.base_url}/system/status.json", 
                           headers=self.headers, timeout=1)
            return "Kismet: Online" if r.status_code == 200 else "Kismet: Error"
        except:
            return "Kismet: Disconnected"

# ============================================================================
# Audio I/O
# ============================================================================

class AudioCapture:
    def __init__(self, sample_rate=16000):
        self.sample_rate = sample_rate
        self.q = queue.Queue()
        
    def listen(self, duration: float) -> np.ndarray:
        print("🎤 Listening...")
        recording = []
        def callback(indata, frames, time, status):
            recording.append(indata.copy())
            
        try:
            with sd.InputStream(samplerate=self.sample_rate, channels=1, callback=callback):
                sd.sleep(int(duration * 1000))
        except Exception as e:
            print(f"Audio Error: {e}")
            return np.array([])
            
        if not recording: return np.array([])
        return np.concatenate(recording).flatten()

class SpeechIO:
    def __init__(self):
        self.stt = None
        self.tts = None
        if HAS_NEMO:
            print("Loading STT...")
            self.stt = nemo_asr.models.ASRModel.from_pretrained("nvidia/parakeet-tdt-0.6b-v3")
        if HAS_TTS:
            print("Loading TTS...")
            self.tts = PocketTTS()
            
    def transcribe(self, audio: np.ndarray) -> str:
        if self.stt and len(audio) > 0:
            return self.stt.transcribe([audio])[0]
        return input("You (text): ").strip()

    def speak(self, text: str):
        print(f"🔊 {text}")
        if self.tts:
            wav = self.tts.synthesize(text)
            sd.play(wav, 24000)
            sd.wait()

# ============================================================================
# Main Assistant
# ============================================================================

class SignalsAssistant:
    def __init__(self, config: Config):
        self.config = config
        print("="*50)
        print("🛰️  Signals Voice Assistant (OSA Enabled)")
        print("="*50)
        
        self.llm = LLMEngine(config)
        self.audio = AudioCapture(config.sample_rate_input)
        self.speech = SpeechIO()
        self.analyzer = AudioAnalyzer(config.sample_rate_input)
        self.lora = LoRaController()
        self.kismet = KismetClient(config.kismet_host, config.kismet_port, config.kismet_api_key)
        
    def get_world_state(self) -> str:
        try:
            if os.path.exists(self.config.toon_path):
                with open(self.config.toon_path) as f:
                    data = yaml.safe_load(f)
                    threats = len(data.get("threats", []))
                    return f"World State: {threats} active threats logged."
        except:
            pass
        return "World State: Unknown"

    def run(self):
        self.speech.speak("System Online. Listening.")
        
        while True:
            try:
                audio = self.audio.listen(self.config.listen_duration)
                text = self.speech.transcribe(audio)
                
                if not text: continue
                print(f"👤 {text}")
                
                if text.lower() in ["quit", "exit"]:
                    self.speech.speak("Shutting down.")
                    break
                    
                # Command Processing
                context = f"{self.kismet.get_context()} | {self.get_world_state()}"
                response = ""
                
                if "lora" in text.lower():
                    response = self.lora.scan()
                elif "listen" in text.lower() or "analyze" in text.lower():
                    res = self.analyzer.analyze(audio)
                    response = f"Audio Analysis: {res['classification']} (Crest: {res['crest_factor']:.1f})"
                else:
                    response = self.llm.generate(text, context)
                    
                self.speech.speak(response)
                
            except KeyboardInterrupt:
                break

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--text-mode", action="store_true")
    args = parser.parse_args()
    
    config = Config.from_env()
    
    # In text mode, we mock the audio capture/speech
    if args.text_mode:
        # Simple override for text mode loop
        assistant = SignalsAssistant(config)
        # Monkey patch for text loop
        assistant.audio.listen = lambda d: np.array([0.0]*1000) # Dummy audio
        assistant.speech.transcribe = lambda a: input("\n👤 You: ").strip()
        assistant.speech.speak = lambda t: print(f"🔊 {t}")
        assistant.run()
    else:
        assistant = SignalsAssistant(config)
        assistant.run()

if __name__ == "__main__":
    main()
