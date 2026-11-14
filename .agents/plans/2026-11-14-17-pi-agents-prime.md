---
plan_format: ainish/plan/v1
slug: pi-agents-prime
date: 2026-11-14
status: done
branch: feat/pi-agents-prime
worktree: /Users/nbiish/code/ainish-coder-pi
task_record: .agents/tasks/2026-11-14-17-pi-agents-prime.md
operator: question-me
---

# Run Elephant and Goldfish as `pi` agents, with real files attached

## 1. Problem

`--context` takes ~42s and produces a weak review. Profiling (2026-11-14) isolated three causes:

1. **Each reviewer call burns ~15s and then fails.** `goldfish_review` sizes `max_tokens` as
   `max(600, goldfish_cap * 4)`, and `goldfish_cap` is 14% of a 1,200-token budget — so ~672 tokens.
   A reasoning model spends that on reasoning before emitting content, gets `finish_reason=length`,
   and the call is discarded. Three steps × ~15s ≈ 33.5s of the 41.6s total. The *time* budget was
   raised for reviews; the *token* budget never was.
2. **The reviewer is rotated off the only working transport.** Separation logic starts goldfish's
   chain on a different transport from the drafter's, which is correct for independence — but with
   the vault locked only `local-router` has no key requirement, and that is the step it rotates away
   from. So every reviewer call walks three key-less direct steps before reaching a transport that
   works.
3. **The prompts are thin.** The whole review receives ~2KB of inlined text, so the agents reason
   about excerpts rather than reading the files.

The operator's direction: use the `pi` agent CLI as the runtime for the Elephant and Goldfish roles,
with clear, detailed instructions and the real context files attached programmatically.

## 2. Anchor facts

Verified live on this host, 2026-11-14:

| Fact | Evidence |
|---|---|
| `pi` 1.5.2 is installed at `~/.local/npm-global/bin/pi` | `which pi`, `pi --version` |
| `pi` runs non-interactively | `--print`, `--mode text|json`, `--no-session` |
| `pi` accepts attached files | `@path` args; a test with two files named the relevant one and dismissed the irrelevant one |
| `pi` accepts a real system prompt | `--append-system-prompt` (the flag; `--system-prompt` replaces the coding-assistant default) |
| `pi` reaches the local router | `pi auth check --model local-router/fallback-models` → `ready`; a call answered in 2.3s |
| `pi --no-session` writes no state | no new files under `~/.pi` after runs |
| `pi` returns typed content blocks | `[{"type":"thinking",...},{"type":"text","text":"..."}]` — text must be selected, not concatenated blindly |
| Attached files are read in full | 7,461 input tokens with one `@.agents/wiki/README.md` vs ~500 when inlined |
| Reviewer truncation is the latency cause | `attempts`: `truncated by token budget (finish_reason=length, max_tokens=672)` |
| Goldfish's chain starts on `zai` | `chain_steps("goldfish")` rotates the head off `local-router` |

## 3. Design

### 3.1 `pi` becomes the runtime for both roles

A new module-level helper runs one agent invocation:

```
pi --print --no-session --mode json --model <id> \
   --append-system-prompt <role instructions> \
   @<file> [...] "<task and inline excerpt>"
```

