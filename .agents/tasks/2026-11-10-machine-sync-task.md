# Task: `--machine-sync` — federate a repository across capacity-named machines

- lane: now
- branch: `feat/machine-sync`
- status: done
- scope: `src/machine_sync.sh`, `bin/ainish-coder`, `src/help.sh`, `README.md`, `llms.txt`, `scripts/test-machine-sync.sh`, `~/.ssh/config`, `~/.config/ainish-coder/machines.txt`
- objective: Give the operator one command that moves a repository between their machines directly, so work is not ferried through a Git remote and uncommitted work stops living on one machine.

## Why

The operator rotates between a 18 GiB Mac and a 128 GiB Windows box, alone and with agents. Git's
answer to that is a remote: commit, push, switch, pull. It costs three round trips through a third
party for traffic that never leaves the LAN, and it cannot carry the most perishable state — a dirty
tree. Uncommitted work is where an agent's half-finished reasoning lives, and it had no transport at
all; the `feat/agents-context-prime` lane was found sitting only on the Windows disk for that reason.

## What changed

- **`src/machine_sync.sh`** (new, 600 lines) — `machine_sync()`, wired into `bin/ainish-coder` as
  `--machine-sync [DIR]`. Reads peers from `~/.config/ainish-coder/machines.txt`; transport is the
  existing SSH alias (`host:/abs/root`, `host:D:/root`) or a local path. Sends every branch as
  `refs/remotes/<machine>/*`, and snapshots the sender's working tree into a commit on
  `refs/machine-sync/<machine>/<branch>` using a throwaway `GIT_INDEX_FILE`, so HEAD, the index, and
  the working tree are untouched. The pull direction snapshots the *peer* with plain git plumbing
  (`rev-parse --git-path index`, `add -A`, `write-tree`, `commit-tree`, `update-ref`) so it works
  against a machine that has not yet synced this CLI. `--push` / `--pull` / `--both`, `--status`,
  `--dry-run`, `--json`, `--min-ram`, `--kind`, `--as`, `--peer-path`, `--machine`.
- **`scripts/test-machine-sync.sh`** (new) — 23 hermetic assertions across two local checkouts.
- **Docs** — `src/help.sh` (flag + examples), `README.md` (federation section with the registry format
  and the refs table), `llms.txt` (the PRD paragraph).
- **Machine identity** — `~/.ssh/config` and the Windows mirror now carry capacity names
  (`mac-18gb`, `windows-128gb`, `wsl-94gb`) alongside the legacy aliases, with the
  `<kind>[-<accelerator>]-<ram>gb` convention written down in both files. Registry:
  `mac-18gb=self`, `windows-128gb=windows-128gb:D:/Code`, `wsl-94gb=wsl-94gb:/mnt/d/Code`.

## Verification

- `bash scripts/test-machine-sync.sh` — **23/23**. Covers: branches cross both directions; the
  snapshot carries an untracked file and a tracked edit; ignored `debug.log` and `tool.exe` never
  cross; the peer's HEAD, branch name, and `git status` are byte-identical before and after; a second
  run is idempotent; `--min-ram 32` selects the 64 GB peer and skips the 8 GB one; `--status` works
  offline; `--json` parses and carries `ram_gb`; push-only and pull-only both exit 0; a missing peer
  repository exits 1.
- **Live, mac-18gb ↔ windows-128gb over SSH** — exit 0; 4 branches and the WIP snapshot
  (`refs/machine-sync/mac-18gb/main`) landed on Windows; 4 Windows branches arrived here. Confirmed
  from the Windows side with `git show-ref | Select-String machine-sync`.
- `bash scripts/test-pqc-dist.sh` — 153 pass / same 14 pre-existing PQC-environment failures
  (unchanged from the pre-change baseline).
- `ainish-rag --context` — embeddings and both advisory models route through local-router
  (`127.0.0.1:11434`); `ainish-rag index` built 1197 chunks and wrote an audit receipt.

## Not done, and why

- **Vector retrieval on macOS still degrades** (`mode: vector_driver_unavailable`): the Python engine
  has no `lancedb` package and macOS has no compiled binary, so the store is a no-op. The engine fails
  closed and says exactly that. The fix is either `lancedb` in the engine environment or a macOS build
  of `src/rag`; both are decisions worth taking deliberately rather than folding into a sync change.
- **Windows `bin\ainish-rag.exe` is stale** (`ainish-rag --context` exits 2 there; PATH resolves
  `.exe` before `.cmd`). A rebuild from `main` would not help — the `PY_ONLY_SUBCOMMANDS` redirect
  lives on `feat/agents-context-prime`, which is now preserved on origin.
- **wtf device names** still read `windows` / `wsl`; renaming them means re-issuing device keys, and
  the registry already maps capacity names onto those hosts.
- **`D:\Code\ainish-coder\~`** — empty stray tree from an unexpanded `~`; delete with a literal path.

## Cleanup

`~/.ssh/config.bak-20261110` and `C:\Users\kenwa\.ssh\config.bak-20261110` hold the pre-rename
copies. The hermetic gate leaves no state; the earlier `pqc-dist-test.*` directories were removed with
`chflags -R nouchg` first (the gate's own trap cannot clear the `uchg` fixture it sets).
