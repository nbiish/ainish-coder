#!/bin/bash

# Get the absolute path of the repository
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

echo "Setup complete! To activate the changes, run:"
echo "source ~/.zshrc"
echo ""
echo "You can also set them for your whole shell session with:"
echo "export OPENROUTER_API_KEY=your_key"
echo "export GEMINI_API_KEY=your_key"
echo "export DEEPSEEK_API_KEY=your_key" 