#!/bin/bash
# MOLECULE: Claude Code deployment
# Comprehensive Claude Code configuration deployment:
# - AGENTS.md and MAIRULES.md to .claude/rules/
# - Commands from .configs/.claude/commands/
# Requires AGENTS.md to exist first

deploy_claude() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Full Claude Code Configuration${RESET}"
    
    # Create directory structure
    local claude_rules_dir="$target_dir/.claude/rules"
    local claude_commands_dir="$target_dir/.claude/commands"
    safe_mkdir "$claude_rules_dir" || return 1
    safe_mkdir "$claude_commands_dir" || return 1
    
    # Deploy rules
    if cp "$target_dir/AGENTS.md" "$claude_rules_dir/AGENTS.md"; then
        echo -e "${GREEN}✓ Copied: AGENTS.md → .claude/rules/AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy AGENTS.md${RESET}"
        return 1
    fi
    
    if [[ -f "$target_dir/MAIRULES.md" ]]; then
        cp "$target_dir/MAIRULES.md" "$claude_rules_dir/MAIRULES.md"
        echo -e "${GREEN}✓ Copied: MAIRULES.md → .claude/rules/MAIRULES.md${RESET}"
    fi
    
    # Deploy commands from .configs
    if [[ -d "$source_dir/.configs/.claude/commands" ]]; then
        local cmd_count=0
        for cmd_file in "$source_dir/.configs/.claude/commands"/*.md; do
            if [[ -f "$cmd_file" ]]; then
                local filename=$(basename "$cmd_file")
                cp "$cmd_file" "$claude_commands_dir/$filename"
                ((cmd_count++))
                echo -e "${GREEN}✓ Deployed: .claude/commands/$filename${RESET}"
            fi
        done
        if [[ $cmd_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $cmd_count Claude Code command(s)${RESET}"
        fi
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Claude Code fully configured${RESET}"
    echo -e "${BLUE}💡 Commands available via / in Claude Code${RESET}"
    return 0
}
