# UV Python: Professional Package Management & Script Execution

## MANDATORY PREFERENCE: UV SCRIPTS FIRST

**Always prefer UV scripts over traditional venv/pip workflows.** UV provides enterprise-grade dependency management, reproducibility, and security that modern Python development requires.

### Why UV Scripts?

- **Speed**: 10-100x faster than pip for dependency resolution and installation
- **Reproducibility**: Built-in locking ensures consistent environments across teams and CI/CD
- **Dependency Isolation**: Each script manages its own dependencies without global pollution
- **Enterprise-Ready**: Security auditing, dependency pinning, and supply chain integrity built-in
- **Modern Standard**: PEP 723 compliant inline script metadata for self-contained executables

### When to Use UV

- **New Python tooling**: Always start with UV scripts
- **Standalone scripts**: Use inline dependency metadata (PEP 723)
- **Project dependencies**: Use `uv.lock` for reproducible builds
- **CI/CD pipelines**: Leverage UV's speed and locking for consistent builds
- **Multi-environment projects**: Isolate dependencies per script or project

## CORE COMMANDS REFERENCE

### Virtual Environment Management

#### `uv venv`

Creates `.venv` in the current directory with isolated Python environment.

**Use Cases:**

- Project-level virtual environments for long-term development
- When you need persistent environment across multiple scripts
- Legacy project migration requiring traditional venv structure

**Enterprise Context:**

- Automatically uses system Python or specified version
- Creates reproducible environment structure
- Compatible with existing tooling expecting `.venv` directory

**Example:**

```bash
uv venv                    # Creates .venv with default Python
uv venv --python 3.11      # Creates .venv with Python 3.11
uv venv --python python3.12 # Creates .venv with specific Python version
```

#### `uv pip install <package>`

Installs packages into the current directory's `.venv` (must exist).

**Use Cases:**

- Adding dependencies to existing project virtual environment
- Installing development tools into project environment
- Legacy workflow compatibility

**Enterprise Context:**

- **Prefer `uv add <package>` for projects with `pyproject.toml`**
- Use `uv pip install` only when managing dependencies manually
- Always pin versions: `uv pip install "package==1.2.3"`

**Example:**

```bash
uv pip install requests==2.31.0        # Pinned version (recommended)
uv pip install "requests>=2.30,<3.0"  # Version range
uv pip install -r requirements.txt     # From requirements file
```

### Script Execution

#### `uv run <script.py>`

Runs Python files using the current directory's `.venv` (creates if needed).

**Use Cases:**

- Quick script execution without manual venv activation
- One-off scripts with project dependencies
- Testing scripts in isolated environment

**Enterprise Context:**

- Automatically resolves and installs dependencies from script metadata
- Creates temporary environment if `.venv` doesn't exist
- **Prefer UV scripts with inline metadata for better isolation**

**Example:**

```bash
uv run script.py                    # Runs with current .venv
uv run --python 3.11 script.py     # Runs with Python 3.11
uv run --no-project script.py      # Runs without project context
```

### Tool Installation

#### `uv tool install <package>`

Installs packages as isolated, globally-available tools.

**Use Cases:**

- CLI tools that should be available system-wide
- Development utilities (linters, formatters, build tools)
- Tools that don't belong to specific projects

**Enterprise Context:**

- Each tool gets isolated environment (no dependency conflicts)
- Tools are versioned and can be updated independently
- Prefer over `pip install --user` for better isolation
- Use for tools like `black`, `ruff`, `mypy`, `pytest`

**Example:**

```bash
uv tool install black              # Install black formatter
uv tool install ruff@0.1.0        # Install specific version
uv tool install --help             # See all options
```

## UV SCRIPTS: THE PROFESSIONAL STANDARD

UV scripts use PEP 723 inline script metadata to declare dependencies directly within Python files. This creates self-contained, executable scripts that manage their own dependencies.

### PEP 723 Inline Script Metadata

Scripts declare dependencies using special comments at the top of the file:

```python
/// script
requires-python = ">=3.11"
dependencies = [
    "requests>=2.31.0",
    "click>=8.1.0",
]
///

import requests
import click

# Your script code here
```

### Key Features

#### Python Version Requirements

