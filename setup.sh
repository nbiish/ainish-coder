#!/bin/bash

# Get the absolute path of the repository
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create .gitignore file if it doesn't exist
if [ ! -f "${REPO_DIR}/.gitignore" ]; then
  echo "Creating .gitignore file..."
  cat > "${REPO_DIR}/.gitignore" << EOF
# Ignore Aider history files but keep configs
.aider.chat.history.md
.aider.input.history
.aider.*.json
.aider.llm.history
.env

# Don't ignore our configuration directories
!mai-aider/
!mai-aider/configs/
!mai-aider/.env.example
EOF
else
  # Update .gitignore to keep our configuration files but ignore .env
  if grep -q "^.aider\*" "${REPO_DIR}/.gitignore"; then
    echo "Updating .gitignore to keep configuration files..."
    sed -i '' 's/^.aider\*$/# Ignore Aider history files but keep configs\n.aider.chat.history.md\n.aider.input.history\n.aider.*.json\n.aider.llm.history\n.env\n\n# Don'\''t ignore our configuration directories\n!mai-aider\/\n!mai-aider\/configs\/\n!mai-aider\/.env.example/' "${REPO_DIR}/.gitignore"
  fi
fi

# Set up .env file if it doesn't exist
if [ ! -f "${REPO_DIR}/mai-aider/.env" ]; then
  if [ -f "${REPO_DIR}/mai-aider/.env.example" ]; then
    echo "Setting up .env file from example..."
    cp "${REPO_DIR}/mai-aider/.env.example" "${REPO_DIR}/mai-aider/.env"
    echo "Please edit ${REPO_DIR}/mai-aider/.env to add your API keys."
  else
    echo "Warning: .env.example not found. Please manually create .env file."
  fi
fi

# Create or update AIDER_CONFIG section in .zshrc
ZSHRC="${HOME}/.zshrc"
if [ -f "$ZSHRC" ]; then
  echo "Updating .zshrc with Aider configurations..."
  
  # Check if AIDER_CONFIG section exists
  if grep -q "### AIDER ALIASES ###" "$ZSHRC"; then
    # Remove existing AIDER_CONFIG section
    sed -i '' '/### AIDER ALIASES ###/,/### END AIDER ALIASES ###/d' "$ZSHRC"
  fi
  
  # Remove Vertex AI settings if they exist
  sed -i '' '/# VERTEX AI SETTINGS/,/# END VERTEX AI SETTINGS/d' "$ZSHRC" 2>/dev/null || true
  
  # Add new AIDER_CONFIG section
  cat >> "$ZSHRC" << EOF

# AIDER configuration
export AIDER_DARK_MODE=true

### AIDER ALIASES ###
# Create a shell function for Aider that handles different configurations
# API keys are expected to be in the environment when running aider
aider() {
  case "\$1" in
    smart)
      shift
      # Using architect mode with R1 as architect and Claude 3.5 Sonnet as editor
      command aider --architect --model r1 --editor-model openrouter/anthropic/claude-3.5-sonnet "\$@"
      ;;
    r1)
      shift
      command aider --model r1 --edit-format diff "\$@"
      ;;
    v3)
      shift
      # Using DeepSeek Chat model with diff edits
      command aider --model deepseek/deepseek-chat --edit-format diff "\$@"
      ;;
    pro)
      shift
      # Using Gemini 2.0 Pro model with whole edits
      command aider --model gemini/gemini-2.0-pro-exp-02-05 --edit-format whole --no-show-model-warnings "\$@"
      ;;
    *)
      command aider "\$@"
      ;;
  esac
}
### END AIDER ALIASES ###
EOF

  echo "Aider configuration added to .zshrc"
else
  echo "Warning: ~/.zshrc not found. Please manually add the Aider configuration."
fi

# Check if the required Python package for Gemini is installed
# First check if uv is available
if command -v uv &> /dev/null; then
  # Use uv if available - using pip mode within uv to keep libraries isolated
  if ! uv pip list | grep -q "google-generativeai"; then
    echo "Installing required Python packages for Gemini using uv..."
    # Using --system to ensure we're not creating a new virtualenv
    uv pip install --system google-auth google-auth-oauthlib google-generativeai
    
    # If aider was installed as a uv tool, also install these packages in the aider environment
    if command -v uv tool list | grep -q "aider-chat"; then
      echo "Installing Google packages for aider UV tool..."
      UV_TOOL_DIR=$(dirname "$(command -v aider)")
      UV_ENV_DIR=$(dirname "$UV_TOOL_DIR")
      
      # Use uv pip to install packages to the aider tool environment
      PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
      uv pip install --python "$PYTHON_VERSION" --target "$UV_ENV_DIR/lib/python$PYTHON_VERSION/site-packages" google-auth google-auth-oauthlib google-generativeai
    fi
  fi
else
  # Fall back to pip if uv is not available
  if ! pip list | grep -q "google-generativeai"; then
    echo "Installing required Python packages for Gemini using pip..."
    pip install google-auth google-auth-oauthlib google-generativeai
    echo "Tip: For faster package installation, consider using 'uv': https://github.com/astral-sh/uv"
    echo "     Install with: curl -sSf https://astral.sh/uv/install.sh | sh"
  fi
fi

echo "Setup complete! To activate the changes, run:"
echo "source ~/.zshrc"
echo ""
echo "⚠️ Important: Set your API keys before running aider commands with:" 
echo "OPENROUTER_API_KEY=your_key GEMINI_API_KEY=your_key DEEPSEEK_API_KEY=your_key aider <command>"
echo ""
echo "You can also set them for your whole shell session with:"
echo "export OPENROUTER_API_KEY=your_key"
echo "export GEMINI_API_KEY=your_key"
echo "export DEEPSEEK_API_KEY=your_key" 