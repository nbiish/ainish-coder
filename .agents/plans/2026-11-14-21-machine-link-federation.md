---
plan_format: ainish/plan/v1
slug: machine-link-federation
date: 2026-11-14
status: implementing
branch: feat/machine-link-federation
worktree: /Users/nbiish/code/machine-link-federation
task_record: .agents/tasks/2026-11-14-21-machine-link-federation.md
operator: question-me
---

# Plan: `--machine-link` — persistent repo-to-repo federation with hook-driven auto-sync

## 1. Problem

`--machine-sync` transports refs well, but it has no memory of intent and no trigger. There is no way
to say "link the Windows `goal-first-trillion` to this folder" and have it stay true, so the operator
re-types peer paths forever, and the receiving side guesses `<peer-root>/<repo-name>` — which is wrong
for any repo that does not share a directory name and a code root across machines. Nothing fires when
work is committed, so cross-machine work still requires remembering to run a command on each machine.
Three defects also block the first real run: a local-peer smoke check that kills the process, a
`--dry-run` that dies silently when a peer has no tracking ref, and docs that disagree with the
shipped `--ff-peers` default.

## 2. Anchor Facts

- `--machine-sync` exists and is pairwise over SSH — `src/machine_sync.sh` (944 lines), dispatched at
  `bin/ainish-coder:435`.
- `_ms_remote` (`src/machine_sync.sh:313`) runs `ssh ... "$1" "$2"` unconditionally, so an empty host
  for a **local** peer executes `ssh ""` and fails — established by `bash -x` on a local-peer sync
  exiting 255 inside `_ms_smoke_peer`.
- The smoke failure is pre-existing and already red: `bash scripts/test-machine-sync.sh` →
  **20 passed, 6 failed**, the 6 all exit 255 (`sync exits 0`, `second sync exits 0`, `--json did not
  parse`, `pull-only`, `push-only`, `unreachable peer exits 1`).
- `--dry-run` against the real repo exits **1 with a truncated header** — established by running it
  on `~/code-external/goal-first-trillion`. Cause: `bin/ainish-coder:5` sets `set -euo pipefail`, and
  `_ms_peer_forecast` (`:93`) assigns from a `rev-list` against `refs/remotes/mac-18gb/main`, absent
  on Windows.
- `_MS_FF_PEERS=true` (`src/machine_sync.sh:43`) while `src/help.sh:141` documents "Off by default" —
  established by reading both.
- Windows' registry maps `mac-18gb=mac-18gb:/Users/nbiish/code`, so it looks for
  `/Users/nbiish/code/goal-first-trillion`; that path does not exist. The Mac copy lives at
  a removable-volume code root on this Mac — established by `ls` on both sides.
- The three `goal-first-trillion` copies share **no history**: roots `026b902` (Mac), `207d89e`
  (Windows), `39005a8` (origin); `git merge-base HEAD origin/main` prints nothing. They share exactly
  3 paths (`.gitignore`, `AGENTS.md`, `README.md`), all differing in content.
- Origin is the newest: origin `1acba1c` (45 commits, 132 files), Windows `555b46e` (12 commits, 69
  files), Mac `3c87fac` (4 commits, 61 files) — established by `rev-list`/`ls-tree` on each side.
- `--rules-watch` watches the rules contract (`src/deploy_rules_sync.sh:988`), not repositories; the
  hook-block installer idiom to reuse is `_ainish_rules_install_hook_block` (`:258`).

## 3. Plan

### Goals

- One command records a repo↔repo link durably; later syncs use it without re-typing peer paths.
- A commit in a linked repo propagates to its peers with no operator action, and peers fast-forward so
  the next command on the other machine sees the new work.
- `--dry-run` predicts on any peer state, including one that has never synced.
- The machine-sync gate is green, and local peers are first-class.

### Non-goals

- No daemon, watcher, or launchd/systemd unit. Hooks only, per the operator's decision.
- No auto-resolution of content conflicts in the operator's repositories — conflicts are reported.
- No change to the ref namespace; `refs/remotes/*` and `refs/machine-sync/*` stay as shipped.
- No push to a Git remote; federation remains LAN-SSH only.

### Constraints and invariants

- Hooks must never leave a half-merged or moved tree. Hooks **send** only (`--push`); receiving stays
  an explicit `--pull`/`--both`. A peer is only fast-forwarded when it is on the same branch and clean.
- Hook blocks are idempotent and env-guarded (`AINISH_MACHINE_SYNC_ACTIVE`) so re-running rewrites in
  place and cannot recurse.
