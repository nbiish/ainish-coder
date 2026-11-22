2026-11-21-15-airpc-distribute
# Task: move aiRPC into the distributed skills payload

- lane: now
- branch: `skill/airpc-distribute` (merged `2f23e86`, commit `07416aa`)
- status: done (moved; dist suite 440 pass at baseline; demo server stopped on request)
- plan: `.agents/plans/2026-11-21-15-airpc-distribute.md`
- scope: `.agents/skills/aiRPC/` → `skills-to-distribute/skills/aiRPC/` (git mv, four files)
- objective: aiRPC ships with the rest of the `ainish-coder --skills` tooling; the demo server is
  down and no process is left running.

## What changed

| Was | Now |
|---|---|
| `aiRPC/` under `.agents/skills/` (this repo's standing prompt surface) | `aiRPC/` under `skills-to-distribute/skills/` (the distributable payload; `src/deploy_skills.sh` deploys it to consumer repos' `.agents/skills/`) |
| demo bridge running (pid 38656) | stopped via `bridge.mjs stop --session demo`; port 7331 free, no bridge processes (verified) |

## Findings

1. The machine's internal disk was **100% full** (165M free) — `scripts/test-pqc-dist.sh` was
   failing nondeterministically with `No space left on device` on fixture writes. Freeing ~5.6G of
   unambiguous regenerable caches (three updater payloads; puppeteer, codex-runtimes, opencode,
   chrome-devtools-mcp, act) turned the flaky failures into a stable baseline. The model caches
   (huggingface/modelscope/suno/uv) are symlinks to the external 1TB drive — deleting there would
   have freed nothing on the full disk.
2. One dist assertion fails at baseline, before and after this move, identically (440 pass,
   1 fail): "a tool-authored commit is re-authored as the operator" wants `embodied by cursor`
   but gets `embodied by claudecode`. Provenance: the sibling merge `7685720` touched both
   `scripts/test-pqc-dist.sh` and `scripts/harness-attribution.txt`. Not fixed here — that
   subsystem is a sibling session's active boundary; recorded as
   `.agents/suggestions/2026-11-21-15-attribution-table-test-drift.md`.
3. The two `llms.txt` skill indexes are byte-identical by external convention and already list
   `aiRPC/`; the index also lists packs that exist only in the payload, so no index edit was
   needed. Payload links are written for the deployed position (`.agents/skills/<name>/`), as
   `question-me` does — the aiRPC links stay correct after deploy.

## Verification

- `bash scripts/test-pqc-dist.sh`: 440 pass / 1 fail, where the failure is byte-identical to the
  clean-`main` baseline run without this change (both runs: `got '…embodied by claudecode', want
  '…embodied by cursor'`). No new failures from the move.
- `ls` both paths: `skills-to-distribute/skills/aiRPC/` holds SKILL.md + references/; 
  `.agents/skills/` holds only ainish-security, llms.txt, pqc-secrets, question-me.
- `git log main..skill/airpc-distribute` empty at merge; the four files moved as 100% renames
  (diffstat clean); worktree removed, branch deleted.
- Server stopped: `bridge.mjs status --session demo` → `running: false`; `lsof :7331` empty;
  `pgrep -fl 'bridge.mjs serve'` empty.

## Open

- The pre-existing attribution failure above (suggestion filed; owner decides which literal is
  canonical).
- Internal disk stands at 5.4G free (99%) — cleanup scope is the operator's call (Orca item 1).
