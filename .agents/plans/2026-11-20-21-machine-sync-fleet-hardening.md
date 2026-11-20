---
plan_format: ainish/plan/v1
slug: machine-sync-fleet-hardening
date: 2026-11-20
status: ready
branch: feat/machine-sync-fleet-hardening
worktree: ~/code/ainish-coder
task_record: .agents/tasks/2026-11-20-21-machine-sync-fleet-hardening.md
operator: operator
---

# Plan: make `--machine-sync` reliable enough to run an unattended fleet

## 1. Problem

The operator needs several machines to keep a business running with agents working continuously and
almost no human intervention. Federation between those machines is the load-bearing piece: every
agent's work, every plan, and every coordination record has to reach the other machines without
anyone typing a sync command. Today it mostly works, but it fails in ways that are silent, and the
operator cannot tell when the fleet has drifted.

The immediate stakes are real: the operator is in financial difficulty and needs income flowing,
which means the machines must be trustworthy unattended. A sync that reports success while
delivering nothing is worse than one that fails loudly.

## 2. Anchor Facts

Every fact below was verified in this session against the source or a live run.

- **Watcher runs, and has for 5 days.** `launchctl print gui/$(id -u)/ai.nanoboozhoo.ainish-machine-watch`
  reports `state = running`, `pid = 20249`, `last exit code = (never exited)`; process etime is
  `05-07:07:47` — established from `ps -eo pid,etime` and `launchctl print`.
- **The watcher fails ~30% of cycles.** `~/.config/ainish-coder/watch.log` holds 26 `Z ok:` lines
  and 11 `Z failed:` lines — established from `grep -c 'Z ok:'` / `grep -c 'Z failed:'`.
- **Root cause of those failures is a malformed Windows temp path.** The log contains
  `fatal: 'C:/Users/kenwa/AppData/Local/Temp/ainish-machine-sync-in.bundle' does not appear to be a
  git repository` and `fatal: Could not read from remote repository` — established from the log and
  `ssh windows-128gb 'Write-Output $env:TEMP'`, which returns `C:\Users\kenwa\AppData\Local\Temp`.
- **The path is built with a leading separator glued onto an already-absolute Windows path.**
  `_ms_peer_tmp` converts `C:\...` to `C:/...` and returns it; `_ms_push` then does
  `remote_bundle="$(_ms_peer_tmp …)/ainish-machine-sync-in.bundle"` — established from
  `src/machine_sync.sh` (`_ms_peer_tmp` and `_ms_push`).
- **The smoke probe can never succeed on a Windows peer.** `_ms_smoke_peer` probes
  `${root%/}/bin/ainish-coder.cmd` inside the *synced repository*, but that launcher lives at
  `D:\Code\ainish-coder\bin\ainish-coder.cmd` (a different repo) — established from
  `src/machine_sync.sh` and `ssh windows-128gb 'Get-Command ainish-coder'`. Every run therefore
  reports `smoke: windows-128gb — unverified`.
- **Fast-forward is skipped whenever the peer holds any untracked file.** `_ms_fast_forward_peer`
  treats a non-empty `git status --porcelain` as "peer has local changes" and returns early.
  `--porcelain` includes `??` untracked paths. In this session a single untracked directory
  (`products/`, holding gitignored binaries) blocked the fast-forward repeatedly — established from
  `src/machine_sync.sh` and from the live sequence where `?? products/` was the only entry.
