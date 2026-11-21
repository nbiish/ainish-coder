---
plan_format: ainish/plan/v1
slug: airpc-lifecycle-demo
date: 2026-11-21
status: implementing
branch: skill/airpc-lifecycle
worktree: /Users/nbiish/code/ainish-coder-airpc2
task_record: .agents/tasks/2026-11-21-14-airpc-lifecycle-demo.md
operator: direct (Nanoboozhoo, Orca/omp harness)
---

# Plan: aiRPC lifecycle, cross-repo sessions, queries — and a live demo on the repo

## 1. Problem

The operator asked to **see** aiRPC run on this repo, and set three requirements the first cut does
not meet: (1) a session must survive stop/start — you can add to it after starting the stopped
server back up; (2) aiRPC chats must span **repos and queries**; (3) it must be easy to stop — no
running process may exist that neither the user nor the agent can stop.

## 2. Anchor Facts

- State already persists: the bridge writes `inbox.jsonl`/`log.jsonl`/`manifest.json` under
  `$AIRPC_HOME/<session>/` and `wait` re-delivers unacked calls — established from
  `references/bridge.mjs` (written this session) and the smoke (settled call not re-delivered).
- Nothing stops a `serve` today: no `stop` subcommand, no pid record, no shutdown endpoint —
  established from the same file. `serve` is the only long-lived process in the design
  (SKILL.md §3), so stopping it is the whole lifecycle problem.
- Node v22.22.3 and npm 10.9.8 are on this host — established from `node --version`,
  `npm --version`; the bridge targets Node ≥22 already.
- `~/code` holds many repos; a cross-repo demo needs a second repo with an `.agents/` surface —
  to be established by listing candidates before the demo.
- `canvas-app.tsx` carries a `getGeometry` placeholder (`this.app.getGeometry('rectangle')` is
  not the ShapeUtil contract) and is syntax-checked only — established from the file and the
  closed task record's "Open" section.

## 3. Plan

### Goals

- One process total, three stop paths: `bridge.mjs stop` (user), `bridge.mjs stop` (agent),
  a Stop control in the canvas (`POST /shutdown`); `bridge.mjs status` reports liveness; `serve`
  records its pid and exits cleanly on SIGTERM. The skill mandates start→stop pairing.
- Session resume: stop the server, start it again, and the session continues — manifest, calls,
  acks intact; `wait` resumes at the next unacked call. Documented as the "add to the stopped
  server after starting it up" rule.
- Cross-repo: `project --from name=path` (repeatable) scans the allowlisted record surface of each
  repo and emits one manifest; blocks and calls carry `repo`; id/digest include the repo so
  identical paths in two repos cannot collide.
- Queries: a call may be `kind: "query"` (no block seat, empty path) — a question answered in the
  ack without editing the record; the canvas gets a query bar and per-block call/ack threads.
- A live demo the operator can open: the built canvas served **by the bridge itself** (`serve
  --app DIR`), projected across two repos.

### Non-goals

- No multi-user auth, no remote binding — loopback-only stands (SKILL.md §9.1).
- Queries never edit: an edit request without a block seat answers `needs-you` pointing at the
  block — digest binding is what makes edits safe and a query has none.

### Constraints and invariants

- All SKILL.md §9 security invariants hold; `--app` static serving is path-safe (no `..`, no
  absolute escapes) and serves only from the given directory.
- id/digest algorithms change (repo included) — protocol.md is amended in the same change; nothing
  external consumes v1 yet, so the version stays 1 and the algorithms are replaced, not forked.
- Zero-dependency bridge; the canvas demo app is runtime state under `$AIRPC_HOME/app`, not repo
  content.

### Interfaces and data

- `blockId(repo, path, anchor) = "blk-" + sha256(repo + ":" + path + "#" + anchor)[0:12]`;
  `digest = sha256(repo + "\0" + path + "\0" + body)[0:12]`.
- Manifest block: + `repo` (name, non-empty); query calls: `kind: "query"`, `path: ""`,
  `anchor` = question title, `block_id: ""`, `digest: ""`.
- Bridge CLI: `serve [--port] [--session] [--app DIR]`, `project (--manifest F | --from name=path)…`,
  `wait [--session] [--by] [--url]`, `ack --file F`, `stop [--session]`, `status [--session]`.
