#!/bin/bash
# MOLECULE: Qwen deployment
# Symlinks QWEN.md to AGENTS.md
# Requires AGENTS.md to exist first

deploy_qwen() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Qwen Code CLI configuration${RESET}"
    
    local qwen_file="$target_dir/QWEN.md"
    
    # Remove existing
    if [[ -L "$qwen_file" ]]; then
        rm "$qwen_file"
    elif [[ -f "$qwen_file" ]]; then
        mv "$qwen_file" "$qwen_file.backup"
        echo -e "${YELLOW}Backed up existing QWEN.md${RESET}"
    fi
    
    # Create symlink
    if ln -s "AGENTS.md" "$qwen_file" 2>/dev/null; then
        echo -e "${GREEN}✓ Symlinked: QWEN.md → AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to create symlink${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Qwen Code CLI configured${RESET}"
    return 0
}

