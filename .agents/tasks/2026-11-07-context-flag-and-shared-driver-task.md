# Task: `--context` flag support, and the specified role default

- lane: now
- branch: `feat/context-flag-and-shared-driver` (worktree `D:\Code\ac-ctx-flag`)
- status: done
- scope: `src/rag/rag.py`, `src/rag/tests/test_context_injection.py`, `AGENTS.md`, `llms.txt`,
  `scripts/test-pqc-dist.sh`, `.agents/canonical/`, `.agents/audit/`

## The specified flow

```
agent reads AGENTS.md, is told to run `ainish-rag --context`
  -> the command generates the repo wiki/context/rag
  -> BEFORE emitting, it runs local-router/fallback-models twice:
       call 1 = Elephant concatenation
       call 2 = Goldfish concatenation
  -> the agent receives the assembled injection, then proceeds
```

## Two gaps against that, both closed

### 1. `ainish-rag --context` did not work

argparse expects a subcommand, so the leading flag produced:

```
rag.py: error: argument subcommand: invalid choice: 'probe'
rc=2
```

The tool rejected precisely the spelling the flow names. Fixed by normalizing argv before parsing:
a **leading** `--context` becomes the `context` subcommand. Non-leading occurrences are left alone so
an unknown option still fails as an unknown option — silently rewriting a value that merely looks
like the flag would be worse than the error.

### 2. Both roles defaulted to *different* models

That was my own reading of the pair from the previous pass, not the specification. Both now default to
`local-router/fallback-models`, as asked. This makes the pair a **fresh-context review** — the reviewer
reads the same evidence with no accumulated session state — which is the published effect the split
relies on, and it does not require a different model.

Distinct models became an explicit opt-in (`--distinct-reviewer` / `AINISH_RAG_DISTINCT_REVIEWER=1`),
because switching the reviewer to another provider changes cost and latency and fails outright on a
single-provider host. That is an operator decision, not a silent default.

## The sequencing was already correct — now it is measured

Rather than infer "two calls" from two functions existing, I spied on `_post_chat` and counted real
HTTP requests:

```
1. role=elephant   base=http://127.0.0.1:11434   model=local-router/fallback-models
2. role=goldfish   base=http://127.0.0.1:11434   model=local-router/fallback-models
total HTTP calls: 2
```

Both complete before anything is printed, and the envelope carries all four sections plus the pair
line. The exact documented invocation now works end to end:

```
ainish-rag --context --task "add a --distinct-reviewer flag" --budget 1500
  <CONTEXT_INJECTION>
  <!-- pair: elephant=local-router:mimo-v2.6-pro | goldfish=local-router:mimo-v2.6-pro | same model, fresh context -->
  ## orientation ## retrieval ## elephant ## goldfish
```

## Reporting corrected, not just the default

The pair line used to read `SAME MODEL (reviewer shares the drafter bias)` — which framed the default
as a defect. A report that editorialises against the chosen default is a bug in the report. It now
says `same model, fresh context`, and `ainish-rag secrets` states which mode is active instead of
warning about it.

## Test-isolation bug found

Two of my own tests from the previous pass failed, correctly — they asserted the old
distinct-by-default behaviour. But a third failure appeared **only in the full suite** and passed in
isolation. Cause: `RoleModelSeparationTest.setUp` saved and cleared five env vars but not the new
`AINISH_RAG_DISTINCT_REVIEWER`, so one test contaminated the next. That is the kind of bug that makes
a suite lie in one direction only, and it is why the full-suite run matters.

## Verification

- `py -m unittest discover -s src/rag/tests` — **164 pass** (7 new: five for the `--context` alias
  including every non-leading case, plus same-model default and distinct-reviewer opt-in).
- `bash scripts/test-pqc-dist.sh` — **153/153** (6 new alias and default-mode assertions).
- Live HTTP measurement: exactly 2 calls, both `local-router/fallback-models`.
- The exact documented invocation returns a complete envelope.
- `ainish-rag audit verify` after re-signing.

## Not done, and why

- **The prompts are unchanged.** Both roles still receive their own system prompt and the same
  retrieval excerpt. What each role *sees* is a separate, evidence-dependent question, and
  `docs/rag-context-system-plan.md` Phase 1 remains the arbiter of whether the split earns its cost.
- **The compiled Rust engine still has no `context` verb**; the launchers route it to Python, which is
  what makes the flag form work regardless of which engine answers.
