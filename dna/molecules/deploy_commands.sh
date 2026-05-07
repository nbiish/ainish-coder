#!/bin/bash
# MOLECULE: Deploy slash commands/prompts for AI coding tools
# Handles deployment of .github/prompts to tool-specific directories

# Source the prompt deployment molecules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/deploy_claude_commands.sh"
source "${SCRIPT_DIR}/deploy_continue_prompts.sh"

deploy_commands() {
    local tool="$1"
    local target_dir="${2:-$(pwd)}"
    
    # Validate input
    if [[ -z "$tool" ]]; then
        print_error "Missing tool argument"
        echo "" >&2
        echo "Usage: ainish-coder --commands TOOL [TARGET_DIR]" >&2
        echo "" >&2
        echo "IDE Extensions (Config-Based):" >&2
        echo "  continue    Provides config.yaml setup guide" >&2
        echo "" >&2
        echo "Other:" >&2
        echo "  copilot     Use --copilot flag instead" >&2
        echo "  all         Deploy to all supported tools" >&2
        echo "" >&2
        return 1
    fi
    
    case "$tool" in
        # IDE Extensions
        claude|claude-code)
            deploy_claude_commands "$target_dir"
            ;;
        continue|cn)
            deploy_continue_prompts "$target_dir"
            ;;
        copilot)
            echo -e "${BLUE}ℹ Use 'ainish-coder --copilot' to deploy Copilot prompts${RESET}"
            return 0
            ;;
            
        # Deploy all
        all)
            echo -e "${BRIGHT_BLUE}Deploying to all supported tools${RESET}"
            local success=0
            local total=2

            echo -e "${CYAN}--- File-Based Commands ---${RESET}"
            deploy_claude_commands "$target_dir" && ((success++))

            echo ""
            echo -e "${CYAN}--- Config-Based ---${RESET}"
            deploy_continue_prompts "$target_dir" && ((success++))

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
