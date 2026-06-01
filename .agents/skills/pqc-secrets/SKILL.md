---
name: pqc-secrets
description: Post-quantum cryptography secrets management system for protecting API keys, tokens, and private data.
---

# PQC Secrets Management Agent Skill

> **Companion skill:** [pqc-signatures-security](../pqc-signatures-security/SKILL.md) — ML-DSA-65 code signing, integrity verification, and secure coding patterns. Use both together for complete PQC coverage: this skill encrypts secrets at rest; pqc-signatures-security verifies code hasn't been tampered with.

This skill provides comprehensive instructions, policies, and blueprints for managing repository and application secrets (API keys, credentials, private user data) using post-quantum cryptographic (PQC) algorithms.

AI agents using this skill are equipped to:
1. Protect credentials at rest and in memory using FIPS-compliant algorithms.
2. Integrate with the platform's native keychain and standard runtime environments.
3. Validate environments and ensure zero plaintext credentials are written to disk.

---

## 1. Core Philosophy: Zero Plaintext on Disk

Traditional secrets management relies heavily on plaintext `.env` files or insecure environment variables. Under the PQC mandate:
- **Always** protect API keys and private data with FIPS 203 (ML-KEM-768) key encapsulation and AES-256-GCM symmetric encryption.
- **Never** store raw API keys, secrets, or tokens in git repositories, task files, logs, or local unencrypted files.
- **Always** load secrets on-demand directly into the shell environment from an encrypted bundle, and ensure they never persist to disk.

### 1.1 ⚠️ Common Agent Trap: Settings Files with `env` Blocks

Many CLI tools (Claude Code, VS Code, Docker, etc.) use JSON/YAML settings files with an `env` block. **Agents will naturally want to put API keys directly in these files. This is a PQC violation.**

**NEVER do this:**
```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "sk-ss-v1-abc123...",
    "ANTHROPIC_API_KEY": "sk-ant-..."
  }
}
```

```yaml
env:
  API_KEY: "sk-..."
```

```json
{
  "env": {
    "OPENAI_API_KEY": "sk-proj-..."
  }
}
```

**Why this is wrong:** The settings file is a regular file on disk. Anyone with file read access (backup tools, cloud sync, other processes, disk imaging) can extract the key. It will also be committed to git if the file is tracked, and it shows up in file search/grep results.

**ALWAYS do this instead — inject at runtime from the OS keychain:**
```bash
# Shell wrapper reads from Keychain and passes via env var
my-tool() {
    local api_key
    api_key="$(security find-generic-password -s "my-tool" -a "api-key" -w 2>/dev/null)"
    if [[ -z "$api_key" ]]; then
        echo "Error: API key not found in Keychain." >&2
        return 1
    fi
    ANTHROPIC_AUTH_TOKEN="$api_key" command my-tool "$@"
}
```

The settings file keeps everything **except** the secret value:
```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://zenmux.ai/api/anthropic",
    "ANTHROPIC_API_KEY": "",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek/deepseek-v4-flash"
  }
}
```

**The key exists only in two places: the OS keychain (encrypted at rest) and process memory (volatile). Never on disk in any config file.**

---

## 2. Infrastructure Architecture

The PQC secrets system consists of a dual-implementation architecture to ensure maximum performance and cross-platform compatibility:

1. **Rust Native (Primary):** The compiled binary at `bin/pqc-secrets` (source in `src/pqc-secrets/`) uses the NIST FIPS 203 compliant `fips203` crate. It implements a secure **double-envelope** structure:
   - **ML-KEM-768** encapsulates a Key Encapsulating Key (KEK).
   - The KEK wraps a Data Encryption Key (DEK) via AES-256-GCM keywrap.
   - The DEK encrypts the secret payload via AES-256-GCM.
   - Stores metadata including Additional Authenticated Data (`aad`) in `secrets.bundle.json`.
