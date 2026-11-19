2026-11-12-hour-stamped-coordination.plan
---
plan_format: ainish/plan/v1
slug: hour-stamped-coordination
date: 2026-11-12
status: done
branch: fix/hour-stamped-coordination
worktree: /Users/nbiish/code/ainish-coder-hourcoord
task_record: .agents/tasks/2026-11-12-hour-stamped-coordination-task.md
---

# Hour-stamped coordination records (`.agents/{dirs}/{date}-{HH}-slug.md`)

**Goal:** coordination artifacts gain a UTC-hour segment so multiple tasks in one day stop
colliding into one date bucket, and every coordination record becomes markdown.

**Operator decisions (clarified 2026-11-12):**
1. Comms stays ONE ledger per UTC date — renamed to `{date}-team.md`; hour stamps apply to
   tasks/plans/memories/suggestions only.
2. Hour clock is UTC, zero-padded two digits (`{date}-{HH}`), so names sort chronologically as
   text on every machine (macOS + WSL).
3. Grandfather everything existing — old names stay put; the convention applies from cutover.
4. Type suffixes drop: `{date}-{HH}-slug.md` for all four hour-stamped dirs; the type is carried
   by frontmatter (`plan_format: ainish/plan/v1` etc.), which the hook and RAG already parse.

**Layout decision (delegated to the agent, decided):** FLAT files with the hour in the name —
NOT `{date}/` subdirectories. The retrieval model's core invariant is "the newest file in each of
`.agents/{comms,memories,plans,suggestions,tasks}`"; flat + zero-padded HH keeps that invariant
ex