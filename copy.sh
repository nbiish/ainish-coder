#!/bin/bash

# ANISHINAABE-CYBERPUNK-STYLE.MDC COPY SCRIPT
# This script ensures all required files are properly copied to their designated locations

# Get the absolute path of the repository
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ANSI color codes for cyberpunk theme
CYAN='\033[0;36m'
BRIGHT_CYAN='\033[1;36m'
GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BRIGHT_CYAN}╭──────────────────────────────────────────────────────────────────────╮${RESET}"
echo -e "${BRIGHT_CYAN}│  ᐴ OZHITOON ᔔ [ BUILDING ]                                           │${RESET}"
echo -e "${BRIGHT_CYAN}│  ◈──◆──◇─◈ COPYING ALL REQUIRED FILES ◈─◇──◆──◈                      │${RESET}"
echo -e "${BRIGHT_CYAN}╰──────────────────────────────────────────────────────────────────────╯${RESET}"
echo

# Define destination directories
CURSOR_RULES_DIR="${REPO_DIR}/ainish-cursor/.cursor/rules"
ROOT_CURSOR_RULES_DIR="${REPO_DIR}/.cursor/rules"
AIDER_DIR="${REPO_DIR}/ainish-aider"
COPILOT_GITHUB_DIR="${REPO_DIR}/ainish-copilot/.github"
COPILOT_DIR="${REPO_DIR}/ainish-copilot"
CURSOR_DIR="${REPO_DIR}/ainish-cursor"

# Ensure directories exist
mkdir -p "$CURSOR_RULES_DIR" 2>/dev/null
mkdir -p "$ROOT_CURSOR_RULES_DIR" 2>/dev/null
mkdir -p "$AIDER_DIR" 2>/dev/null
mkdir -p "$COPILOT_GITHUB_DIR" 2>/dev/null
mkdir -p "$COPILOT_DIR" 2>/dev/null
mkdir -p "$CURSOR_DIR" 2>/dev/null

# Function to copy file and report status
copy_file() {
    local source="$1"
    local dest="$2"
    local display_name="$3"
    
    if [ ! -f "$source" ]; then
        echo -e "${RED}✗ Source file not found: $source${RESET}"
        return 1
    fi
    
    if cp "$source" "$dest" 2>/dev/null; then
        echo -e "${GREEN}✓ Copied $display_name${RESET}"
        return 0
    else
        echo -e "${YELLOW}⚠️ Failed to copy $display_name${RESET}"
        return 1
    fi
}

echo -e "${BRIGHT_CYAN}Copying critical.mdc...${RESET}"
copy_file "${REPO_DIR}/critical.mdc" "$AIDER_DIR/critical.mdc" "critical.mdc to ainish-aider/"
copy_file "${REPO_DIR}/critical.mdc" "$COPILOT_GITHUB_DIR/critical.mdc" "critical.mdc to ainish-copilot/.github/"
copy_file "${REPO_DIR}/critical.mdc" "$CURSOR_RULES_DIR/critical.mdc" "critical.mdc to ainish-cursor/.cursor/rules/"
copy_file "${REPO_DIR}/critical.mdc" "$ROOT_CURSOR_RULES_DIR/critical.mdc" "critical.mdc to .cursor/rules/"
echo

echo -e "${BRIGHT_CYAN}Copying anishinaabe-cyberpunk-style.mdc...${RESET}"
copy_file "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$AIDER_DIR/anishinaabe-cyberpunk-style.mdc" "anishinaabe-cyberpunk-style.mdc to ainish-aider/"
copy_file "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$COPILOT_GITHUB_DIR/anishinaabe-cyberpunk-style.mdc" "anishinaabe-cyberpunk-style.mdc to ainish-copilot/.github/"
copy_file "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$CURSOR_RULES_DIR/anishinaabe-cyberpunk-style.mdc" "anishinaabe-cyberpunk-style.mdc to ainish-cursor/.cursor/rules/"
copy_file "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" "$ROOT_CURSOR_RULES_DIR/anishinaabe-cyberpunk-style.mdc" "anishinaabe-cyberpunk-style.mdc to .cursor/rules/"
echo


echo -e "${BRIGHT_CYAN}Copying docs-use.mdc...${RESET}"
copy_file "${REPO_DIR}/docs-use.mdc" "$AIDER_DIR/docs-use.mdc" "docs-use.mdc to ainish-aider/"
copy_file "${REPO_DIR}/docs-use.mdc" "$COPILOT_GITHUB_DIR/docs-use.mdc" "docs-use.mdc to ainish-copilot/.github/"
copy_file "${REPO_DIR}/docs-use.mdc" "$CURSOR_RULES_DIR/docs-use.mdc" "docs-use.mdc to ainish-cursor/.cursor/rules/"
copy_file "${REPO_DIR}/docs-use.mdc" "$ROOT_CURSOR_RULES_DIR/docs-use.mdc" "docs-use.mdc to .cursor/rules/"
echo

echo -e "${BRIGHT_CYAN}Copying prompt.md with special naming...${RESET}"
copy_file "${REPO_DIR}/prompt.md" "$COPILOT_GITHUB_DIR/copilot-instructions.md" "prompt.md to ainish-copilot/.github/copilot-instructions.md"
copy_file "${REPO_DIR}/prompt.md" "$AIDER_DIR/.aider-instructions.md" "prompt.md to ainish-aider/.aider-instructions.md"
copy_file "${REPO_DIR}/prompt.md" "$CURSOR_RULES_DIR/gikendaasowin.md" "prompt.md to ainish-cursor/.cursor/rules/gikendaasowin.md"
echo

echo -e "${BRIGHT_CYAN}Copying .gitignore...${RESET}"
if [ -f "${REPO_DIR}/.gitignore" ]; then
    copy_file "${REPO_DIR}/.gitignore" "$AIDER_DIR/.gitignore" ".gitignore to ainish-aider/"
    copy_file "${REPO_DIR}/.gitignore" "$COPILOT_DIR/.gitignore" ".gitignore to ainish-copilot/"
    copy_file "${REPO_DIR}/.gitignore" "$CURSOR_DIR/.gitignore" ".gitignore to ainish-cursor/"
else
    echo -e "${YELLOW}⚠️ .gitignore not found in repository root${RESET}"
fi
echo

echo -e "${BRIGHT_GREEN}✅ All required files have been copied to their designated locations${RESET}"
echo
echo -e "${CYAN}You should now be able to run all ainish tools without issues.${RESET}"
