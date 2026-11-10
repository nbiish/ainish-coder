# Implementation Blueprint: Context Priming, Obsidian Wiki, and Repo-Local RAG

- **Date:** 2026-11-08
- **Branch:** `feat/agents-context-prime`
- **Worktree:** `../ainish-coder-context-prime` (isolated from `main`, per `AGENTS.md`)
- **Protocol:** `question-me` — three forks resolved by the operator before implementation
- **Status:** Design locked, implementation in progress

## 1. Anchor Facts (verified on this host, 2026-11-08)

1. **`ainish-rag --context` did not run.** Shell resolution picks `bin/ainish-rag.exe` on Windows
   (the compiled Rust binary, which had no `context` verb), so the exact command `AGENTS.md`
   mandated failed with `unexpected argument '--context'`. Only `bin\ainish-rag.cmd` reached the
   Python engine. A contract whose one tool call cannot execute is not a contract.
2. **Most of the pipeline already exists** in `src/rag/rag.py`: `run_context_command`,
   `elephant_synthesize`, `goldfish_review`, budgeted `assemble_injection`, `<CONTEXT_INJECTION>`
   rendering, and a `skip_retrieval` route. The Elephant/Goldfish pair was inline inside the
   assembly function rather than its own unit.
3. **`.agents/**` documents were indexed badly.** `index` read `.md`/`.txt` as a single chunk
   truncated at 3000 characters. The current daily memory file is 19,396 characters, so ~85% of it
   never reached a vector — including every fact an agent most needs. The Rust `chunk_doc_file`
   already split on markdown sections and was the model to follow.
4. No `lancedb` Python package on this host (vector writes must go through the compiled engine);
   `cargo`/`rustc` and `uv` are present; `.agents/rag/*` is already gitignored.

## 2. Resolved Decisions

### Decision 1: Vector store for `.agents/**`
- **Question:** Keep LanceDB, add sqlite-vector, or add pgvector?
- **Selected:** Keep LanceDB. Add a dedicated `agents_knowledge` table with proper section-aware
  chunking. No new infrastructure, no new service to run on every host.
- **Trade-offs accepted:** A second table in the same directory, and the requirement to keep two
  ingest paths in sync. Rejected sqlite-vector and pgvector because both add a runtime dependency
  the contract would then have to guarantee on every deployed host.

### Decision 2: Elephant/Goldfish boundary
- **Question:** How literally should the pair be "its own call"?
- **Selected:** A real process boundary — a new `ainish-rag council` subcommand that `context`
  invokes internally, so the agent still receives exactly one output but the pair is independently
  callable and testable.
- **Trade-offs accepted:** One more verb on the surface and a subprocess hop when `context` calls
  it. Rejected a module-only boundary (not testable in isolation the way a subcommand is) and a
  separate agent-facing command (would break the one-call contract in `AGENTS.md`).

### Decision 3: Meaning of "most recent"
- **Question:** What does "review only the most recent" mean concretely?
- **Selected:** Newest 1 file in each of `comms`/`tasks`/`suggestions`/`templates`, newest 3 in
  `memories`. Fixed, cheap, no knobs.
- **Trade-offs accepted:** A task spanning several days may need an older record; that gap is
  covered by the `.agents/**` vector index rather than by widening the read.

### Decision 4: Where plans live
- **Question:** Where does a `question-me` blueprint belong?
- **Selected:** `.agents/plans/{date}-{plan_name}.plan.md`, repo-local, never distributed.
- **Trade-offs accepted:** A new directory and a new `doc_type`; in exchange the blueprint stops
  competing for space in `.agents/tasks/`, which is the record of what *happened*, while a plan is
  the record of what was *intended*.

## 3. Changes

### 3.1 Invocation (`src/rag/src/main.rs`, `bin/ainish-rag`, `bin/ainish-rag.cmd`)
The Rust binary now intercepts Python-only verbs (`context`, `council`, `secrets`) before clap
parses, and execs `src/rag/rag.py` with a proven interpreter. A leading `--context` is rewritten to
the `context` subcommand. The launcher lists stay in sync so wrapper callers behave identically.

### 3.2 Knowledge corpus (`src/rag/rag.py`)
- `LanceStore` is parameterised by table name; `AGENTS_TABLE = "agents_knowledge"` sits beside
  `CODEBASE_TABLE = "codebase_rag"` in one directory.
- `split_markdown_sections` + `chunk_agents_doc` replace `content[:3000]`: sections split on
  `#`-headings and `### [timestamp]` entry headers, windows of ~1200 chars with 150 overlap, capped
  at 60 chunks per file. Each window carries its heading so a mid-file chunk still says which entry
  it belongs to.
- `agents_doc_type` maps an area to a `doc_type` (`agents_comms`, `agents_task`, `agents_memory`,
  `agents_suggestion`, `agents_template`, `agents_wiki`, `agents_skill`, `agents_llms`,
  `agents_plan`) and excludes `.agents/rag/` (self-indexing), `.agents/audit/` (binary receipts),
  `.agents/canonical/` (duplicate of root `AGENTS.md`), and `.agents/bin/` (generated scripts).
