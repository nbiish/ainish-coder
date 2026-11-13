# Hour-stamped coordination records

- **status:** implementing
- **branch:** `fix/hour-stamped-coordination`
- **plan:** `.agents/plans/2026-11-12-hour-stamped-coordination.plan.md`
- **worktree:** `/Users/nbiish/code/ainish-coder-hourcoord`
- **operator ask:** "Review the latest plan and let's proceed to get that implemented."
- **scope:** `AGENTS.md`, `.agents/{plans,llms.txt,templates,memories}/llms.txt`, `.agents/templates/plan.md`,
  `.agents/skills/question-me/SKILL.md` + `skills-to-distribute/skills/question-me/SKILL.md`,
  `llms.txt`, `README.md`, `src/README.md`, `src/templates/AGENTS.COMMS.md`, `.gitignore`,
  `src/plan_gate.sh`, `src/deploy_agents_comms.sh`, `src/scroll_integrity.sh`, `src/help.sh`,
  `bin/ainish-coder`, `bin/git-context.sh`, `bin/security_gate.py`, `bin/context-packet.sh`,
  `src/rag/rag.py`, `src/rag/src/{wiki.rs,main.rs}`, `src/rag/tests/*.py`,
  `scripts/test-pqc-dist.sh`

## What was found in review (2026-11-12)

1. **The plan edited the engine that is not running.** It scoped §3 to the Rust crate
   (`src/rag/src/`). `bin/ainish-rag:69` hard-codes `PY_ONLY_SUBCOMMANDS=" context secrets "`, and
   no native binary exists in `bin/`, so `rag.py` is the engine that serves every `context` call.
   The context call opening this task proved it: its warning strings exist only in `rag.py`.
   Operator chose "amend the plan first" over implementing the Rust-only version.
2. **"Newest wins" was name-sorted, not mtime-sorted** at `rag.py:5564`, `rag.py:5870`,
   `main.rs:3637-3640`. Under grandfathering both schemes coexist for a UTC day, and
   `…-09-memory.md` collates before `…-memory.txt`, so the grandfather file wins. The plan's
   central invariant would have been false on exactly the days it matters.
3. **Dropping the `.plan.md` suffix blinded plan discovery** in three places
   (`rag.py:5897`, `plan_gate.sh:63`, `context-packet.sh:70`). The plan-gate would have refused
   every commit on every new-scheme branch with "no plan of record".
4. **Eight unlisted surfaces** hard-matched `-team.txt` / `-task.md` / `.plan.md`:
   `bin/git-context.sh`, `bin/security_gate.py`, `bin/context-packet.sh`,
   `src/templates/AGENTS.COMMS.md`, `.agents/memories/llms.txt`, `.agents/templates/llms.txt`,
   `src/rag/tests/*.py`, `.gitignore`.
5. **`_read_today_task_record` (`rag.py:7257`) is already dead** — it looks for
   `{date}-task.md`, a name the old scheme never produced. Repaired as part of this task.
6. **Pre-existing `--rules` failure** at the deploy-time signing gate (signer `69e7233d…` vs
   committed anchor `d98405ea…`), recorded in
   `.agents/suggestions/2026-11-12-rules-signing-anchor-mismatch.txt`. Verification records a
   baseline so this task's delta is measurable.

## What changed

_(filled in at close — see the plan's §3 for the full surface list)_
