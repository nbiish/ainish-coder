#!/bin/bash

# AINISH-Coder Unified Setup Script
# This script sets up all tooling configurations in one go and provides wrapper functions

#########################################################################
# FUNCTION REFERENCE
#########################################################################
# Main Functions:
# - setup_ainish_coder_dir(): Creates ~/.ainish-coder and sets up symlinks to repository
# - verify_tool_paths(): Checks if configured tool paths exist
# - cleanup_old_files(): Removes old configuration files from previous versions
# - deploy_ainish_configs(): Deploys all AINISH configurations to a target directory
# - update_gitignore(): Updates .gitignore with AINISH-related entries
# - setup_wrapper_functions(): Adds wrapper functions to .zshrc
# - deploy_vscode_configs(): Deploys only VS Code/Copilot specific configurations
# - deploy_cursor_configs(): Deploys only Cursor specific configurations
# - deploy_aider_configs(): Deploys only Aider specific configurations
# - update_critical_mdc(): Updates critical.mdc in all ainish-* directories
# - update_memory_bank_mdc(): Updates @MEMORY-BANK.mdc in all ainish-* directories
# - update_prompt_md(): Updates prompt.md in all ainish-* directories
# - prepend_non_cursor_content(): Prepends header content from non-cursor-prepend.md to prompt.md files (except for ainish-cursor)
# - main(): Main execution function that processes command arguments
#
# Usage Examples:
# ./ainish-setup.sh                     # Run full setup
# ./ainish-setup.sh deploy /path/dir    # Deploy all configs to specified directory
# ./ainish-setup.sh deploy_cursor_configs /path/dir  # Deploy only Cursor configs
# ./ainish-setup.sh deploy_vscode_configs /path/dir  # Deploy only VS Code configs
# ./ainish-setup.sh deploy_aider_configs /path/dir   # Deploy only Aider configs
# ./ainish-setup.sh update_critical_mdc  # Update critical.mdc in all ainish-* dirs
#########################################################################

# Get the absolute path of the repository and export it
export REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="${HOME}/.zshrc"
AINISH_CODER_DIR="${HOME}/.ainish-coder"

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

# Function to create and populate ~/.ainish-coder directory
setup_ainish_coder_dir() {
  echo -e "${BRIGHT_CYAN}🔧 Setting up ~/.ainish-coder directory...${RESET}"
  
  # Create the main directory
  mkdir -p "${AINISH_CODER_DIR}" 2>/dev/null
  
  # Remove existing directories if they exist
  rm -rf "${AINISH_CODER_DIR}/cursor" 2>/dev/null
  rm -rf "${AINISH_CODER_DIR}/vscode" 2>/dev/null
  rm -rf "${AINISH_CODER_DIR}/aider" 2>/dev/null
  
  # Create symlinks to original repo directories instead of copying
  ln -sf "${REPO_DIR}/ainish-cursor" "${AINISH_CODER_DIR}/cursor" 2>/dev/null
  ln -sf "${REPO_DIR}/ainish-copilot" "${AINISH_CODER_DIR}/vscode" 2>/dev/null
  ln -sf "${REPO_DIR}/ainish-aider" "${AINISH_CODER_DIR}/aider" 2>/dev/null
  
  # Symlink .cursorrules to ~/.ainish-coder/cursor/.cursorrules if it exists
  if [ -f "${REPO_DIR}/.cursorrules" ]; then
    ln -sf "${REPO_DIR}/.cursorrules" "${AINISH_CODER_DIR}/cursor/.cursorrules" 2>/dev/null
    echo -e "${GREEN}✓ Symlinked .cursorrules to ~/.ainish-coder/cursor/.cursorrules${RESET}"
  fi
  
  # Create symlink for critical.mdc
  ln -sf "${REPO_DIR}/critical.mdc" "${AINISH_CODER_DIR}/critical.mdc" 2>/dev/null

  # Create symlink for anishinaabe-cyberpunk-style.mdc
  ln -sf "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" 2>/dev/null

  # Create symlink for MEMORY-BANK.mdc (Corrected filename)
  ln -sf "${REPO_DIR}/MEMORY-BANK.mdc" "${AINISH_CODER_DIR}/MEMORY-BANK.mdc" 2>/dev/null

  # Create symlink for docs-use.mdc
  ln -sf "${REPO_DIR}/docs-use.mdc" "${AINISH_CODER_DIR}/docs-use.mdc" 2>/dev/null

  # Create symlink for prompt.md
  ln -sf "${REPO_DIR}/prompt.md" "${AINISH_CODER_DIR}/prompt.md" 2>/dev/null
  
  # Create symlink for non-cursor-prepend.md
  ln -sf "${REPO_DIR}/non-cursor-prepend.md" "${AINISH_CODER_DIR}/non-cursor-prepend.md" 2>/dev/null
  
  # Copy the setup script itself (this should be a copy, not a symlink)
  cp "${REPO_DIR}/ainish-setup.sh" "${AINISH_CODER_DIR}/ainish-setup.sh" 2>/dev/null
  chmod +x "${AINISH_CODER_DIR}/ainish-setup.sh" 2>/dev/null
  
  # Create a config file with the repository path
  echo "REPO_DIR=\"${REPO_DIR}\"" > "${AINISH_CODER_DIR}/config.sh"
  echo "# This file was automatically generated by ainish-setup.sh" >> "${AINISH_CODER_DIR}/config.sh"
  echo "# It contains paths to the original repository and is used by the ainish-update function" >> "${AINISH_CODER_DIR}/config.sh"
  chmod +x "${AINISH_CODER_DIR}/config.sh" 2>/dev/null
  
  echo -e "${BRIGHT_GREEN}✅ ~/.ainish-coder directory setup complete with symlinks to repo${RESET}"
  echo -e "${GREEN}✓ Changes to repo files will be immediately available to tools${RESET}"
}

