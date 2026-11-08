# Task: make question-me produce a .plan.md per project

- lane: now
- branch: `feat/agents-plans-artifact` (worktree `D:\Code\ainish-coder-plans`)
- status: done
- plan: `.agents/plans/2026-11-08-plans-artifact.plan.md`
- scope: `.agents/plans/`, `.agents/templates/plan.md`, `.agents/templates/llms.txt`, `.agents/llms.txt`, `.agents/skills/question-me/`, `AGENTS.md`, `llms.txt`, `README.md`, `bin/ainish-coder`, `bin/context-packet.sh`, `src/deploy_*.sh`, `src/verify_skills.sh`, `src/help.sh`, `src/rag/rag.py`, `src/rag/tests/test_context_injection.py`, `scripts/test-pqc-dist.sh`, `.agents/canonical/`, `.agents/audit/contract-history.*`
- objective: Give `question-me` a durable planning output — one `.agents/plans/{date}-{slug}.plan.md` holding the agent's plan, the clarification ledger, and the derived todos — and wire that directory through deploy and retrieval orientation.

## Why

`question-me` ended by writing its design record into `.agents/tasks/`, which conflates coordination
state (branch, status, scope, verdict) with working intent (what we plan to build, what was
clarified, what is left). The second is long-lived and read repeatedly during implementation, so it
gets its own artifact and its own directory. The operator's framing: a plan document to follow, with
a section for the agent's plan, a section for the user/agent clarifications, and a section of all
todos derived from those combined.

## What changed

- **`.agents/templates/plan.md`** — frontmatter contract (`plan_format`, `slug`, `date`, `status`,
  `branch`, `worktree`, `task_record`, `operator`) plus seven fixed sections: Problem, Anchor Facts,
  Plan, Clarifications, Todos, Verification, Open Decisions.
- **`.agents/plans/llms.txt`** — DOX child doc. Naming contract, the plans/tasks/comms split table,
  section ownership, mutation rules, and verification commands.
- **`question-me/SKILL.md`** — rewritten around plan compilation. Pillar 6 became "Living Plan
  Artifact"; Phase 0 opens the plan and fills §1-§2; Phase 2 rule 6 logs each decision to §4 before
  the next question; Phase 3 became "Plan Compilation & Lock" (derive §5 last, fill §6, set `ready`,
  create the task record with a `plan:` line). §6 now documents the artifact rather than repeating
  the template, and a new §7 Plan Lifecycle assigns sections to agents per status.
- **`question-me/references/plan-artifacts.md`** — new. Todo derivation rules, the five tests for an
  atomic todo, what does not belong in §5, split thresholds, and closeout.
- **Deploy wiring** — `plans/` scaffolded and the template plus both index files copied by
  `bin/ainish-coder`, `src/deploy_agents.sh`, `src/deploy_skills.sh`, `src/verify_skills.sh`.
- **Orientation** — `render_orientation_section` reports the newest plan's status and open-todo
  count using a stdlib-only frontmatter reader; `bin/context-packet.sh` gains a matching
  `plan_state` section so the non-RAG path is not the one path that cannot see the plan.
- **Contract** — `AGENTS.md` now says planning documents belong in `.agents/plans/{date}-{slug}.plan.md`
  and adds the directory to "Where everything else lives". Canonical snapshot refreshed and re-signed.

## Verification

- `py -m unittest discover -s src/rag/tests` — **172 pass** (167 before; 5 new covering plan
  reporting, mtime ordering, absent directory, malformed frontmatter, and unknown status).
- `bash scripts/test-pqc-dist.sh` — **150 assertions pass**, 6 new (deploy map, child-index
  existence with a non-vacuous parse guard, template ships, plans contract ships, frontmatter
  contract declared, question-me writes plans). The 14 failures are pre-existing WSL-host
  `pqc-install`/`pqc-status` environment failures: a detached baseline worktree at `663da33` fails
  the identical 14.
- `ainish-rag audit verify` — 16/16 receipts verified after the contract re-sign; contract history
  chained to the new `84be207a…` digest.
- Scratch `ainish-coder --rules /tmp/plans-target` — target receives `.agents/plans/`,
  `.agents/templates/plan.md`, and `.agents/plans/llms.txt`.
- Live `ainish-rag context` in that target — orientation reports
  `newest plan: 2026-11-08-smoke.plan.md (status: implementing)` and `todos: 1 done, 2 open`; an
  empty tree still exits 0 with no plan line.
- `bin/context-packet.sh` — `plan_state` reports the same status and counts.

## Not done, and why

- **No `plan-check.sh` gate.** The schema is frontmatter plus stable headings; a linter is only worth
  writing once real plans exist and the failure modes are known rather than guessed.
- **No migration of historical `.agents/tasks/` records** into plans. They were written under the old
  contract and rewriting them would fabricate decisions nobody made.
- **No `--question-me` CLI verb.** The skill is agent-invoked; inventing a flag surface nobody asked
  for is the bikeshedding the skill exists to prevent.
- **`--rules-verify` still reports `NO_VERIFIER` for six sibling targets.** Identical on the
  `663da33` baseline, so it predates this change: those manifests are stale and this WSL host has no
  signer.

## Cleanup

The compiled `bin/ainish-rag.exe` was copied into the worktree only to re-sign the contract and was
removed afterwards; it is gitignored and never tracked. Baseline worktree `D:\Code\ac-plans-baseline`
is a detached scratch checkout and can be removed with
`git worktree remove D:/Code/ac-plans-baseline --force`.
