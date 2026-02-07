#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "agno>=2.0.0",
#   "lancedb>=0.5.0",
#   "sentence-transformers>=2.2.0",
#   "llama-cpp-python>=0.2.0",
#   "requests>=2.28.0",
#   "numpy>=1.24.0",
# ]
# [tool.uv]
# exclude-newer = "2026-02-01T00:00:00Z"
# ///
"""
Signals Memory Agent - UV Portable Script

A persistent memory agent for signals detection with:
- SQLite session storage (Agno)
- LanceDB vector knowledge (RAG)
- LFM 2.5 GGUF local inference
- Kismet wireless monitoring integration

USAGE:
    # Run with uv (auto-installs dependencies)
    uv run memory_agent.py

    # Initialize knowledge base from signals docs
    uv run memory_agent.py --init-knowledge

    # With custom model path
    uv run memory_agent.py --model ./models/lfm25.gguf

REQUIREMENTS:
    - uv (install: curl -LsSf https://astral.sh/uv/install.sh | sh)
    - GGUF model file (download from huggingface.co/liquid/LFM-2.5-1.2B-Instruct-GGUF)

Environment Variables:
    KISMET_API_KEY - API key for Kismet REST API
    LLM_MODEL_PATH - Path to GGUF model
"""

from __future__ import annotations

import os
import re
import sqlite3
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterator, Optional

import requests

# ============================================================================
# Configuration
# ============================================================================

@dataclass
class Config:
    """Memory agent configuration"""
    llm_model_path: str = "./models/lfm25/lfm-2.5-1.2b-instruct-q4_k_m.gguf"
    db_path: str = "data/signals_agent.db"
    kb_path: str = "data/signals_kb"
    signals_docs_path: str = ".signals"
    kismet_host: str = "localhost"
    kismet_port: int = 2501
    kismet_api_key: str = ""
    n_threads: int = 4
    n_ctx: int = 4096
    max_tokens: int = 256
    temperature: float = 0.7

    @classmethod
    def from_env(cls) -> Config:
        return cls(
            llm_model_path=os.environ.get("LLM_MODEL_PATH", cls.llm_model_path),
            kismet_api_key=os.environ.get("KISMET_API_KEY", ""),
        )


# ============================================================================
# LLM Provider for Agno
# ============================================================================

try:
    from agno.models.base import Model
    from agno.models.message import Message
    HAS_AGNO = True
except ImportError:
    HAS_AGNO = False
    print("⚠ Agno not installed. Using simplified agent.")

try:
    from llama_cpp import Llama
    HAS_LLAMA = True
except ImportError:
    HAS_LLAMA = False


class LlamaModel:
    """LFM 2.5 GGUF model via llama-cpp-python"""
    
    def __init__(self, config: Config):
        self.config = config
        self.llm: Optional[Llama] = None
        
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
            print("⚠ LLM not found, using fallback")
    
    def generate(self, messages: list[dict], stream: bool = False) -> str | Iterator[str]:
        if self.llm is None:
            return self._fallback(messages[-1].get("content", ""))
        
        if stream:
            return self._stream_generate(messages)
        
        result = self.llm.create_chat_completion(
            messages=messages,
            max_tokens=self.config.max_tokens,
            temperature=self.config.temperature
        )
        return result["choices"][0]["message"]["content"]
    
    def _stream_generate(self, messages: list[dict]) -> Iterator[str]:
        stream = self.llm.create_chat_completion(
            messages=messages,
            max_tokens=self.config.max_tokens,
            temperature=self.config.temperature,
            stream=True
        )
        for chunk in stream:
            delta = chunk["choices"][0].get("delta", {})
            if "content" in delta:
                yield delta["content"]
    
    def _fallback(self, text: str) -> str:
        t = text.lower()
        if "flock" in t:
            return "FLOCK cameras are ALPR surveillance. SSID: FLOCK-XXXXX, MAC: 58:8E:81."
        if "raven" in t or "shotspotter" in t:
            return "Raven/ShotSpotter: acoustic sensors, BLE UUIDs 0x3100-0x3500."
        if "rssi" in t:
            return "RSSI: -30dBm=<1m, -50dBm=3-5m, -70dBm=10-20m, -85dBm=30-50m."
        if "kismet" in t:
            return "Kismet: 'kismet -c wlan0mon', web UI at localhost:2501."
        return "I'm a signals memory agent. Ask about FLOCK, Raven, RSSI, or Kismet."


