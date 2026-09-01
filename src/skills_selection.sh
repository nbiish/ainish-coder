#!/bin/bash
# MOLECULE: Persisting skill-selection for distribution
#
# The operator toggles which .agents/skills/ packs distribute via
# `ainish-coder --skills` (numbered node-choice UI). The choice persists in
# ~/.config/ainish-coder/skills-selection.json (per-repo keys, keyed by
# absolute repo path) across terminals and machines that share $HOME.
#
# Live intake: the config stores per-REPO selections keyed by skill NAME.
# Source packs are enumerated from disk on every run, so additions, renames,
# and deletions in the repo's .agents/skills/ are picked up automatically —
# new packs default to the repo's default-selection policy.
#
# Hard exclusion (never configurable): .scrolls* payload, 8thfire-scrolls,
# and ghost-layer-injector — the explicit --scrolls channel only.
#
# Headless: `ainish-coder --skills <dir> --headless` / `--rules <dir>
# --headless` skips every prompt and applies the persisted selection as-is
# (agent/CI path).

# Path of the persisted selection config. AINISH_SKILLS_SELECTION overrides
# (tests use this to sandbox).
skills_selection_config_path() {
    if [[ -n "${AINISH_SKILLS_SELECTION:-}" ]]; then
        printf '%s\n' "$AINISH_SKILLS_SELECTION"
        return
    fi
    local dir="${HOME}/.config/ainish-coder"
    safe_mkdir "$dir" >/dev/null 2>&1 || true
    printf '%s\n' "$dir/skills-selection.json"
}

# True when a skill name may NEVER be selected for skills/rules distribution.
_skill_channel_excluded() {
    case "$1" in
        .scrolls*|8thfire-scrolls|ghost-layer-injector) return 0 ;;
        *) return 1 ;;
    esac
}

# skills_selection_default_on — is a pack with no recorded preference
# distributed? Default: YES (all ainish skills distribute; operator opts OUT
# per pack). Overridable globally via AINISH_SKILLS_DEFAULT=off.
skills_selection_default_on() {
    [[ "${AINISH_SKILLS_DEFAULT:-on}" != "off" ]]
}

# skills_selection_repo_key <repo_root> — normalized JSON key for a repo.
# Same repo reached via symlink or relative path maps to one key.
skills_selection_repo_key() {
    local repo="${1:-}"
    [[ -d "$repo" ]] && repo="$(cd "$repo" && pwd)"
    printf '%s' "$repo"
}

# skills_selection_has_entry <repo_root> <skill_name> — true when the config
# holds an explicit preference for this pack (used to distinguish
# ainish-managed stale packs from foreign packs during rename/deletion sweeps).
skills_selection_has_entry() {
    local repo_key; repo_key="$(skills_selection_repo_key "${1:-$(pwd)}")"
    local name="$2"
    REPO="$repo_key" NAME="$name"         SELECTION_PATH="$(skills_selection_config_path)"         python3 -c "
import json, os
try:
    cfg = json.load(open(os.environ['SELECTION_PATH']))
except Exception:
    cfg = {}
name = os.environ['NAME']
entry = cfg.get('repos', {}).get(os.environ['REPO'], {})
print('yes' if name in entry else 'no')
" | grep -q yes
}

# Canonical implementation used everywhere (single code path):
# skills_selection_state <repo_root> <skill_name> -> "on"|"off"
skills_selection_state() {
    local repo_key; repo_key="$(skills_selection_repo_key "${1:-$(pwd)}")"
    local name="$2"
    local global_default="on"
    skills_selection_default_on || global_default="off"
    REPO="$repo_key" NAME="$name" GLOBAL_DEFAULT="$global_default" \
        SELECTION_PATH="$(skills_selection_config_path)" \
        python3 -c "
import json, os
try:
    cfg = json.load(open(os.environ['SELECTION_PATH']))
except Exception:
    cfg = {}
entry = cfg.get('repos', {}).get(os.environ['REPO'], {})
name = os.environ['NAME']
if name in entry:
    print('on' if entry[name] else 'off')
elif str(entry.get('default','')).lower() in ('on','off'):
    print('on' if str(entry['default']).lower()=='on' else 'off')
else:
    print(os.environ['GLOBAL_DEFAULT'])
"
}

# skills_selection_set <repo_root> <skill_name> <on|off> — persist one toggle.
skills_selection_set() {
    local repo_key; repo_key="$(skills_selection_repo_key "$1")"
    local name="$2" state="$3"
    [[ "$state" == "on" || "$state" == "off" ]] || { print_error "state must be on|off"; return 1; }
    REPO="$repo_key" NAME="$name" STATE="$state" \
        SELECTION_PATH="$(skills_selection_config_path)" \
        python3 -c "
import json, os
path = os.environ['SELECTION_PATH']
try:
    cfg = json.load(open(path))
except Exception:
    cfg = {}
repos = cfg.setdefault('repos', {})
entry = repos.setdefault(os.environ['REPO'], {})
entry[os.environ['NAME']] = (os.environ['STATE'] == 'on')
tmp = path + '.tmp'
with open(tmp, 'w') as f:
    json.dump(cfg, f, indent=2, sort_keys=True)
    f.write('\n')
os.replace(tmp, path)
"
}

