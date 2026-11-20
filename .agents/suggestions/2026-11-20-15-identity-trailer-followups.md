2026-11-20-15-identity-trailer-followups
# Follow-ups the identity-trailer work surfaced

## 1. Pushed history still carries 62 harness trailers

The rewrite covered `origin/main..main` only (operator decision). `git log --all` still shows
`Co-authored-by: Cursor` on pushed commits, so the history is inconsistent across the 2026-11 era.

**Settled by:** a deliberate force-push window, or by leaving it — the trailers are cosmetic once the
author field was already correct on most of them. Worth deciding once, not per-commit.

## 2. The table is duplicated into every deployed repo

`--rules` installs a `commit-msg` block that points at the SOURCE installation's
`scripts/strip-harness-trailers.sh`, so a target repo runs the source's table and never gets updates of
its own. That is fine for a fleet that shares one install, and wrong for a target that is meant to be
self-contained.

**Settled by:** whether a deployed target should carry its own copy of the table and script. If yes,
`deploy_rules_sync.sh` should write both into `.agents/bin/` rather than referencing `REPO_DIR`.

## 3. `--rules` does not verify the hooks it installed

`--rules-doctor` checks the rules-sync block but not the identity blocks, so a target that lost its
`commit-msg` hook reports healthy.

**Settled by:** adding the two markers to the doctor's check list — the markers are already stable and
unique per block.

## 4. Unknown harnesses are not caught

The generic `bot_email_pattern` in the guard catches tool-shaped authors with an unrecognised name, but
there is no equivalent for TRAILERS: a harness not in the table gets its attribution strip passed over.

**Settled by:** watching what appears in history after this ships. If a new product shows up, it is one
line in `scripts/harness-attribution.txt` — which is the point of the table.
