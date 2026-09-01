# TASK.2026-09-01.skill-picker-rawmode

**Branch:** `feat/skill-picker-rawmode` (worktree `../skill-picker-rawmode`, from `main` @ `c1488ef`)

## Operator contract
1. Interactive skill selection (`ainish-coder --skills`, `--skills-sync`, `--rules` on a TTY) provides a raw-mode keypress checkbox UI:
   - `↑`/`↓`, `j`/`k`, `Tab`/`Shift-Tab` move cursor across skill list and `[ Save & submit ]`.
   - `Space` toggles the active pack (`[x]` on / `[ ]` off), or submits if on `[ Save & submit ]`.
   - `Enter` immediately saves and persists the batched selection to disk (`~/.config/ainish-coder/skills-selection.json`).
   - `a`/`n` turns all packs on/off.
   - `d` toggles the default policy for newly discovered packs (`on`/`off`), immediately reflected in the footer.
   - `q`, `Esc`, `Ctrl+C`, `Ctrl+D` cancel immediately without persisting changes (exit code 130).
2. Non-TTY / piped environments fall back safely to the legacy numbered prompt.
3. `--headless` skips all UI and applies the persisted per-repo selection as-is.
4. Hard-excluded packs (`.scrolls*`, `8thfire-scrolls`, `ghost-layer-injector`) remain strictly in the `--scrolls` channel.

## Implementation details
- `src/skills_selection.sh`:
  - Implemented `_skills_toggle_ui_raw` with clean ANSI terminal control, `stty raw -echo`, cursor hide/show, and signal traps (`INT TERM EXIT`) for clean restoration.
  - Added support for application cursor keys (`\x1bOA`, `\x1bOB`), Shift-Tab (`\x1b[Z`), and Tab navigation.
  - Implemented batched persistence: mutations apply in-memory during interaction and only write to disk upon explicit save/submit.
  - Fixed `skills_selection_list` source directory resolution to handle targets before deployment.
- `llms.txt`: Documented keypress toggle UI mechanics.

## Verification
- Automated PTY interaction suite covering:
  1. Space toggle, arrow navigation, default toggle, enter save.
  2. `q` cancellation (exit code 130, no disk writes).
  3. `Esc` cancellation with Bash 3.2 fallback timeout (exit code 130, no disk writes).
  4. `a` (all on) batch toggle + save.
  5. `n` (all off) batch toggle + save.
  6. `Tab` / `Shift-Tab` / `j`/`k` navigation.
  7. Space on `[ Save & submit ]` row submit.
- Full E2E deployment & sync suite:
  - Headless deployment of 21 default packs.
  - Deselection of 2 packs, redeployment sweeping deselected directories (19 remain).
  - Sync honoring persisted selection.
  - Byte-integrity verification reporting identical/missing sets.
