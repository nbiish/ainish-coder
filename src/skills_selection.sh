#!/bin/bash
# MOLECULE: Persisting skill-selection for distribution
#
# The operator toggles which .agents/skills/ packs distribute via
# `ainish-coder --skills-sync` (interactive keypress toggle UI: arrows move,
# space toggles, enter/space on the Save & submit row persists). The
# choice persists in
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
# Headless: `ainish-coder --skills-sync <dir> --headless` / `--rules <dir>
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

# Windows Git Bash (MSYS2) rewrites path-shaped values when it execs a native
# binary: REPO=/d/Code/app arrives as D:/Code/app and the JSON lookup misses,
# which made every pack fall back to "on" (a deploy then pinned them all true).
# Keep the repo key byte-identical to the key Linux/WSL wrote, and hand the
# config path to the interpreter in native form.
skills_selection_engine_path() {
    local path="$1"
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -w -- "$path" 2>/dev/null || printf '%s\n' "$path"
    else
        printf '%s\n' "$path"
    fi
}

skills_selection_env_guard() {
    printf '%s' "${MSYS2_ENV_CONV_EXCL:+${MSYS2_ENV_CONV_EXCL};}REPO;ALT_REPO"
}
# True when a skill name may NEVER be selected for skills/rules distribution.
# .ainish-ingest.* are transient same-FS staging dirs from sync_ainish_skills
# — never listed or selectable.
#
# Three distinct reasons a name is excluded from the *selection* channel:
#   - retired/consolidated packs (code-security, llm-security, production-security
#     merged into ainish-security; context-orchestration merged into
#     `ainish-rag context`; orchestrate-subagent-masters retired);
#   - the scroll channel, which has its own explicit distribution surface;
#   - mandatory packs, which are shipped regardless of any selection.
# Excluded-from-selection is a prompt-surface decision and says nothing about
# whether the pack ships — that is _skill_mandatory's job.
_skill_channel_excluded() {
    case "$1" in
        .scrolls*|8thfire-scrolls|ghost-layer-injector|.ainish-ingest.*) return 0 ;;
        code-security|llm-security|production-security|context-orchestration|orchestrate-subagent-masters) return 0 ;;
        pqc-secrets|ainish-security) return 0 ;;
        *) return 1 ;;
    esac
}

# True when a pack is deployed regardless of the operator's selection.
# Kept separate from _skill_channel_excluded so "invisible to the selector" and
# "always shipped" stay distinguishable: one is a prompt-surface decision, the
# other a runtime dependency the contract relies on.
#
# `pqc-secrets`: every secret resolution goes through it.
# `ainish-security`: the universal AGENTS.md links to it by path, so a deploy that
#   omitted it shipped a contract with two dangling links. Anything the always-on
#   rail points at must be mandatory, or the link is a lie in every default repo.
_skill_mandatory() {
    case "$1" in
        pqc-secrets|ainish-security) return 0 ;;
        *) return 1 ;;
    esac
}

# _skills_mandatory_names — the mandatory packs present in the source tree.
# Deploy, verify, and status paths share this one list so a pack can never be
# mandatory in one place and optional in another.
_skills_mandatory_names() {
    printf '%s\n' pqc-secrets
}

# skills_selection_default_on — is a pack with no recorded preference
# distributed? Default: NO; optional skills require an explicit operator
# selection. Overridable globally via AINISH_SKILLS_DEFAULT=on.
#
# Precedence (highest first): this repo's recorded `default` > the persisted
# machine-wide `global_default` (set by `--skills-set-default`) > the
# AINISH_SKILLS_DEFAULT env var > off. The persisted value outranks the env var
# because the flag exists to be durable across shells and repos, while the env
# var is a per-invocation override for CI; if the env var won, a saved default
# would appear to stop working in whichever shell happened to set it.
skills_selection_default_on() {
    [[ "$(skills_selection_global_default)" == "on" ]]
}

