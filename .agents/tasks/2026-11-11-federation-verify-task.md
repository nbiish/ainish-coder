# Federation: predict the outcome, prove the peer is usable

- **status:** done
- **branch:** `feat/federation-verify`
- **plan:** `.agents/plans/2026-11-11-federation-verify.plan.md`
- **scope:** `src/machine_sync.sh`, `scripts/test-pqc-dist.sh`
- **objective:** make `--machine-sync` able to say whether a peer will be usable after it syncs, and
  prove it can execute what it received.

## What was found

1. **Transport was fine; usability was not.** `refs/remotes/mac-18gb/main` reached the peer correctly,
   but the peer's `main` stayed `e2f5cc7` behind our `7f4f725` for days. Verified by comparing
   `git rev-parse --short HEAD` on the peer with the ref it had received.
2. **One stray file blocked the whole fleet.** Both peers were blocked by a half-staged
   `fallback-models.json.bak.*` (`AD` in `git status`). Clearing it let both fast-forward immediately.
3. **`--dry-run` could not predict anything.** It printed `would sync both with <path>` and nothing
   else — no commit delta, no blocking paths, so a dry run could not have warned about #2.
4. **The Windows peers' login shell is PowerShell.** Any remote command using `&&`, `>/dev/null`, or
   `2>/dev/null` fails with a PowerShell parse error. The existing snapshot plumbing already documents
   this (`_ms_snap_cmd` uses `git -C`), but it is easy to reintroduce — and I did reintroduce it while
   writing the forecast, which is what the new gate now prevents.
5. **`windows-128gb` and `wsl-94gb` are the same checkout.** `D:/Code/ainish-coder` and
   `/mnt/d/Code/ainish-coder` are one NTFS tree, so the registry described one machine as two and every
   sync transferred to it twice.

## What changed

- `_ms_peer_forecast`: per peer, reports commits ahead/behind and whether the checkout would
  fast-forward — naming the exact blocking paths when it would not.
- `_ms_smoke_peer`: after a peer syncs, runs a bounded read-only probe (`--version`,
  `--rules-status --json`) and reports the verdict per machine. It never fails the sync: an
  unverifiable peer reads as "unverified", not as broken delivery.
- `_ms_checkout_id`: normalizes `/mnt/<d>/...` and `<D>:/...` to one identity so the same tree is
  detected and synced once, while still being listed under both names.
- All new remote commands use `git -C` rather than `cd && ...`, matching the existing constraint.

## Verification

- `bash scripts/test-pqc-dist.sh` → **217/217**, including nine new federation assertions.
- Live: a dry run against the real repo prints `0 ahead / 0 behind`, `peer tree is clean — the
  checkout would fast-forward`, and `wsl-94gb — same checkout as windows-128gb (d:/Code/ainish-coder);
  syncing once`.
- The POSIX-shell gate was proven to fail by reintroducing a `cd &&` remote command (got 1, want 0),
  then restored.
- The peer was advanced from `e2f5cc7` to `7f4f725` (12 commits) and its tree is clean.

## Two cross-architecture bugs found while verifying

1. **The Windows peer's login shell is PowerShell.** `&&`, `>/dev/null`, and `2>/dev/null` are syntax
   errors there, so any remote command using them fails silently. The snapshot plumbing already
   documented this constraint (`_ms_snap_cmd` uses `git -C`); a gate now rejects `cd '$path' 2>/dev/null &&`.
2. **`bin/ainish-coder` is a bash script**, so probing it on Windows fails and reports a healthy peer as
   unverified. The smoke probe selects the `.cmd` wrapper for drive-letter roots and takes the
   plan-check status from ssh's exit code rather than a remote redirect.

## Not done

- `--status` still reports the Windows entry's stale `main` while the tree's real HEAD has advanced,
  because both registry names are read as independent peers. The dedupe applies to the sync path;
  extending it to `--status` output is a follow-up.
- No per-architecture build verification (`cargo check` on each peer). The smoke probe proves the tool
  runs, not that a native build succeeds on that architecture.
- The anchor-rotation work from `fix/rules-sync-signing` (`ca10cd9`) remains parked and unmerged.
