2026-11-21-14-airpc-lifecycle-demo
# Task: aiRPC lifecycle, cross-repo sessions, queries — and a live demo on the repo

- lane: now
- branch: `skill/airpc-lifecycle` (merged `48207bc`), `skill/airpc-tldraw5` (merged `3ca9e46`)
- status: done (smoke 28/28; demo live at http://127.0.0.1:7331; browser-verified, zero page errors)
- plan: `.agents/plans/2026-11-21-14-airpc-lifecycle-demo.md`
- scope: `.agents/skills/aiRPC/SKILL.md`, `.agents/skills/aiRPC/references/{bridge.mjs,protocol.md,canvas-app.tsx}`
- objective: The operator can see aiRPC running on this repo, sessions survive stop/start, chats
  span repos and queries, and no process exists that neither the user nor the agent can stop.

## What changed

| Was | Now |
|---|---|
| `serve` had no stop path and no pid record | `stop`/`status` subcommands, `POST /shutdown` (canvas Stop button), `serve.pid`, clean SIGTERM; `stop` refuses to signal a pid that is not the bridge |
| state persisted but resume was undocumented | restart is normal operation: manifest/calls/acks intact, `wait` resumes at the next unacked call |
| one repo per manifest; ids hashed `path#anchor` | `project --from name=path` (repeatable) scans each repo's allowlisted surface; `repo` is inside id and digest; `kindLane + repoIndex·9` lanes |
| no question channel | `kind: "query"` calls — answered in the ack, never edited (an edit ask without a digest binding answers `needs-you`) |
| canvas: placeholder geometry, no panel | `Rectangle2d`, chat feed across repos, query bar, Stop button; served **by** the bridge (`serve --app`) so canvas and API are one origin and one process |

## Findings

1. The tldraw 5.6.2 `ShapeUtil` contract replaced `indicator()` with `getIndicatorPath(): Path2D`.
   Built and opened, the drop-in crashed exactly there (`getIndicatorPath is not a function` —
   reported from the operator's console). Fixed against the installed package's `.d.ts`, not from
   memory; verified with a page-error listener after reload (`errors: []`). The version is now
   pinned in the skill and the module header.
2. Reading the scanner before smoking caught a real bug: the preamble path pushed one block per
   line — duplicate empty anchors would have rejected every manifest. Accumulate, then emit one.
3. `validateAck` demanded `new_digest` on every `done`, but the protocol says query acks carry
   none — valid query acks were rejected (and everything downstream cascaded).
4. The smoke itself must obey agent discipline: a second `wait` re-delivers an unacked call, so
   ack before the next wait — tests are consumers too.
5. Ops facts: `git worktree remove` refuses worktrees of repos with submodules (it unregisters
   but leaves the directory); contract files carry macOS `uchg` (user immutable) — clear it only
   on the task's own worktree copies, never the main checkout.

## Verification

- Extended smoke 28/28: multi-repo `--from` projection (ids unique, `Rules~2` duplicate-heading
  suffix, independent id/digest derivation match, one preamble block), cross-repo call + query
  round trip with acks, status/stop/restart/resume (history intact, settled calls not
  re-delivered), `--by` deadline exit 2, unsafe path 400, static index + nested asset served,
  traversal rejected (404/404), `end` event stops the loop, `POST /shutdown` stops serve.
- `node --check` clean; `npx esbuild` parses the TSX; SKILL.md frontmatter and all local links OK.
- Demo: canvas built against tldraw 5.6.2 and served by the bridge at
  http://127.0.0.1:7331 — 323 blocks (ainish-coder 311, mai-agentic 12) across the nine kinds;
  rendering verified in a browser twice; post-fix reload with a page-error listener: zero errors.

## Open

- Demo `serve` (pid 38656, session `demo`) intentionally left running for the operator's
  inspection. Stop paths, all equivalent: the canvas Stop button, `node references/bridge.mjs
  stop --session demo`, or `kill 38656`. It must not outlive the inspection.
- Suggestions that outlive the task: `.agents/suggestions/2026-11-21-14-airpc-followups.md`
  (projection automation; distribution decision).
