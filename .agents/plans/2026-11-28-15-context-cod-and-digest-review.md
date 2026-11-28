---
plan_format: ainish/plan/v1
slug: context-cod-and-digest-review
date: 2026-11-28
status: done
branch: feat/context-cod-and-digest-review
worktree: /Users/nbiish/code/ainish-coder-cod-context
task_record: .agents/tasks/2026-11-28-15-context-cod-and-digest-review.md
operator: nbiish
---

# Plan: CoD Context Output Concision and Consolidates Review/Prune Tooling

## 1. Problem

`ainish-coder --context "<query>"` currently produces verbose, prose-heavy output (`~1141/1200` tokens on a typical query) where `orientation` truncates mid-branch-name before showing working tree, COMMS, federation CoD, task, or plan state; `goldfish` ignores its `token_cap` (~650 tokens across 3 prose blocks) and forces `assemble_injection` to shred `retrieval` down to a bare heading while hiding the 6 attached evidence paths; and `_load_pqc_secrets` blocks on `/dev/tty` (`Vault passphrase:`) in non-interactive shells. In addition, there is no tooling or contract to review, check off, or safely prune items from `.agents/{folder}/consolidates.*.md` digests or guarantee check-off survival across consolidation sweeps.

## 2. Anchor Facts

- Live `ainish-coder --context "how can we review, check off, and remove content from the consolidates.{date}.md docs in the .agents/{context folders}/ content"` hung on `Vault passphrase:` from `src/pqc-secrets/src/vault.rs:354` (`rpassword::prompt_password` opens `/dev/tty`), and with `AINISH_RAG_NO_PQC=1` emitted `1141/1200` tokens with `orientation` truncated mid-ref and `retrieval` trimmed to 3 lines — established by live run on 2026-11-28.
- `goldfish_review` (`src/context/engine.py:5834-5980`) checks `token_cap <= 0` then ignores `token_cap`, passing `REVIEW_MAX_TOKENS` to all 3 steps — established from `src/context/engine.py`.
- `render_orientation_section` (`src/context/engine.py:6092-6312`) lists up to 6 raw remote refs including bare `origin` and duplicate peer prefixes before `working tree`, `COMMS`, `federation`, `task`, and `plan` — established from `src/context/engine.py`.
- Existing unit tests in `src/context/tests/test_context_injection.py` assert `<CONTEXT_INJECTION>`, `Advisory evidence`, `branch:`, `working tree:`, `today's COMMS`, `newest task record`, `newest plan:`, `status:`, `todos:`, `plan branch:`, `- gate: ...`, and the degradation ladder — established from `src/context/tests/test_context_injection.py:720-1045`.
- Existing CoD style in `.agents/federation/2026-11-28.md:47-50` uses terse arrow-chained phrases (`<≤7w> -> <≤7w> -> <≤7w>`).

## 3. Plan

### Goals

- Make `ainish-coder --context` emit compact, Chain-of-Draft (CoD) structured output with full `orientation` (no premature truncation), a durable CoD `retrieval` pointer index (never shredded to an empty heading), CoD `elephant` and `goldfish` outputs that respect `token_cap`, and non-redundant envelope chrome.
- Prevent `_load_pqc_secrets` from hanging on `/dev/tty` in non-interactive shells and deduplicate candidate binaries.
- Add `ainish-context context-digest` (and `ainish-coder --context-digest`) to `--review` (read-only), `--check`, `--uncheck`, and `--prune` checked-off (`- [x] `) items from `.agents/{folder}/consolidates.*.md`, with `--dry-run`, `--json`, frontmatter audit stamps, wiki-graph refresh, and sweep survival rules.

### Non-goals

- Replacing the Elephant/Goldfish 3-step stateless review protocol (all 3 fresh `--no-session` steps remain; only their prompt density and rendered output change).
- Changing `pqc-secrets` Rust vault UX for interactive terminal unlocks.

### Constraints and invariants

- Preserve all existing contract assertions in `src/context/tests/test_context_injection.py` and `src/context/tests/test_wiki_graph.py`.
- Fail closed on `--prune`: only items explicitly marked `- [x] ` may be removed; unchecked items are never deleted.
- Keep `src/context/engine.py` stdlib-only.
- Work in a dedicated worktree off `origin/main`; never commit to `main`.

### Proposed architecture

- **PQC non-blocking export:** `_load_pqc_secrets` deduplicates candidates by resolved path and passes `start_new_session=True` on POSIX so `/dev/tty` fails fast (`ENXIO`) when locked.
- **CoD Context Envelope:**
  - `render_orientation_section`: compact `rules`/`branch`/`worktree`/`working tree`/`COMMS`/`fed`/`task`/`plan` first; deduplicated short peer branch names last (excluding bare remote names).
  - `render_retrieval_section`: emit a CoD pointer block (`- \`path:Lstart-Lend\` (score) -> <gist>`) as the first paragraph (demoting `AGENTS.md` unless the task asks about rules/contract), followed by bounded excerpts for top hits within remaining budget.
  - `elephant_brief` / `goldfish_*_brief` / `goldfish_review`: CoD bullet prompts; Step 1 comprehension runs internally and renders only a compact `drift:` line; `goldfish_review` enforces `token_cap` before returning so it never starves `retrieval`.
  - `render_injection_text`: compact 1-line advisory (`Advisory evidence only...`), deduplicated `pair:` note, deduplicated `degrade_notes`, concise section source comments.
