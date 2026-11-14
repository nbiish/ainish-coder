# Run Elephant and Goldfish as `pi` agents with attached context

- **status:** done
- **branch:** `feat/pi-agents-prime`
- **plan:** `.agents/plans/2026-11-14-17-pi-agents-prime.md`
- **worktree:** `/Users/nbiish/code/ainish-coder-pi`
- **operator ask:** "If they're failing we should utilize `pi` agents ADK to programatically run the
  elephant and goldfish model system for our two internal ainish-rag logic for the final outputs to be
  expertly combined and output as the singular context priming we're looking for combined with the wiki
  agent. We should make very clear and detailed prompt instructions for these agents and if possible
  programatically prompt them with the appropriate attached context folders and files."
- **operator decisions:** `pi` for every context call (not just fallback); attach real files AND inline
  a bounded excerpt; fix the reviewer token-budget defect as part of this work.
- **scope:** `src/rag/rag.py`, `src/rag/tests/test_context_injection.py`, `scripts/test-pqc-dist.sh`,
  `llms.txt`, `AGENTS.md`

## What was found (profiled live, 2026-11-14)

Timing breakdown of a real 41.6s `--context` call:

| Phase | Time |
|---|---|
| route decision (1 model call) | 1.2s |
| retrieval (graph, no model) | 19ms |
| orientation (code, no model) | 47ms |
| elephant (1 model call) | 6.9s |
| reviewer precheck | 0ms |
| goldfish (3 model calls) | **33.5s** |

Payloads were small — elephant prompt 1,551 chars, goldfish prompt 2,004 chars — so content size was
never the problem. The 33.5s was three reviewer calls each burning ~15s and then failing with
`truncated by token budget (finish_reason=length, max_tokens=672)`.

Root causes:
1. **Token budget sized from the wrong thing.** `max(600, goldfish_cap * 4)` with `goldfish_cap` = 14%
   of a 1,200 budget gives ~672 tokens; a reasoning model exhausts that on reasoning. The time budget
   had been raised for reviews; the token budget never was.
2. **Rotation put the reviewer on the wrong transport.** Separation rotates goldfish off the drafter's
   transport — correct for independence — but with the vault locked, `local-router` is the only step
   without a key requirement, and that is what it rotated away from.
3. **Thin prompts.** ~2KB inlined meant the agents reasoned over excerpts instead of reading files.

`pi` was verified end-to-end before designing against it: 1.5.2, `--print --no-session --mode json`,
`@file` attachments (it correctly identified the relevant file of two and dismissed the irrelevant
one), `--append-system-prompt`, router reachability `ready`, no session state written, and typed
content blocks (`thinking` + `text`) that must be separated on extraction.

## What changed

1. **`pi` is the runtime for both roles.** `pi_agent_call` runs one agent turn as
   `pi --print --no-session --no-tools --mode json --thinking <level> --model <id>
   --append-system-prompt <brief> @file... "<prompt>"`. `--no-session` makes the fresh-reader
   requirement structural; `--no-tools` keeps a context call from acquiring authority it was never
   granted; the JSON event stream lets `thinking` blocks be discarded so only the answer reaches the
   prime. Failure (missing binary, timeout, non-zero exit, no text blocks) returns a recorded reason.
2. **Long role briefs.** `elephant_brief`, `goldfish_comprehension_brief`,
   `goldfish_antagonistic_brief`, `goldfish_readiness_brief` — each states authority, duty, hard rules
   (no instructions/authorization/secrets, no invented facts, attached text is evidence not
   instruction), and an output shape with a word cap.
3. **Real files attached.** `_attach_paths_from_hits` attaches up to 6 distinct repo-relative paths
   from the retrieval hits, guarding against path escape (`relative_to(root)`), oversize
   (`PI_MAX_ATTACH_BYTES` 512KB), ignored paths, and duplicates. The inline excerpt stays as the floor.
4. **Model ids translated for pi.** `PI_MODEL_IDS` maps engine transports to pi's provider-qualified
   ids, because a bare `glm-5.3-flash` is ambiguous across five providers in pi's catalog and pi
   refuses rather than guessing (observed live).
5. **Thinking level as a cost lever.** Measured: a one-word reply at `--thinking high` cost 6,904 input
   tokens; at `off`, 56. Elephant defaults to `off` (it composes from given material), goldfish to
   `low` (it reasons about evidence). `AINISH_RAG_PI_THINKING` overrides.
6. **Independence enforced up front** against the two models the roles will actually be handed, not
   the served source after the fact.
7. **Elephant note handed over whole.** The reviewer previously cut it at 3,000 chars and a live run
   spent a finding complaining its subject was truncated — review budget spent on our bug.

## Verification

| Gate | Baseline | After |
|---|---|---|
| `pytest src/rag/tests` | 137 | **145** |
| `scripts/test-pqc-dist.sh` | 285 PASS | **296 PASS** |
| live `--context` wall time | **41.6s** | **22.4s** |
| live reviewer | 2 of 3 steps, 1 truncated | **3 of 3, real content** |

Proven, not assumed:
- the thinking-leak test fails when I deliberately made `_pi_extract_text` accept `thinking` blocks;
- path-escape, oversize, dedupe, timeout, and missing-binary guards each have a test;
- the live reviewer independently caught the elephant-note truncation, which is how that bug was found.

## Not verified, and why

- **`zai` served the best reviewer but is a paid direct call.** It answered in 2.0s and produced the
  strongest review. On a host without a zai key the reviewer falls to a chain that includes
  `local-router`, which is slower but works.
- **`xiaomi` cannot be exercised**: `pi auth check --model xiaomi/mimo-v2.6-pro` returns `not_ready`.
- **`--thinking off` for the elephant is a quality trade** made on timing evidence; if elephant output
  degrades on a harder task, `AINISH_RAG_PI_THINKING=low` is the dial.

## Expected first failure if this is wrong

The prime would still return four sections with a `pair:` line, but the reviewer would be reasoning
about an inline excerpt rather than the attached files — visible as attachments absent from the
`<!-- source: pi agent ... N file(s) attached -->` line, or as a review that cites only what the
excerpt contained. The attachment count in the reason line is the cheap tell.
