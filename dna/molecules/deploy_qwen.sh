#!/bin/bash
# MOLECULE: Qwen deployment
# Comprehensive Qwen CLI configuration deployment:
# - Copies AGENTS.md to QWEN.md
# - Copies AGENTS.md and MAIRULES.md to .qwen/
# - Commands from .configs/.qwen/commands/
# Requires AGENTS.md to exist first

deploy_qwen() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Full Qwen Code CLI Configuration${RESET}"
    
    local agents_file="$target_dir/AGENTS.md"
    local qwen_file="$target_dir/QWEN.md"
    
    # Backup existing file
    if [[ -f "$qwen_file" ]]; then
        mv "$qwen_file" "$qwen_file.backup"
        echo -e "${YELLOW}Backed up existing QWEN.md${RESET}"
    fi
    
    # Copy AGENTS.md to QWEN.md
    if cp "$agents_file" "$qwen_file" 2>/dev/null; then
        echo -e "${GREEN}✓ Copied: QWEN.md from AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy to QWEN.md${RESET}"
        return 1
    fi
    
    # Create .qwen directory structure
    local qwen_dir="$target_dir/.qwen"
    local qwen_commands_dir="$qwen_dir/commands"
    safe_mkdir "$qwen_dir" || return 1
    safe_mkdir "$qwen_commands_dir" || return 1
    
    # Deploy rules to .qwen
    if cp "$target_dir/AGENTS.md" "$qwen_dir/AGENTS.md"; then
        echo -e "${GREEN}✓ Copied: AGENTS.md → .qwen/AGENTS.md${RESET}"
    fi
    
    if [[ -f "$target_dir/MAIRULES.md" ]]; then
        cp "$target_dir/MAIRULES.md" "$qwen_dir/MAIRULES.md"
        echo -e "${GREEN}✓ Copied: MAIRULES.md → .qwen/MAIRULES.md${RESET}"
    fi
    
    # Deploy commands from .configs
    if [[ -d "$source_dir/.configs/.qwen/commands" ]]; then
        local cmd_count=0
        for cmd_file in "$source_dir/.configs/.qwen/commands"/*.toml; do
            if [[ -f "$cmd_file" ]]; then
                local filename=$(basename "$cmd_file")
                cp "$cmd_file" "$qwen_commands_dir/$filename"
                ((cmd_count++))
                echo -e "${GREEN}✓ Deployed: .qwen/commands/$filename${RESET}"
            fi
        done
        if [[ $cmd_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $cmd_count Qwen command(s)${RESET}"
        fi
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Qwen Code CLI fully configured${RESET}"
    echo -e "${BLUE}💡 Commands available in Qwen CLI${RESET}"
    return 0
}

