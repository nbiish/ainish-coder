# TASK.20260528 — Rules Global Symlink & CLI Help Verification

## Objective
- Ensure `ainish-coder --rules` symlinks AGENTS.md to `~/.agents/AGENTS.md` and `~/.config/AGENTS.md`
- Verify `ainish-coder --help` accurately documents all headless commands
- Smoke-test headless commands against help docs

## Status
- [x] Investigate current `--rules` implementation — global symlinks were missing
- [x] Add global symlink logic for AGENTS.md via `deploy_agents_global()`
- [x] Update `--help` text: documented global symlinks, fixed skill count (21→19), removed nonexistent `osa`/`pi` entries, added ENVIRONMENT VARIABLES section, fixed version to v1.5.1
- [x] Smoke-test commands: `--rules -y`, `--agents -y`, `--gitignore -y`, `--llms-txt -y`, `--skills -y`, `--secure -y`, `--critical -y`, `--version`, `--help`
- [x] Audit for secrets/crypto violations — none found

## PQC Flag
- No secrets touched. No crypto changes. Safe.
