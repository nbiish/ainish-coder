# TASK.2026-08-30.rules-deploy-all-skills

`--rules` deploys all skill packs. Scrolls stay separate.

## Context
- Operator: all skills deploy with `ainish-coder --rules`; `--scrolls`
  content remains explicit-only (already refused in --rules bundling).
- `--rules` currently deploys only pqc-secrets, pqc-signatures-security,
  wtf-agent-hub. `deploy_skills` (src/deploy_skills.sh) deploys all packs.
- Motive: distribute prompt-free bootstrap era tooling (SKILL.md §5.12)
  to every project via one command.

## Design (chain-of-draft)
- Replace PQC-only confirm block with all-pack `deploy_skills` call.
- Keep confirm + dest pick + symlink choice parity with siblings.
- AINISH_LINK_MODE env prefix → per-file symlink mode.
- .agents/skills/ contains no .scrolls payload → exclusion automatic;
  guard anyway: skip any dir named .scrolls* (defense in depth).
- help.sh: --rules text + notes/examples updated.

#### worktree + comms checkin
#### bin/ainish-coder --rules block → deploy_skills
#### help.sh text updates
#### gates: bash -n + gitleaks staged
#### scratch deploy verify: all packs land, §5.12 present, no scrolls
#### intent-merge (await user confirm)
