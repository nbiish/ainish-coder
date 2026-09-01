# TASK 2026-09-01 — copy twelve-master tts-cli skill

**Branch:** `docs/tts-cli-twelve-masters`
**Worktree:** `../ainish-tts-twelve-masters`
**Classification:** Confidential — no secrets

## Goal

Load the canonical tts-cli skill so ainish-coder agents speak nine
deterministic production/security chairs plus three `blank / blank`
chairs. Align `AGENTS.md` / `AGENTS.maintainer.md` `<OUTPUT>` so `--rules`
deploys the same roster.

## Done when

- `.agents/skills/tts-cli/SKILL.md` is byte-identical to tts-cli `main`.
- Skill greps clean of `mcp`.
- OUTPUT lists the twelve questions from tts-cli `MASTER_QUESTIONS`.

## Non-goals

- Do not rewrite other skill packs.
- Do not copy unused skills out of tts-cli.
