#!/bin/bash
# Script to add the mai-coder scripts to the user's PATH

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== MAI-CODER PATH SETUP ===${NC}"

# Get the installation directory
INSTALL_DIR="${HOME}/.mai-coder"
BIN_DIR="$INSTALL_DIR/bin"

# Check if the bin directory exists
if [ ! -d "$BIN_DIR" ]; then
    echo -e "${YELLOW}Error: Installation directory not found at $BIN_DIR${NC}"
    echo "Please run the installation script first."
    exit 1
fi

# Function to add the bin directory to the specified shell configuration file
add_to_shell_config() {
    local config_file="$1"
    local path_line="export PATH=\"\$PATH:$BIN_DIR\""
    
    # Check if the config file exists
    if [ -f "$config_file" ]; then
        # Check if the PATH entry already exists
        if grep -q "$BIN_DIR" "$config_file"; then
            echo -e "${YELLOW}PATH entry already exists in $config_file${NC}"
        else
            # Add the PATH entry to the config file
            echo "" >> "$config_file"
            echo "# Add mai-coder scripts to PATH" >> "$config_file"
            echo "$path_line" >> "$config_file"
            echo -e "${GREEN}Added PATH entry to $config_file${NC}"
        fi
    fi
}

# Detect the user's shell
USER_SHELL=$(basename "$SHELL")

echo "Detected shell: $USER_SHELL"
echo "Adding mai-coder scripts to your PATH..."

# Add to the appropriate shell configuration files
case "$USER_SHELL" in
    bash)
        add_to_shell_config "$HOME/.bashrc"
        add_to_shell_config "$HOME/.bash_profile"
        ;;
    zsh)
        add_to_shell_config "$HOME/.zshrc"
        ;;
    fish)
        # For fish shell, we need a different approach
        FISH_CONFIG_DIR="$HOME/.config/fish"
        FISH_CONFIG_FILE="$FISH_CONFIG_DIR/config.fish"
        
        if [ -d "$FISH_CONFIG_DIR" ]; then
            if [ -f "$FISH_CONFIG_FILE" ]; then
                if grep -q "$BIN_DIR" "$FISH_CONFIG_FILE"; then
                    echo -e "${YELLOW}PATH entry already exists in $FISH_CONFIG_FILE${NC}"
                else
                    echo "" >> "$FISH_CONFIG_FILE"
                    echo "# Add mai-coder scripts to PATH" >> "$FISH_CONFIG_FILE"
                    echo "set -gx PATH \$PATH $BIN_DIR" >> "$FISH_CONFIG_FILE"
                    echo -e "${GREEN}Added PATH entry to $FISH_CONFIG_FILE${NC}"
                fi
            else
                mkdir -p "$FISH_CONFIG_DIR"
                echo "# Add mai-coder scripts to PATH" > "$FISH_CONFIG_FILE"
                echo "set -gx PATH \$PATH $BIN_DIR" >> "$FISH_CONFIG_FILE"
                echo -e "${GREEN}Created and added PATH entry to $FISH_CONFIG_FILE${NC}"
            fi
        fi
        ;;
    *)
        echo -e "${YELLOW}Unsupported shell: $USER_SHELL${NC}"
        echo "Please manually add the following line to your shell configuration file:"
        echo "$path_line"
        ;;
esac

echo -e "${GREEN}Setup completed.${NC}"
echo "You may need to restart your terminal or run 'source ~/.bashrc' (or equivalent) for the changes to take effect."
echo ""
echo "You can now use the following commands from anywhere:"
echo "  mai-coder                # Configure all tools"
echo "  mai-coder aider          # Configure only Aider"
echo "  mai-coder code           # Configure only GitHub Copilot"
echo "  mai-coder cursor         # Configure only Cursor"
echo "  mai-coder-aider          # Configure only Aider (alternative)"
echo "  mai-coder-code           # Configure only GitHub Copilot (alternative)"
echo "  mai-coder-cursor         # Configure only Cursor (alternative)"
echo "  mai-coder-config         # Alias for mai-coder (backward compatibility)" 