#!/bin/bash

# Define source paths
REPO_PATH="/Volumes/1tb-sandisk/code/mai-coder"
HOME_CONFIG_PATH="$HOME/.mai-coder"

# Function to copy configuration files
copy_config_files() {
    local target_path="$1"
    
    # Copy .cursorrules if it exists in source
    if [ -f "$HOME_CONFIG_PATH/mai-cursor/.cursorrules" ]; then
        source_file="$HOME_CONFIG_PATH/mai-cursor/.cursorrules"
        target_file="$target_path/.cursorrules"
        
        if [ -f "$target_file" ]; then
            # Check if files are identical before prompting
            if ! cmp -s "$source_file" "$target_file"; then
                read -p "File $target_file exists and is different. Overwrite? (y/n): " choice
                if [[ $choice =~ ^[Yy]$ ]]; then
                    cp "$source_file" "$target_file"
                    echo "Updated: $target_file"
                else
                    echo "Kept existing: $target_file"
                fi
            fi
        else
            cp "$source_file" "$target_file"
            echo "Installed: $target_file"
        fi
    fi
    
    # Copy .cursorindexingignore if it exists in source
    if [ -f "$HOME_CONFIG_PATH/mai-cursor/.cursorindexingignore" ]; then
        source_file="$HOME_CONFIG_PATH/mai-cursor/.cursorindexingignore"
        target_file="$target_path/.cursorindexingignore"
        
        if [ -f "$target_file" ]; then
            # Check if files are identical before prompting
            if ! cmp -s "$source_file" "$target_file"; then
                read -p "File $target_file exists and is different. Overwrite? (y/n): " choice
                if [[ $choice =~ ^[Yy]$ ]]; then
                    cp "$source_file" "$target_file"
                    echo "Updated: $target_file"
                else
                    echo "Kept existing: $target_file"
                fi
            fi
        else
            cp "$source_file" "$target_file"
            echo "Installed: $target_file"
        fi
    fi
    
    # Copy .cursorignore if it exists in source
    if [ -f "$HOME_CONFIG_PATH/mai-cursor/.cursorignore" ]; then
        source_file="$HOME_CONFIG_PATH/mai-cursor/.cursorignore"
        target_file="$target_path/.cursorignore"
        
        if [ -f "$target_file" ]; then
            # Check if files are identical before prompting
            if ! cmp -s "$source_file" "$target_file"; then
                read -p "File $target_file exists and is different. Overwrite? (y/n): " choice
                if [[ $choice =~ ^[Yy]$ ]]; then
                    cp "$source_file" "$target_file"
                    echo "Updated: $target_file"
                else
                    echo "Kept existing: $target_file"
                fi
            fi
        else
            cp "$source_file" "$target_file"
            echo "Installed: $target_file"
        fi
    fi
}

# Function to check if a path leads to a directory
check_project_dir() {
    local target_path="$1"
    
    if [ -d "$target_path" ]; then
        return 0  # True
    elif [ -f "$target_path" ]; then
        return 0  # True
    fi
    
    return 1  # False
}

# Main logic
if [ $# -gt 0 ]; then
    target="$1"
    
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
        
        # Copy configuration files
        copy_config_files "$project_path"
    fi
fi

# Find the actual cursor executable
CURSOR_PATH=$(which -a cursor 2>/dev/null | grep -v "$HOME/.mai-coder/bin/cursor" | head -1)
if [ -z "$CURSOR_PATH" ]; then
    # Fixed path fallback
    if [ -f "/usr/local/bin/cursor" ]; then
        CURSOR_PATH="/usr/local/bin/cursor"
    elif [ -f "/Applications/Cursor.app/Contents/MacOS/Cursor" ]; then
        CURSOR_PATH="/Applications/Cursor.app/Contents/MacOS/Cursor"
    else
        echo "Error: Cursor is not installed or not in your PATH."
        echo "Please install Cursor from https://cursor.sh"
        exit 1
    fi
fi

# Execute the found Cursor command with all arguments
"$CURSOR_PATH" "$@"