# ============================================================================
# Database Manager
# ============================================================================

class DatabaseManager:
    """SQLite database for sessions and detections"""
    
    def __init__(self, db_path: str):
        self.db_path = db_path
        Path(db_path).parent.mkdir(parents=True, exist_ok=True)
        self._init_db()
    
    def _init_db(self):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Chat history
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS chat_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp TEXT NOT NULL
            )
        """)
        
        # Detections
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS detections (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                device_type TEXT,
                mac_address TEXT,
                ssid TEXT,
                rssi INTEGER,
                threat_score INTEGER,
                notes TEXT
            )
        """)
        
        # User preferences
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS preferences (
                key TEXT PRIMARY KEY,
                value TEXT,
                updated_at TEXT
            )
        """)
        
        conn.commit()
        conn.close()
    
    def add_message(self, session_id: str, role: str, content: str):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO chat_history (session_id, role, content, timestamp) VALUES (?, ?, ?, ?)",
            (session_id, role, content, datetime.now().isoformat())
        )
        conn.commit()
        conn.close()
    
    def get_history(self, session_id: str, limit: int = 10) -> list[dict]:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute(
            "SELECT role, content FROM chat_history WHERE session_id = ? ORDER BY id DESC LIMIT ?",
            (session_id, limit)
        )
        rows = cursor.fetchall()
        conn.close()
        return [{"role": r[0], "content": r[1]} for r in reversed(rows)]
    
    def log_detection(self, device_type: str, mac: str, ssid: str = "", 
                     rssi: int = 0, threat: int = 50, notes: str = "") -> int:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO detections (timestamp, device_type, mac_address, ssid, rssi, threat_score, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (datetime.now().isoformat(), device_type, mac, ssid, rssi, threat, notes))
        conn.commit()
        detection_id = cursor.lastrowid
        conn.close()
        return detection_id
    
    def search_detections(self, device_type: str = "", days: int = 7) -> list[dict]:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = "SELECT * FROM detections WHERE timestamp > datetime('now', ?)"
        params = [f"-{days} days"]
        
        if device_type:
            query += " AND device_type LIKE ?"
            params.append(f"%{device_type}%")
        
        query += " ORDER BY timestamp DESC LIMIT 20"
        cursor.execute(query, params)
        
        columns = [d[0] for d in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        conn.close()
        return results


# ============================================================================
# Knowledge Base
# ============================================================================

class KnowledgeBase:
    """LanceDB vector knowledge base"""
    
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
                print(f"✓ Knowledge base loaded ({len(self.table)} chunks)")
            else:
                print("⚠ Knowledge base empty. Run with --init-knowledge")
        except ImportError:
            print("⚠ LanceDB not available")
    
    def index_documents(self, docs_path: str):
        if self.db is None or self.embedder is None:
            print("Cannot index: LanceDB not available")
            return
        
        import lancedb
        
        docs = []
        signals_dir = Path(docs_path)
        
        for filepath in signals_dir.glob("*.md"):
            content = filepath.read_text()
            # Split by sections
            sections = content.split("\n## ")
            for i, section in enumerate(sections):
                if section.strip():
                    text = section if i == 0 else f"## {section}"
                    # Only index non-empty chunks
                    if len(text) > 50:
                        docs.append({
                            "text": text[:2000],  # Limit chunk size
                            "source": filepath.name,
                            "section": i
                        })
        
        if not docs:
            print("No documents found to index")
            return
        
        # Generate embeddings
        print(f"Indexing {len(docs)} document chunks...")
        texts = [d["text"] for d in docs]
        embeddings = self.embedder.encode(texts)
        
        # Add embeddings to docs
        for i, doc in enumerate(docs):
            doc["vector"] = embeddings[i].tolist()
        
        # Create or overwrite table
        if "signals_docs" in self.db.table_names():
            self.db.drop_table("signals_docs")
        
        self.table = self.db.create_table("signals_docs", docs)
        print(f"✓ Indexed {len(docs)} chunks from {signals_dir}")
    
    def search(self, query: str, limit: int = 5) -> list[dict]:
        if self.table is None or self.embedder is None:
            return []
        
        query_embedding = self.embedder.encode([query])[0]
        results = self.table.search(query_embedding).limit(limit).to_list()
        return [{"text": r["text"], "source": r["source"]} for r in results]


# ============================================================================
# Kismet Client
# ============================================================================

class KismetClient:
    """Kismet REST API client"""
    
    def __init__(self, host: str, port: int, api_key: str = ""):
        self.base_url = f"http://{host}:{port}"
        self.headers = {"KISMET": api_key} if api_key else {}
    
    def _get(self, endpoint: str) -> dict | list:
        try:
            resp = requests.get(
                f"{self.base_url}{endpoint}",
                headers=self.headers,
                timeout=5
            )
            resp.raise_for_status()
            return resp.json()
        except:
            return []
    
    def get_devices(self, limit: int = 10) -> list[dict]:
        devices = self._get("/devices/views/phydot11_accesspoints/devices.json")
        if isinstance(devices, list):
            return [{
                "ssid": d.get("kismet.device.base.name", ""),
                "mac": d.get("kismet.device.base.macaddr", ""),
                "rssi": d.get("kismet.device.base.signal", {}).get(
                    "kismet.common.signal.last_signal", 0
                )
            } for d in devices[:limit]]
        return []
    
    def search_surveillance(self, pattern: str = "FLOCK|PENGUIN|RAVEN") -> list[str]:
        devices = self.get_devices(100)
        regex = re.compile(pattern, re.IGNORECASE)
        return [d["ssid"] for d in devices if regex.search(d["ssid"])]
    
    def get_context(self) -> str:
        devices = self.get_devices(100)
        if not devices:
            return "Kismet not connected"
        
        surveillance = self.search_surveillance()
        parts = [f"Tracking {len(devices)} WiFi devices."]
        if surveillance:
            parts.append(f"⚠️ Surveillance detected: {surveillance}")
        return " ".join(parts)


# ============================================================================
# Memory Agent
# ============================================================================

SYSTEM_PROMPT = """You are a signals detection expert with persistent memory.

