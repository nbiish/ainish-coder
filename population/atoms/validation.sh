#!/bin/bash
# Input validation utilities

# Validate that a path exists
validate_path_exists() {
    local path="$1"
    if [[ ! -e "$path" ]]; then
        echo "Error: Path does not exist: $path" >&2
        return 1
    fi
    return 0
}

# Validate that a directory exists
validate_dir_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "Error: Directory does not exist: $dir" >&2
        return 1
    fi
    return 0
}

# Validate command line arguments
validate_args() {
    local expected="$1"
    local actual="$2"
    
    if [[ $actual -lt $expected ]]; then
        echo "Error: Expected at least $expected arguments, got $actual" >&2
        return 1
    fi
    return 0
}
