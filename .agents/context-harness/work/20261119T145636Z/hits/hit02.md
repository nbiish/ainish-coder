llms
# `.agents/plans/` — Plans of Record

## Purpose

One file per task: the plan an agent will follow, the clarifications that shaped it, and the todo
list derived from both. A plan is written *before* implementation and read *during* it, which is what
distinguishes it from `docs/` (forward-looking proposals that no agent is executing) and from
`.agents/tasks/` (coordination state: lane, branch, status, verdict).

The three artifacts split cleanly:

| Artifact | Holds | Lifetime |
|---|---|---|
| `.agents/plans/*.md` | Reasoning: problem, anchor facts, design, clarifications, todos, gates | The task, plus the history of how it was decided |
| `.agents/tasks/*.md` | Coordination: lane, branch, status, scope, verdict, `plan:` pointer | The task, and the fleet's record of who was doing what |
| `.agents/comms/{date}-team.md` | Lifecycle lines: checkin, update, checkout | One UTC day |

## Naming contract

`.agents/plans/{YYYY-MM-DD}-{HH}-{kebab-slug}.md` — UTC date, zero-padded UTC hour, then a short slug
matching the branch's topic (`feat/agents-plans-artifact` → `2026-11-12-09-plans-artifact.md`).

Two schemes are live and both must be accepted by anything that reads this directory:

| Scheme | Shape | Status |
|---|---|---|
| current | `{date}-{HH}-{slug}.md` | written from 2026-11-12 onward |
| grandfathered | `{date}-{slug}.plan.md` | every plan already on disk; never renamed |