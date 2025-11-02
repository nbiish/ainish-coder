#!/bin/bash
# MOLECULE: MAI RULES deployment
# Concatenates all TIER_*_RULES/*.md files and creates/appends to MAIRULES.md in current working directory

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
    local tier_dirs=("TIER_0_RULES" "TIER_1_RULES" "TIER_2_RULES" "TIER_3_RULES" "TIER_4_RULES")
    local files_found=0
    
    for tier_dir in "${tier_dirs[@]}"; do
        local tier_path="${REPO_DIR}/${tier_dir}"
        if [[ -d "$tier_path" ]]; then
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
