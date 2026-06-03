# TASK — Sync pqc_helper.py hardening from local-router
Date: 2026-06-02
Branch: chore/sync-pqc-helper-from-local-router
Base: main @ 4ceed7a

## Plan
- Read local-router hardening commit
- Compare ainish-coder pqc_helper.py
- Identify divergence in run_command
- Apply sync via worktree
- Preserve user WIP in stash
- Commit + push
- Report to user

####

## Findings
- local-router hardened run_command: timeout, check, input_data
- Verify distinguishes 0=ok, 1=fail, else=error
- FileNotFoundError + TimeoutExpired handled
- ainish-coder pqc_helper.py is older, lacks hardening
- SKILL.md content already aligned
- User WIP stashed at stash@{0} on main

## Actions
- git stash push on main (preserve WIP)
- git worktree add chore/sync-pqc-helper-from-local-router
- cp hardened pqc_helper.py into worktree
- py_compile syntax check passed
- chmod +x preserved
- Record task in this file
- Commit + push

####

## Deliverables
1. `.agents/skills/pqc-signatures-security/scripts/pqc_helper.py` — hardened
2. `.agents/tasks/TASK.2026-06-02.sync-pqc-helper.md` — this record
3. Branch `chore/sync-pqc-helper-from-local-router` pushed to `origin`

## Audit
- No secrets in diff
- No banned crypto introduced
- ML-DSA-65 algorithm preserved
- OpenSSL pkeyutl unchanged
- Existing WIP untouched (stash@{0})
- SKILL.md untouched (already aligned)
