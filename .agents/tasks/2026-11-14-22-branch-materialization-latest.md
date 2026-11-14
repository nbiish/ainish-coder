# Task: materialise every branch on every machine, and report which copy is newest

- lane: now
- branch: `feat/branch-materialization-latest`
- status: implementing
- plan: `.agents/plans/2026-11-14-22-branch-materialization-latest.md`
- scope: `src/machine_sync.sh`, `src/machine_link.sh`, `src/help.sh`, `README.md`, `llms.txt`,
  `scripts/test-machine-sync.sh`
- objective: After a sync, every branch exists as a local branch on both machines and one command says
  which machine holds the newest commit per branch.

## Why

`--machine-sync` delivered branches as `refs/remotes/<machine>/*`, which is not a branch you can check
out. Verified: the Mac held 6 local branches while Windows held only `main`. So "sync all branches"
was true only in a sense nobody can work from. And nothing answered "which copy is newest" — `--status`
is documented as no-network, so the question that decides where to work was the one not answered.

## Constraint that shapes the design

Mac `main` (`e4f845d`) and Windows `main` (`555b46e`) have **no common ancestor**. Branch
materialisation must therefore be strictly additive: create a branch only when the name is absent, and
when it exists but differs, refuse and report both tips. Overwriting would destroy one machine's history
to make a report look clean. The base-history merge stays the operator's decision.

Windows also runs `ainish-coder` at `1bd8865`, which predates `--machine-link`, so peer-side mutation
must be plain `git -C … branch …` over ssh and never the peer's CLI.
