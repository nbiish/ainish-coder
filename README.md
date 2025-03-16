# MAI-CODER

MAI-CODER is a unified toolkit for AI pair programming that integrates with multiple AI coding assistants, providing a consistent workflow across different tools.

## Features

- **Unified wrappers** for popular AI pair programming tools
  - GitHub Copilot (VS Code)
  - Aider
  - Cursor IDE
- **Configuration management** that prompts when opening projects
- **Project-specific git configurations** and `.gitignore` templates
- **Consistent experience** across different AI coding assistants

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/nbiish/mai-coder.git
   cd mai-coder
   ```

2. Run the installation script:
   ```bash
   ./install.sh
   ```

3. Apply the changes:
   ```bash
   source ~/.zshrc
   ```

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

## Installation Details

The installation script will:
1. Copy configurations to `~/.mai-coder/`
2. Create wrapper scripts for `code`, `cursor`, and `aider` commands
3. Add these wrappers to your PATH in `.zshrc` or `.bashrc`
4. Install the `mai-setup` command for setting up new projects

## Usage

After installation, you'll have the following commands available:

### `mai-setup`

Run this in a project directory to set up the appropriate `.gitignore` file:

```bash
cd your-project
mai-setup
```

### `code` (VS Code with GitHub Copilot)

The `code` command is wrapped to prompt you about updating GitHub Copilot configurations:

```bash
code your-project
```

### `cursor` (Cursor IDE)

The `cursor` command is wrapped to prompt you about updating Cursor configurations:

```bash
cursor your-project
```

### `aider`

The `aider` command is wrapped to prompt you about updating Aider configurations:

```bash
aider your-project
```

## What Gets Added to Your Projects

When you use the commands, these files are automatically added:
- `.copilotignore` and `.rooignore` - For GitHub Copilot
- `.cursorignore` and `.cursorindexingignore` - For Cursor IDE
- `.aider-instructions.md` - For Aider
- License citation in README.md (if missing)

## Configuration Details

Each tool's configuration files are stored in the `~/.mai-coder` directory:

- `~/.mai-coder/mai-aider/`: Aider configurations
- `~/.mai-coder/mai-copilot/`: GitHub Copilot configurations
- `~/.mai-coder/mai-cursor/`: Cursor IDE configurations

When you run the configuration commands (`mai-coder`, `mai-coder aider`, etc.), the tool copies the configuration files from `~/.mai-coder` to the appropriate locations in your project:

- **Aider files** are copied directly to your project root (`.aider.conf.yml`, `.aiderignore`, etc.)
- **GitHub Copilot files** are copied to the `.github` directory and project root
- **Cursor files** are copied to your project root (`.cursorignore`, etc.)

## Repository Structure

If you're contributing to this project or creating your own fork, the repository should have the following structure:

```
mai-coder/
├── mai-aider/
│   ├── .aider.conf.yml
│   ├── .aiderignore
│   ├── .aider-instructions.md
│   └── .env.example
├── mai-copilot/
│   ├── github-copilot/
│   │   └── .github/
│   │       └── copilot-instructions.md
│   └── .copilotignore
├── mai-cursor/
│   ├── .cursorignore
│   ├── .cursorindexingignore
│   └── .cursorrules
└── bin/
    ├── mai-coder
    ├── setup-repo-structure.sh
    └── other scripts...
