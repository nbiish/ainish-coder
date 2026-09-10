# Task: Interactive TUI for Candidate Skill Ingestion via ainish-coder --skills-sync

- Date: 2026-09-10
- Branch: feat/skills-sync-tui
- Status: in-progress
- Scope: src/verify_skills.sh, bin/ainish-coder, src/help.sh

## Objective
Ensure `ainish-coder --rules` only deploys our latest skills from this root repo (`ainish-coder`) without ingesting or copying back target repo-specific skills, while `ainish-coder --skills-sync` provides the same interactive keypress TUI checkbox/toggle system to selectively copy over target repos' specific skills into `ainish-coder/.agents/skills/`.

## Progress
- Verified `ainish-coder --rules` strictly uses `deploy_skills` which is target-ward only.
- Implemented `_select_candidate_skills_raw` and `_select_candidate_skills_numbered` in `src/verify_skills.sh`.
- Updated `_select_candidate_skills` to route to raw-mode keypress TUI when in an interactive TTY, fallback numbered prompt otherwise, and headless/non-interactive auto-selection.
- Passed automated functional testing in headless mode and verified syntax cleanly with `bash -n`.
