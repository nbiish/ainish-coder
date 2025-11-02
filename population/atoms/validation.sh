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

# Validate target directory (creates if doesn't exist)
validate_target_dir() {
    local dir="$1"
    
    if [[ -z "$dir" ]]; then
        echo "Error: No target directory specified" >&2
        return 1
    fi
    
    # Create directory if it doesn't exist
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" 2>/dev/null || {
            echo "Error: Cannot create directory: $dir" >&2
            return 1
        }
    fi
    
    # Check if directory is writable
    if [[ ! -w "$dir" ]]; then
        echo "Error: Directory is not writable: $dir" >&2
        return 1
    fi
    
    return 0
}

# Safe mkdir (creates directory if doesn't exist)
safe_mkdir() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" 2>/dev/null || {
            echo "Error: Cannot create directory: $dir" >&2
            return 1
        }
    fi
    
    return 0
}

# Require AGENTS.md to exist in target directory
require_agents_md() {
    local target_dir="$1"
    local agents_file="$target_dir/AGENTS.md"
    
    if [[ ! -f "$agents_file" ]]; then
        echo "Error: AGENTS.md not found in $target_dir" >&2
        echo "Run: ainish-coder --agents $target_dir" >&2
        return 1
    fi
    
    return 0
}

# Require MAIRULES.md to exist in target directory
require_mairules_md() {
    local target_dir="$1"
    local mairules_file="$target_dir/MAIRULES.md"
    
    if [[ ! -f "$mairules_file" ]]; then
        echo "Error: MAIRULES.md not found in $target_dir" >&2
        echo "Run: ainish-coder --mairules $target_dir" >&2
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