- HTTP: + `GET /`… static app, `POST /shutdown` → `202`, then clean exit.

### Files and symbols

- `references/bridge.mjs` — stop/status/pid/SIGTERM, `--app` static serving, `project --from`
  scanner, query-call validation, repo in id/digest.
- `references/protocol.md` — algorithms, repo field, query kind, lifecycle section.
- `references/canvas-app.tsx` — `Rectangle2d` geometry, same-origin bridge, query bar, per-block
  threads from `/state` (now includes inbox), Stop button.
- `SKILL.md` — lifecycle rules (start/stop pairing, status, resume), multi-repo projection,
  query semantics; verification updated.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Separate vite dev server for the demo | Two processes, two stop paths; serving the built app from the bridge keeps exactly one stoppable process. |
| Query blocks projected into the manifest | A query has no record seat; faking one would forge a digest binding that means nothing. |
| Keeping id/digest stable and disambiguating by manifest order | Order is layout, not identity; two repos both shipping `AGENTS.md` would collide silently. |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Scanner pulls secrets or signed artifacts into the canvas | Scanner enforces the §4 allowlist in code (`.agents/{wiki,plans,tasks,comms,memories,suggestions}`, `AGENTS.md`, `llms.txt`), never `audit/`, `canonical/`, dotfiles |
| `stop` kills a serve belonging to another session | `stop` targets `$AIRPC_HOME/<session>/serve.pid` only and verifies the pid is the bridge (argv check) before signaling |
| Resume double-delivers a call the agent was mid-edit on | At-least-once is documented; the digest re-check on every call is the guard (protocol §6) |

## 4. Clarifications

### 4.1 Lifecycle shape

- **Question:** How must the running server be stoppable and resumable?
- **Options:** 1. (Recommended) one process, pid-recorded, three stop paths, state persists across
  restarts — the operator's "stop it easily… from the user or agent end" and "add to the stopped
  server after starting it up"; 2. supervisor daemon — a second thing that can itself leak.
- **Selected:** Option 1.
- **Trade-off accepted:** The operator starts/stops the bridge explicitly; no auto-restart.
- **asked:** operator

### 4.2 Cross-repo and queries

- **Question:** What do "aiRPC chats across repos and queries" mean at the wire level?
- **Options:** 1. (Recommended) one session, many repos in the manifest, plus query calls answered
  without edits; 2. one session per repo — no cross-repo chat.
- **Selected:** Option 1; query calls (`kind: "query"`) never edit (ack `needs-you` for edit asks).
- **Trade-off accepted:** The id/digest algorithm changes (repo folded in).
- **asked:** operator

## 5. Todos

- [ ] **T1** Bridge: `stop`/`status`/pid/SIGTERM, `POST /shutdown`, `serve --app`.
  - from: §3 | done when: stop kills serve and status reflects it | verify: smoke
- [ ] **T2** Bridge: `project --from name=path` scanner + repo-aware id/digest + query validation.
  - from: §3 | done when: a two-repo manifest validates end to end | verify: smoke
- [ ] **T3** Canvas: Rectangle2d, same-origin, threads, query bar, Stop button.
  - from: §3 | done when: parses and matches protocol payloads | verify: esbuild parse
- [ ] **T4** SKILL.md + protocol.md carry lifecycle, multi-repo, query semantics.
  - from: §3 | done when: links resolve, field names match wire | verify: link + grep check
- [ ] **T5** Extended smoke: stop, restart-resume, query, multi-repo.
  - from: §3 | done when: all pass | verify: smoke script output
- [ ] **T6** Demo: build canvas, `serve --app`, project two repos, hand over URL + stop paths.
  - from: §1 | done when: operator can open the canvas and stop everything | verify: curl /state

## 6. Verification

- `node --check references/bridge.mjs` — clean.
- Extended smoke — every case in T5 green, recorded in the task record.
- esbuild parse of `canvas-app.tsx`; link check on both markdown files.
- Demo: `curl -s http://127.0.0.1:7331/state` shows both repos' blocks before hand-over.

## 7. Open Decisions

- Whether the scanner becomes `ainish-coder --project` (suggestion 2026-11-21-14) once the demo
  proves the shape — settled when the operator asks for it as a first-class command.
