#!/bin/bash
# MOLECULE: Skills deployment
# Deploys all skills from .agents/skills/ directory to target project

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

    echo -e "${BRIGHT_BLUE}Deploying Skills${RESET}"

    safe_mkdir "$skills_target" || return 1
    local skill_count=0

    for skill_dir in "$skills_source"/*/; do
        if [[ -d "$skill_dir" ]]; then
            local skill_name=$(basename "$skill_dir")
            local target_skill_dir="$skills_target/$skill_name"

            safe_mkdir "$target_skill_dir" || return 1
            cp -r "$skill_dir"* "$target_skill_dir/" 2>/dev/null || true

            ((skill_count++))
            echo -e "${GREEN}✓ Deployed: .agents/skills/$skill_name${RESET}"
        fi
    done

    if [[ $skill_count -gt 0 ]]; then
        echo -e "${BRIGHT_GREEN}✅ Deployed $skill_count skill(s) to $skills_target${RESET}"
    else
        echo -e "${YELLOW}⚠ No skills found to deploy${RESET}"
    fi

    return 0
}
