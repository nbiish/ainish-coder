#!/bin/bash
# MOLECULE: Roo Code deployment
# Comprehensive Roo Code configuration deployment:
# - AGENTS.md and MAIRULES.md to .roo/rules/
# - Commands from .configs/.roo/commands/
# - Ignore files
# Requires AGENTS.md and MAIRULES.md to exist first

deploy_roocode() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    require_mairules_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Full Roo Code Configuration${RESET}"
    
    # Create directory structure
    local roo_rules_dir="$target_dir/.roo/rules"
    local roo_commands_dir="$target_dir/.roo/commands"
    safe_mkdir "$roo_rules_dir" || return 1
    safe_mkdir "$roo_commands_dir" || return 1
    
    # Deploy rules
    if cp "$target_dir/AGENTS.md" "$roo_rules_dir/AGENTS.md"; then
        echo -e "${GREEN}✓ Copied: AGENTS.md → .roo/rules/AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy AGENTS.md${RESET}"
        return 1
    fi
    
    if cp "$target_dir/MAIRULES.md" "$roo_rules_dir/MAIRULES.md"; then
        echo -e "${GREEN}✓ Copied: MAIRULES.md → .roo/rules/MAIRULES.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy MAIRULES.md${RESET}"
        return 1
    fi
    
    # Deploy commands from .configs
    if [[ -d "$source_dir/.configs/.roo/commands" ]]; then
        local cmd_count=0
        for cmd_file in "$source_dir/.configs/.roo/commands"/*.md; do
            if [[ -f "$cmd_file" ]]; then
                local filename=$(basename "$cmd_file")
                cp "$cmd_file" "$roo_commands_dir/$filename"
                ((cmd_count++))
                echo -e "${GREEN}✓ Deployed: .roo/commands/$filename${RESET}"
            fi
        done
        if [[ $cmd_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $cmd_count Roo Code command(s)${RESET}"
        fi
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Roo Code fully configured${RESET}"
    echo -e "${BLUE}💡 Commands available in Roo Code${RESET}"
    return 0
}
