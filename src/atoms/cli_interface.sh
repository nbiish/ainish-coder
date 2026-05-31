#!/usr/bin/env bash
# Interactive CLI interface for ainish-coder
# Provides menu-driven selection of tools, providers, config verification, and hot-swap
set -euo pipefail

# ─── Trap: ensure terminal is sane and configs are restored on any exit ───────
#
# hot_swap.sh normally installs its own EXIT trap via _ainish_ensure_trap().
# We pre-set _AINISH_TRAP_SET so it never does — our _cli_cleanup calls
# _ainish_restore_all as part of the combined cleanup, guaranteeing both
# terminal restore AND config-file restore happen in the right order.

_AINISH_TRAP_SET=1

_cli_cleanup() {
    # 1. Restore any hot-swapped configs first (if hot_swap.sh was sourced)
    if declare -f _ainish_restore_all > /dev/null 2>&1; then
        _ainish_restore_all 2>/dev/null || true
    fi
    # 2. Restore terminal to a sane state
    stty sane 2>/dev/null || true
}

trap _cli_cleanup EXIT

# ─── Tool Registry ────────────────────────────────────────────────────────────
# Each tool: name, binary, config files, hot-swap function, description
# This is the single source of truth for what the CLI knows about.

TOOL_NAMES=(mini)

TOOL_BINARY_mini="mini"

TOOL_DESC_mini="mini-swe-agent — .env / .env-<provider> hot-swap"

# Config files per tool (space-separated, relative to $HOME)
TOOL_CONFIGS_mini=".config/mini-swe-agent/.env"

# ─── Provider JSON path ──────────────────────────────────────────────────────
PROVIDERS_FILE="${AINISH_PROVIDERS:-$HOME/.config/ainish-coder/providers.json}"

# ─── Helpers ──────────────────────────────────────────────────────────────────

_CLI_REPLY=""

# Convert a string to lowercase (bash 3.2 compatible)
_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

