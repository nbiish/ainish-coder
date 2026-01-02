#!/bin/bash
# MOLECULE: Gitignore deployment
# Creates a comprehensive .gitignore file for AI-assisted development projects
# Includes patterns for AI tools, environments, and common development artifacts

deploy_gitignore() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying .gitignore configuration${RESET}"
    
    local gitignore_file="$target_dir/.gitignore"
    local source_gitignore="${REPO_DIR}/.gitignore"
    
    # Check if source .gitignore exists
    if [[ ! -f "$source_gitignore" ]]; then
        echo -e "${BRIGHT_RED}Error: Source .gitignore not found at ${source_gitignore}${RESET}"
        return 1
    fi
    
    # Backup existing .gitignore if it exists
    if [[ -f "$gitignore_file" ]]; then
        local backup_file=$(create_backup "$gitignore_file")
        if [[ $? -eq 0 ]]; then
            echo -e "${YELLOW}⚠️  Backed up existing .gitignore to: $backup_file${RESET}"
        else
            echo -e "${BRIGHT_RED}Error: Failed to backup existing .gitignore${RESET}"
            return 1
        fi
    fi
    
    # Copy .gitignore from repository root
    if cp "$source_gitignore" "$gitignore_file" 2>/dev/null; then
        echo -e "${GREEN}✓ Deployed .gitignore to $target_dir${RESET}"
        echo -e "${BRIGHT_GREEN}✅ Gitignore configured${RESET}"
        return 0
    else
        echo -e "${BRIGHT_RED}Error: Failed to deploy .gitignore${RESET}"
        return 1
    fi
}
