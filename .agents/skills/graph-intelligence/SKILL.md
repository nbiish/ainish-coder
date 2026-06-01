---
name: graph-intelligence
description: >
  Enterprise-grade codebase intelligence via knowledge graphs. Uses GitNexus (MCP-native,
  AST-precise, call-graph aware) as the always-on operational layer and Graphify (multimodal,
  docs+code+papers) as the on-demand semantic enrichment layer. 6 workflow modes: Orient,
  Symbol Dive, Blast Check, Enrich, Stale Guard, Client Brief. Designed for consulting
  engagements with tribal governments, corporations, and multi-repo environments.
---

# Graph Intelligence — Two-Layer Codebase Knowledge Graphs

This skill provides enterprise-grade codebase intelligence by combining two complementary
knowledge graph tools in a **two-layer architecture**:

| Layer | Tool | Type | When | Speed |
|-------|------|------|------|-------|
| **Operational** (always-on) | GitNexus MCP | AST-precise call graphs, impact analysis | Every coding session | ~4s index, <400ms query |
| **Semantic** (on-demand) | Graphify CLI | Multimodal knowledge graph (code+docs+papers+images) | Client onboarding, enrichment | ~12s extract |

**PRD Anchor:** Always read `llms.txt` first. It is the authoritative PRD for this repo.

---

## §1 Prerequisites & Installation

### 1.1 GitNexus

```bash
# Install globally (npm)
npm install -g gitnexus@latest

# Index current repo (pure index, no file injection)
gitnexus analyze --index-only

# Verify
gitnexus status
```

GitNexus provides an MCP server. If not already configured, register it:

```bash
# Auto-detect and configure for all editors
gitnexus setup
```

The MCP server exposes these tools (lazy-loaded):

| Tool | Purpose | Use When |
|------|---------|----------|
| `list_repos` | List all indexed repositories | Starting a session, checking staleness |
| `query` | BM25 + vector search across symbols, files, docs | Finding where something is defined |
| `context` | Full call graph for a symbol (callers, callees, structs, processes) | Understanding a function deeply |
| `impact` | Blast radius analysis (upstream/downstream) | Before editing any code |
| `detect_changes` | Git-diff-aware stale detection | After commits, merges, rebases |
| `cypher` | Raw Cypher queries against the graph | Advanced structural queries |
| `rename` | Safe rename with dependency tracking | Refactoring symbols |
| `route_map` | HTTP route → handler mapping | REST API codebases |
| `shape_check` | Response shape validation | API contract verification |
| `api_impact` | API-specific blast radius | Before changing endpoints |
| `group_list` | List multi-repo groups | Enterprise multi-service work |
| `group_sync` | Cross-repo contract extraction | Multi-repo dependency analysis |

### 1.2 Graphify

```bash
# Install via pipx (macOS-safe)
pipx install graphifyy

# Install skill to Claude Code / Gemini / etc.
graphify install --platform antigravity

# Extract code graph (no LLM needed)
graphify update . --no-cluster
```

For full clustering with community naming (needs LLM):

```bash
secrets-load  # inject GEMINI_API_KEY or ANTHROPIC_AUTH_TOKEN
graphify update .
```

Graphify outputs to `graphify-out/`:

```
graphify-out/
├── graph.json       # persistent graph (5,700+ nodes, 6,800+ links)
├── graph.html       # interactive visualization (open in browser)
├── obsidian/        # open as Obsidian vault
├── wiki/            # Wikipedia-style articles (--wiki flag)
├── GRAPH_REPORT.md  # god nodes, surprising connections, suggested questions
└── cache/           # SHA256 cache — re-runs only process changed files
```

---

## §2 Workflow Modes

### Mode 1: Orient — Start Any Task

**Purpose:** Gain situational awareness of a codebase before writing code.

```
STEP 1  gitnexus analyze --index-only        # Index (if fresh, <1s no-op)
STEP 2  gitnexus MCP → list_repos            # Verify repo is indexed
STEP 3  gitnexus MCP → query({              # Semantic search for task area
          query: "<task keywords>",
          repo: "<repo-name>",
          limit: 10
        })
STEP 4  Review processes and definitions      # Understand execution flows
```

