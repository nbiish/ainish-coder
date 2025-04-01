#!/bin/bash

# AINISH-Coder Unified Setup Script
# This script sets up all tooling configurations in one go and provides wrapper functions

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
  
  # Create symlink for critical.mdc
  ln -sf "${REPO_DIR}/critical.mdc" "${AINISH_CODER_DIR}/critical.mdc" 2>/dev/null
  
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
  if [ -f "${AINISH_CODER_DIR}/cursor/.cursorignore" ]; then
    cp "${AINISH_CODER_DIR}/cursor/.cursorignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .cursorignore${RESET}"
  else
    # Create empty .cursorignore if it doesn't exist
    touch "$TARGET/.cursorignore" 2>/dev/null
    echo -e "${GREEN}✓ Created empty .cursorignore${RESET}"
  fi
  
  if [ -f "${AINISH_CODER_DIR}/cursor/.cursorindexingignore" ]; then
    cp "${AINISH_CODER_DIR}/cursor/.cursorindexingignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .cursorindexingignore${RESET}"
  else
    # Create empty .cursorindexingignore if it doesn't exist
    touch "$TARGET/.cursorindexingignore" 2>/dev/null
    echo -e "${GREEN}✓ Created empty .cursorindexingignore${RESET}"
  fi
  
  if [ -d "${AINISH_CODER_DIR}/cursor/.cursorrules" ]; then
    cp -r "${AINISH_CODER_DIR}/cursor/.cursorrules" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .cursorrules/${RESET}"
  fi
  
  # Handle license files - ainish-cursor uses its own, others use the root version
  if [ -f "${AINISH_CODER_DIR}/cursor/my-license.mdc" ]; then
    cp "${AINISH_CODER_DIR}/cursor/my-license.mdc" "$TARGET/.cursor/rules/license.mdc" 2>/dev/null
    echo -e "${GREEN}✓ Deployed Cursor-specific license.mdc${RESET}"
  fi
  
  # Deploy shared critical.mdc for other tools
  if [ -f "${AINISH_CODER_DIR}/critical.mdc" ]; then
    cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/.cursor/rules/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed critical.mdc to .cursor/rules/${RESET}"
    
    if [ -d "$TARGET/.github" ]; then
      cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/.github/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed critical.mdc to .github/${RESET}"
    fi
  fi
  
  # Deploy Copilot configurations
  if [ -f "${AINISH_CODER_DIR}/vscode/.copilotignore" ]; then
    cp "${AINISH_CODER_DIR}/vscode/.copilotignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .copilotignore${RESET}"
  fi
  
  # Only copy .rooignore if it doesn't already exist in the target directory
  if [ -f "${AINISH_CODER_DIR}/vscode/.rooignore" ] && [ ! -f "$TARGET/.rooignore" ]; then
    cp "${AINISH_CODER_DIR}/vscode/.rooignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .rooignore${RESET}"
  elif [ -f "$TARGET/.rooignore" ]; then
    echo -e "${BLUE}✓ .rooignore already exists, skipping${RESET}"
  fi
  
  # Copy copilot-instructions.md to .github directory
  if [ -f "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" ]; then
    cp "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .github/copilot-instructions.md${RESET}"
  else
    # Check if it exists directly in the source
    if [ -f "${REPO_DIR}/ainish-copilot/.github/copilot-instructions.md" ]; then
      mkdir -p "$TARGET/.github" 2>/dev/null
      cp "${REPO_DIR}/ainish-copilot/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .github/copilot-instructions.md (from repo)${RESET}"
    else
      echo -e "${YELLOW}⚠️ Warning: copilot-instructions.md not found${RESET}"
    fi
  fi
  
  # Deploy Aider configurations
  if [ -f "${AINISH_CODER_DIR}/aider/.aider-instructions.md" ]; then
    cp "${AINISH_CODER_DIR}/aider/.aider-instructions.md" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .aider-instructions.md${RESET}"
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
  
  # Deploy shared critical.mdc
  if [ -f "${AINISH_CODER_DIR}/critical.mdc" ]; then
    cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/.github/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed critical.mdc to .github/${RESET}"
  fi
  
  # Deploy shared critical.mdc directly to target directory, not to .aider subfolder
  if [ -f "${AINISH_CODER_DIR}/critical.mdc" ]; then
    cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed critical.mdc to $TARGET${RESET}"
  fi
  
  # Update .gitignore
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
  # Deploy from the linked repo directories to ensure latest changes are used
  "$AINISH_CODER_DIR/ainish-setup.sh" deploy "$PWD"
  echo "✨ AINISH-Coder configurations deployed to current directory"
  echo "🔄 Using symlinks to repository - changes to repo files are immediately available"
}

