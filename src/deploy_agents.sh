#!/bin/bash
# MOLECULE: AGENTS.md deployment
# Deploys THE singular, repository-agnostic AGENTS.md (this repo's root
# AGENTS.md) into target repositories as a plain tracked COPY.
# One contract everywhere: root AGENTS.md is the single source of truth;
# every target owns a committed copy refreshed by re-running
# `ainish-coder --rules`. No symlinks: deployment never writes through a
# link, so the root file can never be overwritten from downstream.
# Repository-specific direction lives in each repo's llms.txt DOX chain.
# Supported platforms: Linux, macOS (Darwin), Windows (MSYS/Git Bash/WSL).

SRC_DIR="${SRC_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)}"
source "${SRC_DIR}/agents_protection.sh"

# Deploy AGENTS.md as a plain tracked copy of the canonical root file
_deploy_agents_copy() {
    local src="$1"
    local dest="$2"

    local dest_parent
    dest_parent="$(dirname "$dest")"
    mkdir -p "$dest_parent" || return 1

    # Already a regular file identical to the source — up to date
    if [[ -f "$dest" && ! -L "$dest" ]] && cmp -s "$src" "$dest" 2>/dev/null; then
        return 0
    fi

    # Remove existing destination (stale copy or legacy symlink).
    # rm on a symlink removes the LINK itself, never the target — this is
    # the mechanism that keeps the root contract safe from downstream writes.
    if [[ -e "$dest" || -L "$dest" ]]; then
        unlock_agents_contract "$dest" 2>/dev/null || true
        rm -f "$dest" || return 1
    fi

    cp -f "$src" "$dest" || return 1
    return 0
}

deploy_agents() {
    local target_dir="${1:-.}"  # Default to current directory if not provided

    validate_target_dir "$target_dir" || return 1

    local source="${REPO_DIR}/AGENTS.md"
    local dest="$target_dir/AGENTS.md"

    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: singular AGENTS.md not found at $source${RESET}"
        return 1
    fi

    echo -e "${BRIGHT_BLUE}Deploying AGENTS.md (tracked copy of canonical) -> $dest${RESET}"

    # Deploying onto the root repo itself (plain file, same inode/content)
    if [[ ! -L "$dest" && "$source" -ef "$dest" ]]; then
        echo -e "${GREEN}✓ AGENTS.md is already the canonical file at $target_dir${RESET}"
        # Still ensure the warn-only pre-commit guard and snapshot are active
        install_agents_pre_commit_guard "$target_dir" 2>/dev/null || true
        snapshot_canonical_contract "$source" 2>/dev/null || true
        return 0
    fi

    # Clean up legacy files if present
    local legacy_deployed="$target_dir/AGENTS.deployed.md"
    if [[ -f "$legacy_deployed" || -L "$legacy_deployed" ]]; then
        rm -f "$legacy_deployed"
        echo -e "${YELLOW}🧹 Cleaned up legacy AGENTS.deployed.md at $target_dir${RESET}"
    fi
    local legacy_template="$target_dir/src/templates/AGENTS.deployed.md"
    if [[ -f "$legacy_template" && ! -f "$target_dir/bin/ainish-coder" ]]; then
        rm -f "$legacy_template"
        echo -e "${YELLOW}🧹 Cleaned up legacy src/templates/AGENTS.deployed.md at $target_dir${RESET}"
    fi

    # In non-overwrite mode, skip only when already a fresh regular copy
    if [[ "${AINISH_NO_OVERWRITE:-false}" == "true" ]]; then
        if [[ -f "$dest" && ! -L "$dest" ]] && cmp -s "$source" "$dest" 2>/dev/null; then
            echo -e "${YELLOW}⏭️  Skipping AGENTS.md (already an up-to-date copy at $target_dir)${RESET}"
            return 0
        fi
    fi

    # Deploy a plain tracked copy from the root repo
    if ! _deploy_agents_copy "$source" "$dest"; then
        echo -e "${BRIGHT_RED}Error: Failed to copy AGENTS.md to $dest${RESET}"
        return 1
    fi

    # Install/refresh the warn-only AGENTS.md pre-commit guard in the target repo
    install_agents_pre_commit_guard "$target_dir" 2>/dev/null || true

    # Keep the canonical snapshot current (restore path); root stays writable
    snapshot_canonical_contract "$source" 2>/dev/null || true

    echo -e "${GREEN}✓ Copied latest AGENTS.md -> $dest (refresh with: ainish-coder --rules)${RESET}"
    echo -e "${BRIGHT_GREEN}📄 Root AGENTS.md is the single source of truth; the target owns its tracked copy${RESET}"

    return 0
}

# deploy_agents_deployed <target_dir> — backwards-compatible alias
deploy_agents_deployed() {
    deploy_agents "$@"
}

# Alias for backwards compatibility
deploy_agents_maintainer() {
    deploy_agents "$@"
}

# Global AGENTS.md copies — keeps ~/.agents/AGENTS.md and ~/.config/AGENTS.md
# as plain copies of the canonical singular AGENTS.md (no symlinks)
deploy_agents_global() {
    local source="${REPO_DIR}/AGENTS.md"
    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: singular AGENTS.md not found at $source${RESET}"
        return 1
    fi

    mkdir -p "$HOME/.agents" "$HOME/.config"

    for dest in "$HOME/.agents/AGENTS.md" "$HOME/.config/AGENTS.md"; do
        if [[ -f "$dest" && ! -L "$dest" ]] && cmp -s "$source" "$dest" 2>/dev/null; then
            echo -e "${GREEN}✓ Global AGENTS.md copy already up to date: $dest${RESET}"
            continue
        fi

        # Back up an existing customized regular file before overwriting
        if [[ -f "$dest" && ! -L "$dest" ]]; then
            local backup="${dest}.backup.$(date +%Y%m%d%H%M%S)"
            mv "$dest" "$backup"
            echo -e "${YELLOW}⚠ Backed up existing $dest to $backup${RESET}"
        fi

        if ! _deploy_agents_copy "$source" "$dest"; then
            echo -e "${BRIGHT_RED}Error: failed to copy AGENTS.md to $dest${RESET}"
            continue
        fi
        echo -e "${GREEN}✓ Copied latest AGENTS.md to $dest${RESET}"
    done
}
