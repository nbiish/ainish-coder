# TASK.2026-09-02 — --rules/--agents deploy single governing AGENTS.md (from AGENTS.deployed.md)

## Problem

When running `ainish-coder --rules` (and `--agents`) on a target repository, the CLI currently deploys TWO documents:
1. `src/templates/AGENTS.md` → `<target>/AGENTS.md`
2. `src/templates/AGENTS.deployed.md` → `<target>/AGENTS.deployed.md`

This is incorrect and confusing for AI agents operating in the target repository:
- The operator wants ONLY the project-agnostic rules doc (`AGENTS.deployed.md`) deployed to target repositories.
- At the target repository calling location, the file must be named `AGENTS.md` (the universal AI rules entrypoint).
- No file named `AGENTS.deployed.md` should be deployed or left in the target repository.
- The `ainish-coder` repository's own maintainer `AGENTS.md` must be protected against overwriting.

## Operator intent (P3)

- Single governing rules document at target repositories: `<target>/AGENTS.md`.
- Content deployed is `src/templates/AGENTS.deployed.md` (the project-agnostic rules template).
- Name at target calling location is strictly `AGENTS.md`.
- Clean up / prune any redundant `AGENTS.deployed.md` at target if present from prior runs (while never touching `ainish-coder` checkout roots).

## Implementation Steps

1. `bin/ainish-coder`:
   - Under `--rules)`: Remove the `deploy_agents_deployed` call/prompt. Single prompt `confirm_action "Deploy AGENTS.md (project-agnostic rules)?" "y"` calling `_with_link_choice deploy_agents "$target_dir"`.
   - Under `--agents)`: Remove the `deploy_agents_deployed` call/prompt. Single prompt `confirm_action "Deploy AGENTS.md (project-agnostic rules)?" "y"` calling `_with_link_choice deploy_agents "$agents_dest"`.
2. `src/deploy_agents.sh`:
   - `deploy_agents()`: Source template is `${REPO_DIR}/src/templates/AGENTS.deployed.md` (fallback `${REPO_DIR}/AGENTS.deployed.md`). Destination is `$target_dir/AGENTS.md`.
   - Guard against overwriting maintainer `AGENTS.md` inside any `ainish-coder` checkout.
   - If `$target_dir/AGENTS.deployed.md` exists and target is not an `ainish-coder` checkout, remove/clean up the redundant file.
   - `deploy_agents_deployed()` and `deploy_agents_maintainer()` kept as backwards-compatible aliases pointing to `deploy_agents "$@"`.
   - `deploy_agents_global()`: Update global symlinks (`~/.agents/AGENTS.md`, `~/.config/AGENTS.md`) to point to `${REPO_DIR}/src/templates/AGENTS.deployed.md`.
3. `git rm src/templates/AGENTS.md`: Remove the duplicate/stale template.
4. Docs & Help:
   - Update `src/help.sh` descriptions of `--rules` and `--agents`.
   - Update `llms.txt` and `AGENTS.md` / `AGENTS.deployed.md` documentation boundaries.
   - Bump version if appropriate.
5. Verification:
   - Test `--rules <tmpdir> --headless` with skill selection. Verify exactly `<tmpdir>/AGENTS.md` exists and NO `AGENTS.deployed.md`.
   - Test `--agents <tmpdir> --headless`. Verify exactly `<tmpdir>/AGENTS.md` exists.
   - Test cleanup of existing `<tmpdir>/AGENTS.deployed.md`.
   - Test guard inside ainish-coder checkout to verify maintainer contract is preserved.
   - Test global symlinks.
