#!/bin/bash
# MOLECULE: Roo Code slash commands deployment
# Deploys prompt files to .roo/commands/ directory as slash commands
# Based on research: Roo Code uses .roo/commands/*.md with optional YAML frontmatter
# Supports description and argument-hint fields in frontmatter

deploy_roocode_prompts() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Roo Code slash commands${RESET}"
    
    local roo_dir="$target_dir/.roo"
    local commands_dir="$roo_dir/commands"
    
    safe_mkdir "$commands_dir" || return 1
    
    # Deploy prompt files from .github/prompts to .roo/commands
    if [[ -d "$source_dir/.github/prompts" ]]; then
        local command_count=0
        
        for prompt_file in "$source_dir/.github/prompts"/*.prompt.md; do
            if [[ -f "$prompt_file" ]]; then
                local filename=$(basename "$prompt_file" .prompt.md)
                local target_file="$commands_dir/${filename}.md"
                
                # Roo Code KEEPS YAML frontmatter (supports description and argument-hint)
                cp "$prompt_file" "$target_file"
                
                ((command_count++))
                echo -e "${GREEN}✓ Deployed: /${filename}${RESET}"
            fi
        done
        
        if [[ $command_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $command_count Roo Code slash command(s)${RESET}"
            echo -e "${BLUE}💡 Type / in chat to see available commands${RESET}"
            echo -e "${BLUE}📁 Commands stored in .roo/commands/ directory${RESET}"
        else
            echo -e "${YELLOW}⚠ No prompt files found to deploy${RESET}"
        fi
    else
        echo -e "${YELLOW}⚠ Source prompts directory not found: $source_dir/.github/prompts${RESET}"
        return 1
    fi
    
    return 0
}
