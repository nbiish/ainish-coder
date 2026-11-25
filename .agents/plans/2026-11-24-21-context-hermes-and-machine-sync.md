---
plan_format: ainish/plan/v1
slug: context-hermes-and-machine-sync
date: 2026-11-24
status: done
branch: feat/context-hermes-sync
worktree: D:/Code/ainish-coder-worktrees/feat-context-hermes-sync
task_record: .agents/tasks/2026-11-24-21-context-hermes-and-machine-sync.md
operator: question-me
---

# Plan: Self-Improving Hermes Context Agents, `--context-setup`, and `--machine-sync` Parity

## 1. Objective

1. Move prime `ainish-coder --context` Elephant & Goldfish agents onto dedicated, self-improving Hermes profiles (`context-elephant`, `context-goldfish`) routed through `local-router/fallback-models`, with `pi` and direct `DriverEngine` HTTP as explicit degraded fallbacks.
2. Ship zero-secret portable profile blueprints (`config/context-agents/`) and `ainish-coder --context-setup` / `ainish-context context-setup` to bootstrap/sync all 6 profiles (`context-*` + `consolidate-*`) and `~/.pi/agent/models.json` identically across macOS, Windows, and Linux.
3. Fix Goldfish error-masking, `ainish-context secrets` role reporting, `bin/ainish-context` unnecessary `cryptography` uv install on read-only `--context` calls, and stale `rag.py` test paths.
4. Refine `--machine-sync` with cross-OS UTC timestamp formatting in `--latest`, honest SSH-vs-missing-repo peer probing, and `ainish-coder --machine-sync --doctor [--json]`.

## 2. Threat Model & Constraints

- **Assets:** PQC secrets bundle (`~/.config/pqc-secrets/secrets.bundle.json`), `.agents/` coordination history, canonical signed `AGENTS.md`, and operator execution authority.
- **Controls:**
  - Zero secrets in `config/context-agents/**`, profile blueprints, or tests (loopback placeholder `"local-router"` only against `validate_loopback_host`-validated URLs).
  - Context profiles (`context-elephant`, `context-goldfish`) run strictly toolless (`platform_toolsets.cli: []`, `--max-turns 1`, `-Q`, `--oneshot`, `--source tool`, `--format stream-json`, UTF-8 stdin via `--query-file -`) in isolated profile directories.
  - Goldfish never sees Elephant's profile, memories (`memory_enabled: false`, `user_profile_enabled: false`), or session sidecar; `goldfish_review`'s signature stays unchanged.
  - `AGENTS.md` (159/160 lines) and `LICENSE` are untouched. `DRIVER_CHAIN` stays intact.

## 3. Verification

- `py -3 -m unittest discover -s src/context/tests -p "test_*.py"`
- `bash scripts/test-machine-sync.sh`
- `bash scripts/test-pqc-dist.sh`
- `bin/ainish-context gate --summary`
- Live end-to-end smokes: `--context-setup`, `--context`, `secrets`, `--machine-sync --latest`, `--machine-sync --doctor`