# skills_selection_global_default — the machine-wide default for packs with no
# per-repo answer: persisted `global_default`, else env, else off.
skills_selection_global_default() {
    local fallback="off"
    [[ "${AINISH_SKILLS_DEFAULT:-off}" == "on" ]] && fallback="on"
    GLOBAL_FALLBACK="$fallback" \
        SELECTION_PATH="$(skills_selection_engine_path "$(skills_selection_config_path)")" \
        python3 -c "
import json, os
try:
    cfg = json.load(open(os.environ['SELECTION_PATH']))
except Exception:
    cfg = {}
d = cfg.get('global_default', None)
if isinstance(d, bool):
    print('on' if d else 'off')
elif isinstance(d, str) and d.strip().lower() in ('on', 'off'):
    print(d.strip().lower())
else:
    print(os.environ['GLOBAL_FALLBACK'])
" 2>/dev/null || printf '%s\n' "$fallback"
}

# skills_selection_set_global_default <on|off> — persist the machine-wide
# default applied to every repo that has not recorded its own answer. Touches
# no per-repo entry, so repos that already answered keep their selection.
skills_selection_set_global_default() {
    local state="$1"
    [[ "$state" == "on" || "$state" == "off" ]] || { print_error "state must be on|off"; return 1; }
    STATE="$state" \
        SELECTION_PATH="$(skills_selection_engine_path "$(skills_selection_config_path)")" \
        python3 -c "
import json, os
path = os.environ['SELECTION_PATH']
try:
    cfg = json.load(open(path))
except Exception:
    cfg = {}
cfg['global_default'] = (os.environ['STATE'] == 'on')
os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
tmp = path + '.tmp'
with open(tmp, 'w') as f:
    json.dump(cfg, f, indent=2, sort_keys=True)
    f.write('\n')
os.replace(tmp, path)
"
}

# skills_selection_repo_recorded <repo_root> — true when this repo already has
# a recorded selection block (any pack entry or a `default`), i.e. the operator
# has answered the "what do I want deployed here?" question at least once.
skills_selection_repo_recorded() {
    local repo_key; repo_key="$(skills_selection_repo_key "${1:-$(pwd)}")"
    local raw_repo; raw_repo="$(cd "${1:-$(pwd)}" 2>/dev/null && pwd)"
    REPO="$repo_key" ALT_REPO="$raw_repo" \
        SELECTION_PATH="$(skills_selection_engine_path "$(skills_selection_config_path)")" \
        MSYS2_ENV_CONV_EXCL="$(skills_selection_env_guard)" \
        python3 -c "
import json, os
try:
    cfg = json.load(open(os.environ['SELECTION_PATH']))
except Exception:
    cfg = {}
repos = cfg.get('repos', {})
entry = repos.get(os.environ['REPO'])
if entry is None and os.environ.get('ALT_REPO'):
    entry = repos.get(os.environ['ALT_REPO'])
print('yes' if isinstance(entry, dict) else 'no')
" | grep -q yes
}
# skills_selection_enabled_count <repo_root> — number of source packs that
# currently resolve to ON for this repo (drives the deployment summary).
# Mandatory packs are counted unconditionally: they always ship, so omitting
# them would make a repo that receives pqc-secrets look like it received no
# packs at all.
skills_selection_enabled_count() {
    local repo_root="${1:-$(pwd)}"
    local source_dir="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/.agents/skills"
    [[ -d "$source_dir" ]] || { printf '0\n'; return 0; }
    local count=0 d name
    while IFS= read -r d; do
        name="$(basename "$d")"
        _skill_channel_excluded "$name" && ! _skill_mandatory "$name" && continue
        [[ -d "$d" ]] || continue
        if _skill_mandatory "$name"; then
            count=$((count + 1))
            continue
        fi
        if [[ "$(skills_selection_state "$repo_root" "$name")" == "on" ]]; then
            count=$((count + 1))
        fi
    done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -type d | sort)
    printf '%d\n' "$count"
}

# skills_selection_ui_mode — how this invocation may treat the selector.
#   always : operator asked for it explicitly (--select-skills / env=always)
#   never  : headless, non-interactive, no TTY, or env=off
#   auto   : interactive TTY — the selector opens only for a repo that has no
#            recorded selection yet, so repeat runs stay deterministic
# Prints one token; callers branch on it.
skills_selection_ui_mode() {
    local requested="${AINISH_SKILLS_PROMPT:-auto}"
    case "$requested" in
        always|on|force|1) printf 'always\n'; return 0 ;;
        off|none|never|0)  printf 'never\n';  return 0 ;;
    esac
    if [[ "${AINISH_HEADLESS:-false}" == "true" ]] || \
       [[ "${AINISH_NON_INTERACTIVE:-false}" == "true" ]]; then
        printf 'never\n'
        return 0
    fi
    skills_selection_tty_ok || { printf 'never\n'; return 0; }
    printf 'auto\n'
}

