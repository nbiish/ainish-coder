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

# ANSI color codes for cyberpunk theme
CYAN='\033[0;36m'
BRIGHT_CYAN='\033[1;36m'
MAGENTA='\033[0;35m'
BRIGHT_MAGENTA='\033[1;35m'
BLUE='\033[0;34m'
BRIGHT_BLUE='\033[1;34m'
GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
YELLOW='\033[0;33m'
BRIGHT_YELLOW='\033[1;33m'
RED='\033[0;31m'
BRIGHT_RED='\033[1;31m'
RESET='\033[0m'

# Verify the tool paths exist (for those that are files)
verify_tool_paths() {
  local errors=0
  
  if [[ "$CURSOR_PATH" == /* && ! -f "$CURSOR_PATH" ]]; then
    echo -e "${BRIGHT_YELLOW}⚠️  Warning: Cursor not found at $CURSOR_PATH${RESET}"
    echo -e "${YELLOW}Please edit the CURSOR_PATH variable in mai-setup.sh${RESET}"
    errors=$((errors+1))
  fi
  
  # For commands in PATH, just check if they're available
  if ! command -v "$VSCODE_PATH" &> /dev/null; then
    echo -e "${BRIGHT_YELLOW}⚠️  Warning: VS Code command '$VSCODE_PATH' not found in PATH${RESET}"
    echo -e "${YELLOW}Please edit the VSCODE_PATH variable in mai-setup.sh${RESET}"
    errors=$((errors+1))
  fi
  
  if ! command -v "$AIDER_PATH" &> /dev/null; then
    echo -e "${BRIGHT_YELLOW}⚠️  Warning: Aider command '$AIDER_PATH' not found in PATH${RESET}"
    echo -e "${YELLOW}Please edit the AIDER_PATH variable in mai-setup.sh${RESET}"
    errors=$((errors+1))
  fi
  
  if [ $errors -gt 0 ]; then
    return 1
  fi
  return 0
}

# Clean up old mai-coder files from home directory
cleanup_old_files() {
  echo -e "${BRIGHT_CYAN}🧹 Cleaning up old mai-coder files from home directory...${RESET}"
  
  # Remove old setup scripts
  rm -f "${HOME}/setup.sh" "${HOME}/install.sh" "${HOME}/vscode-setup.sh" 2>/dev/null
  
  # Remove old configuration directories
  rm -rf "${HOME}/.mai-coder" "${HOME}/.mai-cursor" "${HOME}/.mai-aider" "${HOME}/.mai-copilot" 2>/dev/null
  
  # Remove old configuration files
  rm -f "${HOME}/.mai-config" "${HOME}/.mai-settings" 2>/dev/null
  
  echo -e "${BRIGHT_GREEN}✅ Cleanup complete${RESET}"
}

# Main deployment function
deploy_mai_configs() {
  local TARGET="$1"
  
  # Verify target is a directory
  if [ ! -d "$TARGET" ]; then
    echo -e "${BRIGHT_RED}Error: $TARGET is not a directory${RESET}"
    return 1
  fi
  
  echo -e "${BRIGHT_BLUE}Deploying MAI configurations to $TARGET${RESET}"
  
  # Create necessary directories
  mkdir -p "$TARGET/.cursor/rules" 2>/dev/null
  mkdir -p "$TARGET/.github" 2>/dev/null
  mkdir -p "$TARGET/.aider" 2>/dev/null
  
  # Deploy Cursor configurations
  if [ -f "$REPO_DIR/mai-cursor/.cursorignore" ]; then
    cp "$REPO_DIR/mai-cursor/.cursorignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .cursorignore${RESET}"
  fi
  
  if [ -f "$REPO_DIR/mai-cursor/.cursorindexingignore" ]; then
    cp "$REPO_DIR/mai-cursor/.cursorindexingignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .cursorindexingignore${RESET}"
  fi
  
  if [ -d "$REPO_DIR/mai-cursor/.cursorrules" ]; then
    cp -r "$REPO_DIR/mai-cursor/.cursorrules" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .cursorrules/${RESET}"
  fi
  
  if [ -f "$REPO_DIR/mai-cursor/my-license.mdc" ]; then
    cp "$REPO_DIR/mai-cursor/my-license.mdc" "$TARGET/.cursor/rules/license.mdc" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .cursor/rules/license.mdc${RESET}"
  fi
  
  # Deploy Copilot configurations
  if [ -f "$REPO_DIR/mai-copilot/.copilotignore" ]; then
    cp "$REPO_DIR/mai-copilot/.copilotignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .copilotignore${RESET}"
  fi
  
  if [ -f "$REPO_DIR/mai-copilot/.rooignore" ]; then
    cp "$REPO_DIR/mai-copilot/.rooignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .rooignore${RESET}"
  fi
  
  # Copy copilot-instructions.md to .github directory
  if [ -f "$REPO_DIR/mai-copilot/github/.github/copilot-instructions.md" ]; then
    cp "$REPO_DIR/mai-copilot/github/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .github/copilot-instructions.md${RESET}"
  elif [ -f "$REPO_DIR/mai-copilot/.github/copilot-instructions.md" ]; then
    cp "$REPO_DIR/mai-copilot/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .github/copilot-instructions.md${RESET}"
  else
    echo -e "${YELLOW}⚠️ Warning: copilot-instructions.md not found${RESET}"
  fi
  
  # Deploy Aider configurations
  if [ -f "$REPO_DIR/mai-aider/.aider-instructions.md" ]; then
    cp "$REPO_DIR/mai-aider/.aider-instructions.md" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .aider-instructions.md${RESET}"
  fi
  
  if [ -f "$REPO_DIR/mai-aider/.aider.conf.yml" ]; then
    cp "$REPO_DIR/mai-aider/.aider.conf.yml" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .aider.conf.yml${RESET}"
  fi
  
  if [ -f "$REPO_DIR/mai-aider/.aiderignore" ]; then
    cp "$REPO_DIR/mai-aider/.aiderignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .aiderignore${RESET}"
  fi
  
  if [ -f "$REPO_DIR/mai-aider/.env.example" ]; then
    cp "$REPO_DIR/mai-aider/.env.example" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .env.example${RESET}"
  fi
  
  # Update .gitignore
  update_gitignore "$TARGET"
  
  echo -e "${BRIGHT_GREEN}✅ MAI configurations deployed to $TARGET${RESET}"
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
      echo -e "${BLUE}Updated .gitignore with MAI config entries${RESET}"
    else
      echo -e "${BLUE}.gitignore already contains MAI entries${RESET}"
    fi
  else
    # Create new .gitignore
    for entry in "${ENTRIES[@]}"; do
      echo "$entry" >> "$GITIGNORE"
    done
    echo -e "${BLUE}Created .gitignore with MAI config entries${RESET}"
  fi

  # Verify .gitignore was created/updated successfully
  if [ -f "$GITIGNORE" ]; then
    echo -e "${GREEN}✓ Verified .gitignore exists${RESET}"
  else
    echo -e "${YELLOW}⚠️ Warning: Failed to create .gitignore${RESET}"
  fi
}

# Setup wrapper functions in .zshrc
setup_wrapper_functions() {
  if [ ! -f "$ZSHRC" ]; then
    echo -e "${YELLOW}⚠️  Warning: ~/.zshrc not found. Please manually add the wrapper functions.${RESET}"
    return
  fi
  
  echo -e "${BRIGHT_BLUE}🔧 Updating .zshrc with wrapper functions...${RESET}"
  
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

  echo -e "${BRIGHT_GREEN}✅ Wrapper functions added to .zshrc${RESET}"
}

# Main execution
main() {
  # Check for command argument
  if [ "$1" == "deploy" ]; then
    # Deploy configurations to the specified directory
    deploy_mai_configs "$2"
  else
    # Print cyberpunk-style header
    echo -e "${BRIGHT_MAGENTA}╔══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BRIGHT_MAGENTA}║${RESET}               ${BRIGHT_CYAN}M A I - C O D E R${RESET}                ${BRIGHT_MAGENTA}║${RESET}"
    echo -e "${BRIGHT_MAGENTA}╚══════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    
    # Regular setup
    echo -e "${BRIGHT_CYAN}🔧 [INIT] Setting up MAI-Coder tooling configurations...${RESET}"
    echo ""
    
    # Clean up old files
    cleanup_old_files
    
    # Verify tool paths
    if ! verify_tool_paths; then
      echo -e "${BRIGHT_YELLOW}⚠️  [WARN] Setup will continue but some tools may not work correctly.${RESET}"
      echo -e "${YELLOW}Please edit the path variables in $REPO_DIR/mai-setup.sh to fix this.${RESET}"
      echo ""
    fi

    # Make script executable
    chmod +x "$REPO_DIR/mai-setup.sh"

    # Set up wrapper functions
    setup_wrapper_functions

    echo -e "${BRIGHT_MAGENTA}╔══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BRIGHT_MAGENTA}║${RESET}               ${BRIGHT_GREEN}M A I - C O D E R${RESET}            ${BRIGHT_MAGENTA}║${RESET}"
    echo -e "${BRIGHT_MAGENTA}╚══════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${BRIGHT_CYAN}🔄 To activate all changes, run: ${BRIGHT_BLUE}source ~/.zshrc${RESET}"
    echo ""
    echo -e "${BRIGHT_MAGENTA}✨ AVAILABLE COMMANDS:${RESET}"
    echo -e "${BRIGHT_BLUE}   ▶ mai-coder${RESET}: ${CYAN}Install all configurations to current directory${RESET}"
    echo -e "${BRIGHT_BLUE}   ▶ mai-cursor${RESET}: ${CYAN}Install Cursor configurations to current directory${RESET}"
    echo -e "${BRIGHT_BLUE}   ▶ mai-aider${RESET}: ${CYAN}Install Aider configurations to current directory${RESET}"
    echo -e "${BRIGHT_BLUE}   ▶ mai-code${RESET}: ${CYAN}Install VS Code configurations to current directory${RESET}"
    echo ""
  fi
}

# Execute main function
main "$@" 