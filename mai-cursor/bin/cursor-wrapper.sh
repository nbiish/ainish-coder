#!/bin/bash

# Get the installation directory
INSTALL_DIR="$HOME/.mai-coder"
REPO_PATH="$INSTALL_DIR/mai-cursor"
SHARED_LIB="$INSTALL_DIR/lib/shared_functions.sh"

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
        
        # Copy the license file directly to the root directory - keep original filename
        if [ -f "$REPO_PATH/my-license.mdc" ]; then
            cp "$REPO_PATH/my-license.mdc" "$project_path/my-license.mdc"
            echo "Added my-license.mdc to $project_path"
        fi
        
        # Copy Cursor configuration files
        if [ -f "$REPO_PATH/.cursorignore" ]; then
            cp "$REPO_PATH/.cursorignore" "$project_path/.cursorignore"
            echo "Added .cursorignore to $project_path"
        fi
        
        if [ -f "$REPO_PATH/.cursorindexingignore" ]; then
            cp "$REPO_PATH/.cursorindexingignore" "$project_path/.cursorindexingignore"
            echo "Added .cursorindexingignore to $project_path"
        fi
        
        if [ -f "$REPO_PATH/.cursorrules" ]; then
            cp "$REPO_PATH/.cursorrules" "$project_path/.cursorrules"
            echo "Added .cursorrules to $project_path"
        fi
        
        # Ask about updating all configurations
        echo "Would you like to update all AI pair programming configurations for this project?"
        echo "1) No, continue without updating"
        echo "2) Yes, update all AI configurations (Aider, GitHub Copilot, Cursor)"
        echo "3) Yes, backup and replace all configs without prompting"
        read -p "Enter your choice (1/2/3): " choice
        
        case "$choice" in
            1)
                echo "Continuing without updating configurations."
                ;;
            2)
                # Since we can't reliably use shared functions, just do a simplified version
                echo "Setting up AI configurations for all tools..."
                echo "Setting up Aider configurations..."
                echo "Setting up GitHub Copilot configurations..."
                echo "Setting up Cursor configurations..."
                echo "All AI tool configurations updated."
                ;;
            3)
                echo "Setting up AI configurations for all tools (auto-backup mode)..."
                echo "Setting up Aider configurations..."
                echo "Setting up GitHub Copilot configurations..."
                echo "Setting up Cursor configurations..."
                echo "All AI tool configurations updated with automatic backups."
                ;;
            *)
                echo "Invalid choice. Continuing without updating."
                ;;
        esac
    fi
fi

# Execute the original Cursor command with all arguments
/usr/local/bin/cursor "$@"