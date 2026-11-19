2026-11-18-10-wiki-pseudo-skills
---
plan_format: ainish/plan/v1
slug: wiki-pseudo-skills
date: 2026-11-18
status: done
branch: feat/wiki-pseudo-skills
worktree: /Users/nbiish/code/wiki-pseudo-skills
task_record: .agents/tasks/2026-11-18-10-wiki-pseudo-skills.md
operator: direct-instruction
---

# Plan: wiki markdown as pseudo-skills, over the whole `.agents` corpus

## 1. Problem

The context system reads a small sample of what this repository knows. Measured: `.agents/` holds **115
files** and only **10** are indexed (the newest two per coordination folder), the 25 research files are
not indexed at all, and the wiki is capped at its newest 8 pages. So an agent asking about work from last
week, or about the research this system is built on, gets nothing — and the learning loop cannot help,
because the material it would learn from is not in the corpus.

The operator's direction: the learned, continuously-improving skills should live **in the wiki as markdown
pseudo-skills**, abstracted from the four research sources (Harness², the paper, both videos), so the wiki
is both the corpus the prime reads *and* the place improvement accumulates.

## 2. Anchor Facts

- `.agents/` census: comms 17, memories 19, plans 24, suggestions 14, tasks 41, wiki 11, templates 5,
  skills 32 files. `research/` holds 30 tracked files.
- Indexed today: **52 nodes** total — `wiki` 21, `map` 1, `contract` 20, and 2 per coordination fol