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

## Addendum — hermes profiles and the scheduler gap (verified 2026-11-20)

The operator asked for continuously running agents plus the `marketing-engineer` profile.

**Verified working:**
- `hermes` v0.23.3 at `~/.hermes/hermes-agent`; `hermes profile list` shows
  `default`, **`marketing-engineer`**, `rev`, `veteran-production-coder`, all with gateway `running`.
- `hermes -z "<prompt>" -m mimo-v2.6-pro` completes a one-shot prompt and prints the answer
  (tested: returned `PROFILE_OK`). So a *programmatic, non-interactive* invocation exists and works.
- Profile selection is a subcommand (`hermes profile`), not a `-p` flag — `hermes -p "text"` fails
  with `'text' is not a hermes command`. Anyone wiring SEZ into it should use `-z`, and select the
  profile through `hermes profile` state rather than an inline flag.
- `hermes cron list` shows exactly one job: `Hermes Federated Backup`, hourly at :50. There is **no**
  business-operations schedule.
- `ai.hermes.gateway` is loaded in launchd (pid 68196), separate from
  `ai.nanoboozhoo.ainish-machine-watch` (pid 20249).

**The real gap for "constantly running agents doing business":** there is no scheduler that runs
income tasks on a cadence. The sync watcher watches git, and the hermes cron only backs up. Nothing
currently polls sales, refreshes listings, or drives traffic. That is a new daemon, not a fix to
`--machine-sync` — recorded here because the operator's request conflated the two, and building it
inside the sync watcher would make both harder to debug.
