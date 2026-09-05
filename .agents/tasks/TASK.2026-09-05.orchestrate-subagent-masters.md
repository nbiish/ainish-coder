# TASK.2026-09-05 — Enhance trae-mini-fleet into orchestrate-subagent-masters

- date: 2026-09-05
- agent: dsh-orchestrator
- branch: feat/fleet-orchestrate-subagent-masters
- worktree: /mnt/d/Code/orchestrate-subagent-masters
- status: verifying

## Objective

Full-replacement evolution of the `trae-mini-fleet` skill pack into
`orchestrate-subagent-masters`: one universal subagent orchestration contract
covering ALL modalities (trae-cli, mini, native subagent, subagent_fork,
workflow, ralph) under master personas, expressed as concise terminal-command /
tool-call instructions — no Python tooling scripts.

## Operator Decisions

1. Architecture: **Full replacement** (rename/absorb; update every AGENTS.md reference).
2. Tooling: **No Python scripts** — strict concise terminal command instructions per agent.

## Changes

- `+ .agents/skills/orchestrate-subagent-masters/SKILL.md` — new universal contract:
  doctrine, 6-modality matrix (one command each), 4 canonical templates,
  terminal-native Dispatch Protocol v3 (preflight one-liner, timeout, scope
  check, scrub), exit taxonomy, handoff chains, COMMS receipts, guardrails.
- `+ .agents/skills/orchestrate-subagent-masters/MASTER-REFLECTIONS.txt` — reflections
  ledger migrated from `trae-mini-fleet/FLEET-SKILL-REFLECTIONS.txt`, header
  updated to all modalities; history preserved.
- `- .agents/skills/trae-mini-fleet/` — removed (SKILL.md absorbed; scripts
  `fleet_dispatch.py`, `fleet_doctor.py`, `scrub_task.py` retired per operator).
- `AGENTS.md` — `<FLEET>` rewritten: Subagent Master Fleet (Tier 3 + native
  modalities), terminal-native Dispatch Protocol v3 (no wrapper/doctor/receipt
  scripts; COMMS ledger = the receipt), taxonomy minus script-only code 70,
  templates pointer repathed; `<DOCUMENT_MODEL>`, frontmatter, `<AUDIT>` #7 updated.
- `llms.txt` — tooling wiring mention + Dispatch Protocol v3.
- `README.md` — skills table row + specification pointer.
- `src/help.sh` — skills list blurb.
- `.agents/skills/gstack-coder/SKILL.md` — 3 pairing references repathed.

## Gates

- [x] Zero stale `trae-mini-fleet` / `fleet_dispatch` / `fleet_doctor` / `scrub_task`
      references in live files (historical ledgers/tasks/TTS log intentionally untouched).
- [x] `bash -n src/help.sh` clean.
- [x] Skill pack count remains 23 (1 removed, 1 added).
- [x] No Python in new pack; no secrets/banned crypto introduced (markdown-only change).
- [x] Graph recon: docs + leaf-script removal; standalone CLIs with zero repo callers
      (grep-verified) — docs-only exemption per `<GRAPH>`, noted in COMMS.
- [ ] Operator merge confirmation (pending).
