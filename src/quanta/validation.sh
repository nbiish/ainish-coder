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

# Ask for user confirmation. Returns 0 if yes, 1 if no.
confirm_action() {
    local prompt="$1"
    local default="${2:-n}" # y or n
    
    if [[ "${AINISH_NON_INTERACTIVE:-false}" == "true" ]]; then
        if [[ "$default" == "y" ]]; then
            return 0
        else
            return 1
        fi
    fi
    
    # Check if stdin is a tty
    if [[ ! -t 0 ]]; then
        if [[ "$default" == "y" ]]; then
            return 0
        else
            return 1
        fi
    fi
    
    local yn
    while true; do
        if [[ "$default" == "y" ]]; then
            echo -ne "${BRIGHT_YELLOW}▸ ${RESET}${prompt} [Y/n]: "
        else
            echo -ne "${BRIGHT_YELLOW}▸ ${RESET}${prompt} [y/N]: "
        fi
        
        # Read user response
        if ! read -r yn; then
            # If EOF, return default
            if [[ "$default" == "y" ]]; then
                return 0
            else
                return 1
            fi
        fi
        
        # Trim whitespace and lowercase
        yn=$(echo "$yn" | tr '[:upper:]' '[:lower:]' | xargs)
        
        if [[ -z "$yn" ]]; then
            if [[ "$default" == "y" ]]; then
                return 0
            else
                return 1
            fi
        fi
        
        case "$yn" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "Please answer yes (y) or no (n)." ;;
        esac
    done
}

