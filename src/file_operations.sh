#!/bin/bash
# File operation utilities

# Copy file with backup
copy_with_backup() {
    local src="$1"
    local dest="$2"

    # Create backup if destination exists
    if [[ -f "$dest" ]]; then
        cp "$dest" "${dest}.backup" || return 1
    fi

    # Copy the file
    cp "$src" "$dest" || return 1
    return 0
}

# Create symlink with backup
symlink_with_backup() {
    local target="$1"
    local link="$2"

    # Remove existing link or backup file
    if [[ -L "$link" ]] || [[ -f "$link" ]]; then
        mv "$link" "${link}.backup" 2>/dev/null || rm -f "$link"
    fi

    # Create symlink
    ln -s "$target" "$link" || return 1
    return 0
}

# Safe remove (with confirmation for existing files)
safe_remove() {
    local file="$1"
    if [[ -e "$file" ]]; then
        rm -f "$file" || return 1
    fi
    return 0
}

# Check if file exists and is readable
file_exists_and_readable() {
    [[ -f "$1" ]] && [[ -r "$1" ]] && return 0 || return 1
}

# Deploy a file or directory from source to destination.
# When AINISH_LINK_MODE=true, creates a symlink instead of copying.
# When AINISH_NO_OVERWRITE=true, skips existing destinations.
# Creates parent directories as needed.
# Usage: deploy_path <source> <dest>
deploy_path() {
    local src="$1"
    local dest="$2"

    # Non-destructive mode: skip if destination already exists
    if [[ "${AINISH_NO_OVERWRITE:-false}" == "true" ]]; then
        if [[ -e "$dest" || -L "$dest" ]]; then
            echo "  ⏭️  Skipping (already exists): $dest" >&2
            return 0
        fi
    fi

    # Ensure parent directory exists
    local dest_parent
    dest_parent="$(dirname "$dest")"
    mkdir -p "$dest_parent" || return 1

    # Remove existing file/link/dir at destination
    if [[ -e "$dest" || -L "$dest" ]]; then
        rm -rf "$dest" || return 1
    fi

    if [[ "${AINISH_LINK_MODE:-false}" == "true" ]]; then
        # Resolve source to absolute so symlinks survive directory moves
        local abs_src
        abs_src="$(cd "$(dirname "$src")" 2>/dev/null && pwd)/$(basename "$src")" || return 1
        if [[ -d "$abs_src" ]]; then
            ln -sfn "$abs_src" "$dest" || return 1
        else
            ln -sf "$abs_src" "$dest" || return 1
        fi
    else
        if [[ -d "$src" ]]; then
            # Copy the tree but strip the secrets surface (.env is
            # local-only; .env.example distributes as the template) and
            # runtime junk (__pycache__).
            if ! cp -r "$src" "$dest"; then
                return 1
            fi
            rm -f "$dest/.env" || true
            rm -rf "$dest/__pycache__" || true
        else
            cp "$src" "$dest" || return 1
        fi
    fi
    return 0
}

# Deploy all files from a source directory into a destination directory.
# When AINISH_LINK_MODE=true, symlinks each file individually.
# When AINISH_NO_OVERWRITE=true, skips files that already exist at destination.
# Usage: deploy_path_contents <src_dir> <dest_dir>
deploy_path_contents() {
    local src_dir="$1"
    local dest_dir="$2"

    mkdir -p "$dest_dir" || return 1

    # Non-destructive mode: deploy only files that don't already exist
    if [[ "${AINISH_NO_OVERWRITE:-false}" == "true" ]]; then
        local skipped=0 deployed=0 rc=0
        shopt -s dotglob nullglob
        for item in "$src_dir"/*; do
            [[ -e "$item" ]] || continue
            local name
            name="$(basename "$item")"
            # Secrets never distribute: skill-local .env is a local-only
            # config surface (.env.example is the distributed template).
            # Runtime junk (__pycache__) never distributes either.
            if [[ "$name" == ".env" || "$name" == "__pycache__" ]]; then
                continue
            fi
            if [[ -e "$dest_dir/$name" || -L "$dest_dir/$name" ]]; then
                echo "  ⏭️  Skipping (already exists): $dest_dir/$name" >&2
                ((skipped++)) || true
            else
                if [[ -d "$item" ]]; then
                    cp -r "$item" "$dest_dir/$name" || rc=1
                else
                    cp "$item" "$dest_dir/$name" || rc=1
                fi
                ((deployed++)) || true
            fi
        done
        if [[ $deployed -gt 0 ]]; then
            echo "  ✓ Deployed $deployed new file(s)" >&2
        fi
        if [[ $skipped -gt 0 ]]; then
            echo "  ⏭️  Skipped $skipped existing file(s)" >&2
        fi
        shopt -u dotglob nullglob
        return "$rc"
    fi

    if [[ "${AINISH_LINK_MODE:-false}" == "true" ]]; then
        local abs_src rc=0 item
        abs_src="$(cd "$src_dir" 2>/dev/null && pwd)" || return 1
        for item in "$abs_src"/*; do
            [[ -e "$item" ]] || continue
            local name
            name="$(basename "$item")"
            # Secrets and runtime junk never distribute.
            if [[ "$name" == ".env" || "$name" == "__pycache__" ]]; then
                continue
            fi
            rm -f "$dest_dir/$name" || { rc=1; continue; }
            if [[ -d "$item" ]]; then
                ln -sfn "$item" "$dest_dir/$name" || rc=1
            else
                ln -sf "$item" "$dest_dir/$name" || rc=1
            fi
        done
        return "$rc"
    else
        # Explicit dotfile-aware copy (glob * misses .env/.env.example);
        # secrets (.env) never distribute — .env.example does. Runtime junk
        # (__pycache__) never distributes either. Per-item failures are
        # collected into the return code so callers running under `set -e`
        # degrade gracefully instead of aborting the whole run.
        shopt -s dotglob nullglob
        local item name rc=0
        for item in "$src_dir"/*; do
            [[ -e "$item" ]] || continue
            name="$(basename "$item")"
            if [[ "$name" == ".env" || "$name" == "__pycache__" ]]; then
                continue
            fi
            if ! rm -rf "$dest_dir/$name"; then
                rc=1
                continue
            fi
            if [[ -d "$item" ]]; then
                cp -r "$item" "$dest_dir/$name" || rc=1
            else
                cp "$item" "$dest_dir/$name" || rc=1
            fi
        done
        shopt -u dotglob nullglob
        return "$rc"
    fi
}
