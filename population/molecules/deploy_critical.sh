#!/bin/bash
# MOLECULE: Critical rules deployment
# Symlinks critical.md from TIER_0 to project root

deploy_critical() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying critical.md${RESET}"
    
    local source="${REPO_DIR}/TIER_0_RULES/docs-protocol.md"
    local dest="$target_dir/critical.md"
    
    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: critical.md not found at $source${RESET}"
        return 1
    fi
    
    # Remove existing symlink or file
    if [[ -L "$dest" ]]; then
        rm "$dest"
    elif [[ -f "$dest" ]]; then
        mv "$dest" "$dest.backup"
        echo -e "${YELLOW}Backed up existing critical.md${RESET}"
    fi
    
    # Create symlink
    if ln -s "$source" "$dest" 2>/dev/null; then
        echo -e "${GREEN}✓ Created symlink: critical.md → TIER_0/critical.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to create symlink${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}✅ critical.md deployed${RESET}"
    return 0
}
