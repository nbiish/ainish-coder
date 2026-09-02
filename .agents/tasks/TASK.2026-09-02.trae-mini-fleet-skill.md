# TASK.2026-09-02.trae-mini-fleet-skill

**Branch:** `feat/skills-trae-mini-fleet` (worktree `../trae-mini-fleet`, from `main`)

## Operator Contract
1. Upgrade `pi-mini-orchestrator` skill to `trae-mini-fleet`.
2. Expert execution of terminal headless-based agents: calling agent acts as orchestration agent calling master coding terminal agents:
   - `live-swe-agent`: https://github.com/OpenAutoCoder/live-swe-agent
   - `trae-agent`: https://github.com/bytedance/trae-agent
3. Both agents configured under the Ollama endpoint (`http://localhost:11434/v1` or `http://127.0.0.1:11434`) representing our `local-router` single config proxy/shim with the `local-router/fallback-models` model.
4. Holds a single-sentence installation directive line for each repository if not on the system.
5. Update all references in `README.md`, `src/help.sh`, and `.agents/skills/gstack-coder/SKILL.md`.


## Phase 2: Expert Harness Documentation & Governing Contracts
- Documented expert harness playbook in `.agents/skills/trae-mini-fleet/SKILL.md`:
  - Resolved `trae-cli` binary identity vs non-existent `trae-agent` command.
  - Formulated robust task file dispatch pattern (`-f <task_file>`).
  - Added 7-phase operational playbook (pre-flight, worktree scaffold, framing, non-blocking dispatch, patch triage, autonomous recovery, cleanup).
  - Outlined common pitfalls and headless guardrails.
- Added `<FLEET>` section and `<TASK_PRIMER>` entries to `AGENTS.md` (repo-internal contract).
- Added `<FLEET>` section and `<TASK_PRIMER>` entries to `AGENTS.deployed.md` and `src/templates/AGENTS.deployed.md` (project-agnostic contract).

