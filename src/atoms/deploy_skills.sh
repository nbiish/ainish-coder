#!/bin/bash
# MOLECULE: Skills deployment
# Deploys all skills from .agents/skills/ directory to target project
# In non-overwrite mode, skips skills that already exist at the target

deploy_skills() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    validate_target_dir "$target_dir" || return 1

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

    for skill_dir in "$skills_source"/*/; do
        if [[ -d "$skill_dir" ]]; then
            local skill_name=$(basename "$skill_dir")
            local target_skill_dir="$skills_target/$skill_name"

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

            ((skill_count++))
            echo -e "${GREEN}✓ Deployed: .agents/skills/$skill_name${RESET}"
        fi
    done

    # Summary
    if [[ $skill_count -gt 0 ]]; then
        echo -e "${BRIGHT_GREEN}✅ Deployed $skill_count skill(s) to $skills_target${RESET}"
    fi
    if [[ $skipped_count -gt 0 ]]; then
        echo -e "${YELLOW}⏭️  Skipped $skipped_count pre-existing skill(s)${RESET}"
    fi

    if [[ $skill_count -eq 0 && $skipped_count -eq 0 ]]; then
        echo -e "${YELLOW}⚠ No skills found to deploy${RESET}"
    fi

    return 0
}
