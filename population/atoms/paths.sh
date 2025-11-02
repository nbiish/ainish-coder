#!/bin/bash
# Path utilities and constants

# Get the absolute path of the script directory
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
}

# Get the project root directory (parent of lib/)
get_project_root() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
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
