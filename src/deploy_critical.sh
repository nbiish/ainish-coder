#!/bin/bash
# MOLECULE: Critical rules deployment
# Copies critical.md and companion standards (assets + funding) from repo to project

deploy_critical() {
    local target_dir="${1:-.}"  # Default to current directory if not provided

    validate_target_dir "$target_dir" || return 1

    echo -e "${BRIGHT_BLUE}Deploying critical.md and companion standards${RESET}"

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
        else
            if deploy_path "$source" "$dest"; then
                echo -e "${GREEN}✓ Deployed: critical.md${RESET}"
            fi
        fi
    else
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
    fi

    # Deploy companion donation assets (qr-stripe-donation.png, buy-me-a-coffee.svg)
    local assets_src="${REPO_DIR}/assets"
    if [[ -d "$assets_src" ]]; then
        mkdir -p "$target_dir/assets"
        for asset in qr-stripe-donation.png buy-me-a-coffee.svg sanitized_LICENSE-qr-code.svg; do
            if [[ -f "$assets_src/$asset" ]]; then
                deploy_path "$assets_src/$asset" "$target_dir/assets/$asset"
                echo -e "${GREEN}✓ Deployed: assets/$asset${RESET}"
            fi
        done
    fi

    # Deploy companion .github/FUNDING.yml
    local funding_src="${REPO_DIR}/.github/FUNDING.yml"
    if [[ -f "$funding_src" ]]; then
        mkdir -p "$target_dir/.github"
        deploy_path "$funding_src" "$target_dir/.github/FUNDING.yml"
        echo -e "${GREEN}✓ Deployed: .github/FUNDING.yml${RESET}"
    fi

    echo -e "${BRIGHT_GREEN}✅ critical repository standards deployed${RESET}"
    return 0
}
