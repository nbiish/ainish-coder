#!/bin/bash
# MOLECULE: Deploy slash commands/prompts for AI coding tools
# Handles deployment of .github/prompts to tool-specific directories

# Source the prompt deployment molecules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

deploy_commands() {
    local tool="$1"
    local target_dir="${2:-$(pwd)}"
    
    # Validate input
    if [[ -z "$tool" ]]; then
        print_error "Missing tool argument"
        echo "" >&2
        echo "Usage: ainish-coder --commands TOOL [TARGET_DIR]" >&2
        echo "" >&2
        echo "Other:" >&2
        echo "  all         Deploy to all supported tools" >&2
        echo "" >&2
        return 1
    fi
    
    case "$tool" in
        # Deploy all
        all)
            echo -e "${BRIGHT_BLUE}Deploying to all supported tools${RESET}"
            local success=0
            local total=0

            echo -e "${CYAN}--- File-Based Commands ---${RESET}"
            echo -e "No tools currently support file-based commands."
            echo ""
            ;;
        *)
            print_error "Unknown tool: $tool"
            echo "Use 'ainish-coder --help' for a list of supported tools." >&2
            return 1
            ;;
    esac
    
    return 0
}
