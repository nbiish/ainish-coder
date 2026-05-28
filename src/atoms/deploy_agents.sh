#!/bin/bash
# MOLECULE: AGENTS.md deployment
# Copies AGENTS.md to project root
# AGENTS.md is the universal standard for AI pair programmers

deploy_agents() {
    local target_dir="${1:-.}"  # Default to current directory if not provided

    validate_target_dir "$target_dir" || return 1

    echo -e "${BRIGHT_BLUE}Deploying AGENTS.md${RESET}"

    local source="${REPO_DIR}/AGENTS.md"
    local dest="$target_dir/AGENTS.md"

    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: AGENTS.md not found at $source${RESET}"
        return 1
    fi

    # Check if we are trying to deploy the file onto itself
    if [[ "$source" -ef "$dest" ]]; then
        echo -e "${GREEN}✓ AGENTS.md is already up to date at $target_dir (same file)${RESET}"
        return 0
    fi

    # In non-overwrite mode, check if destination already has an AGENTS.md
    if [[ "${AINISH_NO_OVERWRITE:-false}" == "true" ]]; then
        if [[ -f "$dest" || -L "$dest" ]]; then
            echo -e "${YELLOW}⏭️  Skipping AGENTS.md (already exists at $target_dir)${RESET}"
            echo -e "${YELLOW}   Use ainish-coder --rules to overwrite (or -y for non-interactive)${RESET}"
            return 0
        fi
    fi

    # Deploy (symlink with --link, copy otherwise)
    if ! deploy_path "$source" "$dest"; then
        echo -e "${BRIGHT_RED}Error: Failed to create AGENTS.md${RESET}"
        return 1
    fi

    echo -e "${GREEN}✓ Created AGENTS.md at $target_dir${RESET}"
    echo -e "${BRIGHT_GREEN}✅ AGENTS.md is ready for all AI tools${RESET}"

    return 0
}

# Global AGENTS.md symlink — ensures ~/.agents/AGENTS.md and ~/.config/AGENTS.md
# always point to the canonical AGENTS.md in the ainish-coder repo.
deploy_agents_global() {
    local source="${REPO_DIR}/AGENTS.md"
    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: AGENTS.md not found at $source${RESET}"
        return 1
    fi

    mkdir -p "$HOME/.agents" "$HOME/.config"

    for dest in "$HOME/.agents/AGENTS.md" "$HOME/.config/AGENTS.md"; do
        if [[ -L "$dest" && "$(readlink "$dest")" == "$source" ]]; then
            echo -e "${GREEN}✓ Global AGENTS.md symlink already correct: $dest${RESET}"
            continue
        fi

        if [[ -e "$dest" && ! -L "$dest" ]]; then
            local backup="${dest}.backup.$(date +%Y%m%d%H%M%S)"
            mv "$dest" "$backup"
            echo -e "${YELLOW}⚠ Backed up existing $dest to $backup${RESET}"
        fi

        ln -sf "$source" "$dest"
        echo -e "${GREEN}✓ Symlinked AGENTS.md to $dest${RESET}"
    done
}