# Verify the tool paths exist (for those that are files)
verify_tool_paths() {
  local errors=0
  
  if [[ "$CURSOR_PATH" == /* && ! -f "$CURSOR_PATH" ]]; then
    echo -e "${BRIGHT_YELLOW}⚠️  Warning: Cursor not found at $CURSOR_PATH${RESET}"
    echo -e "${YELLOW}Please edit the CURSOR_PATH variable in ainish-setup.sh${RESET}"
    errors=$((errors+1))
  fi
  
  # For commands in PATH, just check if they're available
  if ! command -v "$VSCODE_PATH" &> /dev/null; then
    echo -e "${BRIGHT_YELLOW}⚠️  Warning: VS Code command '$VSCODE_PATH' not found in PATH${RESET}"
    echo -e "${YELLOW}Please edit the VSCODE_PATH variable in ainish-setup.sh${RESET}"
    errors=$((errors+1))
  fi
  
  if ! command -v "$AIDER_PATH" &> /dev/null; then
    echo -e "${BRIGHT_YELLOW}⚠️  Warning: Aider command '$AIDER_PATH' not found in PATH${RESET}"
    echo -e "${YELLOW}Please edit the AIDER_PATH variable in ainish-setup.sh${RESET}"
    errors=$((errors+1))
  fi
  
  if [ $errors -gt 0 ]; then
    return 1
  fi
  return 0
}

# Clean up old ainish-coder files from home directory
cleanup_old_files() {
  echo -e "${BRIGHT_CYAN}🧹 Cleaning up old ainish-coder files from home directory...${RESET}"
  
  # Remove old setup scripts
  rm -f "${HOME}/setup.sh" "${HOME}/install.sh" "${HOME}/vscode-setup.sh" 2>/dev/null
  
  # Remove old configuration directories (but not ~/.ainish-coder)
  rm -rf "${HOME}/.ainish-cursor" "${HOME}/.ainish-aider" "${HOME}/.ainish-copilot" 2>/dev/null
  
  # Remove old configuration files
  rm -f "${HOME}/.ainish-config" "${HOME}/.ainish-settings" 2>/dev/null
  
  echo -e "${BRIGHT_GREEN}✅ Cleanup complete${RESET}"
}

# Helper function to prompt for ignore files
prompt_for_ignore_files() {
  local TARGET="$1"
  local TOOL="$2"
  local FILE="$3"
  local DESC="$4"
  local RESPONSE=""

  # Skip if file already exists in target
  if [ -f "$TARGET/$FILE" ]; then
    echo -e "${BLUE}✓ $FILE already exists in target directory, skipping${RESET}"
    return 1
  fi

  echo -e "${BRIGHT_CYAN}Would you like to include $FILE for $TOOL?${RESET}"
  echo -e "${CYAN}$DESC${RESET}"
  echo -e "${BRIGHT_CYAN}[Y/n]:${RESET} "
  read -r RESPONSE

  # Default to yes if empty response
  if [[ -z "$RESPONSE" ]] || [[ "$RESPONSE" =~ ^[Yy] ]]; then
    return 0
  fi
  return 1
}

# Main deployment function
deploy_ainish_configs() {
  local TARGET="$1"
  
  # Verify target is a directory
  if [ ! -d "$TARGET" ]; then
    echo -e "${BRIGHT_RED}Error: $TARGET is not a directory${RESET}"
    return 1
  fi
  
  echo -e "${BRIGHT_BLUE}Deploying AINISH configurations to $TARGET${RESET}"
  
  # Create necessary directories
  mkdir -p "$TARGET/.cursor/rules" 2>/dev/null
  mkdir -p "$TARGET/.github" 2>/dev/null
  
  # Deploy Cursor configurations
  if prompt_for_ignore_files "$TARGET" "Cursor" ".cursorignore" "Controls which files Cursor AI will ignore during code generation and analysis."; then
    if [ -f "${AINISH_CODER_DIR}/cursor/.cursorignore" ]; then
      cp "${AINISH_CODER_DIR}/cursor/.cursorignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .cursorignore${RESET}"
    else
      # Create empty .cursorignore if it doesn't exist
      touch "$TARGET/.cursorignore" 2>/dev/null
      echo -e "${GREEN}✓ Created empty .cursorignore${RESET}"
    fi
  fi
  
  if prompt_for_ignore_files "$TARGET" "Cursor" ".cursorindexingignore" "Controls which files Cursor will skip during indexing (improves performance)."; then
    if [ -f "${AINISH_CODER_DIR}/cursor/.cursorindexingignore" ]; then
      cp "${AINISH_CODER_DIR}/cursor/.cursorindexingignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .cursorindexingignore${RESET}"
    else
      # Create empty .cursorindexingignore if it doesn't exist
      touch "$TARGET/.cursorindexingignore" 2>/dev/null
      echo -e "${GREEN}✓ Created empty .cursorindexingignore${RESET}"
    fi
  fi
  
  # Deploy .cursorrules as a symlink if possible, otherwise copy
  if [ -f "${AINISH_CODER_DIR}/cursor/.cursorrules" ]; then
    if [ -L "$TARGET/.cursorrules" ] || [ -f "$TARGET/.cursorrules" ]; then
      rm -f "$TARGET/.cursorrules"
    fi
    ln -sf "${AINISH_CODER_DIR}/cursor/.cursorrules" "$TARGET/.cursorrules" 2>/dev/null
    if [ -L "$TARGET/.cursorrules" ]; then
      echo -e "${GREEN}✓ Symlinked .cursorrules to project root${RESET}"
    else
      cp "${AINISH_CODER_DIR}/cursor/.cursorrules" "$TARGET/.cursorrules" 2>/dev/null
      echo -e "${GREEN}✓ Copied .cursorrules to project root${RESET}"
    fi
  fi
  
  if [ -f "${AINISH_CODER_DIR}/cursor/my-license.mdc" ]; then
    cp "${AINISH_CODER_DIR}/cursor/my-license.mdc" "$TARGET/.cursor/rules/license.mdc" 2>/dev/null
    echo -e "${GREEN}✓ Deployed Cursor-specific license.mdc${RESET}"
  fi
  
  # Deploy shared critical.mdc and @MEMORY-BANK.mdc
  if [ -f "${AINISH_CODER_DIR}/critical.mdc" ]; then
    cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/.cursor/rules/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed critical.mdc to .cursor/rules/${RESET}"
    
    # Also deploy to aider and copilot locations
    cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/" 2>/dev/null # For Aider
    echo -e "${GREEN}✓ Deployed critical.mdc to $TARGET (for Aider)${RESET}"
    if [ -d "$TARGET/.github" ]; then
      cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/.github/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed critical.mdc to .github/ (for Copilot)${RESET}"
    fi
  fi
  
  # Deploy shared anishinaabe-cyberpunk-style.mdc
  if [ -f "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" ]; then
    cp "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/.cursor/rules/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed anishinaabe-cyberpunk-style.mdc to .cursor/rules/${RESET}"
    
    # Also deploy to aider and copilot locations
    cp "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/" 2>/dev/null # For Aider
    echo -e "${GREEN}✓ Deployed anishinaabe-cyberpunk-style.mdc to $TARGET (for Aider)${RESET}"
    if [ -d "$TARGET/.github" ]; then
      cp "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/.github/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed anishinaabe-cyberpunk-style.mdc to .github/ (for Copilot)${RESET}"
    fi
  fi
  
  # Deploy shared MEMORY-BANK.mdc
  if [ -f "${AINISH_CODER_DIR}/MEMORY-BANK.mdc" ]; then
    cp "${AINISH_CODER_DIR}/MEMORY-BANK.mdc" "$TARGET/.cursor/rules/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed MEMORY-BANK.mdc to .cursor/rules/${RESET}"
    
    # Also deploy to aider and copilot locations
    cp "${AINISH_CODER_DIR}/MEMORY-BANK.mdc" "$TARGET/" 2>/dev/null # For Aider
    echo -e "${GREEN}✓ Deployed MEMORY-BANK.mdc to $TARGET (for Aider)${RESET}"
    if [ -d "$TARGET/.github" ]; then
      cp "${AINISH_CODER_DIR}/MEMORY-BANK.mdc" "$TARGET/.github/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed MEMORY-BANK.mdc to .github/ (for Copilot)${RESET}"
    fi
  fi
  
  # Deploy shared docs-use.mdc
  if [ -f "${REPO_DIR}/docs-use.mdc" ]; then # Use REPO_DIR for root files
      cp "${REPO_DIR}/docs-use.mdc" "$TARGET/.cursor/rules/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed docs-use.mdc to .cursor/rules/${RESET}"

      cp "${REPO_DIR}/docs-use.mdc" "$TARGET/" 2>/dev/null # For Aider
      echo -e "${GREEN}✓ Deployed docs-use.mdc to $TARGET (for Aider)${RESET}"
      if [ -d "$TARGET/.github" ]; then
          cp "${REPO_DIR}/docs-use.mdc" "$TARGET/.github/" 2>/dev/null
          echo -e "${GREEN}✓ Deployed docs-use.mdc to .github/ (for Copilot)${RESET}"
      fi
  fi
  
  # Deploy Copilot configurations
  if prompt_for_ignore_files "$TARGET" "Copilot" ".copilotignore" "Controls which files GitHub Copilot will ignore during code suggestions."; then
    if [ -f "${AINISH_CODER_DIR}/vscode/.copilotignore" ]; then
      cp "${AINISH_CODER_DIR}/vscode/.copilotignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .copilotignore${RESET}"
    fi
  fi
  
  # Only copy .rooignore if user wants it
  if prompt_for_ignore_files "$TARGET" "Copilot" ".rooignore" "Controls which files are excluded from Copilot's context window."; then
    if [ -f "${AINISH_CODER_DIR}/vscode/.rooignore" ]; then
      cp "${AINISH_CODER_DIR}/vscode/.rooignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .rooignore${RESET}"
    fi
  fi
  
  # Deploy custom copilot instructions from ainish-copilot
  if [ -f "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" ]; then
    mkdir -p "$TARGET/.github" 2>/dev/null
    cp "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed custom copilot-instructions.md from ainish-copilot${RESET}"
  fi

  # Deploy Aider configurations
  if prompt_for_ignore_files "$TARGET" "Aider" ".aiderignore" "Controls which files Aider will ignore during code generation and edits."; then
    if [ -f "${AINISH_CODER_DIR}/aider/.aiderignore" ]; then
      cp "${AINISH_CODER_DIR}/aider/.aiderignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .aiderignore${RESET}"
    fi
  fi
  
  if [ -f "${AINISH_CODER_DIR}/aider/.aider.conf.yml" ]; then
    cp "${AINISH_CODER_DIR}/aider/.aider.conf.yml" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .aider.conf.yml${RESET}"
  fi
  
  if [ -f "${AINISH_CODER_DIR}/aider/.env.example" ]; then
    cp "${AINISH_CODER_DIR}/aider/.env.example" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .env.example${RESET}"
  fi
  
  if [ -f "${AINISH_CODER_DIR}/aider/aider-cli-commands.sh" ]; then
    cp "${AINISH_CODER_DIR}/aider/aider-cli-commands.sh" "$TARGET/" 2>/dev/null
    chmod +x "$TARGET/aider-cli-commands.sh" 2>/dev/null # Ensure executable
    echo -e "${GREEN}✓ Deployed aider-cli-commands.sh${RESET}"
  fi
  
  # Deploy prompt.md from root to destinations with special names
  if [ -f "${REPO_DIR}/prompt.md" ]; then
    # Deploy for Copilot
    if [ -d "$TARGET/.github" ]; then
      prepend_non_cursor_content "${REPO_DIR}/prompt.md" "$TARGET/.github/copilot-instructions.md"
    fi
    # Deploy for Aider
    prepend_non_cursor_content "${REPO_DIR}/prompt.md" "$TARGET/.aider-instructions.md"
    # Deploy for Cursor (without non-cursor-append.md content)
    if [ -d "$TARGET/.cursor/rules" ]; then
        cp "${REPO_DIR}/prompt.md" "$TARGET/.cursor/rules/gikendaasowin.md" 2>/dev/null
        echo -e "${GREEN}✓ Deployed prompt.md as gikendaasowin.md to .cursor/rules/${RESET}"
    fi
  fi
  
  # Deploy .gitignore from root
  if [ -f "${REPO_DIR}/.gitignore" ]; then
      cp "${REPO_DIR}/.gitignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed root .gitignore to $TARGET${RESET}"
  fi
  
  # Update .gitignore (append tool-specific ignores)
  update_gitignore "$TARGET"
  
  echo -e "${BRIGHT_GREEN}✅ AINISH configurations deployed to $TARGET${RESET}"
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
      echo -e "${BLUE}Updated .gitignore with AINISH config entries${RESET}"
    else
      echo -e "${BLUE}.gitignore already contains AINISH entries${RESET}"
    fi
  else
    # Create new .gitignore
    for entry in "${ENTRIES[@]}"; do
      echo "$entry" >> "$GITIGNORE"
    done
    echo -e "${BLUE}Created .gitignore with AINISH config entries${RESET}"
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
  sed -i '' '/### AINISH CODER WRAPPERS ###/,/### END AINISH CODER WRAPPERS ###/d' "$ZSHRC" 2>/dev/null
  
  # First export the AINISH_CODER_DIR
  cat >> "$ZSHRC" << EOF
### AINISH CODER WRAPPERS ###
# Export AINISH-Coder paths
export AINISH_CODER_DIR="${AINISH_CODER_DIR}"
export CURSOR_PATH="$CURSOR_PATH"
export VSCODE_PATH="$VSCODE_PATH"
export AIDER_PATH="$AIDER_PATH"
export REPO_DIR="$REPO_DIR"

EOF

  # Then add the functions
  cat >> "$ZSHRC" << 'EOF'
# AINISH-Coder wrapper functions
function ainish-coder {
  # Capture current directory explicitly to handle external volumes
  local CURRENT_DIR="$(pwd)"
  
  # Deploy from the linked repo directories to ensure latest changes are used
  "$AINISH_CODER_DIR/ainish-setup.sh" deploy "$CURRENT_DIR"
  echo "✨ AINISH-Coder configurations deployed to current directory"
  echo "🔄 Using symlinks to repository - changes to repo files are immediately available"
}

function ainish-cursor {
  # Capture current directory explicitly to handle external volumes
  local CURRENT_DIR="$(pwd)"
  
  # Deploy from the linked repo directories to ensure latest changes are used
  "$AINISH_CODER_DIR/ainish-setup.sh" deploy_cursor_configs "$CURRENT_DIR"
  echo "🔄 Using symlinked configuration - changes to repo files are immediately available"
  if [[ "$1" == -* ]]; then
    "$CURSOR_PATH" "$@"
  else
    "$CURSOR_PATH" "$@"
  fi
}

function ainish-aider {
  # Capture current directory explicitly to handle external volumes
  local CURRENT_DIR="$(pwd)"
  
  # Deploy from the linked repo directories to ensure latest changes are used
  "$AINISH_CODER_DIR/ainish-setup.sh" deploy_aider_configs "$CURRENT_DIR"
  echo "🔄 Using symlinked configuration - changes to repo files are immediately available"
}

function ainish-copilot {
  # Capture current directory explicitly to handle external volumes
  local CURRENT_DIR="$(pwd)"
  
  # Deploy from the linked repo directories to ensure latest changes are used
  "$AINISH_CODER_DIR/ainish-setup.sh" deploy_vscode_configs "$CURRENT_DIR"
  echo "🔄 Using symlinked configuration - changes to repo files are immediately available"
  if [[ "$1" == -* ]]; then
    "$VSCODE_PATH" "$@"
  else
    "$VSCODE_PATH" "$@"
  fi
}

### END AINISH CODER WRAPPERS ###
EOF

  echo -e "${BRIGHT_GREEN}✅ Wrapper functions added to .zshrc${RESET}"
}

# Function to deploy only VS Code configurations
deploy_vscode_configs() {
  local TARGET="$1"

  # Verify target is a directory
  if [ ! -d "$TARGET" ]; then
    echo -e "${BRIGHT_RED}Error: $TARGET is not a directory${RESET}"
    return 1
  fi

  echo -e "${BRIGHT_BLUE}Deploying VS Code configurations to $TARGET${RESET}"

  # Create necessary directories
  mkdir -p "$TARGET/.github" 2>/dev/null
  
  # Deploy VS Code-specific configurations
  if prompt_for_ignore_files "$TARGET" "Copilot" ".copilotignore" "Controls which files GitHub Copilot will ignore during code suggestions."; then
    if [ -f "${AINISH_CODER_DIR}/vscode/.copilotignore" ]; then
      cp "${AINISH_CODER_DIR}/vscode/.copilotignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .copilotignore${RESET}"
    fi
  fi

  # Only copy .rooignore if user wants it
  if prompt_for_ignore_files "$TARGET" "Copilot" ".rooignore" "Controls which files are excluded from Copilot's context window."; then
    if [ -f "${AINISH_CODER_DIR}/vscode/.rooignore" ]; then
      cp "${AINISH_CODER_DIR}/vscode/.rooignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .rooignore${RESET}"
    fi
  fi

  # Deploy custom copilot instructions from ainish-copilot
  if [ -f "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" ]; then
    mkdir -p "$TARGET/.github" 2>/dev/null
    cp "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed custom copilot-instructions.md from ainish-copilot${RESET}"
  fi

  # Deploy shared critical.mdc and @MEMORY-BANK.mdc
  if [ -f "${AINISH_CODER_DIR}/critical.mdc" ]; then
    cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/.github/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed critical.mdc to .github/${RESET}"
  fi
  
  # Deploy anishinaabe-cyberpunk-style.mdc
  if [ -f "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" ]; then
    cp "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/.github/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed anishinaabe-cyberpunk-style.mdc to .github/${RESET}"
  fi

  # Corrected source file name
  if [ -f "${AINISH_CODER_DIR}/MEMORY-BANK.mdc" ]; then
    cp "${AINISH_CODER_DIR}/MEMORY-BANK.mdc" "$TARGET/.github/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed MEMORY-BANK.mdc to .github/${RESET}"
  fi

  # Deploy shared docs-use.mdc
  if [ -f "${REPO_DIR}/docs-use.mdc" ]; then # Use REPO_DIR for root files
    if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/docs-use.mdc" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed docs-use.mdc to .github/${RESET}"
    fi
  fi

  # Deploy prompt.md as copilot-instructions.md (ensure it happens)
  local prompt_source="${REPO_DIR}/prompt.md"
  local copilot_target_dir="$TARGET/.github"
  local copilot_target_file="$copilot_target_dir/copilot-instructions.md"
  if [ -f "$prompt_source" ]; then
      mkdir -p "$copilot_target_dir" 2>/dev/null
      prepend_non_cursor_content "$prompt_source" "$copilot_target_file"
  else
      echo -e "${YELLOW}⚠️ Warning: Source prompt.md not found at $prompt_source${RESET}"
  fi

  # Deploy .gitignore from root
  if [ -f "${REPO_DIR}/.gitignore" ]; then
      cp "${REPO_DIR}/.gitignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed root .gitignore to $TARGET${RESET}"
  fi

  # Update .gitignore (append tool-specific ignores)
  update_gitignore "$TARGET"
  
  echo -e "${BRIGHT_GREEN}✅ VS Code configurations deployed to $TARGET${RESET}"
}

# Function to deploy only Cursor configurations
deploy_cursor_configs() {
  local TARGET="$1"
  local SRC_CURSOR_DIR="${AINISH_CODER_DIR}/cursor" # Points to REPO_DIR/ainish-cursor via symlink

  # Verify target is a directory
  if [ ! -d "$TARGET" ]; then
    echo -e "${BRIGHT_RED}Error: $TARGET is not a directory${RESET}"
    return 1
  fi

  echo -e "${BRIGHT_BLUE}Deploying Cursor configurations to $TARGET${RESET}"

  # Create necessary directories
  mkdir -p "$TARGET/.cursor/rules" 2>/dev/null

  # --- Deploy files directly into the TARGET directory ---

  # Deploy .cursorignore
  if prompt_for_ignore_files "$TARGET" "Cursor" ".cursorignore" "Controls which files Cursor AI will ignore during code generation and analysis."; then
    if [ -f "${SRC_CURSOR_DIR}/.cursorignore" ]; then
      cp "${SRC_CURSOR_DIR}/.cursorignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .cursorignore${RESET}"
    else
      touch "$TARGET/.cursorignore" 2>/dev/null
      echo -e "${GREEN}✓ Created empty .cursorignore${RESET}"
    fi
  fi

  # Deploy .cursorindexingignore
  if prompt_for_ignore_files "$TARGET" "Cursor" ".cursorindexingignore" "Controls which files Cursor will skip during indexing (improves performance)."; then
    if [ -f "${SRC_CURSOR_DIR}/.cursorindexingignore" ]; then
      cp "${SRC_CURSOR_DIR}/.cursorindexingignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .cursorindexingignore${RESET}"
    else
      touch "$TARGET/.cursorindexingignore" 2>/dev/null
      echo -e "${GREEN}✓ Created empty .cursorindexingignore${RESET}"
    fi
  fi

  # Deploy .cursorrules (Symlink preferred, copy fallback)
  if [ -f "${SRC_CURSOR_DIR}/.cursorrules" ]; then
    # Remove existing file/symlink first
    rm -f "$TARGET/.cursorrules" 2>/dev/null
    ln -sf "${SRC_CURSOR_DIR}/.cursorrules" "$TARGET/.cursorrules" 2>/dev/null
    if [ -L "$TARGET/.cursorrules" ]; then
      echo -e "${GREEN}✓ Symlinked .cursorrules to project root${RESET}"
    else
      cp "${SRC_CURSOR_DIR}/.cursorrules" "$TARGET/.cursorrules" 2>/dev/null
      echo -e "${GREEN}✓ Copied .cursorrules to project root (symlink failed)${RESET}"
    fi
  fi

  # --- Deploy files into the TARGET/.cursor/rules directory ---
  local SRC_RULES_DIR="${SRC_CURSOR_DIR}/.cursor/rules"
  local TARGET_RULES_DIR="$TARGET/.cursor/rules"

  echo -e "${BLUE}Syncing contents of ${SRC_RULES_DIR} to ${TARGET_RULES_DIR}...${RESET}"
  # Copy all contents from source rules directory, overwriting existing files
  if [ -d "$SRC_RULES_DIR" ]; then
     cp -R "${SRC_RULES_DIR}/." "$TARGET_RULES_DIR/" 2>/dev/null
     echo -e "${GREEN}✓ Copied all rules from ${SRC_RULES_DIR}${RESET}"
  else
     echo -e "${YELLOW}⚠️ Warning: Source rules directory ${SRC_RULES_DIR} not found.${RESET}"
  fi

  # --- Overwrite specific files if needed (ensuring correct source) ---

  # Deploy critical.mdc (ensure it comes from the central location)
  local critical_src="${AINISH_CODER_DIR}/critical.mdc" # Should point to REPO_DIR/critical.mdc
  if [ -f "$critical_src" ]; then
    cp "$critical_src" "$TARGET_RULES_DIR/" 2>/dev/null
    echo -e "${GREEN}✓ Ensured latest critical.mdc is in .cursor/rules/${RESET}"
  fi

  # Deploy MEMORY-BANK.mdc (ensure it comes from the central location)
  local memory_src="${AINISH_CODER_DIR}/MEMORY-BANK.mdc" # Should point to REPO_DIR/MEMORY-BANK.mdc
  if [ -f "$memory_src" ]; then
    cp "$memory_src" "$TARGET_RULES_DIR/" 2>/dev/null # Ensure it's copied into the rules dir
    echo -e "${GREEN}✓ Ensured latest MEMORY-BANK.mdc is in .cursor/rules/${RESET}"
  fi

  # Deploy docs-use.mdc (ensure it comes from the central location)
  local docs_src="${REPO_DIR}/docs-use.mdc" # Use REPO_DIR for root files
  if [ -f "$docs_src" ]; then
      cp "$docs_src" "$TARGET_RULES_DIR/" 2>/dev/null
      echo -e "${GREEN}✓ Ensured latest docs-use.mdc is in .cursor/rules/${RESET}"
  fi

  # Deploy prompt.md as gikendaasowin.md (ensure it comes from the central location)
  local prompt_src="${REPO_DIR}/prompt.md" # Use REPO_DIR directly for root files
  if [ -f "$prompt_src" ]; then
    # For Cursor, don't append non-cursor content
    cp "$prompt_src" "$TARGET_RULES_DIR/gikendaasowin.md" 2>/dev/null
    echo -e "${GREEN}✓ Ensured latest prompt.md is deployed as gikendaasowin.md${RESET}"
  fi

  # Deploy license.mdc if it exists in the source cursor dir (might be specific)
  if [ -f "${SRC_CURSOR_DIR}/my-license.mdc" ]; then
      cp "${SRC_CURSOR_DIR}/my-license.mdc" "$TARGET_RULES_DIR/license.mdc" 2>/dev/null
      echo -e "${GREEN}✓ Deployed license.mdc from ${SRC_CURSOR_DIR}${RESET}"
  fi

  # Verification steps (optional but good)
  echo -e "${BLUE}Verifying deployed Cursor files...${RESET}"
  ls -l "$TARGET/.cursorignore" "$TARGET/.cursorindexingignore" "$TARGET/.cursorrules" "$TARGET_RULES_DIR/" 2>/dev/null || echo -e "${YELLOW}Verification step encountered issues.${RESET}"

  # Deploy .gitignore from root
  if [ -f "${REPO_DIR}/.gitignore" ]; then
      cp "${REPO_DIR}/.gitignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed root .gitignore to $TARGET${RESET}"
  fi

  # Update .gitignore (append tool-specific ignores)
  update_gitignore "$TARGET"

  echo -e "${BRIGHT_GREEN}✅ Cursor configurations deployed to $TARGET${RESET}"
}

# Function to deploy only Aider configurations
deploy_aider_configs() {
  local TARGET="$1"

  # Verify target is a directory
  if [ ! -d "$TARGET" ]; then
    echo -e "${BRIGHT_RED}Error: $TARGET is not a directory${RESET}"
    return 1
  fi

  echo -e "${BRIGHT_BLUE}Deploying Aider configurations to $TARGET${RESET}"

  # Deploy Aider-specific configurations
  # Copy .aider-instructions.md from the root prompt.md
  local prompt_source="${REPO_DIR}/prompt.md"
  local aider_target_file="$TARGET/.aider-instructions.md"
  if [ -f "$prompt_source" ]; then
    prepend_non_cursor_content "$prompt_source" "$aider_target_file"
  else
    echo -e "${YELLOW}⚠️ Warning: Source prompt.md not found at $prompt_source${RESET}"
  fi
  
  # Deploy anishinaabe-cyberpunk-style.mdc
  if [ -f "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" ]; then
    cp "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed anishinaabe-cyberpunk-style.mdc to $TARGET${RESET}"
  fi
  
  if [ -f "${AINISH_CODER_DIR}/aider/.aider.conf.yml" ]; then
    cp "${AINISH_CODER_DIR}/aider/.aider.conf.yml" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .aider.conf.yml${RESET}"
  fi
  
  if [ -f "${AINISH_CODER_DIR}/aider/.aiderignore" ]; then
    cp "${AINISH_CODER_DIR}/aider/.aiderignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .aiderignore${RESET}"
  fi
  
  if [ -f "${AINISH_CODER_DIR}/aider/.env.example" ]; then
    cp "${AINISH_CODER_DIR}/aider/.env.example" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .env.example${RESET}"
  fi

  if [ -f "${AINISH_CODER_DIR}/aider/aider-cli-commands.sh" ]; then
    cp "${AINISH_CODER_DIR}/aider/aider-cli-commands.sh" "$TARGET/" 2>/dev/null
    chmod +x "$TARGET/aider-cli-commands.sh" 2>/dev/null # Ensure executable
    echo -e "${GREEN}✓ Deployed aider-cli-commands.sh${RESET}"
  fi

  # Deploy shared critical.mdc and @MEMORY-BANK.mdc directly to target directory
  if [ -f "${AINISH_CODER_DIR}/critical.mdc" ]; then
    cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed critical.mdc to $TARGET${RESET}"
  fi

  # Corrected source file name
  if [ -f "${AINISH_CODER_DIR}/MEMORY-BANK.mdc" ]; then
    cp "${AINISH_CODER_DIR}/MEMORY-BANK.mdc" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed MEMORY-BANK.mdc to $TARGET${RESET}"
  fi

  # Deploy docs-use.mdc (ensure it comes from the central location)
  local docs_src="${REPO_DIR}/docs-use.mdc" # Use REPO_DIR for root files
  if [ -f "$docs_src" ]; then
      cp "$docs_src" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed docs-use.mdc to $TARGET${RESET}"
  fi

  # Deploy prompt.md as .aider-instructions.md (ensure it comes from the central location)
  local prompt_src="${REPO_DIR}/prompt.md"
  if [ -f "$prompt_src" ]; then
    prepend_non_cursor_content "$prompt_src" "$TARGET/.aider-instructions.md"
  else
    echo -e "${YELLOW}⚠️ Warning: Source prompt.md not found at $prompt_src${RESET}"
  fi

  # Deploy .gitignore from root
  if [ -f "${REPO_DIR}/.gitignore" ]; then
      cp "${REPO_DIR}/.gitignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed root .gitignore to $TARGET${RESET}"
  fi

  # Update .gitignore (append tool-specific ignores)
  update_gitignore "$TARGET"
  
  echo -e "${BRIGHT_GREEN}✅ Aider configurations deployed to $TARGET${RESET}"
}

# Function to append non-cursor content to prompt.md derived files
prepend_non_cursor_content() {
  local SOURCE="$1"
  local DEST="$2"
  local NON_CURSOR_PREPEND="${REPO_DIR}/non-cursor-prepend.md"
  
  # Don't prepend if destination contains "cursor" (for ainish-cursor directory or .cursor/rules)
  if [[ "$DEST" == *"cursor"* ]]; then
    # Just copy the file without modification
    cp "$SOURCE" "$DEST" 2>/dev/null
    return $?
  fi
  
  # Check if non-cursor-prepend.md exists
  if [ ! -f "$NON_CURSOR_PREPEND" ]; then
    echo -e "${YELLOW}⚠️ Warning: non-cursor-prepend.md not found at $NON_CURSOR_PREPEND${RESET}"
    # Fall back to normal copy
    cp "$SOURCE" "$DEST" 2>/dev/null
    return $?
  fi
  
  # Create combined file: non-cursor-prepend.md + separator + prompt.md
  { cat "$NON_CURSOR_PREPEND"; cat "$SOURCE"; } > "$DEST" 2>/dev/null
  local RESULT=$?
  
  if [ $RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ Deployed $SOURCE to $DEST with non-cursor prepended content${RESET}"
  else
    echo -e "${YELLOW}⚠️ Warning: Failed to prepend non-cursor content to $DEST${RESET}"
    # Fall back to normal copy
    cp "$SOURCE" "$DEST" 2>/dev/null
  fi
  
  return $RESULT
}

# Main execution
main() {
  # Check for command argument
  if [ "$1" == "deploy" ]; then
    # Deploy configurations to the specified directory
    deploy_ainish_configs "$2"
  elif [ "$1" == "deploy_vscode_configs" ]; then
    # Deploy VS Code configurations to the specified directory
    deploy_vscode_configs "$2"
  elif [ "$1" == "deploy_cursor_configs" ]; then
    # Deploy Cursor configurations to the specified directory
    deploy_cursor_configs "$2"
  elif [ "$1" == "deploy_aider_configs" ]; then
    # Deploy Aider configurations to the specified directory
    deploy_aider_configs "$2"
  else
    # Default: Run full initial setup
    # Print cyberpunk-style header
    echo -e "${BRIGHT_MAGENTA}╔══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BRIGHT_MAGENTA}║${RESET}               ${BRIGHT_CYAN}A I N I S H - C O D E R${RESET}                ${BRIGHT_MAGENTA}║${RESET}"
    echo -e "${BRIGHT_MAGENTA}╚══════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""

    # --- Perform initial file distribution within the repository ---
    echo -e "${BRIGHT_YELLOW}Performing initial file distribution within repository...${RESET}"
    
    # Define source files (use actual filenames)
    local critical_src="${REPO_DIR}/critical.mdc"
    local memory_src="${REPO_DIR}/MEMORY-BANK.mdc" # Correct filename (removed @)
    local prompt_src="${REPO_DIR}/prompt.md"
    # Define docs-use.mdc source
    local docs_src="${REPO_DIR}/docs-use.mdc"
    
    # Define destination directories relative to REPO_DIR
    local aider_dest_dir="${REPO_DIR}/ainish-aider"
    local copilot_dest_dir="${REPO_DIR}/ainish-copilot" # Base dir for .gitignore
    local copilot_github_dest_dir="${REPO_DIR}/ainish-copilot/.github"
    local cursor_dest_dir="${REPO_DIR}/ainish-cursor" # Base dir for .gitignore
    local cursor_rules_dest_dir="${REPO_DIR}/ainish-cursor/.cursor/rules"
    local root_cursor_rules_dest_dir="${REPO_DIR}/.cursor/rules" # Target for root .cursor/rules/

    # Ensure target directories exist
    mkdir -p "$aider_dest_dir" 2>/dev/null
    mkdir -p "$copilot_github_dest_dir" 2>/dev/null # Ensure .github exists
    mkdir -p "$copilot_dest_dir" 2>/dev/null        # Ensure base copilot dir exists
    mkdir -p "$cursor_rules_dest_dir" 2>/dev/null
    mkdir -p "$cursor_dest_dir" 2>/dev/null         # Ensure base cursor dir exists
    mkdir -p "$root_cursor_rules_dest_dir" 2>/dev/null # Ensure root .cursor/rules exists

    # Copy critical.mdc
    if [ -f "$critical_src" ]; then
      cp "$critical_src" "$aider_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied critical.mdc to ainish-aider/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy critical.mdc to ainish-aider/${RESET}"
      cp "$critical_src" "$copilot_github_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied critical.mdc to ainish-copilot/.github/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy critical.mdc to ainish-copilot/.github/${RESET}"
      cp "$critical_src" "$cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied critical.mdc to ainish-cursor/.cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy critical.mdc to ainish-cursor/.cursor/rules/${RESET}"
      cp "$critical_src" "$root_cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied critical.mdc to .cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy critical.mdc to .cursor/rules/${RESET}"
    else
      echo -e "${YELLOW}⚠️ Warning: Source critical.mdc not found at $critical_src${RESET}"
    fi

    # Copy MEMORY-BANK.mdc
    if [ -f "$memory_src" ]; then
      cp "$memory_src" "$aider_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied MEMORY-BANK.mdc to ainish-aider/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy MEMORY-BANK.mdc to ainish-aider/${RESET}"
      cp "$memory_src" "$copilot_github_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied MEMORY-BANK.mdc to ainish-copilot/.github/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy MEMORY-BANK.mdc to ainish-copilot/.github/${RESET}"
      cp "$memory_src" "$cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied MEMORY-BANK.mdc to ainish-cursor/.cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy MEMORY-BANK.mdc to ainish-cursor/.cursor/rules/${RESET}"
      cp "$memory_src" "$root_cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied MEMORY-BANK.mdc to .cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy MEMORY-BANK.mdc to .cursor/rules/${RESET}"
    else
      echo -e "${YELLOW}⚠️ Warning: Source MEMORY-BANK.mdc not found at $memory_src${RESET}"
    fi
    # Copy docs-use.mdc
    if [ -f "$docs_src" ]; then
      cp "$docs_src" "$aider_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied docs-use.mdc to ainish-aider/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy docs-use.mdc to ainish-aider/${RESET}"
      cp "$docs_src" "$copilot_github_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied docs-use.mdc to ainish-copilot/.github/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy docs-use.mdc to ainish-copilot/.github/${RESET}"
      cp "$docs_src" "$cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied docs-use.mdc to ainish-cursor/.cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy docs-use.mdc to ainish-cursor/.cursor/rules/${RESET}"
      cp "$docs_src" "$root_cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied docs-use.mdc to .cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy docs-use.mdc to .cursor/rules/${RESET}"
    else
      echo -e "${YELLOW}⚠️ Warning: Source docs-use.mdc not found at $docs_src${RESET}"
    fi
    
    # Copy prompt.md to specific destinations
    if [ -f "$prompt_src" ]; then
      local copilot_target="${copilot_github_dest_dir}/copilot-instructions.md" # Corrected path
      local aider_target="${aider_dest_dir}/.aider-instructions.md"
      local cursor_target="${cursor_rules_dest_dir}/gikendaasowin.md"
      
      cp "$prompt_src" "$copilot_target" 2>/dev/null && echo -e "${GREEN}✓ Copied prompt.md to $copilot_target${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy prompt.md to $copilot_target${RESET}"
      cp "$prompt_src" "$aider_target" 2>/dev/null && echo -e "${GREEN}✓ Copied prompt.md to $aider_target${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy prompt.md to $aider_target${RESET}"
      cp "$prompt_src" "$cursor_target" 2>/dev/null && echo -e "${GREEN}✓ Copied prompt.md to $cursor_target${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy prompt.md to $cursor_target${RESET}"
    else
      echo -e "${YELLOW}⚠️ Warning: Source prompt.md not found at $prompt_src${RESET}"
    fi
    
    # Copy .gitignore to specific destinations
    if [ -f "${REPO_DIR}/.gitignore" ]; then
        cp "${REPO_DIR}/.gitignore" "$aider_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied .gitignore to ainish-aider/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy .gitignore to ainish-aider/${RESET}"
        cp "${REPO_DIR}/.gitignore" "$copilot_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied .gitignore to ainish-copilot/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy .gitignore to ainish-copilot/${RESET}"
        cp "${REPO_DIR}/.gitignore" "$cursor_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied .gitignore to ainish-cursor/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy .gitignore to ainish-cursor/${RESET}"
    else
        echo -e "${YELLOW}⚠️ Warning: Source .gitignore not found at ${REPO_DIR}/.gitignore${RESET}"
    fi
    
    echo -e "${GREEN}✓ Initial file distribution complete.${RESET}"
    echo ""
    # --- End initial file distribution ---

    # Regular setup steps continue...
    echo -e "${BRIGHT_CYAN}🔧 [INIT] Setting up AINISH-Coder tooling configurations...${RESET}"
    echo ""

    # Clean up old files
    cleanup_old_files

    # Setup ~/.ainish-coder directory
    setup_ainish_coder_dir

    # Verify tool paths
    if ! verify_tool_paths; then
      echo -e "${BRIGHT_YELLOW}⚠️  [WARN] Setup will continue but some tools may not work correctly.${RESET}"
      echo -e "${YELLOW}Please edit the path variables in $AINISH_CODER_DIR/ainish-setup.sh to fix this.${RESET}"
      echo ""
    fi

    # Make script executable
    chmod +x "$AINISH_CODER_DIR/ainish-setup.sh"

    # Set up wrapper functions
    setup_wrapper_functions
    
    echo -e "${BRIGHT_MAGENTA}╔══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BRIGHT_MAGENTA}║${RESET}               ${BRIGHT_GREEN}A I N I S H - C O D E R${RESET}            ${BRIGHT_MAGENTA}║${RESET}"
    echo -e "${BRIGHT_MAGENTA}╚══════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${BRIGHT_CYAN}🔄 To activate all changes, run: ${BRIGHT_BLUE}source ~/.zshrc${RESET}"
    echo ""
    echo -e "${BRIGHT_MAGENTA}✨ AVAILABLE COMMANDS:${RESET}"
    echo -e "${BRIGHT_BLUE}   ▶ ainish-coder${RESET}: ${CYAN}Install all configurations to current directory${RESET}"
    echo -e "${BRIGHT_BLUE}   ▶ ainish-cursor${RESET}: ${CYAN}Install Cursor configurations to current directory${RESET}"
    echo -e "${BRIGHT_BLUE}   ▶ ainish-aider${RESET}: ${CYAN}Install Aider configurations to current directory${RESET}"
    echo -e "${BRIGHT_BLUE}   ▶ ainish-copilot${RESET}: ${CYAN}Install VS Code configurations to current directory${RESET}"
    echo -e "${BRIGHT_BLUE}   ▶ ainish-update${RESET}: ${CYAN}Update AINISH-Coder from the repository${RESET}"
    echo ""
    echo -e "${BRIGHT_GREEN}🔗 SYMLINKED CONFIGURATION:${RESET}"
    echo -e "${GREEN}   Your AINISH-Coder installation is now symlinked to your repository at:${RESET}"
    echo -e "${CYAN}   $REPO_DIR${RESET}"
    echo -e "${GREEN}   Changes to repository files will be immediately available to the tools${RESET}"
    echo -e "${GREEN}   without needing to rerun the setup script.${RESET}"
    echo ""
  fi
}

# Execute main function
main "$@"