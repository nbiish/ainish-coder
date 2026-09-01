#!/bin/bash
# MOLECULE: Skills deployment
# Deploys all skills from .agents/skills/ directory to target project
# In non-overwrite mode, skips skills that already exist at the target

deploy_skills() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    validate_target_dir "$target_dir" || return 1

    # Self-deploy guard: distributing into the ainish-coder repo itself
    # would rm/cp source packs onto themselves (destroying them). Ainish
    # skills already live here — nothing to distribute.
    if [[ "$(cd "$target_dir" 2>/dev/null && pwd)" == "$source_dir" ]]; then
        echo -e "${YELLOW}ℹ Target is the ainish-coder source repo itself — skills already live here, nothing to distribute.${RESET}"
        return 0
    fi

    local skills_source="$source_dir/.agents/skills"
    local skills_target="$target_dir/.agents/skills"

    if [[ ! -d "$skills_source" ]]; then
        print_error "Skills source directory not found: $skills_source"
        return 1
    fi

    local mode_label="Deploying"
    if [[ "${AINISH_NO_OVERWRITE:-false}" == "true" ]]; then
        mode_label="Adding missing"
    fi
    echo -e "${BRIGHT_BLUE}${mode_label} Skills${RESET}"

    # Detect pre-existing skills at target for intelligent reporting
    local pre_existing_skills=()
    if [[ -d "$skills_target" ]]; then
        for existing_dir in "$skills_target"/*/; do
            if [[ -d "$existing_dir" ]]; then
                pre_existing_skills+=($(basename "$existing_dir"))
            fi
        done
    fi

    safe_mkdir "$skills_target" || return 1
    local skill_count=0
    local skipped_count=0
    local deselected_count=0

    for skill_dir in "$skills_source"/*/; do
        if [[ -d "$skill_dir" ]]; then
            local skill_name=$(basename "$skill_dir")
            local target_skill_dir="$skills_target/$skill_name"

            # Scroll-channel packs (8thfire-scrolls, ghost-layer-injector) and
            # raw .scrolls* payload never deploy with skills — the explicit
            # --scrolls channel is their only distribution surface.
            case "$skill_name" in .scrolls*|8thfire-scrolls|ghost-layer-injector) continue ;; esac

            # Persisted per-repo selection governs distribution. Live intake:
            # packs are enumerated from disk each run, so new/renamed packs
            # resolve through the repo default policy automatically.
            if [[ "$(skills_selection_state "$target_dir" "$skill_name")" != "on" ]]; then
                # OFF = not distributed. Remove a previously-shipped copy so a
                # toggle-off takes effect immediately (foreign packs at the
                # target are never touched — this name exists in source, so it
                # is ainish-managed).
                if [[ -d "$target_skill_dir" && "${AINISH_NO_OVERWRITE:-false}" != "true" ]]; then
                    rm -rf "$target_skill_dir"
                    echo -e "${YELLOW}⊘ Deselected — removed prior copy: $skill_name${RESET}"
                else
                    echo -e "${YELLOW}⊘ Deselected (not deployed): $skill_name${RESET}"
                fi
                ((deselected_count++)) || true
                continue
            fi

            # In non-overwrite mode, skip entire skill directory if it already exists
            if [[ "${AINISH_NO_OVERWRITE:-false}" == "true" ]]; then
                if [[ -d "$target_skill_dir" ]]; then
                    echo -e "${YELLOW}⏭️  Skipping (already exists): .agents/skills/$skill_name${RESET}"
                    ((skipped_count++)) || true
                    continue
                fi
            fi

            safe_mkdir "$target_skill_dir" || return 1
            deploy_path_contents "$skill_dir" "$target_skill_dir" 2>/dev/null || true
            # Pin the distribution: an explicit config entry per deployed pack
            # makes later renames/deletions at source detectable as stale.
            skills_selection_set "$target_dir" "$skill_name" on

            ((skill_count++))
            echo -e "${GREEN}✓ Deployed: .agents/skills/$skill_name${RESET}"
        fi
    done

    # Live intake sweep: handle RENAMES and DELETIONS. A target pack whose
    # name no longer exists at source is stale IF it was ainish-managed —
    # decided by a recorded preference in the persisted config (renamed/
    # deleted packs keep their old entry). Purely foreign packs (never
    # toggled, no config entry) are kept untouched.
    if [[ -d "$skills_target" && "${AINISH_NO_OVERWRITE:-false}" != "true" ]]; then
        local sweep_name sweep_dir
        for sweep_dir in "$skills_target"/*/; do
            [[ -d "$sweep_dir" ]] || continue
            sweep_name="$(basename "$sweep_dir")"
            [[ -d "$skills_source/$sweep_name" ]] && continue
            if skills_selection_has_entry "$target_dir" "$sweep_name"; then
                rm -rf "$sweep_dir"
                echo -e "${YELLOW}⊘ Stale (renamed/deleted at source) — removed: $sweep_name${RESET}"
                ((deselected_count++)) || true
            fi
        done
    fi

    # Stamp provenance so --skills-verify / --skills-sync resolve this repo.
    printf '%s\n' "$source_dir" > "$skills_target/.ainish-source"

    # Summary
    if [[ $skill_count -gt 0 ]]; then
        echo -e "${BRIGHT_GREEN}✅ Deployed $skill_count skill(s) to $skills_target${RESET}"
    fi
    if [[ $skipped_count -gt 0 ]]; then
        echo -e "${YELLOW}⏭️  Skipped $skipped_count pre-existing skill(s)${RESET}"
    fi
    if [[ $deselected_count -gt 0 ]]; then
        echo -e "${YELLOW}⊘ $deselected_count deselected pack(s) skipped (toggled off — run 'ainish-coder --skills' to change)${RESET}"
    fi

    if [[ $skill_count -eq 0 && $skipped_count -eq 0 ]]; then
        echo -e "${YELLOW}⚠ No skills found to deploy${RESET}"
    fi

    return 0
}
