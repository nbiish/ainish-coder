#!/bin/bash
# Molecule: Deploy .clineignore
# Deploys Cline VSCode extension ignore file to target directory

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ATOMS_DIR="${SCRIPT_DIR}/../atoms"

# Source required atoms
source "${ATOMS_DIR}/colors.sh"
source "${ATOMS_DIR}/validation.sh"
source "${ATOMS_DIR}/file_operations.sh"
source "${ATOMS_DIR}/backup.sh"
source "${ATOMS_DIR}/ignore_patterns.sh"

# Deploy .clineignore file
deploy_cline_ignore() {
    local target_dir="${1:-.}"
    
    echo -e "${BRIGHT_BLUE}Deploying Cline Ignore File${RESET}"
    
    # Validate target directory
    if ! validate_target_dir "$target_dir"; then
        echo -e "${BRIGHT_RED}✗ Invalid target directory: $target_dir${RESET}"
        return 1
    fi
    
    local cline_ignore_file="${target_dir}/.clineignore"
    
    # Backup existing file if present
    if [[ -f "$cline_ignore_file" ]]; then
        echo -e "${YELLOW}→ Backing up existing .clineignore${RESET}"
        create_backup "$cline_ignore_file"
    fi
    
    # Generate and write the ignore file
    echo -e "${CYAN}→ Creating .clineignore${RESET}"
    generate_ignore_file "cline" > "$cline_ignore_file"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ .clineignore deployed to $target_dir${RESET}"
        echo -e "${CYAN}  File: $cline_ignore_file${RESET}"
        echo -e "${CYAN}  Tip: Use '!include .gitignore' directive to include .gitignore patterns${RESET}"
        return 0
    else
        echo -e "${BRIGHT_RED}✗ Failed to create .clineignore${RESET}"
        return 1
    fi
}

# If script is run directly (not sourced), execute deployment
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    deploy_cline_ignore "$@"
fi
