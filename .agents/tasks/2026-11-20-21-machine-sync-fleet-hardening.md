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
- `hermes cron list` shows exactly two jobs, both maintenance and both healthy as of this check:
  `Hermes Federated Backup` (hourly at :50) and `Hermes Federation Adopt` (daily at 05:05), both
  `no-agent` script jobs. There is **no** business-operations schedule: nothing polls sales,
  refreshes listings, or drives traffic.
- `ai.hermes.gateway` is loaded in launchd (pid 68196), separate from
  `ai.nanoboozhoo.ainish-machine-watch` (pid 20249).

**The real gap for "constantly running agents doing business":** there is no scheduler that runs
income tasks on a cadence. The sync watcher watches git, and the hermes cron only backs up. Nothing
currently polls sales, refreshes listings, or drives traffic. That is a new daemon, not a fix to
`--machine-sync` — recorded here because the operator's request conflated the two, and building it
inside the sync watcher would make both harder to debug.

## CORRECTION to D1 (found while implementing T1)

**The original D1 diagnosis was wrong.** I claimed `_ms_peer_tmp` produced a malformed `/C:/...`
path. It does not. Verified directly:

- `scp` to `windows-128gb:C:/Users/kenwa/AppData/Local/Temp/...` succeeds; the file lands.
- A real bundle fetched with `git -C 'D:/...' fetch 'C:/Users/.../real-test.bundle'` succeeds and
  prints `* [new branch] main -> refs/testcheck/main`.

So drive-letter temp paths work as constructed. The `does not appear to be a git repository` error
is real, but the cause is different.

**Actual root cause: a fixed peer-side bundle filename races across concurrent cycles.**
`_ms_peer_tmp` returns the peer temp dir, and both directions append a *constant* filename
(`ainish-machine-sync-in.bundle` / `-out.bundle`) while the local side correctly uses `mktemp`.
Every path that finishes with the bundle deletes it. So when the watcher's retry overlaps the next
tick — or a manual run overlaps either — one process unlinks the file the other is about to fetch,
and git reports the file missing even though `scp` succeeded (exit 0). That is precisely what the
log recorded on 11 of 37 cycles, always as `sent=false received=true`.

The source already contains a comment about the two *directions* colliding; it did not anticipate
concurrent runs of the *same* direction.

**Reproduced deterministically** (see commit): with a shared filename, fetch A succeeds, A deletes
the file, fetch B fails with the exact logged message. With per-process names, both succeed.

**Fix:** remote bundle names carry `$$` and `$RANDOM`.
**Verification:** `scripts/test-machine-sync.sh` → 60 passed, 0 failed; three concurrent
`--both --ff-peers` runs completed with zero collision errors and zero leftover bundles on the peer.

## STOPPED: ainish-coder on Windows is an unrelated history (do not merge)

While registering `ainish-coder` itself for federation (T8), the sync reported
`peer could not fast-forward 'main' (diverged)` and the diagnosis is worse than a lag:

| Check | Mac | Windows |
|---|---|---|
| root commit | `dda3a90` | `dc9d7e2` |
| commit count | 1030 | 915 |
| tracked files | 568 | 450 |
| `git merge-base` | — | **NO COMMON ANCESTOR** |

Two different root commits whose message is identical (`Initial commit: reset repo context for AI`).
These are independent histories of the same project, not one behind the other. The trees overlap in
purpose but differ in content.

**Nothing was merged or forced.** Fast-forward is genuinely impossible and a merge would produce
915 invented conflicts decided by a tool. The `--machine-link` registration itself is harmless (it
only records intent), but it should not be left armed on a pair that cannot reconcile: every cycle
will deliver refs and then refuse to advance the checkout.

**Whoever resolves this must choose deliberately**, and it is an operator decision:

1. Keep Mac's history and re-clone Windows from it (loses whatever only exists in Windows' 915
   commits — 118 fewer files, but not a subset).
2. Keep Windows' history and re-clone Mac.
3. Find the true shared origin (GitHub `origin` is reachable from both; compare `origin/main` against
   each) and reconcile deliberately.

**Recorded state:** the concurrency fix is committed on Mac `main` (`f16b286`) and is NOT on Windows.
Windows still runs the fixed-filename version. The Mac watcher was restarted onto the fix and logged
one clean cycle with no new collision errors.

## Verdict on T8

Do not complete T8 until this is resolved. Registering a repo whose peer history is unrelated turns a
working federation into a permanently "diverged" one that reports a skipped fast-forward every cycle.

## Addendum 2 — the business scheduler path exists and works (verified)

Follow-up to the scheduler gap noted in Addendum 1. It is closer to ready than that noted.

**Profile-scoped invocation works.** `hermes -z "<prompt>" --profile marketing-engineer` returned
`SEZ_READY`, so a specific profile can be driven non-interactively from a script. Note the flag is
`--profile`, not `-p` (which hermes reads as a positional command and rejects).

**The cron scheduler is alive.** `hermes cron status` reports a running ticker (heartbeat 31s), 2
active jobs, and a next-run time — it is not dormant.

**`hermes cron create` is the missing business-automation path.** It takes a schedule (`30m`,
`every 2h`, or cron syntax) plus a self-contained prompt, and `--deliver` accepts
`bot-chat[:profile]`, which injects output into a local profile's canonical bot chat. That is
exactly "a job runs on a cadence and a named profile does the work".

**One gap to design around:** `cron create` has no `--profile` flag (verified: zero matches). Profile
targeting happens through the `--deliver bot-chat:<profile>` grammar, not by running the job as that
profile. So a marketing job must be expressed as a prompt delivered into the marketing-engineer bot
chat, not as a command executed by that profile.

**Nothing was scheduled.** Creating a job that spends model tokens on a cadence is a spending
decision for the operator, and the AGENTS.md contract puts unattended spend behind an explicit yes.
The mechanics are proven; the policy is not mine to set.
