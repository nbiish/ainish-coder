# TASK: Sync one-shot tts-cli skill into ainish-coder

**Date:** 2026-09-01
**Branch:** `docs/tts-oneshot-skill-sync`
**Worktree:** `../tts-oneshot-skill-sync`
**Classification:** Confidential — no secrets

## Objective

Copy the tts-cli one-shot master-suggest skill (one sentence per expert,
one fused Next step, one speak call) and align `AGENTS.md` `<OUTPUT>`.

## Verification

`cmp` skill vs tts-cli worktree source. OUTPUT says one-shot, not
per-expert tool loops.
