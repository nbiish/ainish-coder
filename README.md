# ainish-coder

<div align="center">
  <h2>A comprehensive configuration manager for AI coding assistants</h2>
  <p>Providing seamless setup and integration for multiple AI development tools in your projects.</p>

  <hr width="50%">
  
  <h3>Support This Project</h3>
  <div style="display: flex; justify-content: center; gap: 20px; margin: 20px 0;">
    <div>
      <h4>Stripe</h4>
      <img src="qr-stripe-donation.png" alt="Scan to donate" width="180"/>
      <p><a href="https://raw.githubusercontent.com/nbiish/license-for-all-works/8e9b73b269add9161dc04bbdd79f818c40fca14e/qr-stripe-donation.png">Donate via Stripe</a></p>
    </div>
    <div style="display: flex; align-items: center;">
      <a href="https://www.buymeacoffee.com/nbiish"><img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=&slug=nbiish&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff" /></a>
    </div>
  </div>
  
  <hr width="50%">
</div>

## 🌟 Features

- **Unified Setup**: One script (`ainish-setup.sh`) to configure all your AI coding assistants.
- **Automatic File Distribution**: The setup script automatically distributes key files (`critical.mdc`, `MEMORY-BANK.mdc`, `prompt.md`) to appropriate tool directories.
- **Multiple AI Tool Support**: 
  - `ainish-aider`: Configuration for the Aider AI pair programming assistant.
  - `ainish-cursor`: Cursor IDE specific configurations and ignore files.
  - `ainish-copilot`: GitHub Copilot and related tool configurations.
- **Automatic Configuration**: Includes Gitignore rules and tool-specific ignore files.
- **Wrapper Functions**: Sets up convenient shell commands (`ainish-cursor`, `ainish-aider`, `ainish-copilot`, `ainish-coder`) for easy tool usage.

## 🚀 Installation & Updating

```bash
# Clone the repository (if you haven't already)
git clone https://github.com/nbiish/ainish-coder
cd ainish-coder

# Make the setup script executable
chmod +x ainish-setup.sh

# Run the setup script
# This performs the full setup/update process:
# 1. Distributes files (critical.mdc, MEMORY-BANK.mdc, prompt.md) to tool directories
# 2. Sets up ~/.ainish-coder with symlinks
# 3. Installs/Updates wrapper functions in .zshrc
./ainish-setup.sh
```

After installation or update, you may need to run `source ~/.zshrc` (or your shell's equivalent) to activate the latest wrapper functions.

To update later, simply pull the latest changes into the repository directory and re-run `./ainish-setup.sh`.

## 📦 Components

### ainish-aider
- `.gitignore`: Standard Git ignore rules
- `aider-cli-commands.sh`: CLI commands for Aider
- `critical.mdc`: License citation file (from root `critical.mdc`)
- `MEMORY-BANK.mdc`: Project requirements doc (from root `MEMORY-BANK.mdc`)
- `docs-use.mdc`: Documentation usage guidelines (from root `docs-use.mdc`)

### ainish-cursor
- `.cursor/`: Cursor IDE configuration directory
- `.cursor/rules/gikendaasowin.md`: Cognitive Agent instructions (from `prompt.md`)
- `.cursor/rules/critical.mdc`: License citation file (from root `critical.mdc`)
- `.cursor/rules/MEMORY-BANK.mdc`: Project requirements doc (from root `MEMORY-BANK.mdc`)
- `.cursor/rules/docs-use.mdc`: Documentation usage guidelines (from root `docs-use.mdc`)

### ainish-copilot
- `.github/`: GitHub specific configurations
- `.github/critical.mdc`: License citation file (from root `critical.mdc`)
- `.github/MEMORY-BANK.mdc`: Project requirements doc (from root `MEMORY-BANK.mdc`)
- `.github/docs-use.mdc`: Documentation usage guidelines (from root `docs-use.mdc`)

## 🔧 How It Works

The `ainish-setup.sh` script:
1. Automatically distributes `critical.mdc`, `MEMORY-BANK.mdc`, `prompt.md`, and `docs-use.mdc` from the root to their respective tool directories.
2. Creates a `~/.ainish-coder` directory.
3. Creates symbolic links from `~/.ainish-coder` to the tool configuration directories (`ainish-aider`, `ainish-cursor`, `ainish-copilot`) in the repository, ensuring changes in the repo are reflected immediately.
4. Adds convenient wrapper functions (`ainish-cursor`, `ainish-aider`, etc.) to your shell configuration (`.zshrc`).
5. Cleans up potentially conflicting older configuration files.
6. Verifies tool paths.

The wrapper functions (`ainish-cursor`, `ainish-aider`, `ainish-copilot`, `ainish-coder`) ensure that the necessary configurations are deployed to the current working directory when you invoke the tool via the wrapper.

Re-running `./ainish-setup.sh` refreshes the entire setup, including re-distributing files and updating the wrappers.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License and Copyright

Copyright © 2025 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), a descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band, and an enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians. This work embodies Traditional Knowledge and Traditional Cultural Expressions. All rights reserved.

This project is protected under the COMPREHENSIVE RESTRICTED USE LICENSE WITH TRIBAL SOVEREIGNTY PROTECTIONS. See the [LICENSE](LICENSE) file for complete details.

## 📚 Citation

```bibtex
@misc{ainish-coder2025,
  author/creator/steward = {ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band and enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians},
  title/description = {ainish-coder},
  type_of_work = {Indigenous digital creation/software incorporating traditional knowledge and cultural expressions},
  year = {2025},
  publisher/source/event = {GitHub repository under tribal sovereignty protections},
  howpublished = {\url{https://github.com/nbiish/ainish-coder}},
  note = {Authored and stewarded by ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band and enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians. This work embodies Indigenous intellectual property, traditional knowledge systems (TK), traditional cultural expressions (TCEs), and associated data protected under tribal law, federal Indian law, treaty rights, Indigenous Data Sovereignty principles, and international indigenous rights frameworks including UNDRIP. All usage, benefit-sharing, and data governance are governed by the COMPREHENSIVE RESTRICTED USE LICENSE FOR INDIGENOUS CREATIONS WITH TRIBAL SOVEREIGNTY, DATA SOVEREIGNTY, AND WEALTH RECLAMATION PROTECTIONS.}
}
```