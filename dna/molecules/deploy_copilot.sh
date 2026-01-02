#!/bin/bash
# MOLECULE: GitHub Copilot deployment
# Deploys copilot-instructions.md and command prompts
# Requires AGENTS.md to exist first

deploy_copilot() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying GitHub Copilot configuration${RESET}"
    
    local github_dir="$target_dir/.github"
    safe_mkdir "$github_dir" || return 1
    
    # Create empty copilot-instructions.md (VS Code/Copilot reads AGENTS.md directly)
    local copilot_instructions="$github_dir/copilot-instructions.md"
    
    if [[ ! -f "$copilot_instructions" ]]; then
        touch "$copilot_instructions"
        echo -e "${GREEN}✓ Created: copilot-instructions.md${RESET}"
    else
        echo -e "${GREEN}✓ Already exists: copilot-instructions.md${RESET}"
    fi
    
    # Deploy MAIRULES.md as MAIRULES.instructions.md
    local mairules_instructions="$github_dir/MAIRULES.instructions.md"
    local source_mairules="$source_dir/MAIRULES.md"
    
    if [[ -f "$source_mairules" ]]; then
        cp "$source_mairules" "$mairules_instructions"
        echo -e "${GREEN}✓ Deployed: MAIRULES.instructions.md${RESET}"
    else
        echo -e "${YELLOW}⚠ Warning: MAIRULES.md not found in source${RESET}"
    fi
    
    # Deploy command prompts
    local prompts_dir="$github_dir/prompts"
    safe_mkdir "$prompts_dir" || return 1
    
    if [[ -d "$source_dir/.github/prompts" ]]; then
        cp "$source_dir/.github/prompts"/*.prompt.md "$prompts_dir/" 2>/dev/null
        local prompt_count=$(ls -1 "$prompts_dir"/*.prompt.md 2>/dev/null | wc -l)
        if [[ $prompt_count -gt 0 ]]; then
            echo -e "${GREEN}✓ Deployed: $prompt_count command prompt(s)${RESET}"
        fi
    fi
    
    echo -e "${BRIGHT_GREEN}✅ GitHub Copilot configured${RESET}"
    return 0
}

