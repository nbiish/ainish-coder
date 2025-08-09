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

  # Create symlink for prompt.md
  ln -sf "${REPO_DIR}/prompt.md" "${AINISH_CODER_DIR}/prompt.md" 2>/dev/null
  # Create symlink for security-meta-prompt.md
  if [ -f "${REPO_DIR}/security-meta-prompt.md" ]; then
    ln -sf "${REPO_DIR}/security-meta-prompt.md" "${AINISH_CODER_DIR}/security-meta-prompt.md" 2>/dev/null
  fi
  
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

# Helper function to prompt for ignore files
prompt_for_ignore_files() {
  local TARGET="$1"
  local TOOL="$2"
  local FILE="$3"
  local DESC="$4"
  local RESPONSE=""
  local MODE="${AINISH_DEPLOY_MODE:-}"

  # Skip if file already exists in target
  if [ -f "$TARGET/$FILE" ]; then
    echo -e "${BLUE}✓ $FILE already exists in target directory, skipping${RESET}"
    return 1
  fi

  # If a global deploy mode (1-4) is set, decide non-interactively
  if [[ "$MODE" =~ ^[1-4]$ ]]; then
    case "$MODE" in
      2|4)
        return 0
        ;;
      1|3)
        return 1
        ;;
    esac
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

# Prompt once per command whether to include styling rules
prompt_include_style_rules() {
  local RESPONSE=""
  local MODE="${AINISH_DEPLOY_MODE:-}"

  # If a global deploy mode (1-4) is set, decide non-interactively
  if [[ "$MODE" =~ ^[1-4]$ ]]; then
    case "$MODE" in
      1|4)
        return 0
        ;;
      2|3)
        return 1
        ;;
    esac
  fi
  echo -e "${BRIGHT_CYAN}Include styling rules (anishinaabe-cyberpunk-style.mdc)?${RESET}"
  echo -e "${CYAN}These provide the Anishinaabe cyberpunk style guidance for AI tools.${RESET}"
  echo -e "${BRIGHT_CYAN}[Y/n]:${RESET} "
  read -r RESPONSE
  if [[ -z "$RESPONSE" ]] || [[ "$RESPONSE" =~ ^[Yy] ]]; then
    return 0
  fi
  return 1
}

# Helper: ask once for deployment scope (1-4) if not already set
choose_deploy_mode() {
  if [[ "${AINISH_DEPLOY_MODE:-}" =~ ^[1-4]$ ]]; then
    return 0
  fi
  echo -e "${BRIGHT_CYAN}Select deployment scope:${RESET}" >&2
  echo "1) Styling only" >&2
  echo "2) Ignore files only" >&2
  echo "3) Critical + Docs-use + Prompt" >&2
  echo "4) Everything" >&2
  read -r -p "Enter [1-4]: " _mode_choice
  # Sanitize input by removing potential carriage return
  _mode_choice=${_mode_choice%$'\\r'}
  if [[ "$_mode_choice" =~ ^[1-4]$ ]]; then
    export AINISH_DEPLOY_MODE="$_mode_choice"
    return 0
  fi
  echo -e "${YELLOW}Invalid choice. Aborting.${RESET}" >&2
  return 1
}

