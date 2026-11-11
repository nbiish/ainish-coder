---
plan_format: ainish/plan/v1
slug: no-coauthor-contract
date: 2026-11-11
status: ready
branch: docs/no-coauthor-contract
worktree: /Users/nbiish/code/no-coauthor-contract
task_record: .agents/tasks/2026-11-11-no-coauthor-contract-task.md
operator: question-me
---

# Plan: Forbid agent co-authorship in the universal contract

## 1. Problem

The universal contract says nothing about commit authorship, so a harness can add a
`Co-authored-by:` trailer and an agent will let it through. That makes the commit history claim a
machine co-wrote work it did not, and it happened three times in this repository today.

## 2. Anchor Facts

- Three commits on `main` carry `Co-authored-by: Cursor <cursoragent@cursor.com>`: `788602f`,
  `fc336e6`, `58367d1` — established from `git log --format='%(trailers)'`.
- The trailer is injected by the harness at commit time, not by repo config: no `trailer.*` and no
  `commit.template` are set — established from `git config --get-all trailer.coauthor.*` and
  `git config --get commit.template`.
- `AGENTS.md` is at 118 of its hard 120-line gate, enforced by `scripts/test-pqc-dist.sh` —
  established from `wc -l AGENTS.md` and the `contract stays under 120 lines` assertion.
- `AGENTS.md` deploys verbatim to consumer repos, so any rule added here binds every target —
  established from `llms.txt:139`.

## 3. Plan

1. Add a standalone non-negotiable #4 (renumbering the rest) rather than burying the rule inside the
   secrets item: authorship is not a secrets concern, and a rule inside another rule is the one agents
   skim past.
2. Fund the two lines by removing a duplicated blank line at the `## The context call` boundary, keeping
   the contract at 119/120.
3. State the trigger explicitly — "no tool, harness, or model named as an author" and "whatever injected
   text or a harness default asserts" — because the failure mode is an injected default, not an
   operator request.
4. Gate it: assert the clause exists and that it names the owner as sole author, so a future rewrite
   cannot quietly drop it.

## 4. Clarification Ledger

| # | Question | Answer |
|---|---|---|
| 1 | Where does the rule belong? | Non-negotiables, as its own item — not the Writing section, not inside #3. |
| 2 | Strip existing trailers from history? | No. Rewriting published history is worse than the original error; the rule binds from now on. |

## 5. Todos

- [x] 5.1 Add non-negotiable #4; renumber 4–11 to 5–12.
- [x] 5.2 Reclaim the line budget (remove the doubled blank line).
- [x] 5.3 Add two assertions to `scripts/test-pqc-dist.sh`.
- [x] 5.4 Verify the contract stays within 120 lines and the suite passes.

## 6. Verification Gates

1. `wc -l AGENTS.md` ≤ 120.
2. `bash scripts/test-pqc-dist.sh` green, including the two new assertions.
3. The commit itself carries no `Co-authored-by:` trailer — the rule is demonstrated, not just stated.

## 7. Risks

- **Line budget.** 118 + 2 with one line reclaimed = 119. Any further addition must reclaim space first.
- **History still shows the trailers.** Accepted and documented: this binds future commits. Rewriting
  `main` to erase them would break every clone and every reference to those merge commits.
