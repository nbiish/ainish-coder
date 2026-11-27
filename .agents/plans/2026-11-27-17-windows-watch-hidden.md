---
plan_format: ainish/plan/v1
slug: windows-watch-hidden
date: 2026-11-27
status: done
branch: fix/windows-watch-hidden
worktree: /Users/nbiish/code/ainish-coder-worktrees/fix-windows-watch-hidden
task_record: .agents/tasks/2026-11-27-17-windows-watch-hidden.md
integration: new-pr
operator: nanoboozhoo
---

# Plan: Run Windows `AinishMachineWatch` Task Scheduler Silently (No Terminal Popup)

## 1. Objective

Prevent `ainish-coder --machine-watch --install` on Windows from popping up a visible `cmd.exe` terminal window every minute when Task Scheduler triggers `AinishMachineWatch`. Launch `ainish-coder.cmd --machine-watch --once --pull-now` via a tiny `wscript.exe //B //NoLogo` VBScript wrapper (`~/.config/ainish-coder/ainish-machine-watch-hidden.vbs`, window style `0`), and remove the wrapper on `--uninstall`.

## 2. Threat Model & Constraints

- **Assets:** Operator's Windows desktop UX and `~/.config/ainish-coder/` state/logs.
- **Controls:** Wrapper accepts only the fixed CLI path from Task Scheduler, executes with window style `0` (hidden), no shell interpolation of untrusted data, and `--uninstall` cleans both the Scheduled Task and `.vbs` file.

## 3. Checklist

- [x] Update `_mw_install_windows` and `_mw_uninstall_windows` in `src/machine_watch.sh` to use a hidden `wscript.exe` launcher.
- [x] Add hermetic test in `scripts/test-machine-watch.sh`.
- [x] Verify `bash -n`, `--plan-check`, and `scripts/test-machine-watch.sh`, open PR, merge, sync Windows, and re-install `AinishMachineWatch`.
