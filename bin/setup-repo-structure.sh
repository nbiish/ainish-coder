#!/bin/bash
# Script to set up the proper repository directory structure for mai-coder

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== MAI-CODER REPOSITORY STRUCTURE SETUP ===${NC}"

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "Repository directory: $REPO_DIR"

# Create required directories
mkdir -p "$REPO_DIR/mai-aider"
mkdir -p "$REPO_DIR/mai-copilot/github-copilot/.github"
mkdir -p "$REPO_DIR/mai-cursor"
mkdir -p "$REPO_DIR/bin"
mkdir -p "$REPO_DIR/lib"

# Check if we have an .aider directory in the root
if [ -d "$REPO_DIR/.aider" ]; then
    echo -e "${YELLOW}Found .aider directory in repository root${NC}"
    
    # Check if we need to move files to the mai-aider directory
    if [ ! -f "$REPO_DIR/mai-aider/.aider.conf.yml" ] && [ -f "$REPO_DIR/.aider/config.yml" ]; then
        echo -e "${GREEN}Moving .aider/config.yml to mai-aider/.aider.conf.yml${NC}"
        cp "$REPO_DIR/.aider/config.yml" "$REPO_DIR/mai-aider/.aider.conf.yml"
    fi
fi

# Check for Aider-related files in the root and move them to mai-aider
for file in .aider.conf.yml .aiderignore .env.example .aider-instructions.md; do
    if [ -f "$REPO_DIR/$file" ]; then
        echo -e "${GREEN}Moving $file to mai-aider/${NC}"
        cp "$REPO_DIR/$file" "$REPO_DIR/mai-aider/$file"
    fi
done

echo -e "${GREEN}Repository structure set up successfully.${NC}"
echo "You can now add your configuration files to:"
echo "  $REPO_DIR/mai-aider/ - for Aider"
echo "  $REPO_DIR/mai-copilot/ - for GitHub Copilot"
echo "  $REPO_DIR/mai-cursor/ - for Cursor"
echo ""
echo "Run ./install.sh to install the toolkit." 