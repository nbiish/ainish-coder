# TASK: Sync fused tts-cli skill into ainish-coder

**Date:** 2026-08-31
**Branch:** `docs/tts-fused-skill-sync`
**Worktree:** `../tts-fused-skill-sync`
**Classification:** Confidential — no secrets

## Objective

Copy the canonical tts-cli skill (silent "What would this {master} suggest?"
list, fused Next-step, no panel) into ainish-coder so `--skills-sync` and
agent loads match the engine. Align `AGENTS.md` `<OUTPUT>` with that skill.

## Notes

- Skill file is byte-identical to tts-cli `.agents/skills/tts-cli/SKILL.md`
  on tts-cli `main` at the fused-suggestion commit.
- No secrets. No absolute volume paths.

## Verification

`cmp` skill vs tts-cli source. `AGENTS.md` OUTPUT uses the fused prompt and
the master-suggest question list pointer, not first-match / council-chair.
