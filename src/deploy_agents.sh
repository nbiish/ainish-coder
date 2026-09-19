#!/bin/bash
# MOLECULE: AGENTS.md deployment
# Deploys THE singular, repository-agnostic AGENTS.md (this repo's root
# AGENTS.md) as the target repository's single governing AGENTS.md.
# One contract everywhere: root AGENTS.md is both the live contract here
# and the distributed template — there is no separate deployed variant.
# Repository-specific direction lives in each repo's llms.txt DOX chain.

source "${SRC_DIR}/agents_protection.sh"

_is_windows_env() {
    [[ "${OS:-}" == "Windows_NT" ]] || [[ "${OSTYPE:-}" == "msys" ]] || [[ "${OSTYPE:-}" == "cygwin" ]]
}

_to_native_path() {
    local p="$1"
    if _is_windows_env && command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$p" 2>/dev/null || echo "$p"
    else
        echo "$p"
    fi
}

# Deploy AGENTS.md as a symlink pointing to the canonical root AGENTS.md
_deploy_agents_symlink() {
    local src="$1"
    local dest="$2"

    local dest_parent
    dest_parent="$(dirname "$dest")"
    mkdir -p "$dest_parent" || return 1

    # If destination already points to the exact source file (same file/symlink target)
    if [[ "$src" -ef "$dest" ]]; then
        return 0
    fi

    # Remove existing destination (regular file, old copy, or stale symlink)
    if [[ -e "$dest" || -L "$dest" ]]; then
        # Unlock if it was read-only so rm succeeds
        unlock_agents_contract "$dest" 2>/dev/null || true
        rm -rf "$dest" || return 1
    fi

    # Resolve source to absolute path
    local abs_src
    abs_src="$(cd "$(dirname "$src")" 2>/dev/null && pwd)/$(basename "$src")" || return 1

    local linked=false

    if _is_windows_env; then
        local win_dest win_src
        win_dest="$(_to_native_path "$dest")"
        win_src="$(_to_native_path "$abs_src")"

        # 1. Try native symlink via MSYS winsymlinks
        if MSYS="winsymlinks:nativestrict" ln -sf "$abs_src" "$dest" 2>/dev/null; then
            linked=true
        # 2. Try cmd.exe mklink (works if Developer Mode is enabled)
        elif MSYS2_ARG_CONV_EXCL="*" cmd.exe /c "mklink $win_dest $win_src" < /dev/null >/dev/null 2>&1; then
            linked=true
        # 3. If Windows developer mode is off and user is non-admin, fall back to NTFS hard link
        elif MSYS2_ARG_CONV_EXCL="*" cmd.exe /c "mklink /H $win_dest $win_src" < /dev/null >/dev/null 2>&1; then
            linked=true
            echo -e "${YELLOW}ℹ️  Linked via NTFS hardlink (Developer Mode not active for unprivileged symlinks).${RESET}"
            echo -e "${YELLOW}   Tip: Enable Windows Developer Mode in Settings -> System -> For developers to allow pure symlinks.${RESET}"
        fi
    else
        # POSIX systems (Linux/macOS)
        if ln -sf "$abs_src" "$dest" 2>/dev/null; then
            linked=true
        fi
    fi

    if [[ "$linked" != "true" ]]; then
        # Final fallback: standard deploy_path with symlink attempt
        if ! AINISH_LINK_MODE="true" deploy_path "$abs_src" "$dest"; then
            return 1
        fi
    fi

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

    echo -e "${BRIGHT_BLUE}Deploying AGENTS.md (canonical symlink) -> $dest${RESET}"

    # Check if we are trying to deploy the file onto itself
    if [[ "$source" -ef "$dest" ]]; then
        echo -e "${GREEN}✓ AGENTS.md is already up to date at $target_dir (same file/link)${RESET}"
        # Still ensure pre-commit guard and protection are active
        install_agents_pre_commit_guard "$target_dir" 2>/dev/null || true
        lock_agents_contract "$source" 2>/dev/null || true
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

    # In non-overwrite mode, check if destination already correctly points to source
    if [[ "${AINISH_NO_OVERWRITE:-false}" == "true" ]]; then
        if [[ "$source" -ef "$dest" ]]; then
            echo -e "${YELLOW}⏭️  Skipping AGENTS.md (already linked to root at $target_dir)${RESET}"
            return 0
        fi
    fi

    # Deploy as symbolic link from root repo
    if ! _deploy_agents_symlink "$source" "$dest"; then
        echo -e "${BRIGHT_RED}Error: Failed to symlink AGENTS.md to $dest${RESET}"
        return 1
    fi

    # Install pre-commit guard in target repository to block accidental commits modifying AGENTS.md
    install_agents_pre_commit_guard "$target_dir" 2>/dev/null || true

    # Ensure root contract is snapshotted and write-protected (read-only)
    snapshot_canonical_contract "$source" 2>/dev/null || true
    lock_agents_contract "$source" 2>/dev/null || true

    echo -e "${GREEN}✓ Symlinked AGENTS.md -> $source (updates propagate from root)${RESET}"
    echo -e "${BRIGHT_GREEN}🔒 Root AGENTS.md write-protected; downstream pre-commit guard active${RESET}"

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

# Global AGENTS.md symlink — ensures ~/.agents/AGENTS.md and ~/.config/AGENTS.md
# always point to the canonical singular AGENTS.md
deploy_agents_global() {
    local source="${REPO_DIR}/AGENTS.md"
    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: singular AGENTS.md not found at $source${RESET}"
        return 1
    fi

    mkdir -p "$HOME/.agents" "$HOME/.config"

    for dest in "$HOME/.agents/AGENTS.md" "$HOME/.config/AGENTS.md"; do
        if [[ "$source" -ef "$dest" ]]; then
            echo -e "${GREEN}✓ Global AGENTS.md link already correct: $dest${RESET}"
            continue
        fi

        if [[ -e "$dest" && ! -L "$dest" ]]; then
            local backup="${dest}.backup.$(date +%Y%m%d%H%M%S)"
            mv "$dest" "$backup"
            echo -e "${YELLOW}⚠ Backed up existing $dest to $backup${RESET}"
        fi

        _deploy_agents_symlink "$source" "$dest" || ln -sf "$source" "$dest"
        echo -e "${GREEN}✓ Symlinked AGENTS.md to $dest${RESET}"
    done
}
