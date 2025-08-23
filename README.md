# ◈──◆──◇ ainish-coder ◇──◆──◈

<div align="center">
  <h2>A comprehensive configuration manager for AI coding assistants</h2>
  <p>Seamless setup and integration for multiple AI development tools in your projects.</p>

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

<div align="center">
◈──◆──◇─────────────────────────────────────────────────◇──◆──◈
</div>

## ᐴ GASHKITOONAN ᔔ [Capabilities] ◈──◆──◇──◆──◈

- **◇ Unified Setup ◇**: One script (`ainish-setup.sh`) to configure all your AI coding assistants.
- **◇ Automatic File Distribution ◇**: The setup script automatically distributes key files (`critical.mdc`, `modern-prompting.mdc`, `mdc-headers.md`, `docs-use.mdc`, `informing.mdc`, `security.mdc`, `PRD.mdc`, `anishinaabe-cyberpunk-style.mdc`) to appropriate tool directories.
- **◇ Multiple AI Tool Support ◇**: Unified configuration system for all AI coding tools.
- **◇ Automatic Configuration ◇**: Includes Gitignore rules and comprehensive configuration files.
- **◇ Wrapper Functions ◇**: Sets up convenient shell commands (`ainish-coder`) for easy deployment.

<div align="center">
◈──◆──◇─────────────────────────────────────────────────◇──◆──◈
</div>

## ᐴ NITAM-AABAJICHIGANAN ᔔ [Prerequisites] ◈──◆──◇──◆──◈

Before installation, ensure you have:

- **macOS** (script is currently optimized for macOS)
- **Zsh** as your shell (default on modern macOS)
- **Cursor AI** (~1GB, download from [cursor.so](https://cursor.so)) - recommended for optimal experience

The script will check for Cursor availability but can still set up configurations even if it's missing.

<div align="center">
◈──◆──◇─────────────────────────────────────────────────◇──◆──◈
</div>

## ᐴ AABAJITOOWINAN ᔔ [Installation] ◈──◆──◇──◆──◈

```bash
# Clone the repository (if you haven't already)
git clone https://github.com/nbiish/ainish-coder
cd ainish-coder

# Make the setup script executable
chmod +x ainish-setup.sh

# Run the setup script
# This performs the full setup/update process:
# 1. Distributes files (critical.mdc, modern-prompting.mdc, mdc-headers.md, etc.) to tool directories
# 2. Sets up ~/.ainish-coder with symlinks
# 3. Installs/Updates wrapper functions in .zshrc
./ainish-setup.sh
```

After installation or update, you may need to run `source ~/.zshrc` (or your shell's equivalent) to activate the latest wrapper functions.

### Using Wrapper Functions

After installation, you'll have access to this convenient wrapper command:

```bash
# Deploy all configurations to current directory
ainish-coder
```

This wrapper function automatically ensures the latest configuration files are deployed to your current directory.

### Updating

To update later, simply pull the latest changes into the repository directory and re-run `./ainish-setup.sh`.

<div align="center">
◈──◆──◇─────────────────────────────────────────────────◇──◆──◈
</div>

## ᐴ WAAWIINDAMAAGEWIN ᔔ [Overview] ◈──◆──◇──◆──◈

```text
ainish-coder/
├── ainish-setup.sh              # Main setup and distribution script
├── critical.mdc                 # License citation file (distributed to all tools)
├── modern-prompting.mdc         # Advanced cognitive framework for LLM interactions
├── security.mdc                 # Comprehensive security and cybersecurity framework
├── docs-use.mdc                 # Documentation usage guidelines
├── informing.mdc                # Code documentation requirements
├── PRD.mdc                      # Universal Product Requirements Document template
├── mdc-headers.md               # MDC header definitions and documentation
├── non-cursor-prepend.md        # Content to prepend to non-Cursor prompts
├── anishinaabe-cyberpunk-style.mdc  # Styling guide

└── TEST_DIR/                    # Testing directory
```

<div align="center">
◈──◆──◇─────────────────────────────────────────────────◇──◆──◈
</div>

## ᐴ GASHKITOONAN ᔔ [Capabilities] ◈──◆──◇──◆──◈

### Unified Configuration System

The setup script deploys all configuration files to a single `ainish-coder/` directory in your target location, including:

- `critical.mdc`: License citation file
- `modern-prompting.mdc`: Advanced cognitive framework for LLM interactions
- `security.mdc`: Comprehensive security and cybersecurity framework
- `docs-use.mdc`: Documentation usage guidelines
- `informing.mdc`: Code documentation requirements
- `PRD.mdc`: Universal Product Requirements Document template
- `anishinaabe-cyberpunk-style.mdc`: Styling guide combining Anishinaabe elements with cyberpunk aesthetics
- `.gitignore`: Standard Git ignore rules
- `.cursorrules`: Rules for Cursor AI (if applicable)

<div align="center">
◈──◆──◇─────────────────────────────────────────────────◇──◆──◈
</div>

## ᐴ INAABAJICHIGAN ᔔ [Usage] ◈──◆──◇──◆──◈

The `ainish-setup.sh` script:

1. Automatically distributes `critical.mdc`, `modern-prompting.mdc`, `security.mdc`, `docs-use.mdc`, `informing.mdc`, `PRD.mdc`, `mdc-headers.md`, and `anishinaabe-cyberpunk-style.mdc` from the root to their respective tool directories.
2. Creates a `~/.ainish-coder` directory.
3. Creates symbolic links from `~/.ainish-coder` to the repository configuration files, ensuring changes in the repo are reflected immediately.
4. Adds convenient wrapper functions (`ainish-coder`) to your shell configuration (`.zshrc`).
5. Cleans up potentially conflicting older configuration files.
6. Verifies tool paths.

The wrapper function (`ainish-coder`) ensures that the necessary configurations are deployed to the current working directory when you invoke it.

Re-running `./ainish-setup.sh` refreshes the entire setup, including re-distributing files and updating the wrappers.

<div align="center">
◈──◆──◇─────────────────────────────────────────────────◇──◆──◈
</div>

## ᐴ ONAAKONIGE ᔔ [Configuration] ◈──◆──◇──◆──◈

This project uses a unique **Anishinaabe-Cyberpunk** styling approach that combines elements from Anishinaabe culture with cyberpunk aesthetics. This is documented in `anishinaabe-cyberpunk-style.mdc`, which provides detailed guidelines on:

- Cultural context for symbol usage
- Markdown styling elements (headers, dividers, banners)
- Shell script styling patterns
- Standard Anishinaabe terms with translations
- Cyberpunk symbol reference guide

This styling creates a distinctive visual identity that:
- Honors Anishinaabe language and cultural elements
- Incorporates modern cyberpunk aesthetics for technical documentation
- Creates a visually compelling and cohesive project appearance

The style guide is automatically distributed to all tool directories, ensuring consistent formatting across documentation.

For examples of this styling, see the **Standard Anishinaabe Terms** section in `anishinaabe-cyberpunk-style.mdc`.

<div align="center">
◈──◆──◇─────────────────────────────────────────────────◇──◆──◈
</div>

## ᐴ GIKENDAASOWIN ᔔ [MDC Headers] ◈──◆──◇──◆──◈

The `mdc-headers.md` file contains important header definitions that extend the functionality of MDC (Markdown Comments) within the AI coding assistant tools. These headers:

- Define document metadata and behaviors
- Control how documents interact with AI tools
- Set up globs patterns and document relationships
- Determine when and how documentation should be applied

MDC headers are crucial for creating effective AI tool configurations and are distributed to all three tools by the setup script.

<div align="center">
◈──◆──◇─────────────────────────────────────────────────◇──◆──◈
</div>

## ᐴ WIIDOOKAAZOWIN ᔔ [Contributing] ◈──◆──◇──◆──◈

Contributions are welcome! Please feel free to submit a Pull Request.

<div align="center">
◈──◆──◇─────────────────────────────────────────────────◇──◆──◈
</div>

## ᐴ GIGWEJIWEWIN ᔔ [Troubleshooting] ◈──◆──◇──◆──◈

### Common Issues

**Q: The wrapper functions aren't working after installation.**  
A: Try running `source ~/.zshrc` to reload your shell configuration.

**Q: I'm using a shell other than zsh, how do I set up the wrapper functions?**  
A: Copy the wrapper functions from `~/.zshrc` to your shell's configuration file (e.g., `~/.bashrc` for Bash).

**Q: Path validation fails during setup.**  
A: Edit the `ainish-setup.sh` file to update the `CURSOR_PATH` variable to match your system's Cursor installation path.

**Q: Files aren't being distributed to the tool directories.**  
A: Make sure you have the correct file structure in your repository. All root files (`critical.mdc`, etc.) should be in the main repository directory.

**Q: My changes to configuration files aren't taking effect.**  
A: The script uses symlinks to ensure changes to repository files are immediately available. If a file was modified directly in `~/.ainish-coder`, make sure to update the original file in the repository.

<div align="center">
◈──◆──◇─────────────────────────────────────────────────◇──◆──◈
</div>

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