# skills_selection_tty_ok — a selector needs a real terminal on both ends; a
# redirected stdin or a captured stdout/stderr means no operator is watching.
skills_selection_tty_ok() {
    [[ -t 0 ]] || return 1
    [[ -t 1 || -t 2 ]] || return 1
    return 0
}

# skills_selection_prompt_timeout — idle seconds the selector tolerates before
# it cancels itself. Bounded so an abandoned terminal can never stall a deploy
# (the b268b75 regression removed the selector because it could hang).
skills_selection_prompt_timeout() {
    local t="${AINISH_SKILLS_PROMPT_TIMEOUT:-120}"
    [[ "$t" =~ ^[0-9]+$ ]] || t=120
    (( t > 0 )) || t=120
    printf '%s\n' "$t"
}

# skills_selection_should_prompt <repo_root> — true when the interactive
# selector must open for this run: explicit request, or first contact with a
# repo that has never recorded a selection.
#
# A machine-wide default set with `--skills-set-default on` counts as the
# operator having answered for a new repo. Without this, a default of "on"
# still stopped and prompted on every first contact, which defeats the point of
# a saved default. An explicit request still always prompts, and the selector
# can still be reached on demand with `--skills`.
skills_selection_should_prompt() {
    local repo_root="${1:-$(pwd)}"
    case "$(skills_selection_ui_mode)" in
        always) return 0 ;;
        never)  return 1 ;;
    esac
    skills_selection_repo_recorded "$repo_root" && return 1
    [[ "$(skills_selection_global_default)" == "on" ]] && return 1
    return 0
}

# skills_selection_repo_key <repo_root> — normalized JSON key for a repo.
# Same repo reached via symlink or relative path maps to one canonical key.
skills_selection_repo_key() {
    local repo="${1:-}"
    if [[ -d "$repo" ]]; then
        repo="$(cd -P "$repo" 2>/dev/null && pwd)"
    fi
    printf '%s' "$repo"
}

# skills_selection_has_entry <repo_root> <skill_name> — true when the config
# holds an explicit preference for this pack (used to distinguish
# ainish-managed stale packs from foreign packs during rename/deletion sweeps).
skills_selection_has_entry() {
    local repo_key; repo_key="$(skills_selection_repo_key "${1:-$(pwd)}")"
    local raw_repo; raw_repo="$(cd "${1:-$(pwd)}" 2>/dev/null && pwd)"
    local name="$2"
    REPO="$repo_key" ALT_REPO="$raw_repo" NAME="$name" \
        SELECTION_PATH="$(skills_selection_engine_path "$(skills_selection_config_path)")" \
        MSYS2_ENV_CONV_EXCL="$(skills_selection_env_guard)" \
        python3 -c "
import json, os
try:
    cfg = json.load(open(os.environ['SELECTION_PATH']))
except Exception:
    cfg = {}
repos = cfg.get('repos', {})
entry = repos.get(os.environ['REPO'])
if entry is None and os.environ.get('ALT_REPO'):
    entry = repos.get(os.environ['ALT_REPO'], {})
elif entry is None:
    entry = {}
name = os.environ['NAME']
print('yes' if name in entry else 'no')
" | grep -q yes
}

