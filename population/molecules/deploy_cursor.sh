#!/bin/bash
# MOLECULE: Cursor deployment
# Copies AGENTS.md and MAIRULES.md to .cursor/rules/
# Requires AGENTS.md and MAIRULES.md to exist first

deploy_cursor() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    require_mairules_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Cursor configuration${RESET}"
    
    local cursor_rules_dir="$target_dir/.cursor/rules"
    safe_mkdir "$cursor_rules_dir" || return 1
    
    if cp "$target_dir/AGENTS.md" "$cursor_rules_dir/AGENTS.md"; then
        echo -e "${GREEN}✓ Copied: AGENTS.md → .cursor/rules/AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy AGENTS.md${RESET}"
        return 1
    fi
    
    if cp "$target_dir/MAIRULES.md" "$cursor_rules_dir/MAIRULES.md"; then
        echo -e "${GREEN}✓ Copied: MAIRULES.md → .cursor/rules/MAIRULES.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy MAIRULES.md${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Cursor configured${RESET}"
    return 0
}
