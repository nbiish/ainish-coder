# bin/ - AINISH-Coder CLI Entry Point

This directory contains the main **command-line interface** entry point for the AINISH-Coder system.

## Structure

```
bin/
├── ainish-coder        # Main CLI executable (POSIX shell)
├── ainish-coder.cmd    # Native Windows launcher (resolves bash, forwards argv)
├── ainish-rag          # RAG engine wrapper (POSIX shell)
├── ainish-rag.cmd      # Native Windows launcher for the RAG engine
├── pqc-secrets         # FIPS 203 secrets manager — platform-dispatch wrapper (see llms.txt)
├── pqc-secrets.darwin-arm64  # Native Rust backend binary (keygen/pack/export) for darwin/arm64
├── lib/                # Shared utilities and libraries
├── security_gate.py    # PQC & zero-trust compliance scanner
└── README.md           # This file
```

## Philosophy

The `bin/` directory follows the **Unix philosophy** of simplicity:

- **Single Entry Point**: Contains only the main CLI executable
- **Thin Entry Point**: Deployment logic lives in the directly discoverable `src/` components
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

For system-wide access, symlink the CLI directly:

```bash
# Create symlink to your PATH
sudo ln -sf "$(pwd)/bin/ainish-coder" /usr/local/bin/ainish-coder

# Now use from anywhere
ainish-coder --help
ainish-coder --rules ~/my-project
```

### Windows

`ainish-coder.cmd` is the native launcher: it locates the bash shipped with Git for Windows, MSYS2, or Cygwin and runs the same POSIX CLI with it, so no WSL is required. Arguments are forwarded verbatim, so Windows paths need no conversion at the prompt:

```bat
ainish-coder --help
ainish-coder --rules
ainish-coder --rules "D:\Code\my project"
```

Add `bin` to your user PATH once with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\ainish-setup.ps1
```

Windows-style path arguments are canonicalised to POSIX form by `src/runtime.sh`, which also resolves a working Python interpreter (skipping the Microsoft Store alias that `python`/`python3` normally resolve to). Both bridges are inert on Linux, macOS, and WSL.

## Architecture

The `ainish-coder` script sources the directly named components under `src/` and routes commands to them.

### Why This Structure?

- **Separation of Concerns**: CLI interface separate from implementation
- **Maintainability**: Logic organized by function in src/
- **Testability**: Modules can be tested independently
- **Reusability**: Functions can be sourced by other scripts

## Related Directories

- **`src/`** - Contains shared utilities and deployment commands
- **`src/templates/`** - Deployable boilerplate templates

## Development

### Adding New Commands

1. Create the component in `src/`
2. Source it in `bin/ainish-coder`
3. Add case statement in the `main()` function
4. Update help text in `src/help.sh`

### Modifying Behavior

- **Don't edit** `bin/ainish-coder` for logic changes
- **Do edit** the appropriate file directly under `src/`
- The CLI script only orchestrates, doesn't implement

## See Also

- [src/README.md](../src/README.md) - Implementation architecture

---

**Remember**: The `bin/` directory is just the **front door**. The real work happens in `src/`.
