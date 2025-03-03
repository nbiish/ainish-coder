#!/bin/bash

# Get the absolute path of the repository
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set text colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}🤖 AI Tool Setup for Your Project 🤖${NC}"
echo -e "${BLUE}=====================================${NC}"

# Get the target directory
read -p "Enter the path to your project directory (or '.' for current directory): " TARGET_DIR

# Use current directory if not specified
if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR="."
fi

# Create directory if it doesn't exist
if [ ! -d "$TARGET_DIR" ]; then
    read -p "Directory does not exist. Create it? (y/n): " CREATE_DIR
    if [[ "$CREATE_DIR" =~ ^[Yy]$ ]]; then
        mkdir -p "$TARGET_DIR"
        echo -e "${GREEN}✅ Created directory: $TARGET_DIR${NC}"
    else
        echo -e "${RED}❌ Directory does not exist. Exiting.${NC}"
        exit 1
    fi
fi

# Move to target directory
cd "$TARGET_DIR"

# If not a git repo, initialize one
if [ ! -d ".git" ]; then
    read -p "This directory is not a git repository. Initialize one? (y/n): " INIT_GIT
    if [[ "$INIT_GIT" =~ ^[Yy]$ ]]; then
        git init
        echo -e "${GREEN}✅ Initialized git repository${NC}"
    else
        echo -e "${YELLOW}⚠️ Continuing without git initialization${NC}"
    fi
fi

# Functions to set up each tool
setup_aider() {
    echo -e "${BLUE}Setting up Aider configuration...${NC}"
    
    # Create .gitignore entries
    if [ -f ".gitignore" ]; then
        if ! grep -q ".aider.chat.history.md" ".gitignore"; then
            echo -e "\n# Aider files" >> .gitignore
            echo ".aider.chat.history.md" >> .gitignore
            echo ".aider.input.history" >> .gitignore
            echo ".aider.*.json" >> .gitignore
            echo ".aider.llm.history" >> .gitignore
            echo ".aider.conf.yml" >> .gitignore
            echo -e "${GREEN}✅ Added Aider entries to .gitignore${NC}"
        else
            echo -e "${YELLOW}⚠️ Aider entries already in .gitignore${NC}"
        fi
    else
        echo -e "# Aider files" > .gitignore
        echo ".aider.chat.history.md" >> .gitignore
        echo ".aider.input.history" >> .gitignore
        echo ".aider.*.json" >> .gitignore
        echo ".aider.llm.history" >> .gitignore 
        echo ".aider.conf.yml" >> .gitignore
        echo -e "${GREEN}✅ Created .gitignore with Aider entries${NC}"
    fi
    
    # Copy Aider instructions if they exist
    if [ -f "${REPO_DIR}/mai-aider/.aider-instructions.md" ]; then
        cp "${REPO_DIR}/mai-aider/.aider-instructions.md" .
        echo -e "${GREEN}✅ Copied Aider instructions${NC}"
    fi
}

setup_cursor() {
    echo -e "${BLUE}Setting up Cursor configuration...${NC}"
    
    # Copy Cursor config files
    if [ -f "${REPO_DIR}/mai-cursor/.cursorignore" ]; then
        cp "${REPO_DIR}/mai-cursor/.cursorignore" .
        echo -e "${GREEN}✅ Copied .cursorignore${NC}"
    fi
    
    if [ -f "${REPO_DIR}/mai-cursor/.cursorindexingignore" ]; then
        cp "${REPO_DIR}/mai-cursor/.cursorindexingignore" .
        echo -e "${GREEN}✅ Copied .cursorindexingignore${NC}"
    fi

    if [ -f "${REPO_DIR}/mai-cursor/.cursorrules" ]; then
        cp "${REPO_DIR}/mai-cursor/.cursorrules" .
        echo -e "${GREEN}✅ Copied .cursorrules${NC}"
    fi
    
    # Update .gitignore for Cursor
    if [ -f ".gitignore" ]; then
        if ! grep -q ".cursor/" ".gitignore"; then
            echo -e "\n# Cursor files" >> .gitignore
            echo ".cursor/" >> .gitignore
            echo -e "${GREEN}✅ Added Cursor entries to .gitignore${NC}"
        else
            echo -e "${YELLOW}⚠️ Cursor entries already in .gitignore${NC}"
        fi
    else
        # This should never execute as we create .gitignore in setup_aider
        echo -e "# Cursor files" > .gitignore
        echo ".cursor/" >> .gitignore
        echo -e "${GREEN}✅ Created .gitignore with Cursor entries${NC}"
    fi
}

setup_copilot() {
    echo -e "${BLUE}Setting up GitHub Copilot configuration...${NC}"
    
    # Copy Copilot config files
    if [ -f "${REPO_DIR}/mai-copilot/.copilotignore" ]; then
        cp "${REPO_DIR}/mai-copilot/.copilotignore" .
        echo -e "${GREEN}✅ Copied .copilotignore${NC}"
    fi
    
    # Update .gitignore for Copilot
    if [ -f ".gitignore" ]; then
        if ! grep -q ".copilot/" ".gitignore"; then
            echo -e "\n# GitHub Copilot files" >> .gitignore
            echo ".copilot/" >> .gitignore
            echo -e "${GREEN}✅ Added GitHub Copilot entries to .gitignore${NC}"
        else
            echo -e "${YELLOW}⚠️ GitHub Copilot entries already in .gitignore${NC}"
        fi
    fi
}

# Ask which tools to set up
echo -e "${BLUE}Which AI tools would you like to configure for this project?${NC}"

read -p "Set up Aider? (y/n): " SETUP_AIDER
if [[ "$SETUP_AIDER" =~ ^[Yy]$ ]]; then
    setup_aider
fi

read -p "Set up Cursor? (y/n): " SETUP_CURSOR
if [[ "$SETUP_CURSOR" =~ ^[Yy]$ ]]; then
    setup_cursor
fi

read -p "Set up GitHub Copilot? (y/n): " SETUP_COPILOT
if [[ "$SETUP_COPILOT" =~ ^[Yy]$ ]]; then
    setup_copilot
fi

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}✅ AI Tool Setup Complete! ✅${NC}"
echo -e "${GREEN}=====================================${NC}"
echo
echo -e "${YELLOW}Remember:${NC}"
echo "1. This setup only adds configuration files to your project."
echo "2. You still need to install the AI tools themselves."
echo "3. For Aider, you need to set up API keys (e.g., OPENROUTER_API_KEY, GEMINI_API_KEY)."
echo "4. For GitHub Copilot, you need a subscription and to log in via VS Code."
echo "5. For Cursor, you need to download and install it from cursor.sh."
echo
echo -e "To use Aider with Gemini Pro, set the API key and run: ${BLUE}aider pro${NC}" 