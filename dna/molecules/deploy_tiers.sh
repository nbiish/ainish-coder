#!/bin/bash
# MOLECULE: Tier-based deployment system
# Deploys specific tier rules by appending them to MAIRULES.md

# Deploy TIER_0 (Critical - Documentation Protocol)
deploy_tier0() {
    local target_dir="${1:-$(pwd)}"
    local mairules_file="$target_dir/MAIRULES.md"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying TIER_0 (Documentation Protocol) to $mairules_file${RESET}"
    
    local tier_dir="${REPO_DIR}/TIER_0_RULES"
    
    if [[ ! -d "$tier_dir" ]]; then
        echo -e "${BRIGHT_RED}Error: TIER_0_RULES directory not found${RESET}"
        return 1
    fi
    
    echo -e "
## TIER 0: Documentation Protocol
" >> "$mairules_file"
    
    local count=0
    while IFS= read -r -d '' source_file; do
        if [[ -f "$source_file" ]]; then
            local filename=$(basename "$source_file")
            
            echo "# $(basename "$source_file" .md)" >> "$mairules_file"
            echo "" >> "$mairules_file"
            
            if ! cat "$source_file" >> "$mairules_file"; then
                echo -e "${BRIGHT_RED}Error: Failed to append $filename${RESET}"
                return 1
            fi
            echo "" >> "$mairules_file"
            
            echo -e "${GREEN}✓ Deployed $filename${RESET}"
            count=$((count + 1))
        fi
    done < <(find "$tier_dir" -maxdepth 1 -name "*.md" -type f -print0 | sort -z)
    
    echo -e "${BRIGHT_GREEN}✅ TIER_0 deployed ($count file(s))${RESET}"
}

# Deploy TIER_1 (Code Security)
deploy_tier1() {
    local target_dir="${1:-$(pwd)}"
    local mairules_file="$target_dir/MAIRULES.md"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying TIER_1 (Code Security) to $mairules_file${RESET}"
    
    local tier_dir="${REPO_DIR}/TIER_1_RULES"
    
    if [[ ! -d "$tier_dir" ]]; then
        echo -e "${BRIGHT_RED}Error: TIER_1_RULES directory not found${RESET}"
        return 1
    fi
    
    echo -e "
## TIER 1: Code Security
" >> "$mairules_file"
    
    local count=0
    while IFS= read -r -d '' source_file; do
        if [[ -f "$source_file" ]]; then
            local filename=$(basename "$source_file")
            
            echo "# $(basename "$source_file" .md)" >> "$mairules_file"
            echo "" >> "$mairules_file"
            
            if ! cat "$source_file" >> "$mairules_file"; then
                echo -e "${BRIGHT_RED}Error: Failed to append $filename${RESET}"
                return 1
            fi
            echo "" >> "$mairules_file"
            
            echo -e "${GREEN}✓ Deployed $filename${RESET}"
            count=$((count + 1))
        fi
    done < <(find "$tier_dir" -maxdepth 1 -name "*.md" -type f -print0 | sort -z)
    
    echo -e "${BRIGHT_GREEN}✅ TIER_1 deployed ($count file(s))${RESET}"
}

# Deploy TIER_2 (Prompt Security)
deploy_tier2() {
    local target_dir="${1:-$(pwd)}"
    local mairules_file="$target_dir/MAIRULES.md"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying TIER_2 (Prompt Security) to $mairules_file${RESET}"
    
    local tier_dir="${REPO_DIR}/TIER_2_RULES"
    
    if [[ ! -d "$tier_dir" ]]; then
        echo -e "${BRIGHT_RED}Error: TIER_2_RULES directory not found${RESET}"
        return 1
    fi
    
    echo -e "
## TIER 2: Prompt Security
" >> "$mairules_file"
    
    local count=0
    while IFS= read -r -d '' source_file; do
        if [[ -f "$source_file" ]]; then
            local filename=$(basename "$source_file")
            
            echo "# $(basename "$source_file" .md)" >> "$mairules_file"
            echo "" >> "$mairules_file"
            
            if ! cat "$source_file" >> "$mairules_file"; then
                echo -e "${BRIGHT_RED}Error: Failed to append $filename${RESET}"
                return 1
            fi
            echo "" >> "$mairules_file"
            
            echo -e "${GREEN}✓ Deployed $filename${RESET}"
            count=$((count + 1))
        fi
    done < <(find "$tier_dir" -maxdepth 1 -name "*.md" -type f -print0 | sort -z)
    
    echo -e "${BRIGHT_GREEN}✅ TIER_2 deployed ($count file(s))${RESET}"
}

