#!/bin/sh
# Emit a bounded orientation packet for a project/task.
set -eu

task=""
mode="elephant"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --task)
      [ "$#" -ge 2 ] || { echo "error: --task requires text" >&2; exit 2; }
      task=$2
      shift 2
      ;;
    --mode)
      [ "$#" -ge 2 ] || { echo "error: --mode requires elephant|goldfish|build" >&2; exit 2; }
      mode=$2
      case "$mode" in elephant|goldfish|build) ;; *) echo "error: invalid --mode: $mode" >&2; exit 2 ;; esac
      shift 2
      ;;
    --help|-h)
      printf '%s\n' 'Usage: bin/context-packet.sh --task "request"'
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      exit 2
      ;;
  esac
done

[ -n "$task" ] || { echo 'error: --task is required' >&2; exit 2; }

echo '=== CONTEXT PACKET ==='
printf 'request: %s\n' "$task"
printf 'mode: %s\n' "$mode"
if [ "$mode" = "goldfish" ]; then
  echo 'policy: stateless review; only explicit design references are allowed'
  echo '--- goldfish_boundary ---'
  echo 'memory: excluded'
  echo 'comms: excluded'
  echo 'implementation: excluded'
  echo 'provide_design_path_and_explicit_references_to_reviewer'
  echo '=== END CONTEXT PACKET ==='
  exit 0
fi

printf 'branch: %s\n' "$(git branch --show-current 2>/dev/null || printf '?')"
printf 'worktree: %s\n' "$(git rev-parse --show-toplevel 2>/dev/null || printf '?')"
printf 'status_count: %s\n' "$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

echo '--- changed_files ---'
git status --short 2>/dev/null | head -40 || true

echo '--- task_state ---'
found=0
for file in $(ls -1 .agents/tasks/*-task.md .agents/tasks/TASK.*.md 2>/dev/null | sort | tail -3); do
  [ -f "$file" ] || continue
  found=1
  printf '%s: ' "$file"
  grep -E '^- (status|lane|objective|scope):' "$file" 2>/dev/null | head -4 | tr '\n' ';' || true
  printf '\n'
done
[ "$found" -eq 1 ] || echo 'none'

echo '--- master_suggestions ---'
suggestions=$(ls -1 .agents/suggestions/*-suggestions.txt 2>/dev/null | sort | tail -1 || true)
if [ -n "$suggestions" ] && [ -f "$suggestions" ]; then
  printf 'source: %s\n' "$suggestions"
  echo 'advisory_only: true'
  echo 'tail:'
  tail -20 "$suggestions"
else
  echo 'source: none'
  echo 'advisory_only: true'
fi

echo '--- recent_memory ---'
memory=$(ls -1 .agents/memories/*-memory.txt 2>/dev/null | sort | tail -1 || true)
if [ -n "$memory" ]; then
  printf '%s\n' "$memory"
  grep '^- ' "$memory" 2>/dev/null | tail -5 || true
else
  echo 'none'
fi

echo '--- route ---'
if command -v ainish-rag >/dev/null 2>&1; then
  if command -v timeout >/dev/null 2>&1; then
    route_output=$(timeout 20s ainish-rag route "$task" --json 2>/dev/null) || route_output='route_unavailable'
  else
    route_output='route_unavailable:no_timeout_command'
  fi
  printf '%s\n' "$route_output" | sed -n '1,80p'
else
  echo 'ainish-rag unavailable'
fi

echo '=== END CONTEXT PACKET ==='
