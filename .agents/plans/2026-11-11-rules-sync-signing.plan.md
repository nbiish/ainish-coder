---
plan_format: ainish/plan/v1
slug: rules-sync-signing
date: 2026-11-11
status: done
branch: fix/rules-sync-signing
worktree: /Users/nbiish/code/rules-sync-signing
task_record: .agents/tasks/2026-11-11-rules-sync-signing-task.md
operator: question-me
---

# Plan: Make `--rules` deploy and self-refresh on any machine, including non-git targets

## 1. Problem

`ainish-coder --rules ~` refuses to finish: the deployment manifest cannot be signed or verified,
so the auto-sync layer never arms for the home directory. Rules also cannot stay current on a
machine whose targets are not git repositories, because the refresher is installed as git hooks.

## 2. Anchor Facts

Four independent faults, each measured:

1. **The local signing key is not the committed trust anchor.** Signing a fresh file yields
   fingerprint `69e7233dc777…`; `.agents/audit/signer.mldsa65.pub` says `d98405ea3684…` — established
   by signing a temp file and comparing `public_key_fingerprint` to the anchor JSON. The cause:
   `resolve_or_create_seed` (`src/rag/src/pqc.rs:68`) reads a seed from `AINISHRAG_MLDSA65_SEED` or the
   PQC vault, and **otherwise generates a random one and writes `.agents/audit/signer.mldsa65.priv`**.
   That key is gitignored, so every machine silently invents its own identity while the anchor stays
   committed. No seed key exists in the vault (`pqc-secrets list` shows only scroll seeds), so the
   original seed is unrecoverable.
2. **The deploy gate verifies the whole `.agents/` directory, not the manifest.**
   `_ainish_rules_verify_manifest_sig` (`src/deploy_rules_sync.sh:206`) passes
   `$(dirname "$manifest")`, so unrelated receipts decide whether a rules deploy succeeds. At `$HOME`
   it reports 6 passed / 4 failed, and `ainish-deploy.json` is itself among the failures.
3. **`ainish-rag audit verify --path <file>` is broken.** Its help advertises "a Specific receipt file
   or audit directory path", but a file path errors `Os { code: 20, NotADirectory }` — established by
   running it directly. The gate therefore has no way to check one manifest.
4. **Non-git targets get no refresher and are never registered.** `_ainish_rules_target_hooks_dir`
   returns empty when the target is not a git checkout, so `install_rules_sync_hooks` warns and
   `register_rules_target` is still called — but `$HOME` is absent from `targets.txt`, so
   `--rules-sync --all` never refreshes it.

## 3. Plan

1. **Rotate the trust anchor deliberately** (`ainish-rag audit keygen`) so the committed `.pub` matches
   the key this machine signs with, and make the mismatch *impossible to reintroduce*: when a signer
   exists and no anchor exists, write one; when both exist but disagree, refuse with the two
   fingerprints rather than silently signing something that cannot verify.
2. **Narrow the deploy gate** to the manifest it just wrote, using the fixed single-file verify.
3. **Fix `audit verify --path <file>`** in the engine so the help text is true; a directory keeps its
   current aggregate behavior.
4. **Register non-git targets** in `targets.txt` so the root fleet sync refreshes them on every root
   commit, and say plainly in the summary that hooks were not installed and the fleet pass is the
   mechanism instead.

## 4. Clarification Ledger

| # | Question | Answer |
|---|---|---|
| 1 | Rotate the key or recover the old one? | Neither in this branch. No seed exists in the vault, so the original private key is unrecoverable, but rotation strands 14 signed artifacts (12 audit receipts, the canonical contract sig, the wiki ledger) and no bulk re-sign command exists. Rotation is deferred to its own task; it must not ride along with bug fixes. |
| 2 | Narrow the gate or demand a clean audit dir? | Narrow to the manifest; unrelated receipts must not decide a rules deploy. This is also what makes the deploy usable before rotation lands. |
| 3 | How do non-git targets stay current? | Registry + root fleet sync. No cron/launchd. |
| 4 | Stop keys being invented per machine? | Not in this branch, but recorded as the root cause in §7 so the rotation task fixes it rather than papering over it. |

## 5. Todos

- [x] 5.1 `main.rs`: `audit verify --path <file>` verifies one file; directory behavior unchanged.
- [x] 5.2 `deploy_rules_sync.sh`: gate on the manifest only.
- [ ] 5.3 `deploy_rules_sync.sh`: confirm non-git targets register and the summary names the mechanism.
      Deferred with 5.6: registration sits *after* the manifest gate, so it is unreachable while the
      signer/anchor mismatch still aborts the deploy. Proving it needs a working anchor.
- [x] 5.4 Warn (do not fail) when the signer's fingerprint differs from the committed anchor, naming both
      — the deploy must not silently produce artifacts that cannot verify.
- [x] 5.5 Gate all four behaviors; prove each fails before the fix and passes after.
      The three reachable fixes are pinned by 8 new assertions in `scripts/test-pqc-dist.sh`.
      The fourth (`--rules` completing) cannot pass before rotation; see §7.
- [ ] 5.6 (deferred, own task) Rotate the anchor and re-sign the 14 artifacts with a bulk re-sign path.
      Corrected count: **18** tracked signature files (14 `.agents/audit/`, 2 `.agents/canonical/`,
      `.agents/wiki/ledger.sig`, `.scrolls*/manifest.sig*`), and they do not all share one key today —
      `.agents/canonical/AGENTS.sig` is from the local `69e7…` key while the audit receipts are from
      the anchor `d984…`, so both groups must be re-signed in one pass.

## 6. Verification Gates

1. `cargo test --bin ainish-rag` green.
2. `ainish-rag audit verify --path <single-manifest>` exits 0 on a good signature, non-zero on a bad one.
3. `bash scripts/test-pqc-dist.sh` green.
4. `ainish-coder --rules <non-git-dir>` completes AND the target appears in `targets.txt`.
5. A signer/anchor mismatch is reported with both fingerprints, never silently accepted.

## 7. Risks

- **The root cause is deferred, and that has to be loud.** `resolve_or_create_seed`
  (`src/rag/src/pqc.rs:68`) invents a random seed and writes a gitignored `.priv` whenever neither
  `AINISHRAG_MLDSA65_SEED` nor a vault seed is present. Every machine therefore signs with a different
  identity while one anchor is committed. This branch makes `--rules` succeed and *names* the mismatch;
  it does not make signatures verifiable. Rotating the anchor plus setting a durable seed is the real
  fix, and until it lands the deploy reports unverifiable provenance rather than claiming integrity.
- **Rotating the anchor invalidates every existing receipt** signed with `d984…`. A future rotation must
  re-sign 14 artifacts in one pass, or the audit directory will report failures indefinitely.
