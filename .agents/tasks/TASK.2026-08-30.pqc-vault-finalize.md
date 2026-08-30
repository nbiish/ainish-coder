# TASK — PQC Docs Finalization + Team Notification (vault-first live)

- date: 2026-08-30
- branch: `docs/pqc-vault-finalize` (worktree `../pqc-vault-finalize`, from `main` @ `c11e40e`)
- classification: Confidential — no secrets in this file

## Objective
1. Finalize documentation after the vault-first issuance merge (`c11e40e`):
   bring remaining doc surfaces in line with v1.2.0 reality.
2. Notify the team (cross-machine) that the PQC key reset and vault-first
   issuance are live.

## Scope (docs only)
- `AGENTS.md` `<REFERENCE>` command list — add `vault`, `issue`, `envelope`;
  correct the darwin/arm64 fast-path command set.
- `.agents/skills/pqc-secrets/references/implementation-guide.md` §2 — engine
  table + review notes updated for v1.2.0 (vault-first, atomic 0600, sidecar +
  audit tamper evidence); §5 merge-safe writer note.
- wtf hub: announcement bin + event (done pre-worktree; hub is cross-machine,
  not a repo artifact).
- Historical records (`TASK.*.md` prior tasks, `docs/SECURITY_AUDIT.*`) stay
  untouched. Upstream-owned skill copy (`.agents/skills/wtf-agent-hub/SKILL.md`)
  stays untouched — reinstalled from the wtf binary; its §5.9 pointer remains
  valid.

## Invariants
- No code changes. No secrets in docs (names + fingerprints only).
- Worktree gate passed; never on `main`.

## Gates
- [x] Survey: no stale "will be rewired" text outside historical task files
- [x] Edits applied — AGENTS.md REFERENCE (vault/issue/envelope + fast-path set),
      implementation-guide.md §2 engine table + v1.2.0 status block, §5
      merge-safe writer note; wtf hub bin 2 + event #12 pre-worktree
- [x] gitleaks diff clean (`git diff | gitleaks stdin` exit 0; pre-commit hook clean)
- [ ] Commit + intent-merge + operator confirmation (cf48ef0 + this fixup)
