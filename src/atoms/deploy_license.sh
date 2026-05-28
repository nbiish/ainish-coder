#!/bin/bash
# MOLECULE: License deployment
# Copies LICENSE from repo root to project root

deploy_license() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    # Ensure target directory exists
    if [[ ! -d "$target_dir" ]]; then
        print_error "Target directory does not exist: $target_dir"
        return 1
    fi
    
    echo -e "${BRIGHT_BLUE}Deploying LICENSE${RESET}"
    
    local source="${REPO_DIR}/LICENSE"
    local dest="$target_dir/LICENSE"
    
    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: LICENSE not found at $source${RESET}"
        return 1
    fi
    
    # Backup existing file if it exists
    if [[ -f "$dest" ]]; then
        mv "$dest" "$dest.backup"
        echo -e "${YELLOW}Backed up existing LICENSE${RESET}"
    fi
    
    # Deploy (symlink with --link, copy otherwise)
    if deploy_path "$source" "$dest"; then
        echo -e "${GREEN}✓ Deployed: LICENSE${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to deploy LICENSE${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}✅ LICENSE deployed${RESET}"
    return 0
}
