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
#   "scikit-learn>=1.3.0",
# ]
# [tool.uv]
# exclude-newer = "2026-02-01T00:00:00Z"
# ///
"""
Unified Signals Voice Agent — OSA v2.0
=======================================

A comprehensive, interactive voice agent that orchestrates:
  - Proactive alert delivery from correlation engine & Kismet
  - Rich context injection for LLM reasoning
  - Voice-driven continuous improvement feedback loops
  - Proactive insight generation and briefings
  - Acoustic forensics (FFT/impulse detection)
  - LoRa/SDR hardware control
  - OSA world state management
  - ML anomaly detection (Isolation Forest)
  - RAG knowledge base (LanceDB)

Architecture:
  ┌──────────────────────────────────────────────────────────────┐
  │                  Unified Voice Agent                          │
  │                                                              │
  │  ┌──────────┐  ┌──────────────┐  ┌────────────────────────┐ │
  │  │ AudioIO  │  │  LLM Engine  │  │  Alert Orchestrator    │ │
  │  │ STT/TTS  │  │  (LFM 2.5)  │  │  (background monitor)  │ │
  │  └────┬─────┘  └──────┬───────┘  └────────────┬───────────┘ │
  │       │               │                        │             │
  │  ┌────▼───────────────▼────────────────────────▼───────────┐ │
  │  │              Command Router                              │ │
  │  │  voice input → feedback? → command? → LLM query          │ │
  │  └────┬──────────┬──────────┬──────────┬──────────┬────────┘ │
  │       │          │          │          │          │           │
  │  ┌────▼────┐ ┌───▼────┐ ┌──▼───┐ ┌───▼────┐ ┌──▼────────┐ │
  │  │Feedback │ │Insight │ │Audio │ │Context │ │LoRa/SDR   │ │
  │  │ Engine  │ │Engine  │ │Analy.│ │Inject. │ │Controller │ │
  │  └─────────┘ └────────┘ └──────┘ └────────┘ └───────────┘ │
  │                                                              │
  │  ┌──────────────────────────────────────────────────────────┐│
  │  │  Shared State: WorldState, Kismet, AnomalyDetector, DB  ││
  │  └──────────────────────────────────────────────────────────┘│
  └──────────────────────────────────────────────────────────────┘

USAGE:
    uv run unified_voice_agent.py
    uv run unified_voice_agent.py --text-mode
    uv run unified_voice_agent.py --text-mode --no-alerts

"""

from __future__ import annotations

import argparse
import json
import logging
import os
import pickle
import queue
import sys
import threading
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

import numpy as np
import requests
import sounddevice as sd
import yaml
from scipy.fft import fft, fftfreq

# Conditional imports — graceful degradation
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
    from sklearn.ensemble import IsolationForest
    from sklearn.preprocessing import StandardScaler
    HAS_SKLEARN = True
except ImportError:
    HAS_SKLEARN = False

# Local modules
from alert_orchestrator import AlertOrchestrator, Alert, AlertPriority
from correlation_context import CorrelationContextInjector
from continuous_improvement import VoiceContinuousImprovement
from insight_engine import VoiceInsightEngine

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("unified_voice_agent")

# ============================================================================
# Configuration
# ============================================================================

