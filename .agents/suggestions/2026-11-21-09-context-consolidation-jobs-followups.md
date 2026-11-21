2026-11-21-09-context-consolidation-jobs-followups
# Follow-ups from the context/consolidation/jobs work

## 1. The consolidation pass is best-effort

It is a detached child. If the machine sleeps, the pass is lost and the folders stay over cap until
the next `--context` call. The throttle then records nothing, because the attempt is only recorded when
the spawn succeeds.

**Settled by:** whether a queue is worth it. A durable queue for a daily housekeeping job may be more
machinery than the thing deserves — the same judgement the learning pass made.

## 2. A partially-digested period still writes a digest

`tasks` split into two chunks; one failed review, so a digest was written covering 1 of 16 records while
13 originals stayed. The folder is then over cap AND carrying a digest whose `records_consolidated: 1`
understates the period.

**Options:** all-or-nothing per period; or one call per period (hermes took 40K in 66s, so the chunking
may no longer be needed); or name the chunk range in the digest filename.

## 3. `.agents/jobs/` is not read by any tool

It is deliberately inert — nothing in it executes. But nothing indexes it into the retrieval graph
either, so a job record is invisible to `--context` unless an agent opens the file.

**Settled by:** adding `("jobs", ".agents/jobs", True)` to `GRAPH_EXTRA_SOURCES` if jobs should be
retrievable. That is a one-line change, deliberately not made here because the operator said no further
configuration.

## 4. The watcher still runs a stale binary

The plan's T7 (log the source commit at startup so "fix merged but watcher stale" is visible) is not
implemented. The watcher currently runs under launchd from a checkout that may predate the fixes just
merged.

**Settled by:** restarting the watcher, which is an operator action, and then confirming the new state
format appears in `watch.state` (`started=` and `note=` keys are new).