# Main deployment function
deploy_ainish_configs() {
  local TARGET="$1"
  local INCLUDE_STYLE_RULES=0
  local MODE="${AINISH_DEPLOY_MODE:-}"
  # Ask once for mode if not already set
  if [[ -z "$MODE" ]]; then
    if ! choose_deploy_mode; then
      echo -e "${BRIGHT_RED}Aborting due to invalid mode selection.${RESET}"
      return 1
    fi
    MODE="${AINISH_DEPLOY_MODE}"
  fi
  # Interpret mode flags
  local MODE_STYLE_ONLY=0
  local MODE_IGNORE_ONLY=0
  local MODE_CORE_ONLY=0
  local MODE_ALL=0
  case "$MODE" in
    1) MODE_STYLE_ONLY=1 ; INCLUDE_STYLE_RULES=1 ;;
    2) MODE_IGNORE_ONLY=1 ;;
    3) MODE_CORE_ONLY=1 ;;
    4) MODE_ALL=1 ; INCLUDE_STYLE_RULES=1 ;;
    *) ;;
  esac
  if [[ $INCLUDE_STYLE_RULES -eq 0 && ! "$MODE" =~ ^[1-4]$ ]]; then
    if prompt_include_style_rules; then
      INCLUDE_STYLE_RULES=1
    fi
  fi
  
  # Verify target is a directory
  if [ ! -d "$TARGET" ]; then
    echo -e "${BRIGHT_RED}Error: $TARGET is not a directory${RESET}"
    return 1
  fi
  
  echo -e "${BRIGHT_BLUE}Deploying AINISH configurations to $TARGET${RESET}"
  
  # Create necessary directories
  mkdir -p "$TARGET/.cursor/rules" 2>/dev/null
  mkdir -p "$TARGET/.github" 2>/dev/null
  
  # Deploy Cursor configurations (ignore files only when mode specifies)
  if [[ $MODE_IGNORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
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
  fi
  
  if [[ $MODE_IGNORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
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
  fi
  
  # Deploy .cursorrules as a symlink if possible, otherwise copy
  if [[ $MODE_ALL -eq 1 ]]; then
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
  fi
  
  if [[ $MODE_ALL -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/cursor/my-license.mdc" ]; then
      cp "${AINISH_CODER_DIR}/cursor/my-license.mdc" "$TARGET/.cursor/rules/license.mdc" 2>/dev/null
      echo -e "${GREEN}✓ Deployed Cursor-specific license.mdc${RESET}"
    fi
  fi
  
  # Deploy shared critical.mdc
  if [[ $MODE_CORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
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
  fi
  
  # Deploy shared anishinaabe-cyberpunk-style.mdc (conditional)
  if [ $INCLUDE_STYLE_RULES -eq 1 ]; then
    if [ -f "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" ]; then
      cp "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/.cursor/rules/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed anishinaabe-cyberpunk-style.mdc to .cursor/rules/${RESET}"
      
      # Also deploy to aider and copilot locations
      cp "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/" 2>/dev/null # For Aider
      echo -e "${GREEN}✓ Deployed anishinaabe-cyberpunk-style.mdc to $TARGET (for Aider)${RESET}"
      if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed anishinaabe-cyberpunk-style.mdc to .github/ (for Copilot)${RESET}"
      fi
    elif [ -f "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" ]; then
      cp "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/.cursor/rules/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed anishinaabe-cyberpunk-style.mdc to .cursor/rules/${RESET}"
      
      # Also deploy to aider and copilot locations
      cp "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/" 2>/dev/null # For Aider
      echo -e "${GREEN}✓ Deployed anishinaabe-cyberpunk-style.mdc to $TARGET (for Aider)${RESET}"
      if [ -d "$TARGET/.github" ]; then
        cp "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed anishinaabe-cyberpunk-style.mdc to .github/ (for Copilot)${RESET}"
      fi
    else
      echo -e "${YELLOW}⚠️ Warning: anishinaabe-cyberpunk-style.mdc not found${RESET}"
    fi
  else
    echo -e "${BLUE}↪ Skipped styling rules by user choice${RESET}"
  fi
  
  
  
  # Deploy shared docs-use.mdc (core modes)
  if [[ $MODE_CORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
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
  fi
  
  # Deploy mdc-headers.md (but not to Cursor)
  if [ -f "${REPO_DIR}/mdc-headers.md" ]; then # Use REPO_DIR for root files
      # Skip deploying to .cursor/rules/ as requested
      # cp "${REPO_DIR}/mdc-headers.md" "$TARGET/.cursor/rules/" 2>/dev/null
      # echo -e "${GREEN}✓ Deployed mdc-headers.md to .cursor/rules/${RESET}"

      cp "${REPO_DIR}/mdc-headers.md" "$TARGET/" 2>/dev/null # For Aider
      echo -e "${GREEN}✓ Deployed mdc-headers.md to $TARGET (for Aider)${RESET}"
      if [ -d "$TARGET/.github" ]; then
          cp "${REPO_DIR}/mdc-headers.md" "$TARGET/.github/" 2>/dev/null
          echo -e "${GREEN}✓ Deployed mdc-headers.md to .github/ (for Copilot)${RESET}"
      fi
  fi
  
  # Deploy Copilot configurations (ignore files)
  if [[ $MODE_IGNORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    if prompt_for_ignore_files "$TARGET" "Copilot" ".copilotignore" "Controls which files GitHub Copilot will ignore during code suggestions."; then
      if [ -f "${AINISH_CODER_DIR}/vscode/.copilotignore" ]; then
        cp "${AINISH_CODER_DIR}/vscode/.copilotignore" "$TARGET/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed .copilotignore${RESET}"
      fi
    fi
  fi
  
  # Only copy .rooignore if user wants it
  if [[ $MODE_IGNORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    if prompt_for_ignore_files "$TARGET" "Copilot" ".rooignore" "Controls which files are excluded from Copilot's context window."; then
      if [ -f "${AINISH_CODER_DIR}/vscode/.rooignore" ]; then
        cp "${AINISH_CODER_DIR}/vscode/.rooignore" "$TARGET/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed .rooignore${RESET}"
      fi
    fi
  fi
  
  # Deploy custom copilot instructions from ainish-copilot
  if [[ $MODE_ALL -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" ]; then
      mkdir -p "$TARGET/.github" 2>/dev/null
      cp "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed custom copilot-instructions.md from ainish-copilot${RESET}"
    fi
  fi

  # Deploy Aider configurations (.aiderignore is an ignore file; others only in mode 4)
  if [[ $MODE_IGNORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    if prompt_for_ignore_files "$TARGET" "Aider" ".aiderignore" "Controls which files Aider will ignore during code generation and edits."; then
      if [ -f "${AINISH_CODER_DIR}/aider/.aiderignore" ]; then
        cp "${AINISH_CODER_DIR}/aider/.aiderignore" "$TARGET/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed .aiderignore${RESET}"
      fi
    fi
  fi
  
  if [[ $MODE_ALL -eq 1 ]]; then
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
  fi
  
  # Deploy prompt.md from root to destinations with special names (core modes)
  if [[ $MODE_CORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    if [ -f "${REPO_DIR}/prompt.md" ]; then
      # Respect AINISH_PROMPT_MODE for initial distribution
      local prompt_source="${REPO_DIR}/prompt.md"
      if [ "${AINISH_PROMPT_MODE:-}" = "security" ] && [ -f "${REPO_DIR}/security-meta-prompt.md" ]; then
        prompt_source="${REPO_DIR}/security-meta-prompt.md"
      fi
      # Deploy for Copilot
      if [ -d "$TARGET/.github" ]; then
        prepend_non_cursor_content "$prompt_source" "$TARGET/.github/copilot-instructions.md"
      fi
      # Deploy for Aider
      prepend_non_cursor_content "$prompt_source" "$TARGET/.aider-instructions.md"
      # Deploy for Cursor (without non-cursor content)
      if [ -d "$TARGET/.cursor/rules" ]; then
          cp "$prompt_source" "$TARGET/.cursor/rules/cognitive-tool.md" 2>/dev/null
          # Cleanup old name if present
          rm -f "$TARGET/.cursor/rules/gikendaasowin.md" 2>/dev/null
          echo -e "${GREEN}✓ Deployed prompt (initial) to .cursor/rules/cognitive-tool.md${RESET}"
      fi
    fi
  fi
  
  # Deploy .gitignore and update (everything mode only)
  if [[ $MODE_ALL -eq 1 ]]; then
    if [ -f "${REPO_DIR}/.gitignore" ]; then
        cp "${REPO_DIR}/.gitignore" "$TARGET/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed root .gitignore to $TARGET${RESET}"
    fi
    
    # Update .gitignore (append tool-specific ignores)
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

# Helper to read deploy mode (1-4). Honors AINISH_DEPLOY_MODE or --mode= flag.
__ainish_read_mode() {
  local CLI_ARG="${1:-}"
  local MODE="${AINISH_DEPLOY_MODE:-}"
  if [[ "$CLI_ARG" == --mode=* ]]; then MODE="${CLI_ARG#--mode=}"; fi
  if [[ "$MODE" =~ ^[1-4]$ ]]; then echo "$MODE"; return 0; fi
  echo -e "\\033[1;36mSelect deployment scope:\\033[0m" >&2
  echo "1) Styling only" >&2
  echo "2) Ignore files only" >&2
  echo "3) Critical + Docs-use + Prompt" >&2
  echo "4) Everything" >&2
  read -r -p "Enter [1-4]: " MODE
  # Sanitize input by removing potential carriage return
  MODE=${MODE%$'\\r'}
  if [[ ! "$MODE" =~ ^[1-4]$ ]]; then echo "Invalid choice" >&2; return 1; fi
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
  AINISH_DEPLOY_MODE="$MODE_VAL" "$AINISH_CODER_DIR/ainish-setup.sh" deploy "$CURRENT_DIR"
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
    AINISH_DEPLOY_MODE="$MODE_VAL" "$AINISH_CODER_DIR/ainish-setup.sh" deploy_cursor_configs "$CURRENT_DIR"
    echo "🔄 Using symlinked configuration - changes to repo files are immediately available"
  else
    echo "Skipping deployment..."
  fi
  env NODE_OPTIONS="${NODE_OPTIONS:+$NODE_OPTIONS }--force-node-api-uncaught-exceptions-policy=true" "$CURSOR_PATH" "${PASSTHROUGH_ARGS[@]}"
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
    AINISH_DEPLOY_MODE="$MODE_VAL" "$AINISH_CODER_DIR/ainish-setup.sh" deploy_aider_configs "$CURRENT_DIR"
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
    AINISH_DEPLOY_MODE="$MODE_VAL" "$AINISH_CODER_DIR/ainish-setup.sh" deploy_vscode_configs "$CURRENT_DIR"
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
  local PROMPT_MODE="${AINISH_PROMPT_MODE:-}"
  local INCLUDE_STYLE_RULES=0
  local MODE="${AINISH_DEPLOY_MODE:-}"
  # Ask once for mode if not already set
  if [[ -z "$MODE" ]]; then
    if ! choose_deploy_mode; then
      echo -e "${BRIGHT_RED}Aborting due to invalid mode selection.${RESET}"
      return 1
    fi
    MODE="${AINISH_DEPLOY_MODE}"
  fi
  # Interpret mode flags
  local MODE_STYLE_ONLY=0
  local MODE_IGNORE_ONLY=0
  local MODE_CORE_ONLY=0
  local MODE_ALL=0
  case "$MODE" in
    1) MODE_STYLE_ONLY=1 ; INCLUDE_STYLE_RULES=1 ;;
    2) MODE_IGNORE_ONLY=1 ;;
    3) MODE_CORE_ONLY=1 ;;
    4) MODE_ALL=1 ; INCLUDE_STYLE_RULES=1 ;;
    *) ;; # fall through
  esac
  if [[ $INCLUDE_STYLE_RULES -eq 0 && ! "$MODE" =~ ^[1-4]$ ]]; then
    if prompt_include_style_rules; then
      INCLUDE_STYLE_RULES=1
    fi
  fi

  # Verify target is a directory
  if [ ! -d "$TARGET" ]; then
    echo -e "${BRIGHT_RED}Error: $TARGET is not a directory${RESET}"
    return 1
  fi

  echo -e "${BRIGHT_BLUE}Deploying VS Code configurations to $TARGET${RESET}"

  # Create necessary directories
  mkdir -p "$TARGET/.github" 2>/dev/null
  
  # Deploy VS Code-specific configurations
  if [[ $MODE_IGNORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    if prompt_for_ignore_files "$TARGET" "Copilot" ".copilotignore" "Controls which files GitHub Copilot will ignore during code suggestions."; then
      if [ -f "${AINISH_CODER_DIR}/vscode/.copilotignore" ]; then
        cp "${AINISH_CODER_DIR}/vscode/.copilotignore" "$TARGET/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed .copilotignore${RESET}"
      fi
    fi
  fi

  # Only copy .rooignore if user wants it
  if [[ $MODE_IGNORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    if prompt_for_ignore_files "$TARGET" "Copilot" ".rooignore" "Controls which files are excluded from Copilot's context window."; then
      if [ -f "${AINISH_CODER_DIR}/vscode/.rooignore" ]; then
        cp "${AINISH_CODER_DIR}/vscode/.rooignore" "$TARGET/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed .rooignore${RESET}"
      fi
    fi
  fi

  # Deploy custom copilot instructions from ainish-copilot
  if [[ $MODE_CORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" ]; then
      mkdir -p "$TARGET/.github" 2>/dev/null
      cp "${AINISH_CODER_DIR}/vscode/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed custom copilot-instructions.md from ainish-copilot${RESET}"
    fi
  fi

  # Deploy shared critical.mdc
  if [[ $MODE_CORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/critical.mdc" ]; then
      cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/.github/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed critical.mdc to .github/${RESET}"
    fi
  fi
  
  # Deploy anishinaabe-cyberpunk-style.mdc (conditional)
  if [ $INCLUDE_STYLE_RULES -eq 1 ]; then
    if [ -f "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" ]; then
      cp "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/.github/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed anishinaabe-cyberpunk-style.mdc to .github/${RESET}"
    elif [ -f "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" ]; then
      cp "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/.github/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed anishinaabe-cyberpunk-style.mdc to .github/${RESET}"
    else
      echo -e "${YELLOW}⚠️ Warning: anishinaabe-cyberpunk-style.mdc not found${RESET}"
    fi
  else
    echo -e "${BLUE}↪ Skipped styling rules by user choice${RESET}"
  fi

  

  # Deploy shared docs-use.mdc
  if [[ $MODE_CORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    if [ -f "${REPO_DIR}/docs-use.mdc" ]; then # Use REPO_DIR for root files
      if [ -d "$TARGET/.github" ]; then
          cp "${REPO_DIR}/docs-use.mdc" "$TARGET/.github/" 2>/dev/null
          echo -e "${GREEN}✓ Deployed docs-use.mdc to .github/${RESET}"
      fi
    fi
  fi
  
  # Deploy mdc-headers.md
  if [ -f "${REPO_DIR}/mdc-headers.md" ]; then # Use REPO_DIR for root files
    if [ -d "$TARGET/.github" ]; then
        cp "${REPO_DIR}/mdc-headers.md" "$TARGET/.github/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed mdc-headers.md to .github/${RESET}"
    fi
  fi

  # Deploy prompt as copilot-instructions.md (source depends on PROMPT_MODE)
  if [[ $MODE_CORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    local prompt_source="${REPO_DIR}/prompt.md"
    if [ "$PROMPT_MODE" = "security" ]; then
      prompt_source="${REPO_DIR}/security-meta-prompt.md"
    elif [ "$PROMPT_MODE" = "none" ]; then
      prompt_source=""
    fi
    local copilot_target_dir="$TARGET/.github"
    local copilot_target_file="$copilot_target_dir/copilot-instructions.md"
    if [ -n "$prompt_source" ]; then
      if [ -f "$prompt_source" ]; then
          mkdir -p "$copilot_target_dir" 2>/dev/null
          prepend_non_cursor_content "$prompt_source" "$copilot_target_file"
      else
          echo -e "${YELLOW}⚠️ Warning: Prompt source not found at $prompt_source${RESET}"
      fi
    else
      # none: remove if exists
      rm -f "$copilot_target_file" 2>/dev/null
      echo -e "${BLUE}↪ Skipped deploying Copilot prompt (mode=none)${RESET}"
    fi
  fi

  if [[ $MODE_ALL -eq 1 ]]; then
    if [ -f "${REPO_DIR}/.gitignore" ]; then
        cp "${REPO_DIR}/.gitignore" "$TARGET/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed root .gitignore to $TARGET${RESET}"
    fi
    update_gitignore "$TARGET"
  fi
  
  echo -e "${BRIGHT_GREEN}✅ VS Code configurations deployed to $TARGET${RESET}"
}

# Function to deploy only Cursor configurations
deploy_cursor_configs() {
  local TARGET="$1"
  local PROMPT_MODE="${AINISH_PROMPT_MODE:-}"
  local SRC_CURSOR_DIR="${AINISH_CODER_DIR}/cursor" # Points to REPO_DIR/ainish-cursor via symlink
  local INCLUDE_STYLE_RULES=0
  local MODE="${AINISH_DEPLOY_MODE:-}"
  # Ask once for mode if not already set
  if [[ -z "$MODE" ]]; then
    if ! choose_deploy_mode; then
      echo -e "${BRIGHT_RED}Aborting due to invalid mode selection.${RESET}"
      return 1
    fi
    MODE="${AINISH_DEPLOY_MODE}"
  fi
  # Interpret mode flags
  local MODE_STYLE_ONLY=0
  local MODE_IGNORE_ONLY=0
  local MODE_CORE_ONLY=0
  local MODE_ALL=0
  case "$MODE" in
    1) MODE_STYLE_ONLY=1 ; INCLUDE_STYLE_RULES=1 ;;
    2) MODE_IGNORE_ONLY=1 ;;
    3) MODE_CORE_ONLY=1 ;;
    4) MODE_ALL=1 ; INCLUDE_STYLE_RULES=1 ;;
    *) ;; # leave defaults; prompt funcs may still ask
  esac
  # If mode wasn't recognized, fall back to style prompt
  if [[ $INCLUDE_STYLE_RULES -eq 0 && ! "$MODE" =~ ^[1-4]$ ]]; then
    if prompt_include_style_rules; then
      INCLUDE_STYLE_RULES=1
    fi
  fi

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
  if [[ $MODE_IGNORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    if prompt_for_ignore_files "$TARGET" "Cursor" ".cursorignore" "Controls which files Cursor AI will ignore during code generation and analysis."; then
      if [ -f "${SRC_CURSOR_DIR}/.cursorignore" ]; then
        cp "${SRC_CURSOR_DIR}/.cursorignore" "$TARGET/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed .cursorignore${RESET}"
      else
        touch "$TARGET/.cursorignore" 2>/dev/null
        echo -e "${GREEN}✓ Created empty .cursorignore${RESET}"
      fi
    fi
  fi

  # Deploy .cursorindexingignore
  if [[ $MODE_IGNORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    if prompt_for_ignore_files "$TARGET" "Cursor" ".cursorindexingignore" "Controls which files Cursor will skip during indexing (improves performance)."; then
      if [ -f "${SRC_CURSOR_DIR}/.cursorindexingignore" ]; then
        cp "${SRC_CURSOR_DIR}/.cursorindexingignore" "$TARGET/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed .cursorindexingignore${RESET}"
      else
        touch "$TARGET/.cursorindexingignore" 2>/dev/null
        echo -e "${GREEN}✓ Created empty .cursorindexingignore${RESET}"
      fi
    fi
  fi

  # Deploy .cursorrules (Symlink preferred, copy fallback)
  if [[ $MODE_ALL -eq 1 ]]; then
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
  fi

  # --- Deploy files into the TARGET/.cursor/rules directory ---
  local SRC_RULES_DIR="${SRC_CURSOR_DIR}/.cursor/rules"
  local TARGET_RULES_DIR="$TARGET/.cursor/rules"

  if [[ $MODE_ALL -eq 1 ]]; then
    echo -e "${BLUE}Syncing contents of ${SRC_RULES_DIR} to ${TARGET_RULES_DIR}...${RESET}"
    # Copy all contents from source rules directory, overwriting existing files
    if [ -d "$SRC_RULES_DIR" ]; then
       cp -R "${SRC_RULES_DIR}/." "$TARGET_RULES_DIR/" 2>/dev/null
       echo -e "${GREEN}✓ Copied all rules from ${SRC_RULES_DIR}${RESET}"
    else
       echo -e "${YELLOW}⚠️ Warning: Source rules directory ${SRC_RULES_DIR} not found.${RESET}"
    fi
  fi

  # --- Overwrite specific files if needed (ensuring correct source) ---

  # Deploy critical.mdc (ensure it comes from the central location)
  if [[ $MODE_CORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    local critical_src="${AINISH_CODER_DIR}/critical.mdc" # Should point to REPO_DIR/critical.mdc
    if [ -f "$critical_src" ]; then
      cp "$critical_src" "$TARGET_RULES_DIR/" 2>/dev/null
      echo -e "${GREEN}✓ Ensured latest critical.mdc is in .cursor/rules/${RESET}"
    fi
  fi

  

  # Deploy shared anishinaabe-cyberpunk-style.mdc (conditional)
  if [ $INCLUDE_STYLE_RULES -eq 1 ]; then
    if [ -f "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" ]; then
      cp "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET_RULES_DIR/" 2>/dev/null
      echo -e "${GREEN}✓ Ensured latest anishinaabe-cyberpunk-style.mdc is in .cursor/rules/${RESET}"
    elif [ -f "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" ]; then
      cp "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET_RULES_DIR/" 2>/dev/null
      echo -e "${GREEN}✓ Ensured latest anishinaabe-cyberpunk-style.mdc is in .cursor/rules/${RESET}"
    else
      echo -e "${YELLOW}⚠️ Warning: anishinaabe-cyberpunk-style.mdc not found${RESET}"
    fi
  else
    echo -e "${BLUE}↪ Skipped styling rules by user choice${RESET}"
  fi
  
  # Skip deploying mdc-headers.md to Cursor as requested
  # local mdc_headers_src="${REPO_DIR}/mdc-headers.md" # Use REPO_DIR for root files
  # if [ -f "$mdc_headers_src" ]; then
  #     cp "$mdc_headers_src" "$TARGET_RULES_DIR/" 2>/dev/null
  #     echo -e "${GREEN}✓ Ensured latest mdc-headers.md is in .cursor/rules/${RESET}"
  # fi

  # Deploy prompt as cognitive-tool.md based on PROMPT_MODE
  if [[ $MODE_CORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    local prompt_src="${REPO_DIR}/prompt.md"
    if [ "$PROMPT_MODE" = "security" ]; then
      prompt_src="${REPO_DIR}/security-meta-prompt.md"
    elif [ "$PROMPT_MODE" = "none" ]; then
      prompt_src=""
    fi
    local cursor_prompt_target="$TARGET_RULES_DIR/cognitive-tool.md"
    if [ -n "$prompt_src" ]; then
      if [ -f "$prompt_src" ]; then
        cp "$prompt_src" "$cursor_prompt_target" 2>/dev/null
        # Cleanup legacy filename if present
        rm -f "$TARGET_RULES_DIR/gikendaasowin.md" 2>/dev/null
        echo -e "${GREEN}✓ Deployed prompt (mode=${PROMPT_MODE:-normal}) to $cursor_prompt_target${RESET}"
      else
        echo -e "${YELLOW}⚠️ Warning: Prompt source not found at $prompt_src${RESET}"
      fi
    else
      rm -f "$cursor_prompt_target" 2>/dev/null
      rm -f "$TARGET_RULES_DIR/gikendaasowin.md" 2>/dev/null
      echo -e "${BLUE}↪ Skipped deploying Cursor prompt (mode=none)${RESET}"
    fi
  fi

  # Ensure docs-use.mdc for core/all modes
  if [[ $MODE_CORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    local docs_src="${REPO_DIR}/docs-use.mdc"
    if [ -f "$docs_src" ]; then
      cp "$docs_src" "$TARGET_RULES_DIR/" 2>/dev/null
      echo -e "${GREEN}✓ Ensured docs-use.mdc is in .cursor/rules/${RESET}"
    fi
  fi

  # Deploy license.mdc if it exists in the source cursor dir (might be specific)
  if [[ $MODE_ALL -eq 1 ]]; then
    if [ -f "${SRC_CURSOR_DIR}/my-license.mdc" ]; then
        cp "${SRC_CURSOR_DIR}/my-license.mdc" "$TARGET_RULES_DIR/license.mdc" 2>/dev/null
        echo -e "${GREEN}✓ Deployed license.mdc from ${SRC_CURSOR_DIR}${RESET}"
    fi
  fi

  # Verification steps (optional but good)
  echo -e "${BLUE}Verifying deployed Cursor files...${RESET}"
  # Build a verification list that only includes files that should exist
  # .cursorrules is optional; include it only if present
  {
    [ -f "$TARGET/.cursorignore" ] && ls -l "$TARGET/.cursorignore"
    [ -f "$TARGET/.cursorindexingignore" ] && ls -l "$TARGET/.cursorindexingignore"
    [ -f "$TARGET/.cursorrules" ] && ls -l "$TARGET/.cursorrules"
    [ -d "$TARGET_RULES_DIR" ] && ls -ld "$TARGET_RULES_DIR" && ls -l "$TARGET_RULES_DIR"
  } 2>/dev/null || echo -e "${YELLOW}Verification step encountered issues.${RESET}"

  # Deploy .gitignore and update ignore entries only for full mode
  if [[ $MODE_ALL -eq 1 ]]; then
    if [ -f "${REPO_DIR}/.gitignore" ]; then
        cp "${REPO_DIR}/.gitignore" "$TARGET/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed root .gitignore to $TARGET${RESET}"
    fi
    update_gitignore "$TARGET"
  fi

  echo -e "${BRIGHT_GREEN}✅ Cursor configurations deployed to $TARGET${RESET}"
}

# Function to deploy only Aider configurations
deploy_aider_configs() {
  local TARGET="$1"
  local PROMPT_MODE="${AINISH_PROMPT_MODE:-}"
  local INCLUDE_STYLE_RULES=0
  local MODE="${AINISH_DEPLOY_MODE:-}"
  # Ask once for mode if not already set
  if [[ -z "$MODE" ]]; then
    if ! choose_deploy_mode; then
      echo -e "${BRIGHT_RED}Aborting due to invalid mode selection.${RESET}"
      return 1
    fi
    MODE="${AINISH_DEPLOY_MODE}"
  fi
  # Interpret mode flags
  local MODE_STYLE_ONLY=0
  local MODE_IGNORE_ONLY=0
  local MODE_CORE_ONLY=0
  local MODE_ALL=0
  case "$MODE" in
    1) MODE_STYLE_ONLY=1 ; INCLUDE_STYLE_RULES=1 ;;
    2) MODE_IGNORE_ONLY=1 ;;
    3) MODE_CORE_ONLY=1 ;;
    4) MODE_ALL=1 ; INCLUDE_STYLE_RULES=1 ;;
    *) ;;
  esac
  if [[ $INCLUDE_STYLE_RULES -eq 0 && ! "$MODE" =~ ^[1-4]$ ]]; then
    if prompt_include_style_rules; then
      INCLUDE_STYLE_RULES=1
    fi
  fi

  # Verify target is a directory
  if [ ! -d "$TARGET" ]; then
    echo -e "${BRIGHT_RED}Error: $TARGET is not a directory${RESET}"
    return 1
  fi

  echo -e "${BRIGHT_BLUE}Deploying Aider configurations to $TARGET${RESET}"

  # Deploy Aider-specific configurations
  # Copy .aider-instructions.md from selected prompt
  local prompt_source="${REPO_DIR}/prompt.md"
  if [ "$PROMPT_MODE" = "security" ]; then
    prompt_source="${REPO_DIR}/security-meta-prompt.md"
  elif [ "$PROMPT_MODE" = "none" ]; then
    prompt_source=""
  fi
  local aider_target_file="$TARGET/.aider-instructions.md"
  if [ -n "$prompt_source" ]; then
    if [ -f "$prompt_source" ]; then
      prepend_non_cursor_content "$prompt_source" "$aider_target_file"
    else
      echo -e "${YELLOW}⚠️ Warning: Prompt source not found at $prompt_source${RESET}"
    fi
  else
    rm -f "$aider_target_file" 2>/dev/null
    echo -e "${BLUE}↪ Skipped deploying Aider prompt (mode=none)${RESET}"
  fi
  
  # Deploy anishinaabe-cyberpunk-style.mdc (conditional)
  if [ $INCLUDE_STYLE_RULES -eq 1 ]; then
    if [ -f "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" ]; then
      cp "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed anishinaabe-cyberpunk-style.mdc to $TARGET${RESET}"
    elif [ -f "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" ]; then
      cp "${AINISH_CODER_DIR}/anishinaabe-cyberpunk-style.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed anishinaabe-cyberpunk-style.mdc to $TARGET${RESET}"
    else
      echo -e "${YELLOW}⚠️ Warning: anishinaabe-cyberpunk-style.mdc not found${RESET}"
    fi
  else
    echo -e "${BLUE}↪ Skipped styling rules by user choice${RESET}"
  fi
  
  if [[ $MODE_ALL -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/aider/.aider.conf.yml" ]; then
      cp "${AINISH_CODER_DIR}/aider/.aider.conf.yml" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .aider.conf.yml${RESET}"
    fi
  fi
  
  if [[ $MODE_IGNORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/aider/.aiderignore" ]; then
      cp "${AINISH_CODER_DIR}/aider/.aiderignore" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .aiderignore${RESET}"
    fi
  fi
  
  if [[ $MODE_ALL -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/aider/.env.example" ]; then
      cp "${AINISH_CODER_DIR}/aider/.env.example" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed .env.example${RESET}"
    fi
  fi

  if [[ $MODE_ALL -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/aider/aider-cli-commands.sh" ]; then
      cp "${AINISH_CODER_DIR}/aider/aider-cli-commands.sh" "$TARGET/" 2>/dev/null
      chmod +x "$TARGET/aider-cli-commands.sh" 2>/dev/null # Ensure executable
      echo -e "${GREEN}✓ Deployed aider-cli-commands.sh${RESET}"
    fi
  fi

  # Deploy shared critical.mdc directly to target directory
  if [[ $MODE_CORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    if [ -f "${AINISH_CODER_DIR}/critical.mdc" ]; then
      cp "${AINISH_CODER_DIR}/critical.mdc" "$TARGET/" 2>/dev/null
      echo -e "${GREEN}✓ Deployed critical.mdc to $TARGET${RESET}"
    fi
  fi

  

  # Deploy docs-use.mdc (ensure it comes from the central location)
  if [[ $MODE_CORE_ONLY -eq 1 || $MODE_ALL -eq 1 ]]; then
    local docs_src="${REPO_DIR}/docs-use.mdc" # Use REPO_DIR for root files
    if [ -f "$docs_src" ]; then
        cp "$docs_src" "$TARGET/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed docs-use.mdc to $TARGET${RESET}"
    fi
  fi
  
  # Deploy mdc-headers.md (ensure it comes from the central location)
  if [[ $MODE_ALL -eq 1 ]]; then
    local mdc_headers_src="${REPO_DIR}/mdc-headers.md" # Use REPO_DIR for root files
    if [ -f "$mdc_headers_src" ]; then
        cp "$mdc_headers_src" "$TARGET/" 2>/dev/null
        echo -e "${GREEN}✓ Deployed mdc-headers.md to $TARGET${RESET}"
    fi
  fi

  # (Prompt deployment handled above based on PROMPT_MODE)

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
      local cursor_target="${cursor_rules_dest_dir}/cognitive-tool.md"
      
      cp "$prompt_src" "$copilot_target" 2>/dev/null && echo -e "${GREEN}✓ Copied prompt.md to $copilot_target${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy prompt.md to $copilot_target${RESET}"
      cp "$prompt_src" "$aider_target" 2>/dev/null && echo -e "${GREEN}✓ Copied prompt.md to $aider_target${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy prompt.md to $aider_target${RESET}"
      cp "$prompt_src" "$cursor_target" 2>/dev/null && echo -e "${GREEN}✓ Copied prompt.md to $cursor_target${RESET}" || echo -e "${YELLOW}⚠️ Failed to copy prompt.md to $cursor_target${RESET}"
      # Cleanup legacy filename inside repository distribution
      rm -f "${cursor_rules_dest_dir}/gikendaasowin.md" 2>/dev/null
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