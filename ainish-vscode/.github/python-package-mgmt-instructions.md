---
alwaysApply: true
---
# Python Package Management

When working with Python code; use the ```uv``` package manager for all Python-related tasks including but not limited to:

- Creating virtual environments
- Installing packages
- Managing dependencies
- Running isolated scripts with their own dependencies (e.g., ```uv run script.py```)

Only use other Python package managers when explicitly requested by the user or required by the project or PRD.md.

All Python code should be ran from proper isolated .venv or .env environments.

## Example Usage

### Standard Python Project Usage

- Create a virtual environment: `uv venv`
- Install a package: `uv pip install 'package_name'`
- Run a script: `uv run script.py`

### Using uv Script Mode (PEP 723/PEP 722 inline metadata)

- Add inline script metadata for dependencies at the top of your `.py` file using the `# /// script` TOML block.  
  Example:
  ```
  # /// script
  # dependencies = [
  #   "requests<3",
  #   "rich",
  # ]
  # ///
  ```
- (Optionally) Use `uv add --script example.py 'requests<3' 'rich'` to automatically add or update the metadata block.
- Place your Python code below the metadata block.
- Run the script in an isolated environment with dependencies resolved: `uv run example.py`

#### Notes on uv Script Mode

- The inline metadata block declares dependencies and (optionally) Python version requirements for the script.
- `uv run` will automatically create and manage an isolated environment for the script, installing only the declared dependencies.
- You can also specify dependencies at runtime with `uv run --with 'package' example.py`, but inline metadata is preferred for reproducibility.
- For scripts with no dependencies, you can omit the metadata block.

#### Verification

This description matches the official `uv` documentation for "script mode" (PEP 723/722), including inline metadata, dependency management, and isolated execution.  
"uv scripts" refers to Python scripts with inline TOML metadata blocks that declare dependencies and environment requirements, which `uv` uses to manage isolated execution environments automatically.