# TASK.2026-09-01.skills-selection-toggle

**Branch:** `feat/skills-selection-toggle` (worktree `../skills-selection-toggle`, from `main` @ `ed6327b`)

## Operator contract
1. `ainish-coder --skills` opens a numbered node-choice toggle UI; per-pack on/off persists across terminals.
2. `--skills`/`--rules` accept a `--headless` second argument: agents/CI path applying the persisted selection with zero prompts.
3. Live intake: the current repo's `.agents/skills/` is enumerated from disk each run — additions, renames, deletions handled regardless of config staleness.
4. `--skills-sync` interactive mode also opens the toggle UI (add/remove packs to sync).
5. `AGENTS.maintainer.md` — frozen copy of `AGENTS.md` — distributes via `--rules`/`--agents` to guide target-repo refinement/updates/docs. `AGENTS-review.md` + `AGENTS-tiny.md` removed.
6. `llms.txt`, COMMS protocol, `.agents/tasks/` must fully reflect the updated system; operator does hands-on testing after merge.

## Design
- **Config:** `~/.config/ainish-coder/skills-selection.json` — `{"repos": {"<abs-target-repo>": {"<pack>": true|false, "default": true}}}`. Atomic writes (tmp+rename). `AINISH_SKILLS_SELECTION` env overrides path (tests).
- **Precedence:** explicit entry > repo `default` > global default (on; `AINISH_SKILLS_DEFAULT=off` flips).
- **Hard exclusions (never selectable):** `.scrolls*`, `8thfire-scrolls`, `ghost-layer-injector` — `--scrolls` channel only.
- **Module:** `src/skills_selection.sh` — `skills_selection_state/set/set_default/has_entry/list`, `_skills_toggle_ui`.
- **Live intake:** UI + deploy loop enumerate `REPO_DIR/.agents/skills/` from disk every run. Deployed packs are PINNED (explicit config entry), so renames/deletions at source are detectable: target pack absent from source WITH an entry = stale → removed. Packs without entries = foreign, never touched.

## CLI wiring
- `--skills [dir] [--headless]`: headless → deploy per config; interactive → toggle UI then deploy; non-interactive default → deploy per config.
- `--rules [dir] [--headless]`: skills block swaps "all packs" for selection-governed deploy (+UI in interactive).
- `--skills-sync [dir] [--headless]`: headless/non-interactive → sync per config; interactive → toggle UI then sync. Deselected packs never pulled/repaired.
- `--rules`/`--agents`: new `deploy_agents_maintainer` step (headless deploys unprompted).

## Verification (all observed live)
- Module unit: set/state/list/default precedence, atomic JSON.
- Headless `--skills`: 21 packs default; toggling 2 off → both removed (toggle-off removes prior copies), 19 remain.
- Live intake: new pack deployed (default on); rename → old removed (stale sweep via pinned entry), new deployed (22→22); deletion → swept (22→21).
- Headless `--skills-sync`: deselected-for-repo pack drift NOT repaired.
- `--rules --headless`: selection honored (tts-cli absent when off), AGENTS.md + maintainer + scroll-pack exclusion all hold.
- Interactive PTY test of `--skills -i`: toggled pack 1 off → config persisted (21 entries) → deployed set = 20 packs, toggled pack absent.
- Cross-terminal persistence: default config path honored from fresh env-cleared process.
- `AGENTS.maintainer.md` distributes and byte-matches `AGENTS.md`; review/tiny variants gone.
