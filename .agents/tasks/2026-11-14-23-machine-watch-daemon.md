# Task: `--machine-link --watch` — background watcher keeps federated repos current

- lane: now
- branch: `feat/machine-watch-daemon`
- status: implementing
- plan: `.agents/plans/2026-11-14-23-machine-watch-daemon.md`
- scope: `src/machine_watch.sh` (new), `src/machine_link.sh`, `bin/ainish-coder`, `src/help.sh`,
  `README.md`, `llms.txt`, `scripts/test-machine-watch.sh` (new)
- objective: Run the link command once; from then on a saved file reaches the other machines with no
  command, no commit, and no thought.

## Why

Hooks fire on commit. A save is not a commit, so the operator's actual workflow — edit, save, switch
machines — had no transport. The ask is save-level sync across the repos they designated.

## Shape

A per-user daemon (launchd on macOS, systemd on Linux) runs a poll loop: detect a change in a linked
repo, debounce to quiescence, then run the **already-proven** `--machine-sync --both --branches
--auto-commit --linked-only --quiet` path. Nothing new moves bytes; the watcher only decides *when*.

## Honest limits, stated up front

- No `fswatch`/`inotifywait` on this host, so "instant" is a ~2s poll plus debounce, not a kernel
  file event.
- A peer with a dirty tree is **never** overwritten; its state is reported and the operator decides.
- Divergence is reported, never auto-merged.
