#!/bin/bash
# MOLECULE: AGENTS.md Protection & Canonical Integrity
# Ensures the singular root AGENTS.md cannot be overwritten by downstream
# repositories or automated agents, while remaining easily editable at root.

# Detect if the environment is Windows
_is_windows_env() {
    [[ "${OS:-}" == "Windows_NT" ]] || [[ "${OSTYPE:-}" == "msys" ]] || [[ "${OSTYPE:-}" == "cygwin" ]]
}

# Convert path to Windows native format if on Windows
_to_native_path() {
    local p="$1"
    if _is_windows_env && command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$p" 2>/dev/null || echo "$p"
    else
        echo "$p"
    fi
}

# Run attrib.exe on Windows safely
_run_attrib() {
    if command -v attrib.exe >/dev/null 2>&1; then
        attrib.exe "$@"
    elif [[ -x "/c/Windows/System32/attrib.exe" ]]; then
        /c/Windows/System32/attrib.exe "$@"
    elif [[ -x "$WINDIR/System32/attrib.exe" ]]; then
        "$WINDIR/System32/attrib.exe" "$@"
    fi
}

# Apply OS-level write-protection (read-only) to AGENTS.md
lock_agents_contract() {
    local target_file="${1:-${REPO_DIR}/AGENTS.md}"
    if [[ ! -e "$target_file" ]]; then
        echo -e "${YELLOW}Warning: Target file not found to lock: $target_file${RESET}" >&2
        return 1
    fi

    if _is_windows_env; then
        local win_path
        win_path="$(_to_native_path "$target_file")"
        _run_attrib +R "$win_path" >/dev/null 2>&1 || true
        chmod 444 "$target_file" 2>/dev/null || true
    else
        chmod 444 "$target_file" 2>/dev/null || chmod a-w "$target_file" 2>/dev/null || true
    fi

    return 0
}

# Remove OS-level write-protection to allow editing in root repository
unlock_agents_contract() {
    local target_file="${1:-${REPO_DIR}/AGENTS.md}"
    if [[ ! -e "$target_file" ]]; then
        echo -e "${YELLOW}Warning: Target file not found to unlock: $target_file${RESET}" >&2
        return 1
    fi

    if _is_windows_env; then
        local win_path
        win_path="$(_to_native_path "$target_file")"
        _run_attrib -R "$win_path" >/dev/null 2>&1 || true
        chmod 644 "$target_file" 2>/dev/null || true
    else
        chmod 644 "$target_file" 2>/dev/null || chmod u+w "$target_file" 2>/dev/null || true
    fi

    return 0
}

# Check if AGENTS.md is write-protected
is_agents_contract_locked() {
    local target_file="${1:-${REPO_DIR}/AGENTS.md}"
    if [[ ! -e "$target_file" ]]; then
        return 1
    fi

    if [[ ! -w "$target_file" ]]; then
        return 0
    fi

    if _is_windows_env; then
        local win_path
        win_path="$(_to_native_path "$target_file")"
        local attrib_out
        attrib_out="$(_run_attrib "$win_path" 2>/dev/null || true)"
        if [[ "$attrib_out" =~ [[:space:]]R[[:space:]] ]]; then
            return 0
        fi
    fi

    return 1
}

# Calculate SHA256 checksum portably
_calc_sha256() {
    local target_file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$target_file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$target_file" | awk '{print $1}'
    elif command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -NoProfile -Command "(Get-FileHash -Path "$(_to_native_path "$target_file")" -Algorithm SHA256).Hash.ToLower()" 2>/dev/null | tr -d '\r\n'
    else
        cksum "$target_file" | awk '{print $1}'
    fi
}

# Create canonical snapshot and hash of the root AGENTS.md
snapshot_canonical_contract() {
    local source_file="${1:-${REPO_DIR}/AGENTS.md}"
    local snapshot_dir="${2:-${REPO_DIR}/.agents/canonical}"

    if [[ ! -f "$source_file" ]]; then
        echo -e "${BRIGHT_RED}Error: Source contract not found at $source_file${RESET}" >&2
        return 1
    fi

    mkdir -p "$snapshot_dir" || return 1
    local dest_copy="${snapshot_dir}/AGENTS.md"
    local dest_hash="${snapshot_dir}/AGENTS.md.sha256"

    # Unlock destination if locked from previous run
    unlock_agents_contract "$dest_copy" 2>/dev/null || true

    cp "$source_file" "$dest_copy" || return 1
    local hash_val
    hash_val="$(_calc_sha256 "$source_file")"
    echo "$hash_val" > "$dest_hash"

    lock_agents_contract "$dest_copy" 2>/dev/null || true
    return 0
}

