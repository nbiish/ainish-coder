# Task: Remove Legacy --skills Command in Favor of --skills-sync

- Date: 2026-09-10
- Branch: chore/cli-remove-skills-command
- Status: closed
- Scope: bin/ainish-coder, src/help.sh, src/skills_selection.sh, src/deploy_skills.sh, src/verify_skills.sh, src/templates/AGENTS.COMMS.md, llms.txt, README.md

## Objective
Remove the legacy `--skills` command from `ainish-coder` to keep the tooling concise, direct, and unambiguous:
- `ainish-coder --rules [DIR]` handles deployment of skills target-ward (along with AGENTS.md, .gitignore, and comms).
- `ainish-coder --skills-sync [DIR]` handles bidirectional synchronization and interactive candidate skill ingestion.

## Changes Completed
1. `bin/ainish-coder`: Removed the `--skills` case and folded interactive symlink confirmation directly into `--skills-sync`.
2. `src/help.sh`: Removed `--skills` command description, updated options, notes, and examples to feature `--skills-sync`.
3. `src/skills_selection.sh`, `src/deploy_skills.sh`, `src/verify_skills.sh`, `src/templates/AGENTS.COMMS.md`: Updated comments, guidance, and status strings to reference `--skills-sync`.
4. `llms.txt`: Updated documentation and contract boundaries to reflect `--skills-sync` as the sole synchronization command.
5. `README.md`: Updated all CLI examples and usage telemetry to `--skills-sync`.
6. Verified with `bash -n`, `ainish-coder --help`, and `bin/security_gate.py`.
