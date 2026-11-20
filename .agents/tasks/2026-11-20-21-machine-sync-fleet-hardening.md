# 2026-11-20 21 machine-sync fleet hardening

**Lane:** ainish-coder main (`~/code/ainish-coder`)
**Branch:** `feat/machine-sync-fleet-hardening`
**Plan:** `.agents/plans/2026-11-20-21-machine-sync-fleet-hardening.md`
**Status:** ready (plan written, implementation not started)

## Objective

Make `ainish-coder --machine-sync` reliable enough to run an unattended multi-machine fleet, after
finding that the live watcher fails ~30% of cycles and reports success-shaped but unverified results.

## Defects found (all verified in source or against a live run)

| # | Defect | Evidence |
|---|---|---|
| D1 | Windows temp-path join produces `/C:/...`, breaking the fetch | `watch.log`: `fatal: 'C:/Users/kenwa/AppData/Local/Temp/ainish-machine-sync-in.bundle' does not appear to be a git repository`; `_ms_peer_tmp` + `_ms_push` join |
| D2 | Watcher fails 11 of 37 cycles | `grep -c 'Z ok:'` = 26, `grep -c 'Z failed:'` = 11 |
| D3 | Smoke probe always `unverified` on Windows | probes `<synced-repo>/bin/ainish-coder.cmd`; real launcher is `D:\Code\ainish-coder\bin\ainish-coder.cmd` |
| D4 | Untracked-but-ignored files block all fast-forwards | `_ms_fast_forward_peer` treats any `--porcelain` output as dirty; `?? products/` blocked it repeatedly |
| D5 | Ignored binaries have no transport at all | `_ms_wip_snapshot` uses `git add -A`; help text says ignored files are "not in git" |
| D6 | `--auto-commit` uses the operator's git identity | observed commit author `Hermes Bot <hermes@bot.local>` |
| D7 | `watch.state` pid is stale (62786) vs live pid (20249) | `cat watch.state` vs `ps` |
| D8 | The tool's own repo is not federated | mac `2ed96d2` vs Windows `1bd8865`; `links.txt` has one entry |

## What is NOT broken

- Federation does converge: both machines were verified at the same HEAD (`ed875f1`) after a manual
  sync. The refs arrive; the *claims* about them are unreliable.
- The TCC fallback for external volumes works: loopback ssh succeeds and transport resolves to
  `ssh`, which is the designed behaviour for a launchd agent on an external (removable) volume.
- Dedup of Windows/WSL aliases onto one checkout identity works (`_ms_checkout_id`).

## Next action

T1 first: it is the highest-frequency failure and the smallest patch. Do not start T4/T7 (policy and
ergonomics) before T1–T3 make the transport trustworthy, because a fleet that lies about its state
cannot be debugged.
