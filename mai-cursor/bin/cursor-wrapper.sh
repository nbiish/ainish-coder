#!/bin/bash

# Define configuration paths
HOME_CONFIG_PATH="$HOME/.mai-coder"
CURSOR_CONFIG_PATH="$HOME_CONFIG_PATH/mai-cursor"

# Function to handle config updates
handle_configs() {
    local target_dir="$1"
    local force_update="$2"
    
    # Check if configs exist
    if [ -f "$target_dir/.cursorrules" ] || [ -f "$target_dir/.cursorindexingignore" ] || [ -f "$target_dir/.cursorignore" ]; then
        if [ -z "$force_update" ]; then
            echo "Config files already exist. Choose an option:"
            echo "1) Update all configs"
            echo "2) Update aider configs"
            echo "3) Update code configs"
            echo "4) Update cursor configs"
            echo "5) Skip updates"
            read -p "Enter choice (1-5): " choice
            
            case $choice in
                1) force_update="all";;
                2) force_update="aider";;
                3) force_update="code";;
                4) force_update="cursor";;
                5) return;;
                *) echo "Invalid choice. Skipping updates."; return;;
            esac
        fi
    fi
    
    # Update cursor configs if requested
    if [ "$force_update" = "all" ] || [ "$force_update" = "cursor" ] || [ ! -f "$target_dir/.cursorrules" ]; then
        if [ -f "$CURSOR_CONFIG_PATH/.cursorrules" ]; then
            cp "$CURSOR_CONFIG_PATH/.cursorrules" "$target_dir/.cursorrules"
        fi
        
        if [ -f "$CURSOR_CONFIG_PATH/.cursorindexingignore" ]; then
            cp "$CURSOR_CONFIG_PATH/.cursorindexingignore" "$target_dir/.cursorindexingignore"
        fi
        
        if [ -f "$CURSOR_CONFIG_PATH/.cursorignore" ]; then
            cp "$CURSOR_CONFIG_PATH/.cursorignore" "$target_dir/.cursorignore"
        fi
        
        # Copy license file if it exists
        if [ -f "$CURSOR_CONFIG_PATH/my-license.mdc" ]; then
            # Create .mdc directory if it doesn't exist
            mkdir -p "$target_dir/.mdc"
            cp "$CURSOR_CONFIG_PATH/my-license.mdc" "$target_dir/.mdc/license.mdc"
            echo "Added license template to $target_dir/.mdc/license.mdc"
        fi
    fi
    
    # Update common gitignore if requested
    if [ "$force_update" = "all" ] || [ ! -f "$target_dir/.gitignore" ]; then
        if [ -f "$HOME_CONFIG_PATH/.gitignore" ]; then
            cp "$HOME_CONFIG_PATH/.gitignore" "$target_dir/.gitignore"
        fi
    fi
}

# Process arguments to look for directories
DIR_ARG=""
for arg in "$@"; do
    if [ -d "$arg" ]; then
        DIR_ARG="$arg"
        break
    elif [ -d "$(pwd)/$arg" ] && [[ ! "$arg" == -* ]]; then
        DIR_ARG="$(pwd)/$arg"
        break
    fi
done

# Handle configs if directory was provided
if [ -n "$DIR_ARG" ]; then
    handle_configs "$DIR_ARG"
fi

# Get real cursor path
REAL_CURSOR="/usr/local/bin/cursor"
if [ ! -f "$REAL_CURSOR" ]; then
    # Try other common locations
    if [ -f "/Applications/Cursor.app/Contents/MacOS/Cursor" ]; then
        REAL_CURSOR="/Applications/Cursor.app/Contents/MacOS/Cursor"
    else
        # Last resort, use whatever is in PATH except our wrapper
        REAL_CURSOR=$(which -a cursor 2>/dev/null | grep -v "$HOME/.mai-coder/bin/cursor" | head -1)
    fi
fi

# Execute cursor directly
exec $REAL_CURSOR "$@"