function ainish-cursor {
  # Deploy from the linked repo directories to ensure latest changes are used
  "$AINISH_CODER_DIR/ainish-setup.sh" deploy_cursor_configs "$PWD"
  echo "🔄 Using symlinked configuration - changes to repo files are immediately available"
  if [[ "$1" == -* ]]; then
    "$CURSOR_PATH" "$@"
  else
    "$CURSOR_PATH" "$@"
  fi
}

function ainish-aider {
  # Deploy from the linked repo directories to ensure latest changes are used
  "$AINISH_CODER_DIR/ainish-setup.sh" deploy_aider_configs "$PWD"
  echo "🔄 Using symlinked configuration - changes to repo files are immediately available"
  "$AIDER_PATH" "$@"
}

function ainish-copilot {
  # Deploy from the linked repo directories to ensure latest changes are used
  "$AINISH_CODER_DIR/ainish-setup.sh" deploy_vscode_configs "$PWD"
  echo "🔄 Using symlinked configuration - changes to repo files are immediately available"
  if [[ "$1" == -* ]]; then
    "$VSCODE_PATH" "$@"
  else
    "$VSCODE_PATH" "$@"
  fi
}

# Function to update the AINISH-Coder installation from the repository
function ainish-update {
  echo "🔄 Updating AINISH-Coder from repository..."
  # Try to load REPO_DIR from config if not set
  if [ -z "$REPO_DIR" ] && [ -f "$AINISH_CODER_DIR/config.sh" ]; then
    source "$AINISH_CODER_DIR/config.sh"
  fi
  # Re-run the setup script from the repository
  if [ -d "$REPO_DIR" ]; then
    "$REPO_DIR/ainish-setup.sh"
    echo "✅ AINISH-Coder updated successfully"
  else
    echo "❌ Repository directory not found. Please set REPO_DIR environment variable."
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
  if [ -f "${AINISH_CODER_DIR}/vscode/.copilotignore" ]; then
    cp "${AINISH_CODER_DIR}/vscode/.copilotignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .copilotignore${RESET}"
  fi

  # Only copy .rooignore if it doesn't already exist in the target directory
  if [ -f "${AINISH_CODER_DIR}/vscode/.rooignore" ] && [ ! -f "$TARGET/.rooignore" ]; then
    cp "${AINISH_CODER_DIR}/vscode/.rooignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .rooignore${RESET}"
  elif [ -f "$TARGET/.rooignore" ]; then
    echo -e "${BLUE}✓ .rooignore already exists, skipping${RESET}"
  fi

  # Copy copilot-instructions.md to .github directory
  if [ -f "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" ]; then
    cp "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .github/copilot-instructions.md${RESET}"
  else
    # Check if it exists directly in the source
    if [ -f "${REPO_DIR}/ainish-copilot/.github/copilot-instructions.md" ]; then
      mkdir -p "$TARGET/.github" 2>/dev/null
      cp "${REPO_DIR}/ainish-copilot/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .github/copilot-instructions.md (from repo)${RESET}"
    else
      echo -e "${YELLOW}⚠️ Warning: copilot-instructions.md not found${RESET}"
    fi
  fi

  # Deploy shared critical.mdc
  if [ -f "${AINISH_CODER_DIR}/critical.mdc" ]; then
    cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/.github/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed critical.mdc to .github/${RESET}"
  fi

  echo -e "${BRIGHT_GREEN}✅ VS Code configurations deployed to $TARGET${RESET}"
}

