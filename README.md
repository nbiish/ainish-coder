# mai-coder

A comprehensive configuration manager for AI coding assistants, providing seamless setup and integration for multiple AI development tools in your projects.

## 🌟 Features

- **Unified Setup**: One script to configure all your AI coding assistants
- **Multiple AI Tool Support**: 
  - `mai-aider`: Configuration for the Aider AI pair programming assistant
  - `mai-cursor`: Cursor IDE specific configurations and ignore files
  - `mai-copilot`: GitHub Copilot and related tool configurations
- **Automatic Configuration**: Gitignore rules and tool-specific ignore files included with each component

## 🚀 Installation

```bash
# Clone the repository
git clone https://github.com/nbiish/mai-coder
cd mai-coder

# Make the setup script executable
chmod +x mai-setup.sh

# Run the setup script
./mai-setup.sh
```

## 📦 Components

### mai-aider
- `.aider.conf.yml`: Core configuration file
- `.aider-instructions.md`: Custom instructions for the Aider assistant
- `.aiderignore`: File patterns to exclude from Aider
- `.env.example`: Environment variable template

### mai-cursor
- `.cursor/`: Cursor IDE configuration directory
- `.cursorignore`: Rules for files to exclude from Cursor AI
- `.cursorindexingignore`: Rules for files to exclude from indexing

### mai-copilot
- `.copilotignore`: Rules for files to exclude from GitHub Copilot
- `.rooignore`: Rules for the Roo extension
- `.github/`: GitHub specific configurations

## 🔧 How It Works

The `mai-setup.sh` script:
1. Creates a `~/.mai-coder` directory to store all configurations
2. Copies tool configurations to their appropriate directories
3. Updates or creates `.gitignore` with AI-specific entries
4. Adds wrapper functions to your shell configuration
5. Verifies all components are properly installed

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License 

Copyright © 2025 ᓂᐲᔥ Nbiish-Justin Kenwabikise ᑭᓇᐙᐱᑭᓯ. All rights reserved.

COMPREHENSIVE RESTRICTED USE LICENSE WITH TRIBAL SOVEREIGNTY PROTECTIONS

This software is created by ᓂᐲᔥ Nbiish-Justin Kenwabikise ᑭᓇᐙᐱᑭᓯ, a member of the Grand Traverse Band of Ottawa and Chippewa Indians, a federally recognized sovereign tribal nation. This license is grounded in the inherent sovereignty of Indigenous peoples to protect, control, and govern the use of their intellectual and cultural property.

See the [LICENSE](LICENSE) file for complete details.

## 📚 Citation (BibTeX Format) 

```bibtex
@misc{mai-coder2025,
  author = {ᓂᐲᔥ Nbiish-Justin Kenwabikise ᑭᓇᐙᐱᑭᓯ},
  title = {mai-coder},
  year = {2025},
  publisher = {GitHub},
  journal = {GitHub repository},
  howpublished = {\url{https://github.com/nbiish/mai-coder}},
  note = {Created by a member of the Grand Traverse Band of Ottawa and Chippewa Indians, protected under tribal sovereignty and treaty rights}
}
``` 