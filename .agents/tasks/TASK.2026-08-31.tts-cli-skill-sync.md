# TASK: Sync tts-cli skill into ainish-coder

**Date:** 2026-08-31
**Branch:** `docs/tts-cli-skill-sync`
**Worktree:** `../tts-cli-skill-sync`
**Classification:** Confidential

## Objective

Copy the canonical tts-cli skill from `tts-cli` main (council-chair next-step,
chunking, fail-closed second-marker) into ainish-coder so `--skills` / agent
loads match the engine. Align `AGENTS.md` `<OUTPUT>` with that skill so the
binding rule does not drift.

## Notes

- Concurrent: `feat/skills-byte-verify` (unmerged) owns `--skills-verify/--skills-sync`. This task does not touch that surface.
- Skill file is byte-identical to tts-cli `.agents/skills/tts-cli/SKILL.md` at tts-cli commit `93a1628`.
- No secrets.

## Verification

`cmp` skill vs tts-cli source. `AGENTS.md` OUTPUT uses the concise council-chair prompt, not the old hardened-engineer line.