_cli_header() {
    echo ""
    echo -e "${BRIGHT_CYAN}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BRIGHT_CYAN}║            ainish-coder — Interactive Config Manager                 ║${RESET}"
    echo -e "${BRIGHT_CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

_cli_prompt() {
    echo -ne "${BRIGHT_YELLOW}▸ ${RESET}$1"
}

# Read a single line directly into _CLI_REPLY global.
# Strips ANSI escape sequences (arrow keys produce ^[[A etc).
# Does NOT use command substitution for read — avoids subshell issues on bash 3.2.
_cli_read() {
    local raw
    IFS= read -r raw
    # Strip ANSI escape sequences (ESC followed by [ + params + letter)
    # and other control characters except tab/newline
    raw="$(printf '%s' "$raw" | tr -d '\033' | sed 's/\[[0-9;]*[A-Za-z]//g' | tr -d '\001-\010\013\014\016-\037')"
    # Trim whitespace
    raw="${raw#"${raw%%[![:space:]]*}"}"
    raw="${raw%"${raw##*[![:space:]]}"}"
    _CLI_REPLY="$raw"
}

# Print a numbered list, return the array via global _CLI_ITEMS
_CLI_ITEMS=()
_cli_menu() {
    local i=1
    _CLI_ITEMS=()
    for item in "$@"; do
        _CLI_ITEMS+=("$item")
        printf "  ${BRIGHT_WHITE}%2d${RESET}) %s\n" "$i" "$item"
        ((i++))
    done
}

# Show a numbered menu and return the selected item via _CLI_PICK_RESULT.
# All display output goes to stderr so the caller can call this without
# command substitution (which would swallow the menu on bash 3.2).
# Returns 0 if an item was selected, 1 if user quit.
_cli_pick() {
    local prompt="$1"
    shift

    local choice
    while true; do
        _cli_menu "$@"
        echo ""
        _cli_prompt "${prompt} [1-${#_CLI_ITEMS[@]}, q=quit]: "
        _cli_read
        choice="$_CLI_REPLY"

        # Allow quitting from any picker
        if [[ "$(_lower "$choice")" == "q" ]]; then
            echo ""
            _CLI_PICK_RESULT=""
            return 1
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#_CLI_ITEMS[@]} )); then
            _CLI_PICK_RESULT="${_CLI_ITEMS[$((choice-1))]}"
            return 0
        fi

        # Invalid input — brief message, then re-display the menu
        echo ""
        echo -e "  ${YELLOW}Please enter a number between 1 and ${#_CLI_ITEMS[@]}, or 'q' to go back.${RESET}"
        echo ""
    done
}

_cli_pause() {
    echo ""
    _cli_prompt "Press Enter to continue... "
    _cli_read
}

# ─── Provider Listing ─────────────────────────────────────────────────────────

_cli_provider_list() {
    if [[ ! -f "$PROVIDERS_FILE" ]]; then
        echo ""
        return
    fi
    python3 -c "
import json, sys
try:
    with open('${PROVIDERS_FILE}') as f:
        for k in json.load(f):
            print(k)
except Exception:
    pass
"
}

_cli_provider_field() {
    local provider="$1" field="$2"
    python3 -c "
import json, sys
try:
    with open('${PROVIDERS_FILE}') as f:
        data = json.load(f)
    print(data.get('${provider}', {}).get('${field}', ''))
except Exception:
    print('')
"
}

_cli_provider_supports() {
    local provider="$1" tool="$2"
    python3 -c "
import json, sys
try:
    with open('${PROVIDERS_FILE}') as f:
        data = json.load(f)
    print(str(data.get('${provider}', {}).get('tools', {}).get('${tool}', False)).lower())
except Exception:
    print('false')
"
}

# ─── Config Verification ──────────────────────────────────────────────────────

_cli_verify_tool_config() {
    local tool="$1"
    local configs_var="TOOL_CONFIGS_${tool}"
    local configs="${!configs_var}"
    local all_ok=true

    echo -e "${BRIGHT_BLUE}  Verifying ${tool} config files:${RESET}"
    for rel_path in $configs; do
        local full_path="$HOME/${rel_path}"
        if [[ -f "$full_path" ]]; then
            echo -e "    ${GREEN}✓${RESET} ${rel_path}"
        else
            echo -e "    ${RED}✗${RESET} ${rel_path}  ${YELLOW}(missing)${RESET}"
            all_ok=false
        fi
    done

    if $all_ok; then
        echo -e "  ${GREEN}All config files present for ${tool}.${RESET}"
    else
        echo -e "  ${YELLOW}Some config files are missing for ${tool}.${RESET}"
        echo -e "  ${YELLOW}Run the tool once to bootstrap, or use --rules to deploy defaults.${RESET}"
    fi
    echo ""
    $all_ok
}

_cli_show_provider_details() {
    local provider="$1"
    local base_url model env_key
    base_url="$(_cli_provider_field "$provider" "baseUrl")"
    model="$(_cli_provider_field "$provider" "defaultModel")"
    env_key="$(_cli_provider_field "$provider" "envKey")"

    echo -e "  ${BRIGHT_WHITE}Provider:${RESET}  ${BRIGHT_CYAN}${provider}${RESET}"
    echo -e "  ${BRIGHT_WHITE}Base URL:${RESET}  ${base_url}"
    echo -e "  ${BRIGHT_WHITE}Model:${RESET}     ${model}"
    if [[ -n "$env_key" ]]; then
        echo -e "  ${BRIGHT_WHITE}Env Key:${RESET}   ${env_key}"
    fi
    echo -e "  ${BRIGHT_WHITE}API Key:${RESET}   ${GREEN}(configured)${RESET}"
    echo ""
}

# ─── Compatibility Matrix Display ─────────────────────────────────────────────

_cli_show_compat_matrix() {
    local providers
    providers="$(_cli_provider_list)"

    echo -e "${BRIGHT_BLUE}  Provider Compatibility:${RESET}"
    echo ""
    printf "  ${BRIGHT_WHITE}%-14s${RESET}" "Provider"
    for t in "${TOOL_NAMES[@]}"; do
        printf "  ${BRIGHT_WHITE}%-6s${RESET}" "$t"
    done
    echo ""
    echo "  ──────────────────────────────────────────"

    while IFS= read -r prov; do
        [[ -z "$prov" ]] && continue
        printf "  %-14s" "$prov"
        for t in "${TOOL_NAMES[@]}"; do
            local supports
            supports="$(_cli_provider_supports "$prov" "$t")"
            if [[ "$supports" == "true" ]]; then
                printf "  ${GREEN}%-6s${RESET}" "✓"
            else
                printf "  ${RED}%-6s${RESET}" "✗"
            fi
        done
        echo ""
    done <<< "$providers"
    echo ""
}

# ─── Hot-Swap Core (used by both swap-only and swap+launch) ──────────────────

# Performs the actual config backup, rewrite, and confirmation print.
# Does NOT launch the tool. Returns 0 on success.
_cli_do_hot_swap() {
    local tool="$1"
    local provider="$2"

    # Check compatibility
    local supports
    supports="$(_cli_provider_supports "$provider" "$tool")"
    if [[ "$supports" != "true" ]]; then
        echo -e "${RED}✗ Provider '${provider}' does not support ${tool}.${RESET}" >&2
        return 1
    fi

    # Verify config files exist
    if ! _cli_verify_tool_config "$tool"; then
        echo -e "${YELLOW}Config files missing. Hot-swap may fail.${RESET}"
        _cli_prompt "Continue anyway? [y/N]: "
        _cli_read
        local confirm="$_CLI_REPLY"
        if [[ "$(_lower "$confirm")" != "y" ]]; then
            echo "Aborted."
            return 1
        fi
    fi

    echo -e "${BRIGHT_BLUE}Swapping mini .env → .env-${provider}...${RESET}"

    # Source the hot-swap library (use REPO_DIR if available, else resolve)
    local lib_dir
    if [[ -n "${REPO_DIR:-}" ]]; then
        lib_dir="${REPO_DIR}/bin/lib"
    else
        lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../bin/lib" && pwd)"
    fi

    if [[ ! -f "${lib_dir}/providers.sh" ]] || [[ ! -f "${lib_dir}/hot_swap.sh" ]]; then
        echo -e "${RED}✗ Hot-swap library not found at ${lib_dir}${RESET}" >&2
        return 1
    fi

    source "${lib_dir}/providers.sh"
    source "${lib_dir}/hot_swap.sh"

    # Call the hot_swap function — this backs up the original config and
    # registers a one-shot EXIT trap to restore it when ainish-coder exits.
    local swap_fn="hot_swap_${tool}"
    $swap_fn "$provider"

    echo -e "${GREEN}✓ ${tool} configured for ${provider}${RESET}"
    echo -e "${BRIGHT_WHITE}Provider details:${RESET}"
    _cli_show_provider_details "$provider"
    echo -e "  ${BRIGHT_GREEN}ℹ  Renamed .env ↔ .env-<provider> (tracked in mini-env-active-provider).${RESET}"
    echo -e "  ${BRIGHT_GREEN}   Previous provider restores when you exit ainish-coder --cli.${RESET}"
    echo ""
}

# Swap + immediately launch the tool in the current terminal.
# The tool runs in the foreground. When the user exits the tool,
# they return to the CLI menu with the config still swapped.
_cli_hot_swap_and_run() {
    local tool="$1"
    local provider="$2"
    shift 2
    local extra_args=("$@")

    _cli_do_hot_swap "$tool" "$provider" || return $?

    echo -e "${BRIGHT_BLUE}Launching ${tool}...${RESET}"
    echo "─────────────────────────────────────────────────"

    # Resolve the real binary (skip ainish-coder wrapper scripts)
    local self_dir
    if [[ -n "${REPO_DIR:-}" ]]; then
        self_dir="${REPO_DIR}/bin"
    else
        self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../bin" && pwd)"
    fi
    local old_path="$PATH"
    PATH="$(echo "$PATH" | tr ':' '\n' | grep -v "^${self_dir}$" | tr '\n' ':')"
    local real_bin
    real_bin="$(command -v "$tool" 2>/dev/null || true)"
    PATH="$old_path"

    if [[ -z "$real_bin" ]]; then
        echo -e "${RED}✗ Real ${tool} binary not found on PATH.${RESET}" >&2
        echo -e "${YELLOW}   Your original config will still be restored on exit.${RESET}"
        return 1
    fi

    if [[ ${#extra_args[@]} -gt 0 ]]; then
        echo -e "${BRIGHT_WHITE}→ ${tool} ${extra_args[*]}${RESET}"
        "$real_bin" "${extra_args[@]}"
    else
        echo -e "${BRIGHT_WHITE}→ ${tool}${RESET}"
        "$real_bin"
    fi

    local rc=$?
    echo ""
    echo -e "${BRIGHT_BLUE}← ${tool} exited (code ${rc}).${RESET}"
    echo -e "${BRIGHT_GREEN}  Config remains swapped. Choose another tool or exit to restore defaults.${RESET}"
}

# ─── Main CLI Loop ────────────────────────────────────────────────────────────

run_cli_interface() {
    _cli_header

    # Pre-flight: check providers.json exists
    if [[ ! -f "$PROVIDERS_FILE" ]]; then
        echo -e "${RED}✗ Providers config not found: ${PROVIDERS_FILE}${RESET}"
        echo -e "${YELLOW}  Create it first. Example:${RESET}"
        echo ""
        cat << 'PROVIDER_EXAMPLE'
{
  "openrouter": {
    "baseUrl": "https://openrouter.ai/api/v1",
    "apiKey": "sk-or-v1-...",
    "defaultModel": "deepseek/deepseek-v4-pro",
    "envKey": "OPENROUTER_API_KEY",
    "tools": { "pi": true, "mini": true }
  }
}
PROVIDER_EXAMPLE
        echo ""
        return 1
    fi

    while true; do
        echo -e "${BRIGHT_CYAN}━━━ Main Menu ━━━${RESET}"
        echo ""

        local action
        _cli_pick "What do you want to do?" \
            "🔧  Pick a tool, hot-swap to a provider, and optionally launch it" \
            "🔍  Verify config files for a tool (checks all required files exist)" \
            "📋  Show provider ↔ tool compatibility matrix" \
            "📄  View a provider's details (base URL, model, supported tools)" \
            "🚪  Exit (restores all original configs)" || {
            # User pressed 'q' — exit cleanly
            echo ""
            echo -e "${GREEN}Exiting. Original configs will be restored.${RESET}"
            return 0
        }
        action="$_CLI_PICK_RESULT"

        [[ -z "$action" ]] && continue

        case "$action" in
            *hot-swap*)
                _cli_action_hot_swap
                ;;
            *Verify*)
                _cli_action_verify
                ;;
            *compatibility*)
                _cli_action_compat
                ;;
            *View* | *provider*details*)
                _cli_action_provider_details
                ;;
            *Exit*)
                echo ""
                echo -e "${GREEN}Exiting. Original configs will be restored.${RESET}"
                return 0
                ;;
            *)
                echo -e "  ${YELLOW}Unrecognized choice, please try again.${RESET}"
                ;;
        esac
    done
}

