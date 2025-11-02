#!/bin/bash
# MOLECULE: Gemini deployment
# Copies AGENTS.md and MAIRULES.md to .gemini/
# Requires AGENTS.md and MAIRULES.md to exist first

deploy_gemini() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    require_mairules_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Gemini CLI configuration${RESET}"
    
    local gemini_dir="$target_dir/.gemini"
    safe_mkdir "$gemini_dir" || return 1
    
    if cp "$target_dir/AGENTS.md" "$gemini_dir/AGENTS.md"; then
        echo -e "${GREEN}✓ Copied: AGENTS.md → .gemini/AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy AGENTS.md${RESET}"
        return 1
    fi
    
    if cp "$target_dir/MAIRULES.md" "$gemini_dir/MAIRULES.md"; then
        echo -e "${GREEN}✓ Copied: MAIRULES.md → .gemini/MAIRULES.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy MAIRULES.md${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Gemini CLI configured${RESET}"
    return 0
}

