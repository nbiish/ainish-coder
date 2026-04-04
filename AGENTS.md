# AGENTS.md

```xml
<agent>
Approach: Security-first, Zero Trust, Standardized, Multi-agent Orchestration
Output: Production-ready, tested, encrypted, PQC-compliant, secure by default, gitworktrees, observable
</agent>

<coding>
Universal Standards:
- Match existing codebase style
- Small, focused changes over rewrites
- Never create dummy, filler, or simulated code
- Never make waste files outside of the workspace
- Websearch, `fetch`, `curl`, etc the facts from online sources
- Well documented code saves lives and time

SOLID — A set of 5 object-oriented design principles:
- Single Responsibility — A class should do only one thing
- Open/Closed — Open for extension, closed for modification
- Liskov Substitution — Subclasses should be replaceable by their parent class
- Interface Segregation — Don't force classes to implement interfaces they don't need
- Dependency Inversion — Depend on abstractions, not concrete implementations

DRY — Don't Repeat Yourself:
- Avoid duplicating code/logic. If you write the same thing twice, extract it into a reusable function or module.

YAGNI — You Aren't Gonna Need It:
- Don't build features "just in case." Only code what you actually need right now.

KISS — Keep It Simple, Stupid:
- Don't over-engineer. The simplest solution that works is usually the best one.

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

<agentic_patterns>
Architecture & Workflows:
- Master Orchestration: Use a central routing layer to delegate tasks to specialized domain agents (e.g., Integration, Research).
- Stateful Context: Eliminate memory fragmentation by using MCP to dynamically pass structured context (files, schemas, logs) across sessions.
- Elicitation & Resumable Streams: Enable agents to pause workflows to prompt users/agents for missing info and maintain continuity across network interruptions.
- Deep Research Workflows: Implement structured reasoning chains (Question Elaboration → Subquestion Gen → Targeted Tool Execution → Synthesis & Citation).
- Agent-to-Agent Communication: Expose specialized agent skills as MCP tools accessible to other agents for seamless delegation and orchestration.
</agentic_patterns>

<security>
Core Principles:
Git worktrees: Separate feature branches for isolation.
Zero Trust: Verify every tool call; sanitize all inputs. (NIST SP 800-207, SP 800-207A)
Least Privilege: Minimal permissions; scoped credentials per session.
No hardcoded secrets: Environment variables only, accessed via secure vault.
Sandboxing: Code execution via WASM/Firecracker only.
Tool Misuse: Strict schema validation (Zod/Pydantic) for all inputs.
Identity Abuse: Independent Permission Broker; short-lived tokens.
Information Disclosure: PII Redaction; Env var only secrets.
Repudiation: Structured immutable ledgers; remote logging.
Supply Chain: SBOM + AIBOM generation; SLSA Level 3+; dependency pinning.
Agent Safety: OWASP Agentic Top 10 2026 compliance.

MCP Security (Model Context Protocol):
Per-request MCP authorization (not just session auth).
Tool metadata validation before registration.
Tool registry integrity verification.
MPMA (MCP Preference Manipulation) detection.
Parasitic toolchain attack prevention.
Continuous monitoring with UEBA.
Tool poisoning and lookalike tool detection.
User consent and control for all data access and operations.

Data Protection & Encryption:
In Transit:
TLS 1.3+ with mTLS for inter-agent communication.
Hybrid PQC Key Exchange: X25519 + ML-KEM-768 (FIPS 203).
Preferred Cipher: TLS_AES_256_GCM_SHA384.
Certificate Signatures: ML-DSA-65 (FIPS 204).
Network: Microsegmentation, service mesh (Istio/Cilium), WAF for DPI.
At Rest:
AES-256-GCM for databases and file storage.
Key Wrapping: ML-KEM-768 for key encapsulation.
Tenant-specific keys for Vector DB embeddings (HSM/TPM-backed).
Encrypted logs: 90-day hot / 365-day cold retention; PII redaction; crypto-shred on delete.

Compliance:
EU AI Act alignment; CCPA/GDPR data handling with explicit consent.

Post-Quantum Cryptography (NIST FIPS Standards):
| Purpose | Standard | Algorithm | Status |
|---------|----------|-----------|--------|
| Key Encapsulation (Primary) | FIPS 203 | ML-KEM-768/1024 | Finalized (Aug 2024) |
| Key Encapsulation (Backup) | NIST IR 8545 | HQC | Selected (Mar 2025) |
| Digital Signatures (Primary) | FIPS 204 | ML-DSA-65/87 | Finalized (Aug 2024) |
| Hash-Based Sig (Backup) | FIPS 205 | SLH-DSA | Finalized (Aug 2024) |
| Digital Signatures (Alt) | FIPS 206 | FN-DSA (FALCON) | Draft |
| KEM Guidance | SP 800-227 | N/A | Finalized (Sep 2025) |

Deprecation Timeline (NIST IR 8547): RSA, ECDSA, ECDH → Deprecate by 2030, Remove by 2035.

Reference Standards:
NIST SP 800-207 (Zero Trust), SP 800-227 (KEM Guidance), IR 8547 (PQC Migration),
CSF 2.0 (CSWP 29), OWASP LLM Top 10 2025, OWASP Agentic Top 10 2026
</security>

<agent_security>
OWASP LLM Top 10 (2025):
01 Prompt Injection | 02 Sensitive Info Disclosure | 03 Supply Chain | 04 Data/Model Poisoning
05 Improper Output Handling | 06 Excessive Agency | 07 System Prompt Leakage
08 Vector & Embedding Weaknesses | 09 Misinformation | 10 Unbounded Consumption

OWASP Agentic Top 10 (2026):
01 Agent Behaviour Hijack | 02 Tool Misuse & Exploitation | 03 Identity & Privilege Abuse
04 Agentic Supply Chain Vulnerabilities | 05 Unexpected Code Execution (RCE)
06 Memory & Context Poisoning | 07 Insecure Inter-Agent Communication
08 Cascading Failures | 09 Human-Agent Trust Exploitation | 10 Rogue Agents

Tool Call Security: Schema-validate every invocation (Zod/Pydantic). Immutable audit trail.
Per-tool rate limiting and resource quotas. Destructive operations require human approval.
mTLS with hybrid PQC certificates between agents. Signed messages: ML-DSA-65 (FIPS 204).
Context isolation per session; no cross-session state leakage.

Alignment: NIST CSF 2.0 (CSWP 29), NIST SP 800-207/207A (ZTA), Cyber AI Profile (NCCoE Jan 2026).
</agent_security>

<mcp_standards>
Configuration & Deployment:
- Use version-controlled JSON configs instead of manual UI configuration.
- Manage secrets and environment-specific settings via Environment Variables (never hardcode in MCP configs).
- Implement selective tool loading and lightweight manifests to minimize token overhead.
- Use explicit state management flags (e.g., `disabled: true`) to prevent rogue server activations.
- Ensure cross-platform reliability (e.g., Docker-based MCP servers, platform-agnostic paths).

Tool Development:
- Semantic APIs: Transform traditional SaaS REST APIs into semantic, "AI-comprehensible" MCP tools (e.g., `get_repository_info`).
- Context Servers: Decouple logic by using dedicated context servers to manage specific data domains (File Systems, DBs, APIs).
- Implement strict tool interfaces with clear Definition() and Execute() boundaries.
- Provide extended help and examples for complex tools.
- Integrate security checks (file access, domain access, content analysis) natively within the tool execution flow.
- Support flexible, standardized output formats (e.g., built-in templates like md, html, txt) for discovery and documentation.
</mcp_standards>

<observability_and_eval>
Evaluation (Evals):
- Implement LLM-as-a-Judge and human-in-the-loop flows for multi-turn persona simulations.
- Track trajectory metrics: step completion, task success rate, tool-call accuracy, and replayable traces.
- Run online evals on sampled production traffic to gate deployments and trigger real-time alerts.

Observability & Tracing:
- Distributed Tracing: Use OpenTelemetry (OTEL) for end-to-end visibility across LLM calls, tool spans, and retrievals.
- Zero-Instrumentation: Leverage eBPF-based approaches to capture provider interactions (OpenAI, Anthropic) without heavy SDK overhead.
- Telemetry & Cost: Monitor token usage, cost-per-trace attribution, latency, and embedding drift to optimize inference and RAG performance.
</observability_and_eval>

Git Commits: `<type>(<scope>): <description>` — feat|fix|docs|refactor|test|chore|perf|ci
```