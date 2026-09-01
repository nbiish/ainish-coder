# TASK.2026-09-01.scrolls-distribution-boundary

**Branch:** `fix/scrolls-distribution-boundary` (worktree `../scrolls-distribution-boundary`, from `main` @ `8311eaf`)

## Operator contract (three interjections, in order)
1. Scrolls contents must NEVER distribute with `--rules` or any skills-sync command.
2. Scroll sections distribute specifically via `--scrolls`.
3. Ghost Layer Injector same: only with the Scrolls command, never `--rules`/`--skills`.
4. Final: everything (payload + 8thfire-scrolls + ghost-layer-injector) distributes under `--scrolls`; the `--8thfire` command is retired.

## Changes (chain-of-draft)
- `src/deploy_skills.sh` — case guard extended: `.scrolls*|8thfire-scrolls|ghost-layer-injector` skipped. #### rules/skills never carry packs
- `src/verify_skills.sh` — `_ainish_skill_excluded` now also excludes `ghost-layer-injector`; sync never copies/repairs scroll packs. #### sync exclusion proven by drift test
- `src/deploy_scrolls.sh` — now deploys raw payload + both packs (only distribution surface); provenance stamp written. #### single-channel consolidation
- `bin/ainish-coder` — `--8thfire` case + source line removed; verify-first gate now checks SOURCE payload (`REPO_DIR/.scrolls`) before deploy (was checking target's nonexistent copy — fresh-target deploys were impossible). #### gate bug fix
- `src/deploy_8thfire.sh` — deleted. #### command retired
- `src/help.sh` — `--scrolls` documented as THE channel; `--rules`/`--skills-sync` text updated; ghost-layer removed from skills list; notes updated.
- `llms.txt` (root DOX) — distribution boundary rewritten: explicit-only `--scrolls`; no `--8thfire`; sync never touches scroll packs.
- `.scrolls/manifest.*` — re-signed (operator-approved, both keys: ML-DSA-65 + council). Payload had drifted post-sign (3042a39); verify gate correctly FAILed before re-sign.

## Verification (all observed live)
- `--rules` → 21 packs; NO 8thfire-scrolls, NO ghost-layer-injector, NO `.scrolls` payload.
- `--skills` → 21 packs, both packs absent.
- `--skills-sync` → drift-marker in seeded 8thfire pack NOT repaired (exclusion proven).
- `--skills-verify` → scroll packs not counted, no mismatch.
- `-i --scrolls <fresh-dir>` (PTY) → verify gate PASS on source, payload 7 files deployed, both packs deployed, deployed copy re-verifies (2 sigs valid), packs byte-identical to source.
- Tamper test → `file hash mismatch: llms.txt` → gate refuses. Non-interactive `--scrolls` → hard refuse.
- `--8thfire` → `Unknown command` rc=1.
- Gates: `bash -n` all, `gitleaks` clean, `ruff` clean.

## Post-deploy consumer note
Deployed copies re-verify via the traveling manifest using the engine (or any FIPS 204 ML-DSA-65 verifier) — `scrolls_verify` wrapper requires the source repo's engine; downstream consumers without it call the Python engine directly.