- Never write a secret. The links registry carries paths and peer names only.
- Fail closed: a peer that cannot be reached is a reported failure, never a silent success.

### Proposed architecture

```
~/.config/ainish-coder/links.txt      ← "repo | peer | peer path", append-friendly
        │
--machine-link ──► records ──► --machine-sync (consults links before <root>/<repo-name>)
        │
        └──► installs post-commit/post-merge block in the linked repo
                     │
                     └── AINISH_MACHINE_SYNC_ACTIVE=1 --machine-sync . --push --quiet
```

### Interfaces and data

- `--machine-link [DIR] --peer NAME [--peer-path PATH]` — record a link; default path is the machines
  registry root joined with the repo name.
- `--machine-link --list [--json]` — print links for this machine.
- `--machine-link --remove --peer NAME [DIR]` — drop a link and its hook block.
- `--machine-link --no-hooks` — record without arming hooks.
- `--machine-sync --all` — run every repo linked on this machine.
- `--machine-sync --quiet` — no output (hook path).
- `links.txt` format, one link per line: `<repo-abs> | <peer> | <peer-path>`; `#` comments ignored.

### Files and symbols

- `src/machine_sync.sh` — fix `_ms_remote` (local host), tolerate unknown peer refs in
  `_ms_peer_forecast`/`_ms_checkout_id`/`_ms_smoke_peer`; add `--quiet`, `--all`, and links lookup in
  the peer-path resolution; new `machine_link()`.
- `src/machine_link.sh` (new) — registry CRUD and hook install/remove, reusing the hook-block idiom.
- `bin/ainish-coder` — dispatch `--machine-link`.
- `src/help.sh`, `README.md`, `llms.txt` — document links, hooks, `--all`, and correct the
  `--ff-peers` default to match the shipped `true`.
- `scripts/test-machine-sync.sh` — new assertions for links, hooks, `--all`, quiet, and local peers.
- `~/.config/ainish-coder/machines.txt` (Windows + Mac) — correct the Mac code root to
  a removable-volume code root on this Mac.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Watch daemon for dirty trees | Operator chose hooks: no idle process, no service to keep alive. |
| Persist `--peer-path` in repo-local git config | Invisible outside one clone, and cannot support `--all` across repos. |
| Resolve peer paths by repo-name convention only | Already the bug: Windows and Mac keep this repo under different roots. |
| Auto-merge unrelated histories in the hook | Two lanes that meet must be a human decision; merging in a hook is unreviewable. |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Hook recursion across two machines | Env guard plus push-only; a receiving peer's push carries nothing new and terminates. |
| Hook blocks a commit when a peer is offline | `|| true` in the block, bounded `ConnectTimeout`, never fails the commit. |
| Adopting origin rewrites operator history | Preserve both local tips as `preserve/*` branches first; nothing is deleted. |
| Content conflicts on merge | Report and stop; no automatic resolution. |

## 4. Clarifications

### 4.1 Base history for `goal-first-trillion`

- **Question:** The three copies share no root commit; which becomes the base?
- **Options:** 1. (Recommended) origin/main — it is newest; 2. Windows — the original assumption;
  3. keep three permanent branches, merged by hand; 4. investigate further first.
- **Selected:** origin/main (`1acba1c`) is the base; graft each copy's unique work on top.
- **Trade-off accepted:** the Mac's and Windows' local histories get a preservation branch and a merge
  commit rather than staying linear.
- **asked:** operator
- **resolved by:** operator selection in this session.

### 4.2 Sync trigger

- **Question:** What should make a sync happen without a typed command?
- **Options:** 1. (Recommended) git post-commit/post-merge hooks; 2. a background watcher incl. WIP;
  3. both; 4. manual only.
- **Selected:** hooks.
- **Trade-off accepted:** uncommitted work is not auto-propagated — it needs a commit (or `--auto-commit`).
- **asked:** operator
- **resolved by:** operator selection in this session.

### 4.3 Link persistence

- **Question:** How is a link recorded so it survives restarts?
- **Options:** 1. (Recommended) `--machine-link` + `links.txt` registry and `--machine-sync --all`;
  2. per-repo git config via `--peer-path`; 3. extend `machines.txt`.
- **Selected:** a links registry driven by `--machine-link`, plus `--machine-sync --all`.
- **Trade-off accepted:** one more registry file to keep coherent with `machines.txt`.
- **asked:** operator
- **resolved by:** operator selection in this session.

### 4.4 `--ff-peers` default

