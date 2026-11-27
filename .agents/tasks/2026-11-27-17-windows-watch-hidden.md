---
task_format: ainish/task/v1
slug: windows-watch-hidden
date: 2026-11-27
status: done
branch: fix/windows-watch-hidden
plan: .agents/plans/2026-11-27-17-windows-watch-hidden.md
operator: nanoboozhoo
---

# Task: Fix Windows `AinishMachineWatch` Console Popup + `mac-18gb` SSH DNS Drift

## Scope
- `src/machine_watch.sh` (`_mw_install_windows`, `_mw_uninstall_windows`)
- `scripts/test-machine-watch.sh`
- Live Windows host: `C:\Users\kenwa\.ssh\config` (`mac.attlocal.net` → `192.168.1.68` so Mullvad VPN doesn't break LAN DNS) + re-install `AinishMachineWatch` hidden.
