# Task: Restore skill selection in `--rules` (regression from rules hardening)

- lane: now
- branch: fix/rules-skill-selection
- status: done
- scope: `bin/ainish-coder`, `src/skills_selection.sh`, `src/deploy_skills.sh`, `src/help.sh`, `llms.txt`, `AGENTS.md`, `.agents/canonical/AGENTS.md`, `scripts/test-pqc-dist.sh`
- objective: `ainish-coder --rules` must let the operator choose which `.agents/skills/` packs deploy, without reintroducing the interactive stall that `b268b75` removed it for.

## Root cause

Two commits combined into a silent zero-deploy:

- `b268b75` deleted the interactive `_skills_toggle_ui` call from `deploy_rules_bundle` (it had stalled WSL runs) and replaced it with a persisted-selection-only deploy.
- `fdd8537` then flipped `skills_selection_default_on` from `on` to `off`, so a repo with no recorded selection — which the selector was the only way to create — resolved every pack to OFF.

Result: `--rules` printed 19 "Deselected" lines, `⚠ No skills found to deploy`, and no way to choose. The selector survived only on `--skills-sync`.

## Change

- `_rules_deploy_skills` replaces the either/or branch in `deploy_rules_bundle` with three bounded paths:
  `always` (selector opens: explicit request, or first contact with an unrecorded repo on a real TTY), `never`
  (headless/`-y`/non-TTY — persisted selection only), and `auto` (cancel/timeout — falls back to the persisted
  selection so the run still completes).
- Selector is now offered once per repo, then governed by the saved selection, so repeat runs and CI stay
  deterministic instead of prompting forever or deploying nothing.
- `skills_selection_tty_ok` becomes the single TTY predicate; `skills_selection_ui_mode` derives
  always/never/auto from `AINISH_HEADLESS`, `AINISH_NON_INTERACTIVE`, TTY state, and `AINISH_SKILLS_PROMPT`.
- `skills_selection_should_prompt` / `skills_selection_repo_recorded` answer "has this repo been asked?".
- The raw selector's key read is bounded by `AINISH_SKILLS_PROMPT_TIMEOUT` (default 120s), so an abandoned
  terminal cancels instead of hanging — the original stall cannot come back through this path.
- `--select-skills [DIR]` reopens the selector on demand; `--skills-list [DIR] [--json]` reports the saved
  choice (`recorded`, `default`, `on`, `off`, counts) via the new `skills_selection_report`.
- `--skills-sync` on a cancelled selector now syncs the saved selection instead of aborting.
- Zero-pack output names the fixing command in both `deploy_skills` and `_rules_deploy_skills`.
- `llms.txt`, `AGENTS.md` (+ canonical copy, digest, ML-DSA-65 signature), and `--help` document the
  ask-once-then-remember contract.

## Compat

No manifest or selection-file format change; `skills-selection.json` is unchanged and existing per-repo
choices keep working. New flags are additive. `--headless`/`-y`/non-TTY behaviour is unchanged (persisted
selection, no prompts). `AINISH_SKILLS_DEFAULT` / `AINISH_SKILLS_SELECTION` overrides still work.

## Verification

- `bash scripts/test-pqc-dist.sh` → **51/51 PASS** (14 new skill-selection assertions, plus the two
  formerly-failing `--pqc-install` assertions fixed below).
- End-to-end pty smoke with the REAL engine and no stubs, **21/21**: first-contact selector appears and
  deploys exactly the chosen pack; second run reuses the saved selection silently; `-y` and `--headless`
  never prompt; `--select-skills` persists; cancel and idle timeout both fall back to the saved selection
  and still finish the deployment; every run exits 0 within seconds.
- Unattended paths, **4/4**: the installed `.agents/bin/ainish-rules-sync` refresher and
  `--rules-sync --all --quiet` both complete in ~1s and never open the selector.
- Fresh-install identity, **7/7**: `ok:true` with a keypair and no bundle; second install reports
  `present`; a populated store still installs cleanly.
- `set -euo pipefail` edge cases: zero-selection JSON report, human report, empty counts, nonexistent repo,
  missing config file, invalid timeout — all exit 0 with sane values.
- `ainish-rag audit verify` → 16/16 receipts verified; `audit contract --verify-history` → 27 hash-chained
  transitions verified. `AGENTS.md` and `.agents/canonical/AGENTS.md` are byte-identical.

## Notes

- **The WSL hang is fixed, not worked around.** The engine invocation was being stopped by SIGTTIN:
  under WSL the Windows `.exe` launches through `/init`, which reads inherited stdin, and in a
  non-foreground process group (command substitution, git hook, background job) that read stops the
  process (`T`, `wchan: do_signal_stop`) instead of failing. A stopped child also stops the `timeout`
  watchdog, so the 20s bound never fired. Every engine invocation now detaches stdin, which makes the
  existing timeouts enforceable: real-engine `--rules` under a pty went from hanging indefinitely to
  exiting 0 in 6–8s.
- **`--pqc-install` no longer false-negatives on a fresh install.** It required `bundleExists`, but
  `keygen` only creates the ML-KEM-768 keypair and bundles appear when a secret is first packed — so
  every clean install reported `ok:false` while its launcher was ready. Existing stores masked this.
  Success now means "launcher installed and a usable identity resolves".
- The selector never opens inside the auto-sync refresher or the fleet sync (`--headless` by
  construction), verified against the installed refresher and `--rules-sync --all --quiet`.
