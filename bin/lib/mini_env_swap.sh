#!/usr/bin/env bash
# mini-swe-agent provider swap: rename .env <-> .env-<provider> only (no content edits).
#
# Layout (~/.config/mini-swe-agent/):
#   .env              active config (one provider at a time)
#   .env-zenmux       parked zenmux config
#   .env-openrouter   parked openrouter config
#   .env-*            any future provider
#
# State (~/.cache/ainish-coder/):
#   mini-env-active-provider   current provider name (e.g. zenmux)
#   mini-env-providers.list    discovered .env-* names (refreshed each swap)
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=providers.sh
source "${LIB_DIR}/providers.sh"

MINI_ENV_DIR="${AINISH_MINI_ENV_DIR:-${HOME}/.config/mini-swe-agent}"
MINI_ENV_ACTIVE="${MINI_ENV_DIR}/.env"
MINI_ENV_STATE_DIR="${AINISH_PREPEND_STATE:-${HOME}/.cache/ainish-coder}"
MINI_ENV_ACTIVE_PROVIDER_FILE="${MINI_ENV_STATE_DIR}/mini-env-active-provider"
MINI_ENV_PROVIDERS_LIST="${MINI_ENV_STATE_DIR}/mini-env-providers.list"
MINI_ENV_SESSION_PREVIOUS_FILE="${MINI_ENV_STATE_DIR}/mini-env-session-previous"

_mini_env_ensure_dir() {
  mkdir -p "${MINI_ENV_DIR}" "${MINI_ENV_STATE_DIR}"
}

# ─── Provider list (from disk + providers.json) ─────────────────────────────

mini_env_variant_path() {
  local provider="${1:?}"
  echo "${MINI_ENV_DIR}/.env-${provider}"
}

# Discover provider names from .env-* files in the config directory.
mini_env_discover_from_disk() {
  local base prov
  _mini_env_ensure_dir
  [[ -d "${MINI_ENV_DIR}" ]] || return 0
  for base in "${MINI_ENV_DIR}"/.env-*; do
    [[ -f "$base" ]] || continue
    prov="$(basename "$base")"
    prov="${prov#.env-}"
    [[ -n "$prov" ]] && echo "$prov"
  done | sort -u
}

# Providers marked for mini in providers.json.
mini_env_discover_from_json() {
  [[ -f "${PROVIDERS_FILE}" ]] || return 0
  python3 -c "
import json
with open('${PROVIDERS_FILE}') as f:
    data = json.load(f)
for name, cfg in sorted(data.items()):
    if cfg.get('tools', {}).get('mini', False):
        print(name)
" 2>/dev/null || true
}

# Merge disk + JSON, write mini-env-providers.list, print to stdout.
mini_env_refresh_provider_list() {
  local merged="" p
  _mini_env_ensure_dir
  {
    mini_env_discover_from_disk
    mini_env_discover_from_json
    mini_env_read_active_provider
  } | grep -v '^$' | sort -u > "${MINI_ENV_PROVIDERS_LIST}.tmp"
  mv "${MINI_ENV_PROVIDERS_LIST}.tmp" "${MINI_ENV_PROVIDERS_LIST}"
  cat "${MINI_ENV_PROVIDERS_LIST}"
}

mini_env_list_providers() {
  if [[ -f "${MINI_ENV_PROVIDERS_LIST}" ]]; then
    cat "${MINI_ENV_PROVIDERS_LIST}"
  else
    mini_env_refresh_provider_list
  fi
}

# ─── Active provider tracking (name only — never parse URLs) ───────────────────

mini_env_read_active_provider() {
  _mini_env_ensure_dir
  if [[ -f "${MINI_ENV_ACTIVE_PROVIDER_FILE}" ]]; then
    tr -d '[:space:]' < "${MINI_ENV_ACTIVE_PROVIDER_FILE}"
    return 0
  fi
  echo ""
}

mini_env_write_active_provider() {
  local provider="${1:?}"
  _mini_env_ensure_dir
  printf '%s\n' "$provider" > "${MINI_ENV_ACTIVE_PROVIDER_FILE}"
}

# If state file is empty, infer by comparing .env to each .env-<name> (no URL parsing).
mini_env_infer_active_provider() {
  local p variant
  [[ -f "${MINI_ENV_ACTIVE}" ]] || { echo ""; return 0; }
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    variant="$(mini_env_variant_path "$p")"
    if [[ -f "$variant" ]] && cmp -s "${MINI_ENV_ACTIVE}" "$variant" 2>/dev/null; then
      echo "$p"
      return 0
    fi
  done < <(mini_env_discover_from_disk)
  echo ""
}

mini_env_resolve_active_provider() {
  local current
  current="$(mini_env_read_active_provider)"
  if [[ -n "$current" ]]; then
    echo "$current"
    return 0
  fi
  current="$(mini_env_infer_active_provider)"
  if [[ -n "$current" ]]; then
    mini_env_write_active_provider "$current"
    echo "$current"
    return 0
  fi
  echo ""
}

# ─── Swap: mv .env -> .env-<current>, mv .env-<target> -> .env ───────────────