**When to use:** Every new coding session. Every new client engagement. Every unfamiliar repo.

### Mode 2: Symbol Dive — Deep Call Graph Analysis

**Purpose:** Understand exactly how a function works, who calls it, what it calls.

```
STEP 1  gitnexus MCP → context({
          name: "<function_name>",
          repo: "<repo-name>"
        })

Output provides:
  • symbol: exact file, line range
  • incoming.calls: who calls this function
  • outgoing.calls: what this function calls
  • outgoing.accesses: what properties it reads
  • processes: which execution flows it participates in
```

**Example (tested on ainish-coder):**

```
context({name: "cmd_pack", repo: "ainish-coder"})
→ symbol: src/pqc-secrets/src/main.rs:207-303
→ incoming: [main]
→ outgoing: [parse_env_lines, derive_kek, sha3_256, now_utc,
             encrypt_aesgcm, ensure_parent_dir, Bundle, RecipientSection,
             KemSection, KeywrapSection, DataSection, PayloadSection]
→ processes: [Main→Parse_env_lines, Main→PayloadSection, Main→Encrypt_aesgcm]
```

### Mode 3: Blast Check — Impact Analysis Before Edits

**Purpose:** Before modifying any symbol, check what will break.

```
STEP 1  gitnexus MCP → impact({
          target: "<symbol_name>",
          direction: "upstream",      # who depends on me
          repo: "<repo-name>",
          limit: 15
        })

Output provides:
  • risk: LOW / MEDIUM / HIGH / CRITICAL
  • summary.direct: count of direct dependents
  • summary.processes_affected: execution flows that break
  • summary.modules_affected: clusters impacted
  • byDepth: callers at each distance (d=1 WILL BREAK)
  • affected_processes: name, file, step where break occurs

STEP 2  If risk >= MEDIUM, also check downstream:
        impact({target: "<symbol>", direction: "downstream", ...})

STEP 3  Review affected_modules — if >1 cluster impacted,
        consider a phased rollout or feature flag.
```

**Example (tested on ainish-coder):**

```
impact({target: "cmd_export", direction: "upstream", repo: "ainish-coder"})
→ risk: LOW
→ direct: 1 (main)
→ processes_affected: 1
→ modules_affected: 1 (Cluster_51)
→ byDepth.1: [main in src/pqc-secrets/src/main.rs, confidence: 0.95]
```

### Mode 4: Enrich — Multimodal Knowledge Extraction

**Purpose:** When a codebase includes docs, papers, architecture diagrams, or non-code
artifacts that need to be part of the knowledge graph.

```
STEP 1  graphify update . --no-cluster       # Fast: code-only extraction (~12s)
        # OR
        graphify update .                     # Full: with LLM clustering (needs API key)

STEP 2  graphify explain "<concept>"          # Plain-language node explanation
        graphify path "<A>" "<B>"             # Shortest path between concepts

STEP 3  # Ingest external resources
        graphify add https://arxiv.org/abs/...         # papers
        graphify add https://x.com/user/status/...     # tweets
        graphify add https://docs.example.com/api      # docs

STEP 4  # Query the enriched graph
        graphify query "what connects PQC to the deployment pipeline?"
```

**When to use:**
- Client onboarding with existing documentation
- Research-heavy projects with papers, RFCs, design docs
- Multi-language repos where docs bridge code boundaries
- Tribal government IT systems with policy documents alongside code

**Graphify node types observed in ainish-coder:**

| Type | Count | Example |
|------|-------|---------|
| code | 1,039 | Functions, classes, methods, JSON keys |
| document | 4,538 | Markdown sections, policy text, skill instructions |
| rationale | 132 | Design decision explanations, "why" annotations |

### Mode 5: Stale Guard — Keep Indexes Fresh

**Purpose:** Detect when the knowledge graph is out of date after commits.

```
STEP 1  gitnexus MCP → detect_changes({repo: "<repo-name>"})

Output:
  • changed_count: number of symbols affected by uncommitted/new changes
  • affected_count: downstream symbols that may be stale
  • risk_level: none / low / medium / high
  • affected_processes: execution flows that may have shifted

STEP 2  If changed_count > 0:
        gitnexus analyze --index-only          # Re-index (~4s)
        graphify update . --no-cluster         # Re-extract if using enrichment

STEP 3  gitnexus MCP → list_repos             # Verify staleness hint is gone
```

