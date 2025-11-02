#!/bin/bash
# MOLECULE: Continue Dev deployment
# Symlinks .continue/rules/AGENTS.md to AGENTS.md
# Requires AGENTS.md to exist first

deploy_continue() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Continue.dev configuration${RESET}"
    
    local continue_dir="$target_dir/.continue/rules"
    safe_mkdir "$continue_dir" || return 1
    
    local continue_agents="$continue_dir/AGENTS.md"
    
    # Remove existing
    if [[ -L "$continue_agents" ]]; then
        rm "$continue_agents"
    elif [[ -f "$continue_agents" ]]; then
        mv "$continue_agents" "$continue_agents.backup"
    fi
    
    # Create symlink
    if ln -s "../../AGENTS.md" "$continue_agents" 2>/dev/null; then
        echo -e "${GREEN}✓ Symlinked: .continue/rules/AGENTS.md → AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to create symlink${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Continue.dev configured${RESET}"
    return 0
}

