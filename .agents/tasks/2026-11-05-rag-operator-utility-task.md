# Task: Refocus ainish-rag as an operator utility, not agent intake

- lane: now
- branch: docs/rag-operator-utility
- status: done
- scope: `AGENTS.md`, `.agents/canonical/AGENTS.md` (+ digest/signatures), `.agents/llms.txt`, `.agents/skills/context-orchestration/SKILL.md`, `llms.txt`
- objective: Stop presenting RAG as something agents are expected to intake. Reposition `ainish-rag` as the operator's own project utility (retrieval, wiki, audits, pre-merge checks) while keeping every command working.

## Why

The always-on contract told every agent to run `ainish-rag route` and `orient --inject` during orientation. In practice agents were not auto-intaking that context, so the instructions added a mandatory-sounding step nobody performed. That is worse than saying nothing: an agent either skips a stated obligation or burns turns producing retrieval context the operator did not ask for.

## Change

- `AGENTS.md`: replaced the orientation directive with an explicit statement that `.agents/rag/` and the engine are the operator's utility and *not* an agent intake requirement; `bin/context-packet.sh` remains available when a bounded summary is genuinely useful.
- `AGENTS.md` non-negotiable #4 and the lifecycle Orient step: now say "read the files the task needs" instead of "route the request".
- Context packet contract: dropped the router-derived fields from the list; the packet is now a bounded summary, not a routing artifact.
- `.agents/llms.txt`: removed "Route with `ainish-rag route`" from the local workflow; states the utility scope.
- `context-orchestration` skill: the "Route" phase became "Read", with an explicit note that `route`/`orient`/`eval`/`gate` are operator tools used on request and advisory when used.
- `llms.txt`: added a **Scope** paragraph to the RAG section fixing the intent in the repo's own PRD.

## What deliberately did not change

- No `ainish-rag` command, flag, or default was altered — `route`, `orient`, `query`, `wiki`, `gate`, `eval`, `bench`, `decide` all still work exactly as before.
- ML-DSA-65 manifest and contract signing still uses the compiled engine. Deployment provenance is a trust boundary, not retrieval, and was out of scope for this decision.
- `--rules` still runs embedding-provider detection (the operator chose docs-only scope).

## Compatibility

Documentation and prompt-contract only; no schema, CLI, or manifest change. Targets pick up the revised contract on their next rules refresh. Roll back by reverting this commit.

## Verification

- No agent-facing directive to run `route`/`orient` remains (`rg` over `AGENTS.md`, `.agents/llms.txt`, `context-orchestration/SKILL.md` returns nothing).
- `AGENTS.md` and `.agents/canonical/AGENTS.md` byte-identical; canonical contract re-signed with ML-DSA-65 threshold k=1; `audit verify` 16/16 receipts.
- `scripts/test-pqc-dist.sh` 57/57 PASS.
- Fleet: 3/3 targets CURRENT.

## Cleanup in the same change

- Deleted merged branch `fix/rules-skill-selection` and its worktree `D:\Code\ainish-coder-skills-select`.
- Removed the empty non-git leftover `D:\Code\ainish-coder-egm-master-memory`.
- Kept `D:\Code\ainish-coder-rules-smoke` enrolled as a live test target (verified CURRENT).
