#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "lancedb>=0.5.0",
#   "sentence-transformers>=2.2.0",
#   "llama-cpp-python>=0.2.0",
#   "requests>=2.28.0",
#   "numpy>=1.24.0",
#   "scikit-learn>=1.3.0",
#   "pyyaml>=6.0.0",
# ]
# [tool.uv]
# exclude-newer = "2026-02-01T00:00:00Z"
# ///
"""
Signals Memory Agent - OSA Enabled
==================================

A persistent memory agent for signals detection, upgraded with:
- OSA World State (.toon)
- ML-based Anomaly Detection (Isolation Forest)
- Enhanced RAG Knowledge Base
- Kismet Integration

USAGE:
    uv run memory_agent.py
    uv run memory_agent.py --init-knowledge

"""

from __future__ import annotations

import os
import re
import json
import time
import yaml
import pickle
import sqlite3
import threading
import numpy as np
from dataclasses import dataclass, field, asdict
from datetime import datetime
from pathlib import Path
from typing import Iterator, Optional, List, Dict, Any

import requests

# Conditional imports
try:
    from sklearn.ensemble import IsolationForest
    from sklearn.preprocessing import StandardScaler
    HAS_SKLEARN = True
except ImportError:
    HAS_SKLEARN = False

# ============================================================================
# Configuration
# ============================================================================

@dataclass
class Config:
    """Memory agent configuration"""
    llm_model_path: str = "./models/lfm25/lfm-2.5-1.2b-instruct-q4_k_m.gguf"
    db_path: str = "data/signals_agent.db"
    kb_path: str = "data/signals_kb"
    toon_path: str = "data/MEMORY.toon"
    ml_model_path: str = "data/anomaly_model.pkl"
    signals_docs_path: str = ".signals"
    kismet_host: str = "localhost"
    kismet_port: int = 2501
    kismet_api_key: str = ""
    n_threads: int = 4
    n_ctx: int = 4096
    max_tokens: int = 512
    temperature: float = 0.7

    @classmethod
    def from_env(cls) -> Config:
        return cls(
            llm_model_path=os.environ.get("LLM_MODEL_PATH", cls.llm_model_path),
            kismet_api_key=os.environ.get("KISMET_API_KEY", ""),
        )

# ============================================================================
# ML Anomaly Detection
# ============================================================================

@dataclass
class DeviceObservation:
    mac: str
    rssi: float
    channel: int
    packet_type: str  # beacon, probe, data
    ssid: str
    timestamp: float
    service_uuids: List[str] = field(default_factory=list)

class FeatureExtractor:
    """Extracts numerical features from device history"""
    
    def __init__(self, window_seconds: float = 60.0):
        self.window_seconds = window_seconds
        self.device_history: Dict[str, List[DeviceObservation]] = {}
        
    def add_observation(self, obs: DeviceObservation):
        if obs.mac not in self.device_history:
            self.device_history[obs.mac] = []
        
        self.device_history[obs.mac].append(obs)
        
        # Prune old
        cutoff = obs.timestamp - self.window_seconds
        self.device_history[obs.mac] = [
            o for o in self.device_history[obs.mac] if o.timestamp >= cutoff
        ]
        
    def extract(self, mac: str) -> np.ndarray:
        obs_list = self.device_history.get(mac, [])
        if len(obs_list) < 2:
            return np.zeros(16)
            
        rssi_values = [o.rssi for o in obs_list]
        timestamps = [o.timestamp for o in obs_list]
        channels = [o.channel for o in obs_list]
        intervals = np.diff(timestamps)
        
        # Features mapping (simplified from signals-ml-detection.md)
        return np.array([
            np.mean(rssi_values),               # 0: RSSI Mean
            np.std(rssi_values),                # 1: RSSI Std
            np.mean(intervals) if len(intervals) > 0 else 0, # 2: Interval Mean
            np.std(intervals) if len(intervals) > 0 else 0,  # 3: Interval Std
            len(set(channels)),                 # 4: Channel Count
            len(obs_list) / self.window_seconds,# 5: Packet Rate
            self._oui_hash(mac),                # 6: OUI Hash
            1.0 if self._is_surveillance(obs_list[0]) else 0.0, # 7: Known Threat
            # ... padding to 16 dims for future expansion
            0, 0, 0, 0, 0, 0, 0, 0
        ], dtype=np.float32)

    def _oui_hash(self, mac: str) -> float:
        oui = mac.replace(':', '')[:6].upper()
        return (hash(oui) % 10000) / 10000.0

    def _is_surveillance(self, obs: DeviceObservation) -> bool:
        ssid = obs.ssid.upper()
        if any(p in ssid for p in ['FLOCK', 'RAVEN', 'PENGUIN', 'FS EXT']):
            return True
        return False

