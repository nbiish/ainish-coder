2026-11-21-00-consolidation-specialist-agents
# Task: consolidation gets its own specialized agent pair, and a gate that blocks

- lane: now
- branch: `feat/consolidation-specialist-agents`
- status: implementing
- plan: `.agents/plans/2026-11-21-00-consolidation-specialist-agents.md`
- scope: `src/context/engine.py`, `src/context/context_harness.py`, `src/deploy_rules_sync.sh`,
  `scripts/consolidation-skills/`, `AGENTS.md`, `scripts/test-pqc-dist.sh`
- objective: A dedicated `consolidate-elephant` / `consolidate-goldfish` pair, with their own hermes
  profiles and skills, consolidates the records older than the newest three and checks each other's work
  before anything is written or removed — compartmentalized from the prime's own pair.

## What the live test proved

- **Machine-sync works.** A real sync delivered our ref to the peer
  (`refs/remotes/mac-18gb/main` = `c71f164`), correctly left the peer's divergent `main` untouched, and
  the running watcher auto-committed work as `Nanoboozhoo - embodied by cursor`, not the operator.
- **Consolidation does not.** Seven digests, **91 originals left** across five folders; tasks failed all
  six chunks. It uses the prime's own roles, its review is advisory, and it corrupted the prime:
  - `newest task record: DIGEST-tasks-2026-11.md`
  - `newest plan: DIGEST-plans-2026-11.md (status: designing)` — a digest has no `status:` field, so the
    reader invented one.

## Findings

- `pi` timed out at 90s/200s/300s on payloads that answered in 5s with a shorter instruction; hermes
  answered `HERMES_OK` in 9s on the same host.
- The only pre-write check is length + section-count + promise-opener. The goldfish review runs AFTER
  and does not block.
- Digests sort into the same name-space as records, so orientation picks them up.

## Next action

T1: the hermes transport.
