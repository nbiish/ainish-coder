#!/bin/bash
# MOLECULE: Cursor deployment
# Comprehensive Cursor configuration deployment:
# - AGENTS.md and MAIRULES.md to .cursor/rules/
# - Slash commands from .configs/.cursor/commands/
# - Ignore files
# Requires AGENTS.md and MAIRULES.md to exist first

deploy_cursor() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    require_mairules_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Full Cursor Configuration${RESET}"
    
    # Create directory structure
    local cursor_rules_dir="$target_dir/.cursor/rules"
    local cursor_commands_dir="$target_dir/.cursor/commands"
    safe_mkdir "$cursor_rules_dir" || return 1
    safe_mkdir "$cursor_commands_dir" || return 1
    
    # Deploy rules
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
    
    # Deploy commands from .configs
    if [[ -d "$source_dir/.configs/.cursor/commands" ]]; then
        local cmd_count=0
        for cmd_file in "$source_dir/.configs/.cursor/commands"/*.md; do
            if [[ -f "$cmd_file" ]]; then
                local filename=$(basename "$cmd_file")
                cp "$cmd_file" "$cursor_commands_dir/$filename"
                ((cmd_count++))
                echo -e "${GREEN}✓ Deployed: .cursor/commands/$filename${RESET}"
            fi
        done
        if [[ $cmd_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $cmd_count Cursor command(s)${RESET}"
        fi
    fi
    
    # Deploy ignore files
    if [[ -f "$source_dir/.cursorignore" ]]; then
        if cp "$source_dir/.cursorignore" "$target_dir/.cursorignore" 2>/dev/null || [[ -f "$target_dir/.cursorignore" ]]; then
            echo -e "${GREEN}✓ Deployed: .cursorignore${RESET}"
        fi
    fi
    
    if [[ -f "$source_dir/.cursorindexignore" ]]; then
        if cp "$source_dir/.cursorindexignore" "$target_dir/.cursorindexignore" 2>/dev/null || [[ -f "$target_dir/.cursorindexignore" ]]; then
            echo -e "${GREEN}✓ Deployed: .cursorindexignore${RESET}"
        fi
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Cursor fully configured${RESET}"
    echo -e "${BLUE}💡 Commands available via Cmd+K in Cursor${RESET}"
    return 0
}
