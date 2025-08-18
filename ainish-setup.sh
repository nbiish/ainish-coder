#!/usr/bin/env bash

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
#
# - update_prompt_md(): Updates prompt.md in all ainish-* directories
# - update_anishinaabe_cyberpunk_style(): Updates anishinaabe-cyberpunk-style.mdc in all ainish-* directories
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
# ./ainish-setup.sh update_anishinaabe_cyberpunk_style  # Update anishinaabe-cyberpunk-style.mdc in all ainish-* dirs
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

  

  # Create symlink for docs-use.mdc
  ln -sf "${REPO_DIR}/docs-use.mdc" "${AINISH_CODER_DIR}/docs-use.mdc" 2>/dev/null

  # Create symlink for PRD.mdc
  ln -sf "${REPO_DIR}/PRD.mdc" "${AINISH_CODER_DIR}/PRD.mdc" 2>/dev/null

  # Create symlink for modern-prompting.mdc
  ln -sf "${REPO_DIR}/modern-prompting.mdc" "${AINISH_CODER_DIR}/modern-prompting.mdc" 2>/dev/null
  # Create symlink for security.mdc
  ln -sf "${REPO_DIR}/security.mdc" "${AINISH_CODER_DIR}/security.mdc" 2>/dev/null

  # Create symlink for informing.mdc
  ln -sf "${REPO_DIR}/informing.mdc" "${AINISH_CODER_DIR}/informing.mdc" 2>/dev/null
  
  # Create symlink for non-cursor-prepend.md
  ln -sf "${REPO_DIR}/non-cursor-prepend.md" "${AINISH_CODER_DIR}/non-cursor-prepend.md" 2>/dev/null
  
  # Create symlink for mdc-headers.md
  ln -sf "${REPO_DIR}/mdc-headers.md" "${AINISH_CODER_DIR}/mdc-headers.md" 2>/dev/null
  
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

# Legacy function - no longer used with simplified mode system
prompt_for_ignore_files() {
  echo -e "${YELLOW}Warning: prompt_for_ignore_files() is deprecated. Files are now deployed based on mode automatically.${RESET}" >&2
  return 1
}

# Legacy function - no longer used with simplified mode system
prompt_include_style_rules() {
  echo -e "${YELLOW}Warning: prompt_include_style_rules() is deprecated. Style rules are now controlled by mode (1=style only, 4=everything).${RESET}" >&2
  return 1
}

# Legacy function - no longer used with simplified mode system
choose_deploy_mode() {
  echo -e "${YELLOW}Warning: choose_deploy_mode() is deprecated. Use simple mode parameters instead.${RESET}" >&2
  return 1
}