**Automation:** GitNexus hooks can auto-trigger reindex after `git commit`, `git merge`,
`git rebase`, and `git cherry-pick` in Claude Code and Antigravity (hooks installed by
`gitnexus setup`).

### Mode 6: Client Brief — Visual Deliverables

**Purpose:** Generate interactive visualizations and structured reports for stakeholder
review — tribal councils, corporate leadership, government IT oversight.

```
STEP 1  graphify update .                     # Full extraction + clustering
        # Ensure GEMINI_API_KEY or ANTHROPIC_AUTH_TOKEN is loaded via secrets-load

STEP 2  # Open interactive graph
        open graphify-out/graph.html           # macOS
        # Click nodes, search, filter by community

STEP 3  # Generate wiki (optional)
        graphify wiki .

STEP 4  # Review GRAPH_REPORT.md for:
        # - God nodes (high centrality — risk concentrators)
        # - Surprising connections (unexpected dependencies)
        # - Suggested questions (automated curiosity prompts)
        cat graphify-out/GRAPH_REPORT.md

STEP 5  # For multi-repo client engagements:
        graphify merge-graphs repo1/graphify-out/graph.json \
                              repo2/graphify-out/graph.json \
                              --out merged-graph.json
```

**Cross-repo with GitNexus groups:**

```bash
# Create a client group
gitnexus group create tribal-health-it

# Add repos
gitnexus group add tribal-health-it "backend/ehr" ehr-service
gitnexus group add tribal-health-it "frontend/portal" patient-portal
gitnexus group add tribal-health-it "infra/deploy" terraform-infra

# Cross-repo contract analysis
gitnexus group sync tribal-health-it

# Query across all repos
gitnexus group query tribal-health-it "authentication flow"
```

---

## §3 Decision Matrix — Which Tool When

| Scenario | Tool | Command / MCP Call |
|----------|------|--------------------|
| "Where is X defined?" | GitNexus | `query({query: "X", repo: "..."})` |
| "What calls X?" | GitNexus | `context({name: "X", repo: "..."})` |
| "What breaks if I change X?" | GitNexus | `impact({target: "X", direction: "upstream"})` |
| "Is the index stale?" | GitNexus | `detect_changes({repo: "..."})` |
| "Show me the full architecture" | Graphify | `graphify update . && open graphify-out/graph.html` |
| "What connects PQC to deployment?" | Graphify | `graphify query "PQC deployment pipeline"` |
| "Ingest this paper/RFC/doc" | Graphify | `graphify add https://...` |
| "Client briefing visual" | Graphify | `open graphify-out/graph.html` |
| "Cross-repo dependencies" | Both | GitNexus `group sync` + Graphify `merge-graphs` |
| "Safe rename across codebase" | GitNexus | `rename({old: "X", new: "Y", repo: "..."})` |

---

## §4 GitNexus MCP Quick Reference

All tools are MCP-native and can be called directly from any agent session.

### query — Semantic + BM25 Search

```json
{
  "query": "deploy_path file_operations symlink",
  "repo": "ainish-coder",
  "limit": 10
}
```

Returns: `processes` (execution flows), `process_symbols` (functions in flows),
`definitions` (matching symbols with file:line), `timing` (ms breakdown).

### context — Full Symbol Context

```json
{
  "name": "cmd_export",
  "repo": "ainish-coder"
}
```

Returns: `symbol` (exact location), `incoming.calls`, `outgoing.calls`,
`outgoing.accesses`, `processes` (flow participation).

### impact — Blast Radius

```json
{
  "target": "cmd_export",
  "direction": "upstream",
  "repo": "ainish-coder",
  "limit": 15
}
```

Returns: `risk` level, `summary` (direct/processes/modules), `byDepth` (callers at d=1..N),
`affected_processes`, `affected_modules`.

### detect_changes — Staleness Check

```json
{
  "repo": "ainish-coder"
}
```

Returns: `changed_count`, `affected_count`, `risk_level`, `changed_symbols`,
`affected_processes`.

