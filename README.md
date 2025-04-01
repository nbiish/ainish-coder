# ainish-coder

<div align="center">
  <h3>A comprehensive configuration manager for AI coding assistants</h3>
  <p>Providing seamless setup and integration for multiple AI development tools in your projects.</p>

  <img src="qr-stripe-donation.png" alt="Scan to donate" width="200"/>
  <p>
    <a href="https://donate.stripe.com/3cs29La1j8UGfnObII">Scan to donate</a> |
    <a href="https://www.buymeacoffee.com/nbiish"><img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=&slug=nbiish&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff" /></a>
  </p>
</div>

## 🌟 Features

- **Unified Setup**: One script to configure all your AI coding assistants
- **Multiple AI Tool Support**: 
  - `ainish-aider`: Configuration for the Aider AI pair programming assistant
  - `ainish-cursor`: Cursor IDE specific configurations and ignore files
  - `ainish-copilot`: GitHub Copilot and related tool configurations
- **Automatic Configuration**: Gitignore rules and tool-specific ignore files included with each component

## 🚀 Installation

```bash
# Clone the repository
git clone https://github.com/nbiish/ainish-coder
cd ainish-coder

# Make the setup script executable
chmod +x ainish-setup.sh

# Run the setup script
./ainish-setup.sh
```

## 📦 Components

### ainish-aider
- `.aider.conf.yml`: Core configuration file
- `.aider-instructions.md`: Custom instructions for the Aider assistant
- `.aiderignore`: File patterns to exclude from Aider
- `.env.example`: Environment variable template
- `critical.mdc`: License citation file for Aider

### ainish-cursor
- `.cursor/`: Cursor IDE configuration directory
- `.cursorignore`: Rules for files to exclude from Cursor AI
- `.cursorindexingignore`: Rules for files to exclude from indexing

### ainish-copilot
- `.copilotignore`: Rules for files to exclude from GitHub Copilot
- `.rooignore`: Rules for the Roo extension
- `.github/`: GitHub specific configurations

## 🔧 How It Works

The `ainish-setup.sh` script:
1. Creates a `~/.ainish-coder` directory to store all configurations
2. Creates symbolic links to the original repo directories
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
@misc{ainish-coder2025,
  author = {ᓂᐲᔥ Nbiish-Justin Kenwabikise ᑭᓇᐙᐱᑭᓯ},
  title = {ainish-coder},
  year = {2025},
  publisher = {GitHub},
  journal = {GitHub repository},
  howpublished = {\url{https://github.com/nbiish/ainish-coder}},
  note = {Created by a member of the Grand Traverse Band of Ottawa and Chippewa Indians, protected under tribal sovereignty and treaty rights}
}
``` 