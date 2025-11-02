#!/bin/bash
# MOLECULE: Cline deployment
# Copies AGENTS.md and MAIRULES.md to .clinerules/
# Requires AGENTS.md and MAIRULES.md to exist first

deploy_cline() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    require_mairules_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Cline configuration${RESET}"
    
    local cline_dir="$target_dir/.clinerules"
    if ! mkdir -p "$cline_dir" 2>/dev/null; then
        echo -e "${BRIGHT_RED}Error: Failed to create .clinerules directory${RESET}"
        return 1
    fi
    
    if cp "$target_dir/AGENTS.md" "$cline_dir/AGENTS.md"; then
        echo -e "${GREEN}✓ Copied: AGENTS.md → .clinerules/AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy AGENTS.md${RESET}"
        return 1
    fi
    
    if cp "$target_dir/MAIRULES.md" "$cline_dir/MAIRULES.md"; then
        echo -e "${GREEN}✓ Copied: MAIRULES.md → .clinerules/MAIRULES.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy MAIRULES.md${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Cline configured${RESET}"
    return 0
}
