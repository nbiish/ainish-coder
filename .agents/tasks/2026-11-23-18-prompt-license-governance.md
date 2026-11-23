2026-11-23-18-prompt-license-governance
# Task: prompt governance + canonical license sync gate

- lane: now
- branch: `docs/prompt-license-governance` (worktree `/Users/nbiish/code/ainish-coder-wt-prompt-license`)
- status: done
- plan: `.agents/plans/2026-11-23-18-prompt-license-governance.md`
- companion: `license-for-all-works` branch `docs/license-sync-gate` (canonical standard + CI workflow)
- PRs: `nbiish/ainish-coder#12`, `nbiish/license-for-all-works#6` — open, awaiting human approval
- scope: `AGENTS.md`, `.agents/templates/prompt-context-governance.md`, `scripts/test-pqc-dist.sh`,
  `.github/workflows/license-sync.yml`, `critical.md`, `LICENSE`, canonical contract artifacts
- objective: put a concise prompt/context governance rule in the universal contract with a versioned
  full-text template; make canonical `LICENSE` a byte-for-byte merge gate and auto-sync it on merges
  to `main`; bring in the operator's updated license now. P0 consolidation explicitly deferred.

## What changed

- `AGENTS.md` 5 condensed for anti-promptarding; new rules 13 (prompt governance, versioned
  templates, prune stale rules) and 14 (legal text canonical; CI byte gate; `critical.md` §7).
  Six lines were reclaimed from preambles so the contract stays at 159 of 160 and every phrase
  pinned by `scripts/test-pqc-dist.sh` remains intact. Edit made in a worktree (no `uchg` lock).
- Full operator policy preserved verbatim in `.agents/templates/prompt-context-governance.md`
  (`format: ainish/prompt-policy/v1`, version 1.0.0) with repo-specific operational notes.
- Dist suite asserts the template pointer resolves, the canonical-license rule is present, and
  the workflow file resolves (441 → 445 assertions).
- Canonical `critical.md` §1.3/§1.4 now name production `LICENSE` as the byte-for-byte sync target
  (`working-LICENSE` is byte-identical here; divergence is an operator promotion decision); §6/§7
  describe the PR gate, the metadata check, the integration PR and the exact commit message.
- Canonical `.github/workflows/license-sync.yml`: `pull_request` guard fails when local `LICENSE`
  differs from canonical (`cmp -s`, prints both SHA-256s); metadata declarations in `package.json`,
  `pyproject.toml`, `README.md` and source headers are checked for foreign license names; on
  push/weekly the sync job overwrites drifted files verbatim and opens an integration PR with
  `chore(license): sync canonical license from license-for-all-works`. Canonical repo skips its own
  byte guard; its `license-ci.yml` validates its own changes.
- This repo now carries the canonical workflow, canonical `critical.md` and the updated `LICENSE`
  verbatim (SHA-256 `6b18aab7…`, was `1d330ecc…`). No `package.json`/`pyproject.toml` or source
  license headers here; README license reference already matches canonical.

## Verification

- `bash scripts/test-pqc-dist.sh` → PASS: 445 assertion(s) (baseline 441, +4 new).
- `./bin/ainish-context gate --summary` → `GATE:GREEN | anchor:N/A | patch:DOCS | lock:OK | pqc:13/13 | comms:OK | zt:OK`.
- `./bin/ainish-context audit contract --verify-history` → signature VERIFIED.
- `./bin/ainish-coder --rules-verify` → all registered targets VERIFIED.
- `sha256sum`/`cmp` → `LICENSE`, `critical.md`, `license-sync.yml` byte-identical to canonical.
- Workflow YAML parsed with `yaml.safe_load`; metadata check logic run locally → OK.

## Deliberately not done

- P0 tasks/plans consolidation (operator owns it in a separate task).
- Merging either PR; no force-push, no direct `main` commits, no touching pre-existing dirty paths
  in the main checkout.
