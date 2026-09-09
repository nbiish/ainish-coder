---
name: repo-memory
description: >
  Repo-memory mastery: expert use of the three persistent-memory MCP servers
  available to any agent harness on this machine — Memorix (project memory +
  code graph, SQLite), MCP Reference Memory (knowledge-graph JSONL), and Engram
  (SQLite+FTS5 curated memory, Go). Covers the mastery memory-discipline loop
  (orient → recall → route → store → resolve), exact tool surfaces and call
  patterns, routing doctrine with concrete examples, session-open and
  session-close protocols, wiring any MCP-capable harness (Claude Code/Desktop,
  Cursor, VS Code, Codex, Gemini CLI, OpenCode, Zed, …), install/repair on any
  machine, verification smoke tests, hygiene (PQC secrets, privacy scrubbing),
  and coordination with the COMMS triad. Harness-agnostic: every instruction
  works identically whatever harness reads this skill. Use when starting a
  session in any repo, saving durable knowledge, recalling prior work,
  resolving conflicting memories, onboarding a new machine, or wiring memory
  into any agent harness.
---

# Repo-Memory — Expert Persistent Memory for ANY Agent Harness

Three complementary memory MCP servers run locally on this machine and are
available to **every MCP-capable agent harness** — the same tools, the same
stores, the same discipline regardless of whether you are Claude Code, Cursor,
Codex, OpenCode, Gemini CLI, VS Code, Zed, a headless CI agent, or anything
else that speaks MCP. Mastery of this skill means the three servers behave as
one memory system: you know **which server owns which kind of knowledge**, you
**recall before you store**, you write **one typed fact instead of narrating**,
and you **resolve stale entries** so recall stays trustworthy forever.

Tools surface in your harness as `mcp__<serverName>__<tool>` (name prefixes may
differ per harness — match on the server names `memorix`, `reference_memory`
and the `mem_*` / `create_*` tool names).

## 0. Mastery Doctrine — The Memory Discipline Loop

Run this loop unconsciously, every session, in order:

1. **Orient** (session start, before any edits): pull the memory brief —
   `memorix_project_context` (task lenses + code-graph status) and `mem_context`
   (recent sessions/observations). Read them; they change what you do next.
2. **Recall** (before every decision that feels "fresh"): assume prior agents
   have been here. Search before you conclude: `memorix_search` (observations,
   decisions, gotchas), `mem_search` (curated facts, conflicts),
   `search_nodes` (named entities and their relations). A memory hit is
   cheaper than a rediscovered bug.
3. **Route** (choose the owning server by knowledge KIND — §1 table):
   never ask "where do I save this?" — ask "what KIND of thing is this?"
4. **Store** (at the moment of learning, one typed write): facts the moment
   they harden, decisions the moment they're made, gotchas the moment they
   bite. One structured write — never prose narration, never duplicates
   (search first).
5. **Resolve** (stale = debt): wrong or superseded memory is worse than none.
   Retire aggressively — `memorix_resolve`, `mem_delete`/`mem_review`,
   `delete_observations`/`delete_entities`. Never leave a contradiction in
   the store.
6. **Close** (session end): leave the next agent richer than you found it —
   session summary + the 1–3 durable facts this session produced (§3).

**Anti-patterns (mastery = never doing these):** storing narration instead of
typed facts; duplicating an existing memory (unsearched writes); storing
task-coordination state in memory (that belongs in the repo's coordination
records); letting two servers hold contradictory versions without a conflict
verdict; raw secrets or operator identifiers in any memory.

## 1. The Three Servers — Route by Memory Kind

