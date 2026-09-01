#!/bin/bash
# MOLECULE: Skills byte-integrity (verify + safe sync)
# verify_ainish_skills : read-only report of byte-identity vs this repo
# sync_ainish_skills   : THE one command — verifies and pulls the latest
#                        ainish-coder skills (missing or drifted only);
#                        foreign skills and scroll-channel packs never
#                        touched; the persisted per-repo selection governs
#                        which packs sync (deselected packs never pulled).

# Resolve the ainish-coder source repo (AINISH_SOURCE_REPO > stamp > REPO_DIR).
_ainish_skills_source() {
    if [[ -n "${AINISH_SOURCE_REPO:-}" && -d "$AINISH_SOURCE_REPO/.agents/skills" ]]; then
        echo "$AINISH_SOURCE_REPO"
        return 0
    fi
    local target_dir="${1:-.}"
    local stamp="$target_dir/.agents/skills/.ainish-source"
    if [[ -f "$stamp" ]]; then
        local stamped
        stamped="$(head -n1 "$stamp" 2>/dev/null)"
        if [[ -d "$stamped/.agents/skills" ]]; then
            echo "$stamped"
            return 0
        fi
    fi
    if [[ -d "${REPO_DIR:-}/.agents/skills" ]]; then
        echo "$REPO_DIR"
        return 0
    fi
    return 1
}

# True when a skill name is managed-by-default-excluded (scrolls channel).
_ainish_skill_excluded() {
    case "$1" in
        .scrolls*|8thfire-scrolls|ghost-layer-injector) return 0 ;;
        *) return 1 ;;
    esac
}

# Byte-compare one skill directory tree (symlinks to source are identical).
# Skips .env (local-only secrets surface — never distributed), so a
# gitignored local .env in the source pack cannot fake a mismatch.
_ainish_skill_identical() {
    local src="$1" dst="$2"
    [[ -L "$dst" ]] && [[ "$(cd "$(dirname "$dst")" && cd "$(readlink "$dst")" 2>/dev/null && pwd)" == "$src" ]] && return 0
    [[ -d "$dst" ]] || return 1
    diff -r -x ".env" "$src" "$dst" >/dev/null 2>&1
}

verify_ainish_skills() {
    local target_dir="${1:-.}"
    local source_dir
    source_dir="$(_ainish_skills_source "$target_dir")" || {
        print_error "Cannot resolve ainish-coder source repo (set AINISH_SOURCE_REPO or redeploy skills)"
        return 1
    }
    local skills_target="$target_dir/.agents/skills"
    local skills_source="$source_dir/.agents/skills"
    if [[ ! -d "$skills_target" ]]; then
        print_error "No skills directory at $skills_target"
        return 1
    fi

    echo -e "${BRIGHT_BLUE}Verifying skill byte-identity vs $source_dir${RESET}"
    local identical=0 mismatched=0 foreign=0 missing=0
    local mismatches=()

    local skill
    for skill in "$skills_target"/*/; do
        [[ -d "$skill" ]] || continue
        local name
        name="$(basename "$skill")"
        _ainish_skill_excluded "$name" && continue
        if [[ ! -d "$skills_source/$name" ]]; then
            echo -e "${YELLOW}◦ foreign (untouched): $name${RESET}"
            ((foreign++)) || true
        elif _ainish_skill_identical "$skills_source/$name" "$skills_target/$name"; then
            echo -e "${GREEN}✓ identical: $name${RESET}"
            ((identical++)) || true
        else
            echo -e "${BRIGHT_RED}✗ MISMATCH: $name${RESET}"
            ((mismatched++)) || true
            mismatches+=("$name")
        fi
    done
    for skill in "$skills_source"/*/; do
        [[ -d "$skill" ]] || continue
        local name
        name="$(basename "$skill")"
        _ainish_skill_excluded "$name" && continue
        if [[ ! -d "$skills_target/$name" ]]; then
            echo -e "${YELLOW}◦ missing (not deployed): $name${RESET}"
            ((missing++)) || true
        fi
    done

    echo -e "${BRIGHT_GREEN}✅ identical=$identical${RESET} ${BRIGHT_RED}mismatch=$mismatched${RESET} ${YELLOW}foreign=$foreign missing=$missing${RESET}"
    if (( mismatched > 0 )); then
        echo -e "${YELLOW}Run: ainish-coder --skills-sync $target_dir${RESET}"
        return 1
    fi
    return 0
}

