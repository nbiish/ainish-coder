#!/bin/bash
# MOLECULE: llms.txt file deployment
# Deploys llms.txt file to target

deploy_llms_txt() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    validate_target_dir "$target_dir" || return 1

    local src_file="$source_dir/src/templates/llms.txt"
    local dest_file="$target_dir/llms.txt"

    if [[ ! -f "$src_file" ]]; then
        print_error "llms.txt file template not found in source ($src_file)"
        return 1
    fi

    # Interactive prompt unless non-interactive is set
    if ! confirm_action "Do you want to deploy the llms.txt template to: $dest_file?" "y"; then
        echo -e "${YELLOW}Aborted deployment of llms.txt.${RESET}"
        return 0
    fi

    echo -e "${BRIGHT_BLUE}Deploying llms.txt file to: $dest_file${RESET}"

    cp "$src_file" "$dest_file"

    if [[ -f "$dest_file" ]]; then
        echo -e "${BRIGHT_GREEN}✅ llms.txt file deployed to $dest_file${RESET}"
    else
        print_error "Failed to deploy llms.txt"
        return 1
    fi

    return 0
}

