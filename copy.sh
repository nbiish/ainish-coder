#!/bin/bash

# ANISHINAABE-CYBERPUNK-STYLE.MDC COPY SCRIPT
# This script ensures anishinaabe-cyberpunk-style.mdc is properly copied to all required locations

# Get the absolute path of the repository
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Style file
STYLE_FILE="${REPO_DIR}/anishinaabe-cyberpunk-style.mdc"

# ANSI color codes for cyberpunk theme
CYAN='\033[0;36m'
BRIGHT_CYAN='\033[1;36m'
GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

# Check if the style file exists
if [ ! -f "$STYLE_FILE" ]; then
  echo -e "${RED}Error: anishinaabe-cyberpunk-style.mdc not found at $STYLE_FILE${RESET}"
  exit 1
fi

echo -e "${BRIGHT_CYAN}╭──────────────────────────────────────────────────────────────────────╮${RESET}"
echo -e "${BRIGHT_CYAN}│  ᐴ OZHITOON ᔔ [ BUILDING ]                                           │${RESET}"
echo -e "${BRIGHT_CYAN}│  ◈──◆──◇─◈ COPYING STYLE FILES ◈─◇──◆──◈                             │${RESET}"
echo -e "${BRIGHT_CYAN}╰──────────────────────────────────────────────────────────────────────╯${RESET}"
echo

# Define destination directories
CURSOR_RULES_DIR="${REPO_DIR}/ainish-cursor/.cursor/rules"
ROOT_CURSOR_RULES_DIR="${REPO_DIR}/.cursor/rules"
AIDER_DIR="${REPO_DIR}/ainish-aider"
COPILOT_GITHUB_DIR="${REPO_DIR}/ainish-copilot/.github"

# Ensure directories exist
mkdir -p "$CURSOR_RULES_DIR" 2>/dev/null
mkdir -p "$ROOT_CURSOR_RULES_DIR" 2>/dev/null
mkdir -p "$AIDER_DIR" 2>/dev/null
mkdir -p "$COPILOT_GITHUB_DIR" 2>/dev/null

# Copy to ainish-cursor/.cursor/rules/
cp "$STYLE_FILE" "$CURSOR_RULES_DIR/" 2>/dev/null && \
  echo -e "${GREEN}✓ Copied anishinaabe-cyberpunk-style.mdc to ainish-cursor/.cursor/rules/${RESET}" || \
  echo -e "${YELLOW}⚠️ Failed to copy to ainish-cursor/.cursor/rules/${RESET}"

# Copy to .cursor/rules/
cp "$STYLE_FILE" "$ROOT_CURSOR_RULES_DIR/" 2>/dev/null && \
  echo -e "${GREEN}✓ Copied anishinaabe-cyberpunk-style.mdc to .cursor/rules/${RESET}" || \
  echo -e "${YELLOW}⚠️ Failed to copy to .cursor/rules/${RESET}"

# Copy to ainish-aider/
cp "$STYLE_FILE" "$AIDER_DIR/" 2>/dev/null && \
  echo -e "${GREEN}✓ Copied anishinaabe-cyberpunk-style.mdc to ainish-aider/${RESET}" || \
  echo -e "${YELLOW}⚠️ Failed to copy to ainish-aider/${RESET}"

# Copy to ainish-copilot/.github/
cp "$STYLE_FILE" "$COPILOT_GITHUB_DIR/" 2>/dev/null && \
  echo -e "${GREEN}✓ Copied anishinaabe-cyberpunk-style.mdc to ainish-copilot/.github/${RESET}" || \
  echo -e "${YELLOW}⚠️ Failed to copy to ainish-copilot/.github/${RESET}"

echo
echo -e "${BRIGHT_GREEN}✅ anishinaabe-cyberpunk-style.mdc has been copied to all required locations${RESET}"
echo
echo -e "${CYAN}You should now be able to run ainish-cursor without issues.${RESET}"