@dataclass
class AgentConfig:
    """Unified agent configuration — all settings in one place."""
    # LLM
    llm_model_path: str = "./models/lfm25/lfm-2.5-1.2b-instruct-q4_k_m.gguf"
    n_threads: int = 4
    n_ctx: int = 4096
    max_tokens: int = 200
    temperature: float = 0.7

    # Audio
    sample_rate_input: int = 16000
    sample_rate_output: int = 24000
    listen_duration: float = 5.0

    # Kismet
    kismet_host: str = "localhost"
    kismet_port: int = 2501
    kismet_api_key: str = ""

    # Persistence
    data_dir: str = "data"
    toon_path: str = "data/MEMORY.toon"
    feedback_db_path: str = "data/feedback.db"
    alert_state_path: str = "data/alert_state.json"
    ml_model_path: str = "data/anomaly_model.pkl"
    kb_path: str = "data/signals_kb"
    signals_docs_path: str = ".signals"

    # Alert Orchestrator
    alert_cooldown: float = 30.0
    alert_poll_interval: float = 5.0
    confidence_threshold: float = 0.70
    anomaly_threshold: float = 0.60

    # Flags
    enable_alerts: bool = True
    text_mode: bool = False

    @classmethod
    def from_env(cls) -> AgentConfig:
        return cls(
            llm_model_path=os.environ.get("LLM_MODEL_PATH", cls.llm_model_path),
            kismet_api_key=os.environ.get("KISMET_API_KEY", ""),
            data_dir=os.environ.get("SIGNALS_DATA_DIR", cls.data_dir),
        )


# ============================================================================
# Acoustic Forensics (from voice_assistant.py, enhanced)
# ============================================================================