# Function to deploy only Cursor configurations
deploy_cursor_configs() {
  local TARGET="$1"

  # Verify target is a directory
  if [ ! -d "$TARGET" ]; then
    echo -e "${BRIGHT_RED}Error: $TARGET is not a directory${RESET}"
    return 1
  fi

  echo -e "${BRIGHT_BLUE}Deploying Cursor configurations to $TARGET${RESET}"
  
  # Create necessary directories
  mkdir -p "$TARGET/.cursor/rules" 2>/dev/null
  
  # Deploy Cursor-specific configurations
  if [ -f "${AINISH_CODER_DIR}/cursor/.cursorignore" ]; then
    cp "${AINISH_CODER_DIR}/cursor/.cursorignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .cursorignore${RESET}"
  else
    # Create empty .cursorignore if it doesn't exist
    touch "$TARGET/.cursorignore" 2>/dev/null
    echo -e "${GREEN}✓ Created empty .cursorignore${RESET}"
  fi
  
  if [ -f "${AINISH_CODER_DIR}/cursor/.cursorindexingignore" ]; then
    cp "${AINISH_CODER_DIR}/cursor/.cursorindexingignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .cursorindexingignore${RESET}"
  else
    # Create empty .cursorindexingignore if it doesn't exist
    touch "$TARGET/.cursorindexingignore" 2>/dev/null
    echo -e "${GREEN}✓ Created empty .cursorindexingignore${RESET}"
  fi
  
  if [ -d "${AINISH_CODER_DIR}/cursor/.cursorrules" ]; then
    cp -r "${AINISH_CODER_DIR}/cursor/.cursorrules" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .cursorrules/${RESET}"
  fi
  
  if [ -f "${AINISH_CODER_DIR}/cursor/my-license.mdc" ]; then
    cp "${AINISH_CODER_DIR}/cursor/my-license.mdc" "$TARGET/.cursor/rules/license.mdc" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .cursor/rules/license.mdc${RESET}"
  fi

  # Deploy shared critical.mdc
  if [ -f "${AINISH_CODER_DIR}/critical.mdc" ]; then
    cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/.cursor/rules/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed critical.mdc to .cursor/rules/${RESET}"
  fi

  # Verify files were created
  if [ -f "$TARGET/.cursorignore" ]; then
    echo -e "${GREEN}✓ Verified .cursorignore exists${RESET}"
  else
    echo -e "${YELLOW}⚠️ Warning: Failed to create .cursorignore${RESET}"
  fi
  
  if [ -f "$TARGET/.cursorindexingignore" ]; then
    echo -e "${GREEN}✓ Verified .cursorindexingignore exists${RESET}"
  else
    echo -e "${YELLOW}⚠️ Warning: Failed to create .cursorindexingignore${RESET}"
  fi

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
  if [ -f "${AINISH_CODER_DIR}/aider/.aider-instructions.md" ]; then
    cp "${AINISH_CODER_DIR}/aider/.aider-instructions.md" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .aider-instructions.md${RESET}"
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

  # Deploy shared critical.mdc directly to target directory, not to .aider subfolder
  if [ -f "${AINISH_CODER_DIR}/critical.mdc" ]; then
    cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed critical.mdc to $TARGET${RESET}"
  fi

  echo -e "${BRIGHT_GREEN}✅ Aider configurations deployed to $TARGET${RESET}"
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
    # Print cyberpunk-style header
    echo -e "${BRIGHT_MAGENTA}╔══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BRIGHT_MAGENTA}║${RESET}               ${BRIGHT_CYAN}A I N I S H - C O D E R${RESET}                ${BRIGHT_MAGENTA}║${RESET}"
    echo -e "${BRIGHT_MAGENTA}╚══════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    
    # Regular setup
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