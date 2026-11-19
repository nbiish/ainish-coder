2026-11-17-19-context-priming-master
---
plan_format: ainish/plan/v1
slug: context-priming-master
date: 2026-11-17
status: done
branch: feat/context-priming-master
worktree: /Users/nbiish/code/context-priming-master
task_record: .agents/tasks/2026-11-17-19-context-priming-master.md
operator: question-me
---

# Plan: a per-repo self-improving context harness inside `ainish-rag --context`

## 1. Problem

Every `ainish-rag --context` call runs the same hand-tuned pipeline on every repository. The retrieval
constants (`GRAPH_MAX_WIKI_PAGES`, `GRAPH_CHAPTER_CHARS`, `GRAPH_HOP_BONUS`, the 0.55/0.45 recency
split, the section caps) were chosen by hand for *this* repository and are shipped frozen to every repo
that `ainish-coder --rules` deploys into. Nothing measures whether an assembled prime was useful, so
nothing can improve it. The operator asked for a singular context-priming master system that adapts per
repo and improves itself, seeded at `--rules` time, using the state of the art — and chose to let the
improver write real skill files and scripts, as harness² does, not just numeric knobs.

## 2. Anchor Facts

- `--context` has no learnable state: all ranking constants are module-level literals —
  `src/rag/rag.py:3489` (`CONTEXT_SECTION_CAPS`), `:3591–3594` (`GRAPH_MAX_ARTIFACTS`,
  `GRAPH_MAX_WIKI_PAGES`, `GRAPH_CHAPTER_CHARS`, `GRAPH_HOP_BONUS`), `:3857` (the `0.55 + 0.45 ×
  recency` weighting), `:3787` (`len(s