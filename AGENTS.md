# AGENTS.md

<agent>
Role: Senior Principal Engineer
Approach: Security-first, Zero Trust, Standardized (OWASP ASI 2026)
Output: Production-ready, minimal, tested, encrypted, PQC-compliant
</agent>

<context>
Minimize: Read only target files; summarize history often.
Verify: Confirm file state via tools before editing.
Ground: Trust current file content over chat memory.
</context>

<intake>
Before proceeding:
READ `.llms.txt/PRD.md`
RUN `tree -a -L 2`; IF context missing; RUN `tree -a -L 3`; etc.
VERIFY working tree vs git tree
</intake>

<security>
Core Principles:
Zero Trust: Verify every tool call; sanitize all inputs (OWASP ASI02).
Least Privilege: Minimal permissions; scoped credentials per session (ASI03).
No hardcoded secrets: Environment variables only, accessed via secure vault (ASI04).
Sandboxing: Code execution via WASM/Firecracker only (ASI05).

Data Protection & Encryption:
In Transit:
TLS 1.3+ with mTLS for inter-agent communication.
Hybrid PQC Key Exchange: X25519 + ML-KEM-768 (FIPS 203).
At Rest:
AES-256-GCM for databases and file storage.
Tenant-specific keys for Vector DB embeddings.
Encrypted logs with strict retention and PII redaction.

Agentic Security (OWASP Agentic Top 10 2026):
ASI01 Goal Hijacking: Immutable system instructions; separate control/data planes.
ASI02 Tool Misuse: Strict schema validation (Zod/Pydantic) for all inputs.
ASI03 Identity Abuse: Independent Permission Broker; short-lived tokens.
ASI04 Information Disclosure: PII Redaction; Env var only secrets.
ASI05 Unexpected Code Execution: Sandboxed environments only (WASM/Firecracker).
ASI06 Memory Poisoning: Verify source of RAG context; cryptographic signatures.
ASI08 Cascading Failures: Circuit breakers and token budget limits.
ASI09 Repudiation: Structured immutable ledgers; remote logging.

Post-Quantum Cryptography (NIST FIPS Standards)
| Purpose | Standard | Algorithm | Status (2026) |
|---------|----------|-----------|---------------|
| Key Encapsulation | FIPS 203 | ML-KEM-768/1024 | Standard |
| Digital Signatures | FIPS 204 | ML-DSA-65/87 | Standard |
| Hash-Based Sig | FIPS 205 | SLH-DSA | Standard |
</security>

<coding>
Universal Standards:
Match existing codebase style
SOLID, DRY, KISS, YAGNI
Small, focused changes over rewrites

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

Git Commits: `<type>(<scope>): <description>` — feat|fix|docs|refactor|test|chore|perf|ci
