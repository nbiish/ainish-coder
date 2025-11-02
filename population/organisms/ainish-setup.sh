#!/bin/bash
# Main ainish-coder setup script (Matter layer)

set -euo pipefail

# Get script directory and load atoms
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Load atoms
source "${SCRIPT_DIR}/../atoms/colors.sh"
source "${SCRIPT_DIR}/../atoms/paths.sh"
source "${SCRIPT_DIR}/../atoms/file_operations.sh"
source "${SCRIPT_DIR}/../atoms/validation.sh"
source "${SCRIPT_DIR}/../atoms/backup.sh"

# Load molecules
source "${SCRIPT_DIR}/../molecules/help.sh"
source "${SCRIPT_DIR}/../molecules/deploy_commands.sh"

# Main function
main() {
    local command="$1"
    shift
    
    case "$command" in
        --help|-h)
            show_help
            ;;
        --version|-v)
            show_version
            ;;
        --commands)
            if [[ $# -eq 0 ]]; then
                print_error "Missing argument for --commands"
                echo "Usage: ainish-coder --commands TARGET_ARG" >&2
                exit 1
            fi
            deploy_commands "$1"
            ;;
        *)
            print_error "Unknown command: $command"
            echo "Use 'ainish-coder --help' for usage information" >&2
            exit 1
            ;;
    esac
}

# Check if at least one argument provided
if [[ $# -eq 0 ]]; then
    print_error "No command specified"
    echo "Use 'ainish-coder --help' for usage information" >&2
    exit 1
fi

# Run main function
main "$@"
