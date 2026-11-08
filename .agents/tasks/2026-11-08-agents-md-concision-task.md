# Task: cut `AGENTS.md` to a rules file an agent reads without thinking

- lane: now
- branch: `chore/agents-md-concision` (worktree `D:\Code\ac-rules-slim`)
- status: done
- scope: `AGENTS.md`, `llms.txt`, `bin/ainish-coder`, `scripts/test-pqc-dist.sh`,
  `.agents/canonical/`, `.agents/audit/`

## Why

The file is read on **every task, by every agent, in every target**. That makes every line a
recurring cost. Roughly half of the 208 lines described things an agent cannot act on:

| Removed | Why it did not belong |
|---|---|
| The driver model chain and 8 provider names | The engine resolves them; the agent never chooses a model |
| The four-section envelope table + per-role pins | Engine internals; an agent reads the output, not its construction |
| The nine-master table | Definitions live in `.agents/templates/masters.md`, and `bin/context-packet.sh` already emits all nine inline |
| Machine-agnostic execution | Engine and deploy policy, not an agent instruction |
| Context-packet contract | Redundant once there is one context call |

The test applied to every line: not "is it true" but **"does reading it change what the agent does
next"**.

Result: **208 → 90 lines**, zero model or provider mentions, and the file opens with the one command.

## What it says now

```
1. Call ainish-rag --context --task "<the user's request or your current step>" once
2. Read the <CONTEXT_INJECTION> block, then open the files the task needs
3. Do the work; record it as you go
```

Plus the advisory and never-block rules, eleven one-line non-negotiables, a `Close` checklist, and a
table of where everything else lives — explicitly prefixed "Do not read ahead."

## Three findings that were not the point

### A default deploy never shipped what the contract now points at

`--rules` copied `AGENTS.md` and `llms.txt` but not `.agents/llms.txt`,
`.agents/templates/masters.md`, or `.agents/skills/llms.txt`. The old contract never linked to them,
so the omission was invisible. The moment the short contract said "read `.agents/llms.txt`", it
became a **dangling pointer in every target**.

Fixed: `--rules` now copies those contract surfaces alongside `AGENTS.md`. Verified in a clean repo —
zero missing links.

### `llms.txt` referenced four `AGENTS.md` sections that do not exist

`<DOCUMENT_MODEL>`, `<SERVERS>`, `<REPO_MEMORY>`, `<OUTPUT>` — five references total. Pre-existing and
unrelated to this cut, invisible because nothing asserted on them. All rewritten to state the rule
inline instead of pointing at a missing anchor.

### A short document makes its pointers load-bearing

Compression concentrates claims. Links that were decorative become load-bearing, and anything that was
never true surfaces immediately. That is why finding 1 only appeared after the cut.

## Verification

- `bash scripts/test-pqc-dist.sh` — **156/156**. Three new assertions: the contract names no model or
  provider, the contract stays under 120 lines, and `--rules` names every contract-linked `.agents`
  file.
- `py -m unittest discover -s src/rag/tests` — **164 pass**.
- `ainish-rag audit verify` — 16/16 after re-signing.
- Clean-repo `--rules` deploy: 90 contract lines, **0** model/provider mentions, **0** missing links.
- The nine masters still reach an agent through `bin/context-packet.sh` without appearing in the
  contract.

## Note on the gate assertions

13 assertions pinned strings in `AGENTS.md`, including the model chain that had to go. Each was
**re-decided**, not mechanically repointed: engine-fact assertions moved to `llms.txt`, and a new
assertion now enforces the *absence* of model names plus a line ceiling. A file that grows back into a
manual does so one reasonable-sounding section at a time, so length is worth asserting.
