# TASK: AGENTS.md Coordination Triad — Handoffs + Date-Stamped Comms

- **Date:** 2026-09-07
- **Branch:** `docs/agents-triad-datestamp`
- **Worktree:** `/mnt/d/Code/agents-triad-datestamp`
- **Goal:** Iterate AGENTS.md so agents are orchestrated, clearly and concisely, through the coordination triad — `.agents/comms/` (dated ledger), `.agents/tasks/` (task records), `.agents/handoffs/` (mastered handoff packets) — and strip comms timing to `{date}-team.txt` (one file per UTC date) instead of excess hourly-stamped documents; agents decide when a new file is warranted (new task, different agent/subagent group chat, incident split).
- **Status:** Complete (2026-09-07) — awaiting operator merge confirmation.

## Chain of Draft
1. Worktree gate passed.
2. Comms ledger checked in.
3. Ledger excess observed (two Sep-7 files).
4. COMMS rewritten as triad.
5. Handoffs wired into workflow, orchestration, audit.
6. `{date}-{time}` stripped everywhere.
7. Diff audited: no secrets, no banned crypto.

## Files
- `AGENTS.md`

## Notes
- Handoff packet contract: `.agents/handoffs/HANDOFF.{date}.{slug}.{from}-to-{to}.md`; no packet, no dispatch.
- Existing `*-team.txt` glob references in <SERVERS> stay valid under the new naming.