# ─── Action: Hot-Swap ─────────────────────────────────────────────────────────

_cli_action_hot_swap() {
    echo ""
    echo -e "${BRIGHT_BLUE}━━━ Pick a Tool ━━━${RESET}"
    echo ""

    local tool_items=()
    for t in "${TOOL_NAMES[@]}"; do
        local desc_var="TOOL_DESC_${t}"
        tool_items+=("${t}  —  ${!desc_var}")
    done

    local tool_pick
    _cli_pick "Which tool?" "${tool_items[@]}" || return 0
    tool_pick="$_CLI_PICK_RESULT"
    [[ -z "$tool_pick" ]] && return 0

    local tool="${tool_pick%% *}"

    echo ""
    echo -e "${BRIGHT_BLUE}━━━ Pick a Provider for ${tool} ━━━${RESET}"
    echo ""

    local providers
    providers="$(_cli_provider_list)"

    local compat_providers=()
    while IFS= read -r prov; do
        [[ -z "$prov" ]] && continue
        local supports
        supports="$(_cli_provider_supports "$prov" "$tool")"
        if [[ "$supports" == "true" ]]; then
            local model
            model="$(_cli_provider_field "$prov" "defaultModel")"
            compat_providers+=("${prov}  (model: ${model})")
        fi
    done <<< "$providers"

    if [[ ${#compat_providers[@]} -eq 0 ]]; then
        echo -e "${RED}No compatible providers found for ${tool}.${RESET}"
        _cli_pause
        return 0
    fi

    local prov_pick
    _cli_pick "Which provider?" "${compat_providers[@]}" || return 0
    prov_pick="$_CLI_PICK_RESULT"
    [[ -z "$prov_pick" ]] && return 0

    local provider="${prov_pick%% *}"

    echo ""
    echo -e "${BRIGHT_BLUE}━━━ Confirm & Run ━━━${RESET}"
    echo ""
    echo -e "  Tool:     ${BRIGHT_CYAN}${tool}${RESET}"
    echo -e "  Provider: ${BRIGHT_CYAN}${provider}${RESET}"
    _cli_show_provider_details "$provider"

    _cli_prompt "Hot-swap and launch ${tool} now? [Y/n/q]: "
    _cli_read
    local launch="$_CLI_REPLY"

    if [[ "$(_lower "$launch")" == "q" ]]; then
        echo "Cancelled. Nothing changed."
        return 0
    fi

    if [[ "$(_lower "$launch")" == "n" ]]; then
        # Swap only — no launch, just configure
        _cli_do_hot_swap "$tool" "$provider"
        echo -e "${BRIGHT_WHITE}→ ${tool} is configured for ${provider}. Not launched.${RESET}"
        echo -e "${BRIGHT_WHITE}  You can launch it from another terminal, or pick this menu${RESET}"
        echo -e "${BRIGHT_WHITE}  option again and choose 'Y' to launch directly.${RESET}"
    else
        # Swap AND immediately launch in this terminal
        _cli_prompt "Extra args for ${tool} (or press Enter for none): "
        _cli_read
        local extra="$_CLI_REPLY"
        if [[ -n "$extra" ]]; then
            # shellcheck disable=SC2086
            _cli_hot_swap_and_run "$tool" "$provider" $extra
        else
            _cli_hot_swap_and_run "$tool" "$provider"
        fi
    fi

    _cli_pause
}

# ─── Action: Verify Configs ──────────────────────────────────────────────────

_cli_action_verify() {
    echo ""
    echo -e "${BRIGHT_BLUE}━━━ Verify Tool Configurations ━━━${RESET}"
    echo ""

    local tool_items=()
    tool_items+=("all  —  verify all tools at once")
    for t in "${TOOL_NAMES[@]}"; do
        local desc_var="TOOL_DESC_${t}"
        tool_items+=("${t}  —  ${!desc_var}")
    done

    local tool_pick
    _cli_pick "Which tool to verify?" "${tool_items[@]}" || return 0
    tool_pick="$_CLI_PICK_RESULT"
    [[ -z "$tool_pick" ]] && return 0

    local tool="${tool_pick%% *}"

    echo ""
    if [[ "$tool" == "all" ]]; then
        for t in "${TOOL_NAMES[@]}"; do
            _cli_verify_tool_config "$t" || true
        done

        echo -e "${BRIGHT_BLUE}━━━ Providers Config ━━━${RESET}"
        echo ""
        if [[ -f "$PROVIDERS_FILE" ]]; then
            echo -e "  ${GREEN}✓${RESET} ${PROVIDERS_FILE}"
            echo -e "  ${BRIGHT_WHITE}Configured providers:${RESET}"
            local providers
            providers="$(_cli_provider_list)"
            while IFS= read -r prov; do
                [[ -z "$prov" ]] && continue
                local model
                model="$(_cli_provider_field "$prov" "defaultModel")"
                echo -e "    ${BRIGHT_CYAN}•${RESET} ${prov}  (model: ${model})"
            done <<< "$providers"
        else
            echo -e "  ${RED}✗${RESET} ${PROVIDERS_FILE}  ${YELLOW}(missing)${RESET}"
        fi
    else
        _cli_verify_tool_config "$tool"
    fi
    echo ""

    _cli_pause
}

# ─── Action: Compat Matrix ───────────────────────────────────────────────────

_cli_action_compat() {
    echo ""
    _cli_show_compat_matrix
    _cli_pause
}

# ─── Action: Provider Details ─────────────────────────────────────────────────

_cli_action_provider_details() {
    echo ""
    echo -e "${BRIGHT_BLUE}━━━ Provider Details ━━━${RESET}"
    echo ""

    local providers
    providers="$(_cli_provider_list)"

    local prov_items=()
    while IFS= read -r prov; do
        [[ -z "$prov" ]] && continue
        local model
        model="$(_cli_provider_field "$prov" "defaultModel")"
        prov_items+=("${prov}  (model: ${model})")
    done <<< "$providers"

    if [[ ${#prov_items[@]} -eq 0 ]]; then
        echo -e "${RED}No providers configured in ${PROVIDERS_FILE}${RESET}"
        _cli_pause
        return 0
    fi

    local prov_pick
    _cli_pick "Which provider?" "${prov_items[@]}" || return 0
    prov_pick="$_CLI_PICK_RESULT"
    [[ -z "$prov_pick" ]] && return 0

    local provider="${prov_pick%% *}"

    echo ""
    _cli_show_provider_details "$provider"

    echo -e "  ${BRIGHT_WHITE}Supported tools:${RESET}"
    for t in "${TOOL_NAMES[@]}"; do
        local supports
        supports="$(_cli_provider_supports "$provider" "$t")"
        if [[ "$supports" == "true" ]]; then
            echo -e "    ${GREEN}✓${RESET} ${t}"
        else
            echo -e "    ${RED}✗${RESET} ${t}"
        fi
    done
    echo ""

    echo -e "  ${BRIGHT_WHITE}Config files modified on swap:${RESET}"
    for t in "${TOOL_NAMES[@]}"; do
        local supports
        supports="$(_cli_provider_supports "$provider" "$t")"
        if [[ "$supports" == "true" ]]; then
            local configs_var="TOOL_CONFIGS_${t}"
            echo -e "    ${BRIGHT_CYAN}${t}:${RESET}"
            for rel_path in ${!configs_var}; do
                echo -e "      ~/${rel_path}"
            done
        fi
    done
    echo ""

    _cli_pause
}
