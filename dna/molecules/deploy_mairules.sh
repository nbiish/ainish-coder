#!/bin/bash
# MOLECULE: MAI RULES deployment
# Concatenates all TIER_*_RULES/*.md files and creates/appends to MAIRULES.md in current working directory

# Deploy MAIRULES.md with only TIER_0 (essential/critical rules)
deploy_mairules_tier0() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying MAIRULES.md with TIER_0 (essential rules)${RESET}"
    
    local dest="$target_dir/MAIRULES.md"
    local temp_file=$(mktemp)
    
    # If MAIRULES.md already exists, warn user
    if [[ -f "$dest" ]]; then
        echo -e "${YELLOW}⚠️  MAIRULES.md already exists - will be overwritten${RESET}"
    fi
    
    # Only process TIER_0_RULES
    local tier_path="${REPO_DIR}/TIER_0_RULES"
    local files_found=0
    
    if [[ ! -d "$tier_path" ]]; then
        echo -e "${BRIGHT_RED}Error: TIER_0_RULES directory not found${RESET}"
        rm -f "$temp_file"
        return 1
    fi
    
    echo -e "${BRIGHT_BLUE}Processing TIER_0 (Critical)...${RESET}"
    
    # Add tier header
    echo "## TIER_0: Critical Documentation Protocol" >> "$temp_file"
    echo "" >> "$temp_file"
    
    # Find all .md files in TIER_0_RULES directory and concatenate them
    while IFS= read -r -d '' md_file; do
        if [[ -f "$md_file" ]]; then
            echo -e "${GREEN}  ✓ Adding $(basename "$md_file")${RESET}"
            echo "# $(basename "$md_file" .md)" >> "$temp_file"
            echo "" >> "$temp_file"
            cat "$md_file" >> "$temp_file"
            echo "" >> "$temp_file"
            echo "" >> "$temp_file"
            ((files_found++))
        fi
    done < <(find "$tier_path" -maxdepth 1 -name "*.md" -type f -print0 | sort -z)
    
    # Move temp file to destination
    if [[ $files_found -gt 0 ]]; then
        mv "$temp_file" "$dest"
        echo -e "${GREEN}✓ Deployed MAIRULES.md to $target_dir${RESET}"
        echo -e "${BRIGHT_GREEN}✅ MAIRULES.md created with TIER_0 ($files_found file(s))${RESET}"
        echo -e "${CYAN}💡 Use 'ainish-coder --tier {1-4}' to add more tiers as needed${RESET}"
        return 0
    else
        echo -e "${BRIGHT_RED}Error: No files found in TIER_0_RULES${RESET}"
        rm -f "$temp_file"
        return 1
    fi
}

# Deploy MAIRULES.md with all tiers (for backward compatibility)
deploy_mairules() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying MAIRULES.md from all tiers${RESET}"
    
    local dest="$target_dir/MAIRULES.md"
    local temp_file=$(mktemp)
    
    # If MAIRULES.md already exists, we'll append to it
    local append_mode=false
    if [[ -f "$dest" ]]; then
        append_mode=true
        echo -e "${YELLOW}⚠️  MAIRULES.md already exists - appending new content${RESET}"
        # Add a separator before appending
        echo -e "\n\n---\n# Additional Rules Deployment\n---\n" >> "$dest"
    fi
    
    # Concatenate all tier files in order
    local tier_files=("docs-protocol.md" "uv-python.md" "code-security.md" "prompt-security.md" "anishinaabe-cyberpunk-style.md" "modern-prompting.md")
    local files_found=0
    local tier_path="${REPO_DIR}/TIER_RULES"
    
    if [[ ! -d "$tier_path" ]]; then
        echo -e "${BRIGHT_RED}Error: TIER_RULES directory not found${RESET}"
        rm -f "$temp_file"
        return 1
    fi
    
    echo -e "${BRIGHT_BLUE}Processing TIER_RULES...${RESET}"
    
    for tier_file in "${tier_files[@]}"; do
        local file_path="${tier_path}/${tier_file}"
        if [[ -f "$file_path" ]]; then
            echo -e "${BRIGHT_BLUE}Processing ${tier_dir}...${RESET}"
            
            # Add tier header
            echo "" >> "$temp_file"
            echo "## ${tier_dir}" >> "$temp_file"
            echo "" >> "$temp_file"
            
            # Find all .md files in tier directory and concatenate them
            while IFS= read -r -d '' md_file; do
                if [[ -f "$md_file" ]]; then
                    echo -e "${GREEN}  ✓ Adding $(basename "$md_file")${RESET}"
                    echo "# $(basename "$md_file" .md)" >> "$temp_file"
                    echo "" >> "$temp_file"
                    cat "$md_file" >> "$temp_file"
                    echo "" >> "$temp_file"
                    echo "" >> "$temp_file"
                    ((files_found++))
                fi
            done < <(find "$tier_path" -maxdepth 1 -name "*.md" -type f -print0 | sort -z)
        fi
    done
    
    if [[ $files_found -eq 0 ]]; then
        echo -e "${BRIGHT_RED}Error: No markdown files found in TIER directories${RESET}"
        rm -f "$temp_file"
        return 1
    fi
    
    # Append or create the final file
    if [[ "$append_mode" = true ]]; then
        cat "$temp_file" >> "$dest"
    else
        cat "$temp_file" > "$dest"
    fi
    
    rm -f "$temp_file"
    
    echo -e "${GREEN}✓ Deployed MAIRULES.md to $target_dir${RESET}"
    echo -e "${BRIGHT_GREEN}✅ Concatenated $files_found files from all tiers${RESET}"
    
    if [[ "$append_mode" = true ]]; then
        echo -e "${BRIGHT_YELLOW}📝 Content appended to existing MAIRULES.md${RESET}"
    fi
    
    return 0
}
