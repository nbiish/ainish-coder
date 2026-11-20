2026-11-20-17-contract-internals-followups
# Follow-ups the contract-internals cleanup surfaced

## 1. `.agents/rag/` keeps the retired name

The contract no longer mentions it, but the directory is still where the engine writes its machine-local
state (graph cache, sessions, autolearn throttle, gate status). An agent listing `.agents/` sees `rag/`
and may assume a retrieval system it should reason about.

**Settled by:** renaming to `.agents/state/` or `.agents/cache/` with a one-release read-both fallback.
It is engine-internal, so the rename is safe — but it touches ~10 call sites and the gitignore.

## 2. The 159-line contract has one line of headroom

The gate is `<= 160`. The rewrite freed a line; the next addition has almost no room. That is a fair
place to be — the budget forced the internal description out — but the next task that needs a rule will
have to pay for it by compression.

**Settled by:** whether a rule is ever added without something being cut. If that happens, revisit
whether 160 is still the right number.

## 3. `llms.txt` still describes the prime and the engine in detail

`AGENTS.md` now says only what an agent must DO, but `llms.txt` — which the context call returns and
which an agent may open — still documents `DecisionEngine`, `DriverEngine`, the decision chain, and the
context envelope's internals. That is appropriate for a PRD and inappropriate as prompt surface if an
agent reads it whole.

**Settled by:** deciding whether `llms.txt` is documentation (fine as-is) or context (needs the same
treatment the contract just got). The answer probably depends on whether agents actually open it.

## 4. Nothing verifies that the contract is still true

The rewrites in the last three tasks all changed `AGENTS.md`, and each was verified by greps for phrases.
No test asserts that the contract's claims match behaviour — e.g. that `--context` still exists, that
`.agents/llms.txt` is still present, that the folders it names are real.

**Settled by:** a small assertion per named folder and per named command, so a contract that drifts from
the tree fails the suite rather than misleading an agent.
