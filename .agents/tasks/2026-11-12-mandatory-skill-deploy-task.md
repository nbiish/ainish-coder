2026-11-12-mandatory-skill-deploy-task
# Make `security-first-agent` mandatory, and express "mandatory" once

- **status:** done
- **branch:** `fix/mandatory-skill-deploy`
- **plan:** `.agents/plans/2026-11-12-mandatory-skill-deploy.plan.md`
- **scope:** `src/skills_selection.sh`, `src/verify_skills.sh`, `src/deploy_skills.sh`,
  `src/help.sh`, `llms.txt`, `skills-to-distribute/skills/llms.txt`, `.agents/skills/llms.txt`,
  `scripts/test-pqc-dist.sh`
- **operator ask:** "the security-first-agent skill should also be a mandatory skill deploy with the
  others (the mandatory skills should not be visible in the skills selection, which is a redundancy)."

## What was found

1. **"Mandatory" was written four times and had already drifted.** `_skill_mandatory`
   (`src/skills_selection.sh`) held `pqc-secrets|ainish-security`; `_skill_channel_excluded` held the
   same two again to hide them from the selector; `_ainish_skill_mandatory` (`src/verify_skills.sh`)
   held a third copy with a "keep in step" comment; `_skills_mandatory_names` printed a fourth list —
   and that one said only `pqc-secrets`, so the CLI's "no optional packs selected" hint compared
   against a set that was already wrong.
2. **The hiding mechanism was the redundancy the operator named.** Every selection surface
   (`skills_selection_list`, both toggle UIs) consulted `_skill_channel_excluded`, not
   `_skill_mandatory`. Adding a pack to the mandatory predicate alone therefore left it visible and
   toggleable — mandatory in distribution, optional in the UI.
3. **`--skills-sync` skipped mandatory packs.** `sync_ainish_skills` step 3 skipped anything whose
   persisted selection was not `on`, so a target carrying a stale `security-first-agent: false` (or
   `pqc-secrets: false`) entry received nothing from sync while `--rules` shipped the pack and
   `--skills-verify` failed it as `MISSING MANDATORY`. Three paths, two answers.
4. **The inventory was wrong.** `--help` claimed "20 skill packs" and listed 17; the payload holds 19
   distributable packs (`8thfire-scrolls` and `ghost-layer-injector` are scroll-channel).
   `security-first-agent` and `tts-cli` were missing from the list.

## What changed

- `_skill_mandatory` is now the only list: `pqc-secrets`, `ainish-security`, `security-first-agent`.
- `_skill_channel_excluded` no longer names any mandatory pack; it keeps only retired packs and the
  scroll channel.
- `_skills_mandatory_names` derives the set by enumerating the payload through `_skill_mandatory`, so
  it cannot disagree with the predicate.
- `skills_selection_list` and both toggle UIs skip mandatory packs through `_skill_mandatory`.
- `_ainish_skill_mandatory` is a delegate, not a copy; `verify_ainish_skills` fails closed and loudly
  if the predicate is not loaded instead of downgrading every mandatory pack to a "missing" note.
- `sync_ainish_skills` ships mandatory packs regardless of a recorded `off`.
- `--help` lists all 19 packs, marks the three mandatory ones, and no longer claims 20.
- `AGENTS.md` is deliberately unchanged. A table row pointing at the pack was drafted, drawn, and
  dropped: editing the contract makes the deploy path re-sign `.agents/canonical/*` and append to
  `.agents/audit/contract-history.jsonl`, and this working tree already carries an uncommitted audit
  chain two entries ahead of `HEAD`. Adding a competing chain, or a re-signed snapshot with no chain
  entry, would leave the audit trail worse than it is. The pack is mandatory on the same rule as
  `ainish-security` — the payload index shipped beside it, `.agents/skills/llms.txt`, sends an agent
  to it by path, so an omitted copy is a dead link. The contract row belongs with the anchor rotation.
- `llms.txt` and the payload index (mirrored to `.agents/skills/llms.txt`) describe three mandatory
  packs and state that both `--rules` and `--skills-sync` ship them.

## Verification (all run in the worktree)

- `bash scripts/test-pqc-dist.sh` → **PASS: 240** (baseline 229), exit 0. New assertions:
  mandatory set is exactly the three, an optional pack is not mandatory, channel exclusion names no
  mandatory pack, `_skills_mandatory_names` equals the set, `skills_selection_list` hides all three
  and still shows optional packs, `--skills` refuses to toggle one, verify delegates, sync gates on
  the predicate, help/contract/PRD/payload index name it.
- `bash -n` clean on every touched script.
- Hermetic `--rules` probe (temp `$HOME`, temp target, no recorded selection): logs
  `✓ Deployed (mandatory): .agents/skills/{ainish-security,pqc-secrets,security-first-agent}`; the
  target receives exactly those three plus the index.
- `--skills-list --json` on that target: `mandatory: [ainish-security, pqc-secrets, security-first-agent]`,
  and none of them appear in `on`/`off`.
- `--skills-sync` probe with `{ainish-security:false, pqc-secrets:false, security-first-agent:false}`
  recorded: all three deployed, `deployed=3`, config entries left intact as history.
- `--skills-verify` on a target with the pack removed: `✗ MISSING MANDATORY: security-first-agent`,
  exit 1.
- Probe trees removed by literal path after clearing `uchg`; `find` confirms zero leftovers.

## Findings / open items

- The contract was left alone on purpose. Editing `AGENTS.md` is not free: the deploy path re-signs
  `.agents/canonical/*` and appends to `.agents/audit/contract-history.jsonl`, and this repo's working
  tree already holds an uncommitted chain whose head is two entries past `HEAD`. A test deploy proved
  the churn (four canonical files + one chain entry, signed by the local `69e7233d…` key, which is not
  the committed anchor `d98405ea…`), so the edit was reverted rather than committed. The contract row
  and the anchor rotation should land together, in one re-signing pass.
- `--rules` still refuses to *report* a signed deployment on this host because the RAG engine is not
  built in this worktree (`bin/ainish-rag` is a launcher). Unrelated to this change; skills deploy
  before the refusal.
- `tts-cli` was added to the `--help` inventory because it is a distributable pack, but no surface
  says what it is for beyond its own SKILL.md. If the channel is meant to be retired, the pack should
  be removed or channel-excluded rather than left selectable and undocumented.
