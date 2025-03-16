#!/bin/bash

# MAI-Coder All-in-One Setup Script
# This script sets up all tooling configurations in one go

# Get the absolute path of the repository
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="${HOME}/.zshrc"

# Print header
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                MAI-Coder Setup Script                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "🔧 Setting up MAI-Coder tooling configurations..."
echo ""

# Make all scripts executable
chmod +x "$REPO_DIR/setup.sh" "$REPO_DIR/install.sh" "$REPO_DIR/vscode-setup.sh" 2>/dev/null

# Run the main setup script for Aider
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│                Setting up Aider Configuration                    │"
echo "└─────────────────────────────────────────────────────────────────┘"
"$REPO_DIR/setup.sh"
echo ""

# Create the VS Code wrapper scripts
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│               Setting up VS Code Configuration                   │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo "🔧 Creating VS Code wrapper scripts..."
echo ""

# Create the VS Code setup script if it doesn't exist
if [ ! -f "$REPO_DIR/vscode-setup.sh" ]; then
  cat > "$REPO_DIR/vscode-setup.sh" << 'EOF'
#!/bin/bash

# Script to set up VS Code configuration files in a target directory

# Get the target directory from the command line argument or use the current directory
TARGET="${1:-.}"

# Get absolute path of target
if [[ "$TARGET" == "." ]]; then
  TARGET="$(pwd)"
elif [[ ! "$TARGET" =~ ^/ ]]; then
  TARGET="$(pwd)/$TARGET"
fi

# Check if the target is a directory
if [ ! -d "$TARGET" ]; then
  echo "Error: $TARGET is not a directory"
  exit 1
fi

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up VS Code/Copilot configuration for $TARGET"

# Copy configuration files
cp "$SCRIPT_DIR/mai-copilot/.copilotignore" "$TARGET/" 2>/dev/null
cp "$SCRIPT_DIR/mai-copilot/.rooignore" "$TARGET/" 2>/dev/null

# Create .github directory and copy copilot-instructions.md
mkdir -p "$TARGET/.github"
cp "$SCRIPT_DIR/mai-copilot/github/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null

# Update .gitignore if it exists
if [ -f "$TARGET/.gitignore" ]; then
  if ! grep -q ".copilotignore" "$TARGET/.gitignore"; then
    echo -e "\n# Copilot files\n.copilotignore\n.rooignore\n.github/copilot-instructions.md" >> "$TARGET/.gitignore"
    echo "Added Copilot entries to .gitignore"
  fi
else
  echo -e "# Copilot files\n.copilotignore\n.rooignore\n.github/copilot-instructions.md" > "$TARGET/.gitignore"
  echo "Created .gitignore with Copilot entries"
fi

echo "✅ VS Code/Copilot configuration setup complete for $TARGET"
EOF
  chmod +x "$REPO_DIR/vscode-setup.sh"
fi

# Add VS Code wrapper to .zshrc
if [ -f "$ZSHRC" ]; then
  echo "🔧 Updating .zshrc with VS Code wrapper function..."
  
  # Check if VS Code wrapper section exists
  if grep -q "### VS CODE WRAPPER ###" "$ZSHRC"; then
    # Remove existing VS Code wrapper section
    sed -i '' '/### VS CODE WRAPPER ###/,/### END VS CODE WRAPPER ###/d' "$ZSHRC"
  fi
  
  # Add new VS Code wrapper section
  cat >> "$ZSHRC" << EOF

### VS CODE WRAPPER ###
# VS Code wrapper function
vscode_wrapper() {
  # Get the target directory from the command line argument or use the current directory
  local TARGET="\${1:-.}"
  
  # Get absolute path of target
  if [[ "\$TARGET" == "." ]]; then
    TARGET="\$(pwd)"
  elif [[ ! "\$TARGET" =~ ^/ ]]; then
    TARGET="\$(pwd)/\$TARGET"
  fi
  
  # Check if the target is a directory
  if [ -d "\$TARGET" ]; then
    # Run the setup script
    "$REPO_DIR/vscode-setup.sh" "\$TARGET"
  fi
  
  # Run the original VS Code command
  if [[ "\$1" == "-"* ]]; then
    # If the first argument is an option, don't pass it as a path
    /Applications/Visual\\ Studio\\ Code\\ -\\ Insiders.app/Contents/Resources/app/bin/code "\$@"
  else
    # Otherwise, pass all arguments
    /Applications/Visual\\ Studio\\ Code\\ -\\ Insiders.app/Contents/Resources/app/bin/code "\$@"
  fi
}
alias code=vscode_wrapper
### END VS CODE WRAPPER ###
EOF

  echo "✅ VS Code wrapper function added to .zshrc"
  echo ""
else
  echo "⚠️  Warning: ~/.zshrc not found. Please manually add the VS Code wrapper function."
  echo ""
fi

# Run the install script to set up the wrappers for cursor and aider
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│               Setting up Cursor Configuration                    │"
echo "└─────────────────────────────────────────────────────────────────┘"
"$REPO_DIR/install.sh"
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                   MAI-Coder Setup Complete!                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "🔄 To activate all changes, run: source ~/.zshrc"
echo ""
echo "✨ Now you can use 'cursor', 'aider', and 'code' commands with your"
echo "   configurations automatically applied."
echo "" 