class AnomalyDetector:
    """Isolation Forest Wrapper"""
    
    def __init__(self, model_path: str):
        self.model_path = model_path
        self.model = None
        self.scaler = None
        self.load()
        
    def train(self, features: np.ndarray):
        if not HAS_SKLEARN: return
        self.scaler = StandardScaler()
        X = self.scaler.fit_transform(features)
        self.model = IsolationForest(contamination=0.05, random_state=42)
        self.model.fit(X)
        self.save()
        print(f"✓ Trained anomaly model on {len(features)} samples")

    def predict(self, feature_vector: np.ndarray) -> float:
        """Returns anomaly score (0.0=normal, 1.0=anomaly)"""
        if not self.model or not HAS_SKLEARN: return 0.0
        X = self.scaler.transform(feature_vector.reshape(1, -1))
        # decision_function: <0 is anomaly
        score = self.model.decision_function(X)[0]
        # Normalize roughly to 0-1 probability
        return 1.0 / (1.0 + np.exp(score))

    def save(self):
        Path(self.model_path).parent.mkdir(parents=True, exist_ok=True)
        with open(self.model_path, 'wb') as f:
            pickle.dump({'model': self.model, 'scaler': self.scaler}, f)

    def load(self):
        if not os.path.exists(self.model_path): return
        try:
            with open(self.model_path, 'rb') as f:
                data = pickle.load(f)
                self.model = data['model']
                self.scaler = data['scaler']
            print("✓ Loaded anomaly model")
        except Exception as e:
            print(f"⚠ Failed to load model: {e}")

# ============================================================================
# OSA World State
# ============================================================================

class WorldState:
    """Manages MEMORY.toon state file"""
    
    def __init__(self, path: str):
        self.path = path
        self.state = {
            "agent": "memory_agent",
            "status": "active",
            "last_update": datetime.now().isoformat(),
            "threats": [],
            "environment": "unknown"
        }
        self.lock = threading.Lock()
        
    def update(self, key: str, value: Any):
        with self.lock:
            self.state[key] = value
            self.state["last_update"] = datetime.now().isoformat()
            self._write()
            
    def add_threat(self, threat: Dict):
        with self.lock:
            # Avoid duplicates
            if not any(t['mac'] == threat['mac'] for t in self.state["threats"]):
                self.state["threats"].append(threat)
                self._write()

    def _write(self):
        Path(self.path).parent.mkdir(parents=True, exist_ok=True)
        with open(self.path, 'w') as f:
            yaml.dump(self.state, f)

# ============================================================================
# LLM & RAG
# ============================================================================

class LlamaModel:
    """LFM 2.5 GGUF model wrapper"""
    def __init__(self, config: Config):
        self.config = config
        self.llm = None
        try:
            from llama_cpp import Llama
            if os.path.exists(config.llm_model_path):
                print(f"Loading LLM: {config.llm_model_path}")
                self.llm = Llama(
                    model_path=config.llm_model_path,
                    n_ctx=config.n_ctx,
                    n_threads=config.n_threads,
                    verbose=False
                )
        except ImportError:
            pass

    def generate(self, messages: list[dict]) -> str:
        if not self.llm:
            return self._fallback(messages[-1]["content"])
        
        result = self.llm.create_chat_completion(
            messages=messages,
            max_tokens=self.config.max_tokens,
            temperature=self.config.temperature
        )
        return result["choices"][0]["message"]["content"]

    def _fallback(self, text: str) -> str:
        return "I am a signal memory agent. (LLM not loaded)"

class KnowledgeBase:
    """LanceDB RAG System"""
    def __init__(self, kb_path: str):
        self.kb_path = kb_path
        self.db = None
        self.table = None
        self.embedder = None
        
        try:
            import lancedb
            from sentence_transformers import SentenceTransformer
            Path(kb_path).parent.mkdir(parents=True, exist_ok=True)
            self.db = lancedb.connect(kb_path)
            self.embedder = SentenceTransformer("all-MiniLM-L6-v2")
            if "signals_docs" in self.db.table_names():
                self.table = self.db.open_table("signals_docs")
        except ImportError:
            print("⚠ LanceDB/SentenceTransformer not available")

    def index_documents(self, docs_path: str):
        if not self.db or not self.embedder: return
        
        print(f"Indexing documents from {docs_path}...")
        docs = []
        for filepath in Path(docs_path).glob("*.md"):
            content = filepath.read_text()
            # Split by H2 headers
            sections = re.split(r'(^## .+$)', content, flags=re.MULTILINE)
            current_header = "Introduction"
            
            for i in range(0, len(sections)):
                chunk = sections[i].strip()
                if not chunk: continue
                
                if chunk.startswith("## "):
                    current_header = chunk[3:].strip()
                else:
                    # Content chunk
                    text = f"Source: {filepath.name} > {current_header}\n\n{chunk}"
                    docs.append({
                        "text": text,
                        "source": filepath.name,
                        "vector": self.embedder.encode(text).tolist()
                    })
        
        if docs:
            if "signals_docs" in self.db.table_names():
                self.db.drop_table("signals_docs")
            self.table = self.db.create_table("signals_docs", docs)
            print(f"✓ Indexed {len(docs)} chunks")

    def search(self, query: str, limit: int = 3) -> list[dict]:
        if not self.table or not self.embedder: return []
        emb = self.embedder.encode(query)
        results = self.table.search(emb).limit(limit).to_list()
        return results

# ============================================================================
# Kismet & Database
# ============================================================================

