#!/bin/bash
# MOLECULE: Continue Dev deployment
# Comprehensive Continue.dev configuration deployment:
# - AGENTS.md and MAIRULES.md to .continue/rules/
# - Prompts from .configs/.continue/prompts/
# - Ignore files
# Requires AGENTS.md to exist first

deploy_continue() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Full Continue.dev Configuration${RESET}"
    
    # Create directory structure
    local continue_rules_dir="$target_dir/.continue/rules"
    local continue_prompts_dir="$target_dir/.continue/prompts"
    safe_mkdir "$continue_rules_dir" || return 1
    safe_mkdir "$continue_prompts_dir" || return 1
    
    local agents_source="$target_dir/AGENTS.md"
    local agents_dest="$continue_rules_dir/AGENTS.md"
    
    # Backup existing file
    if [[ -f "$agents_dest" ]]; then
        mv "$agents_dest" "$agents_dest.backup"
        echo -e "${YELLOW}Backed up existing .continue/rules/AGENTS.md${RESET}"
    fi
    
    # Copy AGENTS.md
    if cp "$agents_source" "$agents_dest" 2>/dev/null; then
        echo -e "${GREEN}✓ Copied: .continue/rules/AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy AGENTS.md${RESET}"
        return 1
    fi
    
    # Copy MAIRULES.md if it exists
    if [[ -f "$target_dir/MAIRULES.md" ]]; then
        local mairules_dest="$continue_rules_dir/MAIRULES.md"
        if [[ -f "$mairules_dest" ]]; then
            mv "$mairules_dest" "$mairules_dest.backup"
        fi
        if cp "$target_dir/MAIRULES.md" "$mairules_dest" 2>/dev/null; then
            echo -e "${GREEN}✓ Copied: .continue/rules/MAIRULES.md${RESET}"
        fi
    fi
    
    # Deploy prompts from .configs
    if [[ -d "$source_dir/.configs/.continue/prompts" ]]; then
        local prompt_count=0
        for prompt_file in "$source_dir/.configs/.continue/prompts"/*.prompt.md; do
            if [[ -f "$prompt_file" ]]; then
                local filename=$(basename "$prompt_file")
                cp "$prompt_file" "$continue_prompts_dir/$filename"
                ((prompt_count++))
                echo -e "${GREEN}✓ Deployed: .continue/prompts/$filename${RESET}"
            fi
        done
        # Also copy SETUP_GUIDE if it exists
        if [[ -f "$source_dir/.configs/.continue/prompts/SETUP_GUIDE.md" ]]; then
            cp "$source_dir/.configs/.continue/prompts/SETUP_GUIDE.md" "$continue_prompts_dir/SETUP_GUIDE.md"
            echo -e "${GREEN}✓ Deployed: .continue/prompts/SETUP_GUIDE.md${RESET}"
        fi
        if [[ $prompt_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $prompt_count Continue prompt(s)${RESET}"
        fi
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Continue.dev fully configured${RESET}"
    echo -e "${BLUE}💡 Prompts available via / commands in Continue${RESET}"
    return 0
}

