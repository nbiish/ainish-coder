# TASK — Document application orchestration of PQC keys (from local-router)
Date: 2026-08-18
Branch: docs/pqc-app-orchestration
Base: develop @ 611935e

## Plan
- Extract PQC integration patterns from local-router
- Write application-orchestration reference doc
- Cross-link from SKILL.md section 5
- Commit + push branch
- Open PR to develop

####

## Findings
- local-router develop (9d275af) embeds pqc-secrets as runtime backend
- Skill covered CLI, MCP, schema, rotation, agent-integration
- No reference for app-owned key lifecycle mode
- WSL migration surfaced dispatch + timeout + ceremony lessons
- Config-UI set/unset flows through full-bundle repack

####

## Actions
- Worktree docs/pqc-app-orchestration off develop
- Wrote references/application-orchestration.md (255 lines)
- Added SKILL.md section 5 cross-link blockquote
- Recorded task in this file
- Commit + push
- Open PR targeting develop

####

## Deliverables
1. `.agents/skills/pqc-secrets/references/application-orchestration.md` — new
2. `.agents/skills/pqc-secrets/SKILL.md` — cross-link added
3. `.agents/tasks/TASK.2026-08-18.pqc-app-orchestration-docs.md` — this record
4. Branch `docs/pqc-app-orchestration` pushed, PR to develop

## Audit
- No secrets in diff (provider names only, never values)
- No banned crypto introduced; ML-KEM-768 + AES-256-GCM referenced only
- Bundle/tmpfs pack patterns documented with hygiene rules
- Reference implementation pointers verified against local-router 9d275af
