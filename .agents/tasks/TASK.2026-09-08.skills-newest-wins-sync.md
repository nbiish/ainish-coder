# TASK.2026-09-08.skills-newest-wins-sync

- **Triage:** now
- **Branch:** `feat/skills-newest-wins-sync`
- **Worktree:** `/mnt/d/Code/skills-newest-wins-sync`
- **Agent:** dsh-glm-orchestrator
- **Status:** active

## Scope

`--skills` joins the two-way sync; newest-version-wins conflict resolution in
BOTH directions; `--skills --headless` auto-updates the newest/last-used skills.

## Changes

1. `src/verify_skills.sh` — sync_ainish_skills: newest-wins guard in the
   target-ward pass (a more-recently-refined target copy is never clobbered
   by an older source; equal mtimes: source wins); staged-swap ingestion
   (same-FS stage → writability pre-check → atomic rename) so a failed ingest
   never destroys the canonical pack; ingestions pinned to copy mode;
   `.ainish-ingest.*` staging dirs excluded from enumeration; kept_newer in
   summary.
2. `bin/ainish-coder` — `--skills` routes through sync_ainish_skills in all
   three modes (headless auto-ingests candidates; interactive keeps toggle UI
   + symlink choice; non-interactive = persisted selection).
3. `src/skills_selection.sh` / `src/deploy_skills.sh` — `.ainish-ingest.*`
   excluded from selection lists/UIs and deploy.
4. `src/help.sh`, `llms.txt` — contract text updated (DOX pass done).

## Verification

- bash -n all changed shell files: OK (shellcheck not installed).
- Functional matrix `/tmp/test-skills-sync.sh`: 8/8 PASS — ingest new,
  ingest target-refined, update stale target, scroll-channel exclusion,
  summary counts, newest-wins guard, no-clobber on failed ingest,
  convergence without ping-pong. Real repo untouched (git status verified).
- Read-only `--skills-verify` smoke on /mnt/d/Code/tts-cli: correct report.

## Done criteria

- Merged to main `--no-ff`, worktree removed, branch deleted, ledger closed.
