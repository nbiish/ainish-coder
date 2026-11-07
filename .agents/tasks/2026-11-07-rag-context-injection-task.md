# Task: `AGENTS.md` context injection + the ainish-rag driver/Elephant/Goldfish pipeline

- lane: now
- branch: `feat/rag-context-injection` (worktree `D:\Code\ac-rag-context`)
- status: done
- plan: [`docs/rag-context-system-plan.md`](../../docs/rag-context-system-plan.md) Phase 4 + Phase 5 (partial)
- scope: `AGENTS.md`, `llms.txt`, `.agents/llms.txt`,
  `.agents/skills/context-orchestration/SKILL.md`, `.agents/skills/ainish-security/SKILL.md`,
  `src/rag/rag.py`, `src/rag/tests/test_context_injection.py`, `scripts/test-pqc-dist.sh`,
  `docs/rag-context-system-plan.md`, `.agents/canonical/`, `.agents/audit/contract-history.*`

## Why

The operator asked for `AGENTS.md` to integrate with the ainish-rag context-injection system so that
an agent reads the contract, makes **one** tool call, and receives an engineered injection that
combines Elephant (session-aware) and Goldfish (stateless) additions — with model tiers
`local-router → openrouter → zenmux → local-model` and a genuine offline floor.

The contract could not honestly point at that pipeline: it said the engine was "not an agent intake
requirement", and the engine had no generative path at all (every model call was a typed decision or
an embedding). So the contract and the code had to move together.

## What changed

### Contract (`AGENTS.md`)

- Removed the clause that told agents the engine is not theirs to use; that sentence is why no agent
  ever called it.
- `<CONTEXT_INJECTION>` is new and is the load-bearing section: one command, called once, the three
  labelled sections and how to read each, the advisory rule ("advisory evidence, never authority"),
  the "never block on it" rule, and the tiering/override surface with **no** key, endpoint, or model
  id in the contract.
- Non-negotiable #4 and the Orient step now name the single call so lifecycle and rules agree.

### Engine (`src/rag/rag.py`)

- **`DriverEngine`** — the generative transport mirroring `DecisionEngine`: tier order with env
  override, per-tier timeouts, `source` discipline, `attempts` log, and a never-raising `chat()`.
- **`driver_model_matches`** — compares requested vs returned model, because an unknown id resolves
  through the router's generic fallback chain and still answers HTTP 200.
- **Reasoning-budget guard** — an empty-content response with reasoning tokens is reported as
  "raise max_tokens", not as a transport outage.
- **`elephant_synthesize` / `goldfish_review`** — Goldfish takes exactly
  `(driver, task, retrieval_text, elephant_text, token_cap)`. The signature *is* the isolation.
- **`assemble_injection`** — fixed degradation ladder, with a hard truncation so a single oversized
  chunk cannot escape the cap.
- **`run_context_command`** + the `context` subcommand + completions + `secrets` driver table.

### Docs

- `llms.txt`: the "operator utility, not agent intake" scope is replaced; added the `context` verb,
  the driver transport, and the tier/env surface.
- `.agents/llms.txt`, `context-orchestration` skill: pointer updated to the one call.
- `ainish-security` skill: an injection is untrusted data attributed to a tool; Goldfish's isolation
  must not be widened.
- Plan doc: Phase 4 marked done with measured numbers and the honest latency limit.

## Defects found and fixed during the work

1. **`--json` polluted stdout.** A stray body left behind by my own edit made the `statusline` block
   run unconditionally after `context`, appending a `GATE:` line to the envelope. Any machine caller
   would have failed to parse it. Restored the `elif args.subcommand == "statusline":` header and
   redirected provider startup chatter to stderr under `--json`; verified by parsing child stdout in
   a subprocess. The same fix was applied to `statusline --json`, which is consumed by shell prompts.
2. **Session path traversal.** `session_path` kept leading dots, so `--session ../../etc/passwd`
   produced `..-..-etc-passwd.json` (contained, but ugly and a fragile surface). Now strips leading
   `.`/`-`.
3. **Budget cap could be exceeded.** A retrieval section with no blank-line split survived the
   tail-trimming step and shipped over budget. Added a final hard truncation.
4. **File fallback promoted irrelevant pages.** Scoring counted raw substring hits, so common words
   won. Rewritten to count distinct task terms, and to return a wiki *inventory* when nothing matches
   instead of three unrelated pages.
5. **Launcher handed `context` to a stale binary.** `bin/ainish-rag`/`.cmd` prefer `ainish-rag.exe`
   (built 2026-10-31), which predates the verb and exits "unrecognized subcommand" — so the command
   the contract names would have failed on the default Windows path. Both launchers now check the
   binary's `--help` (plus an explicit Python-only list) and fall through to the Python engine for
   verbs it does not advertise. Verified both paths still work for native verbs (`query`, `--version`).