mini_env_swap() {
  local target="${1:?provider name required}"
  local current variant_target variant_current

  _mini_env_ensure_dir
  mini_env_refresh_provider_list >/dev/null

  variant_target="$(mini_env_variant_path "$target")"
  if [[ ! -f "$variant_target" ]]; then
    echo "mini-env: missing ${variant_target}" >&2
    echo "mini-env: create .env-${target} before swapping (copy from an existing .env-<name>)" >&2
    return 1
  fi

  current="$(mini_env_resolve_active_provider)"

  if [[ "$current" == "$target" ]]; then
    echo "mini-env: already active: ${target}" >&2
    return 0
  fi

  if [[ -f "${MINI_ENV_ACTIVE}" ]]; then
    if [[ -z "$current" ]]; then
      echo "mini-env: active .env exists but provider is unknown." >&2
      echo "mini-env: set current provider: mini-env-swap --set-active <name>" >&2
      echo "mini-env:   (name should match the provider now in .env, e.g. zenmux)" >&2
      return 1
    fi
    variant_current="$(mini_env_variant_path "$current")"
    if [[ -e "$variant_current" ]]; then
      echo "mini-env: refuse overwrite: ${variant_current} already exists" >&2
      return 1
    fi
    mv "${MINI_ENV_ACTIVE}" "$variant_current"
    echo "mini-env: parked ${current} → $(basename "$variant_current")" >&2
  fi

  mv "$variant_target" "${MINI_ENV_ACTIVE}"
  mini_env_write_active_provider "$target"
  mini_env_refresh_provider_list >/dev/null
  echo "mini-env: active → ${target} (.env)" >&2
}

# Copy current .env to .env-<name> for a parked provider (e.g. create .env-openrouter).
# To tag the live .env without copying, use mini_env_set_active instead.
mini_env_save_current_as() {
  local name="${1:?}"
  local variant current
  variant="$(mini_env_variant_path "$name")"
  if [[ ! -f "${MINI_ENV_ACTIVE}" ]]; then
    echo "mini-env: no ${MINI_ENV_ACTIVE} to save" >&2
    return 1
  fi
  if [[ -e "$variant" ]]; then
    echo "mini-env: already exists: ${variant}" >&2
    return 1
  fi
  current="$(mini_env_resolve_active_provider)"
  if [[ "$current" == "$name" ]]; then
    echo "mini-env: .env is already ${name}; use --set-active only (no .env-${name} copy while active)" >&2
    mini_env_set_active "$name"
    return 0
  fi
  cp "${MINI_ENV_ACTIVE}" "$variant"
  mini_env_refresh_provider_list >/dev/null
  echo "mini-env: copied ${MINI_ENV_ACTIVE} → $(basename "$variant") (active remains: ${current:-unknown})" >&2
}

# Declare which provider is in .env without swapping (bootstrap / repair).
mini_env_set_active() {
  local name="${1:?}"
  local variant
  variant="$(mini_env_variant_path "$name")"
  if [[ ! -f "${MINI_ENV_ACTIVE}" ]] && [[ ! -f "$variant" ]]; then
    echo "mini-env: no .env or .env-${name} found" >&2
    return 1
  fi
  mini_env_write_active_provider "$name"
  mini_env_refresh_provider_list >/dev/null
  echo "mini-env: recorded active provider: ${name}" >&2
}

mini_env_status() {
  local current
  _mini_env_ensure_dir
  current="$(mini_env_resolve_active_provider)"
  echo "mini-swe-agent env (${MINI_ENV_DIR})"
  echo "  active file:  ${MINI_ENV_ACTIVE}"
  echo "  provider:     ${current:-<unknown>}"
  echo ""
  if [[ -f "${MINI_ENV_ACTIVE}" ]]; then
    echo "  active:       .env  (${current:-unknown provider})"
  else
    echo "  active:       (missing .env)"
  fi
  echo "  parked (.env-*):"
  local p found=false
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    [[ "$p" == "$current" ]] && continue
    echo "    .env-${p}"
    found=true
  done < <(mini_env_discover_from_disk)
  [[ "$found" == "true" ]] || echo "    (none)"
  echo ""
  echo "  tracked providers (${MINI_ENV_PROVIDERS_LIST}):"
  mini_env_list_providers | sed 's/^/    /'
}

# Session helpers for ainish-coder --cli EXIT restore
mini_env_remember_session_previous() {
  local current
  current="$(mini_env_resolve_active_provider)"
  [[ -n "$current" ]] || return 0
  printf '%s\n' "$current" > "${MINI_ENV_SESSION_PREVIOUS_FILE}"
}

mini_env_restore_session_previous() {
  local previous target
  [[ -f "${MINI_ENV_SESSION_PREVIOUS_FILE}" ]] || return 0
  previous="$(tr -d '[:space:]' < "${MINI_ENV_SESSION_PREVIOUS_FILE}")"
  rm -f "${MINI_ENV_SESSION_PREVIOUS_FILE}"
  [[ -n "$previous" ]] || return 0
  target="$(mini_env_read_active_provider)"
  [[ "$target" == "$previous" ]] && return 0
  mini_env_swap "$previous" 2>/dev/null || true
}

# Back-compat names used by hot_swap.sh / prepend
prepend_activate() {
  mini_env_remember_session_previous
  mini_env_swap "$1"
}

prepend_restore_all() {
  mini_env_restore_session_previous
}

prepend_status() {
  mini_env_status
}

prepend_discover_providers() {
  mini_env_refresh_provider_list
}

_ainish_prepend_ensure_trap() {
  if [[ -z "${_AINISH_PREPEND_TRAP_SET:-}" ]]; then
    trap mini_env_restore_session_previous EXIT
    _AINISH_PREPEND_TRAP_SET=1
  fi
}

prepend_activate_persistent() {
  _AINISH_PREPEND_TRAP_SET=1
  trap - EXIT
  mini_env_swap "$1"
}
