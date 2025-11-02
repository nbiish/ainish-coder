#!/bin/bash
# MOLECULE: AGENTS.md deployment
# Copies MAIRULES.md to AGENTS.md at project root
# AGENTS.md is the universal standard for AI pair programmers

deploy_agents() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying AGENTS.md${RESET}"
    
    local source="${REPO_DIR}/MAIRULES.md"
    local dest="$target_dir/AGENTS.md"
    
    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: MAIRULES.md not found at $source${RESET}"
        return 1
    fi
    
    # Copy MAIRULES.md to AGENTS.md
    if ! cp "$source" "$dest" 2>/dev/null; then
        echo -e "${BRIGHT_RED}Error: Failed to create AGENTS.md${RESET}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Created AGENTS.md at $target_dir${RESET}"
    echo -e "${BRIGHT_GREEN}✅ AGENTS.md is ready for all AI tools${RESET}"
    
    return 0
}
