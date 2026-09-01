# TASK.2026-09-01.tts-cli-agents-integration

**Branch:** `feat/tts-cli-agents-integration` (worktree `../tts-cli-agents-integration`, from `main`)

## Objective
1. Integrate the authoritative `tts-cli` skill contract from `~/code-external/tts-cli/AGENTS.md` and `~/code-external/tts-cli/.agents/skills/tts-cli/SKILL.md` into `ainish-coder/.agents/skills/tts-cli/SKILL.md`:
   - Six deterministic production/security chairs:
     - `What would this adversarial / security master suggest? <one sentence>`
     - `What would this privacy / data-protection regulatory master suggest? <one sentence>`
     - `What would this supply-chain / third-party-risk master suggest? <one sentence>`
     - `What would this systems-architecture / devops / infrastructure master suggest? <one sentence>`
     - `What would this reliability / verification master suggest? <one sentence>`
     - `What would this governance / sovereignty master suggest? <one sentence>`
   - Three custom task-specific slash chairs:
     - `What would this ___ / ___ master suggest? <one sentence>`
     - `What would this ___ / ___ master suggest? <one sentence>`
     - `What would this ___ / ___ master suggest? <one sentence>`
   - Total = 9 master answers following the fused `Next step:` order.
2. Update `src/verify_skills.sh` so `_ainish_skill_identical` and mtime comparisons ignore cache artifacts (`__pycache__`, `*.pyc`, `.DS_Store`) during byte-identity checks and syncs.
3. Test two-way skills sync against `~/code-external/tts-cli` to verify byte-identity across all vendored skills.

## Verification
- `ainish-coder --skills-verify ~/code-external/tts-cli` reports byte-identical for all shared skills (`code-security`, `llm-security`, `pqc-secrets`, `pqc-signatures-security`, `production-security`, `tts-cli`).
- `cli-tts --prompt` works with the exact 9-chair structure.
- Pre-commit secret checks pass with 0 violations.
