#!/usr/bin/env bash
# Interactive provider picker for ainish-coder wrappers.
# Source this file, then call:
#   is_interactive          — returns 0 if terminal is interactive and not forced off
#   picker_select <tool>    — shows picker (fzf or numbered), sets _PICKER_RESULT
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/providers.sh"

# ── Public: is_interactive ────────────────────────────────────────────────────
# Returns 0 if we should show interactive UI, 1 otherwise.
is_interactive() {
  [[ "${AINISH_NON_INTERACTIVE:-false}" != "true" ]] && [[ -t 0 ]] && [[ -t 1 ]]
}

# ── Internal helpers ──────────────────────────────────────────────────────────

# Find fzf binary. Echoes path or returns 1.
_fzf_bin() {
  for cand in /opt/homebrew/bin/fzf /usr/local/bin/fzf; do
    if [[ -x "$cand" ]]; then
      echo "$cand"
      return 0
    fi
  done
  local found
  found="$(command -v fzf 2>/dev/null || true)"
  if [[ -n "$found" && -x "$found" ]]; then
    echo "$found"
    return 0
  fi
  return 1
}

# Write compatible providers to stdout, one per line:  provider|model
_compat_list() {
  local tool="${1:?tool required}"
  python3 -c "
import json, sys
try:
    with open('${PROVIDERS_FILE}') as f:
        data = json.load(f)
    items = []
    for name, cfg in sorted(data.items()):
        if cfg.get('tools', {}).get('${tool}', False):
            model = cfg.get('defaultModel', '?')
            items.append(f'{name}|{model}')
    for item in items:
        print(item)
except Exception:
    pass
"
}

# ── fzf picker ────────────────────────────────────────────────────────────────
# Returns 0 and sets _PICKER_RESULT on selection, 1 on cancel, 2 if fzf unavailable.

_fzf_select() {
  local tool="$1"
  local fzf_bin
  fzf_bin="$(_fzf_bin 2>/dev/null || true)"
  [[ -n "$fzf_bin" ]] || return 2

  local input
  input="$(_compat_list "$tool")"
  [[ -n "$input" ]] || return 1

  local count
  count="$(echo "$input" | wc -l | tr -d ' ')"

  # Single provider: auto-select
  if [[ "$count" -eq 1 ]]; then
    _PICKER_RESULT="${input%%|*}"
    return 0
  fi

  # Pipe through fzf. Read from /dev/tty so it can draw the TUI.
  # Capture output via temp file to avoid subshell terminal loss.
  local tmpfile
  tmpfile="$(mktemp /tmp/ainish-picker.XXXXXX)"
  local fzf_rc=0

  # Format: left-align provider name, right-align model
  echo "$input" | while IFS='|' read -r prov model; do
    printf "%-18s %s\n" "$prov" "$model"
  done | "$fzf_bin" \
    --header="Select provider for ${tool}" \
    --height=~40% \
    --layout=reverse \
    --border \
    --select-1 \
    --exit-0 \
    --prompt="▸ " \
    < /dev/tty > "$tmpfile" 2>/dev/null || fzf_rc=$?

  if [[ -s "$tmpfile" ]]; then
    local selected
    selected="$(head -1 "$tmpfile" | awk '{print $1}')"
    rm -f "$tmpfile"
    if [[ -n "$selected" ]]; then
      _PICKER_RESULT="$selected"
      return 0
    fi
  fi
  rm -f "$tmpfile"
  return 1
}

# ── Numbered-list picker (fallback) ────────────────────────────────────────────

_numbered_select() {
  local tool="$1"

  local input
  input="$(_compat_list "$tool")"
  [[ -n "$input" ]] || return 1

  local count
  count="$(echo "$input" | wc -l | tr -d ' ')"

  # Single provider: auto-select
  if [[ "$count" -eq 1 ]]; then
    _PICKER_RESULT="${input%%|*}"
    return 0
  fi

  # Build parallel arrays (bash 3.2 compat — no associative arrays)
  local providers=() models=()
  local old_ifs="$IFS"
  IFS=$'\n'
  for line in $input; do
    providers+=("${line%%|*}")
    models+=("${line#*|}")
  done
  IFS="$old_ifs"

  # Display menu to stderr so caller can capture function output
  (
    echo ""
    echo -e "\033[1;36mSelect provider for ${tool}:\033[0m"
    echo ""
    local i=1
    for prov in "${providers[@]}"; do
      local model="${models[$((i-1))]}"
      printf "  \033[1;37m%2d\033[0m) %-18s \033[0;36m%s\033[0m\n" "$i" "$prov" "$model"
      ((i++))
    done
    echo ""
  ) >&2

  while true; do
    printf "\033[1;33m▸ \033[0m" >&2
    printf "Choice [1-%d, q=quit]: " "$count" >&2
    local choice
    IFS= read -r choice </dev/tty || { echo "" >&2; return 1; }

    # Trim whitespace
    choice="$(printf '%s' "$choice" | tr -d '[:space:]')"

    if [[ -z "$choice" ]]; then
      continue
    fi

    local lower
    lower="$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lower" == "q" ]]; then
      echo "" >&2
      return 1
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
      _PICKER_RESULT="${providers[$((choice-1))]}"
      return 0
    fi

    printf "  \033[1;33mPlease enter 1-%d or 'q'.\033[0m\n" "$count" >&2
  done
}

# ── Public: picker_select ─────────────────────────────────────────────────────
# Usage: picker_select <tool>
#   tool = "pi" or "mini"
# Returns 0 and sets _PICKER_RESULT on selection.
# Returns 1 if cancelled or no compatible providers.

_PICKER_RESULT=""

picker_select() {
  local tool="${1:?tool required}"
  _PICKER_RESULT=""

  # Try fzf first
  local fzf_rc=0
  _fzf_select "$tool" || fzf_rc=$?

  if [[ "$fzf_rc" -eq 0 ]]; then
    return 0
  elif [[ "$fzf_rc" -eq 1 ]]; then
    # fzf cancelled by user — don't fall back to numbered
    return 1
  fi

  # fzf unavailable (rc=2) — fall back to numbered list
  _numbered_select "$tool"
}
