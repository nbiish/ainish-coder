# Task: Close out signing fail-fast and the smoke sandbox

- lane: now
- branch: main (direct, small targeted fixes)
- status: done
- scope: `src/deploy_rules_sync.sh`, `scripts/test-pqc-dist.sh`
- objective: Close the two remaining threads from the skills-selection work — the empty `test/` sandbox and the RAG-engine signing dependency.

## 1. Signing dependency — half-deployed targets

**Defect.** The compiled `ainish-rag` engine is a gitignored build artifact, so a fresh clone has no signer. `deploy_rules_sync` wrote the manifest and refresher *first*, then tried to sign and failed. The result on a clean clone:

- exit 1 (correct)
- `.agents/ainish-deploy.json` written with **no** `.sig` — a signed-expectation manifest that can never verify
- `.agents/bin/ainish-rules-sync` installed and hooks armed
- target **not** enrolled in the fleet
- one-line warning, no guidance

That is a half-deployed target: the guard fires, but only after mutating the repo.

**Fix.** `_ainish_rules_require_signer` preflights before any artifact is written. A missing engine now fails fast and names the build step; nothing is written, no hooks, no enrollment, and an existing valid manifest is left intact rather than damaged.

**Not done, deliberately.** The signature was not made optional. The operator chose to keep the fail-closed provenance guarantee; making it optional would silently weaken a trust boundary to suit a build-artifact gap. The real remedy for a clone is to build the engine, and the message now says exactly how.

## 2. Smoke sandbox

`D:\Code\ainish-coder\test` was cleared to an empty directory (still gitignored via `/test/`), and its stale fleet enrollment was removed with `--rules-unenroll`, since the deployment inside it no longer exists. The directory remains so the operator can run `ainish-coder --rules` there fresh.

Two real targets remain enrolled and CURRENT: `local-router` and `ainish-coder-rules-smoke`.

## Verification

- Real clone of the repo: old behavior reproduced (manifest without `.sig`, exit 1, unenrolled), new behavior refuses before writing anything.
- `scripts/test-pqc-dist.sh` **62/62 PASS**, including 5 new assertions: refusal exits 1, no manifest written, no refresher installed, refused target not enrolled, and the message names `cargo build --release`.
- Normal deploy path unchanged: manifest, `.sig`, hooks, and enrollment all still produced; `audit verify` 16/16.
- Fleet: 2/2 CURRENT, 2/2 signatures verified.

## Remaining, unfixed by choice

Manifest signing still depends on the compiled RAG binary. Decoupling it (moving ML-DSA signing off the engine) was explicitly deferred — it touches the trust boundary and deserves its own decision, not a side effect of a cleanup pass.
