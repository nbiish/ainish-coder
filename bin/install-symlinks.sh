#!/bin/bash
# Script to install symbolic links for the mai-coder commands

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make the main script executable
chmod +x "$SCRIPT_DIR/mai-coder"

# Create symbolic links for individual tool commands
ln -sf "$SCRIPT_DIR/mai-coder" "$SCRIPT_DIR/mai-coder-aider"
ln -sf "$SCRIPT_DIR/mai-coder" "$SCRIPT_DIR/mai-coder-code"
ln -sf "$SCRIPT_DIR/mai-coder" "$SCRIPT_DIR/mai-coder-cursor"

# Create a symlink for the repo name (for backward compatibility)
ln -sf "$SCRIPT_DIR/mai-coder" "$SCRIPT_DIR/mai-coder-config"

echo "Symbolic links created successfully."
echo "You can now use the following commands:"
echo "  mai-coder                # Configure all tools"
echo "  mai-coder aider          # Configure only Aider"
echo "  mai-coder code           # Configure only GitHub Copilot"
echo "  mai-coder cursor         # Configure only Cursor"
echo "  mai-coder-aider          # Configure only Aider (alternative)"
echo "  mai-coder-code           # Configure only GitHub Copilot (alternative)"
echo "  mai-coder-cursor         # Configure only Cursor (alternative)"
echo "  mai-coder-config         # Alias for mai-coder (backward compatibility)" 