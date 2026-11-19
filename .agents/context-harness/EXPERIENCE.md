# Context harness — experience (generation 0)

- updated: 2026-11-19T14:56:37.722589+00:00
- fingerprint: `4e02eea77ff7f9d9`
- components: 6 tuned value(s), 0 domain hint(s), 0 staged skill(s)

## Why this generation was adopted

rolled back from generation 1 to 0

## Evidence

history entry `0000-items-1-2-7-9-and-11-are-all-agents-plan.json`; no staged skills in that generation, so the newer ones were removed

## Rollback

Copy any `history/*.json` back to `prime-profile.json` and delete `generation` from nothing —
the file is self-describing. Or run `ainish-rag --context-rollback <generation>`.
