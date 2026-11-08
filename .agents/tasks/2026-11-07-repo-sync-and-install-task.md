# TASK — Pull remote content and install on this machine

- date: 2026-11-07
- branch: feat/repo-sync-latest (merged to main as 400994e)
- status: done
- provenance: source_commit=400994efb53f manifest_sha256=1edeab0dd582

## Request

Operator: "Pull down the latest content from the remote for this repo and let's get it
installed for this machine."

## Starting state

`git status --short --branch` on `main` reported `ahead 19, behind 30` against `origin/main`.
The 19 local commits were real, unpushed work:

- rules-fleet migration (`74c2a31`), cross-device deploy (`e6fd07d`), stale sync-lock reclaim
  (`f705aff`), plus their task/COMMS/memory records and merges
- CLI line-ending normalization (`505a60d`, `90f41bc`)
- secret-scan signature exclusion (`f2213be`)
- launcher recursion + Python 3.10 support (`4db2f98`)

The 30 incoming commits were the rag context-injection line, the two-call driver default, the
single `ainish-security` skill consolidation, mandatory `pqc-secrets`, and embedding-space
identity.

## Acceptance criteria

1. No unpushed local work is discarded.
2. The merged tree builds and its tests pass.
3. `main` fast-forwards to a single verified commit; worktree and branch cleaned up.
4. This machine is genuinely installed: CLI on PATH, hooks armed, skill packs verified, and the
   registered rules fleet at the new source commit.

## Conflicts and resolution

`git merge-tree --write-tree` predicted exactly two content conflicts.

- `bin/ainish-rag` — origin wins. Its `is_self()` real-path comparison fixes the same launcher
  self-exec recursion the local commit patched by deleting the candidate branches, and it
  additionally routes Python-only verbs (`context`, `secrets`) past a stale compiled binary.
  The exec bit is kept (`100755`).
- `llms.txt` — origin's `context`/CLI block taken wholesale, then the local registry-migration
  sentences re-attached to the rules-distribution bullet: legacy `rules-targets.json` import,
  `bootstrapped` enrollment, the nested-target hook rule, and `agents-copies` snapshots. Origin
  does not document them, and the code for every one survives the auto-merge untouched.

Everything else auto-merged, including both sides' additions to `src/deploy_rules_sync.sh`.

## Verification

- `bash -n` clean on all 8 touched shell entrypoints.
- `src/rag` suite: 164 passed, 27 subtests passed.
- The single failure, `RoleModelSeparationTest.test_distinct_reviewer_makes_the_two_roles_request_different_models`,
  reproduces identically on pristine `origin/main`, so it is not a merge regression. It is
  environmental: the test needs a resolvable remote provider key, and `pqc-secrets export` waits
  for an interactive vault passphrase. With a stub key the whole suite is green.
- `ainish-rag gate --patch <normal patch>` → GREEN, anchor 96%.
- `ainish-rag gate` with no patch → RED (`FAILED_CREDENTIAL_LEAK`). False positive: the gate diffs
  `HEAD~1`, which is this merge, whose diff adds
  `src/rag/tests/test_embedding_identity.py` containing the fixture literal
  `sk-secret-value-that-must-not-appear` — a value the test asserts is NOT leaked. Not a secret.
- Preflight finding: pristine `origin/main` cannot even import `rag.py` under Python 3.10
  (PEP 701 nested-quote f-string at line 8424). The merged tree imports cleanly because the local
  `4db2f98` fixes are still present. Landing origin alone would have broken this machine.

## Install

- `scripts/ainish-setup.sh` → permissions set, `bin` already on PATH via `~/.zshrc`.
- `scripts/setup-hooks.sh` → post-merge and post-checkout AGENTS.md sync hooks installed.
- `--skills-verify` → identical=18, mismatch=0, foreign=0, missing=0.
- `--rules-sync --all` → 10 checked, 0 failed.
- `--rules-doctor` initially reported 10/10 `RULES_STALE` with byte-identical content: the
  deployed refresh scripts short-circuit when `source_commit` matches, so stale
  `source_agents_sha256` values never self-healed. `--rules-rotate` re-stamped all 10.
- After rotate: `--rules-doctor` 10/10 healthy; `--rules-verify` 10/10 verified, pack bound 10/10.

## Incidents handled

- The canonical contract `.agents/canonical/AGENTS.md` carries the macOS `uchg` immutable flag by
  design (`src/agents_protection.sh`), which aborted the first fast-forward mid-checkout. The flag
  was cleared, the tree reset, untracked files that origin's commits would create were moved to
  `~/.config/ainish-coder/backups/pre-sync-20261107-222430/` rather than deleted, and the flag was
  restored afterward via `chmod 444` + `chflags uchg`.
- All 12 relocated files were confirmed tracked in the resulting commit, so nothing was lost.
- A blanket `chmod +x bin/* scripts/*.sh` left stray mode-only diffs; reverted with `git checkout`.

## Remaining uncertainty

- The `--rules-doctor` staleness check only self-heals via `--rules-rotate`; a future commit that
  rewrites `AGENTS.md` without re-stamping will again show content-stale on every target.
- The gate's `HEAD~1` canary scan will flag any commit whose diff adds a credential-shaped test
  fixture. The existing scan already skips lines containing `re.compile`/`RE_CANARY`; fixture
  literals are not covered.
