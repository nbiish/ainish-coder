2026-11-21-15-attribution-table-test-drift
# The attribution table and its test disagree after the panel merge

`scripts/test-pqc-dist.sh` assertion "a tool-authored commit is re-authored as the operator" pins
the expected author to `Nanoboozhoo - embodied by cursor` (line ~1758), but the re-authoring at
HEAD produces `Nanoboozhoo - embodied by claudecode`. Pre-existing at `7685720` ("merge: sequence
digests, a four-agent panel, and a lock that finally excludes") — that merge touched both
`scripts/test-pqc-dist.sh` and `scripts/harness-attribution.txt` (per `git log` on 2026-11-21).
Baseline and post-move runs agree: 440 pass, exactly this one fails.

Not fixed here on purpose: the attribution table and the fleet work are owned by a sibling session
that merged minutes earlier ("one writer per mutation boundary"), and guessing which side is
correct — the table mapping or the test's pinned literal — would paper over their intent.

Settled when the owning session (or the operator) says which value is canonical: if the table's
`claudecode` mapping is right, update the assertion's expected literal; if `cursor` is the
machine form that must win, fix the table entry. Then `bash scripts/test-pqc-dist.sh` must go
green at 441/441.

## Resolved 2026-11-22

Neither literal was canonical. The operator set the author form to `Nanoboozhoo embodied by:
{agent harness}`, and the test now clears all harness env markers and forces one known marker
before asserting, so it is harness-independent. `scripts/test-pqc-dist.sh` passes 441/441.
