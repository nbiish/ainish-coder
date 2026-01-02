#!/bin/bash
# MOLECULE: Deploy slash commands/prompts for AI coding tools
# Handles deployment of .github/prompts to tool-specific directories

# Source the prompt deployment molecules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/deploy_cursor_commands.sh"
source "${SCRIPT_DIR}/deploy_claude_commands.sh"
source "${SCRIPT_DIR}/deploy_continue_prompts.sh"
source "${SCRIPT_DIR}/deploy_windsurf_prompts.sh"
source "${SCRIPT_DIR}/deploy_cline_prompts.sh"
source "${SCRIPT_DIR}/deploy_roocode_prompts.sh"
# CLI tools
source "${SCRIPT_DIR}/deploy_gemini_cli_prompts.sh"
source "${SCRIPT_DIR}/deploy_goose_prompts.sh"
source "${SCRIPT_DIR}/deploy_qwen_cli_prompts.sh"

deploy_commands() {
    local tool="$1"
    local target_dir="${2:-$(pwd)}"
    
    # Validate input
    if [[ -z "$tool" ]]; then
        print_error "Missing tool argument"
        echo "" >&2
        echo "Usage: ainish-coder --commands TOOL [TARGET_DIR]" >&2
        echo "" >&2
        echo "IDE Extensions (File-Based Commands):" >&2
        echo "  cursor      Deploy to .cursor/commands/ (plain markdown)" >&2
        echo "  roocode     Deploy to .roo/commands/ (markdown with frontmatter)" >&2
        echo "" >&2
        echo "IDE Extensions (Workflows):" >&2
        echo "  windsurf    Deploy to .windsurf/workflows/ (markdown workflows)" >&2
        echo "  cline       Deploy to .clinerules/workflows/ (markdown workflows)" >&2
        echo "" >&2
        echo "IDE Extensions (Config-Based):" >&2
        echo "  continue    Provides config.yaml setup guide" >&2
        echo "" >&2
        echo "CLI Tools (TOML Commands):" >&2
        echo "  gemini-cli  Deploy to .gemini/commands/ (TOML files)" >&2
        echo "  qwen        Deploy to .qwen/commands/ (TOML files)" >&2
        echo "" >&2
        echo "CLI Tools (Recipes):" >&2
        echo "  goose       Deploy to .goose/recipes/ (YAML recipes)" >&2
        echo "" >&2
        echo "Other:" >&2
        echo "  copilot     Use --copilot flag instead" >&2
        echo "  all         Deploy to all supported tools (8 tools)" >&2
        echo "" >&2
        return 1
    fi
    
    case "$tool" in
        # IDE Extensions
        cursor)
            deploy_cursor_commands "$target_dir"
            ;;
        claude|claude-code)
            deploy_claude_commands "$target_dir"
            ;;
        continue|cn)
            deploy_continue_prompts "$target_dir"
            ;;
        windsurf)
            deploy_windsurf_prompts "$target_dir"
            ;;
        cline)
            deploy_cline_prompts "$target_dir"
            ;;
        roocode|roo)
            deploy_roocode_prompts "$target_dir"
            ;;
        copilot)
            echo -e "${BLUE}ℹ Use 'ainish-coder --copilot' to deploy Copilot prompts${RESET}"
            return 0
            ;;
            
        # CLI Tools
        gemini-cli|gemini)
            deploy_gemini_cli_prompts "$target_dir"
            ;;
        goose)
            deploy_goose_prompts "$target_dir"
            ;;
        qwen|qwen-cli)
            deploy_qwen_cli_prompts "$target_dir"
            ;;
            
        # Deploy all
        all)
            echo -e "${BRIGHT_BLUE}Deploying to all supported tools${RESET}"
            local success=0
            local total=8
            
            echo -e "${CYAN}--- File-Based Commands ---${RESET}"
            deploy_cursor_commands "$target_dir" && ((success++))
            deploy_roocode_prompts "$target_dir" && ((success++))
            
            echo ""
            echo -e "${CYAN}--- Workflows ---${RESET}"
            deploy_windsurf_prompts "$target_dir" && ((success++))
            deploy_cline_prompts "$target_dir" && ((success++))
            
            echo ""
            echo -e "${CYAN}--- Config-Based ---${RESET}"
            deploy_continue_prompts "$target_dir" && ((success++))
            
            echo ""
            echo -e "${CYAN}--- CLI TOML Commands ---${RESET}"
            deploy_gemini_cli_prompts "$target_dir" && ((success++))
            deploy_qwen_cli_prompts "$target_dir" && ((success++))
            
            echo ""
            echo -e "${CYAN}--- CLI Recipes ---${RESET}"
            deploy_goose_prompts "$target_dir" && ((success++))
            
            echo ""
            echo -e "${BRIGHT_GREEN}✅ Deployed to $success/$total tools${RESET}"
            echo -e "${BLUE}💡 GitHub Copilot: Use 'ainish-coder --copilot' separately${RESET}"
            ;;
        *)
            print_error "Unknown tool: $tool"
            echo "Use 'ainish-coder --commands --help' for available tools" >&2
            return 1
            ;;
    esac
}