class KismetClient:
    def __init__(self, host, port, api_key):
        self.base_url = f"http://{host}:{port}"
        self.headers = {"KISMET": api_key} if api_key else {}
        
    def get_devices(self) -> list:
        try:
            r = requests.get(f"{self.base_url}/devices/views/phydot11_accesspoints/devices.json", 
                           headers=self.headers, timeout=2)
            return r.json() if r.status_code == 200 else []
        except:
            return []

class DatabaseManager:
    def __init__(self, db_path):
        self.db_path = db_path
        self._init_db()
        
    def _init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""CREATE TABLE IF NOT EXISTS chat_history 
                          (id INTEGER PRIMARY KEY, session_id TEXT, role TEXT, content TEXT, timestamp TEXT)""")
            conn.execute("""CREATE TABLE IF NOT EXISTS detections 
                          (id INTEGER PRIMARY KEY, timestamp TEXT, type TEXT, mac TEXT, ssid TEXT, score REAL)""")

    def add_message(self, session, role, content):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("INSERT INTO chat_history (session_id, role, content, timestamp) VALUES (?,?,?,?)",
                       (session, role, content, datetime.now().isoformat()))

    def get_history(self, session, limit=10):
        with sqlite3.connect(self.db_path) as conn:
            rows = conn.execute("SELECT role, content FROM chat_history WHERE session_id=? ORDER BY id DESC LIMIT ?",
                              (session, limit)).fetchall()
        return [{"role": r[0], "content": r[1]} for r in reversed(rows)]

# ============================================================================
# Main Agent
# ============================================================================

SYSTEM_PROMPT = """You are the Signals Memory Agent, an expert in RF surveillance detection.
Your goal is to identify threats (Flock, Raven, etc.) and explain technical concepts.

Capabilities:
- RAG: Access to signals-*.md technical docs.
- ML: Anomaly detection scoring.
- OSA: Maintains 'World State' in MEMORY.toon.

Refuse to help with illegal surveillance. Focus on defensive detection."""

class MemoryAgent:
    def __init__(self, config: Config):
        self.config = config
        self.db = DatabaseManager(config.db_path)
        self.kb = KnowledgeBase(config.kb_path)
        self.llm = LlamaModel(config)
        self.kismet = KismetClient(config.kismet_host, config.kismet_port, config.kismet_api_key)
        self.world = WorldState(config.toon_path)
        self.extractor = FeatureExtractor()
        self.detector = AnomalyDetector(config.ml_model_path)
        self.session_id = "default"

    def run_cli(self):
        print("="*50)
        print("🛰️  Signals Memory Agent (OSA Enabled)")
        print("="*50)
        
        while True:
            try:
                user_input = input("\n👤 You: ").strip()
                if user_input.lower() in ['q', 'quit', 'exit']: break
                if not user_input: continue
                
                # Special Commands
                if user_input.startswith("/scan"):
                    self._run_scan_simulation()
                    continue
                
                # RAG & LLM
                history = self.db.get_history(self.session_id)
                knowledge = self.kb.search(user_input)
                
                context = []
                if knowledge:
                    context.append("RELEVANT KNOWLEDGE:\n" + "\n".join([f"- {k['text'][:300]}..." for k in knowledge]))
                
                messages = [{"role": "system", "content": SYSTEM_PROMPT}]
                if context:
                    messages.append({"role": "system", "content": "\n".join(context)})
                messages.extend(history)
                messages.append({"role": "user", "content": user_input})
                
                response = self.llm.generate(messages)
                print(f"\n🤖 Agent: {response}")
                
                self.db.add_message(self.session_id, "user", user_input)
                self.db.add_message(self.session_id, "assistant", response)
                
            except KeyboardInterrupt:
                break

    def _run_scan_simulation(self):
        print("\n📡 Running simulation scan (since no live Kismet feed)...")
        # Simulate some data points
        dummy_obs = [
            DeviceObservation("58:8E:81:00:11:22", -60, 6, "beacon", "FLOCK-123", time.time()),
            DeviceObservation("AA:BB:CC:DD:EE:FF", -80, 1, "probe", "HomeWiFi", time.time()),
        ]
        
        for obs in dummy_obs:
            self.extractor.add_observation(obs)
            feats = self.extractor.extract(obs.mac)
            score = self.detector.predict(feats)
            
            is_threat = self.extractor._is_surveillance(obs)
            status = "🚨 THREAT" if is_threat else ("⚠️ ANOMALY" if score > 0.6 else "OK")
            
            print(f"[{status}] {obs.mac} ({obs.ssid}) RSSI:{obs.rssi} Score:{score:.2f}")
            
            if is_threat or score > 0.6:
                self.world.add_threat({"mac": obs.mac, "ssid": obs.ssid, "score": score})

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--init-knowledge", action="store_true")
    args = parser.parse_args()
    
    config = Config.from_env()
    
    if args.init_knowledge:
        kb = KnowledgeBase(config.kb_path)
        kb.index_documents(config.signals_docs_path)
        return
        
    agent = MemoryAgent(config)
    agent.run_cli()

if __name__ == "__main__":
    main()