- `ainish-rag index --agents` refreshes only that table; a full `index` refreshes both. A receipt at
  `.agents/rag/agents-index.json` lets `context` decide staleness by mtime instead of re-embedding
  on every call.
- `recent_agents_files` implements the Decision 3 scope, sorting by name as the durable
  chronological signal (mtime is unreliable in a fresh worktree, where checkout stamps every file
  identically).

### 3.3 `ainish-rag council`
Elephant and Goldfish move out of the assembly function into their own subcommand. Elephant receives
both the prime *input* (task, route decision, expert terms) and the assembled *output*; Goldfish
receives task, prime text, and the Elephant addition, and nothing else — the isolation remains a
signature-level guarantee so the existing `GoldfishIsolationTest` still fails if a session becomes
reachable. `context` invokes `council` and splices the result, so the agent still sees one output.

### 3.4 Prime sections
`CONTEXT_SECTION_CAPS` gains `doctrine` (`.agents/llms.txt` verbatim — it is the map of the tree),
`recent` (the Decision 3 set, so the `AGENTS.md` instruction is mechanically true), and
`architecture` (task-conditioned wiki sections, reusing the existing scoring rather than a second
implementation). Degradation order: trim retrieval tail -> drop goldfish -> drop architecture ->
drop elephant -> drop orientation -> hard-truncate retrieval.

### 3.5 Obsidian-compatible wiki (`rag.py` `generate_wiki`, `src/rag/src/wiki.rs`)
Both generators must change or the two hosts diverge. Wikilinks (`[[01 Architecture]]`) replace
relative markdown links, every page gains frontmatter (`tags`, `aliases`, `generated`), and pages
cross-link so `ledger.md` appears in the graph instead of as an orphan. `.agents/wiki/` is a single
vault root with no absolute paths.

### 3.6 `--rules` isolation (`src/deploy_rules_sync.sh`)
An explicit deny-list (`REPO_LOCAL_AGENT_PATHS`) covers `.agents/rag`, `.agents/wiki`,
`.agents/memories`, `.agents/tasks`, `.agents/suggestions`, `.agents/plans`. The manifest writer
asserts no deny-listed path appears in `managed_paths`, turning today's coincidence into an
invariant. A test seeds a target, runs `--rules`, and asserts RAG state is absent while contract
surfaces are refreshed.

### 3.7 Contract and docs
- `AGENTS.md` rewritten: the one context call, the composite prime chain, the explicit recent-only
  scope, `.agents/llms.txt` promoted to a first read, and the `--context` spelling fixed. Mirrored to
  `.agents/canonical/AGENTS.md` and re-signed.
- `.agents/llms.txt` gains the distributed-vs-repo-local split and the new `plans/` child.
- Root `llms.txt` gains `.agents/plans/` in the DOX index, records `council`, and its wiki
  filename list is corrected to the names the generator actually writes.

## 4. Target Files

- `AGENTS.md`, `.agents/canonical/AGENTS.md`
- `.agents/llms.txt`, `.agents/plans/llms.txt`
- `llms.txt`
- `src/rag/rag.py`
- `src/rag/src/main.rs`, `store.rs`, `ingest.rs`, `wiki.rs`
- `src/deploy_rules_sync.sh`
- `bin/ainish-rag`, `bin/ainish-rag.cmd`
- `src/rag/tests/test_context_injection.py`, `scripts/test-pqc-dist.sh`

## 5. Acceptance Criteria

1. `ainish-rag context --task "..."` returns one `<CONTEXT_INJECTION>` with every section populated,
   through the binary, the `.cmd`, the bash launcher, and the `--context` alias.
2. `ainish-rag index --agents` produces an `agents_knowledge` table, and a memory-only query returns
   text from beyond character 3000 of the current daily memory file.
3. `ainish-rag council --task x --input -` returns the pair alone, and `GoldfishIsolationTest` still
   proves no session state reaches Goldfish.
4. `.agents/wiki/` opens as an Obsidian vault: TOC wikilinks resolve, `ledger.md` has backlinks, no
   broken links.
5. `ainish-coder --rules <dir>` refreshes `AGENTS.md` and `.agents/llms.txt` while leaving
   `.agents/rag/` and `.agents/wiki/` untouched.
6. `ainish-rag gate` is green after the contract is re-signed.

## 6. Risks

- **Latency.** Two sequential model calls dominate (measured ~11s). The added sections grow the
  prompt but not the call count, so the cost is input tokens rather than a third round trip; the
  budget ladder degrades visibly when the route's budget cannot hold them.
- **Split brain between the two wiki generators.** Both are changed in this pass because either one
  alone produces a vault that links inconsistently depending on which host generated it.
- **Index growth.** `.agents/skills/` is large (1,487 of 2,523 chunks). It is included because a
  skill's body is exactly the durable knowledge an agent needs to find; the per-file chunk cap keeps
  any one document from dominating.