| | **Memorix** (`memorix`) | **Reference Memory** (`reference_memory`) | **Engram** (`engram`) |
|---|---|---|---|
| Source | [AVIDS2/memorix](https://github.com/AVIDS2/memorix) Apache-2.0, TS | `@modelcontextprotocol/server-memory` MIT, TS ([src/memory](https://github.com/modelcontextprotocol/servers/tree/main/src/memory)) | [Gentleman-Programming/engram](https://github.com/Gentleman-Programming/engram) MIT, Go |
| Store | SQLite per Git project (`~/.memorix/data`); Orama/FTS5 + optional LanceDB semantic | One JSONL knowledge graph (path pinned via env `MEMORY_FILE_PATH` — see §4) | SQLite + FTS5 `~/.engram/engram.db`; project auto-detected from git remote |
| Strength | Richest layer cake: observations, reasoning/decision rationale, **Git-derived facts**, TS code symbol graph, retention/dedupe, multi-agent team tools | The canonical **entity–relation–observation graph**; direct graph surgery; subscribable `memory://knowledge-graph` resource | Curated session memory with **conflict judging** (`mem_compare`/`mem_judge`), lifecycle review/decay, session summaries, `mem_doctor` |
| Launch | `memorix serve` (stdio) | `mcp-server-memory` (stdio) | `engram mcp` (stdio) |

**Routing doctrine — decide by KIND, then the server picks itself:**

| Knowledge kind | Owner | Exact call |
|---|---|---|
| Project fact, gotcha, bug fix, what-changed | Memorix | `memorix_store` (`type`: `gotcha`/`problem-solution`/`what-changed`/`discovery`/`why-it-exists`/`trade-off`) |
| Decision + rationale, alternatives, constraints, risks | Memorix (rich) | `memorix_store_reasoning` (`decision`, `rationale`, `alternatives`, `constraints`, `risks`) |
| Same, one-liner form | Engram | `mem_save` (`type`: `decision`/`architecture`) |
| Relationship between NAMED things (person→org, module→module, decision→superseded-by) | Reference Memory | `create_entities` first, then `create_relations` (active-voice verbs; **both endpoints must exist first**) |
| Session open / close / summary | Engram | `mem_session_start` / `mem_session_summary` (Goal/Instructions/Discoveries/Accomplished/Next Steps/Files) |
| Two memories disagree | Engram | `mem_compare` (relation: `conflicts_with`/`supersedes`/`scoped`/`related`/`compatible`/`not_conflict`) → `mem_judge`; then fix the loser per §0.5 |
| Where things stand right now | Engram | `mem_context` (recent) + `memorix_project_context` (brief) |
| Fuzzy "what do we know about X" | Memorix | `memorix_search` (`query`, `type`, `since`, `scope`) — semantic-ish; Reference `search_nodes` is substring-only |

**Examples:** "tests fail without `pnpm build` first" → Memorix gotcha.
"We chose SQLite over Postgres because WAL + zero-infra beats ops cost for
single-machine agents" → Memorix `memorix_store_reasoning` (+ Engram
`mem_save type=decision` if you want it in curated recall). "auth-module
depends_on pqc-secrets" → Reference Memory relation. "This session ended; here
is what happened" → Engram `mem_session_summary`.

## 2. Tool Surfaces (verified)

**Memorix** (micro profile default; `--mode lite|team|full` scales to 20/28/47 tools):
`memorix_project_context`, `memorix_context_pack`, `memorix_search` (query/limit/scope/type/since/status), `memorix_detail` (ids/typedRefs), `memorix_store` (entityName/type/title/narrative/facts/filesModified/concepts/topicKey/progress), `memorix_resolve`, `memorix_codegraph_status`; lite+ adds timeline, reasoning, sessions, retention/consolidate/dedupe, transfer, skills/rules sync; team+ adds `team_manage/team_message/team_task/team_file_lock/memorix_poll/memorix_handoff`. CLI: `memorix init --global`, `memorix setup --agent <name>`, `memorix doctor agents`, `memorix background start` (HTTP + dashboard `:3211/mcp`).

**Reference Memory** (9 tools): `create_entities`, `create_relations` (fails if endpoints missing), `add_observations`, `delete_entities` (cascades relations), `delete_observations`, `delete_relations`, `read_graph`, `search_nodes` (substring, ≤2048 chars), `open_nodes`. JSONL records: `{"type":"entity","name":…,"entityType":…,"observations":[…]}` / `{"type":"relation","from":…,"to":…,"relationType":…}`.

**Engram** (22 `mem_*` tools): retrieve `mem_current_project`, `mem_context`, `mem_search(query)`, `mem_timeline(observation_id)`, `mem_get_observation`, `mem_stats`; write `mem_save(title,type,content,topic_key?,scope?)`, `mem_update`, `mem_save_prompt`, `mem_capture_passive` (parses `## Key Learnings:`), `mem_session_summary`; manage `mem_delete`, `mem_pin`/`mem_unpin`, `mem_review`, `mem_merge_projects`, `mem_doctor`; judge `mem_compare`, `mem_judge`. CLI: `engram tui`, `engram serve` (HTTP `127.0.0.1:7437`), `engram export/import`.

