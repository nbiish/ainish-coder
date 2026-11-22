---
branch: chore/federation-profile-cleanup
status: ready
---

# Plan: decouple hermes from --rules and federate the tool repo bidirectionally

## Decisions (operator)

- Re-clone Windows `ainish-coder` from Mac (backup Windows first; 915 Windows-only commits preserved in backup only).
- Unlink `local-router` from the watcher federation; link `ainish-coder` to `windows-128gb` at `D:/Code/ainish-coder`.
- Stop `--rules` from creating hermes profiles; keep `--context` profile usage.

## Steps

1. Remove `_ainish_rules_provision_consolidation_profiles()` and its call from `src/deploy_rules_sync.sh`.
2. Backup and edit `~/.config/ainish-coder/links.txt`: drop `local-router`, add `ainish-coder`.
3. Backup Windows checkout, re-clone from Mac, re-deploy rules there.
4. Verify bidirectional `--both` sync; commit, push, PR and merge all tooling.

## Verification

- Dist suite 441/441, gate GREEN, rules-status clean.
- Both machines share history; a Windows-side commit arrives on Mac.