- **Model:** resolved per role exactly as today (`role_pinned_model`, else the role's chain head), so
  `--elephant-model` / `--goldfish-model` and the env pins keep working.
- **Isolation:** `--no-session` for both roles, so neither inherits any `pi` conversation state. That
  is the structural guarantee EGM needs, and it is the same property the in-process path had.
- **Tools:** `--no-tools`. An agent that can run bash inside a context call is an authority
  escalation the contract does not grant. The roles read and write prose only.
- **Output extraction:** parse `--mode json` events, take `agent_end`, select `content` blocks with
  `type == "text"`, and **ignore `thinking` blocks**. Text blocks are joined; thinking is never
  emitted into the prime.
- **Failure is explicit:** non-zero exit, timeout, unparseable events, or zero text blocks each
  produce a recorded reason. No role may silently return "".

### 3.2 What gets attached

`retrieval` yields hits with `path` and `start_line`/`end_line`. For each distinct path, top 6 by
score, attach the file with `@path` — but only if it is inside the repo and under a size cap
(256KB), so a symlink or a vendored blob cannot pull in something unexpected.

The prompt ALSO carries a bounded inline excerpt (`render_retrieval_section`, unchanged), so an agent
that ignores the attachments still has the evidence. Attachments are the depth; inline is the floor.

Attachments are passed as **paths relative to the repo root, with `cwd=repo_root`**, never as
absolute paths, so a hit that somehow escaped the tree cannot be read.

### 3.3 Instructions, in full

Each role gets a long, explicit system prompt written as an operating brief — not a one-liner. The
Elephant brief states its authority (advisory only), what it must do (read the attached evidence,
say what this session already settled that changes the reading, mark contradictions against the
evidence, never restate), what it must not do (no instructions, no authorization, no secrets, no
invented facts), and its output shape with a hard word cap.

The Goldfish brief carries Google's three steps as three distinct calls with their own instructions
(comprehension → antagonistic → readiness), and states the isolation rule: it has no session, must
not assume one, and must say "the material does not cover this" rather than filling the gap.

### 3.4 Fix the reviewer budget (the measured defect)

- Reviewer `max_tokens` becomes a function of the **role's output need**, not the section cap:
  `REVIEW_MAX_TOKENS` (default 2,048) covering reasoning plus answer, with the section cap applied to
  the *emitted* text afterwards. The cap governs what we keep, not what the model may think.
- `finish_reason=length` becomes a **budget error that stops the walk** rather than a reason to try
  the next transport: the remaining steps would fail identically, so retrying only multiplies latency.
- With `pi`, the same rule applies per invocation.

### 3.5 Independence stays enforced

`plan_reviewer_model` is unchanged in principle but its input changes: the reviewer's model is what
`pi` will be told to use. If that resolves to the drafter's model, the review is refused exactly as
now — the EGM rule does not relax because the runtime changed.

## 4. Tasks

- [ ] `src/rag/rag.py`: add `pi_agent_call(...)` — builds argv, runs with a timeout, parses
      `--mode json`, extracts text blocks only, returns `{text, source, model, duration_ms, error}`.
- [ ] `src/rag/rag.py`: attach-file selection (`_attach_paths_from_hits`) with the in-repo + size-cap
      guards and a deterministic order.
- [ ] `src/rag/rag.py`: rewrite `elephant_synthesize` and `goldfish_review` to call `pi_agent_call`,
      with the full role instructions and the attached files.
- [ ] `src/rag/rag.py`: `REVIEW_MAX_TOKENS` + stop-the-walk on truncation.
- [ ] Detect `pi` availability once; if absent, fall back to the in-process driver with a recorded
      reason (never fail the whole call).
- [ ] Tests: argv construction, thinking-block exclusion, attachment guards (escaping path, oversize),
      truncation stops the walk, `pi` absent → recorded fallback, refusal still fires on same-model.
- [ ] `scripts/test-pqc-dist.sh`: assertions for the above.
- [ ] `llms.txt` + `AGENTS.md` (stay ≤160 lines): state that the roles run as `pi` agents with
      attached files, and that a missing `pi` degrades with a reason.

## 5. Gates

- **No thinking text in the prime.** A test feeds a response containing both a `thinking` and a
  `text` block and asserts only the text reaches the output.
- **No path escapes the repo.** A hit whose path is absolute or `../` is never attached.
- **Truncation costs one call, not four.** A stubbed `finish_reason=length` must stop the walk.
- **`pi` absent never breaks `--context`.** The prime still returns orientation + retrieval + a
  recorded reason.
- **Same-model review is still refused**, now when the *pi* reviewer would be the drafter.

## 6. Verification

- `pytest src/rag/tests` green; `bash scripts/test-pqc-dist.sh` green (baseline first).
- Live `--context` end-to-end: four sections, both roles served by `pi`, attachments present, and the
  wall time measured against the 41.6s baseline.
- Live: the reviewer's comprehension step shows it actually read the attached file (a detail that is
  only in the file, not in the inline excerpt).

## 7. Open

- **`pi` reads attached files with its own tokenizer**, so attachment size drives latency. 7.4k input
  tokens took 7.4s on this host. Six attachments is the cap chosen here; if a real vault page is large
  the cost rises linearly and the cap may need lowering.
- **`pi`'s `thinking` blocks are billable output** and are discarded. That is the price of a reasoning
  model behind a text interface; `thinkingLevel` is configurable in `pi` and could be lowered for the
  reviewer role if cost matters.
