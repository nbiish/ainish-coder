# bin/ - AINISH-Coder CLI Entry Point

This directory contains the main **command-line interface** entry point for the AINISH-Coder system.

## Structure

```
bin/
├── ainish-coder        # Main CLI executable
├── ainish-coder.bak    # Backup of previous version
└── README.md           # This file
```

## Philosophy

The `bin/` directory follows the **Unix philosophy** of simplicity:

- **Single Entry Point**: Contains only the main CLI executable
- **No Implementation**: Actual logic lives in `dna/` following atomic design
- **Clean Interface**: Users interact with one simple command

## Usage

### Direct Execution

```bash
# From repository root
./bin/ainish-coder --help
./bin/ainish-coder --version

# Deploy to specific tools
./bin/ainish-coder cursor /path/to/project
./bin/ainish-coder windsurf /path/to/project

# Deploy tiers
./bin/ainish-coder --tier all /path/to/project
```

### System-Wide Installation

For system-wide access, symlink the wrapper from `dna/organisms/`:

```bash
# Create symlink to your PATH
sudo ln -sf "$(pwd)/dna/organisms/install.sh" /usr/local/bin/ainish-coder

# Now use from anywhere
ainish-coder --help
ainish-coder cursor ~/my-project
```

## Architecture

The `ainish-coder` script follows the **Atomic Design** pattern:

1. **Sources Atoms** (`dna/atoms/`) - Core utilities (colors, paths, validation)
2. **Sources Molecules** (`dna/molecules/`) - Deployment functions
3. **Orchestrates** - Coordinates between modules based on user commands

### Why This Structure?

- **Separation of Concerns**: CLI interface separate from implementation
- **Maintainability**: Logic organized by function in dna/
- **Testability**: Modules can be tested independently
- **Reusability**: Functions can be sourced by other scripts

## Related Directories

- **`dna/`** - Contains all implementation (atoms, molecules, organisms)
- **`dna/organisms/install.sh`** - Wrapper for system-wide installation
- **`CONFIGURATIONS/`** - Configuration templates and tier rules

## Development

### Adding New Commands

1. Create appropriate function in `dna/molecules/`
2. Source the molecule in `bin/ainish-coder`
3. Add case statement in the `main()` function
4. Update help text in `dna/molecules/help.sh`

### Modifying Behavior

- **Don't edit** `bin/ainish-coder` for logic changes
- **Do edit** the appropriate file in `dna/atoms/` or `dna/molecules/`
- The CLI script only orchestrates, doesn't implement

## See Also

- [dna/README.md](../dna/README.md) - Implementation architecture
- [.github/copilot-instructions.md](../.github/copilot-instructions.md) - Development guidelines
- [KNOWLEDGE_BASE/](../KNOWLEDGE_BASE/) - Detailed documentation

---

**Remember**: The `bin/` directory is just the **front door**. The real work happens in `dna/`.
