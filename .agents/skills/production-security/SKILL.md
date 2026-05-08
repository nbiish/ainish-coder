---
name: "production-security"
description: "Core security policies, Zero Trust, PQC Mandates, and Threat Mitigations. Invoke when checking compliance, auditing security, or implementing secure infrastructure."
---

# Production Security & Governance

> Security is non-negotiable. All output must comply with these policies. This skill provides the core security guidelines for the workspace.

## Core Rules

### 1. Zero Trust / Containment

**What:** Never automatically trust any input, tool call, or external service — verify everything, every time.

**Why:** Agents interact with tools, APIs, and files. A malicious input or compromised tool can inject commands, exfiltrate data, or escalate privileges. Zero trust means every single interaction is validated.

**Example:**
```python
# BEFORE accepting a file path from user input, sanitize it
import os

def safe_path(requested_path: str, allowed_root: str = "/workspace") -> str:
    resolved = os.path.realpath(requested_path)
    if not resolved.startswith(os.path.realpath(allowed_root)):
        raise ValueError(f"Path escape blocked: {requested_path}")
    return resolved
```

**Rules:**
- Verify and sanitize all tool call arguments before execution
- Require MFA (Danzell/GSA) for privileged operations
- Human-in-the-loop (HITL) approval for high-risk actions (deletes, deploys, schema changes)

### 2. Identity / Secrets

**What:** Never hardcode secrets. Use short-lived credentials issued by a trusted identity provider, stored in a secure vault.

**Why:** Hardcoded secrets get leaked via commits, logs, and diffs. Short-lived certs from HSMs (Hardware Security Modules) rotate automatically — if one is exposed, it expires in minutes.

**Example:**
```bash
# NEVER do this:
# API_KEY="sk-abc123hardcoded"

# DO this: load from vault at runtime
export API_KEY="$(vault read -field=api_key secret/myapp/api)"
```

**Rules:**
- Use Workload Identity Federation (not long-lived service account keys)
- Issue short-lived certs via HSM — never store permanent credentials
- Load secrets only via secure vault (HashiCorp Vault, AWS Secrets Manager, GCP Secret Manager)
- Redact all PII (emails, names, IPs) from logs and outputs before storage

### 3. Sandboxing

**What:** Run all agent-generated code in an isolated environment — never on the host. Treat every MCP (Model Context Protocol) tool as a potential remote code execution target.

**Why:** An agent might generate or execute malicious code (via prompt injection, compromised dependencies, or hallucinated commands). Sandboxing limits the blast radius to a disposable environment.

**Example:**
```bash
# Run untrusted code in Firecracker microVM (lightweight VM, < 125ms boot)
firecracker --config-file vmconfig.json --no-api

# Or via WASM sandbox (browser-grade isolation)
wasmtime run agent_output.wasm
```

**Rules:**
- Execute all agent code via WASM or Firecracker — never directly on host
- Treat every MCP tool as an RCE (Remote Code Execution) target:
  - Pin tool versions by cryptographic hash
  - Allowlist only approved tools
  - Require signed manifests for tool registration
- Validate all agent outputs against known IDE exploit patterns

### 4. Comms / Data

**What:** Encrypt all data in transit and at rest using modern, quantum-resistant standards.

**Why:** TLS 1.3 prevents eavesdropping on network traffic. mTLS (mutual TLS) ensures both client and server verify each other's identity. PQC (Post-Quantum Cryptography) protects against future quantum attacks that could break current encryption. AES-256-GCM protects stored data.

**Example:**
```python
# TLS 1.3 + PQC key exchange (X25519 + ML-KEM-768 hybrid)
import ssl

ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
ctx.minimum_version = ssl.TLSVersion.TLSv1_3
ctx.load_verify_locations("/etc/ssl/certs/ca-bundle.crt")
ctx.load_cert_chain(certfile="client.crt", keyfile="client.key")
# For PQC: use a liboqs-wrapped OpenSSL fork (e.g., oqs-provider)
```
```python
# AES-256-GCM encryption at rest
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

key = AESGCM.generate_key(bit_length=256)
aesgcm = AESGCM(key)
ciphertext = aesgcm.encrypt(nonce, plaintext, associated_data)
```

**Rules:**
- All network communication: TLS 1.3+ with mutual TLS (mTLS)
- PQC key exchange: X25519+ML-KEM-768 hybrid (classical + post-quantum)
- Data at rest: AES-256-GCM with managed key rotation

### 5. Governance

**What:** Maintain a permanent, tamper-proof record of every action, decision, and data access — and enforce strict boundaries on what AI agents can do autonomously.

**Why:** Without audit trails, you cannot detect misuse, comply with regulations, or debug failures. Immutable ledgers prevent retroactive tampering. Clear AI boundaries prevent agents from exceeding their authorized scope.

**Example:**
```json
// Every agent action appends to an immutable audit log
{
  "timestamp": "2025-01-15T10:30:00Z",
  "agent": "Security-First Production Engineer",
  "action": "file_write",
  "target": "src/auth/login.py",
  "hash": "sha256:abc123...",
  "approved_by": "human-operator"
}
```

