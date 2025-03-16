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
