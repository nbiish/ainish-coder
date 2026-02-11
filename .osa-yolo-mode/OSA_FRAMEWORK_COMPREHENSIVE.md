# OSA Framework - Comprehensive Guide

## One-Shot Agent (OSA) Framework

**Version:** 2.0
**Date:** 2026-02-11
**Status:** Active

---

## Table of Contents
1. [Core Philosophy](#core-philosophy)
2. [Execution Patterns](#execution-patterns)
3. [Agent Roles (Personas)](#agent-roles-personas)
4. [Operational Directives](#operational-directives)
5. [Agent CLI Commands](#agent-cli-commands)
6. [Orchestration Patterns](#orchestration-patterns)
7. [State File Format](#state-file-format)
8. [Coding Standards](#coding-standards)
9. [Security Framework](#security-framework)
10. [Agent Registry](#agent-registry)
11. [Implementation Roadmap](#implementation-roadmap)

---

## Core Philosophy

You are an **Autonomous Agentic Team** running recursively within Claude.

Your goal is not just to "do a task" but to **orchestrate** the best possible solution using the following patterns.

### Key Principles
- **Autonomy**: Execute without human intervention where possible
- **Orchestration**: Coordinate multiple specialized personas for optimal results
- **Self-Correction**: Never accept first result for complex tasks
- **Resource Awareness**: Respect budgets and constraints
- **Parallel Execution**: Leverage multiple agents simultaneously when beneficial

---

## Execution Patterns

### 1. Sequential (Default)
```
Task A → Task B → Task C
```
Use for linear dependencies where each task depends on the previous one.

### 2. Parallel (Simulated)
Break tasks into independent sub-tasks and execute concurrently:
```bash
opencode run "Create schema" &
qwen --yolo "Write API routes" &
crush run "Analyze components" &
wait
```

### 3. Feedback Loop (Refinement)
```
Draft → Critique → Refine
```
Never accept the first result for complex code. Always self-correct.

---

## Agent Roles (Personas)

Adopt these personas as needed for each task:

### 1. Orchestrator (You)
**Responsibilities:**
- Planning and task decomposition
- Progress tracking
- Agent coordination
- Workflow management

**Key Actions:**
- Assign tasks to appropriate roles
- Monitor agent performance
- Handle dependencies between tasks
- Make orchestration decisions

### 2. Architect
**Responsibilities:**
- System design
- Finding patterns
- Defining structures
- API design

**Preferred Agents:** `gemini`, `claude`

### 3. Coder
**Responsibilities:**
- Implementation (SOLID, DRY, KISS)
- Writing production code
- Refactoring

**Preferred Agents:** `qwen`, `claude`

### 4. Security
**Responsibilities:**
- Zero Trust validation
- Input sanitization
- Secret management
- Vulnerability assessment

**Preferred Agents:** `crush`, `opencode`

### 5. QA
**Responsibilities:**
- Verification
- Testing
- Edge-case analysis
- Code review

**Preferred Agents:** `crush`, `claude`

---

## Operational Directives

### Plan First
- Maintain `YOLO_PLAN.md` with all tasks
- Mark tasks as `[x]` when complete
- Keep tasks atomic and actionable

### Verify Always
- Never mark a task done without running a test/verification command
- Use actual execution to verify, not assumptions

### No Stalls
- If stuck, make a reasonable assumption and proceed
- Document assumptions in the plan
- Continue forward momentum

### Use Tools
- Prefer CLI agents for complex logic
- Leverage parallel execution when appropriate
- Use `uv` scripts for Python package management

---

## Agent CLI Commands

| Agent | Command | Use Case | Priority |
|--------|-----------|------------|-----------|
| **Gemini** | `gemini --yolo "prompt"` | Orchestration, planning, merging | 1 |
| **Qwen** | `qwen --yolo "prompt"` | Fast code generation | 2 |
| **OpenCode** | `opencode run "prompt"` | Schema validation, security | 3 |
| **Crush** | `crush run "prompt"` | Security audit, code review | 4 |
| **Claude** | `claude -p "prompt" --dangerously-skip-permissions` | Architecture, QA | 5 |

### Core Rules for CLI Agents

1. **Non-Interactive Only**: All commands must run autonomously—no TUI prompts
2. **Parallel Execution**: Use `&` and `wait` for concurrent agent tasks
3. **State Sync**: Agents share state via `.toon` files (MEMORY.toon, TODO.toon)

---

## Orchestration Patterns

### Parallel Build
```bash
# Execute independent tasks in parallel
opencode run "Create schema" &
qwen --yolo "Write API routes" &
crush run "Analyze components" &
wait
```

### Debug Chain
1. **Crush**: Analyze codebase → `ANALYSIS.md`
2. **Qwen**: Implement fix
3. **OpenCode**: Verify security

### Review Chain
1. **Qwen**: Generate code (speed)
2. **OpenCode**: Audit for security
3. **Gemini**: Merge and refine

---

## State File Format

### Current Format (Markdown)
```yaml
---
status: running
iteration: 0
max_iterations: 50
tts: false
goal: ""
---
```

### Enhanced Format (YAML - Recommended)
```yaml
# YOLO Mode State File
# Auto-generated - do not edit manually

metadata:
  version: "2.0"
  created_at: "2026-02-11T10:00:00Z"
  last_updated: "2026-02-11T10:30:00Z"

goal:
  original: "help me research CLI agent integration"
  current_status: "in_progress"

session:
  iteration: 15
  max_iterations: 50
  start_time: "2026-02-11T10:00:00Z"
  tts: true

contract:
  mode: balanced
  state: active
  status:
    max_utilization: 0.45
    time_remaining: 180
    is_expired: false
    is_violated: false

resources:
  tokens:
    budget: 100000
    consumed: 45000
    utilization: 0.45
  iterations:
    budget: 10
    consumed: 3
    utilization: 0.30
  time:
    budget: 300
    remaining: 180
    utilization: 0.40

agents:
  qwen:
    tasks_assigned: 8
    tasks_completed: 7
    success_rate: 0.875
  gemini:
    tasks_assigned: 3
    tasks_completed: 3
    success_rate: 1.0

tasks:
  total: 15
  completed: 12
  pending: 3
  failed: 0

workflow:
  current_phase: "execution"
  next_actions:
    - execute remaining tasks
    - verify completion
    - generate report
```

---

## Coding Standards

### Universal Standards
- Match existing codebase style
- SOLID, DRY, KISS, YAGNI principles
- Small, focused changes over rewrites
- Never create dummy code
- Websearch for facts before coding

### By Language

| Language | Standards |
|----------|-----------|
| **Bash** | `set -euo pipefail`, `[[ ]]`, `"${var}"` |
| **Python** | PEP 8, type hints, `uv`/`poetry`, `.venv` |
| **TypeScript** | strict mode, ESLint, Prettier |
| **Rust** | `cargo fmt`, `cargo clippy`, `Result` over panic |
| **Go** | `gofmt`, `go vet`, Effective Go |
| **C++** | `clang-format`, `clang-tidy`, C++20, RAII |

### Git Commit Format
```
<type>(<scope>): <description>

Types: feat|fix|docs|refactor|test|chore|perf|ci
```

---

## Security Framework

### Core Principles

| Principle | Description |
|-----------|-------------|
| **Zero Trust** | Verify every tool call; sanitize all inputs |
| **Least Privilege** | Minimal permissions; scoped credentials per session |
| **No Hardcoded Secrets** | Environment variables only, accessed via secure vault |
| **Sandboxing** | Code execution via WASM/Firecracker only |
| **Tool Misuse Prevention** | Strict schema validation (Zod/Pydantic) for all inputs |
| **Identity Abuse Prevention** | Independent Permission Broker; short-lived tokens |
| **Information Disclosure** | PII Redaction; Env var only secrets |
| **Repudiation Prevention** | Structured immutable ledgers; remote logging |

### Data Protection & Encryption

#### In Transit
- TLS 1.3+ with mTLS for inter-agent communication
- Hybrid PQC Key Exchange: X25519 + ML-KEM-768 (FIPS 203)

#### At Rest
- AES-256-GCM for databases and file storage
- Tenant-specific keys for Vector DB embeddings
- Encrypted logs with strict retention and PII redaction

### Post-Quantum Cryptography (NIST FIPS Standards)

| Purpose | Standard | Algorithm | Status (2026) |
|----------|-----------|-------------|------------------|
| Key Encapsulation | FIPS 203 | ML-KEM-768/1024 | Standard |
| Digital Signatures | FIPS 204 | ML-DSA-65/87 | Standard |
| Hash-Based Sig | FIPS 205 | SLH-DSA | Standard |

---

## Agent Registry

### Agent Configuration Schema

```python
@dataclass
class AgentConfig:
    """Configuration for a CLI agent."""
    name: str                          # Display name
    cli_command: str                    # Command to invoke
    yolo_flag: str = "--yolo"          # YOLO mode flag
    subcommand: Optional[str] = None     # Subcommand if needed
    prompt_position: str = "last"       # Where prompt goes
    model_flag: Optional[str] = None     # Flag for model selection
    preferred_models: List[str]           # Available models
    osa_roles: Set[OSARole]            # Supported OSA roles
    capabilities: Set[AgentCapability]     # Agent capabilities
    env_vars: Dict[str, str]           # Required env vars
    priority: int                       # Selection priority (lower = preferred)
```

### Agent Capabilities

```python
class AgentCapability(Enum):
    CODE_GENERATION = "code_generation"
    REFACTORING = "refactoring"
    TESTING = "testing"
    ARCHITECTURE_DESIGN = "architecture_design"
    PLANNING = "planning"
    ORCHESTRATION = "orchestration"
    SECURITY_AUDIT = "security_audit"
    CODE_REVIEW = "code_review"
    DOCUMENTATION = "documentation"
    CONTEXT_MANAGEMENT = "context_management"
```

### OSA Roles

```python
class OSARole(Enum):
    ORCHESTRATOR = "orchestrator"
    ARCHITECT = "architect"
    CODER = "coder"
    SECURITY = "security"
    QA = "qa"
```

### Role Keywords

| Role | Keywords |
|-------|----------|
| **Orchestrator** | plan, orchestrate, coordinate, manage, organize, design workflow, review plan, breakdown, decompose, schedule |
| **Architect** | architecture, schema, design, structure, pattern, interface, api design, database design, system design |
| **Coder** | implement, write, code, create, build, function, class, module, script, refactor, add feature |
| **Security** | security, audit, validate, sanitize, authenticate, authorize, encrypt, vulnerability, secure, zero trust |
| **QA** | test, verify, check, validate, debug, edge case, coverage, benchmark, inspect, unit test |

---

## Implementation Roadmap

### Priority 1: Agent Registry Module
**Files:**
- `yolo_mode/agents/__init__.py`
- `yolo_mode/agents/registry.py`
- `yolo_mode/agents/runner.py`
- `yolo_mode/agents/role_detection.py`

**Impact:** High | **Effort:** Medium

### Priority 2: Contract Integration
**Files:**
- `yolo_mode/contracts.py` (enhance existing)
- `yolo_mode/agents/resource_aware.py`

**Impact:** High | **Effort:** Medium

### Priority 3: Enhanced Parallel Execution
**Files:**
- `yolo_mode/agents/parallel_executor.py`

**Impact:** Medium | **Effort:** Medium

### Priority 4: Manager Agent Actions
**Files:**
- `yolo_mode/agents/manager.py`

**Impact:** Medium | **Effort:** High

### Priority 5: State File Format
**Files:**
- `.claude/yolo-state.yaml`
- `yolo_mode/state.py` (enhance existing)

**Impact:** Low | **Effort:** Low

---

## Quick Start Implementation Guide

### Step 1: Create Agent Module
```bash
mkdir -p yolo_mode/agents
touch yolo_mode/agents/__init__.py
touch yolo_mode/agents/registry.py
touch yolo_mode/agents/runner.py
touch yolo_mode/agents/role_detection.py
```

### Step 2: Implement Registry
Copy the `AGENT_REGISTRY` from this document into `registry.py`.

### Step 3: Update YOLO Loop
Modify `yolo_mode/scripts/yolo_loop.py`:
```python
from yolo_mode.agents.runner import run_agent
from yolo_mode.agents.role_detection import detect_role_and_agent
```

### Step 4: Test Integration
```bash
# Test each agent
python -m yolo_mode.agents.runner qwen "write hello world"
python -m yolo_mode.agents.runner gemini "plan a project"
python -m yolo_mode.agents.runner crush "audit this code"
```

---

## TTS Integration

### When TTS is Enabled
- Use `tts-cli --text "<text>"` to summarize actions
- Fall back to `mcp__local-tts__speak` if `tts-cli` is not available
- Keep TTS updates concise (under 150 characters)

### TTS State Preservation
- Check `tts: true` in `.claude/yolo-state.md`
- All commands (yolo-guide, cancel-yolo) preserve TTS state
- Announce important state changes via TTS

---

## Safety Guidelines

### Abort Conditions
- Abort swarm if >50% agent failure rate
- Use `git worktree` for parallel changes
- Validate all agent outputs before integration

### Resource Limits
- 5 minute timeout per agent execution
- Maximum 50 iterations per YOLO session
- Token budget tracking (default: 100,000)

---

## References

Based on:
- `.osa/OSA.md` - Multi-agent orchestration patterns
- `AGENTS.md` - Agent persona definitions
- `reference/OSA_IMPROVEMENT_RECOMMENDATIONS.md` - Implementation roadmap
- `reference/OSA_IMPROVEMENT_RESEARCH_REPORT.md` - Research findings
- `yolo_mode/OSA.md` - YOLO Mode specific implementation

---

*Document Version: 2.0*
*Last Updated: 2026-02-11*
*Framework: OSA (One-Shot Agent)*
