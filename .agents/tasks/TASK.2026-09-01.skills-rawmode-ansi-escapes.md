# TASK.2026-09-01.skills-rawmode-ansi-escapes

**Branch:** `fix/skills-rawmode-ansi-escapes` (worktree `../skills-rawmode-ansi-escapes`, from `main` @ `4b9ad59`)

## Root Cause
- In `_st_ui_frame`, color definitions from `src/colors.sh` (which use backslash escape strings like `\033[1;36m`) were formatted via `printf \x27\033[K%s\r\n\x27`.
- `%s` in `printf` treats input as literal text without expanding backslash escape sequences, causing raw strings like `\033[1;36m` to be displayed in the terminal instead of ANSI colored text.

## Fix
- Replaced `%s` format specifiers with `%b` in `_st_ui_frame` across all header, item, submit row, and footer `printf` lines.
- `%b` expands all backslash escape sequences in string arguments, correctly rendering ANSI colors across all terminal emulators.

## Verification
- PTY test suite verifying zero literal `\033` strings in the rendered terminal byte stream.
- Zero-Trust and PQC compliance security gate passed cleanly.
