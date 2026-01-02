#!/bin/bash
# MOLECULE: Shell wrapper setup
# Handles setup of wrapper functions in shell configuration files

setup_wrapper_functions() {
    echo -e "${BRIGHT_BLUE}🔧 Updating .zshrc with wrapper functions...${RESET}"
    
    # Create backup
    local backup_file=$(create_backup "$ZSHRC")
    if [[ $? -ne 0 ]]; then
        echo -e "${BRIGHT_RED}Error: Failed to create backup${RESET}"
        return 1
    fi
    
    # Remove existing AINISH CODER WRAPPERS section
    local temp_file="${ZSHRC}.tmp"
    local in_section=0
    local section_start_found=0
    
    while IFS= read -r line; do
        if [[ "$line" == "### AINISH CODER WRAPPERS ###" ]]; then
            in_section=1
            section_start_found=1
            echo -e "${YELLOW}⚠️  Found existing AINISH CODER WRAPPERS section, removing...${RESET}"
            continue
        fi
        
        if [[ "$line" == "### END AINISH CODER WRAPPERS ###" ]]; then
            in_section=0
            echo -e "${GREEN}✓ Removed existing AINISH CODER WRAPPERS section${RESET}"
            continue
        fi
        
        if [[ $in_section -eq 0 ]]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$ZSHRC"
    
    if [[ $section_start_found -eq 0 ]]; then
        echo -e "${YELLOW}ℹ️  No existing AINISH CODER WRAPPERS section found${RESET}"
    fi
    
    mv "$temp_file" "$ZSHRC"
    
    # Validate .zshrc after cleaning
    if [[ ! -f "$ZSHRC" ]] || [[ ! -s "$ZSHRC" ]]; then
        echo -e "${BRIGHT_RED}Error: .zshrc appears to be corrupted after cleaning${RESET}"
        if restore_backup "$backup_file"; then
            echo -e "${BRIGHT_GREEN}✅ .zshrc restored successfully${RESET}"
            return 1
        else
            echo -e "${BRIGHT_RED}Error: Failed to restore .zshrc. Manual intervention required.${RESET}"
            return 1
        fi
    fi
    
    # Add new wrapper functions
    cat >> "$ZSHRC" << EOF
### AINISH CODER WRAPPERS ###
export AINISH_CODER_DIR="${AINISH_CODER_DIR}"
export CURSOR_PATH="${CURSOR_PATH}"
export REPO_DIR="${REPO_DIR}"

function ainish-coder { 
    local current_dir="\$(pwd)"
    
    if [[ "\$1" == "--help" ]]; then
        "\$AINISH_CODER_DIR/ainish-setup.sh" --help
    else
        "\$AINISH_CODER_DIR/ainish-setup.sh" "\$@" "\$current_dir"
    fi
}
### END AINISH CODER WRAPPERS ###
EOF
    
    echo -e "${BRIGHT_GREEN}✅ Wrapper functions added to .zshrc${RESET}"
}

# Setup ~/.ainish-coder directory
setup_ainish_coder_dir() {
    echo -e "${BRIGHT_BLUE}🔧 Setting up ~/.ainish-coder directory...${RESET}"
    
    safe_mkdir "$AINISH_CODER_DIR" || return 1
    
    # Copy this script to ~/.ainish-coder
    if cp "${REPO_DIR}/ainish-setup.sh" "$AINISH_CODER_DIR/ainish-setup.sh" 2>/dev/null; then
        chmod +x "$AINISH_CODER_DIR/ainish-setup.sh"
        echo -e "${GREEN}✓ Copied ainish-setup.sh to ~/.ainish-coder${RESET}"
    fi
    
    # Copy lib directory
    if cp -r "${REPO_DIR}/lib" "$AINISH_CODER_DIR/" 2>/dev/null; then
        echo -e "${GREEN}✓ Copied lib directory to ~/.ainish-coder${RESET}"
    fi
    
    # Create config.sh
    cat > "$AINISH_CODER_DIR/config.sh" << EOF
# AINISH-Coder configuration
export REPO_DIR="${REPO_DIR}"
EOF
    
    echo -e "${BRIGHT_GREEN}✅ ~/.ainish-coder directory setup complete${RESET}"
}

# Cleanup old files
cleanup_old_files() {
    echo -e "${BRIGHT_BLUE}🧹 Cleaning up old files...${RESET}"
    
    # Remove old individual config files from ~/.ainish-coder if they exist
    if [[ -d "$AINISH_CODER_DIR" ]]; then
        find "$AINISH_CODER_DIR" -maxdepth 1 -name "*.mdc" -type f -delete 2>/dev/null
        echo -e "${GREEN}✓ Cleaned up old .mdc files${RESET}"
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Cleanup complete${RESET}"
}
