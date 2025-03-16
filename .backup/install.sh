#!/bin/bash

# MAI-Coder Installation Script
INSTALL_DIR="$HOME/mai-coder-install"
CONFIG_DIR="$INSTALL_DIR/configs"
BIN_DIR="$INSTALL_DIR/bin"

echo "Installing MAI-Coder to $INSTALL_DIR..."

# Create installation directories
mkdir -p "$CONFIG_DIR"/{aider,cursor,copilot}
mkdir -p "$BIN_DIR"

# Copy configuration files
echo "Copying configuration files..."
cp -r mai-aider/* "$CONFIG_DIR/aider/"
cp -r mai-cursor/* "$CONFIG_DIR/cursor/"
cp -r mai-copilot/* "$CONFIG_DIR/copilot/"

# Ensure we don't overwrite the .cursorrules file
echo "Using the provided .cursorrules file directly from mai-cursor directory"

# Create wrapper scripts
echo "Creating wrapper scripts..."

# License check function for all wrappers
cat > "$BIN_DIR/license_check.sh" << 'EOF'
#!/bin/bash

# Function to ensure README.md has the license citation
check_license() {
  local TARGET_DIR="$1"
  local REPO_NAME=$(basename "$TARGET_DIR")
  local YEAR="2025"
  local README="$TARGET_DIR/README.md"
  
  # Check if README.md exists
  if [ -f "$README" ]; then
    # Check if license citation already exists
    if ! grep -q "@misc{$REPO_NAME" "$README"; then
      # Add license citation at the end of the file
      echo -e "\n@misc{$REPO_NAME$YEAR,\n  author = {ᓂᐲᔥ Nbiish-Justin Kenwabikise ᑭᓇᐙᐱᑭᓯ},\n  title = {$REPO_NAME}},\n  year = {$YEAR},\n  publisher = {GitHub},\n  journal = {GitHub repository},\n  howpublished = {\\url{https://github.com/nbiish/$REPO_NAME}},\n}" >> "$README"
      echo "Added license citation to $README"
    fi
  else
    # Create README.md with license citation
    echo -e "# $REPO_NAME\n\n@misc{$REPO_NAME$YEAR,\n  author = {ᓂᐲᔥ Nbiish-Justin Kenwabikise ᑭᓇᐙᐱᑭᓯ},\n  title = {$REPO_NAME}},\n  year = {$YEAR},\n  publisher = {GitHub},\n  journal = {GitHub repository},\n  howpublished = {\\url{https://github.com/nbiish/$REPO_NAME}},\n}" > "$README"
    echo "Created $README with license citation"
  fi
}
EOF

chmod +x "$BIN_DIR/license_check.sh"

# Cursor wrapper
cat > "$BIN_DIR/cursor" << 'EOF'
#!/bin/bash

# Prevent infinite recursion
if [ ! -z "$MAI_CODER_ACTIVE" ]; then
  # Find cursor executable path
  CURSOR_PATH=$(which -a cursor | grep -v "$HOME/mai-coder-install/bin/cursor" | head -n 1)
  if [ -z "$CURSOR_PATH" ]; then
    # Try common locations
    if [ -f "/usr/local/bin/cursor" ]; then
      CURSOR_PATH="/usr/local/bin/cursor"
    elif [ -f "/usr/bin/cursor" ]; then
      CURSOR_PATH="/usr/bin/cursor"
    elif [ -f "/opt/cursor/cursor" ]; then
      CURSOR_PATH="/opt/cursor/cursor"
    elif [ -f "$HOME/.local/bin/cursor" ]; then
      CURSOR_PATH="$HOME/.local/bin/cursor"
    elif [ -f "/Applications/Cursor.app/Contents/MacOS/Cursor" ]; then
      CURSOR_PATH="/Applications/Cursor.app/Contents/MacOS/Cursor"
    else
      echo "Error: Could not find the original cursor executable. Please specify its location."
      exit 1
    fi
  fi
  
  # Execute original cursor command
  exec "$CURSOR_PATH" "$@"
  exit 0
fi

export MAI_CODER_ACTIVE=1

TARGET="${1:-.}"

# Get absolute path of target
if [[ "$TARGET" == "." ]]; then
  TARGET="$(pwd)"
elif [[ ! "$TARGET" =~ ^/ ]]; then
  TARGET="$(pwd)/$TARGET"
fi

if [ -d "$TARGET" ]; then
  # Copy cursor configuration files
  echo "Setting up cursor configuration for $TARGET"
  cp "$HOME/mai-coder-install/configs/cursor/.cursorignore" "$TARGET/" 2>/dev/null
  cp "$HOME/mai-coder-install/configs/cursor/.cursorindexingignore" "$TARGET/" 2>/dev/null
  cp "$HOME/mai-coder-install/configs/cursor/.cursorrules" "$TARGET/" 2>/dev/null
  cp "$HOME/mai-coder-install/configs/cursor/my-license.mdc" "$TARGET/" 2>/dev/null
  
  # Create .gitignore if it doesn't exist or add entries if it does
  if [ ! -f "$TARGET/.gitignore" ]; then
    echo -e "# Cursor files\n.cursor/\n.cursorignore\n.cursorindexingignore\n.cursorrules" > "$TARGET/.gitignore"
    echo "Created .gitignore with cursor entries"
  elif ! grep -q ".cursor/" "$TARGET/.gitignore" || ! grep -q ".cursorignore" "$TARGET/.gitignore"; then
    echo -e "\n# Cursor files\n.cursor/\n.cursorignore\n.cursorindexingignore\n.cursorrules" >> "$TARGET/.gitignore"
    echo "Added cursor entries to .gitignore"
  fi
  
  # Apply license check
  source "$HOME/mai-coder-install/bin/license_check.sh"
  check_license "$TARGET"
fi

# Find cursor executable path
CURSOR_PATH=$(which -a cursor | grep -v "$HOME/mai-coder-install/bin/cursor" | head -n 1)
if [ -z "$CURSOR_PATH" ]; then
  # Try common locations
  if [ -f "/usr/local/bin/cursor" ]; then
    CURSOR_PATH="/usr/local/bin/cursor"
  elif [ -f "/usr/bin/cursor" ]; then
    CURSOR_PATH="/usr/bin/cursor"
  elif [ -f "/opt/cursor/cursor" ]; then
    CURSOR_PATH="/opt/cursor/cursor"
  elif [ -f "$HOME/.local/bin/cursor" ]; then
    CURSOR_PATH="$HOME/.local/bin/cursor"
  elif [ -f "/Applications/Cursor.app/Contents/MacOS/Cursor" ]; then
    CURSOR_PATH="/Applications/Cursor.app/Contents/MacOS/Cursor"
  else
    echo "Error: Could not find the original cursor executable. Please specify its location."
    exit 1
  fi
fi

# Execute original cursor command
exec "$CURSOR_PATH" "$@"
EOF

# Aider wrapper
cat > "$BIN_DIR/aider" << 'EOF'
#!/bin/bash

# Prevent infinite recursion
if [ ! -z "$MAI_CODER_ACTIVE" ]; then
  # Find aider executable path
  AIDER_PATH=$(which -a aider | grep -v "$HOME/mai-coder-install/bin/aider" | head -n 1)
  if [ -z "$AIDER_PATH" ]; then
    # Try common locations
    if [ -f "$HOME/.local/bin/aider" ]; then
      AIDER_PATH="$HOME/.local/bin/aider"
    elif [ -f "/usr/local/bin/aider" ]; then
      AIDER_PATH="/usr/local/bin/aider"
    elif [ -f "/usr/bin/aider" ]; then
      AIDER_PATH="/usr/bin/aider"
    else
      echo "Error: Could not find the original aider executable. Using 'aider' command."
      AIDER_PATH="aider"
    fi
  fi
  
  # Execute original aider command
  exec "$AIDER_PATH" "$@"
  exit 0
fi

export MAI_CODER_ACTIVE=1

TARGET="${1:-.}"

# Get absolute path of target
if [[ "$TARGET" == "." ]]; then
  TARGET="$(pwd)"
elif [[ ! "$TARGET" =~ ^/ ]]; then
  TARGET="$(pwd)/$TARGET"
fi

if [ -d "$TARGET" ]; then
  # Copy aider configuration files
  echo "Setting up aider configuration for $TARGET"
  cp "$HOME/mai-coder-install/configs/aider/.aider-instructions.md" "$TARGET/" 2>/dev/null
  cp "$HOME/mai-coder-install/configs/aider/.aiderignore" "$TARGET/" 2>/dev/null
  
  # If there's an aider config file, copy it too
  if [ -f "$HOME/mai-coder-install/configs/aider/.aider.conf.yml" ]; then
    cp "$HOME/mai-coder-install/configs/aider/.aider.conf.yml" "$TARGET/" 2>/dev/null
  fi
  
  # Apply license check
  source "$HOME/mai-coder-install/bin/license_check.sh"
  check_license "$TARGET"
  
  # Create .gitignore if it doesn't exist or add entries if it does
  if [ ! -f "$TARGET/.gitignore" ]; then
    echo -e "# Aider files\n.aider*\n.aider.conf.yml\n.aider.input.history\n.aider.chat.history.md" > "$TARGET/.gitignore"
    echo "Created .gitignore with aider entries"
  elif ! grep -q ".aider" "$TARGET/.gitignore"; then
    echo -e "\n# Aider files\n.aider*\n.aider.conf.yml\n.aider.input.history\n.aider.chat.history.md" >> "$TARGET/.gitignore"
    echo "Added aider entries to .gitignore"
  fi
fi

# Find aider executable path
AIDER_PATH=$(which -a aider | grep -v "$HOME/mai-coder-install/bin/aider" | head -n 1)
if [ -z "$AIDER_PATH" ]; then
  # Try common locations
  if [ -f "$HOME/.local/bin/aider" ]; then
    AIDER_PATH="$HOME/.local/bin/aider"
  elif [ -f "/usr/local/bin/aider" ]; then
    AIDER_PATH="/usr/local/bin/aider"
  elif [ -f "/usr/bin/aider" ]; then
    AIDER_PATH="/usr/bin/aider"
  else
    echo "Error: Could not find the original aider executable. Using 'aider' command."
    AIDER_PATH="aider"
  fi
fi

# Execute original aider command
exec "$AIDER_PATH" "$@"
EOF

# VS Code wrapper
cat > "$BIN_DIR/code" << 'EOF'
#!/bin/bash

# Prevent infinite recursion
if [ ! -z "$MAI_CODER_ACTIVE" ]; then
  # Find code executable path
  CODE_PATH=$(which -a code | grep -v "$HOME/mai-coder-install/bin/code" | head -n 1)
  if [ -z "$CODE_PATH" ]; then
    # Try common locations
    if [ -f "/usr/local/bin/code" ]; then
      CODE_PATH="/usr/local/bin/code"
    elif [ -f "/usr/bin/code" ]; then
      CODE_PATH="/usr/bin/code"
    elif [ -f "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]; then
      CODE_PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    else
      echo "Error: Could not find the original VS Code executable. Using 'code' command."
      CODE_PATH="code"
    fi
  fi
  
  # Execute original code command
  exec "$CODE_PATH" "$@"
  exit 0
fi

export MAI_CODER_ACTIVE=1

TARGET="${1:-.}"

# Get absolute path of target
if [[ "$TARGET" == "." ]]; then
  TARGET="$(pwd)"
elif [[ ! "$TARGET" =~ ^/ ]]; then
  TARGET="$(pwd)/$TARGET"
fi

if [ -d "$TARGET" ]; then
  # Copy VS Code and Copilot configuration files
  echo "Setting up VS Code/Copilot configuration for $TARGET"
  cp "$HOME/mai-coder-install/configs/copilot/.copilotignore" "$TARGET/" 2>/dev/null
  cp "$HOME/mai-coder-install/configs/copilot/.rooignore" "$TARGET/" 2>/dev/null
  
  # Create .github directory and copy copilot-instructions.md
  mkdir -p "$TARGET/.github"
  cp "$HOME/mai-coder-install/configs/copilot/github/.github/copilot-instructions.md" "$TARGET/.github/" 2>/dev/null
  
  # Create .vscode directory if it doesn't exist
  mkdir -p "$TARGET/.vscode"
  
  # Copy any VS Code settings if they exist
  if [ -d "$HOME/mai-coder-install/configs/copilot/vscode" ]; then
    cp -r "$HOME/mai-coder-install/configs/copilot/vscode"/* "$TARGET/.vscode/" 2>/dev/null
  fi
  
  # Apply license check
  source "$HOME/mai-coder-install/bin/license_check.sh"
  check_license "$TARGET"
  
  # Create .gitignore if it doesn't exist or add entries if it does
  if [ ! -f "$TARGET/.gitignore" ]; then
    echo -e "# VS Code files\n.vscode/\n# Copilot files\n.copilotignore\n.rooignore\n.github/copilot-instructions.md" > "$TARGET/.gitignore"
    echo "Created .gitignore with VS Code/Copilot entries"
  elif ! grep -q ".vscode/" "$TARGET/.gitignore" || ! grep -q ".copilotignore" "$TARGET/.gitignore"; then
    echo -e "\n# VS Code files\n.vscode/\n# Copilot files\n.copilotignore\n.rooignore\n.github/copilot-instructions.md" >> "$TARGET/.gitignore"
    echo "Added VS Code/Copilot entries to .gitignore"
  fi
fi

# Find code executable path
CODE_PATH=$(which -a code | grep -v "$HOME/mai-coder-install/bin/code" | head -n 1)
if [ -z "$CODE_PATH" ]; then
  # Try common locations
  if [ -f "/usr/local/bin/code" ]; then
    CODE_PATH="/usr/local/bin/code"
  elif [ -f "/usr/bin/code" ]; then
    CODE_PATH="/usr/bin/code"
  elif [ -f "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]; then
    CODE_PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  else
    echo "Error: Could not find the original VS Code executable. Using 'code' command."
    CODE_PATH="code"
  fi
fi

# Execute original code command
exec "$CODE_PATH" "$@"
EOF

# Make scripts executable
chmod +x "$BIN_DIR/cursor" "$BIN_DIR/aider" "$BIN_DIR/code"

# Update PATH in shell profile if needed
SHELL_PROFILE=""
if [ -f "$HOME/.zshrc" ]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_PROFILE="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
  SHELL_PROFILE="$HOME/.bash_profile"
fi

if [ -n "$SHELL_PROFILE" ]; then
  if ! grep -q "mai-coder-install/bin" "$SHELL_PROFILE"; then
    echo 'export PATH="$HOME/mai-coder-install/bin:$PATH"' >> "$SHELL_PROFILE"
    echo "Added $BIN_DIR to your PATH in $SHELL_PROFILE"
    echo "Please restart your terminal or run 'source $SHELL_PROFILE' to apply changes"
  else
    echo "$BIN_DIR is already in your PATH"
  fi
else
  echo "Could not find shell profile. Please manually add the following to your shell profile:"
  echo 'export PATH="$HOME/mai-coder-install/bin:$PATH"'
fi

echo "Installation complete!"
echo "Now when you use 'cursor', 'aider', or 'code' commands, configuration files will be automatically applied to your projects." 