# Main deployment function
deploy_ainish_configs() {
  local TARGET="$1"
  local MODES="${2:-4}" # Default to everything if no mode specified
  
  # Simple mode interpretation
  local DEPLOY_STYLING=0
  local DEPLOY_IGNORE=0
  local DEPLOY_CRITICAL=0
  local DEPLOY_SECURITY=0
  local DEPLOY_PRD=0
  local DEPLOY_PROMPT=0
  local DEPLOY_DOCS=0
  local DEPLOY_INFORMING=0
  local DEPLOY_EVERYTHING=0

  for MODE in $MODES; do
    case "$MODE" in
      1) DEPLOY_STYLING=1 ;;
      2) DEPLOY_IGNORE=1 ;;
      3) DEPLOY_CRITICAL=1 ;;
      4) DEPLOY_SECURITY=1 ;;
      5) DEPLOY_PRD=1 ;;
      6) DEPLOY_PROMPT=1 ;;
      7) DEPLOY_DOCS=1 ;;
      8) DEPLOY_INFORMING=1 ;;
      9) DEPLOY_EVERYTHING=1; DEPLOY_STYLING=1; DEPLOY_IGNORE=1; DEPLOY_CRITICAL=1; DEPLOY_SECURITY=1; DEPLOY_PRD=1; DEPLOY_PROMPT=1; DEPLOY_DOCS=1; DEPLOY_INFORMING=1 ;;
      *) echo -e "${BRIGHT_RED}Error: Invalid mode $MODE in list '$MODES'${RESET}"; return 1 ;;
    esac
  done
  
  # Verify target is a directory
  if [ ! -d "$TARGET" ]; then
    echo -e "${BRIGHT_RED}Error: $TARGET is not a directory${RESET}"
    return 1
  fi
  
  echo -e "${BRIGHT_BLUE}Deploying AINISH configurations to $TARGET (modes $MODES)${RESET}"
  
  # Create necessary directories
  mkdir -p "$TARGET/.cursor/rules" 2>/dev/null
  mkdir -p "$TARGET/.github" 2>/dev/null
  
  # Deploy critical.mdc
  if [[ $DEPLOY_CRITICAL -eq 1 || $DEPLOY_EVERYTHING -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/critical.mdc" ]; then
      cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/.cursor/rules/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed critical.mdc to .cursor/rules/${RESET}"
      cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed critical.mdc to root${RESET}"
      if [ -d "$TARGET/.github" ]; then
        cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed critical.mdc to .github/${RESET}"
      fi
    fi
  fi
  
  # Deploy Cursor ignore files
  if [[ $DEPLOY_IGNORE -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/cursor/.cursorignore" ]; then
      cp "${AINISH_CODER_DIR}/cursor/.cursorignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .cursorignore${RESET}"
    fi
    
    if [ -f "${AINISH_CODER_DIR}/cursor/.cursorindexingignore" ]; then
      cp "${AINISH_CODER_DIR}/cursor/.cursorindexingignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .cursorindexingignore${RESET}"
    fi
  fi
  
  # Deploy .cursorrules and other files (only for 'everything' mode)
  if [[ $DEPLOY_EVERYTHING -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/cursor/.cursorrules" ]; then
      if [ -L "$TARGET/.cursorrules" ] || [ -f "$TARGET/.cursorrules" ]; then
        rm -f "$TARGET/.cursorrules"
      fi
      ln -sf "${AINISH_CODER_DIR}/cursor/.cursorrules" "$TARGET/.cursorrules" 2>/dev/null
      if [ -L "$TARGET/.cursorrules" ]; then
        echo -e "${GREEN}✓ Symlinked .cursorrules${RESET}"
      else
        cp "${AINISH_CODER_DIR}/cursor/.cursorrules" "$TARGET/.cursorrules" 2>/dev/null
        echo -e "${GREEN}✓ Copied .cursorrules${RESET}"
      fi
    fi
    
    if [ -f "${AINISH_CODER_DIR}/cursor/my-license.mdc" ]; then
      cp "${AINISH_CODER_DIR}/cursor/my-license.mdc" "$TARGET/.cursor/rules/license.mdc" 2>/dev/null
      echo -e "${GREEN}✓ Deployed license.mdc${RESET}"
    fi
  fi
    
  # Deploy style files
  if [[ $DEPLOY_STYLING -eq 1 ]]; then
    if [ -f "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" ]; then
      cp "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/.cursor/rules/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed style guide to .cursor/rules/${RESET}"
      cp "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed style guide to root${RESET}"
      if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed style guide to .github/${RESET}"
      fi
    fi
  fi
  
  # Deploy documentation files
  if [[ $DEPLOY_DOCS -eq 1 ]]; then
    if [ -f "${REPO_DIR}/docs-use.mdc" ]; then
      cp "${REPO_DIR}/docs-use.mdc" "$TARGET/.cursor/rules/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed docs-use.mdc to .cursor/rules/${RESET}"
      cp "${REPO_DIR}/docs-use.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed docs-use.mdc to root${RESET}"
      if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/docs-use.mdc" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed docs-use.mdc to .github/${RESET}"
      fi
    fi

  fi
  
  # Deploy informing files
  if [[ $DEPLOY_INFORMING -eq 1 ]]; then
    if [ -f "${REPO_DIR}/informing.mdc" ]; then
      cp "${REPO_DIR}/informing.mdc" "$TARGET/.cursor/rules/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed informing.mdc to .cursor/rules/${RESET}"
      cp "${REPO_DIR}/informing.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed informing.mdc to root${RESET}"
      if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/informing.mdc" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed informing.mdc to .github/${RESET}"
      fi
    fi
  fi
  
  # Deploy PRD files
  if [[ $DEPLOY_PRD -eq 1 ]]; then
    if [ -f "${REPO_DIR}/PRD.mdc" ]; then
      cp "${REPO_DIR}/PRD.mdc" "$TARGET/.cursor/rules/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed PRD.mdc to .cursor/rules/${RESET}"
      cp "${REPO_DIR}/PRD.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed PRD.mdc to root${RESET}"
      if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/PRD.mdc" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed PRD.mdc to .github/${RESET}"
      fi
    fi
  fi
  
  # Deploy mdc-headers.md (everything mode)
  if [[ $DEPLOY_EVERYTHING -eq 1 ]]; then
    if [ -f "${REPO_DIR}/mdc-headers.md" ]; then
      cp "${REPO_DIR}/mdc-headers.md" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed mdc-headers.md to root${RESET}"
      if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/mdc-headers.md" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed mdc-headers.md to .github/${RESET}"
      fi
    fi
  fi
  
  # Deploy Copilot ignore files
  if [[ $DEPLOY_IGNORE -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/vscode/.copilotignore" ]; then
      cp "${AINISH_CODER_DIR}/vscode/.copilotignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .copilotignore${RESET}"
    fi
    
    if [ -f "${AINISH_CODER_DIR}/vscode/.rooignore" ]; then
      cp "${AINISH_CODER_DIR}/vscode/.rooignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .rooignore${RESET}"
    fi
  fi
  
  # Deploy Copilot instructions (everything mode)
  if [[ $DEPLOY_EVERYTHING -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" ]; then
      mkdir -p "$TARGET/.github" 2>/dev/null
      cp "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed copilot-instructions.md${RESET}"
    fi
  fi

  # Deploy Aider configurations
  if [[ $DEPLOY_IGNORE -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/aider/.aiderignore" ]; then
      cp "${AINISH_CODER_DIR}/aider/.aiderignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .aiderignore${RESET}"
    fi
  fi
  
  if [[ $DEPLOY_EVERYTHING -eq 1 ]]; then
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
      chmod +x "$TARGET/aider-cli-commands.sh" 2>/dev/null
      echo -e "${GREEN}✓ Deployed aider-cli-commands.sh${RESET}"
    fi
  fi
  
  # Deploy prompt and security files
  if [[ $DEPLOY_PROMPT -eq 1 ]]; then
    # Deploy modern-prompting.mdc
    if [ -f "${REPO_DIR}/modern-prompting.mdc" ]; then
      cp "${REPO_DIR}/modern-prompting.mdc" "$TARGET/.cursor/rules/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed modern-prompting.mdc to .cursor/rules/${RESET}"
      cp "${REPO_DIR}/modern-prompting.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed modern-prompting.mdc to root${RESET}"
      if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/modern-prompting.mdc" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed modern-prompting.mdc to .github/${RESET}"
      fi
      # Deploy for Aider (prepend non-cursor content)
      prepend_non_cursor_content "${REPO_DIR}/modern-prompting.mdc" "$TARGET/.aider-instructions.md"
    fi
  fi
    
  if [[ $DEPLOY_SECURITY -eq 1 ]]; then
    # Deploy security.mdc  
    if [ -f "${REPO_DIR}/security.mdc" ]; then
      cp "${REPO_DIR}/security.mdc" "$TARGET/.cursor/rules/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed security.mdc to .cursor/rules/${RESET}"
      cp "${REPO_DIR}/security.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed security.mdc to root${RESET}"
      if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/security.mdc" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed security.mdc to .github/${RESET}"
      fi
    fi
  fi
    
  if [[ $DEPLOY_EVERYTHING -eq 1 ]]; then
    # Clean up legacy files
    rm -f "$TARGET/.cursor/rules/gikendaasowin.md" 2>/dev/null
    rm -f "$TARGET/.cursor/rules/cognitive-tool.md" 2>/dev/null
  fi
  
  # Deploy .gitignore
  if [[ $DEPLOY_EVERYTHING -eq 1 ]]; then
    if [ -f "${REPO_DIR}/.gitignore" ]; then
      cp "${REPO_DIR}/.gitignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .gitignore${RESET}"
    fi
    
    update_gitignore "$TARGET"
  fi
  
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

# Helper function to sanitize input (remove commas, normalize spaces)
__ainish_sanitize_mode() {
  local input="$1"
  # Remove carriage returns
  input=${input%$'\r'}
  # Replace commas with spaces and normalize all whitespace to single spaces
  input=$(echo "$input" | tr ',' ' ' | tr -s ' ')
  # Trim leading/trailing whitespace
  input=$(echo "$input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  echo "$input"
}

# Helper to read deploy mode (1-9). Honors AINISH_DEPLOY_MODE or --mode= flag.
__ainish_read_mode() {
  local CLI_ARG="${1:-}"
  local MODE="${AINISH_DEPLOY_MODE:-}"
  if [[ "$CLI_ARG" == --mode=* ]]; then MODE="${CLI_ARG#--mode=}"; fi
  
  # Sanitize mode if provided via argument or environment variable
  if [[ -n "$MODE" ]]; then
    MODE=$(__ainish_sanitize_mode "$MODE")
    # Validate mode if passed via argument, allows space separated numbers
    if [[ "$MODE" =~ ^[1-9]( [1-9])*$ ]]; then echo "$MODE"; return 0; fi
  fi

  echo -e "\\033[1;36mSelect deployment scope (space-separated or comma-separated numbers, e.g., 1 3 8 or 1,3,8):\\033[0m" >&2
  echo "1) Styling" >&2
  echo "2) Ignore files" >&2
  echo "3) Critical" >&2
  echo "4) Security" >&2
  echo "5) PRD" >&2
  echo "6) Prompting" >&2
  echo "7) Documentation" >&2
  echo "8) Informing" >&2
  echo "9) Everything" >&2
  printf "Enter numbers: " >&2
  read -r MODE
  
  # Sanitize input
  MODE=$(__ainish_sanitize_mode "$MODE")

  # Validate each number
  for num in ${=MODE}; do
    if [[ ! "$num" =~ ^[1-9]$ ]]; then
      echo "Invalid choice: '$num'. Please enter numbers from 1 to 9." >&2
      return 1
    fi
  done

  echo "$MODE"
}
function ainish-coder {
  # Capture current directory explicitly to handle external volumes
  local CURRENT_DIR="$(pwd)"
  local PROMPT_ARG=""
  local MODE_CLI_ARG=""
  for arg in "$@"; do
    case "$arg" in
      --prompt=*) PROMPT_ARG="$arg" ;;
      --mode=*) MODE_CLI_ARG="$arg" ;;
    esac
  done
  if [[ -n "$PROMPT_ARG" ]]; then export AINISH_PROMPT_MODE="${PROMPT_ARG#--prompt=}"; fi
  local MODE_VAL
  MODE_VAL="$(__ainish_read_mode "$MODE_CLI_ARG")" || return 1
  
  # Deploy from the linked repo directories to ensure latest changes are used
  AINISH_DEPLOY_MODE="$MODE_VAL" "$AINISH_CODER_DIR/ainish-setup.sh" deploy "$CURRENT_DIR" "$MODE_VAL"
  echo "✨ AINISH-Coder configurations deployed to current directory"
  echo "🔄 Using symlinks to repository - changes to repo files are immediately available"
}

function ainish-cursor {
  # Capture current directory explicitly to handle external volumes
  local CURRENT_DIR="$(pwd)"
  local PROMPT_ARG=""
  local MODE_CLI_ARG=""
  local NO_DEPLOY=0
  local PASSTHROUGH_ARGS=()
  for arg in "$@"; do
    case "$arg" in
      --prompt=*) PROMPT_ARG="$arg" ;;
      --mode=*) MODE_CLI_ARG="$arg" ;;
      --no-deploy) NO_DEPLOY=1 ;;
      *) PASSTHROUGH_ARGS+=("$arg") ;;
    esac
  done

  if [[ $NO_DEPLOY -eq 0 ]]; then
    if [[ -n "$PROMPT_ARG" ]]; then export AINISH_PROMPT_MODE="${PROMPT_ARG#--prompt=}"; fi
    local MODE_VAL
    MODE_VAL="$(__ainish_read_mode "$MODE_CLI_ARG")" || return 1
    
    # Deploy from the linked repo directories to ensure latest changes are used
    AINISH_DEPLOY_MODE="$MODE_VAL" "$AINISH_CODER_DIR/ainish-setup.sh" deploy_cursor_configs "$CURRENT_DIR" "$MODE_VAL"
    echo "🔄 Using symlinked configuration - changes to repo files are immediately available"
  else
    echo "Skipping deployment..."
  fi
  "$CURSOR_PATH" "${PASSTHROUGH_ARGS[@]}"
}

function ainish-aider {
  # Capture current directory explicitly to handle external volumes
  local CURRENT_DIR="$(pwd)"
  local PROMPT_ARG=""
  local MODE_CLI_ARG=""
  local NO_DEPLOY=0
  for arg in "$@"; do
    case "$arg" in
      --prompt=*) PROMPT_ARG="$arg" ;;
      --mode=*) MODE_CLI_ARG="$arg" ;;
      --no-deploy) NO_DEPLOY=1 ;;
    esac
  done

  if [[ $NO_DEPLOY -eq 0 ]]; then
    if [[ -n "$PROMPT_ARG" ]]; then export AINISH_PROMPT_MODE="${PROMPT_ARG#--prompt=}"; fi
    local MODE_VAL
    MODE_VAL="$(__ainish_read_mode "$MODE_CLI_ARG")" || return 1
    
    # Deploy from the linked repo directories to ensure latest changes are used
    AINISH_DEPLOY_MODE="$MODE_VAL" "$AINISH_CODER_DIR/ainish-setup.sh" deploy_aider_configs "$CURRENT_DIR" "$MODE_VAL"
    echo "🔄 Using symlinked configuration - changes to repo files are immediately available"
  else
    echo "Skipping deployment..."
  fi
}

function ainish-copilot {
  # Capture current directory explicitly to handle external volumes
  local CURRENT_DIR="$(pwd)"
  local PROMPT_ARG=""
  local MODE_CLI_ARG=""
  local NO_DEPLOY=0
  local PASSTHROUGH_ARGS=()
  for arg in "$@"; do
    case "$arg" in
      --prompt=*) PROMPT_ARG="$arg" ;;
      --mode=*) MODE_CLI_ARG="$arg" ;;
      --no-deploy) NO_DEPLOY=1 ;;
      *) PASSTHROUGH_ARGS+=("$arg") ;;
    esac
  done

  if [[ $NO_DEPLOY -eq 0 ]]; then
    if [[ -n "$PROMPT_ARG" ]]; then export AINISH_PROMPT_MODE="${PROMPT_ARG#--prompt=}"; fi
    local MODE_VAL
    MODE_VAL="$(__ainish_read_mode "$MODE_CLI_ARG")" || return 1
    
    # Deploy from the linked repo directories to ensure latest changes are used
    AINISH_DEPLOY_MODE="$MODE_VAL" "$AINISH_CODER_DIR/ainish-setup.sh" deploy_vscode_configs "$CURRENT_DIR" "$MODE_VAL"
    echo "🔄 Using symlinked configuration - changes to repo files are immediately available"
  else
    echo "Skipping deployment..."
  fi
  "$VSCODE_PATH" "${PASSTHROUGH_ARGS[@]}"
}