# Canonical implementation used everywhere (single code path):
# skills_selection_state <repo_root> <skill_name> -> "on"|"off"
skills_selection_state() {
    local repo_key; repo_key="$(skills_selection_repo_key "${1:-$(pwd)}")"
    local raw_repo; raw_repo="$(cd "${1:-$(pwd)}" 2>/dev/null && pwd)"
    local name="$2"
    local global_default
    global_default="$(skills_selection_global_default)"
    REPO="$repo_key" ALT_REPO="$raw_repo" NAME="$name" GLOBAL_DEFAULT="$global_default" \
        SELECTION_PATH="$(skills_selection_engine_path "$(skills_selection_config_path)")" \
        MSYS2_ENV_CONV_EXCL="$(skills_selection_env_guard)" \
        python3 -c "
import json, os
try:
    cfg = json.load(open(os.environ['SELECTION_PATH']))
except Exception:
    cfg = {}
repos = cfg.get('repos', {})
entry = repos.get(os.environ['REPO'])
if entry is None and os.environ.get('ALT_REPO'):
    entry = repos.get(os.environ['ALT_REPO'], {})
elif entry is None:
    entry = {}
name = os.environ['NAME']
if name in entry:
    print('on' if entry[name] else 'off')
else:
    # 'default' is written as a JSON boolean by batch_save and by
    # skills_selection_set_default. Accept legacy quotes-on/off strings too, or
    # a repo whose default is ON silently behaves as OFF.
    d = entry.get('default', None)
    if isinstance(d, bool):
        print('on' if d else 'off')
    elif isinstance(d, str) and d.strip().lower() in ('on', 'off'):
        print(d.strip().lower())
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
        SELECTION_PATH="$(skills_selection_engine_path "$(skills_selection_config_path)")" \
        MSYS2_ENV_CONV_EXCL="$(skills_selection_env_guard)" \
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
        SELECTION_PATH="$(skills_selection_engine_path "$(skills_selection_config_path)")" \
        MSYS2_ENV_CONV_EXCL="$(skills_selection_env_guard)" \
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

# skills_selection_batch_save <repo_root> <default:on|off> <name:state ...>
# Atomically writes the entire selection for a repo in a single JSON write.
skills_selection_batch_save() {
    local repo_root="$1"
    local repo_key; repo_key="$(skills_selection_repo_key "$repo_root")"
    local raw_repo; raw_repo="$(cd "$repo_root" 2>/dev/null && pwd)"
    shift
    local default_state="$1"
    shift
    local -a pairs=("$@")

    REPO="$repo_key" ALT_REPO="$raw_repo" DEFAULT_STATE="$default_state" \
    PAIRS="${pairs[*]}" SELECTION_PATH="$(skills_selection_engine_path "$(skills_selection_config_path)")" \
        MSYS2_ENV_CONV_EXCL="$(skills_selection_env_guard)" \
    python3 -c "
import json, os
path = os.environ['SELECTION_PATH']
try:
    cfg = json.load(open(path))
except Exception:
    cfg = {}
repos = cfg.setdefault('repos', {})
repo_key = os.environ['REPO']
entry = repos.setdefault(repo_key, {})

# If there was an old entry under ALT_REPO, merge and remove stale duplicate
alt_key = os.environ.get('ALT_REPO')
if alt_key and alt_key != repo_key and alt_key in repos:
    old = repos.pop(alt_key)
    for k, v in old.items():
        if k not in entry:
            entry[k] = v

entry['default'] = (os.environ['DEFAULT_STATE'] == 'on')

for pair in os.environ.get('PAIRS', '').split():
    if ':' in pair:
        name, state = pair.split(':', 1)
        entry[name] = (state == 'on')

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
    local source_dir="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/.agents/skills"
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

# skills_selection_report <repo_root> [json] — operator-facing view of the
# selection that governs deployment for one repo. Human output names the exact
# command that changes it; JSON is stable for CI/agent consumption
# (format: ainish-coder/skills-selection/v1).
skills_selection_report() {
    local repo_root="${1:-$(pwd)}"
    local json="${2:-false}"
    local source_dir="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/.agents/skills"
    [[ -d "$source_dir" ]] || { print_error "No skills directory at $source_dir"; return 1; }

    local on_names=() off_names=() mandatory_names=() d name
    while IFS= read -r d; do
        name="$(basename "$d")"
        if _skill_mandatory "$name"; then
            mandatory_names+=("$name")
            continue
        fi
        _skill_channel_excluded "$name" && continue
        if [[ "$(skills_selection_state "$repo_root" "$name")" == "on" ]]; then
            on_names+=("$name")
        else
            off_names+=("$name")
        fi
    done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -type d | sort)

    local recorded="false"
    skills_selection_repo_recorded "$repo_root" && recorded="true"

    if [[ "$json" == "true" ]]; then
        local on_json="" off_json="" n
        for n in ${on_names[@]+"${on_names[@]}"}; do on_json+="\"$n\","; done
        for n in ${off_names[@]+"${off_names[@]}"}; do off_json+="\"$n\","; done
        printf '{"format": "ainish-coder/skills-selection/v1", "repo": "%s", "recorded": %s, "default": "%s", "on": [%s], "off": [%s], "mandatory": [%s], "counts": {"on": %d, "off": %d, "mandatory": %d}}\n' \
            "$repo_root" "$recorded" "$(_skills_selection_repo_default "$repo_root")" \
            "${on_json%,}" "${off_json%,}" \
            "$(printf '"%s",' ${mandatory_names[@]+"${mandatory_names[@]}"} | sed 's/,$//')" \
            "${#on_names[@]}" "${#off_names[@]}" "${#mandatory_names[@]}"
        return 0
    fi

    echo -e "${BRIGHT_BLUE}Skill packs for: $repo_root${RESET}"
    if [[ "$recorded" == "true" ]]; then
        echo -e "  Selection: ${GREEN}recorded${RESET} (new packs default $(_skills_selection_repo_default "$repo_root"))"
    else
        echo -e "  Selection: ${YELLOW}not recorded yet${RESET} — the next interactive 'ainish-coder --rules' asks"
    fi
    echo ""
    if (( ${#mandatory_names[@]} > 0 )); then
        echo -e "  ${BRIGHT_CYAN}Always deployed (mandatory, not selectable)${RESET}"
        for name in "${mandatory_names[@]}"; do echo -e "    ${BRIGHT_CYAN}[*]${RESET} $name"; done
        echo ""
    fi
    if (( ${#on_names[@]} > 0 )); then
        echo -e "  ${GREEN}Deployed on --rules${RESET}"
        for name in "${on_names[@]}"; do echo -e "    ${GREEN}[x]${RESET} $name"; done
    else
        echo -e "  ${YELLOW}No optional packs selected — --rules deploys only the mandatory packs above.${RESET}"
    fi
    if (( ${#off_names[@]} > 0 )); then
        echo ""
        echo -e "  ${YELLOW}Not deployed${RESET}"
        for name in "${off_names[@]}"; do echo -e "    ${YELLOW}[ ]${RESET} $name"; done
    fi
    echo ""
    echo -e "  Change with: ${BRIGHT_WHITE}ainish-coder --select-skills $repo_root${RESET}"
    return 0
}

# _skills_selection_repo_default <repo_root> — effective default for NEW
# packs in this repo: the repo's recorded default, else the global default.
# Used by the toggle UI footer ("default(new)=…"). Prints on|off.
_skills_selection_repo_default() {
    local repo_key; repo_key="$(skills_selection_repo_key "${1:-$(pwd)}")"
    local raw_repo; raw_repo="$(cd "${1:-$(pwd)}" 2>/dev/null && pwd)"
    local global_default
    global_default="$(skills_selection_global_default)"
    REPO="$repo_key" ALT_REPO="$raw_repo" GLOBAL_DEFAULT="$global_default" \
        SELECTION_PATH="$(skills_selection_engine_path "$(skills_selection_config_path)")" \
        MSYS2_ENV_CONV_EXCL="$(skills_selection_env_guard)" \
        python3 -c "
import json, os
try:
    cfg = json.load(open(os.environ['SELECTION_PATH']))
except Exception:
    cfg = {}
repos = cfg.get('repos', {})
entry = repos.get(os.environ['REPO'])
if entry is None and os.environ.get('ALT_REPO'):
    entry = repos.get(os.environ['ALT_REPO'], {})
elif entry is None:
    entry = {}
d = entry.get('default', None)
if isinstance(d, bool):
    print('on' if d else 'off')
elif isinstance(d, str) and d.strip().lower() in ('on', 'off'):
    print(d.strip().lower())
else:
    print(os.environ['GLOBAL_DEFAULT'])
"
}

# _skills_toggle_ui <repo_root> — interactive skill-selection UI.
# repo_root = the TARGET repo the selection applies to (config key); the
# listed packs are the SOURCE packs in REPO_DIR/.agents/skills (what
# --skills-sync/--rules actually distribute).
# Returns 0 when the operator confirms; selection already persisted on disk.
# Cancelling (esc/q/ctrl+c/ctrl+d) saves NOTHING and returns 130.
# All UI text to stderr; nothing on stdout.
# Dispatch: a real TTY gets the raw-mode keypress UI (arrows move, space
# toggles, enter — or space on the Save & submit row — persists a batched
# write; a/n all-on/all-off; d flips the default-for-new-packs). Without a
# TTY (pipe/CI), falls back to the legacy numbered prompt unchanged.
_skills_toggle_ui() {
    if skills_selection_tty_ok; then
        _skills_toggle_ui_raw "$@"
    else
        _skills_toggle_ui_numbered "$@"
    fi
}

# _skills_toggle_ui_raw <repo_root> — raw-mode keypress checkbox UI.
# Single frame redrawn in place; batched persistence on submit only.
_skills_toggle_ui_raw() {
    local repo_root="$1"
    local source_dir="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/.agents/skills"
    [[ -d "$source_dir" ]] || { print_error "No skills directory at $source_dir"; return 1; }

    # Live intake: enumerate from disk each run.
    local names=() states=() initial=()
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
    initial=("${states[@]}")
    local working_default; working_default="$(_skills_selection_repo_default "$repo_root")"
    local initial_default="$working_default"

    local n=${#names[@]}
    # NOTE: must be a separate statement — bash expands all RHS of a single
    # `local` line BEFORE assigning, so referencing $n on the same line
    # yields the pre-declaration (unset) value.
    local submit_idx=$n cursor=0 frame_lines=$((n + 5))
    local saved_tty restored=0 i key k1 k2 changes
    # bash 3.2 (macOS default) rejects fractional read timeouts; bash 4+
    # accepts them. Snappy ESC handling where possible, integer fallback else.
    local esc_tmo=1
    (( BASH_VERSINFO[0] > 3 )) && esc_tmo=0.05

    _st_ui_restore() {
        (( restored )) && return 0
        restored=1
        stty "$saved_tty" 2>/dev/null || stty sane 2>/dev/null || true
        printf '\033[?25h' >&2          # show cursor
    }

    saved_tty="$(stty -g 2>/dev/null)"
    if [[ -z "$saved_tty" ]]; then
        # Cannot go raw safely — legacy numbered UI.
        _skills_toggle_ui_numbered "$repo_root"
        return
    fi
    trap _st_ui_restore INT TERM EXIT
    stty raw -echo 2>/dev/null
    printf '\033[?25l' >&2              # hide cursor

    _st_ui_frame() {
        local i
        printf '\033[K%b\r\n' "${BRIGHT_CYAN}Skill distribution — toggle per pack${RESET} ${YELLOW}(persisted per repo)${RESET}" >&2
        printf '\033[K%b\r\n' "${YELLOW}Repo: $repo_root${RESET}" >&2
        printf '\033[K\r\n' >&2
        for i in "${!names[@]}"; do
            if (( i == cursor )); then
                printf '\033[K%b\r\n' "  ${BRIGHT_CYAN}▸${RESET} $([ "${states[$i]}" == on ] && printf '%b' "${GREEN}[x]${RESET}" || printf '%b' "${YELLOW}[ ]${RESET}") ${BRIGHT_WHITE}${names[$i]}${RESET}" >&2
            else
                printf '\033[K%b\r\n' "    $([ "${states[$i]}" == on ] && printf '%b' "${GREEN}[x]${RESET}" || printf '%b' "${YELLOW}[ ]${RESET}") ${names[$i]}" >&2
            fi
        done
        if (( cursor == submit_idx )); then
            printf '\033[K%b\r\n' "  ${BRIGHT_GREEN}▸ [ Save & submit ]${RESET}" >&2
        else
            printf '\033[K%b\r\n' "    ${YELLOW}[ Save & submit ]${RESET}" >&2
        fi
        printf '\033[K%b' "${YELLOW}↑/↓ move · space toggle · enter save · a all-on · n all-off · d default(new)=$working_default · q/esc cancel${RESET}" >&2
    }

    _st_ui_frame

    # Bounded idle read: an abandoned terminal cancels the selector instead of
    # hanging the deploy. The persisted selection then applies as-is.
    local idle_tmo
    idle_tmo="$(skills_selection_prompt_timeout)"

    while true; do
        if ! IFS= read -r -n1 -s -t "$idle_tmo" key; then
            trap - INT TERM EXIT
            _st_ui_restore
            printf '\r\n' >&2
            echo -e "${YELLOW}Selector timed out after ${idle_tmo}s — no changes saved; the saved selection applies.${RESET}" >&2
            return 130
        fi
        if [[ "$key" == $'\x1b' ]]; then
            if IFS= read -r -n1 -s -t "$esc_tmo" k1; then
                if [[ "$k1" == "[" || "$k1" == "O" ]]; then
                    IFS= read -r -n1 -s -t "$esc_tmo" k2 || true
                    case "$k2" in
                        A) cursor=$(( (cursor + n) % (n + 1) )) ;;
                        B) cursor=$(( (cursor + 1) % (n + 1) )) ;;
                        Z) cursor=$(( (cursor + n) % (n + 1) )) ;; # Shift-Tab
                    esac
                fi
            else
                trap - INT TERM EXIT
                _st_ui_restore
                printf '\r\n' >&2
                echo -e "${YELLOW}Cancelled — no changes saved.${RESET}" >&2
                return 130
            fi
        else
            case "$key" in
                $'\x03'|$'\x04'|q|Q)
                    trap - INT TERM EXIT
                    _st_ui_restore
                    printf '\r\n' >&2
                    echo -e "${YELLOW}Cancelled — no changes saved.${RESET}" >&2
                    return 130 ;;
                ' ')
                    if (( cursor == submit_idx )); then
                        break
                    fi
                    if [[ "${states[$cursor]}" == "on" ]]; then states[$cursor]="off"; else states[$cursor]="on"; fi
                    ;;
                $'\r'|$'\n'|'')
                    break
                    ;;
                $'\t')
                    cursor=$(( (cursor + 1) % (n + 1) ))
                    ;;
                a|A)
                    for i in "${!names[@]}"; do states[$i]="on"; done ;;
                n|N)
                    for i in "${!names[@]}"; do states[$i]="off"; done ;;
                d|D)
                    if [[ "$working_default" == "on" ]]; then working_default="off"; else working_default="on"; fi ;;
                j|J) cursor=$(( (cursor + 1) % (n + 1) )) ;;
                k|K) cursor=$(( (cursor + n) % (n + 1) )) ;;
            esac
        fi
        printf '\r\033[%dA' "$((frame_lines - 1))" >&2
        _st_ui_frame
    done

    trap - INT TERM EXIT
    _st_ui_restore
    printf '\r\n' >&2

    local pairs=()
    for i in "${!names[@]}"; do
        pairs+=("${names[$i]}:${states[$i]}")
    done
    skills_selection_batch_save "$repo_root" "$working_default" "${pairs[@]}"
    echo -e "${BRIGHT_GREEN}✅ Selection saved${RESET} ${YELLOW}(${#names[@]} pack(s) recorded)${RESET}" >&2
    return 0
}

