#!/bin/bash
# Deploy the repository-agnostic llms.txt template.

deploy_llms_txt() {
    local target_dir="${1:-.}"
    validate_target_dir "$target_dir" || return 1

    local dest_file="$target_dir/llms.txt"
    local source_file="${REPO_DIR}/src/templates/llms.txt"
    if [[ ! -f "$source_file" ]]; then
        print_error "Distributed llms.txt template not found: $source_file"
        return 1
    fi

    # Interactive prompt unless non-interactive is set
    if ! confirm_action "Do you want to deploy the llms.txt file to: $dest_file?" "y"; then
        echo -e "${YELLOW}Aborted deployment of llms.txt.${RESET}"
        rm -f "$temp_file"
        return 0
    fi

    echo -e "${BRIGHT_BLUE}Deploying llms.txt file to: $dest_file${RESET}"
    echo -e "${BRIGHT_BLUE}Source: $source_file${RESET}"

    cp "$source_file" "$dest_file"
    chmod 644 "$dest_file"

    if [[ -f "$dest_file" ]]; then
        echo -e "${BRIGHT_GREEN}✅ llms.txt file deployed to $dest_file${RESET}"
    else
        print_error "Failed to deploy llms.txt"
        return 1
    fi

    return 0
}

