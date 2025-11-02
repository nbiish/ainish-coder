#!/bin/bash
# MOLECULE: GitHub Copilot deployment
# Symlinks .github/copilot-instructions.md to AGENTS.md
# Requires AGENTS.md to exist first

deploy_copilot() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying GitHub Copilot configuration${RESET}"
    
    local github_dir="$target_dir/.github"
    safe_mkdir "$github_dir" || return 1
    
    local copilot_instructions="$github_dir/copilot-instructions.md"
    
    # Remove existing
    if [[ -L "$copilot_instructions" ]]; then
        rm "$copilot_instructions"
    elif [[ -f "$copilot_instructions" ]]; then
        mv "$copilot_instructions" "$copilot_instructions.backup"
        echo -e "${YELLOW}Backed up existing copilot-instructions.md${RESET}"
    fi
    
    # Create symlink
    if ln -s "../AGENTS.md" "$copilot_instructions" 2>/dev/null; then
        echo -e "${GREEN}✓ Symlinked: .github/copilot-instructions.md → AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to create symlink${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}✅ GitHub Copilot configured${RESET}"
    return 0
}