# Compare mtimes of two skill directories.
# Prints "1" if dir1 has newer files, "2" if dir2 has newer files, "0" if equal.
_ainish_skill_newer() {
    local dir1="$1" dir2="$2"
    DIR1="$dir1" DIR2="$dir2" python3 -c "
import os
def get_mtime(d):
    max_m = 0
    if not os.path.exists(d): return 0
    for root, _, files in os.walk(d):
        for f in files:
            p = os.path.join(root, f)
            try: max_m = max(max_m, os.path.getmtime(p))
            except Exception: pass
    return max_m

m1 = get_mtime(os.environ['DIR1'])
m2 = get_mtime(os.environ['DIR2'])
if m1 > m2: print('1')
elif m2 > m1: print('2')
else: print('0')
"
}

# Prompt operator to confirm/select candidate skills to add/update into ainish-coder source
_select_candidate_skills() {
    local -a candidates=("$@")
    _SELECTED_CANDIDATES=()
    local count="${#candidates[@]}"
    (( count > 0 )) || return 0

    # Headless / non-interactive / non-TTY: accept all candidates
    if [[ "${AINISH_HEADLESS:-false}" == "true" ]] || [[ "${AINISH_NON_INTERACTIVE:-false}" == "true" ]] || [[ ! -t 0 ]]; then
        _SELECTED_CANDIDATES=("${candidates[@]}")
        return 0
    fi

    echo ""
    echo -e "${BRIGHT_CYAN}External/upstream skill(s) detected at target repo:${RESET}"
    local i=1
    for item in "${candidates[@]}"; do
        local name="${item%%:*}"
        local kind="${item##*:}"
        if [[ "$kind" == "new" ]]; then
            echo -e "  ${BRIGHT_GREEN}[$i]${RESET} ${GREEN}+ $name${RESET} ${YELLOW}(new skill — add to ainish-coder)${RESET}"
        else
            echo -e "  ${BRIGHT_GREEN}[$i]${RESET} ${CYAN}↑ $name${RESET} ${YELLOW}(upstream update — update ainish-coder)${RESET}"
        fi
        ((i++))
    done
    echo ""

    if (( count == 1 )); then
        local name="${candidates[0]%%:*}"
        local kind="${candidates[0]##*:}"
        local action="Add new skill"
        [[ "$kind" == "updated" ]] && action="Pull updated skill"
        if confirm_action "$action '$name' into ainish-coder repository?" "y"; then
            _SELECTED_CANDIDATES=("${candidates[0]}")
        fi
        return 0
    fi

    # Multiple candidates: allow all, none, or specific numbers
    echo -e "${YELLOW}Options:${RESET} ${GREEN}y${RESET}=add all, ${GREEN}1 2 ...${RESET}=select specific, ${RED}n${RESET}=skip all"
    local ans
    read -r -p "Select skills to add/update into ainish-coder [Y/n/numbers]: " ans
    ans="$(echo "$ans" | tr '[:upper:]' '[:lower:]' | xargs)"

    if [[ -z "$ans" || "$ans" == "y" || "$ans" == "yes" || "$ans" == "all" ]]; then
        _SELECTED_CANDIDATES=("${candidates[@]}")
    elif [[ "$ans" == "n" || "$ans" == "no" ]]; then
        _SELECTED_CANDIDATES=()
    else
        local num
        for num in $(echo "$ans" | tr ',' ' '); do
            if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= count )); then
                local idx=$(( num - 1 ))
                _SELECTED_CANDIDATES+=("${candidates[$idx]}")
            fi
        done
    fi
}

