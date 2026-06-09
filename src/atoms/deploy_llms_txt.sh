#!/bin/bash
# MOLECULE: llms.txt file deployment
# Fetches https://github.com/agent0ai/dox/blob/main/AGENTS.md?plain=1,
# replaces every occurrence of AGENTS.md with llms.txt, and deploys the result.

REMOTE_AGENTS_URL="https://raw.githubusercontent.com/agent0ai/dox/main/AGENTS.md"

deploy_llms_txt() {
    local target_dir="${1:-.}"
    local temp_file
    temp_file=$(mktemp /tmp/llms-txt.XXXXXX)
    trap 'rm -f "$temp_file"' EXIT

    validate_target_dir "$target_dir" || return 1

    local dest_file="$target_dir/llms.txt"

    # Fetch remote AGENTS.md
    if ! curl -fsSL "$REMOTE_AGENTS_URL" -o "$temp_file" 2>/dev/null; then
        print_error "Failed to fetch AGENTS.md from $REMOTE_AGENTS_URL"
        return 1
    fi

    # Replace every occurrence of AGENTS.md with llms.txt in the document
    sed -i.bak 's/AGENTS\.md/llms.txt/g' "$temp_file"
    rm -f "$temp_file.bak"

    # Interactive prompt unless non-interactive is set
    if ! confirm_action "Do you want to deploy the llms.txt file to: $dest_file?" "y"; then
        echo -e "${YELLOW}Aborted deployment of llms.txt.${RESET}"
        return 0
    fi

    echo -e "${BRIGHT_BLUE}Deploying llms.txt file to: $dest_file${RESET}"
    echo -e "${BRIGHT_BLUE}Source: $REMOTE_AGENTS_URL (AGENTS.md → llms.txt)${RESET}"

    cp "$temp_file" "$dest_file"
    chmod 644 "$dest_file"

    if [[ -f "$dest_file" ]]; then
        echo -e "${BRIGHT_GREEN}✅ llms.txt file deployed to $dest_file${RESET}"
    else
        print_error "Failed to deploy llms.txt"
        return 1
    fi

    return 0
}

