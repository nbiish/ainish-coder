# Split the distributable skill payload from this repo's readable packs

- **status:** done
- **branch:** `refactor/skills-distribute-source`
- **scope:** `skills-to-distribute/skills/` (new payload), `.agents/skills/` (curated subset),
  `src/paths.sh`, `src/deploy_skills.sh`, `src/skills_selection.sh`, `src/verify_skills.sh`,
  `src/deploy_rules_sync.sh`, `src/pqc_dist.sh`, `src/deploy_scrolls.sh`, `src/deploy_unlock.sh`,
  `bin/ainish-coder`, `bin/pqc-secrets`, `src/rag/{rag.py,src/main.rs,src/decision.rs,master-surfaces.json}`,
  `scripts/test-pqc-dist.sh`, `README.md`, `llms.txt`, `.agents/llms.txt`, `src/help.sh`
- **objective:** `ainish-coder --rules` / `--skills` / `--skills-sync` / `--scrolls` / `--unlock`
  must resolve every skill from one distributor tree, so this repository can carry only the packs
  its own agents read instead of all 20+ as standing prompt surface.

## What was found

1. **The payload was in the context path.** All 22 packs lived in `.agents/skills/`, the exact
   directory agent harnesses auto-discover (`**/.agents/skills`). Every session in this repo paid the
   full skill corpus as context, whether or not the task touched it — the reported context rot.
2. **Distribution and consumption shared one path.** ~30 sites across nine scripts hardcoded
   `${REPO_DIR}/.agents/skills` for the SOURCE. Moving the tree without a single resolver would have
   broken deploy, select, verify, sync, pqc, scrolls, and unlock independently.
3. **`_PQC_ENGINE_REL` was overloaded.** One constant resolved both the engine in this checkout and the
   vendored engine in a consumer repo. Those are different paths once the payload moves, and the
   target-side checks would have silently inspected a directory that only exists downstream.

## What changed

- `src/paths.sh` defines the two sides once: `AINISH_SKILLS_SOURCE_REL`
  (`skills-to-distribute/skills`) and `AINISH_SKILLS_TARGET_REL` (`.agents/skills`), plus
  `ainish_skills_source_root` / `ainish_skills_target_root`. Every other module calls them.
- `.agents/skills/` keeps only the packs this repo's agents actually read: `ainish-security`,
  `pqc-secrets`, `question-me`, `security-first-agent`. The contract links only at deployed paths, so
  those links stay target-correct while the packs stay readable here.
- `pqc_dist.sh` splits `_PQC_PACK_REL_SOURCE` / `_PQC_PACK_REL_TARGET` and keeps a legacy fallback so
  launchers installed by an older release still resolve their engine.
- The RAG engine treats `skills-to-distribute/` as contract surface, and `decision.rs` probes both
  layouts when locating the pqc engine (a consumer repo only ever has the vendored one).

## Verification

- `bash scripts/test-pqc-dist.sh` → **183/183 assertions** (was 167 pass / 17 fail before the work,
  and the `jget` helper was silently reading nothing on macOS — see below).
- End-to-end `--rules --headless` into a clean repo: 19 packs + `skills/llms.txt` + `AGENTS.md` +
  `llms.txt` deployed; second run idempotent; `--skills-verify` reports `identical=19 mismatch=0`.
  `--skills-list` enumerates all 20 deployable packs from the payload.
- `cargo check` + `cargo test --bin ainish-rag` → 57/57 pass.
- `diff -r` proves `skills-to-distribute/skills/` is byte-identical to what `HEAD` had at
  `.agents/skills/`, and the four local packs are byte-identical to their payload counterparts.

## Gate bugs fixed while verifying

1. **`jget` verified nothing on macOS.** It used `\(true\|false\)` in a basic regex; BSD sed does not
   support `\|`, so every boolean/scalar assertion read as empty. Several `--pqc-install` / `--pqc-sync`
   checks were failing on a *correct* CLI. Switched to `sed -E`.
2. **The suite sourced `skills_selection.sh` without `paths.sh`.** The new resolvers were unbound
   functions in a standalone run; `paths.sh` is now sourced first.
3. **One assertion pinned a single phrasing** of the degradation rule. Relaxed to the behaviour, so a
   future rewrite inside the 120-line contract budget does not read as a regression.

## Remaining

- `AGENTS.md` was intentionally left untouched: it is deployed verbatim and its three
  `.agents/skills/...` links are correct in every consumer repo, which is where the packs land.
  `.agents/llms.txt` now carries the local map instead.
- Consumer repos enrolled before this change keep working (legacy engine fallback), but their
  `.agents/skills/` still holds every previously selected pack. That is their selection, not this
  repo's context, and is unchanged by design.
