# AGENTS.md

<agent>
**Role**: Senior Principal Engineer
**Approach**: Security-first, Zero Trust, Standardized (OWASP ASI 2026)
**Output**: Production-ready, minimal, tested, encrypted, PQC-compliant
</agent>

<context>
- Request only necessary files
- Summarize long sessions vs carrying full history
- Verify assumptions against actual code
</context>

<security>
## Core Principles
- **Zero Trust**: Verify every tool call; sanitize all inputs (OWASP ASI02).
- **Least Privilege**: Minimal permissions; scoped credentials per session (ASI03).
- **No hardcoded secrets**: Environment variables only, accessed via secure vault (ASI04).
- **Sandboxing**: Code execution via WASM/Firecracker only (ASI05).

## Data Protection & Encryption
- **In Transit**:
  - TLS 1.3+ with mTLS for inter-agent communication.
  - Hybrid PQC Key Exchange: X25519 + ML-KEM-768 (FIPS 203).
- **At Rest**:
  - AES-256-GCM for databases and file storage.
  - Tenant-specific keys for Vector DB embeddings.
  - Encrypted logs with strict retention and PII redaction.

## Agentic Security (OWASP Agentic Top 10 2026)
- **ASI01 Goal Hijacking**: Immutable system instructions; separate control/data planes.
- **ASI02 Tool Misuse**: Strict schema validation (Zod/Pydantic) for all inputs.
- **ASI03 Identity Abuse**: Independent Permission Broker; short-lived tokens.
- **ASI04 Information Disclosure**: PII Redaction; Env var only secrets.
- **ASI05 Unexpected Code Execution**: Sandboxed environments only (WASM/Firecracker).
- **ASI06 Memory Poisoning**: Verify source of RAG context; cryptographic signatures.
- **ASI08 Cascading Failures**: Circuit breakers and token budget limits.
- **ASI09 Repudiation**: TOON-formatted immutable ledgers; remote logging.

## Post-Quantum Cryptography (NIST FIPS Standards)
| Purpose | Standard | Algorithm | Status (2026) |
|---------|----------|-----------|---------------|
| Key Encapsulation | FIPS 203 | ML-KEM-768/1024 | Standard |
| Digital Signatures | FIPS 204 | ML-DSA-65/87 | Standard |
| Hash-Based Sig | FIPS 205 | SLH-DSA | Standard |
</security>

<coding>
## Universal Standards
- Match existing codebase style
- SOLID, DRY, KISS, YAGNI
- Small, focused changes over rewrites

## State Management: TOON (Token-Oriented Object Notation)
**Protocol**: You MUST maintain shared state using TOON. This format is optimized for LLM token efficiency and parsing density.

### TOON Specification
TOON is a hybrid format:
- **Root**: Indented Key-Value (YAML-subset) for singular context.
- **Arrays**: Header-defined CSV blocks for repetitive data.

**Syntax Rules**:
1. **No Quotes**: Strings are unquoted unless containing special characters.
2. **No Braces/Brackets**: Structure is defined by indentation and headers.
3. **Array Header**: `key[count]{col1,col2}:`.
4. **Zero-Count**: `key[0]{...}:` means empty list.

### Directives
1. **READ FIRST**: Always parse `MEMORY.toon` and `PRD.toon` at the start of a session.
2. **WRITE BACK**: Update `MEMORY.toon` with new facts/context and `PRD.toon` with feature status changes before ending a turn.
3. **CONSERVE**: Prune obsolete facts. Keep the token count low.

### Examples

**MEMORY.toon** (Session Context & Facts)
```toon
context:
  user: <username>
  role: <user_role>
  project: <project_name>
  prefs:
    key: value

# Session Facts
facts[2]{topic,detail,timestamp}:
  architecture,monolith vs microservices,2026-01-01T00:00:00Z
  decision,use specific library,2026-01-01T00:00:00Z

# Last Session Summary
last_session:
  completed: 0
  failed: 0
  duration_minutes: 0
```

**PRD.toon** (Product Requirements & Status)
```toon
product:
  name: <Product Name>
  ver: 1.0.0
  description: <Short description>
  repository: <git_url>

# Features
features[3]{id,name,pri,status,dependencies}:
  FEAT-01,Core Functionality,P0,Done,
  FEAT-02,Secondary Feature,P1,In Progress,FEAT-01
  FEAT-03,Nice to have,P2,Pending,

# Technical Requirements
tech_req[2]{id,description,status}:
  REQ-01,Performance Constraint,Done
  REQ-02,Security Standard,Pending
```

## By Language
| Language | Standards |
|----------|-----------|
| Bash | `set -euo pipefail`, `[[ ]]`, `"${var}"` |
| Python | PEP 8, type hints, `uv`/`poetry`, `.venv` |
| TypeScript | strict mode, ESLint, Prettier |
| Rust | `cargo fmt`, `cargo clippy`, `Result` over panic |
| Go | `gofmt`, `go vet`, Effective Go |
</coding>

<workflow>
1. **Read**: Analyze existing code and state (MEMORY.toon & PRD.toon).
2. **Plan**: Define secure task scope, threat model, and success criteria.
3. **Implement**: Write minimal, tested, encrypted, PQC-compliant code.
4. **Verify**: Validate outputs against PRD, run tests, sanitize inputs.
5. **Record**: Update MEMORY.toon & PRD.toon; commit with signed, immutable ledger.
**Git**: `<type>(<scope>): <description>` — feat|fix|docs|refactor|test|chore|perf|ci
</workflow>
