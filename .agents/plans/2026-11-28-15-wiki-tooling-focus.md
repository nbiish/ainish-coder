---
plan_format: ainish/plan/v1
slug: wiki-tooling-focus
date: 2026-11-28
status: done
branch: refactor/wiki-tooling-focus
worktree: /Users/nbiish/code/ainish-coder-wiki-focus
task_record: .agents/tasks/2026-11-28-15-wiki-tooling-focus.md
operator: nbiish
---

# Plan: Refactor `.agents/wiki/` to Focus Solely on `ainish-coder` Tooling (Exclude Scrolls)

## 1. Problem

`.agents/wiki/` pages and the `llms.txt` wiki summary currently include references to `.scrolls*`, `deploy_scrolls.sh`, `cultural/philosophical doctrine`, and `Canadian Aboriginal Syllabics`, plus stale boilerplate (`Multimodal Asset Distribution`, retired `bench` claims). Scrolls are an intentional repository easter egg/secret and must not be documented or surfaced in `.agents/wiki/` or future `--context-wiki-review` passes; the wiki should focus exclusively on `ainish-coder`'s `--rules`, `--skills*`, `--context` / `--context-digest`, `--machine-sync`, and `pqc-secrets` tooling.

## 2. Anchor Facts

- `.agents/wiki/01-architecture.md:32`, `.agents/wiki/02-codebase-connections.md:16`, `.agents/wiki/README.md:25`, and `llms.txt:227` contain scrolls / `deploy_scrolls.sh` / cultural-doctrine / syllabics references — established by direct file reads on 2026-11-28.
- `_wiki_evidence_bundle` (`src/context/engine.py:7664-7670`) enumerates `src/deploy_scrolls.sh` into the Hermes review prompt, and `_validate_wiki_page_draft` (`src/context/engine.py:7646-7648`) only checks retired RAG patterns, not scrolls exclusions — established from `src/context/engine.py`.
- `.agents/wiki/ledger.md` and `.agents/wiki/ledger.sig` are signed operator records and must never be modified; `04-improvements-and-debt.md` must keep `## 3. Operator ledger` spliced verbatim.

## 3. Plan

### Goals

- Refactor `.agents/wiki/{README,01..06}.md` to focus cleanly and accurately on `--rules`, `--skills-sync`/`--select-skills`, `--context`/`--context-digest`/`--context-consolidate`, `--machine-sync`, and `pqc-secrets`, with zero scrolls/easter-egg mentions.
- Update `src/context/engine.py` (`_wiki_evidence_bundle`, `_validate_wiki_page_draft`, `run_wiki_review`) to exclude scrolls files from wiki evidence and fail closed if any wiki draft introduces scrolls/easter-egg terms.
- Update `llms.txt` wiki index summary and add a regression unit test in `src/context/tests/test_context_injection.py`.

### Non-goals

- Modifying or deleting `.scrolls*` or `src/deploy_scrolls.sh` themselves (they remain intact in the repo as the easter egg).
- Modifying `.agents/wiki/ledger.md` or `.agents/wiki/ledger.sig`.

### Constraints and invariants

- Preserve Obsidian frontmatter (`ainish/wiki/*` tags, `up: "[[README]]"`), `[[wikilinks]]`, and verbatim `ledger.md` splice in `04-improvements-and-debt.md`.
- Keep all edits on branch `refactor/wiki-tooling-focus` in `/Users/nbiish/code/ainish-coder-wiki-focus`.

### Files and symbols

- `.agents/wiki/{README,01-architecture,02-codebase-connections,03-security-and-governance,04-improvements-and-debt,05-research-and-intelligence,06-marketing-and-positioning}.md`
- `src/context/engine.py` — `_WIKI_EXCLUDED_PATTERNS`, `_validate_wiki_page_draft`, `_wiki_evidence_bundle`, `run_wiki_review`.
- `llms.txt` — line 227 `05-research-and-intelligence.md` description.
- `src/context/tests/test_context_injection.py` — test scrolls exclusion in `run_wiki_review` and live `.agents/wiki/` hygiene.

## 4. Clarifications

### 4.1 Wiki focus
- **Question:** Scope of `.agents/wiki/` refactor.
- **Selected:** Operator instructed: "refactor the `.agents/wiki/` so that it's solely focused on the `ainish-coder --rules/skills/context` tooling and not the scrolls (which is supposed to be an easter egg/secret for the codebase and repo and not the focus of our `.agents/wiki/{context files}`".
- **asked:** operator

## 5. Todos

- [x] **T1** Refactor `.agents/wiki/{README,01..06}.md` to focus strictly on `--rules`/`--skills`/`--context`/`--context-digest`/`--machine-sync`/`pqc-secrets`, preserving `ledger.md` verbatim and removing all scrolls/easter-egg references.
  - from: §3 | done when: zero scrolls/syllabics/8thfire/ghost-layer hits in `.agents/wiki/` | verify: `grep -rn -i "scroll\|syllabic\|8thfire\|ghost.layer" .agents/wiki/`
- [x] **T2** Add fail-closed scrolls exclusion to `_wiki_evidence_bundle`, `_validate_wiki_page_draft`, and `run_wiki_review` in `src/context/engine.py` and update `llms.txt`.
  - from: §3 | done when: wiki reviewer strips scrolls entrypoints and rejects drafts mentioning scrolls | verify: `python3 -m unittest src/context/tests/test_context_injection.py`
- [x] **T3** Add unit test verifying scrolls exclusion and wiki hygiene, verify live `ainish-coder --context`, push branch, and open PR.
  - from: §3 | done when: tests pass, live `--context` succeeds, PR open | verify: `gh pr view`

## 6. Verification

- `grep -rn -i "scroll\|syllabic\|8thfire\|ghost.layer" .agents/wiki/` — 0 matches.
- `python3 -m unittest src/context/tests/test_context_injection.py src/context/tests/test_wiki_graph.py` — 100% OK.
- Live `./bin/ainish-coder --context "how do --rules, --skills-sync, and --context-digest work together"` — exit 0, CoD output grounded in refactored wiki.

## 7. Open Decisions

- None.
