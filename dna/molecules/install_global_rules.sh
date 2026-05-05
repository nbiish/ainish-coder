#!/bin/bash
# MOLECULE: Global Rules Installation
# Installs MAI RULES and tool-specific rules to user's home directory

install_global_mairules() {
    echo -e "${BRIGHT_BLUE}Installing Global MAI RULES...${RESET}"
    
    # Create global MAI RULES directory
    if [[ ! -d "$MAI_RULES_GLOBAL_DIR" ]]; then
        mkdir -p "$MAI_RULES_GLOBAL_DIR"
        echo -e "${GREEN}✓ Created ${MAI_RULES_GLOBAL_DIR}${RESET}"
    fi
    
    # Copy MAIRULES.md to global location
    local source="${REPO_DIR}/MAIRULES.md"
    local dest="${MAI_RULES_GLOBAL_DIR}/MAIRULES.md"
    
    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: MAIRULES.md not found at $source${RESET}"
        return 1
    fi
    
    if cp "$source" "$dest" 2>/dev/null; then
        echo -e "${GREEN}✓ Installed MAIRULES.md to ${MAI_RULES_GLOBAL_DIR}${RESET}"
        echo -e "${BRIGHT_GREEN}📍 Global rules available system-wide at: ${dest}${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy MAIRULES.md to global location${RESET}"
        return 1
    fi
    
    # Copy tier-specific rules to global .mai-rules directory
    echo -e "${BRIGHT_BLUE}Installing tier-specific rules...${RESET}"
    
    local tiers=("TIER_0_RULES" "TIER_1_RULES" "TIER_2_RULES" "TIER_3_RULES" "TIER_4_RULES")
    for tier_var in "${tiers[@]}"; do
        local tier_dir="${REPO_DIR}/TIER_RULES/${tier_var}"
        if [[ -d "$tier_dir" ]]; then
            for rule_file in "$tier_dir"/*.md; do
                if [[ -f "$rule_file" ]]; then
                    local filename=$(basename "$rule_file")
                    if cp "$rule_file" "${MAI_RULES_GLOBAL_DIR}/${filename}" 2>/dev/null; then
                        echo -e "${GREEN}  ✓ Installed ${filename}${RESET}"
                    fi
                fi
            done
        fi
    done
    
    echo -e "${BRIGHT_GREEN}✅ Global MAI RULES installation complete${RESET}"
    echo -e "${BRIGHT_BLUE}📋 Rules hierarchy:${RESET}"
    echo -e "   1. Project: ./MAIRULES.md (highest priority)"
    echo -e "   2. Project config: ./.mai-rules/MAIRULES.md"
    echo -e "   3. Global: ~/.mai-rules/MAIRULES.md (fallback)"
}

install_global_pi() {
    echo -e "${BRIGHT_BLUE}Installing Global Pi Rules...${RESET}"

    # Create global Pi directory
    if [[ ! -d "$PI_GLOBAL_DIR" ]]; then
        mkdir -p "$PI_GLOBAL_DIR"
        echo -e "${GREEN}✓ Created ${PI_GLOBAL_DIR}${RESET}"
    fi

    # Copy consolidated PI.md
    local source="${REPO_DIR}/MAIRULES.md"
    local dest="${PI_GLOBAL_DIR}/PI.md"

    if [[ -f "$source" ]] && cp "$source" "$dest" 2>/dev/null; then
        echo -e "${GREEN}✓ Installed PI.md to ${PI_GLOBAL_DIR}${RESET}"
        echo -e "${BRIGHT_GREEN}📍 Global Pi rules available at: ${dest}${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to install global Pi rules${RESET}"
        return 1
    fi

    echo -e "${BRIGHT_GREEN}✅ Global Pi rules installation complete${RESET}"
}

install_global_gemini() {
    echo -e "${BRIGHT_BLUE}Installing Global Gemini Rules...${RESET}"
    
    # Create global Gemini directory
    if [[ ! -d "$GEMINI_GLOBAL_DIR" ]]; then
        mkdir -p "$GEMINI_GLOBAL_DIR"
        echo -e "${GREEN}✓ Created ${GEMINI_GLOBAL_DIR}${RESET}"
    fi
    
    # Copy consolidated GEMINI.md
    local source="${REPO_DIR}/MAIRULES.md"
    local dest="${GEMINI_GLOBAL_DIR}/GEMINI.md"
    
    if [[ -f "$source" ]] && cp "$source" "$dest" 2>/dev/null; then
        echo -e "${GREEN}✓ Installed GEMINI.md to ${GEMINI_GLOBAL_DIR}${RESET}"
        echo -e "${BRIGHT_GREEN}📍 Global Gemini rules available at: ${dest}${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to install global Gemini rules${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Global Gemini rules installation complete${RESET}"
}

install_global_continue() {
    echo -e "${BRIGHT_BLUE}Installing Global Continue Rules...${RESET}"
    
    # Create global Continue directory
    if [[ ! -d "$CONTINUE_GLOBAL_DIR" ]]; then
        mkdir -p "$CONTINUE_GLOBAL_DIR"
        echo -e "${GREEN}✓ Created ${CONTINUE_GLOBAL_DIR}${RESET}"
    fi
    
    # Copy consolidated CONTINUE.md
    local source="${TIER_1_DIR}/MAIRULES.md"
    local dest="${CONTINUE_GLOBAL_DIR}/CONTINUE.md"
    
    if [[ -f "$source" ]] && cp "$source" "$dest" 2>/dev/null; then
        echo -e "${GREEN}✓ Installed CONTINUE.md to ${CONTINUE_GLOBAL_DIR}${RESET}"
        echo -e "${BRIGHT_GREEN}📍 Global Continue reference available at: ${dest}${RESET}"
        echo -e "${BRIGHT_YELLOW}⚠️  Note: Active config is managed via Continue sidebar (config.yaml)${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to install global Continue rules${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Global Continue reference installation complete${RESET}"
}

install_all_global_rules() {
    echo -e "${BRIGHT_BLUE}========================================${RESET}"
    echo -e "${BRIGHT_BLUE}Installing All Global Rules${RESET}"
    echo -e "${BRIGHT_BLUE}========================================${RESET}"
    echo ""
    
    install_global_mairules
    echo ""
    
    install_global_pi
    echo ""
    
    install_global_gemini
    echo ""
    
    install_global_continue
    echo ""
    
    echo -e "${BRIGHT_BLUE}========================================${RESET}"
    echo -e "${BRIGHT_GREEN}✅ All Global Rules Installed${RESET}"
    echo -e "${BRIGHT_BLUE}========================================${RESET}"
    echo ""
    echo -e "${BRIGHT_BLUE}📍 Global Configuration Locations:${RESET}"
    echo -e "   • MAI RULES:  ~/.mai-rules/MAIRULES.md"
    echo -e "   • Pi:         ~/.pi/PI.md"
    echo -e "   • Gemini:     ~/.gemini/GEMINI.md"
    echo -e "   • Continue:   ~/.continue/CONTINUE.md"
    echo ""
    echo -e "${BRIGHT_BLUE}📚 Configuration Hierarchy:${RESET}"
    echo -e "   1. Working directory (highest priority)"
    echo -e "   2. Project-specific (./.mai-rules/)"
    echo -e "   3. Global user config (~/.mai-rules/)"
    echo -e "   4. Default tool behavior"
}
