# OSA Research & Implementation Plan: Signals Examples v2.0

**Objective**: Build a comprehensive, interactive voice agent that orchestrates
real-time alerts, data correlation insights, and continuous improvement workflows
for the Signals Intelligence system.

**Status**: ✅ v2.0 Implementation Complete (2026-02-08)

---

## 1. Evolution from v1.0

### v1.0 (Completed)

| Component | Capabilities |
|-----------|-------------|
| **memory_agent.py** | RAG (LanceDB), Isolation Forest anomaly detection, Kismet integration, OSA World State |
| **voice_assistant.py** | STT/TTS, acoustic forensics (FFT/impulse), LoRa control, basic Q&A |

### v2.0 (New — This Release)

| Component | File | Capabilities |
|-----------|------|-------------|
| **Alert Orchestrator** | `alert_orchestrator.py` | Proactive detection alerts, surveillance SSID monitoring, correlation cluster alerts, convergence milestones, Kismet IDS forwarding, cooldown/dedup, persistence |
| **Correlation Context** | `correlation_context.py` | LLM context injection from all 9 cluster types, convergence state, surveillance summary, world state, alert history, query-aware context selection |
| **Continuous Improvement** | `continuous_improvement.py` | Voice feedback parsing (18 patterns), false positive/confirmed threat handling, ignore list management, retraining reports, threshold adjustment |
| **Insight Engine** | `insight_engine.py` | Proactive analysis across 5 categories (ecosystem, security, behavioral, temporal, threat), voice briefings, topic-filtered insights |
| **Unified Voice Agent** | `unified_voice_agent.py` | Full orchestrator wiring all subsystems, command routing, text/voice modes, graceful degradation |

---

## 2. Architecture (OSA v2.0)

```
┌──────────────────────────────────────────────────────────────┐
│                  Unified Voice Agent v2.0                      │
│                                                                │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────────┐  │
│  │ AudioIO  │  │  LLM Engine  │  │  Alert Orchestrator    │  │
│  │ STT/TTS  │  │  (LFM 2.5)  │  │  (background monitor)  │  │
│  └────┬─────┘  └──────┬───────┘  └────────────┬───────────┘  │
│       │               │                        │               │
│  ┌────▼───────────────▼────────────────────────▼───────────┐  │
│  │              Command Router                              │  │
│  │  voice input → feedback? → command? → LLM query          │  │
│  └────┬──────────┬──────────┬──────────┬──────────┬────────┘  │
│       │          │          │          │          │             │
│  ┌────▼────┐ ┌───▼────┐ ┌──▼───┐ ┌───▼────┐ ┌──▼────────┐  │
│  │Feedback │ │Insight │ │Audio │ │Context │ │LoRa/SDR   │  │
│  │ Engine  │ │Engine  │ │Analy.│ │Inject. │ │Controller │  │
│  └─────────┘ └────────┘ └──────┘ └────────┘ └───────────┘  │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  Shared: WorldState, Kismet, AnomalyDetector, Correlator │ │
│  └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

### Data Flow

```
User Voice ──► STT ──► Command Router
                           │
                ┌──────────┼──────────┐
                ▼          ▼          ▼
           Feedback    Command    LLM Query
           Engine      Handler   + Context
                │          │          │
                ▼          ▼          ▼
           Update DB   Execute    Generate
           + World     Action     Response
           State                     │
                │          │         │
                └──────────┼─────────┘
                           ▼
                     TTS ──► Speaker

Background:
  AlertOrchestrator ──► poll Kismet + Correlator every 5s
                    ──► emit voice alerts with cooldown
