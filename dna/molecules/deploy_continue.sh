#!/bin/bash
# MOLECULE: Continue Dev deployment
# Copies AGENTS.md and MAIRULES.md to .continue/rules/
# Requires AGENTS.md to exist first

deploy_continue() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Continue.dev configuration${RESET}"
    
    local continue_dir="$target_dir/.continue/rules"
    safe_mkdir "$continue_dir" || return 1
    
    local agents_source="$target_dir/AGENTS.md"
    local agents_dest="$continue_dir/AGENTS.md"
    
    # Backup existing file
    if [[ -f "$agents_dest" ]]; then
        mv "$agents_dest" "$agents_dest.backup"
        echo -e "${YELLOW}Backed up existing .continue/rules/AGENTS.md${RESET}"
    fi
    
    # Copy AGENTS.md
    if cp "$agents_source" "$agents_dest" 2>/dev/null; then
        echo -e "${GREEN}✓ Copied: .continue/rules/AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy AGENTS.md${RESET}"
        return 1
    fi
    
    # Copy MAIRULES.md if it exists
    if [[ -f "$target_dir/MAIRULES.md" ]]; then
        local mairules_dest="$continue_dir/MAIRULES.md"
        if [[ -f "$mairules_dest" ]]; then
            mv "$mairules_dest" "$mairules_dest.backup"
        fi
        if cp "$target_dir/MAIRULES.md" "$mairules_dest" 2>/dev/null; then
            echo -e "${GREEN}✓ Copied: .continue/rules/MAIRULES.md${RESET}"
        fi
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Continue.dev configured${RESET}"
    return 0
}

