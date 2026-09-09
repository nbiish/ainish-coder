---
name: repo-memory
description: >
  Repo-memory mastery: the three persistent-memory MCP servers wired into every
  dsh profile (headless, acp, web, tui) — Memorix (project memory + code graph,
  SQLite), MCP Reference Memory (knowledge-graph JSONL), and Engram (SQLite+FTS5
  curated memory, Go). Covers what each stores, its full MCP tool surface, when
  to route a memory to which server, install/repair on any machine, verification
  smoke tests, hygiene (PQC secrets, privacy scrubbing), and integration with
  the COMMS triad and orchestrate-subagent-masters dispatches. Use when starting
  a session in any repo, saving durable knowledge, recalling prior work,
  onboarding a new machine, or wiring memory into a dsh profile.
---

# Repo-Memory — Three-Server Persistent Memory for dsh

The operator's machines run **three complementary memory MCP servers**, bridged
into DeepSeek Harness via `@deepseek-ai/dsh-mcp-client` and enabled in **every**
dsh profile (headless, acp, web, tui) through the per-profile Cordis patch
layer. Tools surface as `mcp__<serverName>__<tool>`.

## 1. The Three Servers — Route by Memory Kind

| | **Memorix** (`memorix`) | **Reference Memory** (`reference_memory`) | **Engram** (`engram`) |
|---|---|---|---|
| Source | [AVIDS2/memorix](https://github.com/AVIDS2/memorix) Apache-2.0, TS | `@modelcontextprotocol/server-memory` MIT, TS ([src/memory](https://github.com/modelcontextprotocol/servers/tree/main/src/memory)) | [Gentleman-Programming/engram](https://github.com/Gentleman-Programming/engram) MIT, Go |
| Store | SQLite per Git project (`~/.memorix/data`); Orama/FTS5 + optional LanceDB semantic | One JSONL knowledge graph `~/.dsh-mcp-reference-memory.jsonl` (env `MEMORY_FILE_PATH`) | SQLite + FTS5 `~/.engram/engram.db`; project auto-detected from git remote |
| Strength | Richest layer cake: observations, reasoning/decision rationale, **Git-derived facts**, TS code symbol graph, retention/dedupe, multi-agent team tools | The canonical **entity–relation–observation graph**; direct graph surgery; subscribable `memory://knowledge-graph` resource | Curated session memory with **conflict judging** (`mem_compare`/`mem_judge`), lifecycle review/decay, session summaries, `mem_doctor` |
| Launch | `memorix serve` (stdio) | `mcp-server-memory` (stdio) | `engram mcp` (stdio) |

**Routing doctrine (store to the server that owns the kind):**
- *Project/session facts, gotchas, fixes, what-changed* → **Memorix** `memorix_store` (typed: `gotcha`, `problem-solution`, `decision`, `what-changed`, `discovery`, `why-it-exists`, `trade-off`, …).
- *Decision rationale with alternatives/constraints/risks* → **Memorix** `memorix_store_reasoning` or **Engram** `mem_save` (type `decision`/`architecture`).
- *Relationships between named things (person→org, module→module, decision→superseded-by)* → **Reference Memory** `create_entities` + `create_relations` (relations require both endpoints to exist first).
- *Session start/end + end-of-session summary* → **Engram** `mem_session_start` / `mem_session_summary`; session-close summaries also to Memorix via `memorix_store`.
- *Conflict resolution between two memories* → **Engram** `mem_compare` (relation: `conflicts_with|supersedes|scoped|related|compatible|not_conflict`), then `mem_judge`.
- **Read before write:** every session start calls `memorix_project_context` (Autopilot brief) + `mem_context` (Engram); search Memorix `memorix_search` and Reference `search_nodes` before storing, to avoid duplicates.

## 2. Tool Surfaces (verified)

**Memorix** (micro profile default; `--mode lite|team|full` scales to 20/28/47 tools):
`memorix_project_context`, `memorix_context_pack`, `memorix_search` (query/limit/scope/type/since/status), `memorix_detail` (ids/typedRefs), `memorix_store` (entityName/type/title/narrative/facts/filesModified/concepts/topicKey/progress), `memorix_resolve`, `memorix_codegraph_status`; lite+ adds timeline, reasoning, sessions, retention/consolidate/dedupe, transfer, skills/rules sync; team+ adds `team_manage/team_message/team_task/team_file_lock/memorix_poll/memorix_handoff`. CLI: `memorix init --global`, `memorix setup --agent dsh`, `memorix doctor agents`, `memorix background start` (HTTP + dashboard `:3211/mcp`).

**Reference Memory** (9 tools): `create_entities`, `create_relations` (fails if endpoints missing), `add_observations`, `delete_entities` (cascades relations), `delete_observations`, `delete_relations`, `read_graph`, `search_nodes` (substring, ≤2048 chars), `open_nodes`. JSONL records: `{"type":"entity","name":…,"entityType":…,"observations":[…]}` / `{"type":"relation","from":…,"to":…,"relationType":…}`.

**Engram** (22 `mem_*` tools): retrieve `mem_current_project`, `mem_context`, `mem_search(query)`, `mem_timeline(observation_id)`, `mem_get_observation`, `mem_stats`; write `mem_save(title,type,content,topic_key?,scope?)`, `mem_update`, `mem_save_prompt`, `mem_capture_passive` (parses `## Key Learnings:`), `mem_session_summary`; manage `mem_delete`, `mem_pin`/`mem_unpin`, `mem_review`, `mem_merge_projects`, `mem_doctor`; judge `mem_compare`, `mem_judge`. CLI: `engram tui`, `engram serve` (HTTP `127.0.0.1:7437`), `engram export/import`.

## 3. Install on a New Machine

Prerequisites: Node ≥22.18 (nvm), Go 1.24+ only if building engram from source.

```bash
npm install -g memorix                 # pin: memorix@<current>
npm install -g @modelcontextprotocol/server-memory   # pin: @2026.7.4 line
go install github.com/Gentleman-Programming/engram/cmd/engram@v1.20.0
#   or prebuilt: https://github.com/Gentleman-Programming/engram/releases → linux_amd64.tar.gz → ~/.local/bin
memorix init --global && memorix setup --agent dsh   # guidance + hooks (optional)
```

## 4. dsh Wiring (already applied on this machine — reproduce verbatim)

Canonical overlay: `~/.dsh/memory-mcp.cordis.yml` holds the three `insert`
entries (ids `memory-memorix`, `memory-mcp-reference`, `memory-engram`; all
`transport: stdio`, `cwd: !!js process.cwd()`; reference_memory sets
`MEMORY_FILE_PATH` → `~/.dsh-mcp-reference-memory.jsonl`). Each profile's
`~/.dsh/profiles/<name>/cordis.patch.yml` must be **one single YAML array** —
inline the three `- insert:` entries under the header comment (patch files do
NOT support `include:`; a second document after `[]` is a parse error). Verify
with:

```bash
dsh --profile headless --dump-config | grep -c "memory-"   # expect 3 (same for acp/web/tui)
```

Env hygiene: the stdio bridge scrubs any child-env var matching
`/KEY|PASSWORD|SECRET|TOKEN/i` plus all `DSH_*`; anything a server needs comes
via that server's `config.env` pulling decrypted values from `pqc-secrets
export` at runtime — never plaintext in YAML. Other client flags:
`toolCallTimeoutMs` (60s), `failOnStartupError` (false), auto-reconnect with
backoff (tools unregister after the attempt budget — restart the session).

## 5. Verification Smoke Test (run after any install/upgrade)

1. Raw handshake per server: newline-delimited JSON-RPC `initialize` →
   `notifications/initialized` → `tools/list`; expect the tool surfaces of §2.
2. Roundtrip: write a uniquely-tagged observation (e.g. "wickiup-<rand>") via
   each server's write tool; fresh process → read/search → confirm.
3. Through dsh: `dsh --profile headless "Remember … <token>"` (expect a memory
   write tool named in the reply), then a second headless run "What is …?"
   (expect the token). Memory is only as durable as the profile layer — if
   step 3 fails, re-run the §4 grep.
4. `engram mcp` → `mem_doctor`; `memorix doctor agents` for hook health.

## 6. Hygiene, Privacy & COMMS Integration

- **PQC:** server API keys (only Memorix optional-LLM/embedding features need
  any) live in the `pqc-secrets` bundle under `MEMORIX_*` names — never in
  `~/.memorix/config.toml` plaintext on shared machines.
- **Privacy:** all three stores are local-only. Before committing or syncing
  anything derived from memory (task files, handoff packets), scrub operator
  identifiers, credentials, and trajectories per `<COMMS>` packet hygiene.
  Engram auto-redacts `<private>…</private>` spans; do not rely on it.
- **Ledger memory:** durable cross-machine coordination still lives in the
  `.agents/{comms,tasks,handoffs}/` triad (git-synced). Repo-memory servers are
  per-machine convenience context, NOT the coordination system of record —
  never record a task claim only in memory.
- **Dispatches:** headless/ACP subagent dispatches inherit these tools (§4
  enables them profile-wide). Master orchestrators tell dispatches to *consult*
  memory (`memorix_project_context`, `mem_context`) during recon and to *store*
  discovered gotchas/decisions before exit — one write, typed, no narration.
- **Lifecycle:** stale/wrong memories get resolved, never left to rot:
  Memorix `memorix_resolve`, Engram `mem_delete`/`mem_review`, Reference
  `delete_observations`/`delete_entities`.

## 7. Known Gotchas

- **Reference Memory** relation creates fail if either entity doesn't exist;
  `search_nodes` is substring-only (no semantics) — route fuzzy lookups to
  Memorix/Engram.
- **Engram** project detection prefers git remote → same repo on different
  machines maps to one project; use `mem_merge_projects` after name drift.
- **Memorix** pins project to the Git root — run dsh from inside the repo, or
  override with `memorix_session_start(projectRoot=…)` on the HTTP transport.
- JSON-RPC ids from some clients are non-integer; Memorix 1.3.0 and
  server-memory echo integers reliably — use integer ids in raw smoke tests.
- `mem_search` requires the `query` parameter (passing `q` returns an FTS5
  syntax error that reads like a server bug).