- **Ignored files cannot cross, by design.** `_ms_wip_snapshot` uses `git add -A`, so anything
  matched by `.gitignore` is never captured; the `--help` text states this explicitly ("ignored
  files … are not in git"). Any binary-only asset therefore has no transport — established from
  `src/machine_sync.sh` and `--machine-sync --help`.
- **`--auto-commit` authors commits with the operator's git identity.** It runs a plain
  `git commit` with no `-c user.name/user.email`, so commits are attributed to the operator's
  configured identity (observed: `Hermes Bot <hermes@bot.local>`) rather than the machine. The
  contract forbids co-authorship but permits `Nanoboozhoo - embodied by {harness}` — established from
  `src/machine_sync.sh` and `git log -1 --format='%an <%ae>'` in the consumer repo.
- **Only one repository is federated.** `~/.config/ainish-coder/links.txt` contains exactly one line
  (`goal-first-trillion → windows-128gb`). `~/code/ainish-coder` is at `2ed96d2` on this machine and
  `1bd8865` on Windows, i.e. **the sync tool itself is not synced** — established from `cat links.txt`
  and `git -C /mnt/d/Code/ainish-coder rev-parse`.
- **The watcher state file disagrees with the running process.** `watch.state` records `pid=62786`
  while the live process is `20249` — established from `cat watch.state` vs `ps`. Stale pid means a
  reader cannot tell whether the watcher is alive.
- **Loopback ssh works**, so the TCC workaround for external volumes is viable here —
  established from `ssh -o BatchMode=yes localhost 'echo LOOPBACK_OK'`.
- **The repo lives on an external volume** (a removable volume under `/Volumes/`), the exact case
  `machine_watch.sh` documents as TCC-blocked for a launchd-spawned process; transport is resolved
  to `ssh` (recorded in `~/.config/ainish-coder/transport`), matching the designed fallback.

## 3. Plan

### Goals

- A sync cycle has **one** definition of "the peer is up to date", and a run that reports success
  has been proven to have delivered the ref.
- Windows peers stop failing on temp-path construction; failure rate on a 20-cycle sample is 0.
- The smoke probe answers a real question ("can this peer run the tool?") and never reports a
  false `unverified` caused by probing the wrong path.
- A peer holding untracked-but-ignored files is not treated as dirty for fast-forward purposes, so
  `main` advances on both machines without human intervention.
- There is a supported transport for ignored binaries, or a documented refusal — not a silent void.
- Watcher liveness is answerable from a file the operator can read, without racing a pid.
- Agent-run cycles never author commits as the operator.

### Non-goals

- Making `--machine-sync` a general backup tool. It federates git repos; ignored-file transport is
  a separate concern (Syncthing or an explicit asset channel).
- Replacing the bundle-based transport with a git remote server. The offline-capable bundle design
  is correct for machines that are not always reachable; only its bugs are in scope.
- Multi-repo watching beyond what `links.txt` already supports. Registering more repos is
  configuration, not code — but see T7, which does add a supported way to do it.

### Constraints and invariants

- `AGENTS.md`: secrets never in files/argv/logs; commits are the operator's authorship only, with
  the documented `Nanoboozhoo - embodied by {harness}` escape hatch for forced authorship.
- `.agents/plans/llms.txt`: frontmatter keys and section shapes are a parsing contract, read by
  line-based readers. Do not add keys without updating the readers.
- The tool must keep working when the peer runs an **older** ainish-coder (a machine that has not
  synced yet is exactly the machine you pull from) — `_ms_snap_cmd` documents this explicitly.
- PowerShell is the Windows peer's login shell: no `&&`, no `>/dev/null` in remote commands.

### Proposed architecture

Four changes, all inside `src/machine_sync.sh` except the last:

```
  _ms_peer_tmp  ──► returns a path joined safely for the peer's shell
                     (POSIX: /tmp;  Windows: C:/... with no extra leading /)

  _ms_dirty_state ─► replaces the raw `git status --porcelain` emptiness test:
                     classifies tracked changes vs untracked-ignored vs untracked-real,
                     so fast-forward can proceed when only ignored files differ

  _ms_smoke_peer  ──► resolves the launcher from the PEER's own PATH/known roots,
                     not from the synced repo's bin/; reports "not installed" distinctly
                     from "unverified"

  _ms_watch_write ─► atomic state write (tmp + rename) carrying pid + start time,
                     so a reader can detect a dead watcher instead of trusting a stale pid
```

The through-line is **fail closed on claims, not on delivery**. Delivering refs must keep trying and
succeeding; any statement the tool makes about the result must be provable.

### Interfaces and data

| Surface | Before | After |
|---|---|---|
| `_ms_peer_tmp` | may return `/C:/...` via caller join | returns a shell-safe absolute path; caller never prepends `/` |
| `_ms_fast_forward_peer` | any porcelain output ⇒ skip | skip only on tracked modifications; log ignored-only as "advance" |
| `_ms_smoke_peer` verdict | `ok` / `unverified` | `ok` / `not-installed` / `unverified`, each with the resolved path |
| `watch.state` | `pid=` may be stale | `pid=<n>` + `started=<iso>` + `alive=<bool>` rewritten each cycle |
| `--machine-sync --json` | per-peer `ok` bool | unchanged shape; add `"smoke":"ok\|not-installed\|unverified"` (additive) |

### Files and symbols

- `src/machine_sync.sh` — `_ms_peer_tmp` (~L675), `_ms_push` (~L786) for the join bug;
  `_ms_fast_forward_peer` (~L639) for the dirty classification; `_ms_smoke_peer` (~L1300) for
  launcher resolution; auto-commit block (~L1095) for identity.
- `src/machine_watch.sh` — state write path near the cycle end; `_mw_plist_path`/`_mw_unit_path`
  unchanged.
- `.agents/tasks/2026-11-20-21-machine-sync-fleet-hardening.md` — new task record.
- `src/tests/` (new) — regression tests for the path join and the dirty classification.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Patch only the `/C:` join and ship | Leaves a 30%-failure class undiscovered; the same join is used in the pull direction |
| Make fast-forward force (`--ff` on peer) | A peer's branch is not ours to move; would discard real local work |
| Treat ignored files as transportable via `git add -f` | Silently commits secrets and build output into published history |
| Replace bundles with an always-on git server | Machines are intermittently reachable; the bundle design is the right one |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Loosening the dirty test lets a genuine local edit get clobbered | Classify per path; only `!!` (ignored) may be ignored; `??` untracked **still blocks** unless it is inside an ignored directory |
| Smoke verdict change breaks a consumer parsing `ok` | Add the field; never remove `ok`. Grep the repo for parsers before merging |
| Auto-commit identity change alters history attribution | Commit as `Nanoboozhoo - embodied by {machine}` per contract; never the operator |
| Watcher state rewrite races a concurrent cycle | Write to temp + atomic rename; include `started` so staleness is computable |

## 4. Clarifications

- T4 (ignored-file transport) is scoped to a **documented decision**, not an implementation:
  the operator's machine pair has no Syncthing installed (verified), and writing a new transport is a
  larger design than this plan. `asked: resolved from code` — the tool already documents ignored
  files as out of scope; the defect is that nothing tells the operator that binaries therefore have
  no path at all.
- T6 (multi-repo registration) is configuration via `--machine-link`, which already exists.
  `asked: resolved from code`.

## 5. Todos

- [ ] T1 Fix the Windows temp-path join: `_ms_peer_tmp` returns a shell-safe path; `_ms_push` no
  longer prepends `/`. Prove with a 20-cycle watcher sample showing zero `failed:` lines.
- [ ] T2 Replace the fast-forward dirty test with a classifier that distinguishes tracked
  modifications, untracked-ignored, and untracked-real. Prove: a peer whose only difference is an
  ignored directory fast-forwards; a peer with a real edit does not.
- [ ] T3 Make the smoke probe resolve the launcher from the peer (`Get-Command` / known roots), and
  report `not-installed` distinctly. Prove: verdict is `ok` on Windows once the launcher is found.
- [ ] T4 Document the ignored-binary gap in `--machine-sync --help` and the watch guide: state that
  ignored files have no transport and name the supported alternatives.
- [ ] T5 `--auto-commit` authors as `Nanoboozhoo - embodied by {machine}`, never the operator's
  identity. Prove: run in a scratch repo and read `%an <%ae>` back.
- [ ] T6 Atomic `watch.state` with `pid`/`started`/`alive`, so a dead watcher is detectable from the
  file alone.
- [ ] T7 Add a `--machine-link --list` (or equivalent) that prints the linked fleet so the operator
  can see which repos are actually federated without reading `links.txt` by hand.
- [ ] T8 Register `~/code/ainish-coder` itself in `links.txt` so tool fixes reach both machines;
  today the tool is out of sync (`2ed96d2` vs `1bd8865`).

## 6. Verification

- `grep -c 'Z failed:' ~/.config/ainish-coder/watch.log` does not increase across a 20-cycle sample.
- A deliberately dirty peer (one real edit) still refuses to fast-forward; one with only an ignored
  directory does fast-forward. Both are scripted assertions, not manual checks.
- `ainish-coder --machine-sync --json` on this pair reports `"smoke":"ok"` for `windows-128gb`.
- `git log -1 --format='%an <%ae>'` after an `--auto-commit` cycle is not the operator's identity.
- `ainish-coder --machine-sync --help` names the ignored-binary limitation.

## 7. Open Decisions

- **Where do ignored binaries actually travel?** Options: install Syncthing on both machines (the
  root `llms.txt` already names it as intended), or add an explicit `--assets` fetch that rsyncs a
  named ignored subtree with a manifest hash check. Not decided here; recorded so it is not silently
  forgotten. The consumer repo already carries a working `restore_binaries.py` over SSH as a stopgap.
- **Should the watcher own more than sync?** The operator wants continuously running agents doing
  business work. That is a different daemon (a scheduler), and conflating it with the sync watcher
  would make both harder to debug. Out of scope; noted because the request implied it.
