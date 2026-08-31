#!/bin/bash
# MOLECULE: Skills byte-integrity (verify + safe sync)
# verify_ainish_skills : report byte-identity of managed skills vs this repo
# sync_ainish_skills   : refresh ONLY ainish-coder-managed skills; foreign
#                        skills and the scrolls skill are never touched.

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
        .scrolls*|8thfire-scrolls) return 0 ;;
        *) return 1 ;;
    esac
}

# Byte-compare one skill directory tree (symlinks to source are identical).
_ainish_skill_identical() {
    local src="$1" dst="$2"
    [[ -L "$dst" ]] && [[ "$(cd "$(dirname "$dst")" && cd "$(readlink "$dst")" 2>/dev/null && pwd)" == "$src" ]] && return 0
    [[ -d "$dst" ]] || return 1
    diff -r "$src" "$dst" >/dev/null 2>&1
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

    echo -e "${BRIGHT_BLUE}Syncing ainish-coder skills → $skills_target${RESET}"
    safe_mkdir "$skills_target" || return 1

    local skill updated=0 skipped=0
    for skill in "$skills_source"/*/; do
        [[ -d "$skill" ]] || continue
        local name
        name="$(basename "$skill")"

        # Scrolls skill is explicit-channel only — never copied here.
        if _ainish_skill_excluded "$name"; then
            echo -e "${YELLOW}⏭️  skipped (scrolls channel): $name${RESET}"
            ((skipped++)) || true
            continue
        fi

        # Foreign skill at target — never overwritten.
        if [[ -d "$skills_target/$name" && ! -d "$skills_source/$name" ]]; then
            continue
        fi

        if _ainish_skill_identical "$skill" "$skills_target/$name"; then
            echo -e "${GREEN}✓ already identical: $name${RESET}"
            continue
        fi

        rm -rf "$skills_target/$name"
        deploy_path "$skill" "$skills_target/$name" 2>/dev/null || {
            print_error "Failed to sync skill: $name"
            return 1
        }
        echo -e "${GREEN}✓ synced: $name${RESET}"
        ((updated++)) || true
    done

    # Stamp provenance so future verify/sync runs resolve this repo.
    printf '%s\n' "$source_dir" > "$skills_target/.ainish-source"

    echo -e "${BRIGHT_GREEN}✅ Synced $updated skill(s), skipped $skipped scroll skill(s). Foreign skills untouched.${RESET}"
    return 0
}