- **Question:** Code says default-on, help says "off by default". Which is correct?
- **Options:** 1. (Recommended) keep default-on and correct the docs — it is what makes a link useful;
  2. make it default-off and correct the code.
- **Selected:** keep `true`; correct `src/help.sh` and `README.md`.
- **Trade-off accepted:** a peer's checked-out branch moves on sync unless `--no-ff-peers` is passed;
  safe because it requires the same branch and a clean tree.
- **asked:** resolved from code
- **resolved by:** `src/machine_sync.sh:43` versus `src/help.sh:141`, reconciled in favour of the
  shipped behaviour because moving the peer is the stated goal.

## 5. Todos

- [x] **T1** Make `_ms_remote` run locally on an empty host, so local peers stop executing `ssh ""`.
  - from: §2/§3 | done when: a local-peer sync exits 0 | verify: `bash scripts/test-machine-sync.sh`
- [x] **T2** Tolerate a missing peer tracking ref in `_ms_peer_forecast`, `_ms_checkout_id`,
  `_ms_smoke_peer`, so `--dry-run` cannot die under `set -e`.
  - from: §2 | done when: `--dry-run` on an unsynced peer exits 0 with a forecast
- [x] **T3** Add `--quiet` and `--all` to `machine_sync`.
  - from: §3 | done when: `--quiet` prints nothing and `--all` visits each linked repo
- [x] **T4** New `src/machine_link.sh` with `--machine-link` CRUD over `links.txt`.
  - from: §3 | done when: add/list/remove round-trip | verify: new gate assertions
- [x] **T5** Install removable, idempotent, env-guarded hook blocks in linked repos.
  - from: §3 | done when: re-running installs once and `--remove` cleans up
- [x] **T6** Make `--machine-sync` consult `links.txt` before `<root>/<repo-name>`.
  - from: §3 | done when: a linked peer path is used without `--peer-path`
- [x] **T7** Correct the `--ff-peers` documentation and document links/hooks/`--all`.
  - from: §4.4 | done when: `src/help.sh` and `README.md` match the code
- [x] **T8** Extend `scripts/test-machine-sync.sh` to cover T1–T6; baseline must go green.
  - from: §3 | done when: 0 failures | verify: `bash scripts/test-machine-sync.sh`
- [ ] **T9** Converge `goal-first-trillion`: preserve both local tips, adopt origin, report conflicts.
  - from: §4.1 | done when: both `preserve/*` branches exist and conflicts are reported, not resolved
  - status: **partly done** — `preserve/mac-3c87fac` and `preserve/mac-dirty-tree` exist and are pushed
    to the Windows peer; adopting `origin/main` as the base is deliberately left to the operator,
    because it rewrites the working branch of a repo holding 24 uncommitted files. See §7.

## 6. Verification

- `bash scripts/test-machine-sync.sh` — **48 passed, 0 failed** (baseline was 20 passed, 6 failed).
- `bash scripts/test-pqc-dist.sh` — **302 passed, 0 failed** (recorded baseline was 153 pass / 14 fail).
- `--dry-run` against the real `windows-128gb` peer — **exit 0**, `path from link`, forecast names the
  missing peer ref. This is the command that previously exited 1 with a truncated header.
- Live push to `windows-128gb` — exit 0; `refs/remotes/mac-18gb/{main,docs/hub-consolidation,...}` and
  `refs/machine-sync/mac-18gb/docs/hub-consolidation` verified present on the peer by `for-each-ref`.
- Hook propagation, hermetic: a commit in a linked repo advanced the peer's `main` to the same SHA
  with no command run (`scripts/test-machine-sync.sh` §11b).
- `--machine-sync --json` and `--machine-link --list --json` both parse.

## 7. Open Decisions

- **T9 completion.** Both Mac tips are preserved and delivered, but swapping the working branch onto
  `origin/main` is an operator call: the repo holds 24 uncommitted paths, and the three histories
  share no ancestor, so the graft is a manual merge, not a fast-forward. Recommended order: commit or
  discard the dirty tree on this machine, create `base/origin-1acba1c` from `origin/main`, then merge
  `preserve/mac-dirty-tree` and the Windows tip `555b46e` into it one at a time, resolving per file.
- **Windows-to-Mac direction still needs a registry fix.** Windows' `machines.txt` maps
  `mac-18gb=mac-18gb:/Users/nbiish/code`, which does not contain `goal-first-trillion` (it lives at
  a removable-volume code root on this Mac). `--machine-link` on the Windows side is the correct fix and
  is not applied here, because it edits another machine's configuration.