```python
/// script
requires-python = ">=3.11"
dependencies = ["requests"]
///
```

**Enterprise Benefits:**

- Enforces Python version compatibility
- Prevents runtime errors from version mismatches
- Documents minimum Python version requirement

#### Dependency Declaration

```python
/// script
dependencies = [
    "requests>=2.31.0",
    "click>=8.1.0",
    "pydantic>=2.0.0",
]
///
```

**Best Practices:**

- **Always pin major versions** (use `>=` with upper bound or exact version)
- **Prefer exact versions in production**: `"requests==2.31.0"`
- **Use version ranges for flexibility**: `"requests>=2.30,<3.0"`
- **Document why each dependency is needed**

#### Alternative Package Indexes

```python
/// script
dependencies = [
    "private-package",
]
index-url = "https://pypi.company.com/simple"
///
```

**Enterprise Use Cases:**

- Private package repositories
- Internal company packages
- Mirrored PyPI indexes for compliance/performance

#### Executable Scripts (Shebang Support)

```python
#!/usr/bin/env -S uv run
/// script
requires-python = ">=3.11"
dependencies = ["click"]
///

import click

@click.command()
def main():
    click.echo("Hello from UV script!")

if __name__ == "__main__":
    main()
```

**Usage:**

```bash
chmod +x script.py
./script.py  # Executes with UV automatically
```

#### GUI Scripts

```python
/// script
gui-script = true
requires-python = ">=3.11"
dependencies = ["tkinter"]
///

# GUI application code
```

### Dependency Locking for Scripts

UV automatically creates `uv.lock` files when running scripts to ensure reproducibility:

```bash
uv run script.py  # Creates/updates uv.lock automatically
```

**Enterprise Benefits:**

- **Reproducible executions**: Same dependencies every time
- **Security auditing**: Lock file enables vulnerability scanning
- **Team consistency**: All developers use identical dependency versions
- **CI/CD reliability**: Builds are deterministic

## ENTERPRISE-GRADE PATTERNS

### Dependency Locking

#### Project-Level Locking

For projects with `pyproject.toml`:

```bash
uv lock                    # Generate/update uv.lock
uv lock --upgrade-package requests  # Upgrade specific package
uv sync                    # Install from lock file
```

**Enterprise Workflow:**

1. **Development**: `uv add <package>` (updates pyproject.toml and lock)
2. **CI/CD**: `uv sync` (installs exact versions from lock)
3. **Security**: `uv lock --check` (verify lock is up-to-date)

#### Script-Level Locking

UV automatically manages locks for scripts:

```bash
uv run script.py           # Auto-creates/updates uv.lock
uv run --locked script.py  # Fail if lock is outdated
```

**Best Practice:** Commit `uv.lock` files to version control for scripts in production.

### Reproducible Builds

#### Lock File Strategy

```bash
# Generate lock file
uv lock

# Verify reproducibility
uv sync --locked  # Install exactly from lock file
```

**Enterprise Requirements:**

- ✅ Lock files committed to version control
- ✅ CI/CD uses `--locked` flag for deterministic builds
- ✅ Lock files reviewed in pull requests
- ✅ Lock updates require explicit approval

#### Python Version Pinning

```python
/// script
requires-python = "==3.11.7"  # Exact version for maximum reproducibility
dependencies = ["requests==2.31.0"]
///
```

**When to Use:**

- Production scripts requiring exact reproducibility
- Compliance/audit requirements
- Multi-platform consistency

### Security: Dependency Auditing

#### Vulnerability Scanning

```bash
uv pip audit                # Check installed packages for vulnerabilities
uv pip audit --fix         # Attempt automatic fixes
uv pip compile --upgrade   # Upgrade vulnerable packages
```

**Enterprise Integration:**

- Run `uv pip audit` in CI/CD pipelines
- Block deployments with critical vulnerabilities
- Regular scheduled audits (weekly/monthly)
- Track vulnerability remediation in tickets

#### Supply Chain Integrity

**Best Practices:**

- **Pin all dependencies**: Use exact versions or narrow ranges
- **Verify package signatures**: Use `--require-hashes` when available
- **Private indexes**: Use internal PyPI mirrors for compliance
- **SBOM generation**: Export dependency tree for security teams

