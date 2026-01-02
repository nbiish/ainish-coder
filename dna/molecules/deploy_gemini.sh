#!/bin/bash
# MOLECULE: Gemini deployment
# Comprehensive Gemini CLI configuration deployment:
# - AGENTS.md and MAIRULES.md to .gemini/
# - Commands from .configs/.gemini/commands/
# Requires AGENTS.md and MAIRULES.md to exist first

deploy_gemini() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    require_mairules_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Full Gemini CLI Configuration${RESET}"
    
    # Create directory structure
    local gemini_dir="$target_dir/.gemini"
    local gemini_commands_dir="$gemini_dir/commands"
    safe_mkdir "$gemini_dir" || return 1
    safe_mkdir "$gemini_commands_dir" || return 1
    
    # Deploy rules
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
    
    # Deploy commands from .configs
    if [[ -d "$source_dir/.configs/.gemini/commands" ]]; then
        local cmd_count=0
        for cmd_file in "$source_dir/.configs/.gemini/commands"/*.toml; do
            if [[ -f "$cmd_file" ]]; then
                local filename=$(basename "$cmd_file")
                cp "$cmd_file" "$gemini_commands_dir/$filename"
                ((cmd_count++))
                echo -e "${GREEN}✓ Deployed: .gemini/commands/$filename${RESET}"
            fi
        done
        if [[ $cmd_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $cmd_count Gemini command(s)${RESET}"
        fi
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Gemini CLI fully configured${RESET}"
    echo -e "${BLUE}💡 Commands available in Gemini CLI${RESET}"
    return 0
}

