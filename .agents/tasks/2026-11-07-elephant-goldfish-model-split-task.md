# Task: Elephant and Goldfish as two distinct model calls

- lane: now
- branch: `feat/elephant-goldfish-model-split` (worktree `D:\Code\ac-eg-roles`)
- status: done
- scope: `src/rag/rag.py`, `src/rag/tests/test_context_injection.py`, `AGENTS.md`, `llms.txt`,
  `scripts/test-pqc-dist.sh`, `.agents/canonical/`, `.agents/audit/`

## What was already true, and what was not

The request was to implement Elephant and Goldfish as two different AI API calls. **Two separate
calls already existed** — `elephant_synthesize` and `goldfish_review` each called `driver.chat`
independently, with their own system prompt and their own request body, and the two outputs were
already concatenated into the injection alongside `orientation` and `retrieval`.

What did **not** exist was two different *models*. Both roles walked the same chain and, on a healthy
run, landed on the same one:

```
elephant -> local-router:mimo-v2.6-pro
goldfish -> local-router:mimo-v2.6-pro     distinct_models: False
```

That is one opinion purchased twice. A reviewer running the drafter's own model shares its blind
spots and is biased toward agreement, so the second call costs latency and tokens while adding no
independence. **The gap was model separation, not call separation** — and that is what this change
implements.

## What changed

`DriverEngine.chat(..., role=)` and `chain_steps(role)` scope the chain per role:

| Role | Default starting step | Why |
|---|---|---|
| Elephant (drafter) | chain head | It leads; no reason to move it |
| Goldfish (reviewer) | a later step, **preferring a different transport** | Independence is the whole point |

An explicit pin wins over the rotation:

- `--elephant-model <id>` / `--goldfish-model <id>` on `context`
- `AINISH_RAG_ELEPHANT_MODEL` / `AINISH_RAG_GOLDFISH_MODEL` (the `_DRIVER_MODEL` spelling also resolves)

Rotation **never shortens the chain** — the wrapped tail follows, so a failing first choice still
reaches every model. Pins are resolved inside `chain_steps` rather than in `chat`, so the report and
the call cannot disagree about what a role will be sent.

## The defect that made the design work

A positional rotation ("start Goldfish at Elephant's next step") was tried first and failed in a way
worth recording. The chain head is `local-router/fallback-models` — a *route* whose model is unknown
until it replies — and the next step, `xiaomi-mimo-mimo-v2.6-pro`, happened to resolve to the same
underlying model and then failed, falling back onto the same `mimo` again:

```
goldfish requested xiaomi-mimo-mimo-v2.6-pro, failed 1 step, answered as mimo-v2.6-pro
=> distinct_models: False
```

Preferring a **different transport** fixes it, because a router route cannot return a model served
directly by another provider. Measured after the fix:

```
elephant -> local-router:mimo-v2.6-pro                               (0 failed steps)
goldfish -> nous-portal:deepseek/deepseek-v4.1-flash-1017            (0 failed steps)
distinct_models: True
```

## Honesty machinery, which earned its place during development

`provenance.drivers` now reports `elephant`, `goldfish`, both `requested_model`s and
`distinct_models`, and the rendered envelope carries a line like:

```
<!-- pair: elephant=local-router:mimo-v2.6-pro | goldfish=nous-portal:deepseek/… | distinct models -->
```

When the fallback collapsed both roles onto one model, that line read `SAME MODEL (reviewer shares
the drafter bias)` — the failure was visible instead of being presented as a second opinion. That is
the difference between *reporting* a pair and *claiming* one.

`ainish-rag secrets` prints both role chains with their override variable, and warns when they start
on the same model.

## Verification

- `py -m unittest discover -s src/rag/tests` — **157 pass** (11 new in `RoleModelSeparationTest`:
  rotation prefers a different transport, rotation preserves the chain, Elephant is not rotated, both
  pin spellings resolve, a pin keeps the chain's transports, an unknown role is inert, the offline
  floor holds for both roles, `chat` reports its role, and the end-to-end claim that two roles request
  different ids).
- `bash scripts/test-pqc-dist.sh` — **147/147** (8 new assertions covering role scoping, rotation, both
  pins, provenance, the render line, the CLI flag, and the contract text).
- `ainish-rag audit verify` — 16/16 after re-signing.
- Live: distinct models on both roles, `model_verified` true, zero failed steps; explicit
  `--elephant-model` / `--goldfish-model` pins verified end to end.

## One bug found in my own edit

Re-indenting `run_context_command` to add the scoped-pin `try/finally` left the session-roll-forward
block outside the `if` that defines `elephant`, producing `UnboundLocalError` on every
`retrieval_only` and `skip_retrieval` path. Caught by the existing budget tests, not by the new ones.
The `finally` also restores each role env var exactly, so a CLI pin cannot leak into a later call in
the same process.

## Not done, and why

- **The prompt design is unchanged.** Both roles still get their own system prompt and the same
  retrieval excerpt; only the model choice is new. Changing what each role *sees* is a separate,
  evidence-dependent question — `docs/rag-context-system-plan.md` Phase 1 is still the arbiter of
  whether the two-agent split earns its cost.
- **`distinct_models` reflects the answer, not the request.** Two different transports can still
  resolve to the same family. The field reports what happened, which is the honest signal.
