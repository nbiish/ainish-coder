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
uncommitted_count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [ "${uncommitted_count}" -gt 50 ]; then
  echo ''
  echo "  [ORIENT:HIGH_DIVERGENCE] ${uncommitted_count} modified/untracked files detected (>50 threshold)."
  echo "  Vector index drift probable: auto-trigger recommended -> 'ainish-coder --rag index'"
fi

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

# ── AGENT COMMS (daily team ledger) ──
echo ''
echo '--- COMMS ---'
today=$(date +%Y-%m-%d)
# Daily ledger: .agents/comms/{date}-team.txt (one file per UTC date; latest date = active).
# Legacy fallback: AGENTS/{date}.COMMS.md (pre-migration targets).
ledger=""
if [ -d ".agents/comms" ]; then
  ledger=$(ls -1 .agents/comms/*-team.txt 2>/dev/null | sort | tail -1)
fi
if [ -z "${ledger}" ] && [ -f "AGENTS/${today}.COMMS.md" ]; then
  ledger="AGENTS/${today}.COMMS.md"
fi
if [ -n "${ledger}" ] && [ -f "${ledger}" ]; then
  lines=$(wc -l < "${ledger}" | tr -d ' ')
  echo "  ${ledger} (${lines}L)"
  # Latest entries: one line each (event + agent + branch + status), last 6
  grep '^### \[2' "${ledger}" 2>/dev/null | tail -6 | sed 's/^### \[/  /; s/\] /  /; s/ | wt:.*//'
  # Status of the newest entry (first '- status:' after its last '### [' line)
  last_ts=$(grep '^### \[2' "${ledger}" 2>/dev/null | tail -1 | sed 's/^### \[//; s/\].*//')
  [ -n "${last_ts}" ] && awk -v ts="${last_ts}" 'index($0, ts){f=1} f && /^- status:/{print "    " $0; exit}' "${ledger}"
fi

echo ''
echo '--- TASKS ---'
found=0
for f in .agents/tasks/*-task.md .agents/tasks/TASK.*.md; do
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

echo ''
echo '--- SUGGESTIONS ---'
found_sugg=0
for f in .agents/suggestions/*-suggestions.txt .agents/suggestions/*-suggestions.md; do
  [ -f "${f}" ] || continue
  found_sugg=1
  lines=$(wc -l < "${f}" | tr -d ' ')
  echo "  $(basename "${f}") (${lines}L)"
  grep -E '^###|^<|Next step:' "${f}" 2>/dev/null | tail -4 | sed 's/^/    /'
done
if [ "${found_sugg}" -eq 0 ]; then
  echo "  none"
fi

# ── REPO MEMORY (.agents/memories/{date}-memory.txt) ──
echo ''
echo '--- MEMORY ---'
mem_latest=$(ls -1 .agents/memories/*-memory.txt 2>/dev/null | sort | tail -1)
if [ -n "${mem_latest}" ]; then
  mem_lines=$(wc -l < "${mem_latest}" | tr -d ' ')
  echo "  $(basename "${mem_latest}") (${mem_lines}L)"
  grep '^- ' "${mem_latest}" 2>/dev/null | tail -4 | sed 's/^/    /'
elif [ -f .agents/memories/MEMORY.md ]; then
  # legacy digest (pre-dated-file targets)
  echo "  MEMORY.md (legacy)"
  grep '^- \[.*\] \[ACTIVE\]' .agents/memories/MEMORY.md 2>/dev/null | head -4 | sed 's/^/    /'
else
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

# ── RAG & WIKI INTELLIGENCE ──
if [ -d .agents/rag ] || [ -d .agents/wiki ]; then
  echo ''
  echo '--- RAG & WIKI INTELLIGENCE ---'
  if [ -d .agents/wiki ]; then
    wiki_count=$(find .agents/wiki -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    echo "  wiki pages:     ${wiki_count}"
  fi
  if [ -f .agents/rag/drift-monitor.json ]; then
    status=$(grep -o '"status": *"[^"]*"' .agents/rag/drift-monitor.json 2>/dev/null | cut -d'"' -f4 || echo "UNKNOWN")
    recall=$(grep -o '"recall_at_3": *[0-9.]*' .agents/rag/drift-monitor.json 2>/dev/null | awk '{print $2}' || echo "N/A")
    advisory=$(grep -o '"advisory": *"[^"]*"' .agents/rag/drift-monitor.json 2>/dev/null | cut -d'"' -f4 || echo "")
    echo "  rag status:     ${status} (recall@3: ${recall})"
    if [ -n "${advisory}" ] && [ "${advisory}" != "null" ]; then
      echo "  [ADVISORY]      ${advisory}"
    fi
  elif [ -d .agents/rag/lancedb ]; then
    echo "  rag status:     initialized (run 'ainish-rag monitor' to evaluate drift)"
  fi
  if [ -d .agents/audit ]; then
    receipt_count=$(find .agents/audit -maxdepth 1 -name '*-index-receipt.json' 2>/dev/null | wc -l | tr -d ' ')
    echo "  audit receipts: ${receipt_count} (FIPS 204 ML-DSA-65 signed)"
  fi
fi

echo ''
echo '=== END ==='

