---
format: ainish/context-digest/v1
folder: memories
period: 2026-11+
records_consolidated: 2
consolidated_at: 2026-11-21T18:26:22Z
sources:
  - 2026-11-07-memory.txt
  - 2026-11-14-00-memory.md
---

# Digest — `.agents/memories`, 2026-11+

This digest replaces 2 record(s) from 2026-11-07 and 2026-11-14. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.

## Accomplished

The arc of this period: the `ainish-rag` retrieval engine was wired into the agent contract as
agent intake — the change that gave it callers at all — the Elephant/Goldfish two-agent review
pattern was built on top of it and hardened (isolation, model identity, budget/truncation
robustness, honest reporting), and by 2026-11-14 both roles ran as `pi` agents over the operator's
four-step driver chain. Record convention held across both sources: dated `{date}-memory.*` files
pairing with the same-day `../comms/{date}-team.*` ledger (`2026-11-07-memory.txt` pairs with
`../comms/2026-11-07-team.txt`; `2026-11-14-00-memory.md` with `../comms/2026-11-14-team.md`),
format law `AGENTS.md <REPO_MEMORY>`.

- **Retrieval wired into the contract** (`2026-11-07-memory.txt`). The `AGENTS.md` sentence calling
  the engine "not an agent intake requirement" — the reason the pipeline had no callers — was
  removed, and every "operator utility, not agent intake" phrasing across `llms.txt`,
  `.agents/llms.txt` and the context-orchestration skill was rewritten in the same commit, so no
  closer doc could re-forbid what the rail permitted.
- **Elephant/Goldfish review implemented and hardened** (`2026-11-07-memory.txt`).
  `goldfish_review(driver, task, retrieval_text, elephant_text, token_cap)` carries isolation in
  its signature (no session, history, memory or comms reachable from its body); `ainish-rag
  context` mechanises the retrieval and both model passes, replacing the `context-orchestration`
  hand routine while keeping the readiness judgement. A stray edit that deleted an `elif` header
  made a subcommand body run unconditionally and append `GATE:` to every `--json` envelope — fixed
  by asserting the child's stdout parses as JSON rather than eyeballing output. The contract's
  documented spelling `ainish-rag --context` was made real by a one-line argv normalisation,
  scoped to a leading occurrence so unknown options still fail as unknown options.
- **Reviewer independence settled** (`2026-11-07-memory.txt`, `2026-11-14-00-memory.md`). The
  default is a same-model, fresh-context reviewer — `--no-session` is what makes the fresh-reader
  rule structural — and `--goldfish-model` pins a distinct model when wanted, with provenance
  `fresh-context` otherwise. A positional "the chain's next step" skip had collapsed two steps onto
  one model (the chain head resolves at reply time and the next step hit the same underlying
  model); the recorded shape is prefer-a-different-transport plus honest reporting
  (`distinct_models: false` and a "SAME MODEL" line). Reporting that editorialised against the
  chosen default ("SAME MODEL, reviewer shares the drafter bias") was itself fixed to describe
  rather than condemn.
- **AGENTS.md cut from 208 to 90 lines** (`2026-11-07-memory.txt`) — model ids and mechanics moved
  behind a where-to-look table, since the test for a line in an always-read file is "does reading
  it change what the agent does next", and length is now a gate assertion. Shortening exposed a
  dangling pointer: the old file never linked `.agents/llms.txt` and a default `--rules` deploy
  never shipped it; every link a shortened doc introduces is now checked against what deploy
  copies, in a clean target.
- **Driver chain shaped per consumer** (`2026-11-07-memory.txt`, `2026-11-14-00-memory.md`). The
  consumer's order lives in `ainish-rag`'s `DRIVER_CHAIN`, with the shared
  `local-router/fallback-models` chain as one deliberate step marked `expect_any` and pinned steps
  after it. By 2026-11-13 the chain is the operator's four DIRECT transports: `local-router` →
  `local-router/fallback-models` @ http://127.0.0.1:11434; `zai` → `glm-5.3-flash` @
  https://api.z.ai/api/coding/paas/v4; `xiaomi-mimo` → `mimo-v2.6-pro` @
  https://token-plan-sgp.xiaomimimo.com/v1; `openrouter` →
  `deepseek/deepseek-v4.1-flash-1017` @ https://openrouter.ai/api/v1; then the local-model floor.
  Nous Portal, Nebius and ZenMux are out of the default chain (reachable only by explicit pin).