---

## §5 Graphify CLI Quick Reference

### Core Commands

```bash
graphify update .                     # Re-extract + cluster (needs LLM for naming)
graphify update . --no-cluster        # Fast: code-only extraction, no LLM needed
graphify update . --force             # Overwrite even if rebuild has fewer nodes

graphify explain "deploy_path"        # Plain-language node explanation
graphify path "pqc-secrets" "deploy"  # Shortest path between concepts
graphify diagnose multigraph          # Edge collapse diagnostic

graphify add https://arxiv.org/...    # Ingest URL into ./raw + update graph
graphify watch .                      # Watch for changes, rebuild automatically

graphify merge-graphs g1.json g2.json # Merge cross-repo graphs
graphify clone https://github.com/... # Clone + prep for /graphify
```

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `GEMINI_API_KEY` | Gemini backend for clustering/naming |
| `GOOGLE_API_KEY` | Alternative Gemini key |
| `ANTHROPIC_AUTH_TOKEN` | Claude backend for clustering |
| `GRAPHIFY_FORCE` | Set to `1` to force overwrite on rebuild |

Load via `secrets-load` before running clustering commands.

### Output Files

| File | Purpose | Client-Facing? |
|------|---------|----------------|
| `graph.html` | Interactive visualization | ✅ Yes — open in browser |
| `graph.json` | Persistent graph data | No — agent/script use |
| `GRAPH_REPORT.md` | God nodes, connections, questions | ✅ Yes — executive summary |
| `obsidian/` | Obsidian vault | ✅ Yes — knowledge base |
| `wiki/` | Wikipedia-style articles | ✅ Yes — reference docs |
| `cache/` | SHA256 extraction cache | No — internal optimization |

---

## §6 Enterprise Patterns

### New Client Onboarding

```
1. git clone <client-repo>
2. gitnexus analyze --index-only           # Operational layer (~4s)
3. graphify update .                        # Semantic layer (~12s + LLM)
4. gitnexus MCP → query("architecture")   # Orient
5. open graphify-out/graph.html            # Visual tour
6. cat graphify-out/GRAPH_REPORT.md        # God nodes = risk concentrators
```

### Multi-Repo Client (Tribal Government, Enterprise)

```
1. For each repo:
   - gitnexus analyze --index-only
   - graphify update . --no-cluster

2. GitNexus group:
   gitnexus group create <client-name>
   gitnexus group add <client-name> "<path>" <repo-name>
   gitnexus group sync <client-name>

3. Graphify cross-repo:
   graphify merge-graphs repo1/graphify-out/graph.json \
                         repo2/graphify-out/graph.json

4. Query across all:
   gitnexus group query <client-name> "<question>"
```

### Pre-Edit Safety Protocol

```
1. gitnexus MCP → detect_changes({repo})   # Is index fresh?
2. gitnexus MCP → context({name: "<target>"})  # Understand the symbol
3. gitnexus MCP → impact({target, "upstream"})  # What breaks?
4. If risk >= MEDIUM → impact({target, "downstream"})
5. Edit code
6. gitnexus analyze --index-only            # Refresh index
7. gitnexus MCP → detect_changes({repo})    # Confirm clean
```

---

## §7 Limitations & Workarounds

### GitNexus
- **Shell functions**: Bash function calls (e.g. `deploy_path()` calling `ln -sf`) are not
  tracked as edges. Workaround: use `query()` to find the function, then read the file.
- **`route_map` / `shape_check`**: Empty for non-REST codebases. Expected behavior.
- **Document content**: GitNexus clusters *code*, not docs. Use Graphify for doc intelligence.

### Graphify
- **No MCP server**: Can't be called mid-session by agents natively. Must use CLI or
  the `/graphify` slash command in Claude Code.
- **Document noise**: Legal/policy docs (Terms-of-Service, Privacy-Policy) dominate node
  counts. Add to `.graphifyignore` if problematic.
- **Path queries on shell**: Returns ambiguous results for loosely-coupled shell scripts.
  Use GitNexus `query()` instead.
- **LLM required for clustering**: `GRAPH_REPORT.md` and community naming need an API key.
  Code-only extraction works without one.
