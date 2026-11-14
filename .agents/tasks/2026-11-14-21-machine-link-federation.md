# Task: `--machine-link` — persistent repo links and hook-driven auto-sync

- lane: now
- branch: `feat/machine-link-federation`
- status: done (T9 preserved only; convergence left as an operator decision — see the plan §7)
- plan: `.agents/plans/2026-11-14-21-machine-link-federation.md`
- scope: `src/machine_sync.sh`, `src/machine_link.sh` (new), `bin/ainish-coder`, `src/help.sh`,
  `README.md`, `llms.txt`, `scripts/test-machine-sync.sh`
- objective: Make "link the Windows `<repo>` to this folder" a durable, one-time statement that then
  keeps both machines current on every commit, without a daemon and without re-typed peer paths.

## Why

`--machine-sync` transported refs but forgot intent: peer paths were guessed as
`<peer-root>/<repo-name>`, which is wrong whenever a repo sits under different trees on two machines
(verified: Windows' registry resolves the Mac copy to `/Users/nbiish/code/...`, while it lives at
a removable-volume code root on this Mac). Nothing fired on a commit, so cross-machine work still
depended on remembering a command.

## What changed

- **`src/machine_link.sh`** (new) — `--machine-link`: `links.txt` registry CRUD, plus a
  `post-commit`/`post-merge` hook that sends to linked peers. Send-only, `--linked-only`,
  env-guarded, idempotent, and removed whole by `--remove`.
- **`src/machine_sync.sh`** — fixed `_ms_remote` for local peers; guarded every peer probe so
  `set -e` cannot abort a run on a missing ref; added `--quiet`, `--all`, `--linked-only`; peer path
  now resolves `--peer-path` → link → guess, and reports which.
- **Docs** — `src/help.sh`, `README.md`, `llms.txt`; the `--ff-peers` help text now matches the
  shipped default (on) instead of claiming "off by default".
- **`scripts/test-machine-sync.sh`** — sections 10–14 for links, hooks, `--all`, `--quiet`, and the
  unsynced-peer forecast.

## Verification

- `bash scripts/test-machine-sync.sh` — **48 passed, 0 failed** (baseline 20 passed / 6 failed; the 6
  were pre-existing and all exited 255).
- `bash scripts/test-pqc-dist.sh` — **302 passed, 0 failed**.
- Live `windows-128gb`: `--dry-run` exits 0 with `path from link` and a real forecast (previously
  exit 1, truncated header); push delivered all Mac branches and the WIP snapshot, confirmed on the
  peer by `for-each-ref`.
- Hermetic proof that a commit propagates with no command: peer `main` advanced to the commit's SHA.

## Not done, and why

- **Converging `goal-first-trillion` onto `origin/main`.** The three copies share no ancestor, and
  this checkout holds 24 uncommitted paths. Both Mac tips are preserved (`preserve/mac-3c87fac`,
  `preserve/mac-dirty-tree`) and delivered to the peer; the merge itself rewrites a working branch,
  which is the operator's call.
- **Windows `machines.txt`.** It still points `mac-18gb` at `/Users/nbiish/code`. Fixing another
  machine's registry is an operator action; `--machine-link` there is the per-repo fix.
