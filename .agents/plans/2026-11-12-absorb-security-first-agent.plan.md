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
   stop conditions, and the report requirements. Overlap already stated (external text is data,
   secrets, destructive paths, fail closed, one writer) is not duplicated. The context-call section
   gains "the files win over the summary". "Record durable state" and *Close* gain the
   `.agents/suggestions/{date}-{slug}.txt` prompt.
2. **Indexes** — `skills-to-distribute/skills/llms.txt` and `.agents/skills/llms.txt` drop the pack
   bullet and index row (kept byte-identical to each other).
3. **`_skill_mandatory` (`src/skills_selection.sh`)** — back to `pqc-secrets|ainish-security`;
   rationale comment updated (the posture now lives in the contract, not a linked pack).
4. **`src/deploy_skills.sh`** — mandatory-rail comment no longer names the pack.
5. **`src/help.sh`** — 19 → 18 packs; drop the row and the third mandatory name.
6. **`scripts/test-pqc-dist.sh`** — mandatory-set loops and derived names drop the pack; new
   negative pins (retired pack not mandatory, help/index no longer reference it); AGENTS.md
   assertions pin the absorbed posture and the suggestions prompt; PRD assertion flips to
   `Two packs are mandatory`; contract-critical loop drops the pack.
7. **`llms.txt`** — mandatory-packs sentence three → two; document the retirement and why; curated
   subset list drops the pack.
8. **`README.md`** — curated-subset list and skill table row drop it.
9. **Delete** `.agents/skills/security-first-agent/` and
   `skills-to-distribute/skills/security-first-agent/` via `git rm`.

History (`.agents/{tasks,comms,plans}` records naming the pack) stays untouched — append-only.

## Verification

- `bash scripts/test-pqc-dist.sh` green (was 240/240).
- `bash -n` on touched scripts.
- Hermetic `--rules` probe: deploys exactly `ainish-security` + `pqc-secrets`, no selector rows,
  and `security-first-agent` appears nowhere in the deployed tree.
- `--skills-list --json`: mandatory reports two; `--skills-verify` still fails hard on an absent
  mandatory pack.
