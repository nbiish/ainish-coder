#!/bin/bash
# MOLECULE: Windsurf deployment
# Comprehensive Windsurf configuration deployment:
# - AGENTS.md and MAIRULES.md to .windsurf/rules/
# - Workflows from .configs/.windsurf/workflows/
# Requires AGENTS.md and MAIRULES.md to exist first

deploy_windsurf() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    require_mairules_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Full Windsurf Configuration${RESET}"
    
    # Create directory structure
    local windsurf_rules_dir="$target_dir/.windsurf/rules"
    local windsurf_workflows_dir="$target_dir/.windsurf/workflows"
    safe_mkdir "$windsurf_rules_dir" || return 1
    safe_mkdir "$windsurf_workflows_dir" || return 1
    
    # Deploy rules
    if cp "$target_dir/AGENTS.md" "$windsurf_rules_dir/AGENTS.md"; then
        echo -e "${GREEN}✓ Copied: AGENTS.md → .windsurf/rules/AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy AGENTS.md${RESET}"
        return 1
    fi
    
    if cp "$target_dir/MAIRULES.md" "$windsurf_rules_dir/MAIRULES.md"; then
        echo -e "${GREEN}✓ Copied: MAIRULES.md → .windsurf/rules/MAIRULES.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy MAIRULES.md${RESET}"
        return 1
    fi
    
    # Deploy workflows from .configs
    if [[ -d "$source_dir/.configs/.windsurf/workflows" ]]; then
        local workflow_count=0
        for workflow_file in "$source_dir/.configs/.windsurf/workflows"/*.md; do
            if [[ -f "$workflow_file" ]]; then
                local filename=$(basename "$workflow_file")
                cp "$workflow_file" "$windsurf_workflows_dir/$filename"
                ((workflow_count++))
                echo -e "${GREEN}✓ Deployed: .windsurf/workflows/$filename${RESET}"
            fi
        done
        if [[ $workflow_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $workflow_count Windsurf workflow(s)${RESET}"
        fi
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Windsurf fully configured${RESET}"
    echo -e "${BLUE}💡 Workflows available in Windsurf${RESET}"
    return 0
}
