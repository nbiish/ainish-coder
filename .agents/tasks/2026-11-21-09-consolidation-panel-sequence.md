2026-11-21-09-consolidation-panel-sequence
# Task: sequence digests so a folder can always come down, and put four agents on the review

- lane: now
- branch: `feat/consolidation-panel-sequence`
- status: implementing
- plan: `.agents/plans/2026-11-21-09-consolidation-panel-sequence.md`
- scope: `src/context/engine.py`, `scripts/consolidation-skills/`, `src/deploy_rules_sync.sh`,
  `.agents/jobs/consolidate-record.md`, `scripts/test-pqc-dist.sh`
- objective: A folder can always be brought to the 5-original cap, and each consolidation is reviewed by
  four specialized hermes agents with distinct jobs rather than one drafter and one checker.

## Findings that shape the work

- **55 originals remain unconsolidated** across five folders; every folder is over cap.
- **The blocker is period keying.** `DIGEST-<folder>-<period>.md` is terminal: once it exists the period
  can never accept another record, so four of five folders reported "digest already exists" and
  consolidated zero. `DIGEST-tasks-2026-11.md` covers 1 record while 15 sit beside it.
- Four hermes profiles exist and are described (`consolidate-elephant`, `-goldfish`, `-structural`,
  `-archivist`), all on `mimo-v2.6-pro` with the gateway running.
- The three new questions are genuinely orthogonal: fidelity (does the draft follow from the sources),
  completeness (is anything unrepresented), coherence (does it hold together as one record).

## Next action

T1: replace the period lock with a sequence index.
