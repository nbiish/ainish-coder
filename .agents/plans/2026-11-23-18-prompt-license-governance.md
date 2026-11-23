---
branch: docs/prompt-license-governance
status: done
---

# Plan: prompt governance + canonical license sync gate

## Objective

- Add a concise Prompt & Context Governance Policy to the universal contract, with the full
  versioned text in a reusable template (contract stays <= 160 lines, pinned phrases intact).
- Enforce canonical `LICENSE` byte-for-byte before merges to `main` and sync it on merge, with
  canonical `critical.md` §7 as the source of truth; bring the operator's updated license in now.

## Scope

- `AGENTS.md`, `.agents/templates/prompt-context-governance.md`,
  `scripts/test-pqc-dist.sh`, `.github/workflows/license-sync.yml`,
  `critical.md`, `LICENSE` (this repo)
- `critical.md`, `.github/workflows/license-sync.yml` (canonical `license-for-all-works` repo)

## Steps

1. Cut worktree off latest `origin/main` (`docs/prompt-license-governance`); edit contract via
   `ainish-coder --edit-rules` equivalent (unlock/edit/relock), pay for additions with cuts.
2. Add full versioned policy template; add dist-suite assertions for the pointer and line gate.
3. In canonical license repo worktree, amend `critical.md` §6–7 and `license-sync.yml`: fetch and
   `cmp` `LICENSE` byte-for-byte, `pull_request` gate before merge, metadata mismatch check,
   post-merge integration PR with `chore(license): sync canonical license from license-for-all-works`.
4. Deploy canonical workflow + `critical.md` + updated `LICENSE` verbatim into this worktree;
   verify hashes and metadata (README/source headers; no package.json/pyproject.toml here).
5. Run gates, commit atomically (operator sole author), push both branches, open PRs, report.

## Verification

- `bash scripts/test-pqc-dist.sh` (baseline 441 assertions) and `ainish-context gate --summary`.
- `shasum -a 256`/`cmp -s` on LICENSE and critical.md against canonical; workflow YAML parse.
- `ainish-coder --rules-status` (expect 10/10 current), `git diff` read-back before staging.

## Not in scope

- P0 tasks/plans consolidation (operator owns it in a separate chat).
- Merging either PR (human approval required), touching pre-existing dirty paths on `main`.
