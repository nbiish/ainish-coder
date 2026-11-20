2026-11-20-09-identity-trailer-hook
# Task: stop harness attribution trailers at commit time, and clean the unpushed ones

- lane: now
- branch: `feat/identity-trailer-hook`
- status: done (397 assertions pass; merged)
- plan: `.agents/plans/2026-11-20-09-identity-trailer-hook.md`
- scope: `scripts/harness-attribution.txt`, `scripts/strip-harness-trailers.sh`,
  `scripts/rewrite-msg-callback.py`, `scripts/commit-identity-guard.sh`, `scripts/setup-hooks.sh`,
  `src/deploy_rules_sync.sh`, `AGENTS.md`, `scripts/test-pqc-dist.sh`
- objective: A harness attribution trailer must never reach a commit object, so the operator stays the
  only author per AGENTS.md rule 4; and the unpushed commits that still carried one must be cleaned
  without touching pushed history.

## What changed

| Was | Now |
|---|---|
| `post-commit` guard stripped trailers only AFTER amending, and skipped entirely when the author was already correct | `commit-msg` strips BEFORE the object exists: no amend, no re-sign, no rewritten history |
| harness names hardcoded in two scripts, and they disagreed | one table, `scripts/harness-attribution.txt`, read by the hook, the guard, and the rewrite |
| the guard's filter stripped `Signed-off-by:` | preserved — a DCO assertion the operator makes, not a tool claiming authorship |
| `setup-hooks.sh` installed neither `commit-msg` nor `post-commit` | installs both, idempotently |
| hooks went to `$(git rev-parse --git-dir)/hooks` — a path git never reads in a worktree | `--git-common-dir`, the one directory every checkout shares |
| deploy hardcoded `${REPO_DIR}/.git/hooks` | resolved through `git rev-parse --git-path hooks` |
| hook install was not idempotent: one checkout had 12 duplicate guard blocks | each block deduplicated on its OWN marker |
| 62 unpushed commits carried a trailer | 0 across `origin/main..main`; tree hash unchanged |

## Bugs found

1. **The strip existed and was unreachable.** The guard exited as soon as the author was correct, which
   is true for every commit that keeps a trailer — 26 of them.
2. **`setup-hooks.sh` wrote hooks git never runs.** In a worktree `--git-dir` is
   `.git/worktrees/<name>`, so the hook appeared installed and did nothing. Reproduced: a commit with a
   trailer committed with the trailer intact, on a machine that reported the hook present.
3. **The guard stripped `Signed-off-by:`**, deleting a DCO assertion along with the false attribution.
4. **Deploy had the same worktree defect**, so `--rules` into a worktree installed inert hooks.

## Verification

- `scripts/test-pqc-dist.sh` — 397 assertions pass (387 baseline, 10 new), including that human
  co-authors, DCO sign-offs, and prose survive the strip.
- Live on `main`: a commit carrying `Co-authored-by: Cursor` arrived stripped, authored
  `Nanoboozhoo - embodied by cursor`, with the removal reported.
- `git log --format=%B origin/main..main | grep -ci 'co-authored-by:.*cursor'` — 0.
- Tree hash before and after the rewrite — `a1e6f70e3ef6`, identical.
- `wc -l < AGENTS.md` — 160.

## Deliberate deviations

- **Stripped rather than rewritten** to `Nanoboozhoo embodied by: Cursor`. The operator's phrasing is
  not a git trailer (`interpret-trailers --parse` returns nothing for it), and the author field already
  records the harness. A second copy in the message would be duplication, not evidence.
- **Only the 20 unpushed commits were rewritten** (operator decision). Pushed history keeps its
  trailers; recorded in the suggestions file rather than glossed.
