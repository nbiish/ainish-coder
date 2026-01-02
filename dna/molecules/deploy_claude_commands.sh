#!/bin/bash
# MOLECULE: Claude Code slash commands deployment
# Deploys prompt files to .claude/commands/ directory
# Based on research: Claude Code uses .claude/commands/*.md format

deploy_claude_commands() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Claude Code slash commands${RESET}"
    
    local claude_dir="$target_dir/.claude"
    local commands_dir="$claude_dir/commands"
    
    safe_mkdir "$commands_dir" || return 1
    
    # Deploy prompt files from .github/prompts to .claude/commands
    if [[ -d "$source_dir/.github/prompts" ]]; then
        local prompt_count=0
        
        for prompt_file in "$source_dir/.github/prompts"/*.prompt.md; do
            if [[ -f "$prompt_file" ]]; then
                local filename=$(basename "$prompt_file" .prompt.md)
                local target_file="$commands_dir/${filename}.md"
                
                # Strip YAML frontmatter for Claude Code (prefers plain markdown)
                if command -v sed &> /dev/null; then
                    # Remove YAML frontmatter (between --- markers)
                    sed '/^---$/,/^---$/d' "$prompt_file" > "$target_file"
                else
                    # Fallback: copy as-is
                    cp "$prompt_file" "$target_file"
                fi
                
                ((prompt_count++))
                echo -e "${GREEN}✓ Deployed: ${filename}.md${RESET}"
            fi
        done
        
        if [[ $prompt_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $prompt_count Claude Code command(s)${RESET}"
            echo -e "${BLUE}💡 Access with / in Claude Code chat${RESET}"
        else
            echo -e "${YELLOW}⚠ No prompt files found to deploy${RESET}"
        fi
    else
        echo -e "${YELLOW}⚠ Source prompts directory not found: $source_dir/.github/prompts${RESET}"
        return 1
    fi
    
    return 0
}