2. **Python Fallback (Secondary):** A script at `.agents/skills/pqc-secrets/scripts/pqc_secrets.py` uses `kyber-py` and implements a **single-envelope** structure (ML-KEM-768 encapsulates the DEK directly).

> [!WARNING]
> **Format Incompatibility & Mismatch Errors:**
> Because the Rust binary and Python script use different envelope structures, their serialized bundles are incompatible. Running the Rust binary on a Python-packed bundle results in:
> `Error: missing field aad at line X column Y`
>
> If this occurs, you must perform a one-time migration:
> ```bash
> # 1. Export plaintext secrets using the Python fallback
> SECRETS_TXT=$(uv run .agents/skills/pqc-secrets/scripts/pqc_secrets.py export)
> 
> # 2. Generate a new keypair using the Rust binary
> ./bin/pqc-secrets keygen
> 
> # 3. Pack the secrets back into the Rust-compatible bundle
> echo "$SECRETS_TXT" | ./bin/pqc-secrets pack
> ```

The local secrets infrastructure lives at `~/.config/pqc-secrets/`:

```
macOS Keychain                    ~/.config/pqc-secrets/
┌──────────────────────┐          ┌────────────────────────────┐
│ service: pqc-secrets │          │ recipient.pub              │
│ ML-KEM-768 secret key│          │ ML-KEM-768 public key      │
│ (Secure Enclave)     │          │ (safe to commit)           │
└──────────┬───────────┘          └────────────┬───────────────┘
           │                                   │
           │ decaps (ML-KEM-768)               │ encaps
           ▼                                   ▼
┌──────────────────────────────────────────────────────────────┐
│                    secrets.bundle.json                       │
│  ┌─────────────────┐  ┌──────────────────────────────────┐   │
│  │ kem.ciphertext  │  │ data.ciphertext (AES-256-GCM)    │   │
│  │ (ML-KEM-768)    │  │ 24+ API keys encrypted at rest   │   │
│  └─────────────────┘  └──────────────┬───────────────────┘   │
└──────────────────────────────────────┼───────────────────────┘
                                       │ decrypt
                                       ▼
┌──────────────────────────────────────────────────────────────┐
│  Exported environment variables (never touch disk)           │
│  ANTHROPIC_AUTH_TOKEN  ZENMUX_API_KEY  NEBIUS_API_KEY        │
│  OPENROUTER_API_KEY    WAFER_API_KEY    ... (in-memory only) │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. Cryptographic Standards

For all secrets operations, only NIST-approved post-quantum algorithms are permitted. Traditional classical algorithms are strictly forbidden for protecting key material:

| Use Case | Permitted Algorithms (FIPS) | Forbidden Algorithms |
|---|---|---|
| Key Encapsulation (KEM) | ML-KEM-768, ML-KEM-1024 | RSA, ECDH, ECDSA, Ed25519 |
| Symmetric Encryption | AES-256-GCM | AES-CBC, DES, 3DES, Blowfish, RC4 |
| Digital Signatures | ML-DSA-65/87, SLH-DSA-SHA2-128s | MD5, SHA-1, RSA, DSA |

---

## 4. Lifecycle Commands

Use the primary native Rust binary `bin/pqc-secrets` (or run the Python fallback via `uv run .agents/skills/pqc-secrets/scripts/pqc_secrets.py`):

| Step | Rust Command | Python Fallback Command | Description |
|---|---|---|---|
| **Keygen** | `bin/pqc-secrets keygen` | `uv run .agents/skills/pqc-secrets/scripts/pqc_secrets.py keygen` | Generates a new ML-KEM-768 keypair. Stores the private key in macOS Keychain (service: `pqc-secrets`, account: `default`) and writes public key to `~/.config/pqc-secrets/recipient.pub`. |
| **Pack** | `bin/pqc-secrets pack` | `uv run .agents/skills/pqc-secrets/scripts/pqc_secrets.py pack` | Reads `KEY=VAL` lines from stdin, encrypts them via AES-256-GCM, wraps the data key via ML-KEM-768 encapsulation, and outputs `~/.config/pqc-secrets/secrets.bundle.json`. |
| **Load** | `bin/pqc-secrets export` | `uv run .agents/skills/pqc-secrets/scripts/pqc_secrets.py export` | Decrypts the bundle in-memory and outputs `export KEY=VALUE` lines. Can be evaluated in shell (e.g. `eval $(pqc-secrets export)`). |
| **Verify** | `bin/pqc-secrets verify` | `uv run .agents/skills/pqc-secrets/scripts/pqc_secrets.py verify` | Verifies the bundle can be decrypted and lists key names (no values shown). (Note: Rust verify implementation is built into export/pack check). |

### Implementation Details

- **Rust Primary Engine:** `fips203` crate (rust-fips203, NSA CNSA 2.0 / FIPS 203 compliant ML-KEM-768).
- **Rust Primary Dependencies:** `security-framework` (macOS Keychain), `aes-gcm`, `serde`, `serde_json`, `sha3`.
- **Python Fallback Engine:** `kyber-py` (pure Python ML-KEM-768) + `cryptography` (AES-256-GCM).
- **Python Fallback Dependencies:** Managed inline via UV script metadata — `kyber-py>=0.2.0`, `cryptography>=44.0` (auto-resolved by `uv run`).

---

## 5. Application Integration Guidelines

Applications must read secrets exclusively from environment variables populated dynamically in memory. Do not store or read plaintext files inside the application context.

### Pattern 1: Safe Environment Variable Consumption (Python)
```python
import os
import sys

