#!/bin/bash
# MOLECULE: Gitignore deployment
# Creates a comprehensive .gitignore file for AI-assisted development projects
# Includes patterns for AI tools, environments, and common development artifacts
# If target already has .gitignore, merges unique patterns (no duplicates)

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
    
    # If no existing .gitignore, just copy the source
    if [[ ! -f "$gitignore_file" ]]; then
        if cp "$source_gitignore" "$gitignore_file" 2>/dev/null; then
            echo -e "${GREEN}✓ Deployed .gitignore to $target_dir${RESET}"
            echo -e "${BRIGHT_GREEN}✅ Gitignore configured${RESET}"
            return 0
        else
            echo -e "${BRIGHT_RED}Error: Failed to deploy .gitignore${RESET}"
            return 1
        fi
    fi
    
    # Existing .gitignore found - merge unique patterns
    echo -e "${YELLOW}⚠️  Existing .gitignore found - merging unique patterns${RESET}"
    
    local temp_file=$(mktemp)
    local existing_patterns_file=$(mktemp)
    
    # Start with our source template
    cp "$source_gitignore" "$temp_file"
    
    # Extract non-empty, non-comment lines from existing .gitignore for comparison
    # Normalize by trimming whitespace for pattern matching
    grep -v '^[[:space:]]*$' "$gitignore_file" 2>/dev/null | \
        grep -v '^[[:space:]]*#' | \
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
        sort -u > "$existing_patterns_file"
    
    # Extract patterns from our source template (for duplicate detection)
    local source_patterns_file=$(mktemp)
    grep -v '^[[:space:]]*$' "$source_gitignore" 2>/dev/null | \
        grep -v '^[[:space:]]*#' | \
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
        sort -u > "$source_patterns_file"
    
    # Find patterns in existing .gitignore that are NOT in our source
    local unique_patterns_file=$(mktemp)
    comm -23 "$existing_patterns_file" "$source_patterns_file" > "$unique_patterns_file"
    
    # If there are unique patterns from the existing file, append them
    if [[ -s "$unique_patterns_file" ]]; then
        local unique_count=$(wc -l < "$unique_patterns_file" | tr -d ' ')
        echo -e "${BRIGHT_BLUE}Found $unique_count unique patterns in existing .gitignore${RESET}"
        
        # Add separator and append unique patterns
        {
            echo ""
            echo "# ═══════════════════════════════════════════════════════════════════════════"
            echo "# Project-specific patterns (preserved from existing .gitignore)"
            echo "# ═══════════════════════════════════════════════════════════════════════════"
            echo ""
            cat "$unique_patterns_file"
            echo ""
        } >> "$temp_file"
    else
        echo -e "${GREEN}No additional unique patterns found in existing .gitignore${RESET}"
    fi
    
    # Move merged file to target
    if mv "$temp_file" "$gitignore_file" 2>/dev/null; then
        echo -e "${GREEN}✓ Deployed merged .gitignore to $target_dir${RESET}"
        echo -e "${BRIGHT_GREEN}✅ Gitignore configured (merged)${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to deploy merged .gitignore${RESET}"
        rm -f "$temp_file"
        rm -f "$existing_patterns_file" "$source_patterns_file" "$unique_patterns_file"
        return 1
    fi
    
    # Cleanup temp files
    rm -f "$existing_patterns_file" "$source_patterns_file" "$unique_patterns_file"
    
    return 0
}
