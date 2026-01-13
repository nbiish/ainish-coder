#!/bin/bash
# MOLECULE: MAI RULES deployment
# Concatenates all TIER_*_RULES/*.md files and creates/appends to MAIRULES.md in current working directory

# Deploy MAIRULES.md with only TIER_0 (essential/critical rules)
deploy_mairules_tier0() {
    local target_dir="${1:-.}"
    
    validate_target_dir "$target_dir" || return 1
    
    local dest="$target_dir/MAIRULES.md"
    local temp_file=$(mktemp)
    
    local tier_path="${REPO_DIR}/TIER_RULES/TIER_0_RULES"
    local files_found=0
    
    if [[ ! -d "$tier_path" ]]; then
        echo -e "${BRIGHT_RED}Error: TIER_0_RULES directory not found${RESET}"
        rm -f "$temp_file"
        return 1
    fi
    
    while IFS= read -r -d '' md_file; do
        if [[ -f "$md_file" ]]; then
            cat "$md_file" >> "$temp_file"
            echo "" >> "$temp_file"
            ((files_found++))
        fi
    done < <(find "$tier_path" -maxdepth 1 -name "*.md" -type f -print0 | sort -z)
    
    if [[ $files_found -gt 0 ]]; then
        mv "$temp_file" "$dest"
        return 0
    else
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
    local tier_files=(
        "TIER_0_RULES/docs-protocol.md"
        "TIER_1_RULES/rust-cargo.md"
        "TIER_1_RULES/uv-python.md"
        "TIER_2_RULES/code-security.md"
        "TIER_2_RULES/prompt-security.md"
        "TIER_3_RULES/anishinaabe-cyberpunk-style.md"
        "TIER_4_RULES/modern-prompting.md"
    )
    local files_found=0
    local tier_root="${REPO_DIR}/TIER_RULES"
    
    if [[ ! -d "$tier_root" ]]; then
        echo -e "${BRIGHT_RED}Error: TIER_RULES directory not found${RESET}"
        rm -f "$temp_file"
        return 1
    fi
    
    echo -e "${BRIGHT_BLUE}Processing TIER_RULES...${RESET}"
    
    for tier_file in "${tier_files[@]}"; do
        local file_path="${tier_root}/${tier_file}"
        if [[ -f "$file_path" ]]; then
            echo -e "${GREEN}  ✓ Adding $(basename "$tier_file")${RESET}"
            
            # Add file header
            echo "" >> "$temp_file"
            echo "# $(basename "$tier_file" .md)" >> "$temp_file"
            echo "" >> "$temp_file"
            
            cat "$file_path" >> "$temp_file"
            echo "" >> "$temp_file"
            echo "" >> "$temp_file"
            ((files_found++))
        else
            echo -e "${YELLOW}  ⚠ File not found: ${tier_file}${RESET}"
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
