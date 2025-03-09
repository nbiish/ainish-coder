#!/bin/bash
# Test script for mai-coder file structure

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== MAI-CODER FILE STRUCTURE TEST ===${NC}"

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Create a test environment
TEST_DIR="/tmp/mai-coder-test"
TEST_INSTALL_DIR="/tmp/mai-coder-test-install"
TEST_PROJECT_DIR="/tmp/mai-coder-test-project"

echo "Setting up test environment..."
rm -rf "$TEST_DIR" "$TEST_INSTALL_DIR" "$TEST_PROJECT_DIR"
mkdir -p "$TEST_DIR"
mkdir -p "$TEST_INSTALL_DIR"
mkdir -p "$TEST_PROJECT_DIR"

# Copy the repository to the test directory
cp -R "$REPO_DIR/"* "$TEST_DIR/" 2>/dev/null

# Create necessary test files
echo "Creating test configuration files..."
mkdir -p "$TEST_DIR/mai-aider/.aider"
echo "model: gpt-4" > "$TEST_DIR/mai-aider/.aider.conf.yml"
echo "# Test aiderignore file" > "$TEST_DIR/mai-aider/.aiderignore"
echo "# Test aider instructions" > "$TEST_DIR/mai-aider/.aider-instructions.md"
echo "# Test env example" > "$TEST_DIR/mai-aider/.env.example"
echo "# Test aider config" > "$TEST_DIR/mai-aider/.aider/config.yml"

# Set up the mai-coder installation
echo "Setting up test installation..."
mkdir -p "$TEST_INSTALL_DIR/mai-aider/.aider"
cp "$TEST_DIR/mai-aider/.aider.conf.yml" "$TEST_INSTALL_DIR/mai-aider/"
cp "$TEST_DIR/mai-aider/.aiderignore" "$TEST_INSTALL_DIR/mai-aider/"
cp "$TEST_DIR/mai-aider/.aider-instructions.md" "$TEST_INSTALL_DIR/mai-aider/"
cp "$TEST_DIR/mai-aider/.env.example" "$TEST_INSTALL_DIR/mai-aider/"
cp "$TEST_DIR/mai-aider/.aider/config.yml" "$TEST_INSTALL_DIR/mai-aider/.aider/"

# Copy the mai-coder script
mkdir -p "$TEST_INSTALL_DIR/bin"
cp "$TEST_DIR/bin/mai-coder" "$TEST_INSTALL_DIR/bin/"
chmod +x "$TEST_INSTALL_DIR/bin/mai-coder"

# Modify the mai-coder script to use our test installation directory
sed -i '' "s|INSTALL_DIR=\"\${HOME}/.mai-coder\"|INSTALL_DIR=\"$TEST_INSTALL_DIR\"|g" "$TEST_INSTALL_DIR/bin/mai-coder"

echo "Running test setup for Aider..."
"$TEST_INSTALL_DIR/bin/mai-coder" aider "$TEST_PROJECT_DIR" << EOF
3
EOF

echo ""
echo "Checking file structure in test project directory..."
find "$TEST_PROJECT_DIR" -type f | sort

echo ""
echo -e "${GREEN}Test completed.${NC}"
echo "Expected file structure:"
echo "- .aider.conf.yml in project root"
echo "- .aiderignore in project root"
echo "- .aider-instructions.md in project root"
echo "- .env.example in project root"
echo "- Config files in .aider/ directory"

# Verify expected file structure
if [ -f "$TEST_PROJECT_DIR/.aider.conf.yml" ] && \
   [ -f "$TEST_PROJECT_DIR/.aiderignore" ] && \
   [ -f "$TEST_PROJECT_DIR/.aider-instructions.md" ] && \
   [ -f "$TEST_PROJECT_DIR/.env.example" ] && \
   [ -f "$TEST_PROJECT_DIR/.aider/config.yml" ]; then
    echo -e "${GREEN}Success! All expected files were copied to the correct locations.${NC}"
else
    echo -e "${RED}Test failed! Some files are missing or in the wrong location.${NC}"
    if [ ! -f "$TEST_PROJECT_DIR/.aider.conf.yml" ]; then
        echo -e "${RED}Missing: .aider.conf.yml${NC}"
    fi
    if [ ! -f "$TEST_PROJECT_DIR/.aiderignore" ]; then
        echo -e "${RED}Missing: .aiderignore${NC}"
    fi
    if [ ! -f "$TEST_PROJECT_DIR/.aider-instructions.md" ]; then
        echo -e "${RED}Missing: .aider-instructions.md${NC}"
    fi
    if [ ! -f "$TEST_PROJECT_DIR/.env.example" ]; then
        echo -e "${RED}Missing: .env.example${NC}"
    fi
    if [ ! -f "$TEST_PROJECT_DIR/.aider/config.yml" ]; then
        echo -e "${RED}Missing: .aider/config.yml${NC}"
    fi
fi

echo ""
echo "Cleaning up test environment..."
rm -rf "$TEST_DIR" "$TEST_INSTALL_DIR" "$TEST_PROJECT_DIR" 