# TASK.2026-09-01.agents-rules-distinction

**Branch:** `docs/agents-rules-distinction` (worktree `../agents-rules-distinction`, from `main` @ `8cdbe25`)

## Operator contract
1. Clean architectural separation between repository-specific governance and distributed templates:
   - Root `AGENTS.md`: Live, binding governing contract for developing the `ainish-coder` repository.
   - `src/templates/AGENTS.md`: Project-agnostic rules template distributed via `ainish-coder --rules` and `ainish-coder --agents`. Enforces universal PQC secrets, worktree isolation, task coordination, and security gates stripped of `ainish-coder` repo-internal artifacts.
   - `src/templates/AGENTS.maintainer.md` / `AGENTS.maintainer.md`: Frozen snapshot guiding refinement, updates, and documentation of target repositories.
   - `src/templates/llms.txt`: Project-agnostic DOX framework template deployed via `ainish-coder --llms-txt`.
   - `src/templates/AGENTS.COMMS.md`: Distributed protocol template for `AGENTS/{date}.COMMS.md`.
2. `src/deploy_agents.sh` updated to deploy from `src/templates/AGENTS.md` and `src/templates/AGENTS.maintainer.md`.
3. Root `llms.txt` and `AGENTS.md` updated to document the boundary.

## Verification
- Deployed rules test confirming `src/templates/AGENTS.md` and `src/templates/AGENTS.maintainer.md` deploy cleanly to a test directory.
- Security gate passed (Zero-Trust and PQC compliance).
