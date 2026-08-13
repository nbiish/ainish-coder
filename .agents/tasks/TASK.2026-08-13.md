# TASK.2026-08-13 — Document security audit + release develop→main

**Date:** 2026-08-13
**Worktree:** `../security-audit-2026-08-13` (branch `docs/security-audit-2026-08-13`, from `develop`)
**PRD anchor:** `llms.txt` read.
**Classification:** Confidential. No secrets below.

## Objective
Document Aug-2026 PQC/OWASP audit. Release develop→main.

## Chain-of-Draft

1. develop==main tree identical
2. main ahead one release commit
3. nothing new to release yet
4. doc work lands on develop first
5. then develop→main releases it
6. project code: 0 banned hits
7. openssl 3.6.3 native PQC ok
8. mldsa/slhdsa params present
9. vendored findings third-party only
10. sha1 hit cache-key non-security
11. app.exec() qt loop false-positive
12. standards match 2026-08-13
13. verdict PASS four minor gaps
14. wrote docs/SECURITY_AUDIT.2026-08-13.md
15. commit in worktree
16. merge docs→develop
17. gate: no feat branches unmerged
18. release develop→main finalized
19. cleanup worktree+branch

####

## Deliverables
- `docs/SECURITY_AUDIT.2026-08-13.md` — full audit report (verdict PASS)
- develop→main release hop post-integration

## Notes
- Recommended (separate task): add `.scrolls-ceremony`, `docs` to `EXCLUDED_DIRECTORIES` in `bin/security_gate.py`.
- Minor gaps tracked in audit §5: CVE-2025-54136, CISA May-2026 cite, MCP Top 10 beta note.
