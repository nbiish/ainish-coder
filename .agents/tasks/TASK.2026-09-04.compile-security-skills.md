# TASK.2026-09-04 — compile security standards into skills

PRD anchor read. Worktree feat/skills-compile-security-specs from main.
Operator directive: AGENTS_LLM_SECURITY.md and AGENTS_CODE_SECURITY.md compiled into respective .agents/skills/.
Conforms to singular AGENTS.md document model (no extra AGENTS_* in root).
AGENTS_LLM_SECURITY.md compiled to .agents/skills/llm-security/references/production-standards.md (+ AGENTS_LLM_SECURITY.md alias).
AGENTS_CODE_SECURITY.md compiled to .agents/skills/code-security/references/production-standards.md (+ AGENTS_CODE_SECURITY.md alias).
llm-security/SKILL.md & code-security/SKILL.md updated with production standards references.
bin/ainish-coder: --secure updated to deploy from skill packages with fallback.
src/help.sh: updated --secure documentation.
Root AGENTS_CODE_SECURITY.md & AGENTS_LLM_SECURITY.md retired from repo root.
Verification: bash -n bin/ainish-coder & src/help.sh PASS.
security_gate.py PASS (Zero-Trust/PQC compliance).
gitnexus detect-changes --repo ainish-coder PASS (no code symbol regression).
ainish-coder --secure smoke test to /tmp target PASS (clean file deployment).

####
Compiled root security standards into respective .agents/skills/; updated CLI deployment; ready to merge.
