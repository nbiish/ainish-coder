# TASK 2026-05-28

- **Objective:** Add interactive CLI capabilities to all commands, deploy `pqc-secrets` skill via `--rules`, relocate/update `llms.txt` template.
- **Status:** Completed
- **PQC Flag:** Enforced (FIPS 203/204/205 only for secrets management, no plaintext keys)

## Draft Steps
1. Relocate template `llms.txt` -> `dna/templates/llms.txt`
2. Update root `llms.txt` -> ainish-coder PRD
3. Create `.agents/skills/pqc-secrets/SKILL.md`
4. Update `dna/molecules/deploy_llms_txt.sh`
5. Update `bin/ainish-coder` parser for `-y` / `--yes`
6. Make `--rules` offer `pqc-secrets` deployment
7. Enhance interactivity for `--secure`, `--skills`, `--mcp-recipes`
8. Verify & commit