- **Consolidates Digest Review/Check/Prune:**
  - `run_context_digest(repo_root, folder, review, check, uncheck, prune, dry_run, json_out)` operating on `.agents/{comms,memories,plans,suggestions,tasks}/consolidates.*.md`.
  - Stable item IDs `<folder>:<n>` plus substring/regex matching; `- [x] ` check-off syntax; frontmatter `last_reviewed_at` / `last_pruned_at` / `pruned_count`; `--prune` deletes only `- [x] ` bullets and recompiles wiki graph; consolidation panel prompt instructs preserving `[x]` check-offs (or dropping checked items on compaction).

### Interfaces and data

- CLI: `ainish-context context-digest [--folder <name>] [--review] [--check <ref>...] [--uncheck <ref>...] [--prune] [--dry-run] [--json]`
- CLI wrapper: `ainish-coder --context-digest [args...]`
- Format ID: `ainish-coder/context-digest/v1`

### Files and symbols

- `src/context/engine.py` — `_load_pqc_secrets`, `render_retrieval_section`, `elephant_brief`, `goldfish_comprehension_brief`, `goldfish_antagonistic_brief`, `goldfish_readiness_brief`, `goldfish_review`, `render_orientation_section`, `render_injection_text`, `run_context_digest`, consolidation brief preservation rule, argparse + dispatch.
- `bin/ainish-coder` — add `--context-digest` to `--context-*` dispatch.
- `src/context/tests/test_context_injection.py` — add unit tests for CoD formatting, orientation non-truncation, retrieval pointer preservation, goldfish cap enforcement, PQC non-TTY dedup, and `run_context_digest` review/check/uncheck/prune.
- `.agents/jobs/consolidate-record.md`, `llms.txt` — document `context-digest` workflow and CoD context prime behavior.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Dropping Goldfish Step 1 entirely | Violates EGM 3-step protocol (Step 1 comprehension drift is an input to Step 2 antagonistic review). Keeping it internal + emitting terse `drift:` preserves EGM while cutting ~160 words. |
| Allowing `--prune` by pattern without prior `--check` | Violates fail-closed safety: two-step `--check` then `--prune` prevents accidental deletion of unreviewed digest history. |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Tightening orientation/envelope text breaks existing regex/substring tests | Keep every asserted contract substring (`Advisory evidence`, `branch:`, `working tree:`, `today's COMMS`, `newest task record`, `newest plan:`, `- gate: ...`) and run full `unittest` suite. |
| Pruning removes sole on-disk copy of a fact | Fail-closed (`- [x] ` only), `--dry-run` preview, frontmatter audit count, and git history recovery documented in output. |

## 4. Clarifications

### 4.1 Scope of work
- **Question:** Proceed with (1) CoD `--context` concision + budget/orientation/retrieval/PQC fixes and (2) `consolidates.*.md` review/check-off/prune workflow?
- **Options:** 1. (Recommended) Both 1 and 2; 2. Only 1.
- **Selected:** "Proceed with 1 and 2."
- **Trade-off accepted:** Slightly larger single PR, cohesive around `.agents/` context engineering.
- **asked:** operator

## 5. Todos

- [x] **T1** Fix `_load_pqc_secrets` non-interactive TTY hang and candidate deduplication in `src/context/engine.py`.
  - from: §3 | done when: `start_new_session=True` on POSIX and deduped candidates | verify: `python3 -m unittest discover -s src/context/tests`
- [x] **T2** Make `render_orientation_section`, `render_retrieval_section`, `elephant_brief`, `goldfish_*_brief`, `goldfish_review`, and `render_injection_text` concise and CoD-structured while honoring `token_cap`.
  - from: §3 | done when: live `--context` fits CoD orientation + retrieval pointers + elephant + goldfish cleanly under budget | verify: `python3 -m unittest discover -s src/context/tests`
- [x] **T3** Implement `run_context_digest` (`--review`, `--check`, `--uncheck`, `--prune`, `--dry-run`, `--json`), wire CLI in `src/context/engine.py` and `bin/ainish-coder`, and preserve `[x]` state in consolidation sweeps.
  - from: §3 | done when: review/check/uncheck/prune work end-to-end with dry-run and fail-closed prune | verify: `python3 -m unittest discover -s src/context/tests`
- [x] **T4** Add unit tests in `src/context/tests/test_context_injection.py` and update docs (`llms.txt`, `.agents/jobs/consolidate-record.md`).
  - from: §3 | done when: all unit tests pass and DOX pass is complete | verify: `python3 -m unittest discover -s src/context/tests`
- [x] **T5** Verify live `ainish-coder --context` output (without `AINISH_RAG_NO_PQC=1`), push branch, open PR, and record closeout.
  - from: §3 | done when: PR open, live CoD output verified, COMMS/task/memory updated | verify: `gh pr view`

## 6. Verification

- `python3 -m unittest discover -s src/context/tests` — all tests pass with 0 failures and without needing `AINISH_RAG_NO_PQC=1`.
- `ainish-coder --context "how can we review, check off, and remove content from the consolidates.{date}.md docs in the .agents/{context folders}/ content"` — exits 0 without hanging on `Vault passphrase:`, emits complete orientation, CoD retrieval pointers, CoD elephant, and bounded CoD goldfish.
- `ainish-coder --context-digest --review --folder plans` — exits 0 and lists numbered digest items cleanly.

## 7. Open Decisions

- None.