sync_ainish_skills() {
    local target_dir="${1:-.}"
    local source_dir
    source_dir="$(_ainish_skills_source "$target_dir")" || {
        print_error "Cannot resolve ainish-coder source repo (set AINISH_SOURCE_REPO or redeploy skills)"
        return 1
    }
    local skills_target="$target_dir/.agents/skills"
    local skills_source="$source_dir/.agents/skills"
    if [[ ! -d "$skills_source" ]]; then
        print_error "Source skills directory not found: $skills_source"
        return 1
    fi

    # Self-sync guard: syncing the ainish-coder repo onto itself would
    # rm/deploy source packs onto themselves. Nothing to sync.
    if [[ "$(cd "$target_dir" 2>/dev/null && pwd)" == "$source_dir" ]]; then
        echo -e "${YELLOW}ℹ Target is the ainish-coder source repo itself — all skills are home.${RESET}"
        return 0
    fi

    echo -e "${BRIGHT_BLUE}Syncing ainish-coder skills ↔ $skills_target (verify + two-way sync)${RESET}"
    safe_mkdir "$skills_target" || return 1

    local updated=0 identical=0 deployed=0 ingested=0

    # 1. Discover new or updated candidate skills in target repo.
    # Note: Source repo (ainish-coder) NEVER has tools/skills removed.
    local -a candidate_list=()
    local target_skill target_name
    for target_skill in "$skills_target"/*/; do
        [[ -d "$target_skill" ]] || continue
        target_name="$(basename "$target_skill")"
        _ainish_skill_excluded "$target_name" && continue

        if [[ ! -d "$skills_source/$target_name" ]]; then
            candidate_list+=("$target_name:new")
        elif ! _ainish_skill_identical "$skills_source/$target_name" "$target_skill"; then
            if [[ "$(_ainish_skill_newer "$target_skill" "$skills_source/$target_name")" == "1" ]]; then
                candidate_list+=("$target_name:updated")
            fi
        fi
    done

    # 2. Prompt operator to select which candidate skills to ingest into ainish-coder.
    _SELECTED_CANDIDATES=()
    if (( ${#candidate_list[@]} > 0 )); then
        _select_candidate_skills "${candidate_list[@]}"
        local selected_item s_name s_kind
        for selected_item in "${_SELECTED_CANDIDATES[@]}"; do
            s_name="${selected_item%%:*}"
            s_kind="${selected_item##*:}"
            local t_path="$skills_target/$s_name"
            local s_path="$skills_source/$s_name"

            if [[ "$s_kind" == "new" ]]; then
                deploy_path "$t_path" "$s_path" 2>/dev/null || {
                    print_error "Failed to ingest new skill: $s_name"
                    continue
                }
                echo -e "${BRIGHT_GREEN}➕ Ingested new skill: $s_name → ainish-coder${RESET}"
                ((ingested++)) || true
            else
                rm -rf "$s_path"
                deploy_path "$t_path" "$s_path" 2>/dev/null || {
                    print_error "Failed to update skill from target: $s_name"
                    continue
                }
                echo -e "${GREEN}⬆ Pulled updated skill: $s_name → ainish-coder${RESET}"
                ((ingested++)) || true
            fi
        done
    fi

    # 2. Deploy or update ainish-coder skills into target repo per persisted selection.
    local source_skill source_name
    for source_skill in "$skills_source"/*/; do
        [[ -d "$source_skill" ]] || continue
        source_name="$(basename "$source_skill")"
        _ainish_skill_excluded "$source_name" && continue

        # Persisted per-repo selection governs sync: deselected packs are skipped.
        if [[ "$(skills_selection_state "$target_dir" "$source_name")" != "on" ]]; then
            continue
        fi

        if [[ ! -d "$skills_target/$source_name" ]]; then
            # Missing at target -> deploy
            deploy_path "$source_skill" "$skills_target/$source_name" 2>/dev/null || {
                print_error "Failed to deploy skill: $source_name"
                return 1
            }
            echo -e "${GREEN}✓ Deployed: $source_name → $target_dir${RESET}"
            ((deployed++)) || true
        elif _ainish_skill_identical "$source_skill" "$skills_target/$source_name"; then
            ((identical++)) || true
        else
            # Source is newer or equal -> update target
            rm -rf "$skills_target/$source_name"
            deploy_path "$source_skill" "$skills_target/$source_name" 2>/dev/null || {
                print_error "Failed to sync skill: $source_name"
                return 1
            }
            echo -e "${GREEN}⬇ Updated: $source_name at $target_dir${RESET}"
            ((updated++)) || true
        fi
    done

    # Stamp provenance so future verify/sync runs resolve this repo.
    printf '%s\n' "$source_dir" > "$skills_target/.ainish-source"

    echo -e "${BRIGHT_GREEN}✅ Skills synced: identical=$identical deployed=$deployed updated=$updated ingested=$ingested.${RESET}"
    return 0
}
