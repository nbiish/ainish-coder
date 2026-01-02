#!/bin/bash
# Molecule: Deploy .copilotignore
# Deploys GitHub Copilot ignore file to target directory

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ATOMS_DIR="${SCRIPT_DIR}/../atoms"

# Source required atoms
source "${ATOMS_DIR}/colors.sh"
source "${ATOMS_DIR}/validation.sh"
source "${ATOMS_DIR}/file_operations.sh"
source "${ATOMS_DIR}/backup.sh"
source "${ATOMS_DIR}/ignore_patterns.sh"

# Deploy .copilotignore file
deploy_copilot_ignore() {
    local target_dir="${1:-.}"
    
    echo -e "${BRIGHT_BLUE}Deploying GitHub Copilot Ignore File${RESET}"
    
    # Validate target directory
    if ! validate_target_dir "$target_dir"; then
        echo -e "${BRIGHT_RED}✗ Invalid target directory: $target_dir${RESET}"
        return 1
    fi
    
    local copilot_ignore_file="${target_dir}/.copilotignore"
    
    # Backup existing file if present
    if [[ -f "$copilot_ignore_file" ]]; then
        echo -e "${YELLOW}→ Backing up existing .copilotignore${RESET}"
        create_backup "$copilot_ignore_file"
    fi
    
    # Generate and write the ignore file
    echo -e "${CYAN}→ Creating .copilotignore${RESET}"
    generate_ignore_file "copilot" > "$copilot_ignore_file"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ .copilotignore deployed to $target_dir${RESET}"
        echo -e "${CYAN}  File: $copilot_ignore_file${RESET}"
        echo -e "${CYAN}  Note: Copilot also respects .gitignore patterns${RESET}"
        return 0
    else
        echo -e "${BRIGHT_RED}✗ Failed to create .copilotignore${RESET}"
        return 1
    fi
}

# If script is run directly (not sourced), execute deployment
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    deploy_copilot_ignore "$@"
fi