# skills_selection_set_default <repo_root> <on|off> — repo-wide default for
# packs with no recorded preference (live-intake policy).
skills_selection_set_default() {
    local repo_key; repo_key="$(skills_selection_repo_key "$1")"
    local state="$2"
    [[ "$state" == "on" || "$state" == "off" ]] || { print_error "state must be on|off"; return 1; }
    REPO="$repo_key" STATE="$state" \
        SELECTION_PATH="$(skills_selection_config_path)" \
        python3 -c "
import json, os
path = os.environ['SELECTION_PATH']
try:
    cfg = json.load(open(path))
except Exception:
    cfg = {}
repos = cfg.setdefault('repos', {})
repos.setdefault(os.environ['REPO'], {})['default'] = (os.environ['STATE'] == 'on')
tmp = path + '.tmp'
with open(tmp, 'w') as f:
    json.dump(cfg, f, indent=2, sort_keys=True)
    f.write('\n')
os.replace(tmp, path)
"
}

# skills_selection_list <repo_root> — enumerate source packs with state.
# Prints "ON|OFF <name>" lines, sorted; excluded packs never listed.
skills_selection_list() {
    local repo_root="${1:-$(pwd)}"
    local source_dir="$repo_root/.agents/skills"
    [[ -d "$source_dir" ]] || return 1
    local d name
    while IFS= read -r d; do
        name="$(basename "$d")"
        _skill_channel_excluded "$name" && continue
        if [[ "$(skills_selection_state "$repo_root" "$name")" == "on" ]]; then
            printf 'ON  %s\n' "$name"
        else
            printf 'OFF %s\n' "$name"
        fi
    done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -type d | sort)
}

# _skills_toggle_ui <repo_root> — interactive numbered node-choice UI.
# repo_root = the TARGET repo the selection applies to (config key); the
# listed packs are the SOURCE packs in REPO_DIR/.agents/skills (what
# --skills/--rules actually distribute).
# Returns 0 when the operator confirms; selection already persisted on disk.
# All UI text to stderr; nothing on stdout.
_skills_toggle_ui() {
    local repo_root="$1"
    local source_dir="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/.agents/skills"
    [[ -d "$source_dir" ]] || { print_error "No skills directory at $source_dir"; return 1; }

    # Live intake: enumerate from disk each run.
    local names=() states=()
    local d name
    while IFS= read -r d; do
        name="$(basename "$d")"
        _skill_channel_excluded "$name" && continue
        names+=("$name")
        states+=("$(skills_selection_state "$repo_root" "$name")")
    done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -type d | sort)

    if [[ ${#names[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No skill packs found in $source_dir${RESET}" >&2
        return 1
    fi

    while true; do
        echo -e "\n${BRIGHT_CYAN}Skill distribution — toggle per pack${RESET} ${YELLOW}(persisted per repo)${RESET}" >&2
        echo -e "${YELLOW}Repo: $repo_root${RESET}" >&2
        local i
        for i in "${!names[@]}"; do
            if [[ "${states[$i]}" == "on" ]]; then
                printf "  ${BRIGHT_WHITE}%2d${RESET}) ${GREEN}[x]${RESET} %s\n" $((i+1)) "${names[$i]}" >&2
            else
                printf "  ${BRIGHT_WHITE}%2d${RESET}) ${YELLOW}[ ]${RESET} %s\n" $((i+1)) "${names[$i]}" >&2
            fi
        done
        echo -e "   a) toggle ALL on   n) toggle ALL off" >&2
        echo -e "   d) set default for NEW packs (on/off)   s) save & continue" >&2
        echo -ne "\n${BRIGHT_YELLOW}▸ ${RESET}Toggle number(s) (e.g. 1 3 5), a/n/d/s: " >&2
        local choice
        read -r choice || choice="s"
        choice="$(echo "$choice" | xargs)"

        case "$choice" in
            s|S|"")
                echo -e "${BRIGHT_GREEN}✅ Selection saved${RESET}" >&2
                return 0
                ;;
            a|A)
                local i
                for i in "${!names[@]}"; do
                    states[$i]="on"
                    skills_selection_set "$repo_root" "${names[$i]}" on
                done
                ;;
            n|N)
                local i
                for i in "${!names[@]}"; do
                    states[$i]="off"
                    skills_selection_set "$repo_root" "${names[$i]}" off
                done
                ;;
            d|D)
                echo -ne "${BRIGHT_YELLOW}▸ ${RESET}Default for NEW packs [on/off]: " >&2
                local dflt
                read -r dflt || dflt="on"
                dflt="$(echo "$dflt" | xargs)"
                if [[ "$dflt" == "on" || "$dflt" == "off" ]]; then
                    skills_selection_set_default "$repo_root" "$dflt"
                    echo -e "${GREEN}✓ default=$dflt for new packs${RESET}" >&2
                else
                    echo "Invalid: on|off" >&2
                fi
                ;;
            *)
                # Node-choice: one or more numbers, e.g. "1 3 5"
                local tok idx bad=0
                for tok in $choice; do
                    if [[ "$tok" =~ ^[0-9]+$ ]] && (( tok >= 1 && tok <= ${#names[@]} )); then
                        idx=$((tok-1))
                        if [[ "${states[$idx]}" == "on" ]]; then
                            states[$idx]="off"
                            skills_selection_set "$repo_root" "${names[$idx]}" off
                        else
                            states[$idx]="on"
                            skills_selection_set "$repo_root" "${names[$idx]}" on
                        fi
                    else
                        echo "Invalid: $tok" >&2
                        bad=1
                    fi
                done
                ;;
        esac
    done
}
