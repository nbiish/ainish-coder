#!/bin/bash
# MOLECULE: llms.txt directory deployment
# Deploys llms.txt/ directory to target

deploy_llms_txt() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    validate_target_dir "$target_dir" || return 1

    local dest_dir="$target_dir/llms.txt"
    echo -e "${BRIGHT_BLUE}Deploying llms.txt directory to: $dest_dir${RESET}"

    # Create llms.txt directory
    if ! mkdir -p "$dest_dir"; then
        print_error "Failed to create directory: $dest_dir"
        return 1
    fi

    local src_dir="$source_dir/llms.txt"
    local success=0

    if [[ -d "$src_dir" ]]; then
        for file in "$src_dir"/*.md; do
            if [[ -f "$file" ]]; then
                local filename=$(basename "$file")
                cp "$file" "$dest_dir/$filename"
                echo -e "${GREEN}✓ Deployed: $filename${RESET}"
                ((success++))
            fi
        done
    else
        print_error "llms.txt directory not found in source ($src_dir)"
        return 1
    fi

    if [[ $success -gt 0 ]]; then
        echo -e "${BRIGHT_GREEN}✅ llms.txt directory deployed to $dest_dir${RESET}"
    else
        echo -e "${YELLOW}⚠ No files found to deploy from llms.txt${RESET}"
    fi

    return 0
}