```

You can run `./bin/setup-repo-structure.sh` to create this directory structure automatically.

## Customization

You can customize the configurations by editing files in the `~/.mai-coder` directory. The wrappers will use your customized configurations when creating or updating project files.

## License
```
@misc{mai-coder2025,
  author = {ᓂᐲᔥ Nbiish-Justin Kenwabikise ᑭᓇᐙᐱᑭᓯ},
  title = {mai-coder},
  year = {2025},
  publisher = {GitHub},
  journal = {GitHub repository},
  howpublished = {\url{https://github.com/nbiish/mai-coder}},
}
```# MAI-CODER

MAI-CODER is a unified toolkit for AI pair programming that integrates with multiple AI coding assistants, providing a consistent workflow across different tools.

## Features

- **Unified wrappers** for popular AI pair programming tools
  - GitHub Copilot (VS Code)
  - Aider
  - Cursor IDE
- **Configuration management** that prompts when opening projects
- **Project-specific git configurations** and `.gitignore` templates
- **Consistent experience** across different AI coding assistants

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/nbiish/mai-coder.git
   cd mai-coder
   ```

2. Run the installation script:
   ```bash
   ./install.sh
   ```

3. Apply the changes:
   ```bash
   source ~/.zshrc
   ```

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

## Installation Details

The installation script will:
1. Copy configurations to `~/.mai-coder/`
2. Create wrapper scripts for `code`, `cursor`, and `aider` commands
3. Add these wrappers to your PATH in `.zshrc` or `.bashrc`
4. Install the `mai-setup` command for setting up new projects

## Usage

After installation, you'll have the following commands available:

### `mai-setup`

Run this in a project directory to set up the appropriate `.gitignore` file:

```bash
cd your-project
mai-setup
```

### `code` (VS Code with GitHub Copilot)

The `code` command is wrapped to prompt you about updating GitHub Copilot configurations:

```bash
code your-project
```

### `cursor` (Cursor IDE)

The `cursor` command is wrapped to prompt you about updating Cursor configurations:

```bash
cursor your-project
```

### `aider`

The `aider` command is wrapped to prompt you about updating Aider configurations:

```bash
aider your-project
```

## What Gets Added to Your Projects

When you use the commands, these files are automatically added:
- `.copilotignore` and `.rooignore` - For GitHub Copilot
- `.cursorignore` and `.cursorindexingignore` - For Cursor IDE
- `.aider-instructions.md` - For Aider
- License citation in README.md (if missing)

## Configuration Details

Each tool's configuration files are stored in the `~/.mai-coder` directory:

- `~/.mai-coder/mai-aider/`: Aider configurations
- `~/.mai-coder/mai-copilot/`: GitHub Copilot configurations
- `~/.mai-coder/mai-cursor/`: Cursor IDE configurations

When you run the configuration commands (`mai-coder`, `mai-coder aider`, etc.), the tool copies the configuration files from `~/.mai-coder` to the appropriate locations in your project:

- **Aider files** are copied directly to your project root (`.aider.conf.yml`, `.aiderignore`, etc.)
- **GitHub Copilot files** are copied to the `.github` directory and project root
- **Cursor files** are copied to your project root (`.cursorignore`, etc.)

## Repository Structure

If you're contributing to this project or creating your own fork, the repository should have the following structure:

```
mai-coder/
├── mai-aider/
│   ├── .aider.conf.yml
│   ├── .aiderignore
│   ├── .aider-instructions.md
│   └── .env.example
├── mai-copilot/
│   ├── github-copilot/
│   │   └── .github/
│   │       └── copilot-instructions.md
│   └── .copilotignore
├── mai-cursor/
│   ├── .cursorignore
│   ├── .cursorindexingignore
│   └── .cursorrules
└── bin/
    ├── mai-coder
    ├── setup-repo-structure.sh
    └── other scripts...
```

You can run `./bin/setup-repo-structure.sh` to create this directory structure automatically.

## Customization

You can customize the configurations by editing files in the `~/.mai-coder` directory. The wrappers will use your customized configurations when creating or updating project files.

## License
```
@misc{mai-coder2025,
  author = {ᓂᐲᔥ Nbiish-Justin Kenwabikise ᑭᓇᐙᐱᑭᓯ},
  title = {mai-coder},
  year = {2025},
  publisher = {GitHub},
  journal = {GitHub repository},
  howpublished = {\url{https://github.com/nbiish/mai-coder}},
}
```# MAI-CODER

MAI-CODER is a unified toolkit for AI pair programming that integrates with multiple AI coding assistants, providing a consistent workflow across different tools.

## Features

- **Unified wrappers** for popular AI pair programming tools
  - GitHub Copilot (VS Code)
  - Aider
  - Cursor IDE
- **Configuration management** that prompts when opening projects
- **Project-specific git configurations** and `.gitignore` templates
- **Consistent experience** across different AI coding assistants

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/nbiish/mai-coder.git
   cd mai-coder
   ```

2. Run the installation script:
   ```bash
   ./install.sh
   ```

3. Apply the changes:
   ```bash
   source ~/.zshrc
   ```

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

## Installation Details

The installation script will:
1. Copy configurations to `~/.mai-coder/`
2. Create wrapper scripts for `code`, `cursor`, and `aider` commands
3. Add these wrappers to your PATH in `.zshrc` or `.bashrc`
4. Install the `mai-setup` command for setting up new projects

## Usage

After installation, you'll have the following commands available:

### `mai-setup`

Run this in a project directory to set up the appropriate `.gitignore` file:

```bash
cd your-project
mai-setup
```

### `code` (VS Code with GitHub Copilot)

The `code` command is wrapped to prompt you about updating GitHub Copilot configurations:

```bash
code your-project
```

### `cursor` (Cursor IDE)

The `cursor` command is wrapped to prompt you about updating Cursor configurations:

```bash
cursor your-project
```

### `aider`

The `aider` command is wrapped to prompt you about updating Aider configurations:

```bash
aider your-project
```

## What Gets Added to Your Projects

When you use the commands, these files are automatically added:
- `.copilotignore` and `.rooignore` - For GitHub Copilot
- `.cursorignore` and `.cursorindexingignore` - For Cursor IDE
- `.aider-instructions.md` - For Aider
- License citation in README.md (if missing)

## Configuration Details

Each tool's configuration files are stored in the `~/.mai-coder` directory:

- `~/.mai-coder/mai-aider/`: Aider configurations
- `~/.mai-coder/mai-copilot/`: GitHub Copilot configurations
- `~/.mai-coder/mai-cursor/`: Cursor IDE configurations

When you run the configuration commands (`mai-coder`, `mai-coder aider`, etc.), the tool copies the configuration files from `~/.mai-coder` to the appropriate locations in your project:

- **Aider files** are copied directly to your project root (`.aider.conf.yml`, `.aiderignore`, etc.)
- **GitHub Copilot files** are copied to the `.github` directory and project root
- **Cursor files** are copied to your project root (`.cursorignore`, etc.)

## Repository Structure

If you're contributing to this project or creating your own fork, the repository should have the following structure:

```
mai-coder/
├── mai-aider/
│   ├── .aider.conf.yml
│   ├── .aiderignore
│   ├── .aider-instructions.md
│   └── .env.example
├── mai-copilot/
│   ├── github-copilot/
│   │   └── .github/
│   │       └── copilot-instructions.md
│   └── .copilotignore
├── mai-cursor/
│   ├── .cursorignore
│   ├── .cursorindexingignore
│   └── .cursorrules
└── bin/
    ├── mai-coder
    ├── setup-repo-structure.sh
    └── other scripts...
```

You can run `./bin/setup-repo-structure.sh` to create this directory structure automatically.

## Customization

You can customize the configurations by editing files in the `~/.mai-coder` directory. The wrappers will use your customized configurations when creating or updating project files.

## License
```
@misc{mai-coder2025,
  author = {ᓂᐲᔥ Nbiish-Justin Kenwabikise ᑭᓇᐙᐱᑭᓯ},
  title = {mai-coder},
  year = {2025},
  publisher = {GitHub},
  journal = {GitHub repository},
  howpublished = {\url{https://github.com/nbiish/mai-coder}},
}
```# MAI-CODER

MAI-CODER is a unified toolkit for AI pair programming that integrates with multiple AI coding assistants, providing a consistent workflow across different tools.

## Features

- **Unified wrappers** for popular AI pair programming tools
  - GitHub Copilot (VS Code)
  - Aider
  - Cursor IDE
- **Configuration management** that prompts when opening projects
- **Project-specific git configurations** and `.gitignore` templates
- **Consistent experience** across different AI coding assistants

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/nbiish/mai-coder.git
   cd mai-coder
   ```

2. Run the installation script:
   ```bash
   ./install.sh
   ```

3. Apply the changes:
   ```bash
   source ~/.zshrc
   ```

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

## Installation Details

The installation script will:
1. Copy configurations to `~/.mai-coder/`
2. Create wrapper scripts for `code`, `cursor`, and `aider` commands
3. Add these wrappers to your PATH in `.zshrc` or `.bashrc`
4. Install the `mai-setup` command for setting up new projects

## Usage

After installation, you'll have the following commands available:

### `mai-setup`

Run this in a project directory to set up the appropriate `.gitignore` file:

```bash
cd your-project
mai-setup
```

### `code` (VS Code with GitHub Copilot)

The `code` command is wrapped to prompt you about updating GitHub Copilot configurations:

```bash
code your-project
```

### `cursor` (Cursor IDE)

The `cursor` command is wrapped to prompt you about updating Cursor configurations:

```bash
cursor your-project
```

### `aider`

The `aider` command is wrapped to prompt you about updating Aider configurations:

```bash
aider your-project
```

## What Gets Added to Your Projects

When you use the commands, these files are automatically added:
- `.copilotignore` and `.rooignore` - For GitHub Copilot
- `.cursorignore` and `.cursorindexingignore` - For Cursor IDE
- `.aider-instructions.md` - For Aider
- License citation in README.md (if missing)

## Configuration Details

Each tool's configuration files are stored in the `~/.mai-coder` directory:

- `~/.mai-coder/mai-aider/`: Aider configurations
- `~/.mai-coder/mai-copilot/`: GitHub Copilot configurations
- `~/.mai-coder/mai-cursor/`: Cursor IDE configurations

When you run the configuration commands (`mai-coder`, `mai-coder aider`, etc.), the tool copies the configuration files from `~/.mai-coder` to the appropriate locations in your project:

- **Aider files** are copied directly to your project root (`.aider.conf.yml`, `.aiderignore`, etc.)
- **GitHub Copilot files** are copied to the `.github` directory and project root
- **Cursor files** are copied to your project root (`.cursorignore`, etc.)

## Repository Structure

If you're contributing to this project or creating your own fork, the repository should have the following structure:

```
mai-coder/
├── mai-aider/
│   ├── .aider.conf.yml
│   ├── .aiderignore
│   ├── .aider-instructions.md
│   └── .env.example
├── mai-copilot/
│   ├── github-copilot/
│   │   └── .github/
│   │       └── copilot-instructions.md
│   └── .copilotignore
├── mai-cursor/
│   ├── .cursorignore
│   ├── .cursorindexingignore
│   └── .cursorrules
└── bin/
    ├── mai-coder
    ├── setup-repo-structure.sh
    └── other scripts...
```

You can run `./bin/setup-repo-structure.sh` to create this directory structure automatically.

## Customization

You can customize the configurations by editing files in the `~/.mai-coder` directory. The wrappers will use your customized configurations when creating or updating project files.

## License
```
@misc{mai-coder2025,
  author = {ᓂᐲᔥ Nbiish-Justin Kenwabikise ᑭᓇᐙᐱᑭᓯ},
  title = {mai-coder},
  year = {2025},
  publisher = {GitHub},
  journal = {GitHub repository},
  howpublished = {\url{https://github.com/nbiish/mai-coder}},
}
```# MAI-CODER

MAI-CODER is a unified toolkit for AI pair programming that integrates with multiple AI coding assistants, providing a consistent workflow across different tools.

## Features

- **Unified wrappers** for popular AI pair programming tools
  - GitHub Copilot (VS Code)
  - Aider
  - Cursor IDE
- **Configuration management** that prompts when opening projects
- **Project-specific git configurations** and `.gitignore` templates
- **Consistent experience** across different AI coding assistants

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/nbiish/mai-coder.git
   cd mai-coder
   ```

2. Run the installation script:
   ```bash
   ./install.sh
   ```

3. Apply the changes:
   ```bash
   source ~/.zshrc
   ```

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

## Installation Details

The installation script will:
1. Copy configurations to `~/.mai-coder/`
2. Create wrapper scripts for `code`, `cursor`, and `aider` commands
3. Add these wrappers to your PATH in `.zshrc` or `.bashrc`
4. Install the `mai-setup` command for setting up new projects

## Usage

After installation, you'll have the following commands available:

### `mai-setup`

Run this in a project directory to set up the appropriate `.gitignore` file:

```bash
cd your-project
mai-setup
```

### `code` (VS Code with GitHub Copilot)

The `code` command is wrapped to prompt you about updating GitHub Copilot configurations:

```bash
code your-project
```

### `cursor` (Cursor IDE)

The `cursor` command is wrapped to prompt you about updating Cursor configurations:

```bash
cursor your-project
```

### `aider`

The `aider` command is wrapped to prompt you about updating Aider configurations:

```bash
aider your-project
```

## What Gets Added to Your Projects

When you use the commands, these files are automatically added:
- `.copilotignore` and `.rooignore` - For GitHub Copilot
- `.cursorignore` and `.cursorindexingignore` - For Cursor IDE
- `.aider-instructions.md` - For Aider
- License citation in README.md (if missing)

## Configuration Details

Each tool's configuration files are stored in the `~/.mai-coder` directory:

- `~/.mai-coder/mai-aider/`: Aider configurations
- `~/.mai-coder/mai-copilot/`: GitHub Copilot configurations
- `~/.mai-coder/mai-cursor/`: Cursor IDE configurations

When you run the configuration commands (`mai-coder`, `mai-coder aider`, etc.), the tool copies the configuration files from `~/.mai-coder` to the appropriate locations in your project:

- **Aider files** are copied directly to your project root (`.aider.conf.yml`, `.aiderignore`, etc.)
- **GitHub Copilot files** are copied to the `.github` directory and project root
- **Cursor files** are copied to your project root (`.cursorignore`, etc.)

## Repository Structure

If you're contributing to this project or creating your own fork, the repository should have the following structure:

```
mai-coder/
├── mai-aider/
│   ├── .aider.conf.yml
│   ├── .aiderignore
│   ├── .aider-instructions.md
│   └── .env.example
├── mai-copilot/
│   ├── github-copilot/
│   │   └── .github/
│   │       └── copilot-instructions.md
│   └── .copilotignore
├── mai-cursor/
│   ├── .cursorignore
│   ├── .cursorindexingignore
│   └── .cursorrules
└── bin/
    ├── mai-coder
    ├── setup-repo-structure.sh
    └── other scripts...
```

You can run `./bin/setup-repo-structure.sh` to create this directory structure automatically.

## Customization

You can customize the configurations by editing files in the `~/.mai-coder` directory. The wrappers will use your customized configurations when creating or updating project files.

## License
```
@misc{mai-coder2025,
  author = {ᓂᐲᔥ Nbiish-Justin Kenwabikise ᑭᓇᐙᐱᑭᓯ},
  title = {mai-coder},
  year = {2025},
  publisher = {GitHub},
  journal = {GitHub repository},
  howpublished = {\url{https://github.com/nbiish/mai-coder}},
}
```