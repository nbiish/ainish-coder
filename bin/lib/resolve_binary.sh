#!/usr/bin/env bash
# Resolve the real upstream CLI binary, skipping this repo's wrapper scripts.
# Usage: resolve_real_binary <tool_name> <path_to_wrapper_script>
set -euo pipefail

_is_ainish_wrapper() {
  local candidate="${1:?}"
  [[ -f "$candidate" ]] || return 1
  grep -q 'provider-switching wrapper' "$candidate" 2>/dev/null
}

resolve_real_binary() {
  local tool="${1:?tool name required (pi|mini)}"
  local wrapper_script="${2:?wrapper script path required}"
  local wrapper_dir
  wrapper_dir="$(cd "$(dirname "$wrapper_script")" && pwd)"

  local line bin
  while IFS= read -r line; do
    [[ "$line" == *" is "* ]] || continue
    bin="${line#* is }"
    [[ -x "$bin" ]] || continue
    _is_ainish_wrapper "$bin" && continue
    echo "$bin"
    return 0
  done < <(type -a "$tool" 2>/dev/null || true)

  local old_path="$PATH" entry
  PATH=""
  local IFS=:
  for entry in $old_path; do
    [[ -z "$entry" ]] && continue
    [[ "$(cd "$entry" 2>/dev/null && pwd -P 2>/dev/null || echo "$entry")" == "$(cd "$wrapper_dir" && pwd -P)" ]] && continue
    PATH="${PATH:+$PATH:}$entry"
  done
  bin="$(command -v "$tool" 2>/dev/null || true)"
  PATH="$old_path"
  if [[ -n "$bin" ]] && ! _is_ainish_wrapper "$bin"; then
    echo "$bin"
    return 0
  fi

  local candidate
  for candidate in \
    "${HOME}/.local/bin/${tool}" \
    "${HOME}/.cargo/bin/${tool}"; do
    if [[ -x "$candidate" ]] && ! _is_ainish_wrapper "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done

  if [[ -d "${HOME}/.local/share/uv/tools" ]]; then
    for candidate in "${HOME}/.local/share/uv/tools/"*/bin/"${tool}"; do
      [[ -x "$candidate" ]] || continue
      _is_ainish_wrapper "$candidate" && continue
      echo "$candidate"
      return 0
    done
  fi

  echo "error: real ${tool} binary not found (skipped ainish wrappers under ${wrapper_dir})" >&2
  echo "hint: install with 'uv tool install mini-swe-agent' or 'uv tool install pi-coding-agent'" >&2
  return 1
}
