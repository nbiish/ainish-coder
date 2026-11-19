2026-11-12-absorb-security-first-agent.plan
---
plan_format: ainish/plan/v1
slug: absorb-security-first-agent
date: 2026-11-12
status: done
branch: fix/absorb-security-first-agent
worktree: /Users/nbiish/code/ainish-coder-absorb-sfa
task_record: .agents/tasks/2026-11-12-absorb-security-first-agent-task.md
---

# Absorb `security-first-agent` into `AGENTS.md`, retire the pack

- **operator ask:** "We need to expertly integrate the security-first-agent skill info into the
  AGENTS.md so agents don't decide to skip that info. Then we can remove that skill from the
  .agents/skills, skills-to-distribute folder, and `cli ainish-coder --rules` logic." Follow-up:
  AGENTS.md must also prompt filling `.agents/suggestions/` with the proper `{date}-{slug}.txt`.

## Finding

The 2026-11-12 mandatory-deploy task made `security-first-agent` ship on every `--rules` run, but a
skill is progressive disclosure: an agent that never triggers it never reads it. The posture belongs
in the one file every session reads whole — the contract. Once absorbed, the pack is retired and no
payload entry can dangle.

## Changes

1. **`AGENTS.md`** — new `Security-first posture` section: the order of operations (threat-model,
   read the record, name the authority, smallest reversible step, verify by read-back, record), the
   hard rules not already in the contract (least context for subagents, no unattended authority),
   stop conditions, and the repor