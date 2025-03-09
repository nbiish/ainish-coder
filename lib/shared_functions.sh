#!/bin/bash
# Shared functions for AI tool configuration scripts

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to safely copy a file with backup if it exists
safe_copy_file() {
    local source_file="$1"
    local dest_file="$2"
    
    # Check if source file exists
    if [ ! -f "$source_file" ]; then
        echo "Source file does not exist: $source_file"
        return 1
    fi
    
    # Check if destination file already exists
    if [ -f "$dest_file" ]; then
        if [ "$AUTO_BACKUP_MODE" = "true" ]; then
            # Automatically backup and replace without prompting
            local timestamp=$(date +"%Y%m%d%H%M%S")
            local backup_file="${dest_file}.backup_${timestamp}"
            cp "$dest_file" "$backup_file"
            echo "Backed up to: $backup_file"
            cp "$source_file" "$dest_file"
            echo "Updated: $dest_file"
            return 0
        fi
        
        # Prompt user for choice
        echo "File already exists: $dest_file"
        echo "Would you like to:"
        echo "1) Keep existing file"
        echo "2) Backup existing file and replace with template"
        read -p "Enter your choice (1/2): " choice
        
        if [ "$choice" == "2" ]; then
            local timestamp=$(date +"%Y%m%d%H%M%S")
            local backup_file="${dest_file}.backup_${timestamp}"
            cp "$dest_file" "$backup_file"
            echo "Backed up to: $backup_file"
            cp "$source_file" "$dest_file"
            echo "Updated: $dest_file"
        else
            echo "Keeping existing file: $dest_file"
        fi
    else
        # If file doesn't exist, just copy it
        cp "$source_file" "$dest_file"
        echo "Created: $dest_file"
    fi
    
    return 0
}

# Function to check if a path leads to a directory
check_project_dir() {
    local target_path="$1"
    
    # If the argument is a directory
    if [ -d "$target_path" ]; then
        return 0  # True
    # If the argument is a file, check its parent directory
    elif [ -f "$target_path" ]; then
        return 0  # True
    fi
    
    return 1  # False
}

# Function to get the project directory from an argument
get_project_dir() {
    local target="$1"
    local project_path=""
    
    # If no argument provided, use current directory
    if [ -z "$target" ]; then
        project_path="$(pwd)"
        return 0
    fi
    
    # Convert to absolute path if relative
    if [[ ! "$target" = /* ]]; then
        target="$(pwd)/$target"
    fi
    
    # Check if this is a valid project directory
    if check_project_dir "$target"; then
        # Determine the correct project path
        project_path="$target"
        if [ -f "$target" ]; then
            project_path=$(dirname "$target")
        fi
        echo "$project_path"
        return 0
    else
        echo "Error: Not a valid directory or file: $target"
        return 1
    fi
} 