#!/bin/bash
# Molecule: Deploy .cursorignore
# Deploys Cursor IDE ignore file to target directory

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ATOMS_DIR="${SCRIPT_DIR}/../atoms"

# Source required atoms
source "${ATOMS_DIR}/colors.sh"
source "${ATOMS_DIR}/validation.sh"
source "${ATOMS_DIR}/file_operations.sh"
source "${ATOMS_DIR}/backup.sh"
source "${ATOMS_DIR}/ignore_patterns.sh"

# Deploy .cursorignore file
deploy_cursor_ignore() {
    local target_dir="${1:-.}"
    
    echo -e "${BRIGHT_BLUE}Deploying Cursor Ignore File${RESET}"
    
    # Validate target directory
    if ! validate_target_dir "$target_dir"; then
        echo -e "${BRIGHT_RED}✗ Invalid target directory: $target_dir${RESET}"
        return 1
    fi
    
    local cursor_ignore_file="${target_dir}/.cursorignore"
    
    # Backup existing file if present
    if [[ -f "$cursor_ignore_file" ]]; then
        echo -e "${YELLOW}→ Backing up existing .cursorignore${RESET}"
        create_backup "$cursor_ignore_file"
    fi
    
    # Generate and write the ignore file
    echo -e "${CYAN}→ Creating .cursorignore${RESET}"
    generate_ignore_file "cursor" > "$cursor_ignore_file"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ .cursorignore deployed to $target_dir${RESET}"
        echo -e "${CYAN}  File: $cursor_ignore_file${RESET}"
        return 0
    else
        echo -e "${BRIGHT_RED}✗ Failed to create .cursorignore${RESET}"
        return 1
    fi
}

# If script is run directly (not sourced), execute deployment
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    deploy_cursor_ignore "$@"
fi
