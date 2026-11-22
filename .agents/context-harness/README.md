# `.agents/context-harness/` — the per-repo context harness

Written by `ainish-coder --rules` at generation 0, and by `ainish-coder --context-learn` thereafter.

| File | What it is |
|---|---|
| `prime-profile.json` | Bounded retrieval tuning for this repository only. Numbers and short token lists; nothing here can execute. |
| `skills/<name>/` | STAGED skills. Reached only through `--context`, never auto-loaded. |
| `EXPERIENCE.md` | Why the live generation is what it is, with the evidence behind it. |
| `history/` | Every past generation, immutable. |
| `rejected/` | Proposals refused, with the condition that refused them. |

## Rollback in three lines

    ls .agents/context-harness/history/
    ainish-coder --context-rollback <generation>
    ainish-coder --context-status

## Revoking a promoted skill

    rm -rf .agents/skills/learned-<name>/

A promoted pack is standing prompt surface for every agent harness in this repository.
That is why the learner never promotes; only you do.