```

---

## 3. Module Details

### A. Alert Orchestrator (`alert_orchestrator.py`)

**Purpose**: Proactive, real-time alert delivery from multiple sources.

| Feature | Implementation |
|---------|---------------|
| Surveillance SSID scan | Matches FLOCK, RAVEN, PENGUIN, FS EXT, SHOTSPOT, PIGVISION |
| Correlation cluster alerts | Monitors for new high-confidence clusters (>0.70) |
| Convergence milestones | Alerts at 50%, 90%, 100% convergence |
| Kismet IDS forwarding | Relays Kismet security alerts via voice |
| Cooldown management | 30s default cooldown prevents alert spam |
| Deduplication | SHA-256 alert IDs prevent repeat notifications |
| Persistence | Alert state survives restarts (JSON atomic write) |
| External listeners | Callback registration for WebSocket/logging |

### B. Correlation Context Injector (`correlation_context.py`)

**Purpose**: Enrich LLM prompts with full situational awareness.

| Context Section | Content |
|----------------|---------|
| `[CORRELATION]` | All 9 cluster types with counts and descriptions |
| `[CONVERGENCE]` | RSSI gap, step, WiFi/BT tolerance, convergence % |
| `[SURVEILLANCE]` | Surveillance-specific clusters with confidence and RSSI |
| `[WORLD STATE]` | OSA threats, environment, status |
| `[ALERTS]` | Recent alert summary with priority |
| `[KISMET]` | Connection status and device count |

Query-aware mode: only includes sections relevant to the user's question.

### C. Continuous Improvement (`continuous_improvement.py`)

**Purpose**: Closed-loop feedback from operator voice to model improvement.

| Feedback Type | Trigger Phrases | Action |
|--------------|----------------|--------|
| False Positive | "false positive", "that was wrong", "not a threat" | Add to ignore list, remove from world state |
| Confirmed Threat | "confirm threat", "this is a FLOCK", "definitely surveillance" | Add to threat DB, update world state |
| Reclassify | "actually a sensor", "reclassify as tracker" | Record correction for retraining |
| Ignore Device | "ignore this", "ignore that" | Add MAC to ignore list |
| Explanation | "why did you alert", "explain", "how did you know" | Generate evidence-based explanation |
| Threshold Adjust | "too many alerts", "more sensitive" | Record preference, adjust thresholds |

Retraining reports: aggregates feedback over configurable windows, computes
false positive rates by cluster type, and recommends threshold adjustments.

### D. Insight Engine (`insight_engine.py`)

**Purpose**: Proactive analysis and voice briefings.

| Category | Example Insights |
|----------|-----------------|
| **Ecosystem** | Cross-vendor clusters, cross-linked devices, vendor diversity, BT name groups |
| **Security** | MAC randomization effectiveness, PNL trackability, fingerprint defeats |
| **Behavioral** | Stationary vs. mobile, proximity analysis, persistent presence |
| **Temporal** | Convergence progress, session threat count, time-to-convergence |
| **Threat** | Surveillance density, closest device distance estimate, high-alert clusters |

### E. Unified Voice Agent (`unified_voice_agent.py`)

**Purpose**: Main orchestrator — wires all subsystems, runs the conversation loop.

Voice commands:
- `insights` / `briefing` — Proactive RF environment analysis
- `status` — Correlation and monitoring state
- `scan lora` — 915 MHz spectrum check
- `listen` / `analyze audio` — Acoustic forensics
- `report` — Feedback-driven improvement report
- `explain` — Why the last alert was triggered
- `alerts` — Recent alert summary
- `help` — List available commands
- `false positive` / `confirm threat` — Operator feedback
- Free-form questions — LLM with context injection

---

## 4. Integration with Correlation Engine

The v2.0 agent is designed to consume the full output of the
`SignalCorrelator` from `signals-correlation-engine.md`:

| Correlation Feature | Agent Usage |
|--------------------|-------------|
| 9 cluster types | Context injection, insight generation, alert prioritization |
| Confidence scores | Alert threshold (>0.70), insight filtering |
| RSSI convergence | Milestone alerts (50/90/100%), status reporting |
| PNL fingerprinting | Security insights about MAC randomization defeats |
| Cross-linking | Ecosystem insights about multi-radio devices |
| Evidence links | Explanation generation for operator queries |

A `StubCorrelator` is included for standalone testing. In production,
replace with the real `SignalCorrelator` instance.

---

## 5. Continuous Development Workflow

```
Operator Voice Feedback
        │
        ▼
┌───────────────────┐
│ Feedback Database │ ← SQLite: feedback, ignore_list, confirmed_threats
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Retraining Report │ ← Weekly: FP rate, cluster type analysis, recommendations
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Model Update      │ ← Retrain Isolation Forest with corrected labels
│ Threshold Adjust  │ ← Raise/lower confidence_threshold based on FP rate
│ Ignore List Sync  │ ← Propagate to Kismet/Correlator ignore lists
└───────────────────┘
```

---

## 6. File Inventory

| File | Lines | Purpose |
|------|-------|---------|
| `unified_voice_agent.py` | ~580 | Main orchestrator, CLI entry point |
| `alert_orchestrator.py` | ~400 | Background alert monitoring and delivery |
| `correlation_context.py` | ~340 | LLM context building from all subsystems |
| `continuous_improvement.py` | ~430 | Voice feedback parsing and CI/CD workflow |
| `insight_engine.py` | ~420 | Proactive insight generation (5 categories) |
| `voice_assistant.py` | ~370 | Original v1.0 voice assistant (preserved) |
| `memory_agent.py` | ~470 | Original v1.0 memory agent (preserved) |

---

## 7. Running

```bash
# Text mode (no microphone/speaker required)
uv run unified_voice_agent.py --text-mode

# Full voice mode
uv run unified_voice_agent.py

# Text mode without background alerts
uv run unified_voice_agent.py --text-mode --no-alerts

# Custom model path
uv run unified_voice_agent.py --text-mode --model ./models/my-model.gguf
```

---

## 8. Next Steps

1. **Production Correlator**: Replace `StubCorrelator` with real `SignalCorrelator` from Creeper Sweeper webapp
2. **LanceDB RAG**: Integrate `KnowledgeBase` from `memory_agent.py` into the unified agent for document-backed answers
3. **Wake Word**: Add Porcupine wake word detection ("hey signals") for hands-free operation
4. **WebSocket Bridge**: Emit alerts to the Creeper Sweeper dashboard via SocketIO
5. **Batch Retraining**: Automate weekly Isolation Forest retraining from feedback database
6. **ESP32 Edge**: Deploy acoustic analyzer to XIAO ESP32-S3 for distributed sensing
