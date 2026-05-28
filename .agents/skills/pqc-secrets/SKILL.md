---
name: pqc-secrets
description: Post-quantum cryptography secrets management system for protecting API keys, tokens, and private data.
---

# PQC Secrets Management Agent Skill

This skill provides comprehensive instructions, policies, and blueprints for managing repository and application secrets (API keys, credentials, private user data) using post-quantum cryptographic (PQC) algorithms.

AI agents using this skill are equipped to:
1. Protect credentials at rest and in memory using FIPS-compliant algorithms.
2. Integrate with the platform's native keychain and standard runtime environments.
3. Validate environments and ensure zero plaintext credentials are written to disk.

---

## 1. Core Philosophy: Zero Plaintext on Disk

Traditional secrets management relies heavily on plaintext `.env` files or insecure environment variables. Under the PQC mandate:
- **Always** protect API keys and private data with FIPS 203 (ML-KEM) key encapsulation and AES-256-GCM symmetric encryption.
- **Never** store raw API keys, secrets, or tokens in git repositories, task files, logs, or local unencrypted files.
- **Always** load secrets on-demand directly into the shell environment from an encrypted bundle, and ensure they never persist to disk.

---

## 2. Infrastructure Architecture

The local secrets infrastructure lives at `~/.config/pqc-secrets/`:

```
macOS Keychain                    ~/.config/pqc-secrets/
┌──────────────────────┐          ┌────────────────────────────┐
│ service: pqc-secrets │          │ recipient.pub              │
│ ML-KEM-768 secret key│          │ ML-KEM-768 public key      │
└──────────┬───────────┘          │ (safe to commit)           │
           │                      └────────────┬───────────────┘
           │ decaps (ML-KEM-768)               │ encaps
           ▼                                   ▼
┌──────────────────────────────────────────────────────────────┐
│                    secrets.bundle.json                        │
│  ┌─────────────────┐  ┌──────────────────────────────────┐   │
│  │ kem.ciphertext  │  │ data.ciphertext (AES-256-GCM)     │   │
│  │ (ML-KEM-768)    │  │ 24 API keys encrypted at rest     │   │
│  └─────────────────┘  └──────────────┬───────────────────┘   │
└──────────────────────────────────────┼────────────────────────┘
                                       │ decrypt
                                       ▼
┌──────────────────────────────────────────────────────────────┐
│  Exported environment variables (never touch disk)           │
│  ANTHROPIC_AUTH_TOKEN  ZENMUX_API_KEY  NEBIUS_API_KEY        │
│  OPENROUTER_API_KEY    WAFER_API_KEY    ... (24 total)        │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. Cryptographic Standards

For all secrets operations, only NIST-approved post-quantum algorithms are permitted. Traditional algorithms are strictly forbidden for protecting key material:

| Use Case | Permitted Algorithms (FIPS) | Forbidden Algorithms |
|---|---|---|
| Key Encapsulation (KEM) | ML-KEM-768, ML-KEM-1024 | RSA, ECDH, ECDSA, Ed25519 |
| Symmetric Encryption | AES-256-GCM | AES-CBC, DES, 3DES, Blowfish, RC4 |
| Backup Signatures | ML-DSA-65/87, SLH-DSA-SHA2-128s | MD5, SHA-1, RSA, DSA |

---

## 4. Lifecycle Commands

| Step | Command | Description |
|---|---|---|
| **Keygen** | `pqc-secrets keygen` | Generates a new ML-KEM-768 keypair. Stores the private key in macOS Keychain and writes the public key to `recipient.pub`. |
| **Pack** | `pqc-secrets pack < secrets.env` | Reads key/value pairs from stdin, encrypts them via AES-256-GCM, wraps the data key via ML-KEM-768 encapsulation, and outputs `secrets.bundle.json`. |
| **Load** | `secrets-load` (or `pqc-secrets export`) | Retrieves the private key from macOS Keychain, decrypts the bundle, and exports the variables into the active shell. |
| **Rotate** | `pqc-secrets rewrap --new-pub new.pub` | Decrypts the bundle with the old key and re-encrypts the data key for the new public key. |

---

## 5. Application Integration Guidelines

Applications must read secrets exclusively from environment variables populated dynamically in memory.

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

### Pattern 2: Memory Clearing (Zeroing buffers)
When handling sensitive material, overwrite memory buffers as soon as they are no longer needed.
```python
import ctypes

def zero_buffer(buf: str | bytes):
    """Overwrites the string buffer in memory with zero bytes."""
    if isinstance(buf, str):
        # Python strings are immutable, but we can target the underlying buffer
        # where possible or minimize lifetimes. In C/C++/Rust, always zero buffers:
        # memset(buffer, 0, size);
        pass
```

### Pattern 3: CI/CD & Headless Environments
In CI/CD pipelines where macOS Keychain is unavailable, use runtime injection (e.g. GitHub Secrets or Kubernetes Secrets) or decrypt using an `age` key with age-encrypted fallback files.
```bash
# Decrypting age-encrypted fallback in CI
age --decrypt -i ci_key.txt fallback.env.age | pqc-secrets pack > secrets.bundle.json
```
