#!/bin/bash

# Define configuration paths
HOME_CONFIG_PATH="$HOME/.mai-coder"

# Function to handle config updates
handle_configs() {
    local target_dir="$1"
    local force_update="$2"
    
    # Check if configs exist
    if [ -f "$target_dir/.aider-instructions.md" ] || [ -f "$target_dir/.aider.conf.yml" ]; then
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
    
    # Update aider configs if requested
    if [ "$force_update" = "all" ] || [ "$force_update" = "aider" ] || [ ! -f "$target_dir/.aider-instructions.md" ]; then
        if [ -f "$HOME_CONFIG_PATH/mai-aider/.aider-instructions.md" ]; then
            cp "$HOME_CONFIG_PATH/mai-aider/.aider-instructions.md" "$target_dir/.aider-instructions.md"
        fi
        
        if [ -f "$HOME_CONFIG_PATH/mai-aider/.aider.conf.yml" ]; then
            cp "$HOME_CONFIG_PATH/mai-aider/.aider.conf.yml" "$target_dir/.aider.conf.yml"
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

# Find the real aider command
REAL_AIDER=$(which -a aider 2>/dev/null | grep -v "$HOME/.mai-coder/bin/aider" | head -1)
if [ -z "$REAL_AIDER" ]; then
    for path in "/usr/local/bin/aider" "$HOME/.local/bin/aider" "/opt/homebrew/bin/aider"; do
        if [ -x "$path" ]; then
            REAL_AIDER="$path"
            break
        fi
    done
    
    if [ -z "$REAL_AIDER" ]; then
        echo "Error: Could not find aider. Please install it with: pip install aider-chat"
        exit 1
    fi
fi

# Parse the command to determine which configuration to use
CMD_ARGS=()
MODE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        smart|r1|v3|pro)
            MODE="$1"
            shift
            ;;
        *)
            CMD_ARGS+=("$1")
            shift
            ;;
    esac
done

# Apply the appropriate configuration based on mode
case "$MODE" in
    smart)
        exec "$REAL_AIDER" --architect --model r1 --editor-model openrouter/anthropic/claude-3.5-sonnet "${CMD_ARGS[@]}"
        ;;
    r1)
        exec "$REAL_AIDER" --model r1 --edit-format diff "${CMD_ARGS[@]}"
        ;;
    v3)
        exec "$REAL_AIDER" --model deepseek/deepseek-chat --edit-format diff "${CMD_ARGS[@]}"
        ;;
    pro)
        exec "$REAL_AIDER" --model gemini/gemini-2.0-pro-exp-02-05 --edit-format whole "${CMD_ARGS[@]}"
        ;;
    *)
        exec "$REAL_AIDER" "${CMD_ARGS[@]}"
        ;;
esac