# Verify root AGENTS.md matches canonical snapshot
verify_canonical_contract() {
    local source_file="${1:-${REPO_DIR}/AGENTS.md}"
    local snapshot_dir="${2:-${REPO_DIR}/.agents/canonical}"
    local dest_hash="${snapshot_dir}/AGENTS.md.sha256"

    if [[ ! -f "$source_file" ]]; then
        echo -e "${BRIGHT_RED}Error: AGENTS.md not found at $source_file${RESET}" >&2
        return 1
    fi

    if [[ ! -f "$dest_hash" ]]; then
        # If no snapshot exists yet, generate one
        snapshot_canonical_contract "$source_file" "$snapshot_dir" || return 1
    fi

    local expected_hash actual_hash
    expected_hash="$(cat "$dest_hash" | tr -d '[:space:]')"
    actual_hash="$(_calc_sha256 "$source_file" | tr -d '[:space:]')"

    if [[ "$expected_hash" != "$actual_hash" ]]; then
        echo -e "${BRIGHT_RED}❌ Integrity Mismatch: AGENTS.md differs from canonical snapshot!${RESET}" >&2
        echo -e "   Expected: $expected_hash" >&2
        echo -e "   Actual:   $actual_hash" >&2
        return 1
    fi

    return 0
}

# Restore AGENTS.md from canonical snapshot or git HEAD
restore_canonical_contract() {
    local target_file="${1:-${REPO_DIR}/AGENTS.md}"
    local snapshot_dir="${2:-${REPO_DIR}/.agents/canonical}"
    local canonical_copy="${snapshot_dir}/AGENTS.md"

    echo -e "${BRIGHT_BLUE}Restoring canonical AGENTS.md...${RESET}"
    unlock_agents_contract "$target_file" 2>/dev/null || true

    if [[ -f "$canonical_copy" ]]; then
        cp "$canonical_copy" "$target_file" || return 1
        echo -e "${GREEN}✓ Restored AGENTS.md from canonical snapshot (${canonical_copy})${RESET}"
    else
        # Fall back to git checkout
        if git -C "${REPO_DIR}" checkout -- AGENTS.md 2>/dev/null; then
            echo -e "${GREEN}✓ Restored AGENTS.md from git repository HEAD${RESET}"
            snapshot_canonical_contract "$target_file" "$snapshot_dir" || true
        else
            echo -e "${BRIGHT_RED}Error: Could not restore AGENTS.md (no snapshot or git history)${RESET}" >&2
            return 1
        fi
    fi

    lock_agents_contract "$target_file" || true
    echo -e "${BRIGHT_GREEN}🔒 AGENTS.md restored and write-protected${RESET}"
    return 0
}

# Install pre-commit hook in target repository to block downstream modifications to AGENTS.md
install_agents_pre_commit_guard() {
    local target_dir="${1:-.}"
    local git_dir="${target_dir}/.git"

    # If target is not a git repo, skip hook installation
    if [[ ! -d "$git_dir" ]]; then
        return 0
    fi

    local hooks_dir="${git_dir}/hooks"
    mkdir -p "$hooks_dir" || return 1
    local pre_commit_hook="${hooks_dir}/pre-commit"

    local guard_start="# --- AINISH-CODER AGENTS.MD GUARD START ---"
    local guard_end="# --- AINISH-CODER AGENTS.MD GUARD END ---"

    # Check if already installed
    if [[ -f "$pre_commit_hook" ]] && grep -qF "$guard_start" "$pre_commit_hook" 2>/dev/null; then
        return 0
    fi

    if [[ ! -f "$pre_commit_hook" ]]; then
        echo "#!/bin/sh" > "$pre_commit_hook"
    else
        echo "" >> "$pre_commit_hook"
    fi

    cat >> "$pre_commit_hook" << 'HOOK_BLOCK'
# --- AINISH-CODER AGENTS.MD GUARD START ---
# Prevent downstream commits from modifying or decoupling the canonical AGENTS.md
if git rev-parse --verify HEAD >/dev/null 2>&1; then
    staged_agents=$(git diff-index --cached --name-only HEAD | grep -E '^AGENTS\.md$' || true)
else
    staged_agents=$(git diff-index --cached --name-only 4b825dc642cb6eb9a060e54bf8d69288fbee4904 | grep -E '^AGENTS\.md$' || true)
fi

if [ -n "$staged_agents" ]; then
    echo "[1;31m[ERROR] AGENTS.md is a protected canonical symlink managed by ainish-coder.[0m" >&2
    echo "[1;33mModifying or committing AGENTS.md in downstream repositories is forbidden.[0m" >&2
    echo "  -> Move all project-specific rules, contracts, and guidelines to llms.txt." >&2
    echo "  -> To revert changes to AGENTS.md: git checkout -- AGENTS.md" >&2
    echo "  -> To re-establish the symlink: ainish-coder --rules[0m" >&2
    exit 1
fi
# --- AINISH-CODER AGENTS.MD GUARD END ---
HOOK_BLOCK

    chmod +x "$pre_commit_hook" 2>/dev/null || true
    echo -e "${GREEN}✓ Installed downstream AGENTS.md pre-commit protection in ${target_dir}${RESET}"
    return 0
}
