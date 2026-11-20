2026-11-20-14-context-consolidation
# Task: consolidate the context folders into dated digests, and cap them

- lane: now
- branch: `feat/context-consolidation`
- status: done (426 assertions pass; merged)
- plan: `.agents/plans/2026-11-20-14-context-consolidation.md`
- scope: `src/context/engine.py`, `AGENTS.md`, `scripts/test-pqc-dist.sh`
- objective: Old records in `.agents/{memories,comms,tasks,suggestions,plans}` are consolidated by the
  context agents into dated digests that keep what was accomplished, unfinished, learned, and
  repeating — while the three newest stay readable and no folder holds more than 5 originals.

## What was built

`ainish-context context-consolidate [--folder F] [--dry-run] [--period month|week] [--cap 5] [--json]`

1. Census each folder, excluding `llms.txt` and `*.live.*` in code.
2. Protect the 3 newest records, computed from the date in the FILENAME (mtime reshuffles on clone).
3. Chunk the rest 5 at a time through the elephant — measured as the largest reliable payload.
4. Goldfish reviews the draft against the sources.
5. Write `DIGEST-<folder>-<period>.md` with a `sources:` frontmatter list, re-read it, and only then
   remove the records that were actually summarised.

## The near-miss that shaped it

The first real run **deleted 16 files** and replaced them with:

> "I'll start with the required context call, then write the digest."

`pi_agent_call` is an *agent*, so it behaved like one in a role that must not. A non-empty check passed
the reply, and the removal followed. Every file was restored from git.

The fix is `_digest_is_usable`: 200+ characters, at least 3 of 4 expected sections, and rejection of any
reply opening with a promise ("I'll start", "let me first", "sure,"). Nothing is removed unless a chunk
produced a usable digest, and only the records a usable chunk covered are removed.

## Bugs found

1. **The data-loss path above** — a non-empty check on an agent's preamble.
2. **The consolidated prompt hangs the local model intermittently.** A 44,606-char prompt timed out at
   90s, 200s, and 300s; the same payload with a terse instruction answered in 5s; 12,312 chars answered
   in 12s. Chunking at 5 records plus one retry per call is the fix.
3. **`.live.txt` files are date-prefixed**, so a pure date rule would delete five gitignored files with
   no recovery. Only a constructed test caught this — reading the code did not.
4. **`llms.txt` is inside `memories/` and `plans/`** and is the folder index, not a record.
5. **A legacy `.txt` is not valid UTF-8**, so every read needs `errors="replace"`.

## Verification

- `scripts/test-pqc-dist.sh` — **426 assertions pass** (418 baseline, 8 new), including the exclusion
  predicate over 6 constructed cases, the preamble rejection, the write-before-delete ordering, and a
  dry run that changes nothing.
- Real run on `.agents/suggestions`: 19 files → **3 originals + 1 digest**; digest quality inspected by
  hand and found specific, cited, and accurate.
- `AGENTS.md` — 160 lines, re-signed, chain verified at 66 transitions, re-locked.
- Folder restored to 19 files after verification; the digest was kept only as a sample.

## Deviations from the plan

- **Chunked rather than single-shot.** The plan assumed one model call per period; measurement showed
  that hangs, so the digest is built in 5-record chunks and merged.
- **The merge has a documented fallback.** When it fails twice, the partial digests are kept under one
  heading rather than discarded — faithful, if less polished.

## Not done

The other four folders are untouched (~150K tokens still raw). Consolidating them is a production action
that replaces files, so it should be run with the operator watching, one folder at a time.
