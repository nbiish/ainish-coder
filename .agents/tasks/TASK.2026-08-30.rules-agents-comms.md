# TASK: `--rules` ships AGENTS/{date}.COMMS.md deployment

## Goal
`ainish-coder --rules` deploys the Agent Communication System
(`AGENTS/{date}.COMMS.md`) to a target repo, with merge-not-overwrite logic so
iterations of ainish-coder never clobber agent-authored context (entry blocks)
already present in a target's existing ledger.

#### Chain-of-Draft
- rules deploys AGENTS.md+gitignore today; add comms ledger
- template = protocol header, source of truth in ainish-coder
- merge: keep protocol current, never touch agent entries
- marker lines delimit template-managed region
- live board stays local (gitignored); only dated ledger deploys
- smoke: fresh, merge, legacy, -n, idempotent
