#!/bin/bash
# MOLECULE: AGENTS.md deployment
# Deploys the project-agnostic rules document (AGENTS.deployed template)
# AS the target repository's single governing AGENTS.md.
# The ainish-coder repository's own root AGENTS.md is the maintainer
# contract for THIS repo and is never distributed.

deploy_agents() {
    local target_dir="${1:-.}"  # Default to current directory if not provided

    validate_target_dir "$target_dir" || return 1

    echo -e "${BRIGHT_BLUE}Deploying AGENTS.md${RESET}"

    local source="${REPO_DIR}/src/templates/AGENTS.deployed.md"
    [[ -f "$source" ]] || source="${REPO_DIR}/AGENTS.deployed.md"
    local dest="$target_dir/AGENTS.md"

    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: AGENTS.deployed.md template not found at $source${RESET}"
        return 1
    fi

    # Check if we are trying to deploy the file onto itself
    if [[ "$source" -ef "$dest" ]]; then
        echo -e "${GREEN}✓ AGENTS.md is already up to date at $target_dir (same file)${RESET}"
        return 0
    fi

    # Guard: never overwrite the ainish-coder maintainer contract.
    # Any checkout of this repository (main repo or a worktree) carries
    # bin/ainish-coder + src/templates/AGENTS.deployed.md; targets receive
    # the deployed rules doc, source checkouts keep their own AGENTS.md.
    if [[ -f "$target_dir/bin/ainish-coder" && -f "$target_dir/src/templates/AGENTS.deployed.md" ]]; then
        echo -e "${YELLOW}⏭️  Skipping AGENTS.md deployment: $target_dir is an ainish-coder checkout (maintainer AGENTS.md stays)${RESET}"
        return 0
    fi

    # If the target repository has an existing AGENTS.deployed.md from a previous run,
    # clean it up so only the single governing AGENTS.md remains at the target.
    local redundant_deployed="$target_dir/AGENTS.deployed.md"
    if [[ -f "$redundant_deployed" || -L "$redundant_deployed" ]]; then
        if [[ ! -f "$target_dir/bin/ainish-coder" ]]; then
            rm -f "$redundant_deployed"
            echo -e "${YELLOW}🧹 Cleaned up redundant AGENTS.deployed.md at $target_dir (AGENTS.md is the single governing rules doc)${RESET}"
        fi
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
    echo -e "${BRIGHT_GREEN}✅ AGENTS.md (project-agnostic rules) is ready for all AI tools${RESET}"

    return 0
}

# deploy_agents_deployed <target_dir> — backwards-compatible alias:
# rules deployment now deploys the project-agnostic template directly as AGENTS.md.
deploy_agents_deployed() {
    deploy_agents "$@"
}

# Alias for backwards compatibility
deploy_agents_maintainer() {
    deploy_agents "$@"
}

# Global AGENTS.md symlink — ensures ~/.agents/AGENTS.md and ~/.config/AGENTS.md
# always point to the canonical project-agnostic rules template
# (src/templates/AGENTS.deployed.md) — the document distributed to every
# target repository's AGENTS.md.
deploy_agents_global() {
    local source="${REPO_DIR}/src/templates/AGENTS.deployed.md"
    [[ -f "$source" ]] || source="${REPO_DIR}/AGENTS.deployed.md"
    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: AGENTS.deployed.md template not found at $source${RESET}"
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
