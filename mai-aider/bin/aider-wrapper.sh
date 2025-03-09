#!/bin/bash

# Define source paths
REPO_PATH="/Volumes/1tb-sandisk/code/mai-coder"
HOME_CONFIG_PATH="$HOME/.mai-coder"

# Function to copy configuration files
copy_config_files() {
    local target_path="$1"
    
    # Copy .aider-instructions.md if it exists in source
    if [ -f "$HOME_CONFIG_PATH/mai-aider/.aider-instructions.md" ]; then
        source_file="$HOME_CONFIG_PATH/mai-aider/.aider-instructions.md"
        target_file="$target_path/.aider-instructions.md"
        
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
    
    # Copy .aider.conf.yml if it exists in source
    if [ -f "$HOME_CONFIG_PATH/mai-aider/.aider.conf.yml" ]; then
        source_file="$HOME_CONFIG_PATH/mai-aider/.aider.conf.yml"
        target_file="$target_path/.aider.conf.yml"
        
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

# Find the actual aider executable
AIDER_PATH=$(which -a aider 2>/dev/null | grep -v "$HOME/.mai-coder/bin/aider" | head -1)
if [ -z "$AIDER_PATH" ]; then
    # Fixed path fallback
    if [ -f "/usr/local/bin/aider" ]; then
        AIDER_PATH="/usr/local/bin/aider"
    elif [ -f "$HOME/.local/bin/aider" ]; then
        AIDER_PATH="$HOME/.local/bin/aider"
    else
        echo "Error: Aider is not installed or not in your PATH."
        echo "Please install Aider using: pip install aider-chat"
        exit 1
    fi
fi

# Execute the found Aider command with all arguments
"$AIDER_PATH" "$@"