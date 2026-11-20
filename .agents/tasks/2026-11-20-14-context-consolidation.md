2026-11-20-14-context-consolidation
# Task: consolidate the context folders into dated digests, and cap them

- lane: now
- branch: `feat/context-consolidation`
- status: implementing
- plan: `.agents/plans/2026-11-20-14-context-consolidation.md`
- scope: `src/context/engine.py`, `src/context/context_harness.py`, `AGENTS.md`,
  `scripts/test-pqc-dist.sh`
- objective: Old records in `.agents/{memories,comms,tasks,suggestions,plans}` should be consolidated by
  the context agents into dated digests that keep what was accomplished, unfinished, learned, and
  repeating — while the three newest stay readable and no folder holds more than 5 originals.

## Findings that shape the work

- 136 files, ~195K tokens across the five folders; the graph indexes every one of them.
- `memories/llms.txt` and `plans/llms.txt` are DIRECTORY INDEXES, not records — counting or
  consolidating them destroys the map.
- Five comms files are gitignored `.live.txt` sidecars; deleting them is unrecoverable.
- Everything else is tracked, so `git show` is the archive.
- Records are dated in the filename, so period grouping is mechanical.

## Next action

T1: the exclusion and period helpers.