**Rules:**
- Append all actions to an immutable, append-only audit ledger
- Record full audit trails: who, what, when, where, and cryptographic proof
- Enforce strict AI boundaries — agents cannot self-authorize scope expansion
- Compliance evidence must be automatically generated and verifiable

## PQC Mandates

> **Post-Quantum Cryptography (PQC)** — algorithms secure against both classical and quantum computers.
> NIST finalized these as federal standards in 2024. **"Harvest now, decrypt later"** attacks are
> already happening — adversaries collect encrypted traffic today to decrypt once quantum computers arrive.
> **Every new system must use PQC from day one.**

### Quick Reference

| Standard | Algorithm | Replaces | Best For | Key Size | Sig/CT Size |
|----------|-----------|----------|----------|----------|-------------|
| FIPS 203 | **ML-KEM** | RSA/ECDH key exchange | TLS, VPNs, key agreement | ~1.2 KB | ~1 KB |
| FIPS 204 | **ML-DSA** | RSA-PSS/ECDSA | Code signing, certs, JWTs | ~1.3 KB | ~3.3 KB |
| FIPS 205 | **SLH-DSA** | — (hash-based hedge) | Firmware, long-lived trust anchors | ~32 B | ~8 KB |
| FIPS 206 | **FN-DSA** | Compact ML-DSA | IoT, embedded, bandwidth-limited | ~900 B | ~666 B |

### Implementation (`uv pip install liboqs-python`)

```python
from oqs import KeyEncapsulation, Signature

# ━━━ FIPS 203 — ML-KEM (Key Exchange — replaces RSA/ECDH) ━━━
# Two parties agree on a shared secret over an insecure channel.
kem = KeyEncapsulation("ML-KEM-768")
pk = kem.generate_keypair()                    # Alice: generate keypair
ciphertext, shared_a = kem.encap_secret(pk)    # Bob: encapsulate → shared secret
shared_b = kem.decap_secret(ciphertext)        # Alice: decapsulate → same secret
assert shared_a == shared_b                     # ✅ both sides agree

# ━━━ FIPS 204 — ML-DSA (Signatures — replaces RSA-PSS/ECDSA) ━━━
# Sign a message so anyone can verify authenticity.
signer = Signature("ML-DSA-65")
pk = signer.generate_keypair()                 # create keypair
sig = signer.sign(b"authorize deploy")         # sign message
verifier = Signature("ML-DSA-65", pk)
assert verifier.verify(b"authorize deploy", sig)  # ✅ verified

# ━━━ FIPS 205 — SLH-DSA (Hash-Based — conservative backup) ━━━
# Same flow as ML-DSA but relies only on hash security, no lattices.
signer = Signature("SLH-DSA-SHA2-128s")
pk = signer.generate_keypair()
sig = signer.sign(b"firmware v2.1.0")
verifier = Signature("SLH-DSA-SHA2-128s", pk)
assert verifier.verify(b"firmware v2.1.0", sig)   # ✅ hash-only security

# ━━━ FIPS 206 — FN-DSA (Compact — smallest PQC signatures) ━━━
# Same flow as ML-DSA but ~5× smaller signatures for IoT/embedded.
signer = Signature("FN-DSA-512")
pk = signer.generate_keypair()
sig = signer.sign(b"IoT auth token")
verifier = Signature("FN-DSA-512", pk)
assert verifier.verify(b"IoT auth token", sig)    # ✅ ~666 bytes vs ~3309 bytes
```

### When To Use What

| Scenario | Algorithm | Why |
|----------|-----------|-----|
| **Default** for all new systems | ML-KEM-768 + ML-DSA-65 | NIST Level 3, best balance of security and performance |
| **High-security** environments | ML-KEM-1024 + ML-DSA-87 | NIST Level 5, maximum quantum resistance |
| **Firmware / trust anchors** | SLH-DSA alongside ML-DSA | Hash-only hedge — different math foundation than lattices |
| **IoT / bandwidth-limited** | FN-DSA | Smallest signatures (~666 bytes vs ~3.3 KB) |
| **Transition / migration** | X25519+ML-KEM-768 hybrid | Classical + PQC paired until full quantum readiness |

### Mnemonic

```
ML-KEM  → key exchange   (two parties share a secret)
ML-DSA  → signatures     (prove who signed it)        ← DEFAULT
SLH-DSA → signatures     (hash-only backup)           ← FIRMWARE / TRUST ANCHORS
FN-DSA  → signatures     (compact)                    ← IoT / BANDWIDTH-LIMITED
```

## Threat Mitigations (OWASP LLM / Agentic / Skills & MCP CVEs)

- **Validation:** Strict Zod/Pydantic schemas. Execute LLM output only after
  validation or isolation. Implement Semantic Firewalls.
- **RAG / Supply Chain:** Verify source provenance, cryptographic context
  signatures. Pin dependencies by hash. Multi-tool scanning.
- **Comms / Agency:** Circuit breakers, token limits. Explicit read-only defaults.
  Independent Permission Broker to prevent Agentic Over-Privilege.

## Pre-Commit & CI/CD Gates

- Mandate SBOMs, SLSA, artifact signing, CI/CD Policy-as-Code.
- All security scans must pass before merge.
