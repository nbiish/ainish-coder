2026-11-18-15-comms-block-parsing
# Task: orientation reads both COMMS entry delimiters

- lane: now
- branch: `fix/comms-block-parsing`
- status: done
- plan: `.agents/plans/2026-11-18-15-comms-block-parsing.md`
- scope: `src/rag/rag.py`, `scripts/test-pqc-dist.sh`
- objective: Orientation's "today's COMMS, last entry" line must report the actual newest entry's status
  and objective, not the frontmatter fence, whichever of the two live delimiter styles the ledger uses.

## Findings that shape the work

- The parser split only on `### `; current ledgers use `---` fences, so a real context call printed
  `- today's COMMS, last entry: ---`. That is worse than omitting the line, because it looks like state
  was gathered when nothing was.
- Two delimiter styles exist across `.agents/comms/`; historical ledgers are append-only and must not be
  rewritten, so the parser accepts both.

## Next action

Commit, merge, remove the worktree.