def get_api_key(name: str) -> str:
    """Retrieve secret from environment, ensuring no fallback to disk files."""
    api_key = os.environ.get(name)
    if not api_key:
        print(f"CRITICAL ERROR: Environment variable '{name}' is not set.", file=sys.stderr)
        print("Please load secrets via 'secrets-load' before running this command.", file=sys.stderr)
        sys.exit(1)
    return api_key
```

### Pattern 2: Safe Environment Variable Consumption (Node.js)
```javascript
function getApiKey(name) {
    const apiKey = process.env[name];
    if (!apiKey) {
        console.error(`CRITICAL ERROR: Environment variable '${name}' is not set.`);
        console.error("Please load secrets via 'secrets-load' before running this application.");
        process.exit(1);
    }
    return apiKey;
}
```

### Pattern 3: Safe Environment Variable Consumption (Rust)
```rust
fn get_api_key(name: &str) -> String {
    std::env::var(name).unwrap_or_else(|_| {
        eprintln!("CRITICAL ERROR: Environment variable '{}' is not set.", name);
        eprintln!("Please load secrets via 'secrets-load' before running this command.");
        std::process::exit(1);
    })
}
```

### Pattern 4: Shell Wrapper Integration
When wrapping command-line tools or other agents, pass env variables down rather than writing to disk config files. If a configuration file is strictly required by the tool (e.g. `auth.json` or `.env` file), write it dynamically to a secure directory (or temporary RAM disk if supported) and delete it immediately upon tool exit via traps.

```bash
# Example wrapper with exit trap for temporary configs
run_tool_with_secrets() {
  local temp_env
  temp_env=$(mktemp /tmp/tool-env.XXXXXX)
  trap 'rm -f "$temp_env"' EXIT
  
  # Populate temp config from environment variables loaded via secrets-load
  cat > "$temp_env" <<EOF
API_KEY="${ZENMUX_API_KEY}"
EOF

  command-tool --config "$temp_env" "$@"
}
```

### Pattern 5: Headless & CI/CD Pipelines
In headless environments where macOS Keychain is unavailable, use standard platform secrets injection (e.g., GitHub Secrets, Kubernetes Secrets, or Docker environment flags) passed dynamically from standard input.
```bash
# Injecting secrets directly via stdin to avoid write-to-disk
docker run -e ZENMUX_API_KEY=$(bin/pqc-secrets export | grep ZENMUX_API_KEY | cut -d= -f2) my-image
```