# _skills_toggle_ui_numbered <repo_root> — legacy typed prompt (non-TTY
# fallback; behavior preserved verbatim from the original numbered UI).
# Returns 0 when the operator confirms; selection already persisted on disk.
# All UI text to stderr; nothing on stdout.
_skills_toggle_ui_numbered() {
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
    local n=${#names[@]}
    local working_default
    working_default="$(_skills_selection_repo_default "$repo_root")"

    if [[ ${#names[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No skill packs found in $source_dir${RESET}" >&2
        return 1
    fi

    while true; do
        echo -e "\n${BRIGHT_BLUE}Available Skills (${repo_root}):${RESET}" >&2
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
                local pairs=()
                for i in "${!names[@]}"; do
                    pairs+=("${names[$i]}:${states[$i]}")
                done
                skills_selection_batch_save "$repo_root" "$working_default" "${pairs[@]}"
                echo -e "${BRIGHT_GREEN}✅ Selection saved${RESET} ${YELLOW}(${#names[@]} pack(s) recorded)${RESET}" >&2
                return 0
                ;;
            a|A)
                local i
                for i in "${!names[@]}"; do
                    states[$i]="on"
                done
                ;;
            n|N)
                local i
                for i in "${!names[@]}"; do
                    states[$i]="off"
                done
                ;;
            d|D)
                echo -ne "${BRIGHT_YELLOW}▸ ${RESET}Default for NEW packs [on/off]: " >&2
                local dflt
                read -r dflt || dflt="on"
                dflt="$(echo "$dflt" | xargs)"
                if [[ "$dflt" == "on" || "$dflt" == "off" ]]; then
                    working_default="$dflt"
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
                        else
                            states[$idx]="on"
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
