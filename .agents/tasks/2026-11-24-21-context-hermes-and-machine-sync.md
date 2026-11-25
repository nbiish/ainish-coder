# Task: Self-Improving Hermes Context Agents, `--context-setup`, and `--machine-sync` Parity

- lane: now
- branch: `feat/context-hermes-sync`
- worktree: `D:/Code/ainish-coder-worktrees/feat-context-hermes-sync`
- status: done
- plan: `.agents/plans/2026-11-24-21-context-hermes-and-machine-sync.md`
- scope: `config/context-agents/**`, `src/context/engine.py`, `src/context/tests/*.py`, `bin/ainish-coder`, `bin/ainish-context`, `src/help.sh`, `src/machine_sync.sh`, `scripts/consolidation-skills/README.md`, `scripts/test-machine-sync.sh`, `llms.txt`
- objective: Bootstrap and run self-improving Hermes `context-elephant` and `context-goldfish` profiles via `local-router` across machines, keep `pi`/HTTP as explicit degraded fallbacks, fix `bin/ainish-context` and diagnostics, and add `--machine-sync --doctor` + cross-OS `--latest` formatting.

## Verification & Closeout Evidence (2026-11-25)

- `bash -n bin/ainish-context bin/ainish-coder src/machine_sync.sh src/help.sh`: pass (exit 0)
- `bash scripts/test-machine-sync.sh`: **63 passed, 0 failed** (including section 18 Windows UTC formatting, missing-repo `--machine-link` hint, and `--machine-sync --doctor --json`)
- `py -3 -m unittest test_context_injection.HermesContextRuntimeTest test_context_injection.GoldfishIsolationTest -v`: **10 passed, 0 failed** (full `unittest discover`: 145/151 pass; 6 pre-existing baseline/Windows failures in `test_wiki_graph.py`, `test_gate_ready.py`, `RoleModelSeparationTest` previously hidden behind deleted `rag.py`)
- `bash scripts/test-pqc-dist.sh`: **442 passed, 3 failed** (3 pre-existing baseline checks unrelated to diff; `AGENTS.md` and `LICENSE` untouched)
- `bin/ainish-context --context-setup`: created/updated 6 Hermes profiles (`C:\Users\kenwa\AppData\Local\hermes\profiles\{context-*,consolidate-*}`), restored `http://127.0.0.1:11434/v1` in root `config.yaml`, and wired `C:\Users\kenwa\.pi\agent\models.json`
- `pi --list-models`: lists `local-router/fallback-models`
- `bin/ainish-coder --context "smoke_verify..." --json`: served `hermes:context-elephant` and 3-step `hermes:context-goldfish` via `:11434`
- `bin/ainish-coder --machine-sync --doctor`: verified `mac-18gb` SSH reachable, both Windows links (`D:/Code/ainish-coder`, `D:/Workspace/local-router` -> `mac-18gb`), `6/6` Hermes profiles, `pi` `models.json`, and `:11434` online (`wsl-94gb` SSH unreachable -> exit 1 as expected)
- Paired `local-router` PR: `https://github.com/nbiish/local-router/pull/21` (`node bin/agents-doctor.js` confirms `6/6 ctx profiles` and `pi: present`)
