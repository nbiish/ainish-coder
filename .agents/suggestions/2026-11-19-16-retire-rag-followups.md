2026-11-19-16-retire-rag-followups
# Follow-ups the RAG retirement surfaced

## 1. On-disk schema strings still say `ainish-rag/`

`ainish-rag/prime-profile/v1`, `ainish-rag/context-harness-status/v1`,
`ainish-rag/context-harness-autolearn/v1`, `ainish-rag/mldsa65-envelope/v1`, and the rest are written
INTO files (`prime-profile.json`, `*.sig`) that this repo and possibly deployed repos already hold.
Renaming them is a data migration with a compatibility window, not a rename.

**Settled by:** adding a `format`-aliasing reader that accepts either prefix, then bumping the writer
in one deliberate release. Until then the prefix is a schema name, not a product name.

## 2. `AINISH_RAG_*` environment variables remain

`AINISH_RAG_DRIVER_MODEL`, `AINISH_RAG_GOLDFISH_MODEL`, `AINISH_RAG_ALLOW_SELF_REVIEW`,
`AINISH_MLDSA65_SEED` (already new), and friends are read on every call and named in deployed rules.
Renaming them silently would disable an operator's pins on upgrade.

**Settled by:** reading `AINISH_CONTEXT_*` first and falling back to `AINISH_RAG_*` with a one-line
deprecation notice, then removing the fallback after a release.

## 3. Skill packs named for the old era

`skills-to-distribute/skills/typesafe-jev/references/rag-decision-catalog.md` documents the decision
catalogue and is named for RAG, though its content is about typed decisions and is still current. Its
prose is updated; the FILENAME is stale.

**Settled by:** renaming the reference to `decision-catalog.md` and updating the pack's `llms.txt`
index in one edit — safe, because it is a distributed file, not a signed artifact.

## 4. `bin/ainish-rag` should eventually be deleted

It exists so a deployed `AGENTS.md` written before this change keeps working. Every call prints a
deprecation line, which is noise if nothing calls it.

**Settled by:** checking whether any `.agents/ainish-sync.json` in a real deploy target still names
`ainish-rag`; if none do after a release, delete the shim.
