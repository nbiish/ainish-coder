2026-11-20-09-identity-trailer-hook
# Task: stop harness attribution trailers at commit time, and clean the unpushed ones

- lane: now
- branch: `feat/identity-trailer-hook`
- status: implementing
- plan: `.agents/plans/2026-11-20-09-identity-trailer-hook.md`
- scope: `scripts/harness-attribution.txt`, `scripts/strip-harness-trailers.sh`,
  `scripts/commit-identity-guard.sh`, `scripts/setup-hooks.sh`, `src/deploy_rules_sync.sh`,
  `AGENTS.md`, `scripts/test-pqc-dist.sh`
- objective: A harness attribution trailer must never reach a commit object, so the operator stays the
  only author per AGENTS.md rule 4; and the 20 unpushed commits that still carry one must be cleaned
  without touching pushed history.

## Findings that shape the work

- **The strip already exists and is unreachable.** `commit-identity-guard.sh:78` exits when the author
  is already `Nanoboozhoo - embodied by <harness>`, which is true for exactly the commits that keep a
  trailer — 26 of them.
- **`Nanoboozhoo embodied by: Cursor` is not a trailer.** `git interpret-trailers --parse` returns
  nothing for it; the colon is not in key position. `Nanoboozhoo-Embodied-By: Cursor` does parse.
- **`setup-hooks.sh` never installs the guard.** Only `--rules` does, so a local checkout can run for
  months without it.
- **Installation is not idempotent:** `.git/hooks/post-commit` holds 12 duplicate guard blocks, because
  the guard block is deduplicated on the rules-sync marker.
- **82 commits carry trailers, 20 unpushed.** Six variants exist across Cursor, Warp, Copilot, Oz and
  Claude, so the table must be data rather than code.
- **`commit-msg` runs before the commit object exists**, verified in a scratch repo — so stripping
  there needs no amend and cannot lose a signature.

## Next action

T1: the table and the strip script. Everything else calls them.
