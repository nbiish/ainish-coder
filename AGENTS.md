# AGENTS.md

```xml
<agent>
Approach: Security-first, Zero Trust, Standardized  
Output: Production-ready, tested, encrypted, PQC-compliant

Self-reflect and update the user on your actions and decisions with the `tts-cli` tool as follows:
`tts-cli "{self_reflect_current_task} {concise_user_update}"`

If the `local-tts-mcp` tool is available, use the mcp tool instead.
</agent>

<coding>
Universal Standards:
Match existing codebase style
SOLID, DRY, KISS, YAGNI
Small, focused changes over rewrites
Never create dummy code
Fetch the current date
Websearch the facts

By Language:
| Language | Standards |
|----------|-----------|
| Bash | `set -euo pipefail`, `[[ ]]`, `"${var}"` |
| Python | PEP 8, type hints, `uv`/`poetry`, `.venv` |
| TypeScript | strict mode, ESLint, Prettier |
| Rust | `cargo fmt`, `cargo clippy`, `Result` over panic |
| Go | `gofmt`, `go vet`, Effective Go |
| C++ | `clang-format`, `clang-tidy`, C++20, RAII |
</coding>

<security>
Core Principles:
Zero Trust: Verify every tool call; sanitize all inputs. (NIST SP 800-207)
Least Privilege: Minimal permissions; scoped credentials per session.
No hardcoded secrets: Environment variables only, accessed via secure vault.
Sandboxing: Code execution via WASM/Firecracker only.
Tool Misuse: Strict schema validation (Zod/Pydantic) for all inputs.
Identity Abuse: Independent Permission Broker; short-lived tokens.
Information Disclosure: PII Redaction; Env var only secrets.
Repudiation: Structured immutable ledgers; remote logging.
Supply Chain: SBOM + AIBOM generation; SLSA Level 3+; pinned deps with hash verification.

Data Protection & Encryption:
In Transit:
TLS 1.3+ with mTLS for inter-agent communication.
Hybrid PQC Key Exchange: X25519 + ML-KEM-768 (FIPS 203).
Preferred Cipher: TLS_AES_256_GCM_SHA384.
Certificate Signatures: Transition to ML-DSA-65 (FIPS 204).
At Rest:
AES-256-GCM for databases and file storage (quantum-safe at 256-bit).
Key Wrapping: ML-KEM-768 for key encapsulation (replacing RSA wrap).
Tenant-specific keys for Vector DB embeddings (HSM/TPM-backed).
Encrypted logs: 90-day hot / 365-day cold retention; PII redaction; crypto-shred on delete.

Post-Quantum Cryptography (NIST FIPS Standards)
| Purpose | Standard | Algorithm |
|---------|----------|-----------|
| Key Encapsulation (Primary) | FIPS 203 | ML-KEM-768/1024 |
| Key Encapsulation (Backup) | TBD | HQC |
| Digital Signatures (Primary) | FIPS 204 | ML-DSA-65/87 |
| Hash-Based Sig (Backup) | FIPS 205 | SLH-DSA |
| Digital Signatures (Alt) | FIPS 206 | FN-DSA (FALCON) |

PQC CLI Examples (OpenSSL 3.5+ with oqs-provider):
# Generate ML-KEM-768 key pair
openssl genpkey -algorithm mlkem768 -out mlkem768.pem
# Encapsulate a shared secret
openssl pkeyutl -encapsulate -inkey mlkem768.pem -out ciphertext.bin -secret shared.bin

# Generate ML-DSA-65 signing key
openssl genpkey -algorithm mldsa65 -out mldsa65.pem
# Sign a file
openssl pkeyutl -sign -inkey mldsa65.pem -in message.bin -out signature.bin -rawin
# Verify a signature
openssl pkeyutl -verify -pubin -inkey mldsa65_pub.pem -in message.bin -sigfile signature.bin -rawin

# Hybrid PQC TLS server (X25519 + ML-KEM-768)
openssl s_server -cert cert.pem -key key.pem -groups x25519_mlkem768

# Generate SLH-DSA key pair (hash-based backup signatures)
openssl genpkey -algorithm slhdsa128s -out slhdsa.pem

Deprecation: RSA, ECDSA, ECDH → Deprecate by 2030, Remove by 2035 (NIST IR 8547).
</security>

<agent_security>
OWASP LLM Top 10 (2025) — mitigate each:
01 Prompt Injection
02 Sensitive Information Disclosure
03 Supply Chain Vulnerabilities
04 Data & Model Poisoning
05 Improper Output Handling
06 Excessive Agency
07 System Prompt Leakage
08 Vector & Embedding Weaknesses
09 Misinformation
10 Unbounded Consumption

OWASP Agentic Top 10 (2026) — mitigate each:
01 Agent Behaviour Hijack
02 Tool Misuse & Exploitation
03 Identity & Privilege Abuse
04 Agentic Supply Chain Vulnerabilities
05 Unexpected Code Execution (RCE)
06 Memory & Context Poisoning
07 Insecure Inter-Agent Communication
08 Cascading Failures
09 Human-Agent Trust Exploitation
10 Rogue Agents

AIBOM: Generate AI Bill of Materials for all AI/ML components.
AI Red Teaming: Per OWASP Vendor Evaluation Criteria v1.0 (Feb 2026).

Tool Call Security:
Schema-validate every invocation (Zod/Pydantic).
Immutable audit trail with input/output hashes.
Per-tool rate limiting and resource quotas.
Destructive operations require human approval.

Inter-Agent Security:
mTLS with hybrid PQC certificates between agents.
Signed messages: ML-DSA-65 (FIPS 204).
Context isolation per session; no cross-session state leakage.

Alignment:
NIST CSF 2.0 (CSWP 29): Govern, Identify, Protect, Detect, Respond, Recover.
NIST SP 800-207 / 207A: Zero Trust Architecture.
Cyber AI Profile: Monitor (NCCoE, workshop Jan 2026).
</agent_security>

Git Commits: `<type>(<scope>): <description>` — feat|fix|docs|refactor|test|chore|perf|ci


```  
