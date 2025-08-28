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
      <a href="https://www.buymeacoffee.com/nbiish"><img src="buymeacoffee-button.svg" alt="Buy me a coffee" /></a>
    </div>
  </div>
  
  <hr width="50%">
</div>

<div align="center">
◈──◆──◇─────────────────◇──◆──◈
</div>

## ᐴ GASHKITOONAN ᔔ [Capabilities] ◈──◆──◇──◆──◈

- **◇ Unified Setup ◇**: One script (`ainish-setup.sh`) to configure all your AI coding assistants.
- **◇ Automatic File Distribution ◇**: The setup script automatically distributes key files (`critical.mdc`, `modern-prompting.mdc`, `docs-use.mdc`, `informing.mdc`, `security.mdc`, `PRD.mdc`, `anishinaabe-cyberpunk-style.mdc`) to appropriate tool directories.
- **◇ Multiple AI Tool Support ◇**: Unified configuration system for all AI coding tools including GitHub Copilot, Cursor AI, and VSCode.
- **◇ Comprehensive Copilot Instructions ◇**: Consolidated development guidelines, security protocols, and best practices in `copilot-instructions.md` for optimal AI-assisted development.
- **◇ Flexible File Formats ◇**: Support for both `.mdc` and `.md` file formats with the `--markdown` flag.
- **◇ Automatic Configuration ◇**: Includes Gitignore rules and comprehensive configuration files.
- **◇ Wrapper Functions ◇**: Sets up convenient shell commands (`ainish-coder`) for easy deployment.

<div align="center">
◈──◆──◇─────────────────◇──◆──◈
</div>

## ᐴ NITAM-AABAJICHIGANAN ᔔ [Prerequisites] ◈──◆──◇──◆──◈

Before installation, ensure you have:

### **Required:**
- **Git** - Version control system
- **Terminal/Command Line Interface** - Built into your operating system

