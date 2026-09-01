# TASK.2026-09-01.agents-deployed-naming

**Branch:** `chore/agents-deployed-naming` (worktree `../agents-deployed-naming`, from `main` @ `fe6f428`)

## Objective
- Establish clear naming convention between maintainer repository contract and deployed rules:
  - Root `AGENTS.md`: The singularly named maintainer contract for developing the `ainish-coder` repository.
  - `AGENTS.deployed.md` (and `src/templates/AGENTS.deployed.md`): Renamed from `AGENTS.maintainer.md` to represent the project-agnostic rules document distributed to target repositories.
- Rewire `src/deploy_agents.sh`, `bin/ainish-coder`, and `src/help.sh` to deploy and reference `AGENTS.deployed.md`.
- Update `llms.txt` and `AGENTS.md` documentation boundaries.

## Verification
- End-to-end rules deployment verification asserting `AGENTS.deployed.md` is created and correctly configured.
- Security gate (Zero-Trust and PQC compliance) passed with 0 violations.
