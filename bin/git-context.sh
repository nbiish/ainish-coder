#!/bin/sh
# git-context.sh — AI agent context dump for any git repository
# Invoked by: git context  (alias in ~/.gitconfig)
# Purpose: One-command situational awareness for AI coding agents.
#          Structured, token-efficient, actionable.

set -e

echo '=== GIT CONTEXT ==='
echo ''

# ── HEADER: branch, worktree, relationship ──
branch=$(git branch --show-current 2>/dev/null || echo '?')
toplevel=$(git rev-parse --show-toplevel 2>/dev/null || echo '?')
echo "branch:    ${branch}"
echo "worktree:  $(basename "${toplevel}")"

ahead_main=$(git rev-list --count main..HEAD 2>/dev/null || echo '?')
behind_main=$(git rev-list --count HEAD..main 2>/dev/null || echo '?')
echo "vs main:   +${ahead_main}/-${behind_main}"

ahead_dev=$(git rev-list --count dev..HEAD 2>/dev/null || echo '')
behind_dev=$(git rev-list --count HEAD..dev 2>/dev/null || echo '')
if [ -n "${ahead_dev}" ] && [ "${ahead_dev}" != '?' ]; then
  echo "vs dev:    +${ahead_dev}/-${behind_dev}"
fi

# ── STATUS ──
echo ''
echo '--- STATUS ---'
git status --short

# ── UNSTAGED DIFF ──
if ! git diff --quiet 2>/dev/null; then
  echo ''
  echo '--- UNSTAGED DIFF ---'
  git diff --stat
  echo ''
  git diff
fi

# ── STAGED ──
if ! git diff --cached --quiet 2>/dev/null; then
  echo ''
  echo '--- STAGED ---'
  git diff --cached --stat
fi

# ── TASK FILES (ainish-coder repos) ──
echo ''
echo '--- TASKS ---'
found=0
for f in .agents/tasks/TASK.*.md; do
  [ -f "${f}" ] || continue
  found=1
  lines=$(wc -l < "${f}" | tr -d ' ')
  echo "  $(basename "${f}") (${lines}L)"
  # Show first 3 non-blank, non-comment lines as task gist
  grep -v '^$\|^#' "${f}" 2>/dev/null | head -3 | sed 's/^/    /'
done
if [ "${found}" -eq 0 ]; then
  echo "  none"
fi

# ── PRD (llms.txt) ──
echo ''
echo '--- PRD ---'
if [ -f llms.txt ]; then
  ver=$(grep 'Version:' llms.txt 2>/dev/null | head -1 | grep -o '[0-9.]*' | head -1)
  lines=$(wc -l < llms.txt | tr -d ' ')
  echo "  llms.txt v${ver:-?} (${lines}L)"
else
  echo "  no llms.txt"
fi

# ── WORKTREES ──
echo ''
echo '--- WORKTREES ---'
git worktree list 2>/dev/null || echo "  (not available)"

# ── STASHES ──
count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
if [ "${count}" -gt 0 ]; then
  echo ''
  echo "--- STASHES (${count}) ---"
  git stash list
fi

# ── TIMELINE ──
echo ''
echo '--- TIMELINE (14) ---'
git --no-pager log -n 14 --oneline --decorate --graph --all

# ── LAST COMMIT ──
echo ''
echo '--- LAST COMMIT ---'
git --no-pager log -n 1 --stat --decorate

# ── GATE TOOLS ──
echo ''
echo '--- GATES ---'
for tool in ruff bandit gitleaks pqc-secrets; do
  if command -v "${tool}" >/dev/null 2>&1; then
    echo "  ${tool}: available"
  else
    echo "  ${tool}: missing"
  fi
done

# ── EXTRA CONTEXT (ainish-coder repos) ──
if [ -f llms.txt ]; then
  echo ''
  echo '--- AGENTS ---'
  if [ -d .agents/skills ]; then
    count_skills=$(find .agents/skills -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
    echo "  skills: ${count_skills} packs"
  fi
  if [ -f AGENTS.md ]; then
    echo "  AGENTS.md: present"
  fi
fi

echo ''
echo '=== END ==='
