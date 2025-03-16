#!/bin/bash

# MAI-Coder Unified Setup Script
# This script sets up all tooling configurations in one go and provides wrapper functions

# Get the absolute path of the repository and export it
export REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="${HOME}/.zshrc"

# Configuration variables - Edit these to match your installation paths
export CURSOR_PATH="/Applications/Cursor.app/Contents/MacOS/Cursor"
export VSCODE_PATH="code"  # Assuming 'code' is in PATH
export AIDER_PATH="aider"  # Assuming 'aider' is in PATH

# Verify the tool paths exist (for those that are files)
verify_tool_paths() {
  local errors=0
  
  if [[ "$CURSOR_PATH" == /* && ! -f "$CURSOR_PATH" ]]; then
    echo "⚠️  Warning: Cursor not found at $CURSOR_PATH"
    echo "Please edit the CURSOR_PATH variable in mai-setup.sh"
    errors=$((errors+1))
  fi
  
  # For commands in PATH, just check if they're available
  if ! command -v "$VSCODE_PATH" &> /dev/null; then
    echo "⚠️  Warning: VS Code command '$VSCODE_PATH' not found in PATH"
    echo "Please edit the VSCODE_PATH variable in mai-setup.sh"
    errors=$((errors+1))
  fi
  
  if ! command -v "$AIDER_PATH" &> /dev/null; then
    echo "⚠️  Warning: Aider command '$AIDER_PATH' not found in PATH"
    echo "Please edit the AIDER_PATH variable in mai-setup.sh"
    errors=$((errors+1))
  fi
  
  if [ $errors -gt 0 ]; then
    return 1
  fi
  return 0
}

# Clean up old mai-coder files from home directory
cleanup_old_files() {
  echo "🧹 Cleaning up old mai-coder files from home directory..."
  
  # Remove old setup scripts
  rm -f "${HOME}/setup.sh" "${HOME}/install.sh" "${HOME}/vscode-setup.sh" 2>/dev/null
  
  # Remove old configuration directories
  rm -rf "${HOME}/.mai-coder" "${HOME}/.mai-cursor" "${HOME}/.mai-aider" "${HOME}/.mai-copilot" 2>/dev/null
  
  # Remove old configuration files
  rm -f "${HOME}/.mai-config" "${HOME}/.mai-settings" 2>/dev/null
  
  echo "✅ Cleanup complete"
}

# Main deployment function
deploy_mai_configs() {
  local TARGET="$1"
  
  # Verify target is a directory
  if [ ! -d "$TARGET" ]; then
    echo "Error: $TARGET is not a directory"
    return 1
  fi
  
  echo "Deploying MAI configurations to $TARGET"
  
  # Create necessary directories
  mkdir -p "$TARGET/.cursor/rules" 2>/dev/null
  mkdir -p "$TARGET/.github" 2>/dev/null
  mkdir -p "$TARGET/.aider" 2>/dev/null
  
  # Deploy Cursor configurations
  if [ -f "$REPO_DIR/mai-cursor/.cursorignore" ]; then
    cp "$REPO_DIR/mai-cursor/.cursorignore" "$TARGET/" 2>/dev/null
    echo "✓ Deployed .cursorignore"
  fi
  
  if [ -f "$REPO_DIR/mai-cursor/.cursorindexingignore" ]; then
    cp "$REPO_DIR/mai-cursor/.cursorindexingignore" "$TARGET/" 2>/dev/null
    echo "✓ Deployed .cursorindexingignore"
  fi
  
  if [ -d "$REPO_DIR/mai-cursor/.cursorrules" ]; then
    cp -r "$REPO_DIR/mai-cursor/.cursorrules" "$TARGET/" 2>/dev/null
    echo "✓ Deployed .cursorrules/"
  fi
  
  if [ -f "$REPO_DIR/mai-cursor/my-license.mdc" ]; then
    cp "$REPO_DIR/mai-cursor/my-license.mdc" "$TARGET/.cursor/rules/license.mdc" 2>/dev/null
    echo "✓ Deployed .cursor/rules/license.mdc"
  fi
  
  # Deploy Copilot configurations
  if [ -f "$REPO_DIR/mai-copilot/.copilotignore" ]; then
    cp "$REPO_DIR/mai-copilot/.copilotignore" "$TARGET/" 2>/dev/null
    echo "✓ Deployed .copilotignore"
  fi
  
  if [ -f "$REPO_DIR/mai-copilot/.rooignore" ]; then
    cp "$REPO_DIR/mai-copilot/.rooignore" "$TARGET/" 2>/dev/null
    echo "✓ Deployed .rooignore"
  fi
  
  # Copy copilot-instructions.md to .github directory
  if [ -f "$REPO_DIR/mai-copilot/github/.github/copilot-instructions.md" ]; then
    cp "$REPO_DIR/mai-copilot/github/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null
    echo "✓ Deployed .github/copilot-instructions.md"
  elif [ -f "$REPO_DIR/mai-copilot/.github/copilot-instructions.md" ]; then
    cp "$REPO_DIR/mai-copilot/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null
    echo "✓ Deployed .github/copilot-instructions.md"
  else
    echo "⚠️ Warning: copilot-instructions.md not found"
  fi
  
  # Deploy Aider configurations
  if [ -f "$REPO_DIR/mai-aider/.aider-instructions.md" ]; then
    cp "$REPO_DIR/mai-aider/.aider-instructions.md" "$TARGET/" 2>/dev/null
    echo "✓ Deployed .aider-instructions.md"
  fi
  
  if [ -f "$REPO_DIR/mai-aider/.aider.conf.yml" ]; then
    cp "$REPO_DIR/mai-aider/.aider.conf.yml" "$TARGET/" 2>/dev/null
    echo "✓ Deployed .aider.conf.yml"
  fi
  
  if [ -f "$REPO_DIR/mai-aider/.aiderignore" ]; then
    cp "$REPO_DIR/mai-aider/.aiderignore" "$TARGET/" 2>/dev/null
    echo "✓ Deployed .aiderignore"
  fi
  
  if [ -f "$REPO_DIR/mai-aider/.env.example" ]; then
    cp "$REPO_DIR/mai-aider/.env.example" "$TARGET/" 2>/dev/null
    echo "✓ Deployed .env.example"
  fi
  
  # Update .gitignore
  update_gitignore "$TARGET"
  
  echo "✅ MAI configurations deployed to $TARGET"
}

# Function to update .gitignore
update_gitignore() {
  local TARGET="$1"
  local GITIGNORE="$TARGET/.gitignore"
  
  # Config entries to add to .gitignore
  local ENTRIES=(
    "# Cursor files"
    ".cursor/"
    ".cursorignore"
    ".cursorindexingignore"
    ".cursorrules"
    ""
    "# Aider files"
    ".aider/"
    ".aider-instructions.md"
    ".aider.conf.yml"
    ".aiderignore"
    ".env.example"
    ""
    "# Copilot files"
    ".copilot/"
    ".copilotignore"
    ".rooignore"
    ".github/copilot-instructions.md"
  )
  
  if [ -f "$GITIGNORE" ]; then
    # Check if entries already exist
    if ! grep -q ".cursorignore\|.copilotignore" "$GITIGNORE"; then
      echo "" >> "$GITIGNORE"
      for entry in "${ENTRIES[@]}"; do
        echo "$entry" >> "$GITIGNORE"
      done
      echo "Updated .gitignore with MAI config entries"
    else
      echo ".gitignore already contains MAI entries"
    fi
  else
    # Create new .gitignore
    for entry in "${ENTRIES[@]}"; do
      echo "$entry" >> "$GITIGNORE"
    done
    echo "Created .gitignore with MAI config entries"
  fi

  # Verify .gitignore was created/updated successfully
  if [ -f "$GITIGNORE" ]; then
    echo "✓ Verified .gitignore exists"
  else
    echo "⚠️ Warning: Failed to create .gitignore"
  fi
}

# Setup wrapper functions in .zshrc
setup_wrapper_functions() {
  if [ ! -f "$ZSHRC" ]; then
    echo "⚠️  Warning: ~/.zshrc not found. Please manually add the wrapper functions."
    return
  fi
  
  echo "🔧 Updating .zshrc with wrapper functions..."
  
  # Remove existing wrapper sections if they exist
  sed -i '' '/### MAI CODER WRAPPERS ###/,/### END MAI CODER WRAPPERS ###/d' "$ZSHRC" 2>/dev/null
  
  # First export the REPO_DIR
  cat >> "$ZSHRC" << EOF
### MAI CODER WRAPPERS ###
# Export MAI-Coder paths
export REPO_DIR="$REPO_DIR"
export CURSOR_PATH="$CURSOR_PATH"
export VSCODE_PATH="$VSCODE_PATH"
export AIDER_PATH="$AIDER_PATH"

EOF

  # Then add the functions
  cat >> "$ZSHRC" << 'EOF'
# MAI-Coder wrapper functions
function mai-coder {
  "$REPO_DIR/mai-setup.sh" deploy "$PWD"
  echo "✨ MAI-Coder configurations deployed to current directory"
}

function mai-cursor {
  "$REPO_DIR/mai-setup.sh" deploy "$PWD"
  if [[ "$1" == -* ]]; then
    "$CURSOR_PATH" "$@"
  else
    "$CURSOR_PATH" "$@"
  fi
}

function mai-aider {
  "$REPO_DIR/mai-setup.sh" deploy "$PWD"
  "$AIDER_PATH" "$@"
}

function mai-code {
  "$REPO_DIR/mai-setup.sh" deploy "$PWD"
  if [[ "$1" == -* ]]; then
    "$VSCODE_PATH" "$@"
  else
    "$VSCODE_PATH" "$@"
  fi
}
### END MAI CODER WRAPPERS ###
EOF

  echo "✅ Wrapper functions added to .zshrc"
}

# Main execution
main() {
  # Check for command argument
  if [ "$1" == "deploy" ]; then
    # Deploy configurations to the specified directory
    deploy_mai_configs "$2"
  else
    # Print header
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                MAI-Coder Unified Setup Script                   ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Regular setup
    echo "🔧 Setting up MAI-Coder tooling configurations..."
    echo ""
    
    # Clean up old files
    cleanup_old_files
    
    # Verify tool paths
    if ! verify_tool_paths; then
      echo "⚠️  Setup will continue but some tools may not work correctly."
      echo "Please edit the path variables in $REPO_DIR/mai-setup.sh to fix this."
      echo ""
    fi

    # Make script executable
    chmod +x "$REPO_DIR/mai-setup.sh"

    # Set up wrapper functions
    setup_wrapper_functions

    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                   MAI-Coder Setup Complete!                     ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "🔄 To activate all changes, run: source ~/.zshrc"
    echo ""
    echo "✨ You can now use any of these commands:"
    echo "   - mai-coder: Deploy all configurations to current directory"
    echo "   - mai-cursor: Launch Cursor with MAI configurations"
    echo "   - mai-aider: Launch Aider with MAI configurations"
    echo "   - mai-code: Launch VS Code with MAI configurations"
    echo ""
  fi
}

# Execute main function
main "$@" 