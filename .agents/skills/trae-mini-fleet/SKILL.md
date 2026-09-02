---
name: trae-mini-fleet
description: >
  Fleet orchestration of headless terminal coding agents (live-swe-agent and trae-agent)
  with the calling agent acting as the master orchestration agent. Sub-agents are configured
  under the Ollama endpoint (our local-router single config proxy/shim) using model
  local-router/fallback-models with per-dispatch git worktree isolation and verification gates.
---

# Trae-Mini Fleet — Headless Terminal Agent Orchestration

The calling AI agent acts as the **Master Orchestration Agent**, dispatching specialized headless terminal coding agents (`live-swe-agent` and `trae-agent`) to autonomously investigate, modify, and verify codebases. All fleet agents are configured under our unified **Ollama endpoint** proxy/shim (`http://localhost:11434/v1`), using the virtual routing model **`local-router/fallback-models`**.

---

## 1. Architecture Overview

```
Calling Agent (Master Orchestrator)
  │
  ├─ 1. Analyzes high-level task & decomposes into discrete, testable units
  ├─ 2. Creates isolated Git Worktree per dispatch (one dispatch = one worktree)
  ├─ 3. Selects optimal headless terminal agent:
  │      ├─ live-swe-agent  (interactive debugging, reproduction scripts, tool synthesis)
  │      └─ trae-agent      (AST code navigation, multi-file refactoring, patch extraction)
  │
  ├─ 4. Routes inference through Local-Router Single Config Proxy / Shim:
  │      Endpoint:  http://localhost:11434/v1  (Ollama endpoint)
  │      Model:     local-router/fallback-models
  │      (Handles 24-step fallback cascade, rate-limits, and provider auth transparently)
  │
  ├─ 5. Executes agent headlessly in worktree (non-interactive, batch mode)
  ├─ 6. Reviews git diff, trajectory logs, and runs quality verification gates
  └─ 7. Merges verified changes & cleans up worktree
```

---

## 2. Master Coding Terminal Agents

The fleet is comprised of two expert terminal-based coding engines:

