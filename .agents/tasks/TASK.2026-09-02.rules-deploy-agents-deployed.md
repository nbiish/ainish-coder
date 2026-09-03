# TASK.2026-09-02 — Ensure `AGENTS.deployed.md` is deployed as target `AGENTS.md`

## Problem Statement

When running `ainish-coder --rules [target_dir]` (or `ainish-coder --agents`), the user expects the canonical `AGENTS.deployed.md` (which contains the streamlined, project-agnostic rules document) to be copied directly as the target's `AGENTS.md` (`cp AGENTS.deployed.md ${cwd}/AGENTS.md`).

However:
1. `src/deploy_agents.sh` had `local source="${REPO_DIR}/src/templates/AGENTS.deployed.md"`, which checked `src/templates/` before root `AGENTS.deployed.md`.
2. `src/templates/AGENTS.deployed.md` had diverged from root `AGENTS.deployed.md` (it retained the old 418-line, 32KB version, whereas root `AGENTS.deployed.md` was condensed to 220 lines).
3. The prompt in `bin/ainish-coder` and `src/deploy_agents.sh` said `Deploying AGENTS.md`, making it ambiguous whether `AGENTS.md` (maintainer contract) or `AGENTS.deployed.md` (distributed rules) was being deployed.

## Operator Intent (P3)

- `AGENTS.md` in `ainish-coder` is the repository maintainer contract and is never distributed.
- `AGENTS.deployed.md` is the file that goes to target repos as their `AGENTS.md` (`cp AGENTS.deployed.md ${cwd}/AGENTS.md`).
- `src/deploy_agents.sh` must resolve `${REPO_DIR}/AGENTS.deployed.md` as primary source.
- `src/templates/AGENTS.deployed.md` must be kept 100% byte-identical to `AGENTS.deployed.md`.
- Status messages and confirmation prompts must clearly indicate that `AGENTS.deployed.md` is deployed as `AGENTS.md`.

## Implementation Tasks

1. **Source Resolution in `src/deploy_agents.sh`**:
   - In `deploy_agents()`: Set `source="${REPO_DIR}/AGENTS.deployed.md"`, fallback to `${REPO_DIR}/src/templates/AGENTS.deployed.md`.
   - In `deploy_agents_global()`: Set `source="${REPO_DIR}/AGENTS.deployed.md"`, fallback to `${REPO_DIR}/src/templates/AGENTS.deployed.md`.
   - Update log output: `Deploying AGENTS.deployed.md -> $dest`, `✓ Deployed AGENTS.deployed.md as $dest`.
2. **Template Byte Identity**:
   - Update `src/templates/AGENTS.deployed.md` to match `${REPO_DIR}/AGENTS.deployed.md` (100% byte-for-byte identical).
3. **CLI Messages in `bin/ainish-coder`**:
   - Clarify confirmation prompt: `"Deploy AGENTS.deployed.md as AGENTS.md (project-agnostic rules)?"`
4. **Documentation**:
   - Update `src/help.sh` descriptions.
   - Update `llms.txt` and `AGENTS.md` boundaries if needed.
5. **Verification**:
   - Verify non-interactive and interactive deployments copy exact content of `AGENTS.deployed.md` into target `AGENTS.md`.
   - Verify byte identity between `AGENTS.deployed.md` and `src/templates/AGENTS.deployed.md`.
   - Verify guard prevents overwriting inside `ainish-coder` checkout.
