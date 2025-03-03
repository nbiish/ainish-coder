#!/bin/bash

# UV Setup Helper - For consistent package management across different environments
# This script helps set up uv and install required packages in an isolated manner

# Set text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==== UV Package Manager and Aider Setup Helper ====${NC}"
echo "This script will help you set up the uv package manager for Python"
echo "and install required packages for the Aider Gemini Pro setup."
echo

# Check if uv is already installed
if command -v uv &> /dev/null; then
    echo -e "${GREEN}UV is already installed!${NC}"
    UV_PATH=$(which uv)
    echo "Path: $UV_PATH"
    
    # Check uv version
    UV_VERSION=$(uv --version)
    echo "Version: $UV_VERSION"
else
    echo -e "${YELLOW}UV package manager not found.${NC}"
    echo "UV is a fast Python package installer and resolver."
    
    read -p "Would you like to install uv now? (y/n): " INSTALL_UV
    if [[ "$INSTALL_UV" =~ ^[Yy]$ ]]; then
        echo "Installing UV package manager..."
        curl -sSf https://astral.sh/uv/install.sh | sh
        
        # Update PATH for current session
        if [[ -d "$HOME/.cargo/bin" ]]; then
            export PATH="$HOME/.cargo/bin:$PATH"
        fi
        
        # Check if installation succeeded
        if command -v uv &> /dev/null; then
            echo -e "${GREEN}UV has been successfully installed!${NC}"
        else
            echo -e "${RED}Failed to install UV. Please install it manually:${NC}"
            echo "curl -sSf https://astral.sh/uv/install.sh | sh"
            exit 1
        fi
    else
        echo "Continuing without UV. pip will be used instead (slower)."
    fi
fi

# Function to install required packages
install_packages() {
    echo -e "${BLUE}Installing required packages...${NC}"
    
    PACKAGES=("google-auth" "google-auth-oauthlib" "google-generativeai")
    
    if command -v uv &> /dev/null; then
        for pkg in "${PACKAGES[@]}"; do
            echo "Installing $pkg using uv..."
            uv pip install --system "$pkg"
        done
    else
        for pkg in "${PACKAGES[@]}"; do
            echo "Installing $pkg using pip..."
            pip install "$pkg"
        done
    fi
    
    echo -e "${GREEN}Package installation complete!${NC}"
}

# Function to install aider as a uv tool
install_aider() {
    echo -e "${BLUE}Installing aider as a uv tool...${NC}"
    
    if command -v uv &> /dev/null; then
        # Check if Python 3.12 is available
        if command -v python3.12 &> /dev/null; then
            echo "Installing aider with Python 3.12..."
            uv tool install --force --python python3.12 aider-chat@latest
        else
            # Get current Python version
            PYTHON_VERSION=$(python3 -c 'import sys; print(f"python{sys.version_info.major}.{sys.version_info.minor}")')
            echo "Installing aider with $PYTHON_VERSION..."
            uv tool install --force --python "$PYTHON_VERSION" aider-chat@latest
        fi
        
        # Now ensure the Google packages are installed in the aider tool environment
        if command -v aider &> /dev/null; then
            echo "Installing Google packages in aider tool environment..."
            UV_TOOL_DIR=$(dirname "$(command -v aider)")
            UV_ENV_DIR=$(dirname "$UV_TOOL_DIR")
            
            # Determine Python version used by the tool
            TOOL_PYTHON_VERSION=$(ls "$UV_ENV_DIR/lib/" | grep python | head -1)
            
            echo "Installing packages to $UV_ENV_DIR/lib/$TOOL_PYTHON_VERSION/site-packages"
            uv pip install --target "$UV_ENV_DIR/lib/$TOOL_PYTHON_VERSION/site-packages" google-auth google-auth-oauthlib google-generativeai
        else
            echo -e "${RED}Failed to find aider after installation. Check your PATH.${NC}"
        fi
    else
        echo -e "${RED}UV not found. Cannot install aider as a uv tool.${NC}"
        echo "Please install UV first or use pip to install aider."
        return 1
    fi
    
    echo -e "${GREEN}Aider installation complete!${NC}"
}

# Ask if user wants to install required packages
read -p "Would you like to install required packages for Aider Gemini Pro? (y/n): " INSTALL_PACKAGES
if [[ "$INSTALL_PACKAGES" =~ ^[Yy]$ ]]; then
    install_packages
fi

# Ask if user wants to install aider as a uv tool
read -p "Would you like to install aider as a uv tool? (y/n): " INSTALL_AIDER
if [[ "$INSTALL_AIDER" =~ ^[Yy]$ ]]; then
    install_aider
fi

# Run the main setup script to update .zshrc with aliases
read -p "Would you like to update your .zshrc with Aider aliases? (y/n): " UPDATE_ZSHRC
if [[ "$UPDATE_ZSHRC" =~ ^[Yy]$ ]]; then
    echo "Running setup.sh to update .zshrc..."
    ./setup.sh
fi

echo
echo -e "${GREEN}Setup complete!${NC}"
echo -e "${YELLOW}Remember:${NC}"
echo "1. To use UV in future scripts, check if it's installed with:"
echo "   command -v uv &> /dev/null"
echo
echo "2. For isolated package installation, use:"
echo "   uv pip install --system <package-name>"
echo
echo "3. For Aider with Gemini Pro (aider pro command), you need:"
echo "   - GEMINI_API_KEY environment variable set"
echo "   - google-generativeai package installed"
echo
echo "4. To activate the changes to your shell configuration, run:"
echo "   source ~/.zshrc"
echo
echo "5. To use Aider with Gemini Pro, set the API key and run:"
echo "   export GEMINI_API_KEY=your_key"
echo "   aider pro"
echo
echo "This approach ensures your setup remains portable across different machines and repositories." 