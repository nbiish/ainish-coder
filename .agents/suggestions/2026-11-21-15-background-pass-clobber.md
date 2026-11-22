2026-11-21-15-background-pass-clobber
# A background consolidation pass clobbers a concurrent manual digest

## What happened

During a manual `CONSOLIDATE .agents/suggestions` run, a background `context-consolidate` pass (the
engine from this worktree, spawning per-folder children) wrote its own draft over
`.agents/suggestions/DIGEST-suggestions-01.md` at 2026-11-21T15:22:30Z — the same path and the same
`sources:` list as the manual run's just-committed digest — and left it as an uncommitted
working-tree change. Nothing in the file or in `git status` said another writer had produced it; the
rewrite was only visible as a modified file whose `consolidated_at` stamp moved. A sibling
`--folder comms` child was still running and was terminated before it touched comms (it had written
nothing).

## Why it matters

`_digest_path`'s sequence name (`DIGEST-<folder>-01.md`) is deterministic for a given folder state, so
two runs over the same folder collide on the same file, and `run_context_consolidate`'s lock covers
only its own invocations — a manual write path has no lock against it. This is the same class as the
follow-ups in the digest it clobbered: a divergence that happens silently and is never a failure.

## Settled by

- whether a digest's frontmatter should carry provenance (`written_by:` + run id or pid/session) so a
  clobber is detectable after the fact;
- and/or whether `_digest_path` should refuse to overwrite an existing digest — the sequence numbering
  exists so runs do not collide, and the same protection should apply to a same-index write.
