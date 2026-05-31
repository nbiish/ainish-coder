#!/usr/bin/env bash
# Build ultra-concise orchestration metadata for auto thinking classification.
# Output: single-line key=value envelope (no secrets). Safe to prepend to user turns.
#
# Usage:
#   source bin/lib/auto_thinking_context.sh
#   auto_thinking_context_line "fix the auth bug"
#   auto_thinking_context_block "fix the auth bug"   # multi-line for classify script
set -euo pipefail

auto_thinking__task_slug() {
  local task_file=""
  task_file="$(ls -t .agents/tasks/TASK.*.md 2>/dev/null | head -1 || true)"
  if [[ -n "$task_file" ]]; then
    basename "$task_file" .md | sed 's/^TASK\.//'
  else
    echo "none"
  fi
}

auto_thinking__branch() {
  git branch --show-current 2>/dev/null || echo "unknown"
}

auto_thinking__stage() {
  # stage: plan | implement | review | debug | commit | unknown
  local s="${AINISH_STAGE:-}"
  if [[ -n "$s" ]]; then
    echo "$s"
    return
  fi
  if [[ -n "${AINISH_INFERENCE_KIND:-}" ]]; then
    echo "${AINISH_INFERENCE_KIND}"
    return
  fi
  echo "implement"
}

auto_thinking_context_line() {
  local user_prompt="${1:-}"
  local attempt="${AINISH_ATTEMPT:-1}"
  local inference="${AINISH_INFERENCE_CALL:-main}"
  local actions="${AINISH_ACTIONS:-}"
  local task
  task="$(auto_thinking__task_slug)"
  local branch stage
  branch="$(auto_thinking__branch)"
  stage="$(auto_thinking__stage)"
  # Truncate prompt preview for classifier token budget
  local preview="${user_prompt:0:200}"
  preview="${preview//$'\n'/ }"
  printf 'task=%s stage=%s branch=%s attempt=%s inference=%s actions=%s preview=%q' \
    "$task" "$stage" "$branch" "$attempt" "$inference" "$actions" "$preview"
}

auto_thinking_context_block() {
  local user_prompt="${1:-}"
  cat <<EOF
<ainish-auto-ctx $(auto_thinking_context_line "$user_prompt") />
EOF
  if [[ -n "$user_prompt" ]]; then
    printf '%s\n' "$user_prompt"
  fi
}