### END AINISH CODER WRAPPERS ###
EOF

  echo -e "${BRIGHT_GREEN}✅ Wrapper functions added to .zshrc${RESET}"
}

# Function to deploy only VS Code configurations
deploy_vscode_configs() {
  local TARGET="$1"
  local MODES="${2:-4}"
  local PROMPT_MODE="${AINISH_PROMPT_MODE:-}"
  
  # Simple mode interpretation
  local DEPLOY_STYLING=0
  local DEPLOY_IGNORE=0
  local DEPLOY_CRITICAL=0
  local DEPLOY_SECURITY=0
  local DEPLOY_PRD=0
  local DEPLOY_PROMPT=0
  local DEPLOY_DOCS=0
  local DEPLOY_INFORMING=0
  local DEPLOY_EVERYTHING=0

  for MODE in $MODES; do
    case "$MODE" in
      1) DEPLOY_STYLING=1 ;;
      2) DEPLOY_IGNORE=1 ;;
      3) DEPLOY_CRITICAL=1 ;;
      4) DEPLOY_SECURITY=1 ;;
      5) DEPLOY_PRD=1 ;;
      6) DEPLOY_PROMPT=1 ;;
      7) DEPLOY_DOCS=1 ;;
      8) DEPLOY_INFORMING=1 ;;
      9) DEPLOY_EVERYTHING=1; DEPLOY_STYLING=1; DEPLOY_IGNORE=1; DEPLOY_CRITICAL=1; DEPLOY_SECURITY=1; DEPLOY_PRD=1; DEPLOY_PROMPT=1; DEPLOY_DOCS=1; DEPLOY_INFORMING=1 ;;
      *) echo -e "${BRIGHT_RED}Error: Invalid mode $MODE in list '$MODES'${RESET}"; return 1 ;;
    esac
  done

  # Verify target is a directory
  if [ ! -d "$TARGET" ]; then
    echo -e "${BRIGHT_RED}Error: $TARGET is not a directory${RESET}"
    return 1
  fi

  echo -e "${BRIGHT_BLUE}Deploying VS Code configurations to $TARGET (modes $MODES)${RESET}"

  # Create necessary directories
  mkdir -p "$TARGET/.github" 2>/dev/null
  
  # Deploy ignore files
  if [[ $DEPLOY_IGNORE -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/vscode/.copilotignore" ]; then
      cp "${AINISH_CODER_DIR}/vscode/.copilotignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .copilotignore${RESET}"
    fi
    
    if [ -f "${AINISH_CODER_DIR}/vscode/.rooignore" ]; then
      cp "${AINISH_CODER_DIR}/vscode/.rooignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .rooignore${RESET}"
    fi
  fi

  # Deploy critical.mdc
  if [[ $DEPLOY_CRITICAL -eq 1 || $DEPLOY_EVERYTHING -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/critical.mdc" ]; then
      cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/.github/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed critical.mdc to .github/${RESET}"
    fi
  fi
    
  if [[ $DEPLOY_EVERYTHING -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" ]; then
      mkdir -p "$TARGET/.github" 2>/dev/null
      cp "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed copilot-instructions.md${RESET}"
    fi
  fi
  
  # Deploy style files
  if [[ $DEPLOY_STYLING -eq 1 ]]; then
    if [ -f "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" ]; then
      cp "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/.github/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed style guide to .github/${RESET}"
    fi
  fi

  # Deploy documentation files
  if [[ $DEPLOY_DOCS -eq 1 ]]; then
    if [ -f "${REPO_DIR}/docs-use.mdc" ]; then
      if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/docs-use.mdc" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed docs-use.mdc to .github/${RESET}"
      fi
    fi

  fi
  
  # Deploy informing files
  if [[ $DEPLOY_INFORMING -eq 1 ]]; then
    if [ -f "${REPO_DIR}/informing.mdc" ]; then
      if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/informing.mdc" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed informing.mdc to .github/${RESET}"
      fi
    fi
  fi
    
  # Deploy PRD files
  if [[ $DEPLOY_PRD -eq 1 ]]; then
    if [ -f "${REPO_DIR}/PRD.mdc" ]; then
      if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/PRD.mdc" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed PRD.mdc to .github/${RESET}"
      fi
    fi
  fi
  
  # Deploy mdc-headers.md (everything mode)
  if [[ $DEPLOY_EVERYTHING -eq 1 ]]; then
    if [ -f "${REPO_DIR}/mdc-headers.md" ]; then
      if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/mdc-headers.md" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed mdc-headers.md to .github/${RESET}"
      fi
    fi
  fi

  # Deploy prompt and security files
  if [[ $DEPLOY_PROMPT -eq 1 ]]; then
    # Deploy modern-prompting.mdc
    if [ -f "${REPO_DIR}/modern-prompting.mdc" ]; then
      if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/modern-prompting.mdc" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed modern-prompting.mdc to .github/${RESET}"
      fi
      # Deploy for Copilot (prepend non-cursor content)
      local copilot_target_file="$TARGET/.github/copilot-instructions.md"
      mkdir -p "$TARGET/.github" 2>/dev/null
      prepend_non_cursor_content "${REPO_DIR}/modern-prompting.mdc" "$copilot_target_file"
    fi
  fi
    
  # Deploy security.mdc
  if [[ $DEPLOY_SECURITY -eq 1 ]]; then
    if [ -f "${REPO_DIR}/security.mdc" ]; then
      if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/security.mdc" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed security.mdc to .github/${RESET}"
      fi
    fi
  fi

  if [[ $DEPLOY_EVERYTHING -eq 1 ]]; then
    if [ -f "${REPO_DIR}/.gitignore" ]; then
      cp "${REPO_DIR}/.gitignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .gitignore${RESET}"
    fi
    update_gitignore "$TARGET"
  fi
  
  echo -e "${BRIGHT_GREEN}✅ VS Code configurations deployed to $TARGET${RESET}"
}

# Function to deploy only Cursor configurations
deploy_cursor_configs() {
  local TARGET="$1"
  local MODES="${2:-4}"
  local PROMPT_MODE="${AINISH_PROMPT_MODE:-}"
  local SRC_CURSOR_DIR="${AINISH_CODER_DIR}/cursor"
  
  # Simple mode interpretation
  local DEPLOY_STYLING=0
  local DEPLOY_IGNORE=0
  local DEPLOY_CRITICAL=0
  local DEPLOY_SECURITY=0
  local DEPLOY_PRD=0
  local DEPLOY_PROMPT=0
  local DEPLOY_DOCS=0
  local DEPLOY_INFORMING=0
  local DEPLOY_EVERYTHING=0

  for MODE in $MODES; do
    case "$MODE" in
      1) DEPLOY_STYLING=1 ;;
      2) DEPLOY_IGNORE=1 ;;
      3) DEPLOY_CRITICAL=1 ;;
      4) DEPLOY_SECURITY=1 ;;
      5) DEPLOY_PRD=1 ;;
      6) DEPLOY_PROMPT=1 ;;
      7) DEPLOY_DOCS=1 ;;
      8) DEPLOY_INFORMING=1 ;;
      9) DEPLOY_EVERYTHING=1; DEPLOY_STYLING=1; DEPLOY_IGNORE=1; DEPLOY_CRITICAL=1; DEPLOY_SECURITY=1; DEPLOY_PRD=1; DEPLOY_PROMPT=1; DEPLOY_DOCS=1; DEPLOY_INFORMING=1 ;;
      *) echo -e "${BRIGHT_RED}Error: Invalid mode $MODE in list '$MODES'${RESET}"; return 1 ;;
    esac
  done

  # Verify target is a directory
  if [ ! -d "$TARGET" ]; then
    echo -e "${BRIGHT_RED}Error: $TARGET is not a directory${RESET}"
    return 1
  fi

  echo -e "${BRIGHT_BLUE}Deploying Cursor configurations to $TARGET (modes $MODES)${RESET}"

  # Create necessary directories
  mkdir -p "$TARGET/.cursor/rules" 2>/dev/null

  # ALWAYS deploy ignore files for ainish-cursor
  if [ -f "${SRC_CURSOR_DIR}/.cursorignore" ]; then
    cp "${SRC_CURSOR_DIR}/.cursorignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .cursorignore${RESET}"
  fi
  
  if [ -f "${SRC_CURSOR_DIR}/.cursorindexingignore" ]; then
    cp "${SRC_CURSOR_DIR}/.cursorindexingignore" "$TARGET/" 2>/dev/null
    echo -e "${GREEN}✓ Deployed .cursorindexingignore${RESET}"
  fi
  
  # Deploy .cursorrules and all rules (everything mode)
  if [[ $DEPLOY_EVERYTHING -eq 1 ]]; then
    if [ -f "${SRC_CURSOR_DIR}/.cursorrules" ]; then
      rm -f "$TARGET/.cursorrules" 2>/dev/null
      ln -sf "${SRC_CURSOR_DIR}/.cursorrules" "$TARGET/.cursorrules" 2>/dev/null
      if [ -L "$TARGET/.cursorrules" ]; then
        echo -e "${GREEN}✓ Symlinked .cursorrules${RESET}"
      else
        cp "${SRC_CURSOR_DIR}/.cursorrules" "$TARGET/.cursorrules" 2>/dev/null
        echo -e "${GREEN}✓ Copied .cursorrules${RESET}"
      fi
    fi
    
    # Copy all rules directory contents
    local SRC_RULES_DIR="${SRC_CURSOR_DIR}/.cursor/rules"
    local TARGET_RULES_DIR="$TARGET/.cursor/rules"
    if [ -d "$SRC_RULES_DIR" ]; then
      cp -R "${SRC_RULES_DIR}/." "$TARGET_RULES_DIR/" 2>/dev/null
      echo -e "${GREEN}✓ Copied all rules${RESET}"
    fi
  fi

  # Deploy core files individually to ensure they're updated
  local TARGET_RULES_DIR="$TARGET/.cursor/rules"
  
  # Deploy critical.mdc
  if [[ $DEPLOY_CRITICAL -eq 1 || $DEPLOY_EVERYTHING -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/critical.mdc" ]; then
      cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET_RULES_DIR/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed critical.mdc${RESET}"
    fi
  fi
    
  if [[ $DEPLOY_DOCS -eq 1 ]]; then
    if [ -f "${REPO_DIR}/docs-use.mdc" ]; then
      cp "${REPO_DIR}/docs-use.mdc" "$TARGET_RULES_DIR/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed docs-use.mdc${RESET}"
    fi

  fi
  
  # Deploy informing files
  if [[ $DEPLOY_INFORMING -eq 1 ]]; then
    if [ -f "${REPO_DIR}/informing.mdc" ]; then
      cp "${REPO_DIR}/informing.mdc" "$TARGET_RULES_DIR/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed informing.mdc${RESET}"
    fi
  fi
    
  if [[ $DEPLOY_PRD -eq 1 ]]; then
    if [ -f "${REPO_DIR}/PRD.mdc" ]; then
      cp "${REPO_DIR}/PRD.mdc" "$TARGET_RULES_DIR/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed PRD.mdc${RESET}"
    fi
  fi
    
  # Deploy prompt and security files
  if [[ $DEPLOY_PROMPT -eq 1 ]]; then
    if [ -f "${REPO_DIR}/modern-prompting.mdc" ]; then
      cp "${REPO_DIR}/modern-prompting.mdc" "$TARGET_RULES_DIR/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed modern-prompting.mdc${RESET}"
    fi
  fi
    
  if [[ $DEPLOY_SECURITY -eq 1 ]]; then
    if [ -f "${REPO_DIR}/security.mdc" ]; then
      cp "${REPO_DIR}/security.mdc" "$TARGET_RULES_DIR/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed security.mdc${RESET}"
    fi
  fi
    
  if [[ $DEPLOY_EVERYTHING -eq 1 ]]; then
    # Clean up legacy files
    rm -f "$TARGET_RULES_DIR/gikendaasowin.md" 2>/dev/null
    rm -f "$TARGET_RULES_DIR/cognitive-tool.md" 2>/dev/null
  fi

  # Deploy style files
  if [[ $DEPLOY_STYLING -eq 1 ]]; then
    if [ -f "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" ]; then
      cp "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET_RULES_DIR/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed style guide${RESET}"
    fi
  fi

  # Deploy additional files for everything mode
  if [[ $DEPLOY_EVERYTHING -eq 1 ]]; then
    if [ -f "${SRC_CURSOR_DIR}/my-license.mdc" ]; then
      cp "${SRC_CURSOR_DIR}/my-license.mdc" "$TARGET_RULES_DIR/license.mdc" 2>/dev/null
      echo -e "${GREEN}✓ Deployed license.mdc${RESET}"
    fi
  fi

  # Deploy .gitignore for everything mode
  if [[ $DEPLOY_EVERYTHING -eq 1 ]]; then
    if [ -f "${REPO_DIR}/.gitignore" ]; then
      cp "${REPO_DIR}/.gitignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .gitignore${RESET}"
    fi
    update_gitignore "$TARGET"
  fi

  echo -e "${BRIGHT_GREEN}✅ Cursor configurations deployed to $TARGET${RESET}"
}

# Function to deploy only Aider configurations
deploy_aider_configs() {
  local TARGET="$1"
  local MODES="${2:-4}"
  local PROMPT_MODE="${AINISH_PROMPT_MODE:-}"
  
  # Simple mode interpretation
  local DEPLOY_STYLING=0
  local DEPLOY_IGNORE=0
  local DEPLOY_CRITICAL=0
  local DEPLOY_SECURITY=0
  local DEPLOY_PRD=0
  local DEPLOY_PROMPT=0
  local DEPLOY_DOCS=0
  local DEPLOY_INFORMING=0
  local DEPLOY_EVERYTHING=0

  for MODE in $MODES; do
    case "$MODE" in
      1) DEPLOY_STYLING=1 ;;
      2) DEPLOY_IGNORE=1 ;;
      3) DEPLOY_CRITICAL=1 ;;
      4) DEPLOY_SECURITY=1 ;;
      5) DEPLOY_PRD=1 ;;
      6) DEPLOY_PROMPT=1 ;;
      7) DEPLOY_DOCS=1 ;;
      8) DEPLOY_INFORMING=1 ;;
      9) DEPLOY_EVERYTHING=1; DEPLOY_STYLING=1; DEPLOY_IGNORE=1; DEPLOY_CRITICAL=1; DEPLOY_SECURITY=1; DEPLOY_PRD=1; DEPLOY_PROMPT=1; DEPLOY_DOCS=1; DEPLOY_INFORMING=1 ;;
      *) echo -e "${BRIGHT_RED}Error: Invalid mode $MODE in list '$MODES'${RESET}"; return 1 ;;
    esac
  done

  # Verify target is a directory
  if [ ! -d "$TARGET" ]; then
    echo -e "${BRIGHT_RED}Error: $TARGET is not a directory${RESET}"
    return 1
  fi

  echo -e "${BRIGHT_BLUE}Deploying Aider configurations to $TARGET (modes $MODES)${RESET}"

  # Deploy critical.mdc
  if [[ $DEPLOY_CRITICAL -eq 1 || $DEPLOY_EVERYTHING -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/critical.mdc" ]; then
      cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed critical.mdc${RESET}"
    fi
  fi
  
  # Deploy core files
  if [[ $DEPLOY_PROMPT -eq 1 ]]; then
    # Deploy modern-prompting.mdc for Aider (prepend non-cursor content)
    if [ -f "${REPO_DIR}/modern-prompting.mdc" ]; then
      local aider_target_file="$TARGET/.aider-instructions.md"
      prepend_non_cursor_content "${REPO_DIR}/modern-prompting.mdc" "$aider_target_file"
      
      # Also deploy as regular file
      cp "${REPO_DIR}/modern-prompting.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed modern-prompting.mdc${RESET}"
    fi
  fi
    
  if [[ $DEPLOY_SECURITY -eq 1 ]]; then
    # Deploy security.mdc
    if [ -f "${REPO_DIR}/security.mdc" ]; then
      cp "${REPO_DIR}/security.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed security.mdc${RESET}"
    fi
  fi
    
  if [[ $DEPLOY_DOCS -eq 1 ]]; then
    # Deploy critical.mdc and docs-use.mdc
    if [ -f "${REPO_DIR}/docs-use.mdc" ]; then
      cp "${REPO_DIR}/docs-use.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed docs-use.mdc${RESET}"
    fi

  fi
  
  # Deploy informing files
  if [[ $DEPLOY_INFORMING -eq 1 ]]; then
    if [ -f "${REPO_DIR}/informing.mdc" ]; then
      cp "${REPO_DIR}/informing.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed informing.mdc${RESET}"
    fi
  fi
    
  if [[ $DEPLOY_PRD -eq 1 ]]; then
    if [ -f "${REPO_DIR}/PRD.mdc" ]; then
      cp "${REPO_DIR}/PRD.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed PRD.mdc${RESET}"
    fi
  fi
  
  # Deploy style files
  if [[ $DEPLOY_STYLING -eq 1 ]]; then
    if [ -f "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" ]; then
      cp "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed style guide${RESET}"
    fi
  fi
  
  # Deploy ignore files
  if [[ $DEPLOY_IGNORE -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/aider/.aiderignore" ]; then
      cp "${AINISH_CODER_DIR}/aider/.aiderignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .aiderignore${RESET}"
    fi
  fi
  
  # Deploy everything mode files
  if [[ $DEPLOY_EVERYTHING -eq 1 ]]; then
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
      chmod +x "$TARGET/aider-cli-commands.sh" 2>/dev/null
      echo -e "${GREEN}✓ Deployed aider-cli-commands.sh${RESET}"
    fi
    
    # Deploy mdc-headers.md for everything mode
    if [ -f "${REPO_DIR}/mdc-headers.md" ]; then
      cp "${REPO_DIR}/mdc-headers.md" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed mdc-headers.md${RESET}"
    fi
    
    # Deploy .gitignore 
    if [ -f "${REPO_DIR}/.gitignore" ]; then
      cp "${REPO_DIR}/.gitignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .gitignore${RESET}"
    fi

    update_gitignore "$TARGET"
  fi
  
  echo -e "${BRIGHT_GREEN}✅ Aider configurations deployed to $TARGET${RESET}"
}

# Function to append non-cursor content to prompt.md derived files
prepend_non_cursor_content() {
  local SOURCE="$1"
  local DEST="$2"
  local NON_CURSOR_PREPEND="${REPO_DIR}/non-cursor-prepend.md"
  local BASENAME
  BASENAME="$(basename "$SOURCE")"
  
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
  
  # Create combined file: non-cursor-prepend.md + separator + prompt
  { cat "$NON_CURSOR_PREPEND"; echo ""; echo "<!-- Source: $BASENAME -->"; echo ""; cat "$SOURCE"; } > "$DEST" 2>/dev/null
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
    deploy_ainish_configs "$2" "$3"
  elif [ "$1" == "deploy_vscode_configs" ]; then
    # Deploy VS Code configurations to the specified directory
    deploy_vscode_configs "$2" "$3"
  elif [ "$1" == "deploy_cursor_configs" ]; then
    # Deploy Cursor configurations to the specified directory
    deploy_cursor_configs "$2" "$3"
  elif [ "$1" == "deploy_aider_configs" ]; then
    # Deploy Aider configurations to the specified directory
    deploy_aider_configs "$2" "$3"
  elif [ "$1" == "update_anishinaabe_cyberpunk_style" ]; then
    # Update anishinaabe-cyberpunk-style.mdc in all ainish-* directories
    local style_src="${REPO_DIR}/anishinaabe-cyberpunk-style.mdc"
    if [ -f "$style_src" ]; then
      # Define destination directories
      local aider_dir="${REPO_DIR}/ainish-aider"
      local copilot_github_dir="${REPO_DIR}/ainish-copilot/.github"
      local cursor_rules_dir="${REPO_DIR}/ainish-cursor/.cursor/rules"
      local root_cursor_rules_dir="${REPO_DIR}/.cursor/rules"

      # Ensure directories exist
      mkdir -p "$aider_dir" 2>/dev/null
      mkdir -p "$copilot_github_dir" 2>/dev/null
      mkdir -p "$cursor_rules_dir" 2>/dev/null
      mkdir -p "$root_cursor_rules_dir" 2>/dev/null

      # Copy file to all destinations
      cp "$style_src" "$aider_dir/" 2>/dev/null && \
        echo -e "${GREEN}✓ Updated anishinaabe-cyberpunk-style.mdc in ainish-aider/${RESET}" || \
        echo -e "${YELLOW}⚠️ Failed to update anishinaabe-cyberpunk-style.mdc in ainish-aider/${RESET}"
      
      cp "$style_src" "$copilot_github_dir/" 2>/dev/null && \
        echo -e "${GREEN}✓ Updated anishinaabe-cyberpunk-style.mdc in ainish-copilot/.github/${RESET}" || \
        echo -e "${YELLOW}⚠️ Failed to update anishinaabe-cyberpunk-style.mdc in ainish-copilot/.github/${RESET}"
      
      cp "$style_src" "$cursor_rules_dir/" 2>/dev/null && \
        echo -e "${GREEN}✓ Updated anishinaabe-cyberpunk-style.mdc in ainish-cursor/.cursor/rules/${RESET}" || \
        echo -e "${YELLOW}⚠️ Failed to update anishinaabe-cyberpunk-style.mdc in ainish-cursor/.cursor/rules/${RESET}"
      
      cp "$style_src" "$root_cursor_rules_dir/" 2>/dev/null && \
        echo -e "${GREEN}✓ Updated anishinaabe-cyberpunk-style.mdc in .cursor/rules/${RESET}" || \
        echo -e "${YELLOW}⚠️ Failed to update anishinaabe-cyberpunk-style.mdc in .cursor/rules/${RESET}"
      
      echo -e "${BRIGHT_GREEN}✅ anishinaabe-cyberpunk-style.mdc updated in all directories${RESET}"
    else
      echo -e "${RED}Error: anishinaabe-cyberpunk-style.mdc not found at $style_src${RESET}"
      exit 1
    fi
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
    local modern_prompting_src="${REPO_DIR}/modern-prompting.mdc"
    local security_src="${REPO_DIR}/security.mdc"
    # Define docs-use.mdc source
    local docs_src="${REPO_DIR}/docs-use.mdc"
    # Define PRD.mdc source
    local prd_src="${REPO_DIR}/PRD.mdc"
    # Define informing.mdc source
    local informing_src="${REPO_DIR}/informing.mdc"
    
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

    
    # Copy docs-use.mdc
    if [ -f "$docs_src" ]; then
      cp "$docs_src" "$aider_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied docs-use.mdc to ainish-aider/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy docs-use.mdc to ainish-aider/${RESET}"
      cp "$docs_src" "$copilot_github_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied docs-use.mdc to ainish-copilot/.github/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy docs-use.mdc to ainish-copilot/.github/${RESET}"
      cp "$docs_src" "$cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied docs-use.mdc to ainish-cursor/.cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy docs-use.mdc to ainish-cursor/.cursor/rules/${RESET}"
      cp "$docs_src" "$root_cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied docs-use.mdc to .cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy docs-use.mdc to .cursor/rules/${RESET}"
    else
      echo -e "${YELLOW}⚠️ Warning: Source docs-use.mdc not found at $docs_src${RESET}"
    fi
    
    # Copy PRD.mdc
    if [ -f "$prd_src" ]; then
      cp "$prd_src" "$aider_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied PRD.mdc to ainish-aider/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy PRD.mdc to ainish-aider/${RESET}"
      cp "$prd_src" "$copilot_github_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied PRD.mdc to ainish-copilot/.github/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy PRD.mdc to ainish-copilot/.github/${RESET}"
      cp "$prd_src" "$cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied PRD.mdc to ainish-cursor/.cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy PRD.mdc to ainish-cursor/.cursor/rules/${RESET}"
      cp "$prd_src" "$root_cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied PRD.mdc to .cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy PRD.mdc to .cursor/rules/${RESET}"
    else
      echo -e "${YELLOW}⚠️ Warning: Source PRD.mdc not found at $prd_src${RESET}"
    fi
    
    # Copy informing.mdc
    if [ -f "$informing_src" ]; then
      cp "$informing_src" "$aider_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied informing.mdc to ainish-aider/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy informing.mdc to ainish-aider/${RESET}"
      cp "$informing_src" "$copilot_github_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied informing.mdc to ainish-copilot/.github/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy informing.mdc to ainish-copilot/.github/${RESET}"
      cp "$informing_src" "$cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied informing.mdc to ainish-cursor/.cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy informing.mdc to ainish-cursor/.cursor/rules/${RESET}"
      cp "$informing_src" "$root_cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied informing.mdc to .cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy informing.mdc to .cursor/rules/${RESET}"
    else
      echo -e "${YELLOW}⚠️ Warning: Source informing.mdc not found at $informing_src${RESET}"
    fi
    
    # Copy modern-prompting.mdc and security.mdc to specific destinations
    if [ -f "$modern_prompting_src" ]; then
      # Copy modern-prompting.mdc to all destination directories
      cp "$modern_prompting_src" "$aider_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied modern-prompting.mdc to ainish-aider/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy modern-prompting.mdc to ainish-aider/${RESET}"
      cp "$modern_prompting_src" "$copilot_github_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied modern-prompting.mdc to ainish-copilot/.github/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy modern-prompting.mdc to ainish-copilot/.github/${RESET}"
      cp "$modern_prompting_src" "$cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied modern-prompting.mdc to ainish-cursor/.cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy modern-prompting.mdc to ainish-cursor/.cursor/rules/${RESET}"
      cp "$modern_prompting_src" "$root_cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied modern-prompting.mdc to .cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy modern-prompting.mdc to .cursor/rules/${RESET}"
      
      # Create .aider-instructions.md (prepend non-cursor content)
      local aider_target="${aider_dest_dir}/.aider-instructions.md"
      prepend_non_cursor_content "$modern_prompting_src" "$aider_target"
      
      # Create copilot-instructions.md (prepend non-cursor content)
      local copilot_target="${copilot_github_dest_dir}/copilot-instructions.md"
      prepend_non_cursor_content "$modern_prompting_src" "$copilot_target"
    else
      echo -e "${YELLOW}⚠️ Warning: Source modern-prompting.mdc not found at $modern_prompting_src${RESET}"
    fi
    
    if [ -f "$security_src" ]; then
      # Copy security.mdc to all destination directories
      cp "$security_src" "$aider_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied security.mdc to ainish-aider/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy security.mdc to ainish-aider/${RESET}"
      cp "$security_src" "$copilot_github_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied security.mdc to ainish-copilot/.github/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy security.mdc to ainish-copilot/.github/${RESET}"
      cp "$security_src" "$cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied security.mdc to ainish-cursor/.cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy security.mdc to ainish-cursor/.cursor/rules/${RESET}"
      cp "$security_src" "$root_cursor_rules_dest_dir/" 2>/dev/null && echo -e "${GREEN}✓ Copied security.mdc to .cursor/rules/${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy security.mdc to .cursor/rules/${RESET}"
    else
      echo -e "${YELLOW}⚠️ Warning: Source security.mdc not found at $security_src${RESET}"
    fi
    
    # Cleanup legacy files
    rm -f "${cursor_rules_dest_dir}/gikendaasowin.md" 2>/dev/null
    rm -f "${cursor_rules_dest_dir}/cognitive-tool.md" 2>/dev/null
    rm -f "${root_cursor_rules_dest_dir}/gikendaasowin.md" 2>/dev/null
    rm -f "${root_cursor_rules_dest_dir}/cognitive-tool.md" 2>/dev/null
    
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