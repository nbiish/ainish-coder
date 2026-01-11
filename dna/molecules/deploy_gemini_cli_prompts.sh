#!/bin/bash
# MOLECULE: Gemini CLI custom slash commands deployment
# Deploys prompt files to .gemini/commands/ directory as TOML files
# Based on research: Gemini CLI uses .toml files (NOT markdown) for custom commands
# Reference: https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/commands.md

deploy_gemini_cli_prompts() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Gemini CLI custom slash commands${RESET}"
    
    local gemini_dir="$target_dir/.gemini"
    local commands_dir="$gemini_dir/commands"
    
    safe_mkdir "$commands_dir" || return 1
    
    # Deploy prompt files from .github/prompts and convert to TOML format
    if [[ -d "$source_dir/.github/prompts" ]]; then
        local command_count=0
        
        for prompt_file in "$source_dir/.github/prompts"/*.prompt.md; do
            if [[ -f "$prompt_file" ]]; then
                local filename=$(basename "$prompt_file" .prompt.md)
                local target_file="$commands_dir/${filename}.toml"
                
                # Extract YAML frontmatter for description
                local description=""
                if command -v sed &> /dev/null && command -v awk &> /dev/null; then
                    description=$(sed -n '/^---$/,/^---$/p' "$prompt_file" | grep "^description:" | sed 's/^description: *//' | tr -d '"')
                fi
                
                # Extract prompt content (without YAML frontmatter)
                local prompt_content=""
                if command -v sed &> /dev/null; then
                    prompt_content=$(sed '/^---$/,/^---$/d' "$prompt_file")
                else
                    prompt_content=$(cat "$prompt_file")
                fi
                
                # Create TOML file format
                # Note: Using triple-quoted string for multi-line prompt
                {
                    echo "# ${filename} - Gemini CLI Custom Command"
                    echo "# Generated from ainish-coder prompts"
                    echo ""
                    if [[ -n "$description" ]]; then
                        echo "description = \"$description\""
                        echo ""
                    fi
                    echo "prompt = \"\"\""
                    echo "$prompt_content"
                    echo "\"\"\""
                } > "$target_file"
                
                ((command_count++))
                echo -e "${GREEN}✓ Deployed: /${filename}${RESET}"
            fi
        done
        
        if [[ $command_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $command_count Gemini CLI command(s)${RESET}"
            echo -e "${BLUE}💡 Type / in Gemini CLI to see available commands${RESET}"
            echo -e "${BLUE}📁 Commands stored as .toml files in .gemini/commands/${RESET}"
            echo -e "${BLUE}� Example: /code-judge, /secure-code, /secure-prompts${RESET}"
        else
            echo -e "${YELLOW}⚠ No prompt files found to deploy${RESET}"
        fi
    else
        echo -e "${YELLOW}⚠ Source prompts directory not found: $source_dir/.github/prompts${RESET}"
        return 1
    fi
    
    return 0
}
