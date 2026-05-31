#!/usr/bin/env bash
# mini-swe-agent env hot-swap (rename .env / .env-<provider> only).
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/mini_env_swap.sh"

_AINISH_SWAPPED_TOOLS=()

_ainish_restore_all() {
  prepend_restore_all
  _AINISH_SWAPPED_TOOLS=()
}

_ainish_ensure_trap() {
  _ainish_prepend_ensure_trap
}

hot_swap_mini() {
  prepend_activate "$1"
  _AINISH_SWAPPED_TOOLS+=(mini)
}
