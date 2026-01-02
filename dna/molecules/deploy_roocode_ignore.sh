#!/bin/bash
# Molecule: Deploy .rooignore
# Deploys Roo Code ignore file to target directory

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ATOMS_DIR="${SCRIPT_DIR}/../atoms"

# Source required atoms
source "${ATOMS_DIR}/colors.sh"
source "${ATOMS_DIR}/validation.sh"
source "${ATOMS_DIR}/file_operations.sh"
source "${ATOMS_DIR}/backup.sh"
source "${ATOMS_DIR}/ignore_patterns.sh"

# Deploy .rooignore file
deploy_roocode_ignore() {
    local target_dir="${1:-.}"
    
    echo -e "${BRIGHT_BLUE}Deploying Roo Code Ignore File${RESET}"
    
    # Validate target directory
    if ! validate_target_dir "$target_dir"; then
        echo -e "${BRIGHT_RED}✗ Invalid target directory: $target_dir${RESET}"
        return 1
    fi
    
    local roo_ignore_file="${target_dir}/.rooignore"
    
    # Backup existing file if present
    if [[ -f "$roo_ignore_file" ]]; then
        echo -e "${YELLOW}→ Backing up existing .rooignore${RESET}"
        create_backup "$roo_ignore_file"
    fi
    
    # Generate and write the ignore file
    echo -e "${CYAN}→ Creating .rooignore${RESET}"
    generate_ignore_file "roocode" > "$roo_ignore_file"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ .rooignore deployed to $target_dir${RESET}"
        echo -e "${CYAN}  File: $roo_ignore_file${RESET}"
        echo -e "${CYAN}  Note: Files excluded by .rooignore but not by .gitignore${RESET}"
        echo -e "${CYAN}        will still be checkpointed for undo functionality${RESET}"
        return 0
    else
        echo -e "${BRIGHT_RED}✗ Failed to create .rooignore${RESET}"
        return 1
    fi
}

# If script is run directly (not sourced), execute deployment
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    deploy_roocode_ignore "$@"
fi
