---
task_format: ainish/task/v1
slug: computer-use-browser-use-skills
date: 2026-11-27
status: done
branch: feat/computer-use-browser-use-skills
plan: .agents/plans/2026-11-27-16-computer-use-browser-use-skills.md
operator: nanoboozhoo
---

# Task: Add `computer-use` (`agent-desktop`) & Upgrade `browser-use` (`Browser MCP`) Skills + Fix Multi-Repo TCC Watch Transport

## Scope
- `skills-to-distribute/skills/computer-use/SKILL.md` (new)
- `skills-to-distribute/skills/browser-use/SKILL.md`
- `skills-to-distribute/skills/llms.txt` & `.agents/skills/llms.txt`
- `src/help.sh`
- `src/machine_watch.sh` & `scripts/test-machine-watch.sh`

## Progress
- [x] Merged PR #24 (`954a25f`) and activated Windows `AinishMachineWatch`.
- [x] Fetched official `vercel-labs/agent-desktop` and `browsermcp.io/docs` references.
- [x] Write skill packs, update indexes/help, fix macOS multi-repo TCC watch transport, test (`test-machine-watch.sh` 46/46), and open PR.
