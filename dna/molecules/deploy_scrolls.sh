#!/bin/bash
# MOLECULE: Deploy Scrolls
# Deploys scroll templates to the target directory

deploy_scrolls() {
    local target_dir="${1:-$(pwd)}"
    
    # Check if target directory exists
    if [[ ! -d "$target_dir" ]]; then
        print_error "Target directory does not exist: $target_dir"
        return 1
    fi
    
    local scrolls_dir="$target_dir/.scrolls"
    
    echo -e "${BRIGHT_BLUE}Deploying Scrolls to: $scrolls_dir${RESET}"
    
    # Create directory
    if ! mkdir -p "$scrolls_dir"; then
        print_error "Failed to create directory: $scrolls_dir"
        return 1
    fi
    
    # Source directory (from repo root)
    local src_dir="${REPO_DIR}/.scrolls"
    
    if [[ ! -d "$src_dir" ]]; then
        print_error "Source .scrolls directory not found at: $src_dir"
        return 1
    fi
    
    # Copy all files
    local count=0
    # Enable nullglob to handle case where no files match
    shopt -s nullglob
    for file in "$src_dir"/*; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            if cp "$file" "$scrolls_dir/"; then
                echo -e "${GREEN}✓ Deployed $filename${RESET}"
                ((count++))
            else
                print_error "Failed to copy $filename"
            fi
        fi
    done
    shopt -u nullglob
    
    if [[ $count -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No scroll files found to deploy${RESET}"
    else
        echo -e "${BRIGHT_GREEN}✅ Scrolls deployment complete ($count files)${RESET}"
    fi
}
