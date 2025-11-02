#!/bin/bash
# MOLECULE: Roo Code deployment
# Copies AGENTS.md and MAIRULES.md to .roo/rules/
# Requires AGENTS.md and MAIRULES.md to exist first

deploy_roocode() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    require_mairules_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Roo Code configuration${RESET}"
    
    local roo_dir="$target_dir/.roo/rules"
    if ! mkdir -p "$roo_dir" 2>/dev/null; then
        echo -e "${BRIGHT_RED}Error: Failed to create .roo/rules directory${RESET}"
        return 1
    fi
    
    if cp "$target_dir/AGENTS.md" "$roo_dir/AGENTS.md"; then
        echo -e "${GREEN}✓ Copied: AGENTS.md → .roo/rules/AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy AGENTS.md${RESET}"
        return 1
    fi
    
    if cp "$target_dir/MAIRULES.md" "$roo_dir/MAIRULES.md"; then
        echo -e "${GREEN}✓ Copied: MAIRULES.md → .roo/rules/MAIRULES.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy MAIRULES.md${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Roo Code configured${RESET}"
    return 0
}
