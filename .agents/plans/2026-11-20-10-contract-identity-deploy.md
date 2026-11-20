---
plan_format: ainish/plan/v1
slug: contract-identity-deploy
date: 2026-11-20
status: ready
branch: feat/contract-identity-deploy
worktree: /Users/nbiish/code/contract-identity-deploy
task_record: .agents/tasks/2026-11-20-10-contract-identity-deploy.md
operator: direct-instruction
---

# Plan: correct the contract's identity text, and deploy the identity hooks with `--rules`

## 1. Problem

The operator edited the identity sentences out of `AGENTS.md` as redundant now that the hooks do that
work automatically — and the edit was silently refused, because both contract files are OS-locked
(444, `uchg`). So the contract still tells every agent to reason about scripts it no longer needs to
know, and the repository cannot tell an intentional edit from a lost one.

Separately, `--rules` deploys to a target repo installs NO identity hooks at all: trailer stripping and
author repair exist only where the source install lives. A deployed repo therefore ships harness
trailers with every generated commit, which is the exact problem the hooks were built to prevent.

## 2. Anchor Facts

- `AGENTS.md` and `.agents/canonical/AGENTS.md` are `uchg` at 444; `echo >> AGENTS.md` fails with
  `operation not permitted` — verified.
- `AGENTS.md` is byte-identical to HEAD (`d68fe0d`), so the operator's edit never landed.
- Rule 4 at `:55-60` names `scripts/strip-harness-trailers.sh` and `commit-identity-guard.sh`.
- `install_rules_sync_hook()` (`src/deploy_rules_sync.sh:520`) installs the identity blocks into
  `${REPO_DIR}/.git/hooks` — the SOURCE repo — and takes no target argument.
- `install_rules_sync_hooks target` (`:486`) is the target installer and contains only the
  rules-sync block, on `post-merge` and `post-checkout`.
- Measured: `ainish-coder --rules <scratch-git-repo>` produced `post-checkout`, `post-merge`,
  `pre-commit` and **zero** identity blocks.
- `bin/ainish-coder:313` calls `deploy_embed_provider_detect`, deleted with `src/embed_config.sh` on
  2026-11-19 — every `--rules` run prints `command not found`.
- `.agents/bin/` is not gitignored, so a copied script there is tracked in the target.

## 3. Plan

### Goals

- Rule 4 states the rule, not the implementation: no agent is told to reason about hook scripts.
- `--rules` into a git target installs trailer stripping and author repair that WORK there, from files
  the target owns.
- Re-running `--rules` refreshes those files, so a new harness entry reaches every target.
- The dangling `deploy_embed_provider_detect` call is gone.

### Non-goals

- Changing the hook behaviour itself; it works and is covered by 397 assertions.
- Unlocking the contract permanently. Editing needs the explicit unlock step, and the plan uses it.
- Deploying to non-git targets: hooks need a `.git` to be hooks. The current warning stays, and is
  made accurate.

### Constraints and invariants

- `AGENTS.md` stays at 160 lines; every non-negotiable survives.
- The contract is re-signed and re-locked after editing; the hash chain stays verifiable.
- A deployed hook must never point outside the target repo.
- Hook blocks stay idempotent, keyed on their own markers.

### Proposed architecture

```
ainish-coder --rules <target-git-repo>
  ├─ .agents/bin/ainish-rules-sync          (existing)
  ├─ .agents/bin/strip-harness-trailers.sh  (new: copied)
  ├─ .agents/bin/harness-attribution.txt    (new: copied)
  ├─ .agents/bin/commit-identity-guard.sh   (new: copied)
  └─ hooks/
       commit-msg    -> .agents/bin/strip-harness-trailers.sh "$1"
       post-commit   -> .agents/bin/commit-identity-guard.sh
```

### Interfaces and data

- `_ainish_rules_deploy_identity_scripts <target>` — copies the three files into
  `<target>/.agents/bin/`, modes 0755 / 0644, and sets `AINISH_HARNESS_TABLE` in the hook block so the
  table is found beside the script.
- `install_rules_sync_hooks <target>` — gains the two identity blocks, pointing at
  `.agents/bin/…` relative to the target.
- `strip-harness-trailers.sh` — default table path becomes "beside this script", which it already is;
  no change needed once the file sits next to the table.
