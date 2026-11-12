# Rules deploy: fail for the right reason, and name the one it cannot fix

- **status:** done (see *Scope boundary* — gate 4 is deliberately not met)
- **branch:** `fix/rules-sync-signing`
- **plan:** `.agents/plans/2026-11-11-rules-sync-signing.plan.md`
- **scope:** `src/deploy_rules_sync.sh`, `src/rag/src/main.rs`, `src/rag/src/pqc.rs`, `scripts/test-pqc-dist.sh`

## What was found

1. **`audit verify --path <file>` was broken.** Its help advertises "a Specific receipt file or audit
   directory path", but a file path fell through to `read_dir` and died with
   `Os { code: 20, NotADirectory }`. No caller could verify one artifact, so the deploy gate had to
   sweep a whole directory — which is fault 2.
2. **The deploy gate judged the whole `.agents/` directory.** `_ainish_rules_verify_manifest_sig`
   passed `$(dirname "$manifest")`, so at `$HOME` (where `.agents/` also holds mcp-settings, a skill
   lock and contract history) six unrelated receipts decided the deploy — and `ainish-deploy.json`
   was itself among the failures. A rules deploy is answerable only for what it wrote.
3. **The signing key is not the committed trust anchor.** `resolve_or_create_seed`
   (`src/rag/src/pqc.rs`) invents a random seed and writes a gitignored
   `.agents/audit/signer.mldsa65.priv` whenever neither `AINISHRAG_MLDSA65_SEED` nor a vault seed
   exists. Measured on this host: signer `69e7233dc777…`, anchor `d98405ea3684…`.
4. **The original seed is unrecoverable, so the mismatch cannot be repaired by configuration.**
   `pqc-secrets list` holds no `AINISHRAG_MLDSA65_SEED`; the only `signer.mldsa65.priv` on this
   machine is the invented one; and `git log -- .agents/audit/signer.mldsa65.pub` shows the anchor
   unchanged since `20da58c` (2026-10-12). Established by all three checks.

## What was built

1. **`audit verify --path <file>` verifies exactly that file**, and a directory keeps its aggregate
   sweep. A missing envelope fails that file by name.
2. **The deploy gate verifies the manifest it just wrote** — nothing else.
3. **`ainish-rag audit anchor-check`** prints `signer|anchor` and exits 3 on a mismatch, silent and 0
   when they agree. `--rules` calls it and prints both fingerprints before deciding, so a deploy
   never silently produces artifacts that cannot verify.
4. **Rotation is refused as a side effect.** The check is read-only: it never writes the anchor,
   never re-signs, never clears flags. A trust-root change stays a deliberate, reviewed act.

## Scope boundary — gate 4 is not met, on purpose

The plan's gate 4 ("`ainish-coder --rules <non-git-dir>` completes AND the target appears in
`targets.txt`") **does not pass on a machine whose signer is not the anchor**, and this branch does
not make it pass. Measured: the deploy now prints the mismatch and still exits
`✗ Auto-sync deployment failed; refusing to report an unsigned or unverifiable rules deployment`,
because `verify_file` compares the envelope's `public_key_fingerprint` against the anchor and they
disagree. That is the correct behavior — accepting the signature would be reporting integrity the
deploy does not have.

Making gate 4 pass requires **rotating the anchor and re-signing 18 tracked artifacts** (14 in
`.agents/audit/`, 2 in `.agents/canonical/`, `.agents/wiki/ledger.sig`, and the `.scrolls**` set).
The artifacts are not interchangeable: `.agents/canonical/AGENTS.sig` is already from the *local*
key `69e7…` while `.agents/wiki/ledger.sig` and the audit receipts are from the *anchor* key
`d984…`, so a rotation re-signs the first group and invalidates the second unless both are redone in
one pass. That is plan todo 5.6 and it is deliberately a separate task. Deferring it was the
operator's decision (plan clarification 1: "Rotation is deferred to its own task; it must not ride
along with bug fixes").

## Verification

- `cargo test --bin ainish-rag` — 58 passed, 0 failed.
- `bash scripts/test-pqc-dist.sh` — 229 assertions pass (up from 221; the 8 new ones pin the three
  fixes above and refuse an anchor rotation in the deploy path).
- `ainish-rag audit anchor-check` on this host — `69e7233dc777…|d98405ea3684…`, exit 3. Correctly
  detects the live mismatch rather than reporting success.
- `ainish-rag audit verify --path <single file>` — signed file fails only with `signed by a key
  other than the trust anchor` (the honest state); unsigned file fails by name; neither raises
  `NotADirectory`.
- `ainish-coder --rules <tmp target>` — completes the deploy, prints both fingerprints, then refuses
  at manifest verification with the message above. **Not** gate 4.
- Temp-tree cleanup: a deployed `AGENTS.md` is `uchg`-locked by design, so the old `rm -rf "$WORK"`
  trap failed every run and left 13 orphaned `pqc-dist-test.*` trees in `$TMPDIR`. The trap now
  clears `uchg`/`+i` and write bits first. Verified: 0 trees remain after a full run.

## Remaining

- Rotate the trust anchor and re-sign all 18 artifacts in one pass, then set a durable
  `AINISHRAG_MLDSA65_SEED` in the vault so a machine cannot invent its own identity again. Plan
  todo 5.6.
- Until then, `--rules` reports unverifiable provenance and refuses. That is the honest state.