- **EGM roles moved onto `pi` agents** (`2026-11-14-00-memory.md`):
  `pi --print --no-session --no-tools --mode json --thinking <level> --model <id>
  --append-system-prompt <brief> @file...`. Engine transports are translated to pi-qualified ids
  in `PI_MODEL_IDS`; `pi_agent_call` retries the router's intermittent empty response once and
  reports `attempts_made`; `served_model` is captured from pi's `message_end`; the per-call ceiling
  is 90s (`AINISH_RAG_PI_TIMEOUT`); both roles run `--thinking off` on the router.
- **Pack deployment made consistent** (`2026-11-07-memory.txt`). `pqc-secrets` had been excluded
  from the selector and therefore never deployed, although the contract resolves every secret
  through it. The durable shape landed: two predicates (excluded-from-selection and mandatory) plus
  one shared list every path (deploy, verify, status, sync) consults. Follow-ons recorded: a
  mandatory pack must MIRROR rather than merge (a file deleted upstream otherwise survives and the
  deployed copy stops matching its signed digest), and because `deploy_path_contents` reads the
  no-overwrite flag from the environment, the flag must be bypassed at the copy layer too, not just
  by an outer exemption.
- **Security consolidated from four packs into one** (`2026-11-07-memory.txt`). Splitting security
  across four packs had made the reader classify "code" vs "AI" before rules could apply; the only
  cross-domain file was an 88-line summary the common case never got past; two of the four packs
  were byte-identical duplicates of files they were copied from and one pointed readers at a path
  inside another pack. One instructional stating the domain-independent rules plus progressive
  references for depth replaced the split. (This is the security-pack split — separate from the
  `context-orchestration` retirement, which was a different problem: a procedure nothing
  executed.)
- **Pack retirements swept across all surfaces** (`2026-11-07-memory.txt`). `orchestrate-subagent-masters`
  was still pointed at from four surfaces after its directory was deleted — the skills index, a
  sibling skill's description and body (three places), the deploy/selection cleanup lists, and the
  help text's pack inventory. A retired name now enters two lists (deploy sweep and selection
  exclusion) in the same commit that deletes the directory, with a gate assertion that no live
  surface still recommends it (retirement-marked mentions are fine; a bare "pair with X skill" is
  not). The earlier `context-orchestration` retirement had never been added to the cleanup lists,
  so it would have survived in any pre-existing target.
- **Doc-drift gate added** (`2026-11-07-memory.txt`). README had advertised three deleted packs,
  omitted four that existed, listed two that never existed, and its pack count was wrong by four —
  invisible for weeks because nothing broke. A gate now asserts every `.agents/skills/<name>/`
  mentioned in README, the skills index, `help.sh` and `llms.txt` resolves to a real directory; it
  was proved against an injected fake reference before being trusted.
