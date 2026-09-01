# TASK.2026-09-01.skills-sync-prompt-and-safety

**Branch:** `feat/skills-sync-tools` (worktree `../skills-sync-tools`, from `main` @ `d37733c`)

## Objective
1. Skills Sync Source Deletion Safety:
   - Guarantee that `ainish-coder --skills-sync` NEVER removes or deletes any tools or skills from `ainish-coder` repository root (`.agents/skills/`).
2. Candidate Skill Ingestion Selection & Prompts (`src/verify_skills.sh`):
   - When external or upstream skills are detected at a target repository:
     - In interactive mode, display detected candidate skills and prompt the operator to confirm/select which skills to add or update into `ainish-coder`.
     - Supports individual item selection, full approval, or skipping.
     - In `--headless` mode, automatically ingests candidate skills without prompts.
3. Documentation Updates:
   - Document source deletion safety and ingestion selection prompts in `AGENTS.md`, `src/templates/AGENTS.md`, `src/templates/AGENTS.deployed.md`, `AGENTS.deployed.md`, and `llms.txt`.

## Verification
- Automated test suite verifying specific skill selection, full confirmation, and preservation of all source skills in `mock_source`.
- Security gate (Zero-Trust and PQC compliance) passed with 0 violations.
