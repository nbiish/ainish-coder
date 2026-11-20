2026-11-20-21-consolidation-followups
# Follow-ups the consolidation work surfaced

## 1. The merge step fails more often than the chunks do

Across three real runs the chunk calls succeeded but the merge call returned nothing (twice). The
fallback keeps the partial digests under one heading, which is faithful but reads as batches rather than
one digest. Since the merge input is *smaller* than a chunk input, the failure is probably the
instruction shape rather than size.

**Settled by:** trying the merge with the same terse system prompt the chunks use, and measuring the
success rate over ~10 runs rather than one.

## 2. Consolidation is not yet on the `--context` path

It is a manual verb. The operator's ask was that the context agents do this, which they now can — but
nothing triggers it. The autolearn throttle is the natural neighbour, and it has the same weakness
(it has not fired since 2026-11-19).

**Settled by:** whether consolidation should be spawned by the same background pass as learning, with
its own interval. That is one design decision, not two.

## 3. Real folders have not been consolidated yet

Only `.agents/suggestions` was run, twice, and restored both times. The other four (136 files total,
~150K tokens) are untouched. The first production run should be done with the operator watching, because
the digest replaces source files and the only backup is git.

**Settled by:** running `context-consolidate --folder X` one folder at a time on `main`, checking the
digest by eye before moving to the next.

## 4. `--cap` warns but does not enforce

A folder left over the cap says so and names the unsummarised records, but nothing fails. That is
deliberate — failing would block a commit over housekeeping — but "never more than 5" was the
operator's requirement, so it may need to become a gate rather than a warning.

**Settled by:** whether a folder ever drifts over the cap and stays there.
