---
name: graph-intelligence
description: >
  Utilitous codebase intelligence powered by GitNexus (AST-precise, call-graph aware, zero LLM overhead)
  for deterministic code call-chains, blast-radius, coordinated renames, and diff change detection.
  Seamlessly bridged with the /repo-memory persistent memory substrate (Memorix, Reference Memory, Engram)
  to pair AST code structure ("where") with architectural decisions and gotchas ("why").
  Trigger on: "how does X work", "what calls Y", "what breaks if I change Z", "show me the architecture",
  "call hierarchy", "blast radius", or pre-edit code navigation.
version: 4.0.0
---

# Graph Intelligence — Utilitous Code-Graph Engine

A streamlined, high-velocity AST and code-symbol intelligence engine powered by **GitNexus**, seamlessly bridged with `/repo-memory` for persistent knowledge, decisions, and gotchas.

## 0. Fleet Context Standard — llms.txt is the PRD (CLAUDE.md replacement)
- **`llms.txt` is the PRD.** Repo-root `llms.txt` (plus per-directory DOX files) replaces CLAUDE.md as the canonical project-context source. Consult it before graph queries; update it after meaningful changes (DOX "Update After Editing" gate).
- **`.agents/` is the global skill standard.** All skills, including the GitNexus playbooks bundled here, live in `.agents/skills/`.
- **`.claude/` pairing.** Tooling may generate `.claude/` alongside (GitNexus `analyze` mirrors skills there), and Claude-Code-compatible harnesses — notably `fcc-claude` — require it. Tolerate the generated mirror and never hand-edit both: `.agents/` + `llms.txt` are the source of truth; `.claude/` is paired tool output for fcc-claude.

---

## 1. Pure Utilitous Architecture — Division of Labor

To maximize execution velocity and eliminate bloat, graph operations separate strictly by concern:

| Layer | Engine | Primary Specialization & Best Purpose |
|---|---|---|
| **Code-Graph & AST (The "WHERE")** | **GitNexus** | **Deterministic AST-level call-chains & blast radius:** AST-precise symbol exploration, incoming/outgoing call hierarchies, pre-edit blast radius ($d=1, d=2$), coordinated multi-file renames, and git diff symbol change detection. Operates locally with zero LLM overhead via LadybugDB (`lbug`). |
| **Epistemic & Decision Memory (The "WHY")** | **Repo-Memory (`/repo-memory`)** | **Persistent facts, decisions, and session continuity:** Memorix (project facts, gotchas, reasoning), Reference Memory (knowledge graph JSONL), and Engram (session summaries, conflict judging). Replaces external, heavyweight graph-memory layers. |

