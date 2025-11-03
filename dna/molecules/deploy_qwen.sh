#!/bin/bash
# MOLECULE: Qwen deployment
# Copies AGENTS.md to QWEN.md
# Requires AGENTS.md to exist first

deploy_qwen() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Qwen Code CLI configuration${RESET}"
    
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
    
    echo -e "${BRIGHT_GREEN}✅ Qwen Code CLI configured${RESET}"
    return 0
}

