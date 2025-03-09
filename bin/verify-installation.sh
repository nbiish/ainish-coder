#!/bin/bash
# Script to verify the mai-coder installation

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== MAI-CODER INSTALLATION VERIFICATION ===${NC}"

# Check if mai-coder is installed
INSTALL_DIR="${HOME}/.mai-coder"
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}Error: mai-coder is not installed at $INSTALL_DIR${NC}"
    echo "Please run ./install.sh to install mai-coder"
    exit 1
fi

echo -e "${GREEN}mai-coder is installed at $INSTALL_DIR${NC}"

# Check for required directories
for dir in mai-aider mai-copilot mai-cursor bin lib; do
    if [ ! -d "$INSTALL_DIR/$dir" ]; then
        echo -e "${RED}Error: Required directory $dir is missing${NC}"
        echo "Please run ./install.sh to reinstall mai-coder"
        exit 1
    fi
done

echo -e "${GREEN}All required directories are present${NC}"

# Check for required scripts
for script in mai-coder mai-coder-aider mai-coder-code mai-coder-cursor; do
    if [ ! -f "$INSTALL_DIR/bin/$script" ]; then
        echo -e "${RED}Error: Required script $script is missing${NC}"
        echo "Please run ./install.sh to reinstall mai-coder"
        exit 1
    fi
    if [ ! -x "$INSTALL_DIR/bin/$script" ]; then
        echo -e "${YELLOW}Warning: Script $script is not executable${NC}"
        echo "Running: chmod +x $INSTALL_DIR/bin/$script"
        chmod +x "$INSTALL_DIR/bin/$script"
    fi
done

echo -e "${GREEN}All required scripts are present and executable${NC}"

# Check for aider files
for file in .aider.conf.yml .aiderignore .aider-instructions.md .env.example; do
    if [ ! -f "$INSTALL_DIR/mai-aider/$file" ]; then
        echo -e "${YELLOW}Warning: Aider file $file is missing${NC}"
    fi
done

# Check if mai-coder is in PATH
if command -v mai-coder >/dev/null 2>&1; then
    echo -e "${GREEN}mai-coder is in your PATH${NC}"
    mai_coder_path=$(which mai-coder)
    echo "mai-coder path: $mai_coder_path"
else
    echo -e "${YELLOW}Warning: mai-coder is not in your PATH${NC}"
    echo "You can add it to your PATH by running:"
    echo "$INSTALL_DIR/bin/add-to-path.sh"
fi

echo ""
echo -e "${GREEN}===== Verification completed successfully! =====${NC}"
echo "You can now use the following commands:"
echo "  mai-coder                # Configure all tools"
echo "  mai-coder aider          # Configure only Aider"
echo "  mai-coder code           # Configure only GitHub Copilot"
echo "  mai-coder cursor         # Configure only Cursor"
echo ""
echo "If you encounter any issues, please run ./install.sh to reinstall mai-coder" 