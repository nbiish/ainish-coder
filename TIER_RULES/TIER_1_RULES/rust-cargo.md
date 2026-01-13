# Rust Cargo: Professional Package Management & Build System

> **Official Documentation Sources:**
>
> - [The Cargo Book](https://doc.rust-lang.org/cargo/) - Comprehensive Cargo documentation
> - [Cargo Reference](https://doc.rust-lang.org/cargo/reference/) - Detailed reference for Cargo.toml and features
> - [Rust Edition Guide](https://doc.rust-lang.org/edition-guide/) - Information about Rust editions
> - [Rust By Example - Cargo](https://doc.rust-lang.org/stable/rust-by-example/cargo.html) - Practical Cargo examples

## MANDATORY PREFERENCE: CARGO FIRST

**Always prefer Cargo for Rust project management.** Cargo provides enterprise-grade dependency management, reproducible builds, and security auditing that modern Rust development requires.

### Why Cargo?

- **Integrated Toolchain**: Unified build system, package manager, and test runner
- **Reproducible Builds**: Cargo.lock ensures consistent builds across teams and CI/CD
- **Dependency Resolution**: Automatic dependency resolution with conflict detection
- **Enterprise-Ready**: Built-in security auditing, dependency pinning, and supply chain integrity
- **Modern Standard**: Industry-standard tooling with comprehensive ecosystem support
- **Performance**: Incremental compilation and parallel builds for fast iteration

### When to Use Cargo

- **All Rust projects**: Cargo is the standard toolchain for Rust development
- **Binary applications**: Use `cargo new --bin` for executables
- **Library crates**: Use `cargo new --lib` for reusable libraries
- **Workspace projects**: Use `cargo new --workspace` for multi-crate projects
- **CI/CD pipelines**: Leverage Cargo's reproducible builds and caching
- **Production deployments**: Use Cargo's release profiles for optimized builds

## CORE COMMANDS REFERENCE

### Toolchain Management

#### `rustup`

Manages Rust toolchains, components, and versions.

**Use Cases:**

- Installing and updating Rust toolchains
- Managing multiple Rust versions (stable, beta, nightly)
- Installing additional components (clippy, rustfmt, rust-analyzer)
- Setting default toolchain for projects

**Enterprise Context:**

- Ensures consistent Rust versions across development teams
- Enables testing against multiple Rust versions
- Supports toolchain pinning via `rust-toolchain.toml`
- Critical for reproducible builds and CI/CD

**Example:**

```bash
rustup install stable              # Install stable toolchain
rustup install 1.75.0             # Install specific version
rustup default stable             # Set default toolchain
rustup component add clippy        # Install clippy linter
rustup component add rustfmt       # Install formatter
rustup toolchain list              # List installed toolchains
```

#### `rustup update`

Updates installed toolchains and components to latest versions.

**Use Cases:**

- Keeping toolchains current with security patches
- Updating to latest stable releases
- Syncing team toolchain versions

**Enterprise Context:**

- Regular updates ensure security patches are applied
- Coordinate updates across team to maintain consistency
- Test updates in CI/CD before team-wide rollout

**Example:**

```bash
rustup update stable              # Update stable toolchain
rustup update                     # Update all toolchains
rustup self update                # Update rustup itself
```

### Project Initialization

#### `cargo new`

Creates a new Rust project with standard directory structure.

**Use Cases:**

- Starting new binary applications
- Creating new library crates
- Initializing workspace projects
- Setting up project scaffolding

**Enterprise Context:**

- Generates standard project structure for consistency
- Includes Git repository initialization
- Creates proper Cargo.toml with metadata
- Sets up standard directory layout

**Example:**

```bash
cargo new my-project              # Create binary project
cargo new --lib my-lib            # Create library crate
cargo new --name custom-name .     # Create in current directory
cargo new --vcs git my-project    # Explicitly use Git
cargo new --vcs none my-project   # Skip version control
```

#### `cargo init`

Initializes a Cargo project in an existing directory.

**Use Cases:**

- Converting existing directories to Cargo projects
- Adding Cargo support to legacy projects
- Setting up projects in non-empty directories

**Enterprise Context:**

- Useful for migrating existing codebases to Cargo
- Maintains existing directory structure
- Adds Cargo.toml without creating new directories

**Example:**

```bash
cargo init                        # Initialize in current directory
cargo init --lib                  # Initialize as library
cargo init --name project-name    # Set custom package name
```

### Building Projects

#### `cargo build`

Compiles the project and all dependencies.

**Use Cases:**

- Building projects for local development
- Compiling dependencies before running
- Verifying code compiles without running
- Creating release builds

**Enterprise Context:**

- Development builds are unoptimized but fast
- Use `--release` for production builds
- Incremental compilation speeds up development
- Parallel compilation utilizes multiple CPU cores

**Example:**

```bash
cargo build                       # Development build
cargo build --release             # Optimized release build
cargo build --bin my-binary       # Build specific binary
cargo build --lib                 # Build library only
cargo build --workspace           # Build all workspace members
```

#### `cargo check`

Quickly checks code for compilation errors without producing binaries.

**Use Cases:**

- Fast feedback during development
- CI/CD linting stages
- Verifying syntax without full compilation
- IDE integration for real-time checking

**Enterprise Context:**

- Much faster than full builds for quick feedback
- Reduces development iteration time
- Ideal for pre-commit hooks and CI checks
- Doesn't produce artifacts, saving disk space

**Example:**

```bash
cargo check                       # Check current package
cargo check --workspace          # Check all workspace members
cargo check --all-targets        # Check tests, examples, benches
```

### Running Projects

#### `cargo run`

Compiles and runs the main binary.

**Use Cases:**

- Quick testing during development
- Running binary applications
- Executing examples
- Testing command-line interfaces

**Enterprise Context:**

- Automatically rebuilds if source changed
- Passes arguments to the binary
- Uses development profile by default
- Use `--release` for performance testing

**Example:**

```bash
cargo run                         # Run main binary
cargo run --release              # Run optimized build
cargo run --bin my-binary        # Run specific binary
cargo run --example my-example   # Run example
cargo run -- --arg1 --arg2       # Pass arguments to binary
```

### Testing

#### `cargo test`

Runs all tests in the project.

**Use Cases:**

- Running unit tests
- Executing integration tests
- Running documentation tests
- Verifying test coverage

**Enterprise Context:**

- Parallel test execution by default
- Tests are compiled separately from main code
- Supports test-specific dependencies via `[dev-dependencies]`
- Critical for CI/CD quality gates

**Example:**

```bash
cargo test                        # Run all tests
cargo test --release             # Run tests in release mode
cargo test test_name             # Run specific test
cargo test --lib                 # Run only library tests
cargo test --doc                 # Run only documentation tests
cargo test --no-fail-fast        # Run all tests even if one fails
```

### Dependency Management

#### `cargo add`

Adds dependencies to Cargo.toml (modern approach).

**Use Cases:**

- Adding new dependencies to projects
- Adding development dependencies
- Adding optional dependencies
- Specifying version requirements

**Enterprise Context:**

- **Preferred method** for adding dependencies
- Automatically updates Cargo.toml with correct syntax
- Supports version specifiers and features
- Updates Cargo.lock automatically

**Example:**

```bash
cargo add serde                  # Add latest version
cargo add serde@1.0             # Add specific version
cargo add serde --dev           # Add as dev dependency
cargo add serde --optional       # Add as optional dependency
cargo add serde --features derive # Add with features
cargo add serde --no-default-features # Exclude default features
```

#### `cargo remove`

Removes dependencies from Cargo.toml.

**Use Cases:**

- Removing unused dependencies
- Cleaning up dependency lists
- Removing deprecated crates
- Simplifying dependency tree

**Enterprise Context:**

- Keeps Cargo.toml clean and maintainable
- Reduces attack surface by removing unused code
- Helps identify truly necessary dependencies
- Updates Cargo.lock automatically

**Example:**

```bash
cargo remove serde               # Remove dependency
cargo remove serde --dev         # Remove dev dependency
```

#### `cargo update`

Updates dependencies within version constraints.

**Use Cases:**

- Updating dependencies to latest compatible versions
- Refreshing Cargo.lock with latest versions
- Updating specific dependencies
- Keeping dependencies current

**Enterprise Context:**

- Updates within version constraints in Cargo.toml
- Use `--precise` for exact version updates
- Regular updates ensure security patches
- Review changes before committing updated Cargo.lock

**Example:**

```bash
cargo update                     # Update all dependencies
cargo update serde              # Update specific crate
cargo update --precise 1.0.0    # Update to exact version
cargo update --dry-run          # Preview updates without applying
```

### Tool Installation

#### `cargo install`

Installs binary crates from crates.io or Git repositories.

**Use Cases:**

- Installing CLI tools (ripgrep, fd, bat, etc.)
- Installing development utilities
- Installing tools from Git repositories
- Installing specific versions of tools

**Enterprise Context:**

- Each tool gets isolated installation
- Tools are installed to `~/.cargo/bin` by default
- Use `--force` to update existing installations
- Prefer `cargo install` over manual compilation

**Example:**

```bash
cargo install ripgrep            # Install from crates.io
cargo install --git https://github.com/user/repo # Install from Git
cargo install --version 1.0.0 tool-name # Install specific version
cargo install --force tool-name  # Update existing installation
cargo install --path ./local-tool # Install from local path
```

### Utility Commands

#### `cargo tree`

Visualizes dependency tree.

**Use Cases:**

- Understanding dependency relationships
- Identifying dependency conflicts
- Finding duplicate dependencies
- Debugging dependency issues

**Enterprise Context:**

- Essential for supply chain auditing
- Helps identify security vulnerabilities
- Useful for dependency optimization
- Generates dependency graphs for documentation

**Example:**

```bash
cargo tree                       # Show full dependency tree
cargo tree --depth 1             # Limit depth
cargo tree --package my-crate    # Show tree for specific package
cargo tree --duplicates          # Show duplicate dependencies
cargo tree --invert serde         # Show reverse dependencies
```

#### `cargo fmt`

Formats code according to Rust style guidelines.

**Use Cases:**

- Consistent code formatting across projects
- Pre-commit formatting checks
- CI/CD formatting validation
- Team style consistency

**Enterprise Context:**

- Enforces consistent code style
- Reduces code review time on formatting
- Use `--check` in CI to enforce formatting
- Integrates with rust-analyzer for IDE formatting

**Example:**

```bash
cargo fmt                        # Format all code
cargo fmt --check                # Check formatting without changing
cargo fmt --all                  # Format all packages in workspace
```

#### `cargo clippy`

Runs the Clippy linter for additional checks.

**Use Cases:**

- Finding common mistakes and improvements
- Enforcing best practices
- Identifying performance issues
- Code quality assurance

**Enterprise Context:**

- Catches bugs before they reach production
- Suggests performance optimizations
- Enforces Rust idioms and best practices
- Essential for code quality gates

**Example:**

```bash
cargo clippy                     # Run clippy checks
cargo clippy -- -W clippy::all   # Enable all lints
cargo clippy --fix               # Auto-fix issues where possible
cargo clippy -- -D warnings      # Deny warnings (fail on warnings)
```

## CARGO.TOML: THE PROFESSIONAL STANDARD

Cargo.toml is the manifest file that defines your Rust project's metadata, dependencies, and build configuration. It's the single source of truth for your project's dependencies and settings.

### Basic Structure

```toml
[package]
name = "my-project"
version = "0.1.0"
edition = "2024"  # 2024 edition is now stable (as of 2025)
description = "A brief description"
license = "MIT OR Apache-2.0"
repository = "https://github.com/user/my-project"
readme = "README.md"

[dependencies]
serde = { version = "1.0", features = ["derive"] }
tokio = { version = "1.0", features = ["full"] }

[dev-dependencies]
tokio-test = "0.4"

[build-dependencies]
cc = "1.0"
```

### Package Metadata

#### Required Fields

- **name**: Package name (must be valid crate name, required by Cargo)
- **version**: Semantic version (MAJOR.MINOR.PATCH) - Required for publishing to crates.io
- **edition**: Rust edition (2015, 2018, 2021, 2024) - Defaults to 2015 if not specified

**Note:** The `name` field is the only field required by Cargo itself. However, crates.io requires `version`, `description`, and either `license` or `license-file` for publishing.

#### Recommended Fields

- **description**: Brief project description (required for crates.io)
- **license** or **license-file**: SPDX license identifier or path to license file (required for crates.io)
- **repository**: Source code repository URL
- **readme**: Path to README file (defaults to README.md if exists)
- **homepage**: Project homepage URL (if different from repository)
- **documentation**: Documentation URL (defaults to docs.rs if not specified)
- **keywords**: Search keywords for crates.io (max 5, each max 20 chars)
- **categories**: Crate categories for crates.io (max 5, must match crates.io category slugs)
- **rust-version**: Minimum supported Rust version (MSRV)

#### Deprecated Fields

- **authors**: Deprecated field (still supported for backwards compatibility, but not recommended for new projects)

**Enterprise Best Practices:**

- Always specify `edition` explicitly (use "2024" for new projects as of 2025)
- Use dual licensing (MIT OR Apache-2.0) for maximum compatibility
- Include repository URL for transparency and supply chain verification
- Provide clear description for discoverability
- Specify `rust-version` to document MSRV requirements
- Do not use deprecated `authors` field in new projects

### Dependency Declaration

#### Version Specifiers

```toml
[dependencies]
# Exact version (not recommended for libraries)
serde = "1.0.0"

# Caret requirement (default, recommended)
serde = "1.0"          # >=1.0.0, <2.0.0

# Tilde requirement
serde = "~1.0"         # >=1.0.0, <1.1.0

# Wildcard requirement
serde = "1.*"          # >=1.0.0, <2.0.0

# Comparison requirements
serde = ">=1.0, <2.0"  # Version range
serde = ">=1.0"        # Minimum version
```

**Enterprise Recommendations:**

- **Libraries**: Use caret requirements (`"1.0"`) for flexibility
- **Applications**: Consider exact versions for maximum reproducibility
- **Production**: Pin versions in Cargo.lock, use ranges in Cargo.toml
- **Security**: Regularly audit and update dependencies

#### Dependency Sources

```toml
[dependencies]
# From crates.io (default)
serde = "1.0"

# From Git repository
my-crate = { git = "https://github.com/user/repo" }
my-crate = { git = "https://github.com/user/repo", branch = "main" }
my-crate = { git = "https://github.com/user/repo", tag = "v1.0.0" }
my-crate = { git = "https://github.com/user/repo", rev = "abc123" }

# From local path
my-crate = { path = "../my-crate" }

# From registry (alternative to crates.io)
my-crate = { registry = "my-registry", version = "1.0" }
```

**Enterprise Context:**

- Prefer crates.io for public dependencies
- Use Git dependencies with specific tags/commits for reproducibility
- Local paths useful for workspace development
- Private registries for internal crates

#### Features

```toml
[dependencies]
serde = { version = "1.0", features = ["derive"], default-features = false }
tokio = { version = "1.0", features = ["rt", "rt-multi-thread", "net"] }

[features]
default = ["feature1", "feature2"]
feature1 = []
feature2 = ["dep:optional-dep"]
no-std = []
```

**Enterprise Benefits:**

- Conditional compilation reduces binary size
- Feature flags enable optional functionality
- `default-features = false` minimizes dependencies
- Features enable platform-specific code

### Optional Dependencies

```toml
[dependencies]
optional-dep = { version = "1.0", optional = true }

[features]
default = ["optional-dep"]
my-feature = ["dep:optional-dep"]
```

**Use Cases:**

- Dependencies only needed for specific features
- Reducing dependency tree for minimal builds
- Platform-specific dependencies
- Development-only functionality

### Development Dependencies

```toml
[dev-dependencies]
tokio-test = "0.4"
mockito = "1.0"
criterion = "0.5"

[[dev-dependencies]]
name = "integration-test-helper"
path = "../test-helpers"
```

**Enterprise Context:**

- Only included when running tests/examples/benches
- Keeps production dependencies minimal
- Use for testing frameworks, mocks, benchmarks
- Separate from production code dependencies

### Build Dependencies

```toml
[build-dependencies]
cc = "1.0"
pkg-config = "0.3"
```

**Use Cases:**

- Dependencies needed for build.rs scripts
- Native library compilation
- Code generation during build
- Platform-specific build tools

### Profiles

```toml
[profile.dev]
opt-level = 0
debug = true
split-debuginfo = "unpacked"

[profile.release]
opt-level = 3
lto = "thin"
codegen-units = 1
panic = "abort"
strip = true

[profile.test]
opt-level = 1
debug = true

[profile.bench]
opt-level = 3
lto = "thin"
```

**Enterprise Best Practices:**

- **dev**: Fast compilation, full debugging info
- **release**: Maximum optimization, minimal binary size
- **test**: Balanced optimization for test performance
- **bench**: Same as release for accurate benchmarks

### Workspaces

```toml
[workspace]
members = ["crate1", "crate2", "crates/*"]
exclude = ["old-crate"]
resolver = "2"

[workspace.package]
version = "0.1.0"
edition = "2021"
authors = ["Team <team@example.com>"]
license = "MIT OR Apache-2.0"

[workspace.dependencies]
serde = "1.0"
tokio = { version = "1.0", features = ["full"] }
```

**Enterprise Benefits:**

- Shared dependencies reduce compilation time
- Consistent versions across workspace members
- Single Cargo.lock for entire workspace
- Monorepo support for large projects

## ENTERPRISE-GRADE PATTERNS

### Cargo.lock Management

#### When to Commit Cargo.lock

**Always commit for:**

- Binary applications (executables)
- Final products deployed to production
- Projects where exact versions matter

**Optional for:**

- Library crates published to crates.io
- Crates used as dependencies by others

**Enterprise Strategy:**

```bash
# For applications (always commit)
git add Cargo.lock

# For libraries (optional, but recommended)
git add Cargo.lock  # Recommended for reproducibility
```

**Rationale:**

- Applications need exact reproducibility
- Libraries benefit from flexibility for dependents
- Committing Cargo.lock ensures team consistency
- CI/CD can verify Cargo.lock is up-to-date

#### Lock File Verification

```bash
# Verify Cargo.lock is up-to-date
cargo build --locked              # Fail if lock is outdated
cargo test --locked                # Test with locked dependencies

# Update lock file
cargo update                       # Update within constraints
cargo update --precise 1.0.0 crate # Update to exact version
```

**Enterprise Workflow:**

1. **Development**: `cargo add <crate>` (updates Cargo.toml and lock)
2. **CI/CD**: `cargo build --locked` (ensures reproducibility)
3. **Security**: `cargo audit` (verify lock file security)

### Security: Dependency Auditing

#### cargo-audit

Scans dependencies for known security vulnerabilities.

```bash
# Install cargo-audit
cargo install cargo-audit

# Run audit
cargo audit                        # Check for vulnerabilities
cargo audit --deny warnings        # Fail on warnings
cargo audit --db ./advisory-db    # Use custom advisory database
```

**Enterprise Integration:**

- Run `cargo audit` in CI/CD pipelines
- Block deployments with critical vulnerabilities
- Regular scheduled audits (weekly/monthly)
- Track vulnerability remediation in tickets

#### cargo-deny

Comprehensive dependency checking and linting.

```bash
# Install cargo-deny
cargo install cargo-deny

# Configure deny.toml
cargo deny init

# Run checks
cargo deny check                  # Run all checks
cargo deny check licenses         # Check licenses
cargo deny check bans            # Check banned crates
cargo deny check sources          # Check source registries
```

**Enterprise Features:**

- License compliance checking
- Ban specific crates or versions
- Verify source registries (prevent typosquatting)
- Generate dependency reports

**Example deny.toml:**

```toml
[bans]
# Ban specific crates
deny = [
    { name = "insecure-crate" },
]

# Allow with exceptions
allow = [
    { name = "allowed-crate", version = "1.0.0" },
]

[licenses]
# Allow only specific licenses
allow = ["MIT", "Apache-2.0", "BSD-3-Clause"]
deny = ["GPL-3.0"]

[sources]
# Only allow crates.io
allow-registry = ["https://github.com/rust-lang/crates.io-index"]
```

### Supply Chain Integrity

**Best Practices:**

- **Pin dependencies**: Use exact versions or narrow ranges
- **Verify checksums**: Cargo automatically verifies crate checksums
- **Private registries**: Use internal registries for proprietary crates
- **SBOM generation**: Export dependency tree for security teams

```bash
# Generate dependency tree for SBOM
cargo tree --format "{p}" > dependencies.txt
cargo metadata --format-version=1 > cargo-metadata.json
```

### Multi-Environment Management

#### Development vs Production

```toml
# Cargo.toml
[dependencies]
# Production dependencies
serde = "1.0"
tokio = "1.0"

[dev-dependencies]
# Development-only dependencies
tokio-test = "0.4"
mockito = "1.0"

[profile.dev]
# Fast compilation
opt-level = 0
debug = true

[profile.release]
# Optimized for production
opt-level = 3
lto = "thin"
panic = "abort"
strip = true
```

#### Feature Flags for Environments

```toml
[features]
default = []
production = ["logging", "metrics"]
development = ["dev-tools", "debug-logging"]

[dependencies]
# Conditional dependencies using dep: prefix (Rust 1.60+)
tracing = { version = "0.1", optional = true }
tracing-subscriber = { version = "0.3", optional = true }

[features]
logging = ["dep:tracing", "dep:tracing-subscriber"]
```

**Important Notes (from official Cargo documentation):**

- The `dep:` prefix syntax is available starting with Rust 1.60
- Using `dep:` disables the implicit feature that would otherwise be created for optional dependencies
- Features should be **additive** - enabling a feature should not disable functionality
- Features are unified across the dependency graph (use resolver = "2" to avoid unwanted unification)
- Maximum 300 features per crate on crates.io (exceptions granted case-by-case)

### CI/CD Integration Patterns

#### GitHub Actions Example

```yaml
name: Rust CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, rustfmt
      
      - name: Cache cargo registry
        uses: actions/cache@v3
        with:
          path: ~/.cargo/registry
          key: ${{ runner.os }}-cargo-registry-${{ hashFiles('**/Cargo.lock') }}
      
      - name: Cache cargo index
        uses: actions/cache@v3
        with:
          path: ~/.cargo/git
          key: ${{ runner.os }}-cargo-git-${{ hashFiles('**/Cargo.lock') }}
      
      - name: Check formatting
        run: cargo fmt --check
      
      - name: Run clippy
        run: cargo clippy -- -D warnings
      
      - name: Run tests
        run: cargo test --locked
      
      - name: Security audit
        run: |
          cargo install cargo-audit
          cargo audit
      
      - name: Build release
        run: cargo build --release --locked
```

#### GitLab CI Example

```yaml
stages:
  - test
  - security
  - build

rust-latest:
  image: rust:latest
  stage: test
  before_script:
    - rustup component add clippy rustfmt
  script:
    - cargo fmt --check
    - cargo clippy -- -D warnings
    - cargo test --locked
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - target/
      - .cargo/

security-audit:
  image: rust:latest
  stage: security
  script:
    - cargo install cargo-audit
    - cargo audit

build-release:
  image: rust:latest
  stage: build
  script:
    - cargo build --release --locked
  artifacts:
    paths:
      - target/release/
```

**Enterprise CI/CD Best Practices:**

- Use `--locked` flag to ensure reproducibility
- Cache `target/` and `.cargo/` for faster builds
- Run `cargo audit` in security stage
- Fail builds on formatting/clippy warnings
- Build release artifacts for deployment

## BEST PRACTICES

### Decision Tree: When to Use Which Command

```text
Starting a new Rust project?
├─ Creating new project?
│  └─ YES → Use `cargo new` (preferred)
│  └─ NO (existing directory) → Use `cargo init`
│
├─ Adding dependencies?
│  └─ YES → Use `cargo add` (preferred)
│  └─ NO (removing) → Use `cargo remove`
│
├─ Building project?
│  ├─ Quick check → Use `cargo check`
│  ├─ Development → Use `cargo build`
│  └─ Production → Use `cargo build --release`
│
├─ Running project?
│  └─ YES → Use `cargo run` (or `cargo run --release`)
│
├─ Testing code?
│  └─ YES → Use `cargo test`
│
└─ Installing tools?
   └─ YES → Use `cargo install <tool-name>`
```

### Dependency Management Strategies

#### Strategy 1: Caret Requirements (Recommended for Libraries)

**Use When:**

- Building libraries for others to use
- Need flexibility for dependents
- Following semantic versioning

**Pattern:**

```toml
[dependencies]
serde = "1.0"          # >=1.0.0, <2.0.0
tokio = "1.0"          # Allows patch updates
```

#### Strategy 2: Exact Versions (Recommended for Applications)

**Use When:**

- Building final applications
- Maximum reproducibility required
- Production deployments

**Pattern:**

```toml
[dependencies]
serde = "1.0.193"      # Exact version
tokio = "1.35.1"       # Pinned for reproducibility
```

**Note:** Still use ranges in Cargo.toml, exact versions come from Cargo.lock

#### Strategy 3: Version Ranges (For Specific Constraints)

**Use When:**

- Need specific version constraints
- Avoiding known buggy versions
- Compatibility requirements

**Pattern:**

```toml
[dependencies]
serde = ">=1.0.100, <2.0.0"  # Specific range
tokio = ">=1.0, <1.36"        # Exclude problematic versions
```

### Version Pinning Recommendations

#### Library Crates

```toml
[dependencies]
# Use caret requirements for flexibility
serde = "1.0"
tokio = "1.0"
```

**Rationale:**

- Allows dependents to use compatible versions
- Enables patch updates automatically
- Follows semantic versioning principles

#### Application Crates

```toml
[dependencies]
# Use caret requirements, lock exact versions
serde = "1.0"    # Range in Cargo.toml
# Exact version in Cargo.lock: serde 1.0.193
```

**Rationale:**

- Cargo.lock provides exact reproducibility
- Cargo.toml allows flexibility for updates
- Best of both worlds: reproducible + maintainable

### Security Considerations

#### Dependency Security Checklist

- ✅ **Pin dependencies** in Cargo.lock (commit for applications)
- ✅ **Use `cargo audit`** regularly in CI/CD
- ✅ **Review dependency updates** before merging
- ✅ **Prefer well-maintained crates** with active security updates
- ✅ **Use `cargo-deny`** for license and source verification
- ✅ **Generate SBOM** for security teams
- ✅ **Monitor for vulnerabilities** (GitHub Dependabot, Snyk, etc.)
- ✅ **Minimize dependencies** to reduce attack surface

#### Supply Chain Security

```bash
# Audit dependencies
cargo audit

# Check licenses and sources
cargo deny check

# Verify lock file integrity
cargo build --locked

# Generate dependency report
cargo tree --format "{p}" > dependencies.txt
```

### Workspace Organization

#### Monorepo Structure

```text
workspace/
├── Cargo.toml              # Workspace manifest
├── Cargo.lock              # Shared lock file
├── crates/
│   ├── core/               # Core library
│   │   └── Cargo.toml
│   ├── api/                # API library
│   │   └── Cargo.toml
│   └── cli/                # CLI binary
│       └── Cargo.toml
└── examples/
    └── example1/
        └── Cargo.toml
```

**Workspace Cargo.toml:**

```toml
[workspace]
members = ["crates/*", "examples/*"]
resolver = "2"  # Required for virtual workspaces, recommended for all workspaces

[workspace.package]
version = "0.1.0"
edition = "2024"  # 2024 edition is now stable
license = "MIT OR Apache-2.0"

[workspace.dependencies]
serde = "1.0"
tokio = { version = "1.0", features = ["full"] }
```

**Key Workspace Points (from official Cargo documentation):**

- All packages share a common `Cargo.lock` file at the workspace root
- All packages share a common output directory (`target/` at workspace root)
- `[patch]`, `[replace]`, and `[profile.*]` sections are only recognized in the root manifest
- Virtual workspaces (without a root package) must explicitly set `resolver = "2"`
- Workspace members can inherit package metadata via `{key}.workspace = true`
- Workspace dependencies can be inherited via `{dep}.workspace = true`

**Enterprise Benefits:**

- Shared dependencies reduce compilation time
- Consistent versions across all crates
- Single Cargo.lock for entire workspace
- Easier dependency management

## EXAMPLES

### Example 1: Simple Binary Project

**Cargo.toml:**

```toml
[package]
name = "my-cli"
version = "0.1.0"
edition = "2024"

[dependencies]
clap = { version = "4.0", features = ["derive"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tokio = { version = "1.0", features = ["full"] }

[dev-dependencies]
tokio-test = "0.4"
```

**src/main.rs:**

```rust
use clap::Parser;

#[derive(Parser)]
struct Args {
    #[arg(short, long)]
    name: String,
}

#[tokio::main]
async fn main() {
    let args = Args::parse();
    println!("Hello, {}!", args.name);
}
```

**Usage:**

```bash
cargo build --release
cargo run -- --name World
```

### Example 2: Library Crate with Features

**Cargo.toml:**

```toml
[package]
name = "my-library"
version = "0.1.0"
edition = "2024"

[dependencies]
serde = { version = "1.0", features = ["derive"], optional = true }
tokio = { version = "1.0", optional = true }

[features]
default = ["serde", "async"]
serde = ["dep:serde"]
async = ["dep:tokio"]
no-std = []

[dev-dependencies]
tokio-test = "0.4"
```

**src/lib.rs:**

```rust
#[cfg(feature = "serde")]
use serde::{Deserialize, Serialize};

#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct Data {
    pub value: i32,
}

#[cfg(feature = "async")]
pub async fn process_async(data: Data) -> Data {
    // Async processing
    data
}

pub fn process(data: Data) -> Data {
    // Sync processing
    data
}
```

**Usage:**

```bash
# Build with default features
cargo build

# Build without default features
cargo build --no-default-features

# Build with specific features
cargo build --features "serde,async"
```

### Example 3: Workspace Project

**Workspace Cargo.toml:**

```toml
[workspace]
members = ["crates/core", "crates/api", "crates/cli"]
resolver = "2"

[workspace.package]
version = "0.1.0"
edition = "2021"
license = "MIT OR Apache-2.0"

[workspace.dependencies]
serde = "1.0"
tokio = { version = "1.0", features = ["full"] }
```

**crates/core/Cargo.toml:**

```toml
[package]
name = "core"
version.workspace = true
edition.workspace = true  # Inherits "2024" from workspace.package

[dependencies]
serde.workspace = true
```

**crates/cli/Cargo.toml:**

```toml
[package]
name = "cli"
version.workspace = true
edition.workspace = true

[dependencies]
core = { path = "../core" }
tokio.workspace = true
clap = { version = "4.0", features = ["derive"] }
```

**Workflow:**

```bash
# Build all workspace members
cargo build --workspace

# Build specific member
cargo build -p cli

# Run specific binary
cargo run -p cli -- --help

# Test all members
cargo test --workspace
```

### Example 4: Production-Ready Project Structure

```text
production-project/
├── Cargo.toml
├── Cargo.lock              # Committed for reproducibility
├── deny.toml               # cargo-deny configuration
├── rust-toolchain.toml     # Pinned Rust version
├── .github/
│   └── workflows/
│       └── ci.yml          # CI/CD configuration
├── src/
│   ├── main.rs
│   └── lib.rs
├── tests/
│   └── integration_test.rs
└── README.md
```

**rust-toolchain.toml:**

```toml
[toolchain]
channel = "1.85.0"  # Use latest stable version
components = ["clippy", "rustfmt", "rust-analyzer"]
```

**Note:** As of 2025, Rust 1.85.0+ is current. Always use the latest stable version for new projects, or pin to a specific version for reproducibility.

**deny.toml:**

```toml
[bans]
deny = []

[licenses]
allow = ["MIT", "Apache-2.0", "BSD-3-Clause"]
deny = ["GPL-3.0"]

[sources]
allow-registry = ["https://github.com/rust-lang/crates.io-index"]
```

**CI/CD Workflow:**

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: dtolnay/rust-toolchain@stable
      
      - name: Check formatting
        run: cargo fmt --check
      
      - name: Run clippy
        run: cargo clippy -- -D warnings
      
      - name: Run tests
        run: cargo test --locked
      
      - name: Security audit
        run: |
          cargo install cargo-audit
          cargo audit
      
      - name: Build release
        run: cargo build --release --locked
```

---

## SUMMARY: CARGO EXCELLENCE CHECKLIST

### For Every Rust Project

- ✅ **Use Cargo** for all Rust projects
- ✅ **Pin Rust version** via `rust-toolchain.toml`
- ✅ **Commit Cargo.lock** for applications (optional for libraries)
- ✅ **Use `--locked` flag** in CI/CD for reproducibility
- ✅ **Run `cargo audit`** regularly for security
- ✅ **Use `cargo-deny`** for license and source verification
- ✅ **Document dependencies** (why each crate is needed)
- ✅ **Use workspaces** for multi-crate projects

### Enterprise Standards

- ✅ **Reproducible builds** via Cargo.lock
- ✅ **Security auditing** integrated into CI/CD
- ✅ **Supply chain integrity** through version pinning
- ✅ **License compliance** via cargo-deny
- ✅ **SBOM generation** for compliance
- ✅ **Private registries** for internal crates
- ✅ **Feature flags** for conditional compilation
- ✅ **Workspace organization** for scalability

**Remember:** Cargo represents the modern, professional standard for Rust development. Always prefer Cargo for new Rust projects, and leverage its comprehensive tooling ecosystem for better reproducibility, security, and maintainability.
