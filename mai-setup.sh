#!/bin/bash

# Get the absolute path of the repository
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "🤖 Setting up AI Pair Programmers 🤖"
echo "======================================"

# Check if Aider is installed
if ! command -v aider &> /dev/null; then
    echo "❌ Aider is not installed."
    echo "Would you like to install it? (y/n)"
    read -r install_aider
    if [[ "$install_aider" == "y" ]]; then
        echo "📦 Installing Aider..."
        pip install aider-chat
        if [ $? -eq 0 ]; then
            echo "✅ Aider installed successfully!"
        else
            echo "❌ Failed to install Aider. Please install manually."
        fi
    else
        echo "⏭️ Skipping Aider installation."
    fi
else
    echo "✅ Aider is already installed."
fi

# Set up Aider configuration
echo "🔧 Setting up Aider configuration..."
./setup.sh

# Check if Cursor is installed
if ! command -v cursor &> /dev/null; then
    echo "❌ Cursor is not installed."
    echo "Would you like to download Cursor? (y/n)"
    read -r install_cursor
    if [[ "$install_cursor" == "y" ]]; then
        echo "🌐 Opening Cursor download page..."
        open "https://cursor.sh/download"
        echo "⚠️ Please install Cursor manually from the website."
    else
        echo "⏭️ Skipping Cursor installation."
    fi
else
    echo "✅ Cursor is already installed."
fi

# Check if VS Code is installed
if ! command -v code &> /dev/null; then
    echo "❌ VS Code is not installed."
    echo "Would you like to download VS Code? (y/n)"
    read -r install_vscode
    if [[ "$install_vscode" == "y" ]]; then
        echo "🌐 Opening VS Code download page..."
        open "https://code.visualstudio.com/download"
        echo "⚠️ Please install VS Code manually from the website."
    else
        echo "⏭️ Skipping VS Code installation."
    fi
else
    echo "✅ VS Code is already installed."
    
    # Check if GitHub Copilot extension is installed
    if ! code --list-extensions | grep -q "GitHub.copilot"; then
        echo "❌ GitHub Copilot extension is not installed."
        echo "Would you like to install it? (y/n)"
        read -r install_copilot
        if [[ "$install_copilot" == "y" ]]; then
            echo "📦 Installing GitHub Copilot extension..."
            code --install-extension GitHub.copilot
            if [ $? -eq 0 ]; then
                echo "✅ GitHub Copilot extension installed successfully!"
            else
                echo "❌ Failed to install GitHub Copilot extension. Please install manually."
            fi
        else
            echo "⏭️ Skipping GitHub Copilot extension installation."
        fi
    else
        echo "✅ GitHub Copilot extension is already installed."
    fi
fi

echo "======================================"
echo "✅ AI Pair Programmer Setup Complete! ✅"
echo "======================================"
echo "To activate the changes, run:"
echo "source ~/.zshrc" 