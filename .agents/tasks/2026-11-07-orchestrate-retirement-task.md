# Task: retire orchestrate-subagent-masters and align with the local-router/PQC updates

- lane: now
- branch: `chore/retire-orchestrate-and-lr-sync` (worktree `D:\Code\ac-orch-removal`)
- status: done
- scope: `.agents/skills/orchestrate-subagent-masters/` (deleted), `.agents/skills/llms.txt`,
  `.agents/skills/gstack-coder/SKILL.md`, `.agents/skills/ainish-security/`,
  `src/skills_selection.sh`, `src/deploy_skills.sh`, `src/help.sh`, `src/rag/rag.py`,
  `src/rag/tests/test_context_injection.py`, `scripts/test-pqc-dist.sh`, `.agents/canonical/`,
  `.agents/audit/`

## Why

The operator deleted `orchestrate-subagent-masters` and asked to complete the removal, and reported
PQC and model-serving updates from `~/code-external/local-router`.

**Path note:** `~/code-external/local-router` does not exist on this machine — only
`goal-first-trillion` is under `~/code-external`. The live checkout with those updates is
`D:\Code\local-router` at `4390f72`, and the work its comms entry describes (cryptography floor 47,
off-PATH `uv` resolution, reasoning capability advertisement and passthrough) is already merged into
`ainish-coder` at `bb502d3`. So this pass *verified the effects* rather than re-applying them.

## What changed

### Removing the pack was four edits, not one

Deleting the directory removed it from source. Four other surfaces still pointed at it:

| Surface | State found | Fixed |
|---|---|---|
| `.agents/skills/llms.txt` | Still recommended the *already-retired* `context-orchestration` and listed it in the child index | Rewritten; retirement documented |
| `gstack-coder/SKILL.md` | Recommended pairing with it in the description and twice in the body | Replaced with "call `dsh` directly; no pack required" |
| `src/deploy_skills.sh` / `src/skills_selection.sh` | Named `orchestrate-subagent-masters` but **never** `context-orchestration` | Both retired names now in both lists |
| `src/help.sh` | Claimed 20 packs including three that no longer exist (`browser-harness`, `camofox-stack`, `skyvern`), omitting five real ones | Now lists the actual 18 and marks both mandatory packs |

The `context-orchestration` gap was a defect from my previous pass: retiring a pack without adding
it to the cleanup lists means any target already carrying a copy keeps it forever. A retirement that
only works for repos created afterwards is not a retirement.

`AGENTS-TTS-COMMS.txt` also names the skill and was **deliberately left alone** — it is an
append-only transcript of past `cli-tts` output, so editing it to match current state would falsify
a historical ledger. It is a log, not an instruction surface.

### Truncated driver responses now fail closed

This is the real finding from the local-router update. Reasoning tokens now pass through and consume
the same budget as the answer, which makes `finish_reason: length` far more likely than before. The
driver accepted any non-empty content as success, so a response cut mid-sentence was concatenated
into the injection as though it were a complete Elephant draft.

Measured: `max_tokens=16` returned `'Thorough testing is essential'` with
`finish_reason: length` and non-empty content.

`_post_chat` now raises on truncation, naming the reasoning-token count, and surfaces
`finish_reason` on success. Verified the default 900 budget does not truncate real
Elephant-shaped prompts (117 completion tokens, `finish_reason: stop`).

### Corrected the cryptography floor

My consolidated `code-and-infrastructure.md` claimed `pyca/cryptography >= 45` for ML-DSA. The
`asymmetric.mlkem` / `.mldsa` modules ship from **47.0** — which is precisely the defect that made
`pqc-secrets` fully dead in WSL. Verified empirically: 45.0.7 and 46.0.5 import-fail, 47+ works.
Corrected in both the reference and the `SKILL.md` PQC section, stated as a verified fact with the
failure mode named.

## Verification

- `py -m unittest discover -s src/rag/tests` — **145 pass** (3 new: truncation raises, `finish_reason`
  surfaced on success, reasoning-only stays a budget error, not a transport error).
- `bash scripts/test-pqc-dist.sh` — **136/136** (5 new: the fifth retired pack absent, no live
  surface still recommending it, skills index documenting the retirement, deploy sweep naming
  `context-orchestration`, selection exclusion naming it).
- `ainish-rag audit verify` — 16/16 after re-signing.
- Live `context` through the updated router: `orientation, retrieval, elephant, goldfish`, drivers
  `local-router:mimo-v2.6-pro`, `degraded: false`.
- All ten driver chain steps confirmed reachable against the updated router.
- Reasoning passthrough observed on the wire: message keys are
  `role, content, reasoning_content, tool_calls` — the engine reads `content` and is unaffected.

## Not done, and why

- **`~/code-external/local-router` was not inspected** because it does not exist here. If that is a
  new checkout the operator intends as canonical, the path should be confirmed before anything reads
  it — the working tree at `D:\Code\local-router` is what is actually serving on this machine.
- **`AGENTS-TTS-COMMS.txt` left unedited**, per the reasoning above.
- **The compiled `bin/ainish-rag.exe` still predates the driver chain and the truncation guard.**
  Its `secrets` output has no chain table. The launcher falls through to Python for verbs the binary
  does not advertise, but `secrets` *is* advertised, so that particular report comes from the stale
  binary. A rebuild is the fix; it is a gitignored artifact and outside this change.
