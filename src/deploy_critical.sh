#!/bin/bash
# MOLECULE: Critical rules deployment
# Copies critical.md from repo root to project root

deploy_critical() {
    local target_dir="${1:-.}"  # Default to current directory if not provided

    validate_target_dir "$target_dir" || return 1

    echo -e "${BRIGHT_BLUE}Deploying critical.md${RESET}"

    local source="${REPO_DIR}/critical.md"
    local dest="$target_dir/critical.md"

    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: critical.md not found at $source${RESET}"
        return 1
    fi

    # In non-overwrite mode, skip if destination already exists
    if [[ "${AINISH_NO_OVERWRITE:-false}" == "true" ]]; then
        if [[ -f "$dest" || -L "$dest" ]]; then
            echo -e "${YELLOW}⏭️  Skipping critical.md (already exists at $target_dir)${RESET}"
            return 0
        fi
    fi

    # Backup existing file if it exists
    if [[ -f "$dest" ]]; then
        mv "$dest" "$dest.backup"
        echo -e "${YELLOW}Backed up existing critical.md${RESET}"
    fi

    # Deploy (symlink with --link, copy otherwise)
    if deploy_path "$source" "$dest"; then
        echo -e "${GREEN}✓ Deployed: critical.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to deploy critical.md${RESET}"
        return 1
    fi

    echo -e "${BRIGHT_GREEN}✅ critical.md deployed${RESET}"
    return 0
}