```bash
uv pip list --format=json > sbom.json  # Generate Software Bill of Materials
```

### Multi-Environment Management

#### Development vs Production

```python
# dev-script.py
/// script
requires-python = ">=3.11"
dependencies = [
    "requests",
    "pytest>=7.4.0",      # Dev-only dependency
    "black>=23.0.0",       # Dev-only dependency
]
///
```

```python
# prod-script.py
/// script
requires-python = ">=3.11"
dependencies = [
    "requests==2.31.0",    # Pinned for production
]
///
```

#### Environment-Specific Indexes

```python
/// script
dependencies = ["internal-package"]
index-url = {env = "PYPI_INDEX_URL", default = "https://pypi.org/simple"}
///
```

### CI/CD Integration Patterns

#### GitHub Actions Example

```yaml
- name: Install UV
  uses: astral-sh/setup-uv@v1
  
- name: Set up Python
  run: uv python install 3.11
  
- name: Install dependencies
  run: uv sync --locked
  
- name: Run scripts
  run: uv run script.py
```

#### GitLab CI Example

```yaml
test:
  image: python:3.11
  before_script:
    - pip install uv
    - uv sync --locked
  script:
    - uv run pytest
```

**Enterprise CI/CD Best Practices:**

- Use `--locked` flag to ensure reproducibility
- Cache `uv.lock` and `.venv` for faster builds
- Run `uv pip audit` in security stage
- Fail builds on lock file conflicts

## BEST PRACTICES

### Decision Tree: When to Use Which Command

```text
Need to run a Python script?
├─ Script has inline dependencies (PEP 723)?
│  └─ YES → Use `uv run script.py` (preferred)
│
├─ Script needs project dependencies?
│  └─ YES → Use `uv run script.py` with existing .venv
│
├─ Need isolated global tool?
│  └─ YES → Use `uv tool install <package>`
│
└─ Managing project dependencies?
   ├─ Project has pyproject.toml?
   │  └─ YES → Use `uv add <package>` (preferred)
   │  └─ NO → Use `uv pip install` in .venv
   │
   └─ Need reproducible build?
      └─ YES → Use `uv lock` + `uv sync --locked`
```

### Dependency Management Strategies

#### Strategy 1: UV Scripts (Recommended for Standalone Scripts)

**Use When:**

- Script is self-contained
- Dependencies are script-specific
- Script may be shared/executed independently

**Pattern:**

```python
/// script
requires-python = ">=3.11"
dependencies = ["requests==2.31.0"]
///
```

#### Strategy 2: Project Dependencies (Recommended for Applications)

**Use When:**

- Multiple scripts share dependencies
- Building an application or library
- Need coordinated dependency updates

**Pattern:**

```bash
uv add requests==2.31.0    # Adds to pyproject.toml and updates lock
uv sync                    # Install from lock file
```

#### Strategy 3: Tool Installation (Recommended for Development Tools)

**Use When:**

- Installing CLI tools (linters, formatters)
- Tools used across multiple projects
- Need version isolation

**Pattern:**

```bash
uv tool install black@23.0.0
uv tool install ruff@0.1.0
```

### Version Pinning Recommendations

#### Production Scripts

```python
/// script
requires-python = "==3.11.7"  # Exact Python version
dependencies = [
    "requests==2.31.0",        # Exact package versions
    "click==8.1.7",
]
///
```

**Rationale:**

- Maximum reproducibility
- Prevents unexpected updates
- Easier debugging (known versions)

#### Development Scripts

```python
/// script
requires-python = ">=3.11"
dependencies = [
    "requests>=2.30,<3.0",     # Allow patch/minor updates
    "click>=8.1,<9.0",
]
///
```

**Rationale:**

- Flexibility for development
- Still prevents breaking changes
- Easier to test new versions

### Security Considerations

#### Dependency Security Checklist

- ✅ **Pin all production dependencies** to exact versions
- ✅ **Use `uv pip audit`** regularly in CI/CD
- ✅ **Review dependency updates** before merging
- ✅ **Prefer well-maintained packages** with active security updates
- ✅ **Use private indexes** for internal packages
- ✅ **Generate SBOM** for security teams
- ✅ **Monitor for vulnerabilities** (GitHub Dependabot, Snyk, etc.)

