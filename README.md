# MAI-Coder: My AI Pair Programmer Setup

This repository contains configuration files and setup scripts for various AI pair programming tools. The main goal is to help manage AI coding tool configurations and ensure their files don't get committed to your projects.

## Purpose

This repository solves the following problems:

1. **Keep AI Tool Files Out of Your Projects**: Provides comprehensive `.gitignore` settings for Aider, Cursor, GitHub Copilot, and other AI tools
2. **Standardize AI Tool Configurations**: Maintains optimal settings for each AI coding tool
3. **Quick Setup**: Quickly configure any machine for AI pair programming
4. **Environment Variable Management**: Helps manage API keys safely without storing them in git

## Quick Setup

To set up all AI pair programmers at once:

```bash
git clone https://github.com/yourusername/mai-coder.git
cd mai-coder
chmod +x ./mai-setup.sh     # Make sure the script is executable
./mai-setup.sh
source ~/.zshrc
```

The `mai-setup.sh` script will:
1. Check if Aider is installed and offer to install it if needed
2. Configure Aider with custom profiles
3. Check if Cursor is installed and offer to download it
4. Check if VS Code is installed and offer to install GitHub Copilot

For Aider setup only:

```bash
chmod +x ./setup.sh        # Make sure the script is executable  
./setup.sh
source ~/.zshrc
```

## How to Use with Your Projects

After setup, you have three main ways to use these configurations with your projects:

### 1. Use the Setup Project Script (Recommended)

The easiest way to set up your project with AI tool configurations is to use the provided script:

```bash
# Make the script executable if needed
chmod +x ./setup-project.sh

# Run the setup project script
./setup-project.sh
```

The script will:
- Ask for the path to your project directory
- Create a git repository if needed
- Add appropriate entries to .gitignore
- Copy configuration files for the AI tools you choose
- Guide you through the setup process

### 2. Copy Configuration Files Manually

```bash
# Copy the appropriate ignore files to your project
cp mai-cursor/.cursorignore your-project/
cp mai-cursor/.cursorindexingignore your-project/
cp mai-aider/.aider-instructions.md your-project/
```

### 3. Create a Custom Script

You can create your own script based on `setup-project.sh` to set up projects according to your specific needs.

## API Keys

You'll need API keys for the services you want to use. After running setup, you can set the keys in your shell environment:

```bash
# Set API keys for a single aider command
OPENROUTER_API_KEY=your_key GEMINI_API_KEY=your_key DEEPSEEK_API_KEY=your_key aider smart

# Or set them for your entire shell session
export OPENROUTER_API_KEY=your_key
export GEMINI_API_KEY=your_key
export DEEPSEEK_API_KEY=your_key
```

This repository is designed to use environment variables directly, so you don't need to edit any files. Just ensure the following keys are available in your environment as needed:

- `OPENROUTER_API_KEY` - For OpenRouter services (used by `aider smart` for Claude 3.5)
- `GEMINI_API_KEY` - For Gemini models (used by `aider pro`)
- `DEEPSEEK_API_KEY` - For DeepSeek models (used by `aider r1` and `aider v3`)

### Gemini Setup

The Gemini Pro model (`aider pro`) requires the Google Generative AI package:

1. **Install Required Package**:
   Our setup script will automatically install the necessary package, but you can also install it manually:
   
   ```bash
   # Using UV (recommended for faster installation)
   uv pip install --system google-auth google-auth-oauthlib google-generativeai
   
   # Or using standard pip
   pip install google-auth google-auth-oauthlib google-generativeai
   ```

2. **UV Tool Installation** (Optional but Recommended):
   If you prefer to install aider as a UV tool for better isolation:
   
   ```bash
   # Install UV if needed
   curl -sSf https://astral.sh/uv/install.sh | sh
   
   # Install aider with UV
   uv tool install --force --python python3.12 aider-chat@latest
   
   # Install required Google packages for the aider tool environment
   UV_TOOL_DIR=$(dirname "$(command -v aider)")
   UV_ENV_DIR=$(dirname "$UV_TOOL_DIR")
   TOOL_PYTHON_VERSION=$(ls "$UV_ENV_DIR/lib/" | grep python | head -1)
   uv pip install --target "$UV_ENV_DIR/lib/$TOOL_PYTHON_VERSION/site-packages" \
       google-auth google-auth-oauthlib google-generativeai
   ```

3. **Ready to Use**:
   After setting up and sourcing your .zshrc:
   ```bash
   source ~/.zshrc
   
   # Set your Gemini API key
   export GEMINI_API_KEY=your_key
   
   # Use aider with Gemini Pro
   aider pro
   ```

## How It Works

This repository organizes AI tool configurations into dedicated directories:

- `mai-aider/` - Aider configurations
- `mai-cursor/` - Cursor IDE configurations 
- `mai-copilot/` - GitHub Copilot configurations

The setup scripts:
1. Install necessary tools or prompt you to download them
2. Configure your shell with Aider aliases
3. Copy configuration files where needed
4. Set up the proper gitignore rules to keep AI tool files out of your repositories

## Aider Profiles

Aider is configured with several custom commands:

- `aider` - Default Aider with standard settings
- `aider smart` - Architect mode using R1 (DeepSeek-Reasoner) as the architect model and Claude 3.5 Sonnet as the editor model
- `aider r1` - DeepSeek-Reasoner with diff edits
- `aider v3` - DeepSeek Chat model with diff edits
- `aider pro` - Gemini 2.0 Pro model with whole edits

## Repository Structure

```
mai-coder/
├── mai-aider/                 # Aider configurations
│   ├── .env.example           # Template for API keys
│   └── .aider-instructions.md # Instructions for Aider
├── mai-copilot/               # GitHub Copilot configurations
│   └── .copilotignore         # Copilot ignore file
├── mai-cursor/                # Cursor configurations
│   ├── .cursorignore          # Cursor ignore file
│   ├── .cursorindexingignore  # Cursor indexing ignore
│   └── .cursorrules           # Cursor rules
├── .cursor/                   # Cursor rules directory (for this repo)
│   └── rules/                 # Rules applied in Cursor
├── setup.sh                   # Aider-specific setup script
├── mai-setup.sh               # Master setup script for all AI tools
├── uv-setup.sh                # UV package manager setup
├── setup-project.sh           # Tool to set up configurations in any project
└── README.md                  # This file
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[MIT License] 