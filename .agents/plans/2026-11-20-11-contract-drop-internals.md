---
plan_format: ainish/plan/v1
slug: contract-drop-internals
date: 2026-11-20
status: ready
branch: feat/contract-drop-internals
worktree: /Users/nbiish/code/contract-drop-internals
task_record: .agents/tasks/2026-11-20-11-contract-drop-internals.md
operator: direct-instruction
---

# Plan: the contract stops explaining the context system and names the folders instead

## 1. Problem

`AGENTS.md` describes how the context system works — a four-part prime, orientation, retrieval, an
elephant drafter, a goldfish reviewer, a background tuning pass, `provenance.harness`, retrieval
constants, and a sentence about there being no embeddings or vector store. An agent reading the
contract does not need any of it: it needs to know to call one command, and which `.agents/` folders
hold the record. The internal description is also where the retired vector vocabulary survived, so a
reader learns about a system that has been gone since 2026-11-12.

## 2. Anchor Facts

- Lines 23-26 describe the four-part prime including "no embeddings, no vector store" — the operator's
  flagged excerpt.
- Lines 28-33 describe the background tuning pass, `provenance.harness`, and "never hand-edit
  retrieval constants".
- Line 15 says the call "returns the rules, orientation, the relevant corpus, and two reviews".
- `AGENTS.md` is `uchg` at 444; an edit is refused until unlocked.
- The suite asserts `'one command is the whole context system'` (`:1414`) and `'Never call a second
  command to prime yourself'` (`:1416`) — both sentences are in the block being rewritten.
- `scripts/test-pqc-dist.sh:1119` already asserts the contract names no provider or model.
- Unrelated but found while reading: `src/context/engine.py:7642-7643` looks for
  `src/rag/master-surfaces.json`, which does not exist since the engine moved to `src/context/`.

## 3. Plan

### Goals

- The contract tells an agent what to DO and what to READ, not how the tool works.
- No embedding, vector, corpus, prime, retrieval-constant, or provenance vocabulary remains.
- The `.agents/` folders an agent should read are named in the contract.

### Non-goals

- Renaming `.agents/rag/` or changing engine internals: the operator chose the flagged-section scope.
- Changing the context engine's behaviour. This is a contract edit only.

### Constraints and invariants

- `AGENTS.md` stays at exactly 160 lines.
- Every non-negotiable and every pointer in "Where everything else lives" survives.
- The contract is re-signed, the chain verified, and the file re-locked.
- The `<CONTEXT_INJECTION>` evidence rule, the reviewer-independence rule, and the failure rule stay:
  they govern how an agent TREATS the output, which is a rule, not an implementation detail.

### Proposed architecture

```
before:  call once → "four-part prime over contract/llms.txt/wiki/.agents — no embeddings, no vector
         store: orientation and retrieval cost no model call, elephant reads..., goldfish comprehends..."
after:   call once → "it returns the rules plus the relevant record from .agents/. Read it, then open
         the files it names. One command; never a second to prime yourself."
```

### Interfaces and data

No interface changes. The rewritten section keeps: the command, the instruction to pass the request
verbatim, the folders to read, the one-command rule, the evidence-not-instruction rule, the
reviewer-independence rule, and the degraded-handling rule.

### Files and symbols

- `AGENTS.md` — lines 13-15 (Start-here bullet), 23-33 (the prime and tuning paragraphs), 43
  (`wiki_graph_empty` in the degraded list), 150 (`.agents/{rag,audit,canonical}/`).
- `.agents/canonical/AGENTS.md` — synced copy.
- `.agents/canonical/AGENTS.md.sha256`, `AGENTS.sig`, `AGENTS.threshold.sig` — re-signed.
- `scripts/test-pqc-dist.sh` — repoint the two assertions that pin removed sentences; add one that the
  removed vocabulary stays out.
- `src/context/engine.py` — the `src/rag/master-surfaces.json` path becomes `src/context/`.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Delete the words "no embeddings, no vector store" only | Leaves the prime, tuning, and provenance description, which is the same class of internal detail |
| Rewrite the whole contract | Every other section is already rule-shaped; a wholesale rewrite risks losing a rule for a style gain |
| Rename `.agents/rag/` in the same change | Broadens a contract edit into an engine change; recorded as a follow-up |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| A needed rule is lost with the prose | Every non-negotiable grepped after the edit; the suite has 407 assertions |
| Line count drifts off 160 | Check after the edit and adjust prose, never by deleting a rule |
| The locked contract silently refuses the write | Unlock first and verify writability, as the last task learned |
| An assertion pins a removed sentence | Repoint it to the RULE it was really protecting, not the wording |

## 4. Clarifications

### 4.1 How much internal detail leaves

- **Question:** Lines 23-26 describe the four-part prime; a later paragraph describes tuning and retrieval constants. How much goes?
- **Options:** 1. (Recommended) The flagged paragraphs plus the Start-here bullet; 2. also rename `.agents/rag/`; 3. only the embedding words.
- **Selected:** 1 — the flagged sections.
- **Trade-off accepted:** `.agents/rag/` keeps its name in the tree, so the old vocabulary survives in a path an agent may see. Recorded as a follow-up.

### 4.2 Naming the folders

- **Question:** Should the contract list the `.agents/` folders, or keep deferring to `.agents/llms.txt`?
- **Options:** 1. (Recommended) Name them; 2. keep the pointer only.
- **Selected:** 1 — name them.
- **Trade-off accepted:** A folder added later needs a contract edit, which is a 160-line-budget decision, not a silent drift.

## 5. Todos

- [ ] **T1** Unlock the contract and rewrite lines 13-15 and 23-33 so no internal mechanism is described.
  - from: §4 | done when: no `prime`/`corpus`/`embedding`/`vector`/`retrieval constant`/`provenance` remains | verify: grep
- [ ] **T2** Name the `.agents/` folders an agent should read, inside the same section.
  - from: §4.2 | done when: tasks, plans, comms, memories, suggestions, wiki all appear | verify: grep
- [ ] **T3** Clean the two incidental references: `wiki_graph_empty` in the degraded list and
  `{rag,audit,canonical}` at the bottom.
  - from: §3 | done when: neither string remains | verify: grep
- [ ] **T4** Sync the canonical copy, re-sign, verify the chain, relock.
  - from: §3 | done when: `audit contract --verify-history` passes and the file is `uchg` | verify: that command
- [ ] **T5** Repoint the two assertions and add one that the removed vocabulary stays out.
  - from: §5 | done when: suite passes at or above 407 | verify: `scripts/test-pqc-dist.sh`

## 6. Verification

- `scripts/test-pqc-dist.sh` — passes at or above 407 assertions.
- `wc -l < AGENTS.md` — exactly 160.
- `grep -cE 'prime|corpus|embedding|vector|provenance.harness' AGENTS.md` — 0.
- `ainish-context audit contract --verify-history` — chain verified.
- A write to `AGENTS.md` after the change fails with `operation not permitted`.

## 7. Open Decisions

- Whether `.agents/rag/` should be renamed now that the contract no longer names it — settled by
  whether a future agent is confused by the path.
- Whether the `Master Surfaces` path fix belongs in this branch or its own — this plan fixes it because
  it is two lines and the suite already covers the gate line.
