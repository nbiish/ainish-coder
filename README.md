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
      <p><a href="https://donate.stripe.com/3cs29La1j8UGfnObII">Donate via Stripe</a></p>
    </div>
    <div style="display: flex; align-items: center;">
      <a href="https://www.buymeacoffee.com/nbiish"><img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=&slug=nbiish&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff" /></a>
    </div>
  </div>
  
  <hr width="50%">
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

After installation, you can periodically run `ainish-update` to ensure all configurations, including critical.mdc files, are kept in sync across all ainish-* directories.

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
6. Ensures critical.mdc is copied to all ainish-* directories during updates

The script also provides the `ainish-update` command which:
- Updates critical.mdc in all ainish-* directories automatically
- Ensures license compliance and configuration consistency across all components
- Re-runs the setup script to refresh all configurations

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
  author/creator/steward = {ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band},
  title/description = {ainish-coder},
  type_of_work = {Indigenous digital creation/software incorporating traditional knowledge and cultural expressions},
  year = {2025},
  publisher/source/event = {GitHub repository under tribal sovereignty protections},
  howpublished = {\url{https://github.com/nbiish/ainish-coder}},
  note = {Authored and stewarded by ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi), also known legally as JUSTIN PAUL KENWABIKISE, professionally documented as Nbiish-Justin Paul Kenwabikise, Anishinaabek Dodem (Anishinaabe Clan): Animikii (Thunder), descendant of Chief ᑭᓇᐙᐸᑭᓯ (Kinwaabakizi) of the Beaver Island Band (whose community faced violent dispersal resulting in descendants affiliating with LTBB, GTBOCI, and First Nations in Canada, as detailed in the Preamble), an enrolled member of the sovereign Grand Traverse Band of Ottawa and Chippewa Indians. This work embodies Indigenous intellectual property, traditional knowledge systems (TK), traditional cultural expressions (TCEs), and associated data protected under tribal law, federal Indian law, treaty rights, Indigenous Data Sovereignty principles, and international indigenous rights frameworks including UNDRIP. All usage, benefit-sharing, and data governance are governed by the COMPREHENSIVE RESTRICTED USE LICENSE FOR INDIGENOUS CREATIONS WITH TRIBAL SOVEREIGNTY, DATA SOVEREIGNTY, AND WEALTH RECLAMATION PROTECTIONS.}
}
``` 