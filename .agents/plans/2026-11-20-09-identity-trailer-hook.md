---
plan_format: ainish/plan/v1
slug: identity-trailer-hook
date: 2026-11-20
status: done
branch: feat/identity-trailer-hook
worktree: /Users/nbiish/code/identity-trailer-hook
task_record: .agents/tasks/2026-11-20-09-identity-trailer-hook.md
operator: direct-instruction
---

# Plan: stop harness attribution trailers at commit time, and clean the unpushed ones

## 1. Problem

AGENTS.md rule 4 says the operator is the only author. Harnesses comply by setting the author field,
but several also append `Co-authored-by: Cursor <cursoragent@cursor.com>` (and Warp, Copilot, Oz,
Claude equivalents) to the message. The guard that strips those lines exists and works — but it exits
early when the author is ALREADY correct, so the exact case it needs to handle is the one it skips.
Measured: 26 commits have the author `Nanoboozhoo - embodied by cursor` and a surviving Cursor
trailer.

## 2. Anchor Facts

- `commit-identity-guard.sh:78` exits when `cur_name` already equals the target identity; the strip at
  `:94` is therefore unreachable for exactly the commits that need it — 26 of them.
- Trailer counts in history: Cursor 81, Warp 51, Copilot 16, Oz 13, Claude (two spellings) 11.
- `git interpret-trailers --parse` returns NOTHING for `Nanoboozhoo embodied by: Cursor` — the colon
  is not in key position, so it is prose, not a trailer. `Nanoboozhoo-Embodied-By: Cursor` parses.
- `scripts/setup-hooks.sh` installs `pre-commit`, `post-merge`, `post-checkout`; it never installs
  `post-commit`, so a local checkout only gets the guard if `--rules` ran against it.
- `.git/hooks/post-commit` contains **12** duplicate guard blocks: `_ainish_rules_install_hook_block`
  replaces on the RULES-SYNC marker, while the guard block is checked with that same marker.
- 82 commits carry the trailer; **20 are unpushed** (`origin/main..HEAD` is 24, 20 of them trailers).
- `git filter-repo` is installed at `/Users/nbiish/miniconda3/bin/git-filter-repo`.
- `commit.gpgsign=true`, key `68F4E3D4B06832C0`; an amend re-signs only because the guard passes `-S`.
- Verified in a scratch repo: a `commit-msg` hook rewrites the message BEFORE the commit object exists,
  so no amend and no signature loss.

## 3. Plan

### Goals

- A harness trailer never reaches a commit object: stripped in `commit-msg`, before signing.
- The author guard keeps doing its job and no longer skips its own strip step.
- The trailer table is data, so adding a harness is one line.
- The 20 unpushed trailer commits are cleaned; nothing pushed is rewritten.

### Non-goals

- Rewriting the 62 already-pushed trailer commits: it changes SHAs on a shared remote for cosmetics.
- Changing the author identity format: `Nanoboozhoo - embodied by <harness>` stays the rule.
- Blocking commits. This is a repair hook, not a gate — it edits and proceeds, like the author guard.

### Constraints and invariants

- `commit-msg` must be idempotent and must never fail a commit (a broken hook that blocks work gets
  disabled, which is how the trailer got here).
- Signing must survive: edits happen pre-object, so no `-S` re-sign is involved.
- `AGENTS.md` stays at 160 lines.
- Hook installation must be idempotent — no more duplicate blocks.
- The rewrite touches only unpushed commits and only trailer lines.

### Proposed architecture

```
git commit
  └─ commit-msg  (NEW)  strip <attr>: …<harness> lines; record them → no amend, signature intact
  └─ post-commit        re-author a harness-authored commit (existing guard, minus the early exit)
```

### Interfaces and data

- `scripts/harness-attribution.txt` — one `name|match-regex|replacement` line per harness; the single
  source both hooks and the rewrite read.
- `scripts/strip-harness-trailers.sh [--check|--rewrite-msg FILE]` — the strip logic, callable from a
  hook and from `filter-repo`'s `--msg-filter`.
- `scripts/commit-identity-guard.sh` — early exit narrowed to "author correct AND message clean".
- `scripts/setup-hooks.sh` — installs `post-commit` (guard) and `commit-msg` (strip), idempotently.
- `src/deploy_rules_sync.sh` — install both blocks with distinct markers.

### Files and symbols

