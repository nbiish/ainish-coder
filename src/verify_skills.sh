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

    echo -e "${BRIGHT_BLUE}Syncing ainish-coder skills → $skills_target (verify + pull latest)${RESET}"
    safe_mkdir "$skills_target" || return 1

    local skill updated=0 identical=0 foreign=0
    for skill in "$skills_source"/*/; do
        [[ -d "$skill" ]] || continue
        local name
        name="$(basename "$skill")"

        # Scrolls skill is explicit-channel only — never copied here.
        if _ainish_skill_excluded "$name"; then
            continue
        fi

        # Persisted per-repo selection governs sync: deselected packs are
        # never pulled or repaired (live intake — state resolved per run).
        if [[ "$(skills_selection_state "$target_dir" "$name")" != "on" ]]; then
            continue
        fi

        if _ainish_skill_identical "$skill" "$skills_target/$name"; then
            ((identical++)) || true
            continue
        fi

        rm -rf "$skills_target/$name"
        deploy_path "$skill" "$skills_target/$name" 2>/dev/null || {
            print_error "Failed to sync skill: $name"
            return 1
        }
        echo -e "${GREEN}⬇ pulled latest: $name${RESET}"
        ((updated++)) || true
    done

    # Foreign skills at target — reported, never overwritten.
    for skill in "$skills_target"/*/; do
        [[ -d "$skill" ]] || continue
        local name
        name="$(basename "$skill")"
        _ainish_skill_excluded "$name" && continue
        if [[ ! -d "$skills_source/$name" ]]; then
            echo -e "${YELLOW}◦ foreign (kept): $name${RESET}"
            ((foreign++)) || true
        fi
    done

    # Stamp provenance so future verify/sync runs resolve this repo.
    printf '%s\n' "$source_dir" > "$skills_target/.ainish-source"

    echo -e "${BRIGHT_GREEN}✅ Skills synced: identical=$identical updated=$updated foreign-kept=$foreign. Foreign + scrolls untouched.${RESET}"
    return 0
}
