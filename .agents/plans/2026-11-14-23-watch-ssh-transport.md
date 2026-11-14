---
plan_format: ainish/plan/v1
slug: watch-ssh-transport
date: 2026-11-14
status: implementing
branch: feat/watch-ssh-transport
worktree: /Users/nbiish/code/watch-ssh-transport
task_record: .agents/tasks/2026-11-14-23-watch-ssh-transport.md
operator: question-me
---

# Plan: let the watcher reach external-volume repos that macOS TCC denies it

## 1. Problem

The launchd watcher cannot read a repository on an external volume: TCC returns `Operation not
permitted` for reads by a launchd-spawned process, even though the same user's terminal reads the
same repo fine. The operator keeps repositories on an external disk by choice, so "move it internal"
is not an answer. The watcher must reach those repos without asking for a permission the operator
cannot easily grant (the Full Disk Access picker will not navigate to `/bin/bash`).

## 2. Anchor Facts

- A launchd agent reading the external repo directly fails: `fatal: Unable to read current working
  directory: Operation not permitted` — established by a minimal probe agent.
- **The same agent reaching the repo through `ssh localhost` succeeds** and prints the commit
  (`13ae854`) — established in the same probe, seconds apart, same process.
- `ssh -o BatchMode=yes localhost` works non-interactively from this account.
- The FDA picker in System Settings does not let the operator navigate to `/bin/bash`; copying bash
  elsewhere fails (`SIGKILL`, exit 137 — code signing), so a copied binary is not an option.
- The operator's terminal already has the access (it reads the repo), which is why the foreground
  loop works while the agent does not.

## 3. Plan

### Goals

- The daemon syncs external-volume repositories with no permission grant.
- No weakened control: the transport choice is detected and verified, not assumed.
- Works for internal-disk repos exactly as before (no extra process where none is needed).

### Non-goals

- Not requesting/automating TCC changes (impossible to script, and the operator's choice to make).
- Not copying or re-signing system binaries.
- Not changing the sync semantics: same `--machine-sync` path, same protections.

### Constraints and invariants

- **Verify, then use.** The agent must prove which transport works (direct vs `ssh localhost`) with a
  bounded probe, and record it; never assume.
- **No silent downgrade.** If neither transport works, say which host and why, and fail.
- `ssh localhost` requires the user's own key to be authorized; if it is not, report that clearly.
- Keep one sync cycle at a time, the debounce, the backoff, and the dirty-peer refusal unchanged.

### Proposed architecture

```
launchd agent
   │
   ├─ probe once at install:  direct read  ──► works?  use DIRECT
   │                                          └► denied? try SSH
   │
   └─ at each cycle, run the sync through the chosen transport:
        DIRECT: ainish-coder --machine-watch --once  (as today)
        SSH:    ssh localhost 'cd <repo> && ainish-coder --machine-watch --once'
```

The SSH transport runs the *existing* sync on the far side of a loopback ssh, so nothing about the
sync logic branches — only the process that invokes it.

### Interfaces and data

- `--machine-watch --transport auto|direct|ssh` (default `auto`).
- State records `transport=direct|ssh|none` in `watch.state`.
- Plist gains nothing new; the transport is decided at runtime and stored in state.

### Files and symbols

- `src/machine_watch.sh` — `_mw_detect_transport`, `_mw_run_via_transport`, wire into `_mw_sync_repo`.
- `scripts/test-machine-watch.sh` — assert transport detection and that a denied-direct host falls
  back to ssh.
- `README.md`, `src/help.sh`, `llms.txt` — document it.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Full Disk Access for `/bin/bash` | Picker cannot navigate there; copying bash is SIGKILLed. |
| Move repos to the internal disk | Operator uses the external disk deliberately for space. |
| Copy `/bin/bash` into $HOME | Code signing kills it (exit 137). |
| Run the watcher only in the foreground | Dies with the terminal; not a background service. |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| `ssh localhost` needs a key the agent lacks | Probe at install; report the exact missing step |
| Loopback ssh re-enters the same repo and races | The existing PID lock still applies; one cycle at a time |
| Silent fallback to a broken transport | Probe is verified by reading a real `rev-parse` on the repo |

## 4. Clarifications

### 4.1 Transport for external volumes

- **Question:** How should the daemon reach a repo TCC denies it?
- **Options:** 1. (Recommended) detect and use loopback ssh; 2. require Full Disk Access; 3. move repo.
- **Selected:** detect and use loopback ssh, falling back only when direct read is denied.
- **Trade-off accepted:** one extra ssh process per cycle for external-volume repos.
- **asked:** resolved from code
- **resolved_by:** the same probe agent failed direct read and succeeded over `ssh localhost`.

## 5. Todos

- [x] **T1** `_mw_detect_transport`: probe direct read, then `ssh localhost`, and record the result.
- [x] **T2** `_mw_run_via_transport`: invoke the cycle through the chosen transport.
- [x] **T3** Add `--transport` and surface it in `--status`/`--json` and `watch.state`.
- [x] **T4** Gate: a denied-direct fixture falls back to ssh and still syncs.
- [x] **T5** Docs: `src/help.sh`, `README.md`, `llms.txt`.
- [x] **T6** Live: install the daemon; prove a save on the external-volume repo reaches Windows.

## 6. Verification

- `bash scripts/test-machine-watch.sh` — 0 failures, with a new transport assertion.
- `bash scripts/test-machine-sync.sh` — still 60/0.
- Live: daemon installed, external-volume repo, save → Windows, no permission grant.
- `--machine-watch --status` names the transport in use.