### Upstream Repository & CLI
- **GitNexus:** Learn more at [GitNexus on GitHub](https://github.com/abhigyanpatwari/GitNexus), and install the latest release via `npm install -g gitnexus` (or connect via native MCP stdio `gitnexus`).

---

## 2. The Four Symbiotic Bridges to `/repo-memory`

Real-world coding needs require structural code awareness to feed directly into agent memory:

```
┌─────────────────────────────────────────────────────────────┐
│                 GitNexus (Code-Graph Engine)                │
│   AST Symbols • Call Hierarchies • Blast Radius • Diff Hunks│
└──────────────┬───────────────────────────────▲──────────────┘
               │ 1. Scoped Recall              │ 4. Stale Symbol Check
               │    (feed callers to memory)   │    (flag retired nodes)
               ▼                               │
┌──────────────────────────────────────────────┴──────────────┐
│                  Repo-Memory Substrate                      │
│   Memorix (Gotchas) • Engram (Decisions) • Ref Memory (JSONL│
└──────────────┬───────────────────────────────▲──────────────┘
               │ 2. Canonical AST UIDs         │ 3. Diff-to-Summary
               │    (ground entity relations)  │    (audit modified symbols)
               ▼                               │
┌──────────────────────────────────────────────┴──────────────┐
│             .agents/memories/ (Git-Tracked Layer)           │
│   MEMORY.md Digest • engram.json • reference-graph.jsonl    │
└─────────────────────────────────────────────────────────────┘
```

1. **AST Blast-Radius Scoped Memory Recall (GitNexus $\rightarrow$ Memorix/Engram):**
   - *Practice:* Before modifying a symbol, run `gitnexus context <target>` or `gitnexus impact <target>` to identify direct callers and callees.
   - *Bridge:* Pass those exact symbol names and file paths to `memorix_search` and `mem_search` (e.g. `memorix_search("safeFetch")`). Instead of generic ungrounded queries, memory retrieval is laser-scoped to the code's blast radius.
2. **Canonical AST UIDs in Reference Memory (GitNexus $\rightarrow$ Reference Memory):**
   - *Practice:* When mapping architecture in Reference Memory (`create_entities`, `reference-graph.jsonl`), use GitNexus symbol UIDs (e.g. `Function:src/ssrf-guard.ts:safeFetch`, `Module:src/reasoning.ts`).
   - *Bridge:* Anchoring entity nodes to verified AST symbols prevents entity drift and hallucinated relationship graphs.
3. **Diff-to-Symbol Verification for Session Closeout (GitNexus $\rightarrow$ Engram Closeout):**
   - *Practice:* Before closing a task, run `gitnexus detect-changes` on the git diff.
   - *Bridge:* GitNexus maps edited diff hunks to affected AST symbols. Inject this exact symbol list into `mem_session_summary` (Files/Accomplished) and `MEMORY.md` to guarantee zero drift between code changed and memory logged.
4. **AST-Driven Stale Memory Retirement (GitNexus $\rightarrow$ Memorix Resolve):**
   - *Practice:* When refactoring or deleting symbols, check stored memories referencing them.
   - *Bridge:* If GitNexus returns `Symbol not found` for a previously tracked symbol, retire the memory via `memorix_resolve` or `mem_delete` to eliminate epistemic rot.

---

## 3. Minimal Core Invocations & Help-Driven Discovery

> **Argument Discovery Protocol:** Beyond the base commands below, **always run `--help` or `help`** to dynamically discover available options, flags, and subcommands.

### GitNexus (CLI & MCP)
- **Discover:** `gitnexus --help` or `gitnexus <command> --help`
- **List / Register:** `gitnexus list` · `gitnexus index <repo-path>` (instant registration of existing `.gitnexus/`)
- **Index Repo:** `gitnexus analyze` (full AST parsing and graph build)
- **Symbol 360° Context:** `gitnexus context <symbol> [-r <repo>]` (incoming callers, outgoing callees, processes)
- **Blast Radius (Impact):** `gitnexus impact <symbol> [-r <repo>]` (upstream dependents that break if symbol changes)
- **Execution Flow Query:** `gitnexus query "<search_term>"` (hybrid search across processes, flows, and symbols)
- **Shortest Call Path:** `gitnexus trace <from_symbol> <to_symbol>` (directed call + member edge path)
- **Diff Change Detection:** `gitnexus detect-changes` (maps git diff hunks to AST symbols and affected execution flows)
- **Coordinated Rename:** `gitnexus rename <old_symbol> <new_symbol>` (multi-file AST-safe renaming with dry-run)

---

## 4. Concrete "Master" Prompts

### Master A: AST Blast-Radius & Pre-Edit Risk Master (GitNexus + Repo-Memory)
*Embody this persona when tracing call hierarchies, assessing pre-edit risk, or querying historical gotchas for a target interface.*

```markdown
# TASK: AST Call-Chain & Pre-Edit Blast Radius Assessment

## ROLE & EXPERT PERSONA
You are acting as the **AST Blast-Radius & Pre-Edit Risk Master**. You execute deterministic, AST-level call-graph exploration to ensure zero regressions before modifying exported interfaces.

## TOOL DISCOVERY & EXECUTION DIRECTIVES
1. Run `gitnexus context <SYMBOL_NAME> -r <REPO>` to map incoming callers and outgoing callees.
2. Run `gitnexus impact <SYMBOL_NAME> -r <REPO>` to compute upstream blast radius and affected files.
3. Bridge to Memory: query `memorix_search` and `mem_search` using the discovered caller symbols to load historical gotchas and architectural constraints.
4. Output a structured blast-radius and gotcha matrix before writing any code modifications.
```

---

### Master B: Coordinated AST Refactoring Master (GitNexus)
*Embody this persona when safely renaming symbols, extracting interfaces, or refactoring across multiple files.*

```markdown
# TASK: Coordinated AST Refactoring & Interface Migration

## ROLE & EXPERT PERSONA
You are acting as the **Coordinated AST Refactoring Master**. You execute safe multi-file refactoring using deterministic AST graph edges.

## TOOL DISCOVERY & EXECUTION DIRECTIVES
1. Inspect the target symbol with `gitnexus context <SYMBOL>`.
2. Execute dry-run rename: `gitnexus rename <OLD_SYMBOL> <NEW_SYMBOL> --dry-run`.
3. Verify all affected call sites and module exports.
4. Apply the refactoring, run native compiler checks (`tsc`, `cargo check`), and verify zero broken references.
```

---

### Master C: Diff-to-Memory Closeout Auditor (GitNexus + Repo-Memory)
*Embody this persona when auditing a completed task diff and landing the persistent memory record.*

```markdown
# TASK: Diff-to-Memory Verification & Session Closeout

## ROLE & EXPERT PERSONA
You are acting as the **Diff-to-Memory Closeout Auditor**. You ensure every code modification has verifiable AST coverage and is faithfully documented in persistent memory.

## EXECUTION SEQUENCE
1. Run `gitnexus detect-changes` on the current git diff to map modified lines to AST symbols.
2. Formulate durable decision records in `memorix reasoning` and `engram save --type decision` citing the exact symbol UIDs.
3. Call `mem_session_summary` recording the verified symbol list under Files and Accomplished.
4. Update `.agents/memories/MEMORY.md` with dated, typed entries and refresh `exports/`.
```

---

## 5. Fleet Orchestration Bridge (Fueling Headless Dispatches)

Graph Intelligence functions as the radar for Master Orchestrators and subagents:

1. **Deterministic Target Scoping:** Query `gitnexus impact <target>` $\rightarrow$ extract all affected files $\rightarrow$ inject directly into `SCOPE & TARGET FILES` of subagent dispatches. Subagents never touch out-of-scope files.
2. **TDD Failure Isolation:** When a test fails, pass the failing signature to `gitnexus context` to locate upstream callers $\rightarrow$ dispatch a surgical bug-fix subagent.
3. **Post-Edit Safety Audit:** Run `gitnexus detect-changes` on the git diff $\rightarrow$ verify that ONLY the intended symbols were modified.

---

## 6. Deep GitNexus Operational Manuals & References

For deep dives into specialized GitNexus capabilities, consult the bundled reference playbooks in `references/`:

| Manual | Focus Area & When to Consult | Primary Command / Tools |
|---|---|---|
| [`gitnexus-cli.md`](references/gitnexus-cli.md) | Indexing, runner setup (`node .gitnexus/run.cjs`), cache cleaning | `gitnexus analyze`, `clean`, `status` |
| [`gitnexus-debugging.md`](references/gitnexus-debugging.md) | Tracing bugs, root cause analysis, 500 responses, error call paths | `context`, `query`, `cypher` |
| [`gitnexus-exploring.md`](references/gitnexus-exploring.md) | Architecture discovery, execution flows, entry point ranking | `context`, `processes`, `query` |
| [`gitnexus-guide.md`](references/gitnexus-guide.md) | Complete MCP schema, graph nodes/edges, epistemic confidence levels | `gitnexus://repo/{name}/context` |
| [`gitnexus-impact-analysis.md`](references/gitnexus-impact-analysis.md) | Pre-edit blast radius ($d=1, d=2$), ripple effects, breaking changes | `impact({direction: "upstream"})` |
| [`gitnexus-refactoring.md`](references/gitnexus-refactoring.md) | Safe multi-file renames, symbol extraction, module splitting | `rename`, `detect_changes` |
