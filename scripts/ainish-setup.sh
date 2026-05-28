#!/bin/bash
# ◈──◆──◇ ainish-coder setup ◇──◆──◈
# Simplistic setup script to make the ainish-coder CLI available in your environment

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                   AINISH-CODER SETUP UTILITY                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get the absolute path to the ainish-coder bin directory, resolving symlinks
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
ROOT_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
BIN_DIR="${ROOT_DIR}/bin"
CLI_EXEC="${BIN_DIR}/ainish-coder"

if [[ ! -f "$CLI_EXEC" ]]; then
    echo -e "${RED}Error: Cannot find $CLI_EXEC${NC}"
    exit 1
fi

echo -e "${BLUE}[1/3] Setting execute permissions...${NC}"
chmod +x "$CLI_EXEC"
chmod +x "${ROOT_DIR}/fix-path.sh" 2>/dev/null || true
echo -e "${GREEN}✓ Permissions set.${NC}"
echo ""

echo -e "${BLUE}[2/3] Detecting shell profile...${NC}"

PROFILE=""
if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
    PROFILE="$HOME/.zshrc"
    echo -e "Detected Zsh. Using $PROFILE"
elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == *"bash"* ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        PROFILE="$HOME/.bash_profile"
    else
        PROFILE="$HOME/.bashrc"
    fi
    echo -e "Detected Bash. Using $PROFILE"
else
    PROFILE="$HOME/.profile"
    echo -e "Fallback shell detection. Using $PROFILE"
fi
echo ""

echo -e "${BLUE}[3/3] Configuring PATH...${NC}"

# Check if PATH already contains the ainish-coder bin directory
if grep -q "export PATH=.*${BIN_DIR}" "$PROFILE" 2>/dev/null; then
    echo -e "${GREEN}✓ $BIN_DIR is already in $PROFILE${NC}"
else
    # Create profile if it doesn't exist
    touch "$PROFILE"
    
    echo "" >> "$PROFILE"
    echo "# ◈──◆──◇ ainish-coder CLI ◇──◆──◈" >> "$PROFILE"
    echo "# Added on $(date)" >> "$PROFILE"
    echo "export PATH=\"${BIN_DIR}:\$PATH\"" >> "$PROFILE"
    
    echo -e "${GREEN}✓ Added $BIN_DIR to $PROFILE${NC}"
fi

# Clean up legacy wrappers if they exist
if grep -q "### AINISH CODER WRAPPERS ###" "$PROFILE" 2>/dev/null; then
    echo -e "${YELLOW}Notice: Found legacy wrappers in $PROFILE. You may want to remove them manually.${NC}"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  SETUP COMPLETE!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "To start using ainish-coder immediately, run:"
echo -e "    ${YELLOW}source $PROFILE${NC}"
echo ""
echo -e "Then try:"
echo -e "    ${YELLOW}ainish-coder --help${NC}"
echo ""
