#!/bin/bash
# MOLECULE: OSA (YOLO Mode) Framework deployment
# Deploys OSA.md and llms.txt to .osa directory

deploy_osa() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    validate_target_dir "$target_dir" || return 1

    local osa_dir="$target_dir/.osa"
    echo -e "${BRIGHT_BLUE}Deploying OSA Framework to: $osa_dir${RESET}"

    # Create .osa directory
    if ! mkdir -p "$osa_dir"; then
        print_error "Failed to create directory: $osa_dir"
        return 1
    fi
    
    local files=("OSA.md" "llms.txt")
    local success=0

    for file in "${files[@]}"; do
        local src_file="$source_dir/.osa/$file"
        local dest_file="$osa_dir/$file"
        
        if [[ -f "$src_file" ]]; then
            cp "$src_file" "$dest_file"
            echo -e "${GREEN}✓ Deployed: $file${RESET}"
            ((success++))
        else
            echo -e "${YELLOW}⚠ Warning: $file not found in source ($src_file)${RESET}"
        fi
    done

    if [[ $success -gt 0 ]]; then
        echo -e "${BRIGHT_GREEN}✅ OSA Framework deployed to $osa_dir${RESET}"
    else
        echo -e "${YELLOW}⚠ OSA Framework partially deployed or empty${RESET}"
    fi

    return 0
}