#### Supply Chain Security

```bash
# Audit dependencies
uv pip audit

# Check for known vulnerabilities
uv pip audit --fix

# Verify lock file integrity
uv lock --check
```

## EXAMPLES

### Example 1: Simple Script with Inline Dependencies

```python
#!/usr/bin/env -S uv run
/// script
requires-python = ">=3.11"
dependencies = [
    "requests>=2.31.0",
]
///

import requests
import sys

def fetch_data(url: str) -> dict:
    """Fetch JSON data from URL."""
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    return response.json()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: ./fetch.py <url>")
        sys.exit(1)
    
    data = fetch_data(sys.argv[1])
    print(data)
```

**Usage:**

```bash
chmod +x fetch.py
./fetch.py https://api.example.com/data
```

### Example 2: Production-Ready Script with Locking

```python
/// script
requires-python = "==3.11.7"
dependencies = [
    "requests==2.31.0",
    "pydantic==2.5.0",
    "click==8.1.7",
]
///

import requests
import click
from pydantic import BaseModel

class ApiResponse(BaseModel):
    status: str
    data: dict

@click.command()
@click.option('--url', required=True, help='API endpoint URL')
def main(url: str):
    """Fetch and validate API response."""
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    
    api_response = ApiResponse(**response.json())
    click.echo(f"Status: {api_response.status}")

if __name__ == "__main__":
    main()
```

**Workflow:**

```bash
# First run creates uv.lock
uv run script.py --url https://api.example.com/data

# Commit uv.lock to version control
git add uv.lock

# CI/CD uses locked dependencies
uv run --locked script.py --url $API_URL
```

### Example 3: Multi-Script Project Structure

```text
project/
├── scripts/
│   ├── data-processor.py    # Has its own dependencies
│   ├── report-generator.py  # Has its own dependencies
│   └── deploy.py            # Has its own dependencies
├── src/
│   └── app.py               # Uses project dependencies
├── pyproject.toml           # Project dependencies
├── uv.lock                  # Project lock file
└── README.md
```

**data-processor.py:**

```python
/// script
requires-python = ">=3.11"
dependencies = ["pandas==2.1.0", "numpy==1.24.0"]
///
# Processing logic
```

**app.py (uses project dependencies):**

```python
# No inline metadata - uses project .venv
from fastapi import FastAPI
# Uses dependencies from pyproject.toml
```

**Workflow:**

```bash
# Install project dependencies
uv sync

# Run standalone script
uv run scripts/data-processor.py

# Run application (uses project .venv)
uv run src/app.py
```

### Example 4: Tool Installation Pattern

```bash
# Install development tools
uv tool install black@23.0.0
uv tool install ruff@0.1.0
uv tool install mypy@1.7.0
uv tool install pytest@7.4.0

# Use tools (available globally)
black .
ruff check .
mypy src/
pytest tests/
```

**Benefits:**

- Each tool isolated (no conflicts)
- Versioned independently
- Available across all projects
- Easy to update: `uv tool install black@latest`

---

## SUMMARY: UV EXCELLENCE CHECKLIST

### For Every Python Script

- ✅ **Prefer UV scripts** with inline PEP 723 metadata
- ✅ **Pin Python version** (`requires-python`)
- ✅ **Pin dependencies** (exact versions for production)
- ✅ **Commit lock files** (`uv.lock`) to version control
- ✅ **Use `--locked` flag** in CI/CD for reproducibility
- ✅ **Run `uv pip audit`** regularly for security
- ✅ **Document dependencies** (why each package is needed)

### Enterprise Standards

- ✅ **Reproducible builds** via lock files
- ✅ **Security auditing** integrated into CI/CD
- ✅ **Supply chain integrity** through version pinning
- ✅ **Multi-environment support** (dev/staging/prod)
- ✅ **SBOM generation** for compliance
- ✅ **Private package indexes** for internal packages

**Remember:** UV scripts represent the modern, professional standard for Python tooling. Always prefer UV scripts for new development, and migrate existing scripts to UV patterns for better reproducibility, security, and maintainability.
