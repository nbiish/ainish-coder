#!/bin/bash
# MOLECULE: Tier-based deployment system
# Deploys specific tier rules by appending them to MAIRULES.md

# Deploy TIER_0 (Critical rules)
deploy_tier0() {
    local target_dir="${1:-$(pwd)}"
    local mairules_file="$target_dir/MAIRULES.md"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying TIER_0 (Critical) rules to $mairules_file${RESET}"
    
    local tier_dir="${REPO_DIR}/TIER_0_RULES"
    
    if [[ ! -d "$tier_dir" ]]; then
        echo -e "${BRIGHT_RED}Error: TIER_0 directory not found${RESET}"
        return 1
    fi
    
    echo -e "
## TIER 0: Critical Rules
" >> "$mairules_file"
    
    local count=0
    while IFS= read -r source_file; do
        if [[ -f "$source_file" ]]; then
            local filename=$(basename "$source_file")
            
            if ! cat "$source_file" >> "$mairules_file"; then
                echo -e "${BRIGHT_RED}Error: Failed to append $filename${RESET}"
                return 1
            fi
            echo "" >> "$mairules_file" # Add a newline for separation
            
            echo -e "${GREEN}✓ Deployed $filename${RESET}"
            count=$((count + 1))
        fi
    done < <(find "$tier_dir" -name "*.md" -type f | sort)
    
    echo -e "${BRIGHT_GREEN}✅ Deployed $count TIER_0 rule(s) to $mairules_file${RESET}"
}

# Deploy TIER_1 (Core rules)
deploy_tier1() {
    local target_dir="${1:-$(pwd)}"
    local mairules_file="$target_dir/MAIRULES.md"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying TIER_1 (Core) rules to $mairules_file${RESET}"
    
    local tier_dir="${REPO_DIR}/TIER_1_RULES"
    
    if [[ ! -d "$tier_dir" ]]; then
        echo -e "${BRIGHT_RED}Error: TIER_1_RULES directory not found${RESET}"
        return 1
    fi
    
    echo -e "
## TIER 1: Core Rules
" >> "$mairules_file"
    
    local count=0
    while IFS= read -r source_file; do
        if [[ -f "$source_file" ]]; then
            local filename=$(basename "$source_file")
            
            if ! cat "$source_file" >> "$mairules_file"; then
                echo -e "${BRIGHT_RED}Error: Failed to append $filename${RESET}"
                return 1
            fi
            echo "" >> "$mairules_file"
            
            echo -e "${GREEN}✓ Deployed $filename${RESET}"
            count=$((count + 1))
        fi
    done < <(find "$tier_dir" -name "*.md" -type f | sort)
    
    echo -e "${BRIGHT_GREEN}✅ Deployed $count TIER_1 rule(s) to $mairules_file${RESET}"
}

# Deploy TIER_2 (Security rules)
deploy_tier2() {
    local target_dir="${1:-$(pwd)}"
    local mairules_file="$target_dir/MAIRULES.md"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying TIER_2 (Security) rules to $mairules_file${RESET}"
    
    local tier_dir="${REPO_DIR}/TIER_2_RULES"
    
    if [[ ! -d "$tier_dir" ]]; then
        echo -e "${BRIGHT_RED}Error: TIER_2_RULES directory not found${RESET}"
        return 1
    fi
    
    echo -e "
## TIER 2: Security Rules
" >> "$mairules_file"
    
    local count=0
    while IFS= read -r source_file; do
        if [[ -f "$source_file" ]]; then
            local filename=$(basename "$source_file")
            
            if ! cat "$source_file" >> "$mairules_file"; then
                echo -e "${BRIGHT_RED}Error: Failed to append $filename${RESET}"
                return 1
            fi
            echo "" >> "$mairules_file"
            
            echo -e "${GREEN}✓ Deployed $filename${RESET}"
            count=$((count + 1))
        fi
    done < <(find "$tier_dir" -name "*.md" -type f | sort)
    
    echo -e "${BRIGHT_GREEN}✅ Deployed $count TIER_2 rule(s) to $mairules_file${RESET}"
}

# Deploy TIER_3 (Style & advanced rules)
deploy_tier3() {
    local target_dir="${1:-$(pwd)}"
    local mairules_file="$target_dir/MAIRULES.md"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying TIER_3 (Style & Advanced) rules to $mairules_file${RESET}"
    
    local tier_dir="${REPO_DIR}/TIER_3_RULES"
    
    if [[ ! -d "$tier_dir" ]]; then
        echo -e "${BRIGHT_RED}Error: TIER_3_RULES directory not found${RESET}"
        return 1
    fi
    
    echo -e "
## TIER 3: Style & Advanced Rules
" >> "$mairules_file"
    
    local count=0
    while IFS= read -r source_file; do
        if [[ -f "$source_file" ]]; then
            local filename=$(basename "$source_file")
            
            if ! cat "$source_file" >> "$mairules_file"; then
                echo -e "${BRIGHT_RED}Error: Failed to append $filename${RESET}"
                return 1
            fi
            echo "" >> "$mairules_file"
            
            echo -e "${GREEN}✓ Deployed $filename${RESET}"
            count=$((count + 1))
        fi
    done < <(find "$tier_dir" -name "*.md" -type f | sort)
    
    echo -e "${BRIGHT_GREEN}✅ Deployed $count TIER_3 rule(s) to $mairules_file${RESET}"
}

# Deploy TIER_4 (Additional rules)
deploy_tier4() {
    local target_dir="${1:-$(pwd)}"
    local mairules_file="$target_dir/MAIRULES.md"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying TIER_4 rules to $mairules_file${RESET}"
    
    local tier_dir="${REPO_DIR}/TIER_4_RULES"
    
    if [[ ! -d "$tier_dir" ]]; then
        echo -e "${BRIGHT_RED}Error: TIER_4_RULES directory not found${RESET}"
        return 1
    fi
    
    echo -e "
## TIER 4: Additional Rules
" >> "$mairules_file"
    
    local count=0
    while IFS= read -r source_file; do
        if [[ -f "$source_file" ]]; then
            local filename=$(basename "$source_file")
            
            if ! cat "$source_file" >> "$mairules_file"; then
                echo -e "${BRIGHT_RED}Error: Failed to append $filename${RESET}"
                return 1
            fi
            echo "" >> "$mairules_file"
            
            echo -e "${GREEN}✓ Deployed $filename${RESET}"
            count=$((count + 1))
        fi
    done < <(find "$tier_dir" -name "*.md" -type f | sort)
    
    echo -e "${BRIGHT_GREEN}✅ Deployed $count TIER_4 rule(s) to $mairules_file${RESET}"
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
