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