### **Recommended:**
- **Cursor AI** (~1GB, download from [cursor.so](https://cursor.so)) - Recommended for optimal experience
- **VSCode** - Alternative code editor with Copilot support

### **Operating System Support:**
- **macOS** - Fully supported with zsh/bash
- **Linux** - Fully supported with bash/zsh/fish
- **Windows** - Supported via PowerShell, Command Prompt, or WSL (Windows Subsystem for Linux)

The script will automatically detect your system and configure accordingly.

<div align="center">
◈──◆──◇─────────────────◇──◆──◈
</div>

## ᐴ AABAJITOOWINAN ᔔ [Installation] ◈──◆──◇──◆──◈

### **Step 1: Install Prerequisites**

#### **Git Installation:**
- **Windows:** Download from [git-scm.com](https://git-scm.com/download/win)
- **macOS:** Install via [Homebrew](https://brew.sh) with `brew install git` or download from git-scm.com
- **Linux:** Use your package manager:
  ```bash
  # Ubuntu/Debian
  sudo apt update && sudo apt install git
  
  # Fedora/RHEL
  sudo dnf install git
  
  # Arch Linux
  sudo pacman -S git
  ```

#### **Verify Git Installation:**
```bash
git --version
```
You should see something like `git version 2.39.0`

### **Step 2: Clone the Repository**

Open your terminal/command prompt and run:
```bash
# Clone the repository
git clone https://github.com/nbiish/ainish-coder

# Navigate into the directory
cd ainish-coder
```

### **Step 3: Platform-Specific Installation**

#### **macOS Installation:**
```bash
# Make the setup script executable
chmod +x ainish-setup.sh

# Run the setup script
./ainish-setup.sh
```

#### **Linux Installation:**
```bash
# Make the setup script executable
chmod +x ainish-setup.sh

# Run the setup script
./ainish-setup.sh
```

#### **Windows Installation:**

**Option A: PowerShell (Recommended)**
```powershell
# Navigate to the directory
cd ainish-coder

# Run the setup script
.\ainish-setup.sh
```

**Option B: Command Prompt**
```cmd
# Navigate to the directory
cd ainish-coder

# Run the setup script
ainish-setup.sh
```

**Option C: WSL (Windows Subsystem for Linux)**
```bash
# Navigate to the directory
cd ainish-coder

# Make the setup script executable
chmod +x ainish-setup.sh

# Run the setup script
./ainish-setup.sh
```

### **Step 4: Activate the Installation**

After running the setup script, you need to reload your shell configuration:

**macOS/Linux:**
```bash
source ~/.zshrc    # If using zsh
source ~/.bashrc   # If using bash
source ~/.config/fish/config.fish  # If using fish
```

**Windows PowerShell:**
```powershell
. $PROFILE
```

**Windows Command Prompt:**
```cmd
# Restart your command prompt
```

### **Step 5: Verify Installation**

Test that the installation worked:
```bash
# Check if the command is available
ainish-coder --help

# Or try the basic command
ainish-coder
```

You should see deployment messages and files being created in your current directory.

### **Quick Start for Experienced Users**

If you're familiar with command line tools, you can use this simplified installation:

```bash
# Clone and setup in one go
git clone https://github.com/nbiish/ainish-coder && cd ainish-coder && chmod +x ainish-setup.sh && ./ainish-setup.sh

# Reload shell (choose your shell)
source ~/.zshrc  # zsh
source ~/.bashrc  # bash
source ~/.config/fish/config.fish  # fish
. $PROFILE        # PowerShell
```

### Using Wrapper Functions

After installation, you'll have access to this convenient wrapper command:

```bash
# Deploy all configurations to current directory
ainish-coder

# Deploy all configurations as .md files to current directory
ainish-coder --markdown

# Deploy VSCode/Copilot configurations to .github directory
ainish-coder --vscode
```

This wrapper function automatically ensures the latest configuration files are deployed to your current directory.

### Updating

To update later, simply pull the latest changes into the repository directory and re-run `./ainish-setup.sh`.

<div align="center">
◈──◆──◇─────────────────◇──◆──◈
</div>

## ᐴ WAAWIINDAMAAGEWIN ᔔ [Overview] ◈──◆──◇──◆──◈

```text
ainish-coder/
├── ainish-setup.sh              # Main setup and distribution script
├── critical.mdc                 # Core AINISH configuration file
├── modern-prompting.mdc         # Advanced cognitive framework for LLM interactions
├── security.mdc                 # Comprehensive security and cybersecurity framework
├── docs-use.mdc                 # Documentation usage guidelines
├── informing.mdc                # Code documentation requirements
├── PRD.mdc                      # Universal Product Requirements Document template
├── prd-and-context.mdc          # PRD and context management rules
├── anishinaabe-cyberpunk-style.mdc  # Styling guide combining Anishinaabe elements with cyberpunk aesthetics
├── python-package-mgmt.mdc      # Python package management rules
├── verify-date-and-time.mdc     # Date and time verification rules
├── .gitignore                   # Standard Git ignore rules
├── .github/                     # GitHub configuration
│   └── FUNDING.yml             # Funding configuration for Sponsor button and donation links
├── ainish-vscode/               # VSCode/Copilot configurations
│   ├── .copilotignore          # Copilot ignore rules
│   ├── anishinaabe-cyberpunk-style.md  # VSCode styling guide
│   └── copilot-instructions.md # Comprehensive Copilot instruction set
└── .cursor/                     # Cursor AI configuration
    └── rules/                  # Cursor rules directory
```

<div align="center">
◈──◆──◇─────────────────◇──◆──◈
</div>

## ᐴ GASHKITOONAN ᔔ [Capabilities] ◈──◆──◇──◆──◈

### Triple Deployment System

The `ainish-coder` command provides three distinct deployment modes:

#### **Core AINISH Configurations** (`ainish-coder`)
Deploys essential AINISH configuration files to `./ainish-coder/` directory:
- `critical.mdc`: Core AINISH configuration file
- `modern-prompting.mdc`: Advanced cognitive framework for LLM interactions
- `security.mdc`: Comprehensive security and cybersecurity framework
- `docs-use.mdc`: Documentation usage guidelines
- `informing.mdc`: Code documentation requirements
- `PRD.mdc`: Universal Product Requirements Document template
- `prd-and-context.mdc`: PRD and context management rules
- `anishinaabe-cyberpunk-style.mdc`: Styling guide combining Anishinaabe elements with cyberpunk aesthetics
- `python-package-mgmt.mdc`: Python package management rules
- `verify-date-and-time.mdc`: Date and time verification rules
- `.gitignore`: Standard Git ignore rules
- `.github/FUNDING.yml`: GitHub funding configuration for Sponsor button and donation links

#### **Core AINISH Configurations (Markdown Format)** (`ainish-coder --markdown`)
Deploys essential AINISH configuration files as `.md` files to `./ainish-coder/` directory:
- All core configuration files converted from `.mdc` to `.md` format
- Same content and functionality as standard deployment
- Better compatibility with standard markdown tools and GitHub
- **Total: 13 configuration files (as .md)**

#### **VSCode/Copilot Configurations** (`ainish-coder --vscode`)
Deploys editor-specific configurations:
- `.cursor/rules/` directory: Cursor AI rule files
- `ainish-vscode/` directory: VSCode and Copilot configurations (including copilot-instructions.md and styling guides)

<div align="center">
◈──◆──◇─────────────────◇──◆──◈
</div>

## ᐴ INAABAJICHIGAN ᔔ [Usage] ◈──◆──◇──◆──◈

The `ainish-setup.sh` script:

1. Creates a `~/.ainish-coder` directory with symbolic links to repository configuration files.
2. Adds convenient wrapper functions (`ainish-coder`) to your shell configuration (`.zshrc`).
3. Cleans up potentially conflicting older configuration files.
4. Verifies tool paths.

### Wrapper Functions

After installation, you'll have access to these convenient wrapper commands:

#### **`ainish-coder`** - Core AINISH Configurations
Deploys essential AINISH configuration files to `./ainish-coder/` directory in your current location:
- Core configuration files (`.mdc` files)
- `.gitignore` file
- `.github/FUNDING.yml` file
- **Total: 13 configuration files**

#### **`ainish-coder --markdown`** - Core AINISH Configurations (Markdown Format)
Deploys essential AINISH configuration files as `.md` files to `./ainish-coder/` directory in your current location:
- Core configuration files (`.md` files converted from .mdc)
- `.gitignore` file
- `.github/FUNDING.yml` file
- **Total: 13 configuration files (as .md)**

#### **`ainish-coder --vscode`** - VSCode/Copilot Configurations
Deploys editor-specific configurations:
- `.cursor/rules/` directory: Cursor AI rule files
- `ainish-vscode/` directory: VSCode and Copilot configurations (including copilot-instructions.md and styling guides)
- **Total: 14+ VSCode/Copilot configuration files**

### Updating

To update later, simply pull the latest changes into the repository directory and re-run `./ainish-setup.sh`.

<div align="center">
◈──◆──◇─────────────────◇──◆──◈
</div>

## ᐴ ONAAKONIGE ᔔ [Configuration] ◈──◆──◇──◆──◈

### Comprehensive Copilot Instructions

The project includes a consolidated `copilot-instructions.md` file that combines all development guidelines, security protocols, and best practices into a single, professionally organized reference. This file is automatically distributed to the `ainish-vscode/` directory when using `ainish-coder --vscode`, providing GitHub Copilot with:

- **Security & Cybersecurity Framework** (Highest Priority)
- **Modern Prompting & Context Engineering** (Core Methodology)
- **Code Structure & Architecture** (Development Standards)
- **Package Management Rules** (Technology-Specific)
- **Documentation & Context Rules** (Project Alignment)
- **Time & Information Gathering** (Current Data Protocol)
- **Critical Operations** (Essential Procedures)

### Flexible File Formats

The project now supports multiple file format options to meet different needs:

- **`.mdc` Format** (Default): Custom markdown format with enhanced metadata and structure
- **`.md` Format** (`--markdown` flag): Standard markdown format for better compatibility with:
  - Standard markdown editors and tools
  - GitHub markdown rendering
  - Universal markdown processors
  - Better integration with existing workflows

### Anishinaabe-Cyberpunk Styling

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
◈──◆──◇─────────────────◇──◆──◈
</div>

## ᐴ WIIDOOKAAZOWIN ᔔ [Contributing] ◈──◆──◇──◆──◈

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on how to contribute to this project.

**Note**: This project operates under a dual management system:
- **AINISH-Coder**: Manages core configuration and rule files through local deployment, including comprehensive Copilot instructions
- **Licensing System**: Handles LICENSE, CONTRIBUTING.md, README.md, and funding through centralized repository management

**Important**: The current [LICENSE](LICENSE) and [CONTRIBUTING.md](CONTRIBUTING.md) files have been updated through the centralized licensing system and should not be modified locally.

<div align="center">
◈──◆──◇─────────────────◇──◆──◈
</div>

## ᐴ GIGWEJIWEWIN ᔔ [Troubleshooting] ◈──◆──◇──◆──◈

### **Common Installation Issues**

#### **Git Not Found:**
```bash
git: command not found
```
**Solution:** Install Git using the instructions in the Prerequisites section above.

#### **Permission Denied:**
```bash
Permission denied (publickey)
```
**Solution:** This is normal for public repositories. The clone should still work.

#### **Script Not Executable (Linux/macOS):**
```bash
bash: ./ainish-setup.sh: Permission denied
```
**Solution:** Run `chmod +x ainish-setup.sh` to make the script executable.

#### **Script Won't Run (Windows):**
```cmd
'ainish-setup.sh' is not recognized as an internal or external command
```
**Solution:** Use PowerShell instead of Command Prompt, or run `bash ainish-setup.sh` if you have Git Bash installed.

### **Common Usage Issues**

**Q: The wrapper functions aren't working after installation.**  
A: Try reloading your shell configuration:
- **macOS/Linux:** `source ~/.zshrc` or `source ~/.bashrc`
- **Windows PowerShell:** `. $PROFILE`
- **Windows Command Prompt:** Restart your command prompt

**Q: I'm using a shell other than zsh, how do I set up the wrapper functions?**  
A: The script automatically detects your shell and configures accordingly. If you have issues, manually copy the wrapper functions from `~/.zshrc` to your shell's configuration file.

**Q: Path validation fails during setup.**  
A: Edit the `ainish-setup.sh` file to update the `CURSOR_PATH` variable to match your system's Cursor installation path.

**Q: Files aren't being distributed to the tool directories.**  
A: Make sure you have the correct file structure in your repository. All root files (`critical.mdc`, etc.) should be in the main repository directory.

**Q: My changes to configuration files aren't taking effect.**  
A: The script uses symlinks to ensure changes to repository files are immediately available. If a file was modified directly in `~/.ainish-coder`, make sure to update the original file in the repository.

### **Cross-Platform Considerations**

#### **Windows:**
- **PowerShell (Recommended):** Full support with automatic shell detection
- **Command Prompt:** Basic support, some features may be limited
- **WSL:** Full Linux compatibility, recommended for advanced users
- **Git Bash:** Full bash compatibility, good alternative to PowerShell

#### **Linux:**
- **Bash:** Full support, default on most distributions
- **Zsh:** Full support, popular alternative shell
- **Fish:** Full support, modern shell with enhanced features
- **Other shells:** May require manual configuration

#### **macOS:**
- **Zsh:** Full support, default shell since macOS Catalina
- **Bash:** Full support, available as alternative
- **Homebrew:** Recommended for easy package management

### **Platform-Specific Issues**

#### **Windows Issues:**
- **PowerShell Execution Policy:** If you get execution policy errors, run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
- **Line Endings:** If you see strange characters, ensure Git is configured with `git config --global core.autocrlf true`

#### **Linux Issues:**
- **Shell Detection:** If the script doesn't detect your shell correctly, manually specify it in the setup script
- **Permissions:** Ensure you have write permissions to your home directory

#### **macOS Issues:**
- **Gatekeeper:** If you get security warnings, right-click the script and select "Open"
- **Shell Version:** Ensure you're using a modern version of zsh or bash

<div align="center">
◈──◆──◇─────────────────◇──◆──◈
</div>

## 📝 License and Copyright

Copyright © 2025 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᭇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), a descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band, and an enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians. This work embodies Traditional Knowledge and Traditional Cultural Expressions. All rights reserved.

This project is protected under the COMPREHENSIVE RESTRICTED USE LICENSE WITH TRIBAL SOVEREIGNTY PROTECTIONS. See the [LICENSE](LICENSE) file for complete details.

## 📚 Citation

```bibtex
@misc{ainish-coder2025,
  author/creator/steward = {ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᭇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band and enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians},
  title/description = {ainish-coder},
  type_of_work = {Indigenous digital creation/software incorporating traditional knowledge and cultural expressions},
  year = {2025},
  publisher/source/event = {GitHub repository under tribal sovereignty protections},
  howpublished = {\url{https://github.com/nbiish/ainish-coder}},
  note = {Authored and stewarded by ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᭇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band and enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians. This work embodies Indigenous intellectual property, traditional knowledge systems (TK), traditional cultural expressions (TCEs), and associated data protected under tribal law, federal Indian law, treaty rights, Indigenous Data Sovereignty principles, and international indigenous rights frameworks including UNDRIP. All usage, benefit-sharing, and data governance are governed by the COMPREHENSIVE RESTRICTED USE LICENSE FOR INDIGENOUS CREATIONS WITH TRIBAL SOVEREIGNTY, DATA SOVEREIGNTY, AND WEALTH RECLAMATION PROTECTIONS.}
}
```