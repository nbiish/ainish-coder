# Signals Memory Agent: Expert Technical Reference

> **Beyond Expert-Level Guide to Persistent Memory Agents for Signals Detection**
>
> Part of the **signals detection** knowledge base — integrating Agno framework with SQLite persistence, LanceDB vector knowledge, LFM 2.5 inference, and Kismet monitoring.
>
> **Companion documents**: [Signals Voice Assistant](signals-voice-assistant.md) | [Signals Kismet](signals-kismet.md)

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Agno Framework Fundamentals](#2-agno-framework-fundamentals)
3. [SQLite Session Persistence](#3-sqlite-session-persistence)
4. [LanceDB Knowledge Base](#4-lancedb-knowledge-base)
5. [LFM 2.5 GGUF Integration](#5-lfm-25-gguf-integration)
6. [Kismet Tool Integration](#6-kismet-tool-integration)
7. [Detection History Database](#7-detection-history-database)
8. [Complete Implementation](#8-complete-implementation)
9. [Deployment](#9-deployment)

---

## 1. Architecture Overview

### 1.1 Memory Agent Pipeline

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Signals Memory Agent                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   User Input                                                            │
│       │                                                                  │
│       ▼                                                                  │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                    Agno Agent Framework                         │   │
│   │                                                                 │   │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │   │
│   │  │   Session   │  │  Knowledge  │  │         Tools           │ │   │
│   │  │   Memory    │  │    Base     │  │  - Kismet detection     │ │   │
│   │  │  (SQLite)   │  │  (LanceDB)  │  │  - Log detection        │ │   │
│   │  │             │  │             │  │  - Search history       │ │   │
│   │  │ • Chat hist │  │ • signals/* │  │  - Set preference       │ │   │
│   │  │ • Context   │  │ • RAG embed │  └─────────────────────────┘ │   │
│   │  │ • State     │  │ • Patterns  │                              │   │
│   │  └──────┬──────┘  └──────┬──────┘                              │   │
│   │         │                │                                      │   │
│   │         └────────┬───────┘                                      │   │
│   │                  │                                              │   │
│   │                  ▼                                              │   │
│   │         ┌─────────────────┐                                     │   │
│   │         │   LFM 2.5 GGUF  │                                     │   │
│   │         │  (llama.cpp)    │                                     │   │
│   │         │  Local inference│                                     │   │
│   │         └────────┬────────┘                                     │   │
│   │                  │                                              │   │
│   └──────────────────┼──────────────────────────────────────────────┘   │
│                      │                                                   │
│                      ▼                                                   │
│               Agent Response                                             │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Summary

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Agent Framework** | Agno 2.2+ | Session management, tools, memory |
| **Session Storage** | SQLite | Conversation persistence |
| **Vector Knowledge** | LanceDB | Document RAG, semantic search |
| **LLM** | LFM 2.5-1.2B GGUF | Local inference via llama-cpp-python |
| **Detection Source** | Kismet REST API | Real-time WiFi/BLE monitoring |

---

## 2. Agno Framework Fundamentals

### 2.1 Installation

```bash
# Core installation
pip install agno lancedb

# With all providers
pip install "agno[all]"

# For local LLM support
pip install llama-cpp-python
```

### 2.2 Agent Concepts

**Agent**: Autonomous unit with LLM brain, tools, memory, and knowledge.

```python
from agno.agent import Agent
from agno.models.openai import OpenAIChat

agent = Agent(
    name="signals-expert",
    model=OpenAIChat(id="gpt-4"),  # Or local LLM
    description="Expert in signals detection and surveillance analysis",
    instructions=["Be concise", "Cite signal patterns"],
)

response = agent.run("What is a FLOCK camera?")
print(response.content)
```

**Memory Types:**
- **Session Memory**: Chat history within a session
- **Session Storage**: Persists sessions to database (SQLite)
- **Knowledge**: Vector-embedded documents for RAG
- **User Memory**: Learned preferences (agent learns about user)

### 2.3 Agent Lifecycle

```python
# Session 1
agent.run("My name is Alex. I'm interested in FLOCK detection.")

# Session 2 (later, with storage)
agent.run("What am I interested in?")
# → Retrieves from storage: "You mentioned interest in FLOCK detection"
```

---

## 3. SQLite Session Persistence

### 3.1 SqliteStorage Configuration

```python
from agno.agent import Agent
from agno.storage.sqlite import SqliteStorage

# Create storage backend
storage = SqliteStorage(
    table_name="agent_sessions",
    db_file="data/signals_agent.db"
)

# Create agent with persistent storage
agent = Agent(
    name="signals-memory-agent",
    storage=storage,
    add_history_to_messages=True,   # Include chat history
    num_history_responses=10,        # Last 10 exchanges
    # ... model, tools, etc.
)

# Sessions auto-persist on agent.run()
agent.run("Remember: I detected a FLOCK at Main & 5th")
```

### 3.2 Session Management

```python
from agno.storage.sqlite import SqliteStorage

storage = SqliteStorage(
    table_name="agent_sessions",
    db_file="data/signals_agent.db"
)

# List all sessions
sessions = storage.get_all_sessions()
for session in sessions:
    print(f"Session: {session.session_id}, User: {session.user_id}")

# Get specific session
session = storage.get_session(session_id="user-123-session-1")
if session:
    print(f"Messages: {len(session.messages)}")
    print(f"Last active: {session.updated_at}")

# Delete old sessions
storage.delete_session(session_id="old-session-id")
```

### 3.3 Multi-User Sessions

```python
# Each user gets their own session
def get_agent_for_user(user_id: str) -> Agent:
    return Agent(
        name="signals-memory-agent",
        session_id=f"session-{user_id}",  # Unique per user
        user_id=user_id,
        storage=SqliteStorage(
            table_name="agent_sessions",
            db_file="data/signals_agent.db"
        ),
        # ... rest of config
    )

# User Alice
alice_agent = get_agent_for_user("alice")
alice_agent.run("I focus on LoRa detection")

# User Bob (separate session)
bob_agent = get_agent_for_user("bob")
bob_agent.run("I focus on WiFi detection")
```

---

## 4. LanceDB Knowledge Base

### 4.1 Overview

LanceDB provides fast vector search for RAG (Retrieval-Augmented Generation), enabling the agent to answer questions using your signals documentation.

### 4.2 Creating Knowledge Base

```python
from agno.knowledge.lancedb import LanceDb
from agno.knowledge.document import Document
from agno.embedder.sentence_transformer import SentenceTransformerEmbedder
import os

# Initialize LanceDB with local embeddings
knowledge = LanceDb(
    table_name="signals_knowledge",
    uri="data/signals_kb",
    embedder=SentenceTransformerEmbedder(
        model="all-MiniLM-L6-v2"  # Fast, good quality
    )
)

# Load signals documentation
def load_signals_docs(signals_dir: str) -> list[Document]:
    docs = []
    for filename in os.listdir(signals_dir):
        if filename.endswith(".md"):
            filepath = os.path.join(signals_dir, filename)
            with open(filepath, 'r') as f:
                content = f.read()
            
            # Split by sections for better chunking
            sections = content.split("\n## ")
            for i, section in enumerate(sections):
                if section.strip():
                    docs.append(Document(
                        name=f"{filename}#section-{i}",
                        content=section if i == 0 else f"## {section}",
                        meta_data={"source": filename}
                    ))
    return docs

# Index documents
docs = load_signals_docs(".signals")
knowledge.load_documents(docs)
print(f"Indexed {len(docs)} document chunks")
```

### 4.3 Agent with Knowledge

```python
from agno.agent import Agent
from agno.knowledge.lancedb import LanceDb

knowledge = LanceDb(
    table_name="signals_knowledge",
    uri="data/signals_kb"
)

agent = Agent(
    name="signals-rag-agent",
    knowledge=knowledge,
    search_knowledge=True,          # Auto-search on queries
    num_documents=5,                # Top 5 relevant chunks
    # ... model, storage, etc.
)

# Agent will search knowledge base before answering
response = agent.run("What are the BLE UUIDs for Raven sensors?")
# → Retrieves from signals-quickref.md and signals.md
```

### 4.4 Hybrid Search (SQL + Vector)

```python
from agno.knowledge.combined import CombinedKnowledgeBase
from agno.knowledge.lancedb import LanceDb
from agno.knowledge.sql import SQLKnowledgeBase

# Vector for documents
vector_kb = LanceDb(table_name="signals_docs", uri="data/kb")

# SQL for structured data (detections)
sql_kb = SQLKnowledgeBase(
    db_url="sqlite:///data/detections.db",
    table_name="detections"
)

# Combined knowledge
knowledge = CombinedKnowledgeBase(
    sources=[vector_kb, sql_kb]
)

agent = Agent(
    name="hybrid-agent",
    knowledge=knowledge,
    # ...
)
```

---

## 5. LFM 2.5 GGUF Integration

### 5.1 Custom LLM Provider

Agno supports custom model providers. Here's how to integrate LFM 2.5 via llama-cpp-python:

```python
from agno.models.base import Model
from agno.models.message import Message
from llama_cpp import Llama
from typing import Iterator, Optional

class LlamaModel(Model):
    """Agno model provider for llama.cpp GGUF models"""
    
    def __init__(
        self,
        model_path: str,
        n_ctx: int = 4096,
        n_threads: int = 4,
        n_gpu_layers: int = 0,
        temperature: float = 0.7,
        max_tokens: int = 256,
    ):
        super().__init__(id=f"llama:{model_path}")
        self.llm = Llama(
            model_path=model_path,
            n_ctx=n_ctx,
            n_threads=n_threads,
            n_gpu_layers=n_gpu_layers,
            verbose=False
        )
        self.temperature = temperature
        self.max_tokens = max_tokens
    
    def invoke(self, messages: list[Message]) -> str:
        formatted = [
            {"role": m.role, "content": m.content}
            for m in messages
        ]
        
        response = self.llm.create_chat_completion(
            messages=formatted,
            max_tokens=self.max_tokens,
            temperature=self.temperature
        )
        
        return response["choices"][0]["message"]["content"]
    
    def invoke_stream(self, messages: list[Message]) -> Iterator[str]:
        formatted = [
            {"role": m.role, "content": m.content}
            for m in messages
        ]
        
        stream = self.llm.create_chat_completion(
            messages=formatted,
            max_tokens=self.max_tokens,
            temperature=self.temperature,
            stream=True
        )
        
        for chunk in stream:
            delta = chunk["choices"][0].get("delta", {})
            if "content" in delta:
                yield delta["content"]
```

### 5.2 Using with Agent

```python
from agno.agent import Agent

# Create local LLM model
local_llm = LlamaModel(
    model_path="./models/lfm-2.5-1.2b-instruct-q4_k_m.gguf",
    n_ctx=4096,
    n_threads=4,
    temperature=0.7,
    max_tokens=256
)

# Create agent with local LLM
agent = Agent(
    name="local-signals-agent",
    model=local_llm,
    instructions=[
        "You are a signals detection expert.",
        "Be concise (2-3 sentences).",
        "Reference specific patterns when discussing devices."
    ],
    # ... storage, knowledge, tools
)
```

---

## 6. Kismet Tool Integration

### 6.1 Agent Tools

Agno uses `@tool` decorator to define agent capabilities:

```python
from agno.tools import tool
import requests

KISMET_URL = "http://localhost:2501"
KISMET_API_KEY = ""

@tool
def get_wifi_devices(limit: int = 10) -> str:
    """Get list of detected WiFi access points from Kismet.
    
    Args:
        limit: Maximum number of devices to return
    
    Returns:
        JSON string of detected WiFi devices
    """
    headers = {"KISMET": KISMET_API_KEY} if KISMET_API_KEY else {}
    try:
        resp = requests.get(
            f"{KISMET_URL}/devices/views/phydot11_accesspoints/devices.json",
            headers=headers,
            timeout=5
        )
        devices = resp.json()[:limit]
        return str([{
            "ssid": d.get("kismet.device.base.name", ""),
            "mac": d.get("kismet.device.base.macaddr", ""),
            "rssi": d.get("kismet.device.base.signal", {}).get(
                "kismet.common.signal.last_signal", 0
            )
        } for d in devices])
    except Exception as e:
        return f"Error: {e}"

@tool
def search_surveillance_devices(pattern: str = "FLOCK|PENGUIN|RAVEN") -> str:
    """Search Kismet for surveillance device SSIDs.
    
    Args:
        pattern: Regex pattern to match SSIDs
    
    Returns:
        List of matching surveillance devices
    """
    import re
    headers = {"KISMET": KISMET_API_KEY} if KISMET_API_KEY else {}
    try:
        resp = requests.get(
            f"{KISMET_URL}/devices/views/phydot11_accesspoints/devices.json",
            headers=headers,
            timeout=5
        )
        devices = resp.json()
        regex = re.compile(pattern, re.IGNORECASE)
        matches = [
            d for d in devices
            if regex.search(d.get("kismet.device.base.name", ""))
        ]
        if matches:
            return f"Found {len(matches)} surveillance devices: " + str([
                d.get("kismet.device.base.name") for d in matches
            ])
        return "No surveillance devices detected"
    except Exception as e:
        return f"Error: {e}"

@tool
def get_alerts() -> str:
    """Get recent security alerts from Kismet."""
    headers = {"KISMET": KISMET_API_KEY} if KISMET_API_KEY else {}
    try:
        resp = requests.get(
            f"{KISMET_URL}/alerts/all_alerts.json",
            headers=headers,
            timeout=5
        )
        alerts = resp.json()
        if alerts:
            return f"{len(alerts)} alerts: " + str([
                a.get("type", "Unknown") for a in alerts[:5]
            ])
        return "No alerts"
    except:
        return "Kismet not available"
```

### 6.2 Agent with Tools

```python
from agno.agent import Agent

agent = Agent(
    name="kismet-agent",
    tools=[get_wifi_devices, search_surveillance_devices, get_alerts],
    show_tool_calls=True,
    # ... model, storage, knowledge
)

# Agent can now use Kismet
response = agent.run("Are there any FLOCK cameras nearby?")
# → Agent calls search_surveillance_devices tool
```

---

## 7. Detection History Database

### 7.1 Schema Design

```python
import sqlite3
from datetime import datetime

def init_detection_db(db_path: str = "data/detections.db"):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Detections table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS detections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            device_type TEXT,
            mac_address TEXT,
            ssid TEXT,
            rssi INTEGER,
            channel INTEGER,
            latitude REAL,
            longitude REAL,
            threat_score INTEGER,
            notes TEXT
        )
    """)
    
    # User preferences
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS user_preferences (
            key TEXT PRIMARY KEY,
            value TEXT,
            updated_at TEXT
        )
    """)
    
    conn.commit()
    conn.close()
```

### 7.2 Detection Logging Tool

```python
from agno.tools import tool
import sqlite3
from datetime import datetime

@tool
def log_detection(
    device_type: str,
    mac_address: str,
    ssid: str = "",
    rssi: int = 0,
    threat_score: int = 50,
    notes: str = ""
) -> str:
    """Log a surveillance device detection to the database.
    
    Args:
        device_type: Type of device (FLOCK, RAVEN, PENGUIN, etc.)
        mac_address: MAC address of device
        ssid: SSID if WiFi device
        rssi: Signal strength in dBm
        threat_score: Threat level 0-100
        notes: Additional notes
    
    Returns:
        Confirmation of logged detection
    """
    conn = sqlite3.connect("data/detections.db")
    cursor = conn.cursor()
    
    cursor.execute("""
        INSERT INTO detections 
        (timestamp, device_type, mac_address, ssid, rssi, threat_score, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (
        datetime.now().isoformat(),
        device_type,
        mac_address,
        ssid,
        rssi,
        threat_score,
        notes
    ))
    
    conn.commit()
    detection_id = cursor.lastrowid
    conn.close()
    
    return f"Logged detection #{detection_id}: {device_type} at {mac_address}"

@tool
def search_detection_history(
    device_type: str = "",
    days: int = 7
) -> str:
    """Search past detection events.
    
    Args:
        device_type: Filter by device type (empty for all)
        days: Number of days to search back
    
    Returns:
        List of matching detections
    """
    conn = sqlite3.connect("data/detections.db")
    cursor = conn.cursor()
    
    query = """
        SELECT timestamp, device_type, ssid, mac_address, rssi, threat_score
        FROM detections
        WHERE timestamp > datetime('now', ?)
    """
    params = [f"-{days} days"]
    
    if device_type:
        query += " AND device_type LIKE ?"
        params.append(f"%{device_type}%")
    
    query += " ORDER BY timestamp DESC LIMIT 20"
    
    cursor.execute(query, params)
    results = cursor.fetchall()
    conn.close()
    
    if not results:
        return "No detections found in the specified period"
    
    output = f"Found {len(results)} detections:\n"
    for row in results:
        output += f"- {row[0]}: {row[1]} ({row[2] or row[3]}) RSSI:{row[4]} Threat:{row[5]}\n"
    
    return output
```

---

## 8. Complete Implementation

### 8.1 Full Agent Example

```python
#!/usr/bin/env python3
"""Complete Signals Memory Agent with all integrations"""

from agno.agent import Agent
from agno.storage.sqlite import SqliteStorage
from agno.knowledge.lancedb import LanceDb
from agno.embedder.sentence_transformer import SentenceTransformerEmbedder

# Import custom LLM and tools
from llama_model import LlamaModel
from kismet_tools import get_wifi_devices, search_surveillance_devices, get_alerts
from detection_tools import log_detection, search_detection_history

# Initialize components
def create_signals_agent(user_id: str = "default") -> Agent:
    # Storage
    storage = SqliteStorage(
        table_name="agent_sessions",
        db_file="data/signals_agent.db"
    )
    
    # Knowledge base
    knowledge = LanceDb(
        table_name="signals_knowledge",
        uri="data/signals_kb",
        embedder=SentenceTransformerEmbedder(model="all-MiniLM-L6-v2")
    )
    
    # Local LLM
    model = LlamaModel(
        model_path="./models/lfm-2.5-1.2b-instruct-q4_k_m.gguf",
        n_ctx=4096,
        n_threads=4,
        temperature=0.7
    )
    
    # Create agent
    return Agent(
        name="signals-memory-agent",
        model=model,
        storage=storage,
        knowledge=knowledge,
        tools=[
            get_wifi_devices,
            search_surveillance_devices,
            get_alerts,
            log_detection,
            search_detection_history
        ],
        session_id=f"session-{user_id}",
        user_id=user_id,
        add_history_to_messages=True,
        num_history_responses=10,
        search_knowledge=True,
        num_documents=5,
        show_tool_calls=True,
        instructions=[
            "You are an expert signals detection assistant with persistent memory.",
            "Use tools to interact with Kismet and the detection database.",
            "Search knowledge base for technical details about devices.",
            "Be concise but thorough in responses.",
            "Log important detections when the user reports them."
        ]
    )

# Main loop
def main():
    print("🛰️ Signals Memory Agent")
    print("=" * 50)
    
    agent = create_signals_agent(user_id="default")
    
    while True:
        try:
            user_input = input("\n👤 You: ").strip()
            if not user_input:
                continue
            if user_input.lower() in ["quit", "exit", "q"]:
                print("Goodbye!")
                break
            
            response = agent.run(user_input)
            print(f"\n🔊 Agent: {response.content}")
            
        except KeyboardInterrupt:
            print("\nGoodbye!")
            break

if __name__ == "__main__":
    main()
```

---

## 9. Deployment

### 9.1 Docker Compose

```yaml
version: "3.8"

services:
  signals-agent:
    build: .
    volumes:
      - ./data:/app/data
      - ./models:/app/models
      - ./.signals:/app/.signals
    environment:
      - KISMET_API_KEY=${KISMET_API_KEY}
    ports:
      - "8080:8080"
    depends_on:
      - kismet
  
  kismet:
    image: kismetwireless/kismet
    privileged: true
    network_mode: host
    volumes:
      - ./kismet_data:/root/.kismet
```

### 9.2 Systemd Service

```ini
[Unit]
Description=Signals Memory Agent
After=network.target kismet.service

[Service]
Type=simple
User=signals
WorkingDirectory=/opt/signals-agent
ExecStart=/opt/signals-agent/venv/bin/python memory_agent.py
Restart=always
RestartSec=10
Environment=KISMET_API_KEY=your_key

[Install]
WantedBy=multi-user.target
```

---

## Quick Reference

### Key Imports

```python
from agno.agent import Agent
from agno.storage.sqlite import SqliteStorage
from agno.knowledge.lancedb import LanceDb
from agno.tools import tool
```

### Memory Flow

```
User Query → Session History (SQLite) → Knowledge Search (LanceDB)
                                              ↓
                              LFM 2.5 (reasoning + tools)
                                              ↓
                              Tool Execution (Kismet, DB)
                                              ↓
                              Response → Session Update
```

---

## Resources

- **Agno Documentation**: https://docs.agno.com
- **LanceDB**: https://lancedb.github.io/lancedb/
- **llama-cpp-python**: https://github.com/abetlen/llama-cpp-python
- **Sentence Transformers**: https://sbert.net

---

*Document Version: 1.0 | Created: 2026-02-06 | Part of ainish-coder signals detection suite*
