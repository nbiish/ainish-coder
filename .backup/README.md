# MAI-Coder: My AI Pair Programmer Setup

This repository helps you set up and manage AI coding tools (Cursor, Aider, GitHub Copilot) with consistent configurations.

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/nbiish/mai-coder.git
   cd mai-coder
   ```

2. Run the setup script:
   ```bash
   ./mai-setup.sh
   ```

3. Apply the changes:
   ```bash
   source ~/.zshrc
   ```

That's it! Now when you use `cursor`, `aider`, or `code` commands, your AI tools will be automatically configured.

## What Does This Do?

When you run any of these commands:
- `cursor my-project/` - Opens Cursor IDE
- `aider my-project/` - Starts Aider pair programming
- `code my-project/` - Opens VS Code

MAI-Coder will automatically:
1. Add the right configuration files to your project
2. Keep AI tool files out of git
3. Set up proper license citations

## API Keys

You'll need these API keys to use Aider's different modes:

```bash
# Set in your shell:
export OPENROUTER_API_KEY=your_key  # For Claude 3.5 (aider smart)
export GEMINI_API_KEY=your_key      # For Gemini (aider pro)
export DEEPSEEK_API_KEY=your_key    # For DeepSeek (aider r1/v3)
```

## Aider Commands

After setup, you can use these Aider commands:
- `aider smart` - Best for complex tasks (uses Claude 3.5)
- `aider r1` - Good for reasoning tasks
- `aider v3` - Fast for simple changes
- `aider pro` - Uses Gemini for whole-file edits

## What Gets Added to Your Projects

When you use the commands, these files are automatically added:
- `.copilotignore` and `.rooignore` - For GitHub Copilot
- `.cursorignore` and `.cursorindexingignore` - For Cursor IDE
- `.aider-instructions.md` - For Aider
- License citation in README.md (if missing)

## License

@misc{mai-coder2025,
  author = {ᓂᐲᔥ Nbiish-Justin Kenwabikise ᑭᓇᐙᐱᑭᓯ},
  title = {mai-coder},
  year = {2025},
  publisher = {GitHub},
  journal = {GitHub repository},
  howpublished = {\url{https://github.com/nbiish/mai-coder}},
}
