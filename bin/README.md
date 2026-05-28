# bin/ - AINISH-Coder CLI Entry Point

This directory contains the main **command-line interface** entry point for the AINISH-Coder system.

## Structure

```
bin/
├── ainish-coder        # Main CLI executable
├── pqc-secrets         # FIPS 203 secrets manager binary
├── pi                  # Pi wrapper (provider hot-swap)
├── mini                # mini-swe-agent wrapper (provider hot-swap)
├── lib/                # Provider hot-swap libraries
├── security_gate.py    # PQC & zero-trust compliance scanner
└── README.md           # This file
```

## Philosophy

The `bin/` directory follows the **Unix philosophy** of simplicity:

- **Single Entry Point**: Contains only the main CLI executable
- **No Implementation**: Actual logic lives in `src/` following MAQ design
- **Clean Interface**: Users interact with one simple command

## Usage

### Direct Execution

```bash
# From repository root
./bin/ainish-coder --help
./bin/ainish-coder --version

# Deploy to specific tools
./bin/ainish-coder --rules /path/to/project

# Interactive CLI menu
./bin/ainish-coder --cli
```

### System-Wide Installation

For system-wide access, symlink the wrapper from `src/molecules/`:

```bash
# Create symlink to your PATH
sudo ln -sf "$(pwd)/src/molecules/install.sh" /usr/local/bin/ainish-coder

# Now use from anywhere
ainish-coder --help
ainish-coder --rules ~/my-project
```

## Architecture

The `ainish-coder` script follows the **MAQ Design** pattern:

1. **Sources Quanta** (`src/quanta/`) - Core utilities (colors, paths, validation)
2. **Sources Atoms** (`src/atoms/`) - Deployment functions
3. **Orchestrates** - Coordinates between modules based on user commands

### Why This Structure?

- **Separation of Concerns**: CLI interface separate from implementation
- **Maintainability**: Logic organized by function in src/
- **Testability**: Modules can be tested independently
- **Reusability**: Functions can be sourced by other scripts

## Related Directories

- **`src/`** - Contains all implementation (quanta, atoms, molecules)
- **`src/molecules/install.sh`** - Wrapper for system-wide installation
- **`src/templates/`** - Deployable boilerplate templates

## Development

### Adding New Commands

1. Create appropriate function in `src/atoms/`
2. Source the atom in `bin/ainish-coder`
3. Add case statement in the `main()` function
4. Update help text in `src/atoms/help.sh`

### Modifying Behavior

- **Don't edit** `bin/ainish-coder` for logic changes
- **Do edit** the appropriate file in `src/quanta/` or `src/atoms/`
- The CLI script only orchestrates, doesn't implement

## See Also

- [src/README.md](../src/README.md) - Implementation architecture

---

**Remember**: The `bin/` directory is just the **front door**. The real work happens in `src/`.