## 3. Session Protocols (copy into your behavior, verbatim)

**Open (first tool calls of any session, any repo):**
1. `memorix_project_context` — the brief; note stale/suspect cautions.
2. `mem_context` — what recent sessions did and left behind.
3. If the task touches a named subsystem: `memorix_search` + `mem_search` +
   `search_nodes` for that subsystem's names.

**During work:**
- The moment a fact hardens (bug root-caused, decision made, gotcha bites):
  route + store immediately (§0.4). One typed write.
- If you find yourself re-deriving something, STOP — search first; you are
  probably duplicating a memory that exists.
- If a new fact contradicts a stored one: `mem_compare` → `mem_judge` →
  retire/fix the stale side in the same breath.

**Close (last tool calls before yielding):**
1. `mem_session_summary` (Engram) — structured Goal/Discoveries/Accomplished/
   Next Steps/Files.
2. 1–3 durable typed writes to Memorix for anything that outlives the session.
3. Retire anything you disproved today (§0.5). A session that stores nothing
   and resolves nothing learned nothing.
4. Land the record: update `.agents/memories/` (digest + refreshed exports,
   §8) and commit it on the task branch.

**Subagent/dispatch protocol:** agents you spawn inherit these tools. Give
each dispatch two lines: recon ("consult `memorix_project_context` +
`mem_context` before edits") and closeout ("store one typed gotcha/decision
before exit"). One write, typed, no narration.

## 4. Wiring Any Agent Harness (MCP stdio config)

All three are standard stdio MCP servers — any harness that accepts MCP
servers can use them. Registration shape is the universal `mcpServers` JSON:

```json
{
  "mcpServers": {
    "memorix":           { "command": "memorix", "args": ["serve"] },
    "reference_memory":  { "command": "mcp-server-memory" },
    "engram":            { "command": "engram", "args": ["mcp"] }
  }
}
```

- **reference_memory:** always set env `MEMORY_FILE_PATH` to an absolute,
  stable path (e.g. `~/.local/state/reference-memory/graph.jsonl`) — the
  unwired default lands inside the npm package cache and is wiped on upgrade.
  The file is JSONL (§2 records) and safe to back up or sync.
- **Engram env:** `ENGRAM_DATA_DIR` (data), `ENGRAM_PROJECT` (project pin),
  `ENGRAM_HTTP_TOKEN` (admin HTTP). **Memorix env:** `MEMORIX_DATA_DIR`,
  `MEMORIX_MODE` (tool profile).
- **Built-in installers:** `memorix setup --agent <name>` (claude, codex,
  cursor, windsurf, copilot, kiro, gemini-cli, opencode, and more) and
  `engram setup <agent>` (opencode, cursor, gemini-cli, codex, windsurf, kiro,
  qwen, …) write the config for supported harnesses automatically; Claude Code
  also supports the Engram plugin marketplace.
- Always launch from **inside the target repo** — Memorix and Engram bind to
  the Git root / remote they find in the working directory.
- **Secrets:** no server needs a key for core memory. Optional Memorix
  LLM/embedding features read env vars at launch — inject them decrypted from
  a secrets manager at runtime; never write keys into config files.

## 5. Install on a New Machine

Prerequisites: Node ≥22.18 (nvm); Go 1.24+ only if building engram from source.

```bash
npm install -g memorix                 # pin: memorix@<current>
npm install -g @modelcontextprotocol/server-memory   # pin: @2026.7.4 line
go install github.com/Gentleman-Programming/engram/cmd/engram@v1.20.0
#   or prebuilt: https://github.com/Gentleman-Programming/engram/releases → linux_amd64.tar.gz → ~/.local/bin
memorix init --global && memorix setup --agent <your-harness>   # guidance + hooks (optional)
```

## 6. Verification Smoke Test (run after any install/upgrade)

1. Raw handshake per server (works for any harness): newline-delimited JSON-RPC
   `initialize` → `notifications/initialized` → `tools/list`; expect the tool
   surfaces of §2.
2. Roundtrip: write a uniquely-tagged observation (e.g. "wickiup-<rand>") via
   each server's write tool; fresh process → read/search → confirm.
3. Through your harness: prompt "Remember … <token>" (expect a memory write
   tool call), then a fresh session "What is …?" (expect the token back). If
   this fails, the harness's MCP registration is broken — fix §4 wiring, not
   the servers.
4. `engram mcp` → `mem_doctor`; `memorix doctor agents` for hook health.

## 7. Hygiene, Privacy & Coordination Integration

- **PQC:** any server API keys live encrypted in the secrets manager (PQC-wrapped
  bundle) under tool-prefixed names — never in `~/.memorix/config.toml` or any
  plaintext config on shared machines.
- **Privacy:** all three stores are local-only. Before committing or syncing
  anything derived from memory (task files, handoff packets, docs), scrub
  operator identifiers, credentials, and trajectories. Engram auto-redacts
  `<private>…</private>` spans; do not rely on it.
- **Not the system of record:** durable cross-machine coordination lives in
  the repository's coordination records (e.g. the `.agents/{comms,tasks,
  handoffs}/` triad, git-synced). Live memory-server stores are per-machine
  context; the git-tracked `.agents/memories/` folder (§8) is the portable
  knowledge record. Never record a task claim ONLY in memory.
- **Lifecycle:** stale/wrong memories get resolved, never left to rot:
  Memorix `memorix_resolve`, Engram `mem_delete`/`mem_review`, Reference
  `delete_observations`/`delete_entities`.

## 8. The Repo Memory Layer — `.agents/memories/`

Every repository carries a git-tracked `.agents/memories/` folder beside the
other `.agents/` coordination folders — the **singular place where memory data
lands** so it can be inspected, diffed, iterated on, and cloned to other
machines (the live server stores are per-machine; this folder is portable).

**Layout** (contract: `.agents/memories/llms.txt` in each repo):

| Path | What |
|---|---|
| `MEMORY.md` | Curated digest — one typed entry per durable fact, newest first per section (Facts / Decisions / Gotchas) |
| `exports/engram.json` | `engram export <file>` snapshot |
| `exports/memorix.<project>.json` | `memorix transfer export --format json --out <file>` snapshot |
| `exports/reference-graph.jsonl` | Copy of the Reference Memory `MEMORY_FILE_PATH` JSONL |

**Write protocol (session close, before yielding):**
1. Append the session's durable facts to `MEMORY.md` (typed, dated, sourced;
   prune anything you retired per §0.5). Facts that are CONTRACTS belong in
   the owning `llms.txt`, never duplicated here.
2. Regenerate exports whose live stores moved:
   `engram export .agents/memories/exports/engram.json` ·
   `memorix transfer export --format json --out
   .agents/memories/exports/memorix.<project>.json` · copy the reference JSONL.
   Scrub retired/soft-deleted memories and any identifiers first — engram
   snapshots include soft-deleted rows.
3. Commit `.agents/memories/` on the task branch; it merges and pushes like
   any artifact. Hygiene rules of §7 apply in full before commit.

**Recall fallback:** when a memory server is unreachable (fresh clone before
setup, CI, broken MCP registration), read `MEMORY.md` and grep `exports/` —
the folder is the offline memory of record.

**Connection to the other `.agents/` folders:** `comms/`, `tasks/`,
`handoffs/` remain the coordination system of record — task claims and
lifecycle NEVER move into memories. `skills/` holds this skill. The memory
layer holds knowledge. When a handoff packet or task record needs prior
context, cite `MEMORY.md` entries; when a memory proves a task's done-criteria
wrong, fix both.

## 9. Known Gotchas

- **Reference Memory** relation creates fail if either entity doesn't exist;
  `search_nodes` is substring-only (no semantics) — route fuzzy lookups to
  Memorix/Engram.
- **Engram** project detection prefers git remote → the same repo on different
  machines maps to one project; use `mem_merge_projects` after name drift.
- **Memorix** pins project to the Git root — launch the server from inside the
  repo, or bind explicitly (`memorix_session_start(projectRoot=…)` on HTTP).
- JSON-RPC ids from some clients are non-integer; Memorix 1.3.0 and
  server-memory echo integers reliably — use integer ids in raw smoke tests.
- `mem_search` requires the `query` parameter (passing `q` returns an FTS5
  syntax error that reads like a server bug).
