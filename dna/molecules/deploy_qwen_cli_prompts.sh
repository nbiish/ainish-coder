#!/bin/bash
# MOLECULE: Qwen Code CLI custom slash commands deployment  
# Deploys prompt files to .qwen/commands/ directory as TOML files
# Based on research: Qwen Code is forked from Gemini CLI and uses .toml format
# Reference: https://github.com/QwenLM/Qwen-Code

deploy_qwen_cli_prompts() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Qwen Code CLI custom slash commands${RESET}"
    
    local qwen_dir="$target_dir/.qwen"
    local commands_dir="$qwen_dir/commands"
    
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
                
                # Create TOML file format (same as Gemini CLI)
                {
                    echo "# ${filename} - Qwen Code CLI Custom Command"
                    echo "# Generated from ainish-coder prompts"
                    echo "# Optimized for Qwen3-Coder models"
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
            echo -e "${BRIGHT_GREEN}✅ Deployed $command_count Qwen Code CLI command(s)${RESET}"
            echo -e "${BLUE}💡 Type / in Qwen Code CLI to see available commands${RESET}"
            echo -e "${BLUE}📁 Commands stored as .toml files in .qwen/commands/${RESET}"
            echo -e "${BLUE}📖 Example: /code-judge, /secure-code, /secure-prompts${RESET}"
        else
            echo -e "${YELLOW}⚠ No prompt files found to deploy${RESET}"
        fi
    else
        echo -e "${YELLOW}⚠ Source prompts directory not found: $source_dir/.github/prompts${RESET}"
        return 1
    fi
    
    return 0
}
