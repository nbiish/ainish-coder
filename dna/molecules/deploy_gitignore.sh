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
        
        # Merge any entries from backup that aren't in the new .gitignore
        if [[ -n "${backup_file:-}" && -f "$backup_file" ]]; then
            echo -e "${BRIGHT_BLUE}Merging unique entries from backup...${RESET}"
            # Find lines in backup that aren't in the new .gitignore and append them
            local unique_entries
            unique_entries=$(comm -13 <(grep -v '^$' "$gitignore_file" | sort) <(grep -v '^$' "$backup_file" | sort) 2>/dev/null || true)
            if [[ -n "$unique_entries" ]]; then
                echo "" >> "$gitignore_file"
                echo "# Preserved from previous .gitignore" >> "$gitignore_file"
                echo "$unique_entries" >> "$gitignore_file"
                echo -e "${GREEN}✓ Merged $(echo "$unique_entries" | wc -l | tr -d ' ') unique entries from backup${RESET}"
            else
                echo -e "${YELLOW}No unique entries to merge from backup${RESET}"
            fi
        fi
        
        echo -e "${BRIGHT_GREEN}✅ Gitignore configured${RESET}"
        return 0
    else
        echo -e "${BRIGHT_RED}Error: Failed to deploy .gitignore${RESET}"
        return 1
    fi
}
