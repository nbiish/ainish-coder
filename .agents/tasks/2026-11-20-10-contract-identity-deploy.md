2026-11-20-10-contract-identity-deploy
# Task: correct the contract's identity text, and deploy the identity hooks with `--rules`

- lane: now
- branch: `feat/contract-identity-deploy`
- status: done (407 assertions pass; merged)
- plan: `.agents/plans/2026-11-20-10-contract-identity-deploy.md`
- scope: `AGENTS.md`, `.agents/canonical/AGENTS.md`, `src/deploy_rules_sync.sh`,
  `bin/ainish-coder`, `scripts/test-pqc-dist.sh`
- objective: The contract states the authorship rule, not the scripts that enforce it; a repo deployed
  with `ainish-coder --rules` strips harness attribution itself rather than depending on the machine
  that deployed it.

## What changed

| Was | Now |
|---|---|
| Rule 4 named `strip-harness-trailers.sh` and `commit-identity-guard.sh` | states the rule and the `Nanoboozhoo - embodied by {agent harness}` form; enforcement is the tooling's business |
| `--rules` installed **no** identity hooks into a target | copies the table, stripper and guard into `<target>/.agents/bin/` and installs `commit-msg` + `post-commit` blocks calling them |
| target hooks would have pointed at the installing checkout | relative `.agents/bin/…` paths; verified no absolute path to the source appears in a target's hooks |
| `bin/ainish-coder` called `deploy_embed_provider_detect`, deleted 2026-11-19 | call removed; `--rules` no longer prints `command not found` |
| an assertion pinned the contract to a script filename | asserts the rule is present AND no enforcement script is named |

## Bugs found

1. **The operator's edit had been silently refused.** Both contract files are `uchg` at 444, so the
   write failed with `operation not permitted` and the file stayed byte-identical to HEAD.
2. **`--rules` deployed no identity hooks at all.** `install_root_rules_sync_hook` writes to
   `${REPO_DIR}` — the source — and takes no target argument. Every deployed repo shipped harness
   trailers on every generated commit.
3. **A dangling call to a module deleted last session** made every `--rules` run print
   `command not found`.

## Verification

- `scripts/test-pqc-dist.sh` — **407 assertions pass** (397 baseline, 10 new), including a behavioural
  test that commits into a deployed scratch repo and asserts its trailer was stripped.
- `wc -l < AGENTS.md` — 160; every non-negotiable greps present.
- `ainish-context audit contract --verify-history` — 66 transitions verified after re-signing.
- Contract re-locked: a write attempt fails with `operation not permitted`.
- A deployed target's hooks contain no reference to the installing checkout.

## Deliberate deviation

Rule 4 no longer names where the tooling lives, which means an agent cannot discover the harness table
from the contract alone. That is the trade the operator asked for — the contract is read on every task
and script paths are implementation detail. Discovery belongs in `.agents/llms.txt` if it is ever
needed.
