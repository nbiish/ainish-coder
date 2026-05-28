#!/bin/bash
# Path utilities and constants

# Repository root directory (ainish-coder installation)
# This should be set by the main script that sources this file
if [[ -z "${REPO_DIR:-}" ]]; then
    # Try to detect it from the script location
    REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
export REPO_DIR

# Get the absolute path of the script directory
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
}

# Get the project root directory (ainish-coder repository root)
get_project_root() {
    echo "$REPO_DIR"
}

# Check if a path is absolute
is_absolute_path() {
    [[ "$1" = /* ]] && return 0 || return 1
}

# Convert relative path to absolute
to_absolute_path() {
    local path="$1"
    if is_absolute_path "$path"; then
        echo "$path"
    else
        echo "$(pwd)/$path"
    fi
}

# Ensure directory exists
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || return 1
    fi
    return 0
}
