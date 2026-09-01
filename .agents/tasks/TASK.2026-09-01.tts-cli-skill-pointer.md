# TASK 2026-09-01 — tts-cli skill pointer, not a copied roster

**Branch:** `docs/tts-cli-skill-pointer`
**Worktree:** `../ainish-tts-skill-pointer`
**Classification:** Confidential — no secrets

## Goal

Keep `.agents/skills/tts-cli/SKILL.md` as the speak prompt. `AGENTS.md` and
`AGENTS.maintainer.md` only say how to operate `cli-tts` through that skill.
Do not paste tts-cli's twelve-master roster into this repo's `AGENTS.md`.

## Done when

- Skill file unchanged (still byte-identical to tts-cli).
- `<OUTPUT>` points at the skill; no `What would this … master suggest?` list.
- `--voice` / `--speed` / `--wait` / `--output` remain omitted.

## Non-goals

- Do not rewrite other skill packs.
- Do not copy tts-cli `AGENTS.md` into this repo.
