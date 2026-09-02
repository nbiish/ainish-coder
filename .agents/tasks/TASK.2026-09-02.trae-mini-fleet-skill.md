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

## Architecture & Integration
- **Orchestration Agent**: Calling agent evaluates issues, scaffolds worktrees, assigns tasks, verifies patches, runs tests, and integrates code.
- **Headless Terminal Agents**:
  - `mini` / `mini-live` with `livesweagent.yaml` configuration.
  - `trae-cli run` with `--config-file` or command line options.
- **Local-Router Shim**: Single Ollama-compatible endpoint proxying model `local-router/fallback-models`. No per-agent multi-provider complexity.