- `scripts/harness-attribution.txt` — new; the harness table.
- `scripts/strip-harness-trailers.sh` — new; strip + report.
- `scripts/commit-identity-guard.sh` — `:76-82` early exit becomes a cleanliness test.
- `scripts/setup-hooks.sh` — add post-commit and commit-msg installation.
- `src/deploy_rules_sync.sh` — split the two hook markers; install commit-msg.
- `AGENTS.md` — one sentence naming the hook, paid for by trim; stays 160.
- `scripts/test-pqc-dist.sh` — assertions for strip, idempotency, and signing survival.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Keep stripping in `post-commit` and drop the early exit | Works, but amends every such commit and re-signs; a pre-object hook is strictly better |
| `prepare-commit-msg` | Runs before the message is final and is skipped for `-F`/`-m` in some paths |
| Rewrite all 82 commits | Changes SHAs on a shared remote for a cosmetic gain |
| `Nanoboozhoo embodied by: Cursor` verbatim | Not a trailer — `interpret-trailers` returns nothing, so tooling cannot read it |
| A `server-side`/CI check only | Detects after the fact; the commit already exists and needs an amend to fix |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| A buggy hook blocks every commit | Strip path is `|| true`, edits only matched lines, exits 0 always; test proves a failing grep cannot abort |
| Signature lost | Edits precede the object; assertion proves a signed commit stays signed |
| Rewrite damages history | `filter-repo --refs origin/main..main`, dry-run first, `git log` diff after, backup ref kept |
| Harness adds a new trailer spelling | Table is data; the generic `<attr>: … <harness>` rule catches unknown emails from known products |

## 4. Clarifications

### 4.1 What replaces the trailer

- **Question:** A `Co-authored-by:` line contradicts rule 4, and the author field already records the harness. What replaces it?
- **Options:** 1. (Recommended) Strip entirely; 2. rewrite to a parseable `Nanoboozhoo-Embodied-By:` trailer; 3. use the literal string the operator wrote; 4. both author and trailer.
- **Selected:** 1 — strip.
- **Trade-off accepted:** The message loses a standalone greppable marker for the harness; the author field keeps it, and the live ledger records every rewrite.

### 4.2 How far back to rewrite

- **Question:** 82 commits carry the trailer, 20 unpushed. How far back?
- **Options:** 1. (Recommended) Unpushed only; 2. all 82; 3. forward-only.
- **Selected:** 1 — unpushed only.
- **Trade-off accepted:** Pushed history keeps its trailers, so `git log` stays inconsistent across the era. Recorded rather than glossed.

## 5. Todos

- [x] **T1** Add `scripts/harness-attribution.txt` and `scripts/strip-harness-trailers.sh`.
  - from: §3 | done when: the strip removes every known variant and reports what it removed | verify: `printf 'x\n\nCo-authored-by: Cursor <cursoragent@cursor.com>\n' | ./scripts/strip-harness-trailers.sh --stdin`
- [x] **T2** Narrow the guard's early exit to "author correct AND message clean".
  - from: §3 | done when: a correct-author commit with a trailer is still stripped | verify: suite assertion
- [x] **T3** Install `commit-msg` and `post-commit` from `setup-hooks.sh` and `--rules`, idempotently.
  - from: §3 | done when: re-running installs leaves exactly one copy of each block | verify: grep -c
- [x] **T4** Prove a signed commit stays signed after the strip.
  - from: §3 | done when: `git verify-commit` passes on a commit whose trailer was stripped | verify: that command
- [x] **T5** Rewrite the 20 unpushed commits with filter-repo, keeping a backup ref.
  - from: §4.2 | done when: no trailer remains in `origin/main..main` and the tree is unchanged | verify: `git log --format=%B origin/main..main | grep -c Co-authored-by`
- [x] **T6** Update `AGENTS.md` and the suite.
  - from: §3 | done when: 160 lines and the suite passes at or above baseline | verify: `wc -l` + suite

## 6. Verification

- `scripts/test-pqc-dist.sh` — passes at or above 387 assertions.
- `wc -l < AGENTS.md` — 160.
- A commit made with a Cursor trailer arrives with no trailer and a valid signature.
- `git log --format=%B origin/main..main | grep -ciE 'co-authored-by:.*(cursor|claude|copilot|warp)'` — 0.
- Re-running hook installation leaves one block per hook.

## 7. Open Decisions

- Whether to publish the harness table as a deployed artifact so target repos inherit new entries —
  settled when a second repo needs an entry this one does not have.
- Whether the guard should also normalise trailers it does NOT recognise — settled by whether an
  unknown harness appears in history after the table ships.