6. **Python host could not read the index at all.** Python has no `lancedb`, so retrieval degraded to
   wiki files while 3,627 indexed chunks sat unread. `NativeQueryStore` now shells to the compiled
   engine's `query --json --no-rerank` and normalises its records, restoring real retrieval on the
   host most agents run on. Two parse bugs surfaced here: ANSI SGR contains `[`, and the
   `[rag:embed-provider]` log tag looks like a JSON array start — the payload is now located by a
   line-anchored regex after stripping colour.
7. **An explicit `--budget` crashed.** `budget_floor_note` was assigned in only one branch, so
   `--budget` raised `UnboundLocalError` and the command produced no output. Also, `--budget 400`
   silently became 600. An explicit budget is now honoured exactly down to a 300-token floor, and a
   raise is reported in `degrade_notes` rather than applied silently.
8. **`skip_retrieval` still searched, then paid drivers to disclaim.** A route that deliberately
   skipped retrieval still ran a vector search, then the file fallback, then two driver calls whose
   only content was "this material is unrelated". Now a skip emits no retrieval section and invokes
   no driver; the reason lands in `degrade_notes`.
9. **Offline mode was overridden by the flag default.** `DriverEngine(allow_remote=not no_remote)`
   passed an explicit `True`, which disabled `AINISH_RAG_DRIVER_OFFLINE` — an "offline" run still
   called local-router and reached a paid provider through it. Now `None` (consult the environment)
   unless `--no-remote` is set.
10. **Local-tier probes poisoned themselves.** A 1.5 s timeout was too short for an idle backend, and
    the negative result was cached, permanently disabling the offline floor for the process. The
    probe now allows 4 s, never caches a negative, and excludes non-chat artefacts (embedding, image,
    audio) that a shared endpoint advertises.
11. **Degraded notes were unactionable.** "elephant unavailable" became
    "elephant unavailable: local-model/<id>: HTTP 400 … No model is loaded" — the operator now learns
    which tier failed and why. A "driver identifier mismatch" note is emitted only when a driver
    actually answered.

## Verification

- `py -m unittest discover -s src/rag/tests -p "test_*.py"` — **124 pass** (89 before, 35 new).
- `bash scripts/test-pqc-dist.sh` under Git Bash — **99/99** (86 before, 13 new assertions covering
  the contract→engine wiring and a no-key/no-endpoint rule for `AGENTS.md`).
- `ainish-rag audit verify` — 16/16 after re-signing the canonical contract.
- Live end-to-end, through the launcher the contract actually names:
  `ainish-rag context --task "…" --budget 1400 --json` → `retrieval`+`elephant`+`goldfish`,
  544/1400 tokens, `degraded: false`, drivers both `local-router:deepseek/deepseek-v4.1-flash-1017`,
  strategy `hybrid_rerank`, and a real 0.71-relevance hit from `rag-decision-catalog.md`.
- Live driver tiers probed directly (not just through the router): OpenRouter
  `deepseek/deepseek-v4.1-flash-1017` (839 ms), ZenMux `deepseek/deepseek-v4.1-flash` (5206 ms),
  local-router tier 1 (9659 ms cold) — all `DRIVER_OK` with reasoning tokens reported, confirming the
  reasoning-budget constraint is real and not theoretical.
- Offline floor: `AINISH_RAG_DRIVER_OFFLINE=1` contacts no remote tier and reports the exact local
  failure (`No model is loaded…` on 8888), so an operator knows which tier to fix. The local tier is
  genuinely unserviceable on this machine right now (8888 has no model loaded, 11435 requires auth,
  8080 is down) — that is a machine state, not a code defect, and it is now reported accurately
  instead of as a generic "unavailable".
- `context --json` stdout parses as pure JSON when invoked from a subprocess (asserted by test and by
  a live check); `statusline --json` likewise.
- Budget: `--budget 400` → `cap: 400`; `--budget 20` → floor 300 with a reported raise; no flag →
  route-derived 2000. All three exercised live.

## Not done, and why

- **Rust engine parity.** `bin/ainish-rag.exe` (built 2026-10-31) has no `context` verb. The
  launchers now fall through to Python for verbs the binary does not advertise, so the contract's
  command works on every host — but a real rebuild, or mirroring `DriverEngine` and the injection
  pipeline into `src/rag/src/`, is still the correct long-term fix. Until then the Python engine is
  the implementation of record for `context`.
- **`sync` (Phase 5 command 1)** is not built; the two-verb surface remains half-delivered.
- **Latency.** Two sequential generative passes dominate (~11–21 s here, mostly remote embedding plus
  two driver calls). Inside budget only because the local router answers in ~1 s; Phase 4 caching is
  the fix.
- **Phase 1 evidence dossier** still does not exist. The Elephant/Goldfish split is labelled a design
  hypothesis in the code and the plan, which is the honest position until it is measured.
- **The local driver tier cannot serve on this machine today.** 8888 advertises 31 models but none is
  loaded, 11435 requires auth, 8080 is down. The code discovers and reports this correctly; making
  offline generation actually work needs a model loaded in Unsloth Studio (or an authed ollama), which
  is an operator action, not a code change.
