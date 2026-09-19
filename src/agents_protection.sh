#!/bin/bash
# MOLECULE: AGENTS.md Protection & Canonical Integrity
# Ensures the singular root AGENTS.md cannot be overwritten by downstream
# repositories or automated agents, while remaining easily editable at root.
# Supported platforms: Linux, macOS (Darwin), Windows (MSYS/Git Bash/WSL).

# Detect if the environment is Windows
_is_windows_env() {
    [[ "${OS:-}" == "Windows_NT" ]] || [[ "${OSTYPE:-}" == "msys" ]] || [[ "${OSTYPE:-}" == "cygwin" ]]
}

# Detect if the environment is macOS (Darwin)
_is_darwin() {
    [[ "$(uname -s 2>/dev/null)" == "Darwin" ]] || [[ "${OSTYPE:-}" == darwin* ]]
}

# Detect if the environment is Linux
_is_linux() {
    [[ "$(uname -s 2>/dev/null)" == "Linux" ]] || [[ "${OSTYPE:-}" == linux* ]]
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
    elif _is_darwin; then
        # macOS: apply chmod 444 first, then BSD user immutable flag (uchg).
        # chmod must precede chflags because chmod fails with EPERM once uchg is active.
        chmod 444 "$target_file" 2>/dev/null || chmod a-w "$target_file" 2>/dev/null || true
        chflags uchg "$target_file" 2>/dev/null || true
    else
        # Linux / POSIX: revoke write bits for all users; set immutable flag if permitted.
        chmod 444 "$target_file" 2>/dev/null || chmod a-w "$target_file" 2>/dev/null || true
        chattr +i "$target_file" 2>/dev/null || true
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
    elif _is_darwin; then
        # macOS: clear BSD user immutable flag FIRST so chmod and writes succeed
        chflags nouchg "$target_file" 2>/dev/null || true
        chmod 644 "$target_file" 2>/dev/null || chmod u+w "$target_file" 2>/dev/null || true
    else
        # Linux / POSIX: clear immutable attribute if set, then restore user write permission
        chattr -i "$target_file" 2>/dev/null || true
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

    # 1. Standard POSIX write test: if not writable, it is locked
    if [[ ! -w "$target_file" ]]; then
        return 0
    fi

    # 2. Darwin (macOS): check BSD user immutable flag (uchg)
    if _is_darwin; then
        if ls -lO "$target_file" 2>/dev/null | grep -qw "uchg"; then
            return 0
        fi
    fi

    # 3. Linux: check ext/xfs/btrfs immutable attribute
    if _is_linux && command -v lsattr >/dev/null 2>&1; then
        if lsattr -d "$target_file" 2>/dev/null | grep -q "^....i"; then
            return 0
        fi
    fi

    # 4. Windows: check Read-Only attribute
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

# Calculate SHA256 checksum portably across Linux, macOS, BSD, and Windows
_calc_sha256() {
    local target_file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$target_file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$target_file" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$target_file" | awk '{print $NF}'
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], 'rb').read()).hexdigest())" "$target_file" 2>/dev/null
    elif command -v python >/dev/null 2>&1; then
        python -c "import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], 'rb').read()).hexdigest())" "$target_file" 2>/dev/null
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

    local guard_code
    guard_code="$(cat << 'HOOK_BLOCK'
# --- AINISH-CODER AGENTS.MD GUARD START ---
# Prevent downstream commits from modifying or decoupling the canonical AGENTS.md
if git rev-parse --verify HEAD >/dev/null 2>&1; then
    staged_agents=$(git diff-index --cached --name-only HEAD 2>/dev/null | grep -E '^AGENTS\.md$' || true)
else
    staged_agents=$(git diff-index --cached --name-only 4b825dc642cb6eb9a060e54bf8d69288fbee4904 2>/dev/null | grep -E '^AGENTS\.md$' || true)
fi

if [ -n "$staged_agents" ]; then
    printf "\033[1;31m[ERROR] AGENTS.md is a protected canonical symlink managed by ainish-coder.\033[0m\n" >&2
    printf "\033[1;33mModifying or committing AGENTS.md in downstream repositories is forbidden.\033[0m\n" >&2
    printf "  -> Move all project-specific rules, contracts, and guidelines to llms.txt.\n" >&2
    printf "  -> To revert changes to AGENTS.md: git checkout -- AGENTS.md\n" >&2
    printf "  -> To re-establish the symlink: ainish-coder --rules\n" >&2
    exit 1
fi
# --- AINISH-CODER AGENTS.MD GUARD END ---
HOOK_BLOCK
)"

    if [[ ! -f "$pre_commit_hook" ]]; then
        printf "#!/bin/sh\n\n%s\n" "$guard_code" > "$pre_commit_hook"
    else
        # If pre-commit exists, prepend the guard right after the shebang line
        # so it runs before any other hook logic (even if the existing hook exits 0 later)
        local tmp_hook="${pre_commit_hook}.tmp.$$"
        local first_line
        first_line="$(head -n 1 "$pre_commit_hook" 2>/dev/null || echo "#!/bin/sh")"
        if [[ "$first_line" =~ ^#! ]]; then
            {
                echo "$first_line"
                echo ""
                echo "$guard_code"
                echo ""
                tail -n +2 "$pre_commit_hook"
            } > "$tmp_hook"
        else
            {
                echo "#!/bin/sh"
                echo ""
                echo "$guard_code"
                echo ""
                cat "$pre_commit_hook"
            } > "$tmp_hook"
        fi
        mv "$tmp_hook" "$pre_commit_hook"
    fi

    chmod 755 "$pre_commit_hook" 2>/dev/null || chmod +x "$pre_commit_hook" 2>/dev/null || true
    echo -e "${GREEN}✓ Installed downstream AGENTS.md pre-commit protection in ${target_dir}${RESET}"
    return 0
}
