---
plan_format: ainish/plan/v1
slug: mandatory-skill-deploy
date: 2026-11-12
status: done
branch: fix/mandatory-skill-deploy
worktree: /Users/nbiish/code/mandatory-skill-deploy
task_record: .agents/tasks/2026-11-12-mandatory-skill-deploy-task.md
operator: nbiish
---

# Plan: one mandatory-skill list, honoured by every distribution path

## 1. Problem

`security-first-agent` is a pack an agent must carry, but nothing in the tooling says so: it is
selectable, defaults to OFF, and a target deployed with `--rules` today receives neither it nor any
statement that it is required. Meanwhile "mandatory" is expressed three times in three shapes, and the
copies have already drifted:

1. `_skill_mandatory` (`src/skills_selection.sh:92`) — `pqc-secrets|ainish-security`.
2. `_skill_channel_excluded` (`src/skills_selection.sh:74`) — hides the same two from the selector,
   duplicating the list. This is the redundancy: the selector hides mandatory packs only because a
   second list happens to name them, so adding a pack to `_skill_mandatory` alone leaves it visible.
3. `_ainish_skill_mandatory` (`src/verify_skills.sh:106`) — a third copy, with a comment telling the
   reader to "keep in step" with #1. `_skills_mandatory_names` (`src/skills_selection.sh:102`)
   is a fourth, and already disagrees with #1: it prints only `pqc-secrets`.

Two behavioural faults follow from the split:

- **`--skills-sync` skips mandatory packs.** `sync_ainish_skills` step 3 (`src/verify_skills.sh:567`)
  continues unless the persisted selection says `on`, so a repo whose stale config records
  `pqc-secrets: false` never receives it by sync, while `--rules` ships it and `--skills-verify`
  fails it as `MISSING MANDATORY`. Distribution paths disagree about the same pack.
- **`--skills-list` and the toggle UIs hide mandatory packs by the wrong predicate.** They consult
  `_skill_channel_excluded`, not `_skill_mandatory`.

## 2. Anchor Facts

- `src/skills_selection.sh:74-97` — the duplicated lists, as quoted above.
- `src/verify_skills.sh:106-111` — the third copy; `:166` consumes it for the hard failure.
- `src/verify_skills.sh:566-569` — the sync skip that contradicts it.
- `src/deploy_skills.sh:102-168` — the only consumer that already does the right thing
  (`_skill_mandatory` gates the mirror-swap, the `--no-overwrite` exemption, and the no-pin rule).
- `bin/ainish-coder:211` — `_skills_mandatory_names` drives the "no optional packs" hint.
- `skills-to-distribute/skills/` holds 21 directories; 2 are scroll-channel, leaving **19**
  distributable packs. `src/help.sh:334` claims 20 and lists 17 (missing `security-first-agent`
  and `tts-cli`), so the operator-facing inventory is wrong today.
- `.agents/skills/llms.txt` and `skills-to-distribute/skills/llms.txt` are byte-identical and both
  describe `security-first-agent` as merely "use when…", never as mandatory.

## 3. Change Set

1. **`src/skills_selection.sh`** — `_skill_mandatory` becomes the one list:
   `pqc-secrets`, `ainish-security`, `security-first-agent`. Drop the mandatory branch from
   `_skill_channel_excluded` (it keeps only retired packs and the scroll channel). `_skills_mandatory_names`
   enumerates the source tree through `_skill_mandatory` instead of printing a hardcoded name.
   `skills_selection_list`, `_skills_toggle_ui_raw`, `_skills_toggle_ui_numbered` and
   `skills_selection_enabled_count` skip mandatory packs via `_skill_mandatory`.
2. **`src/verify_skills.sh`** — delete `_ainish_skill_mandatory`'s private case list; delegate to
   `_skill_mandatory`, and fail the verify early (loudly) if the predicate is not loaded. Make
   `sync_ainish_skills` treat a mandatory pack as `on` regardless of the persisted entry.
3. **`src/deploy_skills.sh`** — comment only: name the property, not one pack.
4. **`src/help.sh`** — 19 packs, every one listed, mandatory ones marked; `security-first-agent`
   and `tts-cli` no longer missing.
5. **`llms.txt`** — three mandatory packs, why each is one, and the fact that both `--rules` and
   `--skills-sync` ship them.
6. **`skills-to-distribute/skills/llms.txt`** (+ repo-local `.agents/skills/llms.txt`, kept identical) —
   mark `security-first-agent` mandatory in the child index.
7. **`AGENTS.md`** — considered, then deliberately not touched. A table row pointing at
   `.agents/skills/security-first-agent/SKILL.md` would have made the contract the reason the pack is
   mandatory, but editing the contract makes the deploy path re-sign `.agents/canonical/*` and append
   to `.agents/audit/contract-history.jsonl` — and this repo's working tree carries an uncommitted
   audit chain whose head is two entries ahead of `HEAD`. Committing a competing chain, or a
   re-signed snapshot with no chain entry, would trade one inconsistency for a worse one. The pack is
   mandatory on the same rule as `ainish-security`: the payload index that ships beside it,
   `.agents/skills/llms.txt`, sends an agent to it by path, so an omitted copy is a dead link.
   Adding the contract row belongs with the anchor-rotation work that re-signs the whole set at once.
8. **`scripts/test-pqc-dist.sh`** — replace the two text assertions that pin the old duplicated lists
   with functional ones: all three packs classify mandatory, `_skill_channel_excluded` names no
   mandatory pack, `_skills_mandatory_names` equals the set, `skills_selection_list` omits them,
   `sync_ainish_skills` gates on `_skill_mandatory`, and `--help`/`llms.txt`/the payload index name
   the pack.

## 4. Verification

- `bash scripts/test-pqc-dist.sh` — all assertions pass (baseline 229).
- `bash -n` on every touched script.
- Hermetic exercise: temp `$HOME`, `ainish-coder --rules <tmp> --headless` deploys
  `.agents/skills/security-first-agent/` with no selection entry; `--skills-list <tmp>` does not
  list it; a target with `security-first-agent: false` recorded still receives it on `--skills-sync`.
- `ainish-coder --skills-verify` on a target missing the pack exits 1 naming `MISSING MANDATORY`.

## 5. Risks / boundaries

- `AGENTS.md` is untouched on purpose (see §3.7): editing the contract re-signs
  `.agents/canonical/*` and appends to the audit chain, which this working tree already carries
  uncommitted. The pack is mandatory for the same reason `ainish-security` is, and the contract row
  belongs with the anchor rotation that re-signs everything in one pass.
- The selector's raw-mode UI cannot be driven headlessly; its exclusion is verified by the predicate
  it now calls plus the numbered fallback path, not by keystrokes.
- No signing/anchor work: `--rules` still refuses at manifest verification on this host (unrelated,
  recorded in `.agents/tasks/2026-11-11-rules-sync-signing-task.md`).

## 6. Todos

1. [x] Worktree off `main`; plan of record written.
2. [x] Collapse the mandatory lists in `skills_selection.sh`; make every selector surface consult it.
3. [x] Delegate verify's copy; make `--skills-sync` ship mandatory packs.
4. [x] Refresh help, `llms.txt`, payload index, and the contract row.
5. [x] Update and extend `scripts/test-pqc-dist.sh`; run it plus a hermetic deploy probe.
6. [ ] Task record + COMMS/memory lines; merge to `main`; remove the worktree.