- **Diagnostics de-confounded** (`2026-11-07-memory.txt`). Six "dead" providers were one bug: a
  fixed `/v1/chat/completions` suffix appended to inconsistently-terminated provider bases
  produced `/api/v1/v1/...`, and the reachability probe shared the hardcoded suffix so the
  diagnostic agreed with the bug. The zero-hit query path now carries a reason string (no binary /
  non-zero exit with the engine's own stderr / no output / no JSON / no hits) in `degrade_notes`
  instead of collapsing every failure into `native_engine_empty`.

## Unfinished

- **The Elephant/Goldfish split is an unmeasured hypothesis** (`2026-11-07-memory.txt`). It leans
  on two published effects — a fresh-context reviewer catching what an incremental one misses, and
  adversarial critique-then-revise improving output — but the specific two-agent topology is
  unmeasured on this corpus. Saying so in the code, the plan and the contract is what keeps
  "advisory" honest and keeps Phase 1 able to invalidate the design instead of quietly ratifying
  it. Nothing in this period ran that measurement.
- **The direct-transport chain steps have not run for real on this host** (`2026-11-14-00-memory.md`).
  The PQC vault is locked: `_pqc_export()` returns 0 entries and `resolve_driver_key` returns None
  for every direct transport, so steps 2–4 skip with "no API key resolved" (`pqc-secrets export
  --json` prompts for a passphrase when locked). The vendor steps are configured but unexercised;
  faking keys with env vars would prove nothing about the real path.
- **Several fixes are prescribed in the records without a landing confirmation**
  (`2026-11-07-memory.txt`): checking `finish_reason` and raising on `length` (the driver accepted
  any non-empty content as success, so a mid-sentence cut was concatenated into the injection as a
  complete Elephant draft); passing `encoding="utf-8"` / `errors="replace"` explicitly to any
  subprocess whose output is parsed; routing report verbs like `secrets` to the Python engine of
  record via the `PY_ONLY_SUBCOMMANDS` list (the Rust binary printed a shorter report that read as
  a removed feature); and deriving probe URLs from the same function that builds request URLs. Each
  remedy is stated in imperative form; the records do not confirm the change landed — verify in
  code before relying on any of them.

## Insights

- **A contract nobody calls is a contract nobody follows** (`2026-11-07-memory.txt`): a capability
  the always-on rail tells you to skip is dead regardless of quality. When wiring a tool into the
  contract, the load-bearing change is usually the removal of a disclaimer — and every phrasing
  that contradicts it must change in the same commit.
- **HTTP 200 proves nothing about which model answered** (`2026-11-07-memory.txt`,
  `2026-11-14-00-memory.md`): the local-router resolves an unknown id through its shared
  `fallback-models` chain and returns 200 with a different model. The only durable signal is
  comparing `response.model` to the request — with care: the router-facing id is `openrouter-<id>`
  while the provider answers `deepseek/<id>`, and router answers come back provider-stripped
  (`xiaomi-mimo-mimo-v2.6-pro` → `mimo-v2.6-pro`, `zai-glm-5.3-flash` → `glm-5.3-flash`), so
  matching must strip decorations without collapsing a snapshot suffix (`-1017` is a different
  model, not a formatting variant). A chain step's NAME is not its TRANSPORT — pin the
  `(transport, id)` pairing in tests, never just the id list. A route whose model is unknown until
  it replies cannot be excluded by name or position.
- **Isolation must be a signature, not a comment** (`2026-11-07-memory.txt`): "we simply don't pass
  the session" is a comment the next refactor violates for convenience; a function whose parameter
  list makes session/history/memory unreachable is a shape a test can assert.
- **Every truncation point needs its own bounds** (`2026-11-07-memory.txt`,
  `2026-11-14-00-memory.md`): a budget ladder that trims by blank-line blocks cannot bound a single
  oversized chunk, so any such ladder needs a final hard truncation; a truncation that appends a
  marker must budget for the marker or the section exceeds the cap it was trimming to; and a
  reviewer must be handed its input WHOLE — a 3,000-char slice cut the subject mid-sentence and the
  reviewer spent a finding reporting that its own subject was incomplete.
- **Empty content with a reasoning count is a budget error, never a transport failure**
  (`2026-11-07-memory.txt`): `deepseek-v4.1-flash` is a reasoning model, so `max_tokens: 16`
  yields empty content and 16 reasoning tokens; misreading it sends the caller to a fallback tier
  for a problem the next tier reproduces. Related: once the router passed reasoning through,
  reasoning tokens eat the answer budget and `finish_reason: length` becomes likely — a cut
  mid-sentence accepted as success is half a thought presented as a whole one, invisible to
  everything downstream.
- **Call count is not independence — but same-model can still be a second opinion**
  (`2026-11-07-memory.txt`, `2026-11-14-00-memory.md`): two calls walking the same chain to the
  same model are one opinion. But the fresh-reader effect the pair actually relies on works on one
  model; a distinct model is the stronger version, not the definition. EGM requires a fresh
  reviewer CONTEXT (`--no-session`), not a distinct MODEL — conflating the two made distinct-model
  mandatory and pushed the reviewer onto a paid endpoint for no stated benefit. And a report that
  editorialises against the chosen default is a bug in the report.
- **A fallback order belongs to its consumer** (`2026-11-07-memory.txt`): local-router's
  `fallback-models` chain is shared with VS Code, Claude Code, Cline and every other client on the
  machine, so repointing it reroutes everything. Make it one deliberate step (`expect_any`, because
  whatever it picks is correct for that step) in the consumer's own order, with pinned steps after
  whose mismatch is a real signal. An offline mode that filters its chain down to nothing must keep
  the floor step, or it reports "no step configured" instead of the backend's real error.
- **Unattributed is not the same as unexplained** (`2026-11-07-memory.txt`): a line appended to
  `AGENTS.md` that the agent did not recognise was the operator's edit, and removing a human's
  content from the governing contract is a worse error than shipping it. Keep unexplained content
  and ask; strip only what is provably machine-generated output. "I don't recognise it" is not
  evidence of contamination.
- **Hidden from the prompt is not the same as not shipped** (`2026-11-07-memory.txt`): a pack can be
  invisible to the operator and still mandatory at runtime (`pqc-secrets` is exactly that — the
  contract resolves every secret through it). Keep excluded-from-selection and mandatory as two
  predicates over one shared list every path consults, or a pack is mandatory in one place and
  optional in another.
- **One wrong URL looks like six dead vendors** (`2026-11-07-memory.txt`): provider bases end
  inconsistently (`https://openrouter.ai/api/v1` vs `https://api.z.ai/api/coding/paas/v4`), so a
  fixed suffix yields `/api/v1/v1/...` — and a probe sharing the hardcoded suffix confirms the bug
  instead of catching it. When many independent integrations fail identically, suspect the shared
  code path before the vendors. And treat "reachable" as "the host answered HTTP at all", not "it
  served the catalogue I expected" — several providers 404 `/v1/models` while serving chat
  normally.
- **Four security packs, one domain, was a loading problem** (`2026-11-07-memory.txt`): the split
  forced a "code" vs "AI" classification before rules applied, and the tell was two byte-identical
  duplicate packs plus one dangling cross-pack pointer. One instructional plus progressive
  references removes the guess. (This is separate from `context-orchestration`, whose problem was
  different: it prescribed by hand what `ainish-rag context` already did automatically.)
- **A procedure nothing executes is not a control** (`2026-11-07-memory.txt`): documentation that
  prescribes by hand what a tool does automatically gets skimmed, not followed. Keep what only
  judgement can do (decide readiness); mechanise what is merely state (branch, worktree, tree
  state, COMMS, task record). Mechanics: the shared-state root is not the working directory — git
  state must be read from cwd, or orientation confidently reports `main` from a worktree, the exact
  fact the contract's first rule depends on.
- **`subprocess.run(text=True)` is a platform bet** (`2026-11-07-memory.txt`): it decodes with the
  platform default — cp1252 on Windows — and the crash surfaces as UnicodeDecodeError inside
  reader-thread cleanup while the process exits, nowhere near the offending read. A character whose
  UTF-8 third byte is 0x90 (U+2010 HYPHEN, U+0110) is undefined in cp1252 and raises. Pass
  `encoding="utf-8"` and `errors="replace"` explicitly; prefer bytes plus explicit decode when the
  payload matters.
- **Advertising a verb is not implementing its current contract** (`2026-11-07-memory.txt`): a
  launcher preferring a compiled binary for every verb handed `secrets` to the Rust engine, which
  prints a shorter report with no driver chain — output that read as a removed feature rather than
  a stale artifact. Route report verbs to the Python engine of record explicitly; don't infer
  readiness from `--help`. The same class: when a contract names an invocation, the spelling is
  interface — `ainish-rag context` documented vs `ainish-rag --context` natural, with argparse
  rejecting the latter at exit 2.
- **Shortening a file exposes what it was hiding** (`2026-11-07-memory.txt`): compressing a document
  concentrates its claims — decorative pointers become load-bearing and the never-true ones surface
  at once (the `.agents/llms.txt` link a default deploy never shipped). Check every link a
  shortened doc introduces against what the deploy actually copies, in a clean target.
- **A test that reads the environment is testing the environment** (`2026-11-07-memory.txt`): a
  role-separation test failed when the PQC store went from 24 keys to 1 and both roles legitimately
  converged on the router — and it had been failing on main, masked by an earlier green run before
  the keys disappeared. Assert the property the code owns (which chain step a role selects), not
  the downstream outcome that depends on credentials; key-store contents are ambient state.
- **A missing key is not a missing index** (`2026-11-07-memory.txt`): retrieval looked dead while
  every test passed — the store held 3627 records the whole time and vector search was returning a
  401. Unit tests prove code paths, a live call proves the wiring, and only a credential check
  proves the system can see anything. Falling back to local embeddings across vector spaces would
  have returned confidently wrong neighbours rather than an error. Same collapse one level up: zero
  hits can mean an empty index or a rejected credential — opposite remedies — so a function that
  collapses distinct failures into one empty value has moved the debugging cost onto whoever reads
  the result later.
- **`up` means the endpoint answered, not that the step will work** (`2026-11-14-00-memory.md`):
  OpenRouter serves its `/models` catalogue publicly with no auth, so `probe_health` reports `up`
  while the chat path would 401. When diagnosing a 401, check whether the key RESOLVED before
  believing the error text — a request with `Bearer None` yields a plausible "token
  expired/incorrect" from Z.AI and "Missing Authentication header" from OpenRouter, pointing at
  keys when the real cause is the locked vault.
- **pi mechanics** (`2026-11-14-00-memory.md`): pi resolves model ids against its own provider
  catalog, where a bare `glm-5.3-flash` is ambiguous across five providers and pi refuses rather
  than guessing — hence `PI_MODEL_IDS`. pi's cost is its agentic system prompt, not the payload: a
  one-word reply costs 6,904 input tokens at `--thinking high` and 56 at `off`, so thinking level
  is the lever and trimming the prompt is not. Attaching files beats inlining (the full vault page
  made a reviewer reason about provenance). `--thinking low` on the router can return a thinking
  block with no text at all (8.7s for nothing) — hence `--thinking off` for both roles. The router
  intermittently returns an EMPTY response (measured 1 in 3 on this host, no `message_end`), so one
  retry with `attempts_made` reporting is required or a third of primes silently lose a role while
  the envelope looks complete. A route cannot be verified from its request — capture `responseModel`
  from `message_end` as `served_model`. The 90s per-call ceiling names the timed-out step instead
  of stalling a prime for minutes. `--no-tools` stops a context call from acquiring authority.

## Recurring

- **Identity must be verified from the response, never the request or the status code** — the
  period's strongest pattern, four appearances: the router's 200-with-a-different-model
  (`2026-11-07-memory.txt`), step NAME ≠ TRANSPORT (`2026-11-14-00-memory.md`), a "next step" that
  resolved to the same underlying model as the chain head (`2026-11-07-memory.txt`), and the
  `served_model` capture without which "reviewed by the router" is uncheckable
  (`2026-11-14-00-memory.md`).
- **Truncation and budget overruns recur** — oversized chunks a blank-line-block trimmer cannot
  bound plus marker budgets (`2026-11-07-memory.txt`), `finish_reason: length` mid-sentence cuts
  (`2026-11-07-memory.txt`), reasoning tokens eating the answer budget (`2026-11-07-memory.txt`),
  and reviewer input sliced mid-thought (`2026-11-14-00-memory.md`). Every cap needs an over-cap
  story and every marker needs its own budget line.
- **Distinct failures collapsing into one misleading symptom** — empty content with a reasoning
  count (a budget error), zero hits (empty index vs rejected credential), a missing key read as a
  missing index (`2026-11-07-memory.txt`), and the router's 1-in-3 empty response
  (`2026-11-14-00-memory.md`). Carry a reason out of every early return; report `attempts_made`.
- **A probe or diagnostic that shares the bug confirms the bug** — the reachability probe with the
  same hardcoded URL suffix "verified" six false vendor failures, and `probe_health` semantics say
  `up` while chat 401s (`2026-11-07-memory.txt`, `2026-11-14-00-memory.md`). The paired lesson
  recurs too: prove a detector against an injected fake before trusting it — the doc-drift gate was
  tested that way, and the `--json` envelope bug was caught by asserting the child's stdout parses
  as JSON (`2026-11-07-memory.txt`).
- **Ambient host state masquerading as code failure** — the key store dropping from 24 keys to 1
  broke an environment-reading test (`2026-11-07-memory.txt`), the locked PQC vault silently skips
  every direct transport (`2026-11-14-00-memory.md`), and `text=True`'s platform-default decoding
  turns UTF-8 into a Windows crash (`2026-11-07-memory.txt`). Establish what the environment
  actually resolved before believing a failure.
- **Changing what is "on the rail" is a multi-surface sweep** — a retired pack still pointed at
  from four surfaces, and one capability's permitting/disclaiming phrasing spread across three
  documents (`2026-11-07-memory.txt`). The whole set changes in one commit, backed by an assertion
  that nothing still recommends the old state.
