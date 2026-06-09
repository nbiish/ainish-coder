# TASK — feat/agents-rules-distribution

**Date:** 2026-06-03
**Branch:** feat/agents-rules-distribution
**Base:** main @ 51753e7

## Goal
Ensure `ainish-coder --rules` AGENTS.md distribution auto-updates on repo changes.

## Chain-of-Draft

1. Existing: symlinks at ~/.agents + ~/.config → repo AGENTS.md ✓
2. Gap: no git hooks to re-validate after pull/checkout
3. Created: scripts/hooks/agents-md-sync.sh
4. Dual-install: post-merge + post-checkout hooks
5. Updated: setup-hooks.sh integrates auto-sync hooks
6. Result: AGENTS.md changes propagate via symlink + hook re-validation

## Files Changed
- scripts/hooks/agents-md-sync.sh (new)
- scripts/setup-hooks.sh (updated)
