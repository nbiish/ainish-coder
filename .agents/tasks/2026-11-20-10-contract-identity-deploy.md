2026-11-20-10-contract-identity-deploy
# Task: correct the contract's identity text, and deploy the identity hooks with `--rules`

- lane: now
- branch: `feat/contract-identity-deploy`
- status: implementing
- plan: `.agents/plans/2026-11-20-10-contract-identity-deploy.md`
- scope: `AGENTS.md`, `.agents/canonical/AGENTS.md`, `src/deploy_rules_sync.sh`,
  `bin/ainish-coder`, `scripts/test-pqc-dist.sh`
- objective: The contract should state the authorship rule, not the scripts that enforce it, and a repo
  deployed with `ainish-coder --rules` should strip harness attribution itself rather than depending on
  the machine that deployed it.

## Findings that shape the work

- **The operator's edit never landed.** Both contract files are `uchg` at 444, so the write was refused
  with `operation not permitted`; `AGENTS.md` is byte-identical to HEAD. Rule 4 still names
  `scripts/strip-harness-trailers.sh` and `commit-identity-guard.sh`.
- **`--rules` installs no identity hooks in a target.** Measured on a scratch git repo: it received
  `post-checkout`, `post-merge`, `pre-commit` and zero identity blocks. `install_root_rules_sync_hook`
  writes them to `${REPO_DIR}` — the source — and takes no target argument.
- **`bin/ainish-coder:313` calls `deploy_embed_provider_detect`**, deleted with `src/embed_config.sh`
  on 2026-11-19. Every `--rules` run prints `command not found` and continues.
- `.agents/bin/` is not gitignored, so a copied script is tracked in the target.

## Next action

T1: unlock, apply the operator's edit, re-sign, relock.
