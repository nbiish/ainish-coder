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
    
    # Deploy copilot-instructions.md
    local copilot_instructions="$github_dir/copilot-instructions.md"
    local source_instructions="$source_dir/.github/copilot-instructions.md"
    
    if [[ -f "$source_instructions" ]]; then
        cp "$source_instructions" "$copilot_instructions"
        echo -e "${GREEN}✓ Deployed: copilot-instructions.md${RESET}"
    else
        echo -e "${YELLOW}⚠ Warning: copilot-instructions.md not found in source${RESET}"
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

