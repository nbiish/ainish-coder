#!/bin/bash
# MOLECULE: AGENTS.md deployment
# Deploys THE singular, repository-agnostic AGENTS.md (this repo's root
# AGENTS.md) as the target repository's single governing AGENTS.md.
# One contract everywhere: root AGENTS.md is both the live contract here
# and the distributed template — there is no separate deployed variant.
# Repository-specific direction lives in each repo's llms.txt DOX chain.

deploy_agents() {
    local target_dir="${1:-.}"  # Default to current directory if not provided

    validate_target_dir "$target_dir" || return 1

    local source="${REPO_DIR}/AGENTS.md"
    local dest="$target_dir/AGENTS.md"

    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: singular AGENTS.md not found at $source${RESET}"
        return 1
    fi

    echo -e "${BRIGHT_BLUE}Deploying AGENTS.md (universal standard) -> $dest${RESET}"

    # Check if we are trying to deploy the file onto itself
    if [[ "$source" -ef "$dest" ]]; then
        echo -e "${GREEN}✓ AGENTS.md is already up to date at $target_dir (same file)${RESET}"
        return 0
    fi

    # If the target repository still has a legacy AGENTS.deployed.md from a
    # previous dual-contract run, clean it up: AGENTS.md is the one contract.
    local legacy_deployed="$target_dir/AGENTS.deployed.md"
    if [[ -f "$legacy_deployed" || -L "$legacy_deployed" ]]; then
        rm -f "$legacy_deployed"
        echo -e "${YELLOW}🧹 Cleaned up legacy AGENTS.deployed.md at $target_dir (singular AGENTS.md model)${RESET}"
    fi
    local legacy_template="$target_dir/src/templates/AGENTS.deployed.md"
    if [[ -f "$legacy_template" && ! -f "$target_dir/bin/ainish-coder" ]]; then
        rm -f "$legacy_template"
        echo -e "${YELLOW}🧹 Cleaned up legacy src/templates/AGENTS.deployed.md at $target_dir${RESET}"
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

    echo -e "${GREEN}✓ Deployed the universal AGENTS.md as $dest${RESET}"
    echo -e "${BRIGHT_GREEN}✅ AGENTS.md (singular, repo-agnostic) is ready for all AI tools; project direction lives in llms.txt${RESET}"

    return 0
}

# deploy_agents_deployed <target_dir> — backwards-compatible alias:
# the legacy deployed-variant doc is retired; AGENTS.md is the one contract.
deploy_agents_deployed() {
    deploy_agents "$@"
}

# Alias for backwards compatibility
deploy_agents_maintainer() {
    deploy_agents "$@"
}

# Global AGENTS.md symlink — ensures ~/.agents/AGENTS.md and ~/.config/AGENTS.md
# always point to the canonical singular AGENTS.md — the same document that
# governs this repository and deploys to every target repository.
deploy_agents_global() {
    local source="${REPO_DIR}/AGENTS.md"
    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: singular AGENTS.md not found at $source${RESET}"
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