class AudioAnalyzer:
    """FFT and impulse detection on audio samples."""

    def __init__(self, sample_rate: int):
        self.sample_rate = sample_rate

    def analyze(self, audio: np.ndarray) -> Dict[str, Any]:
        if len(audio) == 0:
            return {"status": "silent", "classification": "Silent"}

        rms = float(np.sqrt(np.mean(audio ** 2)))
        peak = float(np.max(np.abs(audio)))
        crest_factor = peak / (rms + 1e-9)

        N = len(audio)
        yf = fft(audio)
        xf = fftfreq(N, 1 / self.sample_rate)

        idx = slice(0, N // 2)
        freqs = xf[idx]
        mags = np.abs(yf[idx])

        low_band = float(np.sum(mags[(freqs >= 20) & (freqs < 300)]))
        mid_band = float(np.sum(mags[(freqs >= 300) & (freqs < 2000)]))
        high_band = float(np.sum(mags[(freqs >= 2000) & (freqs < 8000)]))

        classification = "Ambient"
        if crest_factor > 10.0 and high_band > low_band:
            classification = "Impulse (Click/Snap)"
        elif mid_band > (low_band + high_band) * 2:
            classification = "Voice Activity"

        return {
            "rms": rms,
            "peak": peak,
            "crest_factor": crest_factor,
            "classification": classification,
            "bands": {"low": low_band, "mid": mid_band, "high": high_band},
        }


# ============================================================================
# LoRa Controller (mock — ready for real hardware)
# ============================================================================

class LoRaController:
    """Simulates LoRa/SDR hardware control."""

    def scan(self) -> str:
        import random
        threats = []
        if random.random() < 0.3:
            threats.append("Meshtastic Node (User ID: !12345678)")
        if random.random() < 0.1:
            threats.append("Unknown LoRaWAN device (DevAddr: 26011234)")

        if threats:
            return f"LoRa scan complete. Detected: {', '.join(threats)}"
        return "LoRa scan complete. No signals detected in 915 MHz band."


# ============================================================================
# Kismet Client
# ============================================================================

class KismetClient:
    """REST client for Kismet wireless IDS."""

    def __init__(self, host: str, port: int, api_key: str):
        self.base_url = f"http://{host}:{port}"
        self.headers = {"KISMET": api_key} if api_key else {}

    def get_devices(self, phy: str = "wifi") -> List[Dict[str, Any]]:
        try:
            endpoint = (
                f"{self.base_url}/devices/views/phydot11_accesspoints/devices.json"
                if phy == "wifi"
                else f"{self.base_url}/devices/views/all/devices.json"
            )
            r = requests.get(endpoint, headers=self.headers, timeout=2)
            return r.json() if r.status_code == 200 else []
        except Exception:
            return []

    def get_alerts(self) -> List[Dict[str, Any]]:
        try:
            r = requests.get(
                f"{self.base_url}/alerts/all_alerts.json",
                headers=self.headers, timeout=2,
            )
            return r.json() if r.status_code == 200 else []
        except Exception:
            return []

    def get_context(self) -> str:
        try:
            r = requests.get(
                f"{self.base_url}/system/status.json",
                headers=self.headers, timeout=1,
            )
            if r.status_code == 200:
                data = r.json()
                devices = data.get("kismet.system.devices.count", 0)
                return f"Kismet: Online ({devices} devices)"
            return "Kismet: Error"
        except Exception:
            return "Kismet: Disconnected"


# ============================================================================
# OSA World State
# ============================================================================

class WorldState:
    """Manages MEMORY.toon state file."""

    def __init__(self, path: str):
        self.path = path
        self.state: Dict[str, Any] = {
            "agent": "unified_voice_agent",
            "version": "2.0",
            "status": "active",
            "last_update": datetime.now(timezone.utc).isoformat(),
            "threats": [],
            "environment": "unknown",
            "session_start": datetime.now(timezone.utc).isoformat(),
        }
        self._lock = threading.Lock()
        self._load()

    def update(self, key: str, value: Any) -> None:
        with self._lock:
            self.state[key] = value
            self.state["last_update"] = datetime.now(timezone.utc).isoformat()
            self._write()

    def add_threat(self, threat: Dict[str, Any]) -> None:
        with self._lock:
            if not any(t.get("mac") == threat.get("mac") for t in self.state["threats"]):
                self.state["threats"].append(threat)
                self.state["last_update"] = datetime.now(timezone.utc).isoformat()
                self._write()

    def _write(self) -> None:
        Path(self.path).parent.mkdir(parents=True, exist_ok=True)
        tmp = Path(self.path).with_suffix(".tmp")
        tmp.write_text(yaml.dump(self.state, default_flow_style=False))
        tmp.rename(self.path)

    def _load(self) -> None:
        if Path(self.path).exists():
            try:
                with open(self.path) as f:
                    loaded = yaml.safe_load(f)
                    if isinstance(loaded, dict):
                        self.state.update(loaded)
            except Exception:
                pass


# ============================================================================
# ML Anomaly Detector (from memory_agent.py)
# ============================================================================

@dataclass
class DeviceObservation:
    mac: str
    rssi: float
    channel: int
    packet_type: str
    ssid: str
    timestamp: float
    service_uuids: List[str] = field(default_factory=list)


class FeatureExtractor:
    """Extracts numerical features from device observation history."""

    SURVEILLANCE_PATTERNS = ["FLOCK", "RAVEN", "PENGUIN", "FS EXT", "SHOTSPOT"]

    def __init__(self, window_seconds: float = 60.0):
        self.window_seconds = window_seconds
        self.device_history: Dict[str, List[DeviceObservation]] = {}

    def add_observation(self, obs: DeviceObservation) -> None:
        if obs.mac not in self.device_history:
            self.device_history[obs.mac] = []
        self.device_history[obs.mac].append(obs)
        cutoff = obs.timestamp - self.window_seconds
        self.device_history[obs.mac] = [
            o for o in self.device_history[obs.mac] if o.timestamp >= cutoff
        ]

    def extract(self, mac: str) -> np.ndarray:
        obs_list = self.device_history.get(mac, [])
        if len(obs_list) < 2:
            return np.zeros(16, dtype=np.float32)

        rssi_values = [o.rssi for o in obs_list]
        timestamps = [o.timestamp for o in obs_list]
        channels = [o.channel for o in obs_list]
        intervals = np.diff(timestamps)

        return np.array([
            np.mean(rssi_values),
            np.std(rssi_values),
            np.mean(intervals) if len(intervals) > 0 else 0,
            np.std(intervals) if len(intervals) > 0 else 0,
            len(set(channels)),
            len(obs_list) / self.window_seconds,
            self._oui_hash(mac),
            1.0 if self._is_surveillance(obs_list[0]) else 0.0,
            0, 0, 0, 0, 0, 0, 0, 0,
        ], dtype=np.float32)

    @staticmethod
    def _oui_hash(mac: str) -> float:
        oui = mac.replace(":", "")[:6].upper()
        return (hash(oui) % 10000) / 10000.0

    def _is_surveillance(self, obs: DeviceObservation) -> bool:
        ssid = obs.ssid.upper()
        return any(p in ssid for p in self.SURVEILLANCE_PATTERNS)


class AnomalyDetector:
    """Isolation Forest anomaly detector with persistence."""

    def __init__(self, model_path: str):
        self.model_path = model_path
        self.model = None
        self.scaler = None
        self._load()

    def train(self, features: np.ndarray) -> None:
        if not HAS_SKLEARN:
            return
        self.scaler = StandardScaler()
        X = self.scaler.fit_transform(features)
        self.model = IsolationForest(contamination=0.05, random_state=42)
        self.model.fit(X)
        self._save()
        logger.info("Trained anomaly model on %d samples", len(features))

    def predict(self, feature_vector: np.ndarray) -> float:
        if not self.model or not HAS_SKLEARN:
            return 0.0
        X = self.scaler.transform(feature_vector.reshape(1, -1))
        score = self.model.decision_function(X)[0]
        return 1.0 / (1.0 + np.exp(score))

    def _save(self) -> None:
        Path(self.model_path).parent.mkdir(parents=True, exist_ok=True)
        with open(self.model_path, "wb") as f:
            pickle.dump({"model": self.model, "scaler": self.scaler}, f)

    def _load(self) -> None:
        if not Path(self.model_path).exists():
            return
        try:
            with open(self.model_path, "rb") as f:
                data = pickle.load(f)
                self.model = data["model"]
                self.scaler = data["scaler"]
            logger.info("Loaded anomaly model")
        except Exception as e:
            logger.warning("Failed to load anomaly model: %s", e)


# ============================================================================
# Stub Correlation Engine (for standalone testing)
# ============================================================================

class StubCorrelator:
    """
    Minimal correlator stub for standalone testing.

    In production, replace with the real SignalCorrelator from the
    Creeper Sweeper webapp.
    """

    def __init__(self) -> None:
        self.clusters: Dict[str, Dict[str, Any]] = {}
        self._step = 0

    def rssi_tolerance_info(self) -> Dict[str, Any]:
        gap_initial = 20.0
        gap_target = 1.0
        decay = 0.92
        amplitude = gap_initial - gap_target
        gap = gap_target + amplitude * (decay ** self._step)
        envelope = amplitude * (decay ** self._step)
        pct = min(100.0, (1 - envelope / amplitude) * 100) if amplitude > 0 else 100.0

        return {
            "step": self._step,
            "rssi_gap_dbm": round(gap, 1),
            "rssi_gap_target_dbm": gap_target,
            "rssi_gap_initial_dbm": gap_initial,
            "wifi_tolerance_dbm": round(gap, 1),
            "bt_tolerance_dbm": round(gap + 4, 1),
            "wifi_target_dbm": gap_target,
            "bt_target_dbm": gap_target + 4,
            "initial_dbm": gap_initial,
            "decay_factor": decay,
            "wifi_envelope_dbm": round(envelope, 1),
            "bt_envelope_dbm": round(envelope, 1),
            "converged": envelope < 1.0,
            "convergence_pct": round(pct, 0),
        }

    def advance_step(self) -> None:
        self._step += 1


# ============================================================================
# LLM Engine
# ============================================================================

SYSTEM_PROMPT = """You are the Unified Signals Voice Agent v2.0, an expert in RF surveillance detection and signals intelligence.

Your capabilities:
- Real-time monitoring of WiFi, BLE, and LoRa signals via Kismet
- Correlation engine tracking device clusters across protocols
- Acoustic forensics (FFT analysis, impulse detection)
- ML anomaly detection for behavioral profiling
- Proactive alerts for surveillance devices (FLOCK, RAVEN, PENGUIN)
- Continuous improvement through operator feedback

Voice commands available:
- "insights" or "briefing": Proactive analysis of the RF environment
- "status": Current correlation and monitoring state
- "scan lora": Check 915 MHz band
- "listen" or "analyze audio": Acoustic spectrum analysis
- "report": Improvement report from feedback data
- "explain": Why the last alert was triggered
- "false positive" / "confirm threat": Provide feedback on detections

Keep responses concise (2-3 sentences) since they are spoken aloud.
Use technical terms but explain briefly when first mentioned.
Always prioritize actionable information."""


class LLMEngine:
    """LFM 2.5 GGUF model with context-enriched prompts."""

    def __init__(self, config: AgentConfig):
        self.config = config
        self.llm = None
        self.messages: List[Dict[str, str]] = [
            {"role": "system", "content": SYSTEM_PROMPT}
        ]

        if HAS_LLAMA and Path(config.llm_model_path).exists():
            logger.info("Loading LLM: %s", config.llm_model_path)
            self.llm = Llama(
                model_path=config.llm_model_path,
                n_ctx=config.n_ctx,
                n_threads=config.n_threads,
                verbose=False,
            )
        else:
            logger.warning("LLM not available — using fallback responses")

    def generate(self, user_input: str, context: str = "") -> str:
        """Generate response with injected context."""
        # Build prompt with context
        prompt = user_input
        if context:
            prompt = f"[SYSTEM CONTEXT]\n{context}\n[END CONTEXT]\n\nUser: {user_input}"

        self.messages.append({"role": "user", "content": prompt})

        if self.llm:
            try:
                res = self.llm.create_chat_completion(
                    messages=self.messages,
                    max_tokens=self.config.max_tokens,
                    temperature=self.config.temperature,
                )
                text = res["choices"][0]["message"]["content"]
            except Exception as e:
                logger.error("LLM generation error: %s", e)
                text = self._fallback(user_input)
        else:
            text = self._fallback(user_input)

        self.messages.append({"role": "assistant", "content": text})

        # Trim history to prevent context overflow
        if len(self.messages) > 20:
            self.messages = self.messages[:1] + self.messages[-18:]

        return text

    @staticmethod
    def _fallback(text: str) -> str:
        t = text.lower()
        if "lora" in t:
            return "Scanning LoRa band on 915 MHz."
        if "listen" in t or "audio" in t:
            return "Analyzing acoustic signatures."
        if "flock" in t:
            return "FLOCK cameras are ALPR devices, typically broadcasting SSID FLOCK-XXXXX on WiFi."
        if "raven" in t:
            return "Raven sensors are acoustic gunshot detectors using BLE with UUID prefix 0x3100."
        return "I am the Unified Signals Voice Agent. Ask about WiFi, BLE, LoRa, or surveillance detection."


# ============================================================================
# Audio I/O
# ============================================================================

class AudioCapture:
    """Microphone input capture."""

    def __init__(self, sample_rate: int = 16000):
        self.sample_rate = sample_rate

    def listen(self, duration: float) -> np.ndarray:
        print("  [mic] Listening...")
        recording: List[np.ndarray] = []

        def callback(indata: np.ndarray, frames: int, time_info: Any, status: Any) -> None:
            recording.append(indata.copy())

        try:
            with sd.InputStream(
                samplerate=self.sample_rate, channels=1, callback=callback
            ):
                sd.sleep(int(duration * 1000))
        except Exception as e:
            logger.error("Audio capture error: %s", e)
            return np.array([], dtype=np.float32)

        if not recording:
            return np.array([], dtype=np.float32)
        return np.concatenate(recording).flatten()


class SpeechIO:
    """Speech-to-text and text-to-speech."""

    def __init__(self) -> None:
        self.stt = None
        self.tts = None

        if HAS_NEMO:
            logger.info("Loading STT (Parakeet v3)...")
            self.stt = nemo_asr.models.ASRModel.from_pretrained(
                "nvidia/parakeet-tdt-0.6b-v3"
            )
        if HAS_TTS:
            logger.info("Loading TTS (PocketTTS)...")
            self.tts = PocketTTS()

    def transcribe(self, audio: np.ndarray) -> str:
        if self.stt and len(audio) > 0:
            try:
                return self.stt.transcribe([audio])[0]
            except Exception as e:
                logger.error("STT error: %s", e)
        return input("  You (text): ").strip()

    def speak(self, text: str) -> None:
        print(f"  Agent: {text}")
        if self.tts:
            try:
                wav = self.tts.synthesize(text)
                sd.play(wav, 24000)
                sd.wait()
            except Exception as e:
                logger.error("TTS error: %s", e)


# ============================================================================
# Command Router
# ============================================================================

class CommandRouter:
    """
    Routes voice input to the appropriate handler.

    Priority order:
      1. Exit commands
      2. Feedback (continuous improvement)
      3. Built-in voice commands (insights, status, scan, etc.)
      4. LLM query with context injection
    """

    COMMANDS: Dict[str, List[str]] = {
        "insights": ["insights", "briefing", "brief me", "what do you see"],
        "status": ["status", "state", "how are things", "report status"],
        "scan_lora": ["scan lora", "lora scan", "check lora"],
        "analyze_audio": ["listen", "analyze audio", "analyze sound", "acoustic"],
        "report": ["report", "improvement report", "feedback report", "retraining"],
        "explain": ["explain", "why did you alert", "what triggered", "how did you know"],
        "alerts": ["alerts", "recent alerts", "alert summary", "what happened"],
        "help": ["help", "commands", "what can you do"],
    }

    @classmethod
    def match(cls, text: str) -> Optional[str]:
        """Match user input to a command. Returns command key or None."""
        t = text.lower().strip()
        for cmd, patterns in cls.COMMANDS.items():
            if any(p in t for p in patterns):
                return cmd
        return None


# ============================================================================
# Unified Voice Agent
# ============================================================================

class UnifiedSignalsVoiceAgent:
    """
    Main orchestrator that wires all subsystems together.

    Lifecycle:
      1. __init__: Load all models and subsystems
      2. run(): Main conversation loop
      3. Background: AlertOrchestrator monitors in separate thread
    """

    def __init__(self, config: AgentConfig):
        self.config = config
        Path(config.data_dir).mkdir(parents=True, exist_ok=True)

        print("=" * 60)
        print("  Unified Signals Voice Agent v2.0 (OSA)")
        print("=" * 60)

        # --- Core Voice I/O ---
        self.audio = AudioCapture(config.sample_rate_input)
        self.speech = SpeechIO()
        self.llm = LLMEngine(config)

        # --- Acoustic & Hardware ---
        self.analyzer = AudioAnalyzer(config.sample_rate_input)
        self.lora = LoRaController()

        # --- Shared State ---
        self.kismet = KismetClient(
            config.kismet_host, config.kismet_port, config.kismet_api_key
        )
        self.world = WorldState(config.toon_path)
        self.anomaly = AnomalyDetector(config.ml_model_path)
        self.feature_extractor = FeatureExtractor()

        # --- Correlation Engine (stub for standalone, real in production) ---
        self.correlator = StubCorrelator()

        # --- New Subsystems ---
        self.alert_orchestrator = AlertOrchestrator(
            voice=self.speech,
            correlator=self.correlator,
            kismet=self.kismet,
            cooldown_seconds=config.alert_cooldown,
            poll_interval=config.alert_poll_interval,
            confidence_threshold=config.confidence_threshold,
            anomaly_threshold=config.anomaly_threshold,
            persistence_path=config.alert_state_path,
        )

        self.context_injector = CorrelationContextInjector(
            correlator=self.correlator,
            world_state=self.world,
            alert_orchestrator=self.alert_orchestrator,
            kismet=self.kismet,
        )

        self.feedback_engine = VoiceContinuousImprovement(
            db_path=config.feedback_db_path,
            world_state=self.world,
            anomaly_detector=self.anomaly,
        )

        self.insight_engine = VoiceInsightEngine(
            correlator=self.correlator,
            world_state=self.world,
            feedback_db=self.feedback_engine.db,
        )

        # Track last detection for feedback context
        self._last_detection: Dict[str, Any] = {}

        logger.info("All subsystems initialized")

    # ------------------------------------------------------------------
    # Main Loop
    # ------------------------------------------------------------------

    def run(self) -> None:
        """Main conversation loop."""
        # Start background alert monitoring
        if self.config.enable_alerts:
            self.alert_orchestrator.start()
            logger.info("Alert orchestrator started")

        # Greeting
        greeting = self._build_greeting()
        self.speech.speak(greeting)

        try:
            while True:
                try:
                    # Capture audio
                    if self.config.text_mode:
                        audio = np.array([0.0] * 1000, dtype=np.float32)
                        text = input("\n  You: ").strip()
                    else:
                        audio = self.audio.listen(self.config.listen_duration)
                        text = self.speech.transcribe(audio)

                    if not text:
                        continue

                    if not self.config.text_mode:
                        print(f"  You: {text}")

                    # Exit check
                    if text.lower().strip() in ("quit", "exit", "goodbye", "bye"):
                        self._shutdown()
                        break

                    # Process input
                    response = self._process_input(text, audio)
                    if response:
                        self.speech.speak(response)

                except KeyboardInterrupt:
                    self._shutdown()
                    break
                except Exception as e:
                    logger.exception("Error in main loop")
                    self.speech.speak(f"An error occurred: {e}")

        finally:
            self.alert_orchestrator.stop()

    # ------------------------------------------------------------------
    # Input Processing Pipeline
    # ------------------------------------------------------------------

    def _process_input(self, text: str, audio: np.ndarray) -> Optional[str]:
        """
        Route input through the processing pipeline:
          1. Feedback check
          2. Command match
          3. LLM query with context
        """
        # 1. Check for feedback (continuous improvement)
        feedback_response = self.feedback_engine.process_feedback(
            text, self._last_detection
        )
        if feedback_response:
            return feedback_response

        # 2. Check for built-in commands
        command = CommandRouter.match(text)
        if command:
            return self._handle_command(command, text, audio)

        # 3. LLM query with context injection
        context = self.context_injector.build_query_context(text)
        return self.llm.generate(text, context)

    # ------------------------------------------------------------------
    # Command Handlers
    # ------------------------------------------------------------------

    def _handle_command(
        self, command: str, text: str, audio: np.ndarray
    ) -> str:
        """Dispatch to command handler."""
        handlers = {
            "insights": self._cmd_insights,
            "status": self._cmd_status,
            "scan_lora": self._cmd_scan_lora,
            "analyze_audio": lambda t, a: self._cmd_analyze_audio(a),
            "report": self._cmd_report,
            "explain": self._cmd_explain,
            "alerts": self._cmd_alerts,
            "help": self._cmd_help,
        }
        handler = handlers.get(command)
        if handler:
            return handler(text, audio)
        return self.llm.generate(text, self.context_injector.build_voice_context())

    def _cmd_insights(self, text: str, audio: np.ndarray) -> str:
        """Generate and deliver proactive insights."""
        # Check if topic-specific
        topic_keywords = ["security", "threat", "device", "behavior", "pattern"]
        topic = ""
        for kw in topic_keywords:
            if kw in text.lower():
                topic = kw
                break

        if topic:
            insights = self.insight_engine.get_insights_for_topic(topic, max_count=3)
        else:
            insights = self.insight_engine.get_insights(max_count=3)

        if not insights:
            return "No insights available yet. The system needs more data to generate analysis."

        parts = ["Here's my analysis."]
        for insight in insights:
            parts.append(insight.text)
        return " ".join(parts)

    def _cmd_status(self, text: str, audio: np.ndarray) -> str:
        """Report current system status."""
        return self.context_injector.build_voice_context()

    def _cmd_scan_lora(self, text: str, audio: np.ndarray) -> str:
        """Execute LoRa scan."""
        return self.lora.scan()

    def _cmd_analyze_audio(self, audio: np.ndarray) -> str:
        """Analyze captured audio for acoustic signatures."""
        if len(audio) == 0:
            return "No audio captured for analysis."

        result = self.analyzer.analyze(audio)
        classification = result["classification"]
        crest = result["crest_factor"]
        bands = result["bands"]

        return (
            f"Audio analysis: {classification}. "
            f"Crest factor {crest:.1f}. "
            f"Band energy — low: {bands['low']:.0f}, "
            f"mid: {bands['mid']:.0f}, high: {bands['high']:.0f}."
        )

    def _cmd_report(self, text: str, audio: np.ndarray) -> str:
        """Generate improvement report from feedback data."""
        return self.feedback_engine.get_report_voice_summary(days=7)

    def _cmd_explain(self, text: str, audio: np.ndarray) -> str:
        """Explain the most recent detection/alert."""
        if not self._last_detection:
            return "No recent detection to explain. Ask about a specific alert."
        return self.feedback_engine._generate_explanation(self._last_detection)

    def _cmd_alerts(self, text: str, audio: np.ndarray) -> str:
        """Summarize recent alerts."""
        return self.alert_orchestrator.get_alert_summary()

    def _cmd_help(self, text: str, audio: np.ndarray) -> str:
        """List available commands."""
        return (
            "Available commands: "
            "'insights' for analysis, "
            "'status' for system state, "
            "'scan lora' for spectrum check, "
            "'listen' for audio analysis, "
            "'report' for improvement data, "
            "'explain' for alert details, "
            "'alerts' for recent activity, "
            "'false positive' or 'confirm threat' for feedback. "
            "Or ask any question about signals detection."
        )

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    def _build_greeting(self) -> str:
        """Build startup greeting with current state."""
        parts = ["Unified Signals Voice Agent online."]

        kismet_status = self.kismet.get_context()
        parts.append(kismet_status + ".")

        threats = len(self.world.state.get("threats", []))
        if threats > 0:
            parts.append(f"{threats} threats in world state.")

        if self.config.enable_alerts:
            parts.append("Alert monitoring active.")

        parts.append("Say 'help' for available commands.")
        return " ".join(parts)

    def _shutdown(self) -> None:
        """Clean shutdown."""
        self.world.update("status", "shutdown")
        self.alert_orchestrator.stop()
        self.speech.speak("Shutting down. Stay vigilant.")
        logger.info("Agent shutdown complete")


# ============================================================================
# Entry Point
# ============================================================================

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Unified Signals Voice Agent v2.0"
    )
    parser.add_argument(
        "--text-mode", action="store_true",
        help="Use text input instead of microphone",
    )
    parser.add_argument(
        "--no-alerts", action="store_true",
        help="Disable background alert monitoring",
    )
    parser.add_argument(
        "--model", type=str, default=None,
        help="Path to GGUF model file",
    )
    parser.add_argument(
        "--data-dir", type=str, default=None,
        help="Data directory for persistence",
    )
    args = parser.parse_args()

    config = AgentConfig.from_env()
    config.text_mode = args.text_mode
    config.enable_alerts = not args.no_alerts

    if args.model:
        config.llm_model_path = args.model
    if args.data_dir:
        config.data_dir = args.data_dir
        config.toon_path = f"{args.data_dir}/MEMORY.toon"
        config.feedback_db_path = f"{args.data_dir}/feedback.db"
        config.alert_state_path = f"{args.data_dir}/alert_state.json"
        config.ml_model_path = f"{args.data_dir}/anomaly_model.pkl"

    agent = UnifiedSignalsVoiceAgent(config)
    agent.run()


if __name__ == "__main__":
    main()
