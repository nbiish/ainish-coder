#!/usr/bin/env bash
# Shared cmd-tracker integration for ainish-coder wrappers.
# Source this file, then call:
#   run_with_tracker <tool> <subcommand> <provider> -- <command...>
#
# If cmd-tracker is on PATH and AINISH_NO_TRACKING is not "true",
# the command is wrapped so invocations are logged to ~/.cache/ainish-coder/usage.csv.
# Otherwise the command runs directly with zero overhead.
set -euo pipefail

# Resolve the cmd-tracker binary. Echoes path or empty string.
_tracker_bin() {
  local found
  found="$(command -v cmd-tracker 2>/dev/null || true)"
  if [[ -n "$found" && -x "$found" ]]; then
    echo "$found"
  else
    echo ""
  fi
}

# Usage: run_with_tracker <tool> <subcommand> <provider> -- <command...>
#   tool       = "pi" | "mini" | "ainish-coder"
#   subcommand = "--skills" | "--rules" | "" | skill name | etc.
#   provider   = provider name or "" if none
# Everything after "--" is the command + args to execute.
#
# Returns the command's exit code.
run_with_tracker() {
  local tracker
  tracker="$(_tracker_bin)"

  if [[ -z "$tracker" ]] || [[ "${AINISH_NO_TRACKING:-false}" == "true" ]]; then
    # No tracker available or tracking disabled — shift past our args and run directly
    while [[ $# -gt 0 && "$1" != "--" ]]; do
      shift
    done
    if [[ $# -gt 0 && "$1" == "--" ]]; then
      shift
    fi
    "$@"
    return $?
  fi

  local tool="$1"
  local subcommand="$2"
  local provider="$3"

  # Validate separator
  if [[ "${4:-}" != "--" ]]; then
    # No separator — shift past metadata and run directly
    shift 3
    "$@"
    return $?
  fi

  shift 4  # past tool, subcommand, provider, and "--"

  "$tracker" "$tool" "$subcommand" "$provider" -- "$@"
  return $?
}