- `bin/ainish-coder` — the `deploy_embed_provider_detect` block is removed entirely.

### Files and symbols

- `AGENTS.md` / `.agents/canonical/AGENTS.md` — rule 4 shortened; unlock, edit, re-sign, re-lock.
- `src/deploy_rules_sync.sh` — new copy helper; identity blocks in `install_rules_sync_hooks`.
- `bin/ainish-coder` — delete the embed-provider block at `:311-316`.
- `scripts/test-pqc-dist.sh` — assertions for the deployed hooks and the copied files.
- `.agents/audit/{contract-history.jsonl,contract-history.sig}` — re-signing receipts.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Point target hooks at the source install (current) | Breaks when the source moves or is a throwaway worktree; the target is not self-contained |
| Inline the patterns into the hook | Loses the data table, which is the thing that made adding a harness one line |
| Leave rule 4 naming the scripts | The operator's stated intent; the hooks are automatic, so naming them is noise in a contract read on every task |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Editing the locked contract corrupts the signature chain | Unlock → edit → re-sign → verify chain → relock, all in one step, with the chain checked |
| Copied scripts go stale in a target | `--rules` re-run refreshes them; the copy is unconditional, unlike the manifest |
| A target without `.git` gets half a deployment | Copy is skipped with an accurate message; hooks are never claimed as installed |
| Deleting the embed block breaks another caller | `grep -rn deploy_embed_provider_detect` must return only the definition site (none) |

## 4. Clarifications

### 4.1 What rule 4 should say

- **Question:** Rule 4 names two scripts. You called that redundant with the hooks doing the work. What stays?
- **Options:** 1. (Recommended) State the rule only; 2. name the stripper so an agent can find the table; 3. keep both.
- **Selected:** the operator's own edit — remove the sentences that name the scripts. The rule keeps the requirement and the `Nanoboozhoo - embodied by {agent harness}` form, which is what an agent must KNOW; how it is enforced is the tooling's business.
- **Trade-off accepted:** An agent cannot discover the table from the contract. Discovery goes through `.agents/llms.txt` and the repo tree, which is where every other tool's location lives.

### 4.2 How a deployed repo gets the hooks

- **Question:** `--rules` installs no identity hooks into a target today. How should it?
- **Options:** 1. (Recommended) Copy the scripts into the target's `.agents/bin/`; 2. reference the source install; 3. inline the patterns.
- **Selected:** 1 — copy.
- **Trade-off accepted:** Three more files per target, refreshed on every `--rules` run. In exchange the target works with no reference to the machine that deployed it.

## 5. Todos

- [ ] **T1** Unlock the contract, apply the operator's rule-4 edit, re-sign, verify the chain, relock.
  - from: §4.1 | done when: rule 4 states the rule only and `audit contract --verify-history` passes | verify: that command
- [ ] **T2** Delete the dangling `deploy_embed_provider_detect` call.
  - from: §3 | done when: `--rules` prints no `command not found` | verify: a scratch deploy's log
- [ ] **T3** Copy the three identity files into the target's `.agents/bin/`.
  - from: §4.2 | done when: a scratch target has all three, executable where needed | verify: `ls -la <target>/.agents/bin`
- [ ] **T4** Install `commit-msg` and `post-commit` blocks in the target, pointing at `.agents/bin/`.
  - from: §4.2 | done when: a commit in the target has its trailer stripped without the source repo present | verify: a commit in the scratch target
- [ ] **T5** Add the deployed-hook assertions to the suite.
  - from: §5 | done when: the suite proves target-side stripping, not just source-side | verify: `scripts/test-pqc-dist.sh`

## 6. Verification

- `scripts/test-pqc-dist.sh` — passes at or above 397 assertions.
- `wc -l < AGENTS.md` — 160.
- `ainish-rag audit contract --verify-history` — chain verifies after the re-sign.
- A scratch git repo deployed with `--rules`, then committed into with a Cursor trailer, arrives clean.
- `ainish-coder --rules` on a scratch repo prints no `command not found`.

## 7. Open Decisions

- Whether a target should also receive a copy of the SUGGESTIONS/COMMS templates the identity hooks
  write to — settled if a deployed repo's guard tries to log and finds no `.agents/comms/`.
- Whether the copied scripts should carry a version stamp so a stale target is detectable — settled by
  whether a target is ever found running an older table.
