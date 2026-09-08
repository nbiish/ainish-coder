# TASK.2026-09-08.remove-merge-gate

- **Triage:** now
- **Branch:** `docs/agents-remove-merge-gate`
- **Worktree:** `/mnt/d/Code/agents-remove-merge-gate`
- **Agent:** dsh-glm-orchestrator
- **Status:** active

## Scope

Remove the operator merge gate from the universal `AGENTS.md` (the singular governing
contract deployed by `ainish-coder --rules` / `--agents`). Operator reports that the
"ask before merging" hop terminates headless/non-interactive agents before they can
complete work — they end their run blocked on merge confirmation.

## Change contract

- Worktree isolation stays (WORKTREE GATE untouched).
- Git history stays the revert path (`--no-ff` merges, `git revert` / reflog).
- Merge becomes autonomous: green gates (audit → native gates → verify) ARE the
  approval; `intent-merge` ledger entry becomes a post-hoc audit record, not a
  permission request.

## Edits (AGENTS.md, 5 spots)

1. Frontmatter: "Ask before merging." → "Gates green → merge autonomously, no operator confirmation gate."
2. Workflow step 8: drop operator prompt; merge after `intent-merge`, gates are approval.
3. New subsection `<WORKFLOW>`: "Autonomous Merge (headless-safe — no operator gate)".
4. `<AUDIT>` #6: "operator confirms merge" → autonomous merge after green gates.
5. `<REINFORCEMENT>`: "Never self-approve merges — ask every hop." → autonomous-merge law.

## Done criteria

- Zero merge-gate phrases remain in AGENTS.md (grep-verified).
- Docs-only: no code paths touched, `no-rebuild-needed`.
- Merged to `main` `--no-ff`, worktree removed, branch deleted, ledger closed.
