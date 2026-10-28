# TASK — Latest CLI and rules distribution

- **Date:** 2026-10-28
- **Branch:** `chore/install-latest-rules-distribution`
- **Worktree:** `/Users/nbiish/code/ainish-latest-rules`
- **Triage:** now
- **Status:** verifying

## Scope

Sync `origin/main`, repair CLI startup line endings, install the canonical CLI, refresh `AGENTS.md` in existing configured repositories with `--agents`, and configure a local post-merge refresh with backups.

## Constraints

Preserve the pre-existing local ledger edit and WorkBuddy memory. Do not overwrite target rules without backup. Do not deploy skills or `.gitignore` changes in this task. No secrets in task or coordination records.

## Verification

- `bash -n` on changed shell entrypoints
- `ainish-coder --version` and `--help`
- `python3 bin/security_gate.py`
- Byte-compare every deployed target `AGENTS.md` with canonical root
- Verify post-merge hook and target sync script syntax
