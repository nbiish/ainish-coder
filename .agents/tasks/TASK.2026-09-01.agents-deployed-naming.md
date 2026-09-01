# TASK.2026-09-01.agents-deployed-naming

**Branch:** `chore/agents-deployed-naming` (worktree `../agents-deployed-naming`, from `main` @ `fe6f428`)

## Objective
1. Clear naming and contract distinction:
   - Root `AGENTS.md`: The singularly named maintainer contract for developing the `ainish-coder` repository.
   - `AGENTS.deployed.md` (and `src/templates/AGENTS.deployed.md`): Renamed from `AGENTS.maintainer.md` to represent the project-agnostic rules document distributed to target repositories.
2. Rewire `src/deploy_agents.sh`, `bin/ainish-coder`, and `src/help.sh` to deploy and reference `AGENTS.deployed.md`.
3. Two-way Skills Sync & Auto-Ingestion (`src/verify_skills.sh`):
   - `ainish-coder --skills-sync` performs bidirectional synchronization.
   - Automatically ingests new skills created in external target repositories (such as `tts-cli`, `wtf-is-going-on-mcp`) into `ainish-coder/.agents/skills/`.
   - Pulls newer upstream versions of existing skills from target repositories into `ainish-coder`.
   - Deploys missing or updated ainish-managed skills to target repositories per persisted selection.
   - Leaves byte-identical skills untouched and preserves scroll-channel exclusions.
4. Update `llms.txt` and `AGENTS.md` documentation boundaries and skill verify sections.

## Verification
- Automated test suite verifying two-way sync, ingestion of new skills into ainish-coder source, upstream update pulling, and downstream deployment.
- Deployed rules test asserting `AGENTS.deployed.md` is created and correctly configured.
- Security gate (Zero-Trust and PQC compliance) passed with 0 violations.
