#!/bin/bash
# MOLECULE: Windsurf deployment
# Copies AGENTS.md and MAIRULES.md to .windsurf/rules/
# Requires AGENTS.md and MAIRULES.md to exist first

deploy_windsurf() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    require_mairules_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Windsurf configuration${RESET}"
    
    local windsurf_dir="$target_dir/.windsurf/rules"
    if ! mkdir -p "$windsurf_dir" 2>/dev/null; then
        echo -e "${BRIGHT_RED}Error: Failed to create .windsurf/rules directory${RESET}"
        return 1
    fi
    
    if cp "$target_dir/AGENTS.md" "$windsurf_dir/AGENTS.md"; then
        echo -e "${GREEN}✓ Copied: AGENTS.md → .windsurf/rules/AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy AGENTS.md${RESET}"
        return 1
    fi
    
    if cp "$target_dir/MAIRULES.md" "$windsurf_dir/MAIRULES.md"; then
        echo -e "${GREEN}✓ Copied: MAIRULES.md → .windsurf/rules/MAIRULES.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy MAIRULES.md${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Windsurf configured${RESET}"
    return 0
}
