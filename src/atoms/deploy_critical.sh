#!/bin/bash
# MOLECULE: Critical rules deployment
# Copies critical.md from repo root to project root

deploy_critical() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying critical.md${RESET}"
    
    local source="${REPO_DIR}/critical.md"
    local dest="$target_dir/critical.md"
    
    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: critical.md not found at $source${RESET}"
        return 1
    fi
    
    # Backup existing file if it exists
    if [[ -f "$dest" ]]; then
        mv "$dest" "$dest.backup"
        echo -e "${YELLOW}Backed up existing critical.md${RESET}"
    fi
    
    # Copy file
    if cp "$source" "$dest" 2>/dev/null; then
        echo -e "${GREEN}✓ Copied: critical.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy critical.md${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}✅ critical.md deployed${RESET}"
    return 0
}
