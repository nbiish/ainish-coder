#!/bin/bash

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_CONFIG_DIR="$HOME/.mai-coder"

# Create home config directory if it doesn't exist
mkdir -p "$HOME_CONFIG_DIR"

# Copy all configuration files and directories
echo "Setting up configuration files in $HOME_CONFIG_DIR..."

# Copy mai-copilot files
mkdir -p "$HOME_CONFIG_DIR/mai-copilot"
cp -r "$SCRIPT_DIR/mai-copilot/.github" "$HOME_CONFIG_DIR/mai-copilot/" 2>/dev/null
cp "$SCRIPT_DIR/mai-copilot/.copilotignore" "$HOME_CONFIG_DIR/mai-copilot/" 2>/dev/null
cp "$SCRIPT_DIR/mai-copilot/copilot-instructions.md" "$HOME_CONFIG_DIR/mai-copilot/" 2>/dev/null

# Copy mai-cursor files
mkdir -p "$HOME_CONFIG_DIR/mai-cursor"
cp "$SCRIPT_DIR/mai-cursor/.cursorignore" "$HOME_CONFIG_DIR/mai-cursor/" 2>/dev/null
cp "$SCRIPT_DIR/mai-cursor/.cursorindexingignore" "$HOME_CONFIG_DIR/mai-cursor/" 2>/dev/null
cp "$SCRIPT_DIR/mai-cursor/.cursorrules" "$HOME_CONFIG_DIR/mai-cursor/" 2>/dev/null

# Copy mai-aider files
mkdir -p "$HOME_CONFIG_DIR/mai-aider"
cp "$SCRIPT_DIR/mai-aider/.aider.conf.yml" "$HOME_CONFIG_DIR/mai-aider/" 2>/dev/null
cp "$SCRIPT_DIR/mai-aider/.aider-instructions.md" "$HOME_CONFIG_DIR/mai-aider/" 2>/dev/null

# Copy root .gitignore
cp "$SCRIPT_DIR/.gitignore" "$HOME_CONFIG_DIR/" 2>/dev/null

# Create bin directory in home folder
mkdir -p "$HOME/.mai-coder/bin"

# Create common helper function file for all wrappers
mkdir -p "$HOME/.mai-coder/lib"
cat > "$HOME/.mai-coder/lib/helper.sh" << 'EOF'
#!/bin/bash

# Helper function to prompt for file installation
install_config_files() {
    local source_dir="$1"
    local target_dir="$2"
    local file_list=("${@:3}")
    
    mkdir -p "$target_dir"
    
    for file in "${file_list[@]}"; do
        source_file="$source_dir/$file"
        target_file="$target_dir/$file"
        
        if [ -f "$source_file" ]; then
            if [ -f "$target_file" ]; then
                # Check if files are identical before prompting
                if cmp -s "$source_file" "$target_file"; then
                    # Files are identical, no action needed
                    continue
                fi
                
                read -p "File $target_file exists and is different. Overwrite? (y/n): " choice
                if [[ $choice =~ ^[Yy]$ ]]; then
                    cp "$source_file" "$target_file"
                    echo "Updated: $target_file"
                else
                    echo "Kept existing: $target_file"
                fi
            else
                cp "$source_file" "$target_file"
                echo "Installed: $target_file"
            fi
        fi
    done
}
EOF
chmod +x "$HOME/.mai-coder/lib/helper.sh"

# Copy wrapper scripts with enhanced functionality
cat > "$HOME/.mai-coder/bin/code" << 'EOF'
#!/bin/bash
CONFIG_DIR="$HOME/.mai-coder"
source "$CONFIG_DIR/lib/helper.sh"

# Install/update configuration files
install_config_files "$CONFIG_DIR/mai-copilot" "$HOME/.vscode" \
  ".copilotignore" "copilot-instructions.md"

# Run the original VSCode command
code "$@"
EOF

cat > "$HOME/.mai-coder/bin/cursor" << 'EOF'
#!/bin/bash
CONFIG_DIR="$HOME/.mai-coder"
source "$CONFIG_DIR/lib/helper.sh"

# Install/update configuration files
install_config_files "$CONFIG_DIR/mai-cursor" "$HOME" \
  ".cursorignore" ".cursorindexingignore" ".cursorrules"

# Run the original Cursor command
cursor "$@"
EOF

cat > "$HOME/.mai-coder/bin/aider" << 'EOF'
#!/bin/bash
CONFIG_DIR="$HOME/.mai-coder"
source "$CONFIG_DIR/lib/helper.sh"

# Install/update configuration files
install_config_files "$CONFIG_DIR/mai-aider" "$HOME" \
  ".aider.conf.yml" ".aider-instructions.md"

# Run the original Aider command
aider "$@"
EOF

# Make wrapper scripts executable
chmod +x "$HOME/.mai-coder/bin/code" 2>/dev/null
chmod +x "$HOME/.mai-coder/bin/cursor" 2>/dev/null
chmod +x "$HOME/.mai-coder/bin/aider" 2>/dev/null

# Add bin directory to PATH if not already present
SHELL_CONFIG_FILE=""
if [ -n "$ZSH_VERSION" ]; then
    SHELL_CONFIG_FILE="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_CONFIG_FILE="$HOME/.bashrc"
fi

if [ -n "$SHELL_CONFIG_FILE" ]; then
    if ! grep -q "export PATH=\"\$HOME/.mai-coder/bin:\$PATH\"" "$SHELL_CONFIG_FILE"; then
        echo '' >> "$SHELL_CONFIG_FILE"
        echo '# Add mai-coder bin directory to PATH' >> "$SHELL_CONFIG_FILE"
        echo 'export PATH="$HOME/.mai-coder/bin:$PATH"' >> "$SHELL_CONFIG_FILE"
        echo "Added mai-coder bin directory to PATH in $SHELL_CONFIG_FILE"
        echo "Please restart your terminal or run: source $SHELL_CONFIG_FILE"
    fi
fi

echo "Setup complete! The wrapper scripts are now installed in $HOME/.mai-coder/bin"
echo "Configuration files are installed in $HOME/.mai-coder"