# Deploy TIER_3 (Cultural/Stylistic)
deploy_tier3() {
    local target_dir="${1:-$(pwd)}"
    local mairules_file="$target_dir/MAIRULES.md"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying TIER_3 (Cultural/Stylistic) to $mairules_file${RESET}"
    
    local tier_dir="${REPO_DIR}/TIER_3_RULES"
    
    if [[ ! -d "$tier_dir" ]]; then
        echo -e "${BRIGHT_RED}Error: TIER_3_RULES directory not found${RESET}"
        return 1
    fi
    
    echo -e "
## TIER 3: Cultural & Stylistic Preferences
" >> "$mairules_file"
    
    local count=0
    while IFS= read -r -d '' source_file; do
        if [[ -f "$source_file" ]]; then
            local filename=$(basename "$source_file")
            
            echo "# $(basename "$source_file" .md)" >> "$mairules_file"
            echo "" >> "$mairules_file"
            
            if ! cat "$source_file" >> "$mairules_file"; then
                echo -e "${BRIGHT_RED}Error: Failed to append $filename${RESET}"
                return 1
            fi
            echo "" >> "$mairules_file"
            
            echo -e "${GREEN}✓ Deployed $filename${RESET}"
            count=$((count + 1))
        fi
    done < <(find "$tier_dir" -maxdepth 1 -name "*.md" -type f -print0 | sort -z)
    
    echo -e "${BRIGHT_GREEN}✅ TIER_3 deployed ($count file(s))${RESET}"
}

# Deploy TIER_4 (Advanced Prompting)
deploy_tier4() {
    local target_dir="${1:-$(pwd)}"
    local mairules_file="$target_dir/MAIRULES.md"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying TIER_4 (Advanced Prompting) to $mairules_file${RESET}"
    
    local tier_dir="${REPO_DIR}/TIER_4_RULES"
    
    if [[ ! -d "$tier_dir" ]]; then
        echo -e "${BRIGHT_RED}Error: TIER_4_RULES directory not found${RESET}"
        return 1
    fi
    
    echo -e "
## TIER 4: Advanced Prompting Techniques
" >> "$mairules_file"
    
    local count=0
    while IFS= read -r -d '' source_file; do
        if [[ -f "$source_file" ]]; then
            local filename=$(basename "$source_file")
            
            echo "# $(basename "$source_file" .md)" >> "$mairules_file"
            echo "" >> "$mairules_file"
            
            if ! cat "$source_file" >> "$mairules_file"; then
                echo -e "${BRIGHT_RED}Error: Failed to append $filename${RESET}"
                return 1
            fi
            echo "" >> "$mairules_file"
            
            echo -e "${GREEN}✓ Deployed $filename${RESET}"
            count=$((count + 1))
        fi
    done < <(find "$tier_dir" -maxdepth 1 -name "*.md" -type f -print0 | sort -z)
    
    echo -e "${BRIGHT_GREEN}✅ TIER_4 deployed ($count file(s))${RESET}"
}

# Deploy all tiers at once
deploy_all_tiers() {
    local target_dir="${1:-$(pwd)}"
    local mairules_file="$target_dir/MAIRULES.md"

    # Clear the file before deploying all tiers
    > "$mairules_file"
    
    echo -e "${BRIGHT_MAGENTA}╔══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BRIGHT_MAGENTA}║${RESET}               ${BRIGHT_CYAN}DEPLOYING ALL TIERS${RESET}                                        ${BRIGHT_MAGENTA}║${RESET}"
    echo -e "${BRIGHT_MAGENTA}╚══════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    
    deploy_tier0 "$target_dir" || return 1
    echo ""
    deploy_tier1 "$target_dir" || return 1
    echo ""
    deploy_tier2 "$target_dir" || return 1
    echo ""
    deploy_tier3 "$target_dir" || return 1
    echo ""
    deploy_tier4 "$target_dir" || return 1
    echo ""
    
    echo -e "${BRIGHT_MAGENTA}╔══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BRIGHT_MAGENTA}║${RESET}               ${BRIGHT_GREEN}ALL TIERS DEPLOYED${RESET}                                         ${BRIGHT_MAGENTA}║${RESET}"
    echo -e "${BRIGHT_MAGENTA}╚══════════════════════════════════════════════════════════════════════════╝${RESET}"
}
