# TASK.20260904-graph-intel

- **date:** 2026-09-04
- **agent:** dsh-orchestrator
- **branch:** docs/graph-intelligence-integration (worktree `../graph-intelligence-integration` from main `a045216`)
- **operator directive:** Utilize `/graph-intelligence` across all repos; begin llms.txt integration; determine the most effective tooling and narrow it to concise usage paired with agent actions.

#### draft: gate → orient → probe tools → edit AGENTS.md → edit llms.txt → verify

## Tooling determination (probe results, 2026-09-04)

| Tool | Status | Verdict |
|---|---|---|
| GitNexus | installed (`~/.local/bin/gitnexus`, full CLI: analyze/context/impact/trace/cypher/detect-changes/check + MCP) | **Mandatory core pillar** — deterministic AST call-graphs, blast radius, post-edit scope proof, zero LLM cost |
| Graphify | not installed | Conditional escalation — `pip install graphifyy` only for cross-doc synthesis / PR triage |
| Semantica | not installed | Conditional escalation — `pip install semantica` only for decision records / SHACL / PROV-O audit |
| trae-cli / mini | installed | Unchanged Tier-3 fleet; scoped by gitnexus impact allowlists |

Key discovery: `gitnexus analyze` rewrites its section inside `AGENTS.md`/`CLAUDE.md` unless run with `--skip-agents-md` → contract-protection rule codified (non-optional flag + `.gitnexus/`/`.claude/` gitignored).

## Changes

1. `AGENTS.md` (universal, deploys to all repos via `--rules`):
   - New `<GRAPH>` section: pillar routing table (core GitNexus / escalate Graphify, Semantica), minimal invocations, Iron-Pipeline pairing (impact → fleet allowlist; detect-changes → merge precondition; semantica decision record), contract-protection flags, graceful degradation.
   - Frontmatter + TASK_PRIMER graph-recon pointers; WORKFLOW gains step 3 Recon and detect-changes scope proof in step 7 Verify; FLEET Tier-2 cross-reference; AUDIT item 8 Graph Verification; REINFORCEMENT clause.
2. `llms.txt` (this repo's PRD): new "Graph Intelligence Integration (repo-local)" section — tooling verdict, contract-protection rule, PRD precedence over graph queries, deployment path.
3. `.gitignore`: ignore `.gitnexus/` + `.claude/` (deploys to all targets with `--rules`).
4. `AGENTS/2026-09-04.COMMS.md`: checkin / update / intent-merge ledger entries.

## Verification

- `gitnexus analyze --skip-agents-md --no-stats` executed in-worktree (proof run).
- `gitnexus detect-changes` maps the diff to scope proof (docs-only change set).
- Audit: no secrets, no banned crypto introduced (markdown + gitignore only).

#### draft result: one core pillar + two escalations, wired into universal standard