### 1. Live-SWE-Agent (`mini` / `mini-live`)
- **Repository:** [https://github.com/OpenAutoCoder/live-swe-agent](https://github.com/OpenAutoCoder/live-swe-agent)
- **Installation Directive:** If live-swe-agent (or mini-swe-agent) is not installed on the system, clone and install it from https://github.com/OpenAutoCoder/live-swe-agent via `uv` or `pip` (e.g. `uv tool install mini-swe-agent` or `pip install -e .`).
- **Core Strengths:**
  - Dynamic tool synthesis: creates Python helper scripts on the fly to solve task-specific problems.
  - Test-driven problem reproduction: establishes reproduction scripts before making edits.
  - Step-by-step verification and autonomous bash feedback loop.
- **Headless Execution Pattern:**
  - Invoke non-interactively using `--yolo` and `--exit-immediately`.

### 2. Trae-Agent (`trae-cli`)
- **Repository:** [https://github.com/bytedance/trae-agent](https://github.com/bytedance/trae-agent)
- **Installation Directive:** If trae-agent is not installed on the system, clone and install it from https://github.com/bytedance/trae-agent via `uv` (e.g. `git clone https://github.com/bytedance/trae-agent.git && cd trae-agent && uv sync --all-extras && uv tool install .` or `pip install -e .`).
- **Core Strengths:**
  - ByteDance's LLM-driven software engineering agent.
  - Structural codebase exploration, AST symbol lookup, and repository-level issue resolution.
  - Clean patch generation (`--patch-path`) and trajectory tracking (`--trajectory-file`).
- **Headless Execution Pattern:**
  - Invoke non-interactively using `trae-cli run` with `--console-type simple`, specifying `-w <worktree>` and `--max-steps`.

---

## 3. Local-Router Single Config Proxy / Shim

All agents in the fleet connect exclusively through the **Ollama endpoint shim** hosted by `local-router`:

- **Endpoint URL:** `http://localhost:11434/v1` (OpenAI-compatible) or `http://localhost:11434` (Ollama native API).
- **Target Model:** `local-router/fallback-models`
- **Key / Auth:** `local-router` (or any non-empty bearer token; credentials are held upstream by the PQC bundle).

### Why the Local-Router Shim?
1. **Zero Subagent Multi-Provider Logic:** Terminal agents do not need complex multi-provider retry loops or hardcoded keys.
2. **24-Step Auto-Failover:** If a primary provider experiences rate-limiting, downtime, or context exhaustion, `local-router` seamlessly cascades (Ollama Cloud → NIM → Free-tier → Subscriptions → Paid API backstops).
3. **No Plaintext Secrets:** Sub-agents never touch raw API keys on disk or in command arguments; traffic routes through the local loopback proxy.

---

## 4. Headless Dispatch Specifications

### A. Dispatching Live-SWE-Agent (`mini` / `mini-live`)

Generate a temporary YAML configuration that binds LiteLLM to the local-router Ollama endpoint, then execute `mini`:

```bash
dispatch_live_swe_agent() {
    local task="$1"
    local workdir="${2:-$(pwd)}"
    local temp_config
    temp_config=$(mktemp /tmp/liveswe-config.XXXXXX.yaml)
    trap 'rm -f "$temp_config"' EXIT

    cat > "$temp_config" <<EOF
agent:
  mode: yolo
  step_limit: 30
  cost_limit: 0.0
model:
  model_name: "ollama/local-router/fallback-models"
  model_kwargs:
    api_base: "http://localhost:11434/v1"
    api_key: "local-router"
    temperature: 0.0
    drop_params: true
environment:
  env:
    PAGER: cat
    MANPAGER: cat
    LESS: -R
    PIP_PROGRESS_BAR: "off"
    TQDM_DISABLE: "1"
EOF

    (
        cd "$workdir" || exit 1
        OPENAI_API_BASE="http://localhost:11434/v1" \
        OLLAMA_API_BASE="http://localhost:11434" \
        mini \
          --config "$temp_config" \
          --task "$task" \
          --yolo \
          --exit-immediately
    )
}
```

### B. Dispatching Trae-Agent (`trae-cli`)

Invoke `trae-cli run` pointing directly to the Ollama endpoint with the simple console:

```bash
dispatch_trae_agent() {
    local task="$1"
    local workdir="${2:-$(pwd)}"
    local patch_output="${workdir}/trae_solution.patch"
    local trajectory_output="${workdir}/trae_trajectory.json"

    trae-cli run "$task" \
      --provider openai \
      --model-base-url "http://localhost:11434/v1" \
      --model "local-router/fallback-models" \
      --api-key "local-router" \
      --working-dir "$workdir" \
      --max-steps 30 \
      --console-type simple \
      --patch-path "$patch_output" \
      --trajectory-file "$trajectory_output"
}
```

Alternatively, configure `trae_config.yaml` dynamically in the dispatch worktree:

```yaml
provider: "openai"
model: "local-router/fallback-models"
model_base_url: "http://localhost:11434/v1"
api_key: "local-router"
working_dir: "."
max_steps: 30
console_type: "simple"
```

---

## 5. Orchestration Workflow & Worktree Isolation

**Fundamental Rule: One dispatch = One isolated worktree.** Never run headless agents on the current working branch or directly on `main`.

```
Orchestrator Lifecycle:
┌────────────────────────────────────────────────────────┐
│ 1. Create task worktree:                               │
│    git worktree add -b feat/<slug> ../<slug> HEAD      │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│ 2. Select Agent & Dispatch Headlessly:                 │
│    - Bug / reproduction / test fix → live-swe-agent    │
│    - Feature / multi-file / refactor → trae-agent      │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│ 3. Orchestrator Inspection & Verification:             │
│    - git diff / git status in worktree                 │
│    - Verify patch compiles, tests pass, linter clean   │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│ 4. Integration & Worktree Cleanup:                     │
│    - Merge task branch into main branch after verify   │
│    - git worktree remove ../<slug>                     │
│    - git branch -d feat/<slug>                         │
└────────────────────────────────────────────────────────┘
```

### Agent Selection Matrix

| Task Characteristics | Recommended Agent | Rationale |
|----------------------|-------------------|-----------|
| Failing tests / bug reproduction | `live-swe-agent` | Creates reproduction script first; iterates until passing. |
| Complex algorithmic debugging | `live-swe-agent` | Dynamic tool synthesis allows writing custom Python debug probes. |
| Broad repo structure search & AST edits | `trae-agent` | Optimized for large codebase navigation and symbol resolution. |
| Clean patch generation for review | `trae-agent` | Native `--patch-path` exports standalone unified diffs. |
| Full-stack multi-file implementation | Trae → Live-SWE | Trae scaffolds architecture; Live-SWE verifies & hardens tests. |

---

## 6. Operational Guardrails

1. **Verify Endpoint Health First:** Before dispatching, ensure `local-router` is up on port 11434:
   ```bash
   curl -s http://localhost:11434/v1/models | grep -q "fallback-models" || echo "Warning: fallback-models not ready"
   ```
2. **Enforce Step Limits:** Always supply an explicit `--max-steps` (recommended 20–35) to prevent infinite loops.
3. **Headless Output Logging:** Redirect subagent stdout/stderr to `/tmp/<agent>-<slug>.log` so terminal traces can be reviewed without polluting the orchestrator context.
4. **Never Hardcode Secrets:** Let `local-router` handle authentication. Use `local-router` as the placeholder API key string.
5. **Clean Worktree State:** If a subagent dispatch fails or produces broken code, simply discard the worktree (`git worktree remove --force ../<slug>`) without harming the primary repository state.
