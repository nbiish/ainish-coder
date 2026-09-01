# TASK 2026-09-01 — copy CLI-only tts-cli skill

**Branch:** `docs/tts-cli-cli-only-skill`
**Worktree:** `../ainish-tts-cli-skill`
**Classification:** Confidential — no secrets

## Goal

Load the canonical tts-cli skill so ainish-coder agents see only `cli-tts`
tooling: one `--prompt` per turn, eleven master answers, no MCP wording.
Align `AGENTS.md` `<OUTPUT>` with tts-cli (ainish-coder `--rules` deploys
this file).

## Done when

- `.agents/skills/tts-cli/SKILL.md` is byte-identical to tts-cli main.
- Skill file greps clean of `mcp`.
- `AGENTS.md` `<OUTPUT>` matches tts-cli: fused Next-step plus eleven
  one-sentence master answers; no `local-tts-mcp`.

## Non-goals

- Do not rewrite other skill packs.
- Do not add a TTS server.
