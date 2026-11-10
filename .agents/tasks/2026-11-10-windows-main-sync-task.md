# Task: converge the macOS rules checkout with the Windows checkout

- lane: now
- branch: `chore/machine-sync-20261110` (this checkout, `/Users/nbiish/code/ainish-coder`)
- status: done
- scope: `.agents/tasks/2026-11-10-windows-main-sync-task.md`, `.agents/comms/2026-11-10-team.txt`
- objective: Make both machines carry the same rules revision, so a target repo pulls one truth regardless of which machine the operator is working from.

## Why

The rules source is the distribution point for every other repo on both machines. When the two
checkouts sit on different commits, agents on each machine answer the same question from a different
contract, and a `--rules` deploy from either side stamps a different `source_commit` into every
target's manifest. Windows was one commit ahead of macOS and origin; that commit carries two
distribution defects (nested `__pycache__` shipped to targets, and a manifest that understated what
it deploys), so the macOS copy was distributing a knowingly wrong manifest.

## What changed

- **macOS `main` fast-forwarded** `d045363..c5bf68e` — the Windows commit *fix(rules): stop shipping
  bytecode caches, and make the manifest describe reality*. It touches `src/file_operations.sh`,
  `src/deploy_rules_sync.sh`, `scripts/test-pqc-dist.sh`, and the 2026-11-08 ledger.
- **`origin/main` pushed** to the same commit, so the Windows checkout needs no pull to be current.
- **This record and the 2026-11-10 ledger** — the durable trace of the sync.

## How the transfer was done

The Windows checkout's `origin` is HTTPS and the macOS checkout's is SSH; both reach the same GitHub
repo, and the delta was exactly one commit. So the byte transfer was `git bundle` over the existing
SSH link (`windows:` alias, Git for Windows real paths only — no junction, per the transport
contract), then `git fetch <bundle>`, then `git merge --ff-only`. No `rsync`: a tracked tree has
deletions and renames that a file-copy cannot express, and copying the working directories would
have carried `bin\ainish-rag.exe` (124 MB, Windows-only), `bin/cmd-tracker.exe`, the literal `~`
junk directory at `D:\Code\ainish-coder\~`, and each machine's `.agents/rag` index and signing key.

## Verification

- Three surfaces agree: macOS `git rev-parse HEAD`, `git ls-remote origin refs/heads/main`, and the
  Windows checkout's `HEAD` are all `c5bf68e`; `git status` clean on both; 389 tracked files on both.
- `bash -n` on `src/file_operations.sh`, `src/deploy_rules_sync.sh`, `scripts/test-pqc-dist.sh` — clean.
- `bash scripts/test-pqc-dist.sh` — **153 assertions pass, 14 fail**. A detached worktree at
  `d045363` (the pre-sync commit) runs the same gate to **150 pass, 14 fail** with the identical 14,
  so the synced commit adds 3 assertions and introduces no regression. The 14 are the PQC-install /
  PQC-status environment failures that `uv run` cannot satisfy on this host either (the Windows lane
  measured the same 14 on WSL) — pre-existing, not caused by this sync.

## Left alone, deliberately

- **Uncommitted lane on Windows** — `D:\Code\ainish-coder-context-prime`
  (`feat/agents-context-prime`, base `663da33`) holds 13 modified files (+4184/−2361) under
  `src/rag` plus 8 untracked `scripts/test-*.sh` / build helpers, a plan, and a task record. It is
  the *only* copy of the Rust `PY_ONLY_SUBCOMMANDS` redirect, which is what makes the mandatory
  `ainish-rag --context` work on Windows. Uncommitted work has no transport; it needs a commit on
  its branch before it can cross machines. Recorded in the 2026-11-10 ledger, not touched here.
- **`bin\ainish-rag.exe` is stale** (PATH resolves `.exe` before `.cmd`), so `ainish-rag --context`
  exits 2 on Windows while macOS works through the bash launcher. Machine-local build output; fixed
  by a rebuild from the source that carries the redirect, or by removing the stale `.exe` so the
  `.cmd` launcher wins. Not a repo change.
- **`D:\Code\ainish-coder\~`** — an empty directory tree created by an unexpanded `~` during an
  earlier copy. Zero files; safe to delete with a literal path. Left for the operator to confirm.
- **`scripts/test-pqc-dist.sh` cleanup leaks on macOS** — the gate sets `uchg` on a fixture
  `AGENTS.md` and its `trap cleanup` cannot remove it, so every macOS run leaves an immutable
  `pqc-dist-test.*` directory in `TMPDIR`. Cleared by `chflags -R nouchg` before `rm -rf`; worth
  fixing in the trap, but that is a code change outside this sync.