CAPABILITIES:
- Remember conversations across sessions
- Search knowledge base for technical details
- Query Kismet for live WiFi/BLE detection
- Log and search detection history

DOMAIN KNOWLEDGE:
- FLOCK cameras: SSID "FLOCK-XXXXX", MAC 58:8E:81
- Raven/ShotSpotter: BLE UUID 0x3100-0x3500
- RSSI ranges: -30dBm=<1m, -50dBm=3-5m, -70dBm=10-20m
- Kismet: REST API on port 2501

Be concise (2-3 sentences). Use your tools when relevant."""


class MemoryAgent:
    """Signals memory agent with persistent storage"""
    
    def __init__(self, config: Optional[Config] = None):
        self.config = config or Config.from_env()
        self.session_id = "default"
        
        print("=" * 50)
        print("🛰️  Signals Memory Agent")
        print("=" * 50)
        
        # Initialize components
        self.db = DatabaseManager(self.config.db_path)
        self.kb = KnowledgeBase(self.config.kb_path)
        self.kismet = KismetClient(
            self.config.kismet_host,
            self.config.kismet_port,
            self.config.kismet_api_key
        )
        self.llm = LlamaModel(self.config)
        
        print("=" * 50)
    
    def run(self, user_input: str) -> str:
        # Save user message
        self.db.add_message(self.session_id, "user", user_input)
        
        # Build context
        history = self.db.get_history(self.session_id, limit=10)
        knowledge = self.kb.search(user_input, limit=3)
        kismet_context = self.kismet.get_context()
        
        # Build messages
        messages = [{"role": "system", "content": SYSTEM_PROMPT}]
        
        # Add knowledge context if relevant
        if knowledge:
            kb_text = "\n".join([f"[{k['source']}]: {k['text'][:500]}" for k in knowledge])
            messages.append({
                "role": "system",
                "content": f"Relevant knowledge:\n{kb_text}"
            })
        
        # Add Kismet context
        messages.append({
            "role": "system",
            "content": f"Current status: {kismet_context}"
        })
        
        # Add history
        messages.extend(history)
        
        # Add current query
        messages.append({"role": "user", "content": user_input})
        
        # Generate response
        response = self.llm.generate(messages)
        
        # Save response
        self.db.add_message(self.session_id, "assistant", response)
        
        return response
    
    def log_detection(self, device_type: str, mac: str, **kwargs) -> str:
        detection_id = self.db.log_detection(device_type, mac, **kwargs)
        return f"Logged detection #{detection_id}: {device_type} at {mac}"
    
    def search_history(self, device_type: str = "", days: int = 7) -> list[dict]:
        return self.db.search_detections(device_type, days)


# ============================================================================
# Main
# ============================================================================

def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description="🛰️ Signals Memory Agent - UV Portable Script",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
EXAMPLES:
    uv run memory_agent.py
    uv run memory_agent.py --init-knowledge
    uv run memory_agent.py --model ./lfm25.gguf
        """
    )
    parser.add_argument("--model", type=str, help="Path to GGUF model")
    parser.add_argument("--init-knowledge", action="store_true",
                       help="Index .signals docs into knowledge base")
    parser.add_argument("--signals-path", type=str, default=".signals",
                       help="Path to signals documentation")
    args = parser.parse_args()
    
    config = Config.from_env()
    if args.model:
        config.llm_model_path = args.model
    if args.signals_path:
        config.signals_docs_path = args.signals_path
    
    # Initialize knowledge base if requested
    if args.init_knowledge:
        kb = KnowledgeBase(config.kb_path)
        kb.index_documents(config.signals_docs_path)
        return
    
    # Run agent
    agent = MemoryAgent(config)
    
    print("\nType 'quit' to exit, 'log TYPE MAC' to log detection")
    print("-" * 50)
    
    while True:
        try:
            user_input = input("\n👤 You: ").strip()
            
            if not user_input:
                continue
            
            if user_input.lower() in ["quit", "exit", "q"]:
                print("Goodbye!")
                break
            
            # Handle special commands
            if user_input.lower().startswith("log "):
                parts = user_input.split()
                if len(parts) >= 3:
                    result = agent.log_detection(parts[1], parts[2])
                    print(f"\n🔊 {result}")
                    continue
            
            if user_input.lower().startswith("history"):
                parts = user_input.split()
                device_type = parts[1] if len(parts) > 1 else ""
                results = agent.search_history(device_type)
                if results:
                    print(f"\n🔊 Found {len(results)} detections:")
                    for r in results[:5]:
                        print(f"  - {r['timestamp']}: {r['device_type']} ({r['ssid'] or r['mac_address']})")
                else:
                    print("\n🔊 No detections found")
                continue
            
            # Normal query
            response = agent.run(user_input)
            print(f"\n🔊 Agent: {response}")
            
        except KeyboardInterrupt:
            print("\nGoodbye!")
            break
        except EOFError:
            break


if __name__ == "__main__":
    main()
