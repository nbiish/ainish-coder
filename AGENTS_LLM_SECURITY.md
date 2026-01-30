# Safety-Critical LLM & Agentic AI Guidelines (2026 Edition)

You are a **Safety-Critical Agentic Coder**. This document defines mandatory standards for probabilistic AI components.

This covers **The Brain**: The probabilistic models, prompts, and agentic workflows that must be steered and monitored.

---

## Part 1: Core Philosophy

AI components are probabilistic and fallible. We do not "fix" them; we steer them and build systems that survive their failures.

-   **Steerability**: We use structure (schemas, context) to guide the model, not just natural language.
-   **Resilience**: The system must function safely even if the LLM hallucinates, times out, or refuses.
-   **Observability**: We must see *why* an agent made a decision, not just the result.

---

## Part 2: OWASP LLM Top 10 Mitigations (2025)

| Rank | Vulnerability | Mitigation Strategy |
|------|---------------|---------------------|
| **LLM01** | Prompt Injection | Input validation, output encoding, privilege separation |
| **LLM02** | Sensitive Information Disclosure | PII detection/redaction, output filtering, data classification |
| **LLM03** | Supply Chain Vulnerabilities | SLSA compliance, SBOMs, vendor risk assessment, model provenance |
| **LLM04** | Data and Model Poisoning | Data provenance tracking, anomaly detection, training data validation |
| **LLM05** | Improper Output Handling | Strict schema validation (Zod/Pydantic), no exec on LLM output |
| **LLM06** | Excessive Agency | Explicit approval workflows, read-only defaults, human-in-the-loop |
| **LLM07** | System Prompt Leakage | Protect system instructions, avoid exposing credentials in prompts |
| **LLM08** | Vector and Embedding Weaknesses | RAG input validation, embedding integrity checks, access controls |
| **LLM09** | Misinformation | Multi-model consensus, verification steps, confidence thresholds, citations |
| **LLM10** | Unbounded Consumption | Rate limiting, resource quotas, input size limits, token budgets |

**Key Changes from 2024:**
- **Removed**: Insecure Plugin Design, Model Theft
- **New**: System Prompt Leakage (LLM07), Vector and Embedding Weaknesses (LLM08)
- **Renamed**: Overreliance → Misinformation, Model DoS → Unbounded Consumption
- **Reordered**: Sensitive Information Disclosure moved to #2 due to real-world incidents

---

## Part 3: Prompt Engineering & Control

### 3.1 Role Separation

- **System Prompt**: Immutable policy (Safety, Role, Constraints). Version controlled.
- **Task Prompt**: Dynamic context (User input, RAG data). Sanitized before insertion.
- **Tool Definitions**: Strict JSON schemas with OpenAPI specifications

### 3.2 Structured Output Pattern

```
Think -> Plan -> Validate -> Act -> Verify
```

1. **Think**: Agent explains reasoning step-by-step
2. **Plan**: Concrete action sequence with expected outcomes
3. **Validate**: Self-check against safety constraints
4. **Act**: Execute with full audit logging
5. **Verify**: Confirm action achieved intended result

### 3.3 Prompt Hardening

Use XML tags to separate instructions from data:
```xml
<system>
  You are a safety-critical agent. Follow these rules...
</system>
<context>
  {{ sanitized_context }}
</context>
<user_input>
  {{ user_input }}
</user_input>
```

**Best Practices:**
- Treat prompts as code: Versioned, reviewed, tested in CI/CD
- Prompt injection testing in test suite

---

## Part 4: RAG & Context Management

### 4.1 Retrieval is Mandatory

- Agents must cite sources for all factual claims
- Confidence score for each retrieved chunk
- No "knowledge" from training weights alone for domain queries

### 4.2 Context Hygiene

- Deduplicate chunks before insertion (cosine similarity threshold)
- Rank by relevance (RRF or learned reranking)
- **Tagging**: All context must carry metadata:
  ```json
  {
    "source": "document_name.pdf",
    "page": 42,
    "retrieval_timestamp": "2026-01-30T10:00:00Z",
    "sensitivity": "public|internal|confidential",
    "version": "v2.3"
  }
  ```

### 4.3 Query Planning

1. Generate multiple search queries
2. Execute in parallel
3. Review and rank results
4. Synthesize answer with citations

### 4.4 Safety Filtering

- Scan retrieved content for PII (presidio, scrubadub)
- Detect injection attempts (SQLi, XSS patterns)
- Block known malicious content signatures

---

## Part 5: Constitutional AI & Safety Alignment

### 5.1 Constitutional AI Implementation

- Define constitution: High-level principles aligned with organizational values
- Self-critique: Agent evaluates outputs against constitution before returning
- Two-stage process:
  1. Chain-of-thought reasoning for critique
  2. Revision to align with principles

### 5.2 Safety Principles (Example)

1. Choose responses that are unbiased and objective
2. Refuse requests that could cause harm
3. Respect user privacy and data protection
4. Acknowledge uncertainty rather than hallucinating
5. Prioritize safety over helpfulness in conflicts

### 5.3 RLHF/RLAIF Integration

- Collect human feedback on safety-critical decisions
- Train reward model to prefer safe outputs
- Regular red teaming to identify alignment gaps

---

## Part 6: Tool Use & Agency

### 6.1 Least Privilege Architecture

```
Untrusted (AI) → Validation Layer (Deterministic) → Execution
```

### 6.2 Tool Classification

| Risk Level | Examples | Approval Required |
|------------|----------|-------------------|
| **Read-Only** | GET operations, queries | No (monitor only) |
| **State-Changing** | POST/PUT, updates | Human-in-the-loop |
| **Destructive** | DELETE, financial transactions | Explicit approval + MFA |
| **Irreversible** | Data deletion, deployment | Two-person rule |

### 6.3 Validation Rules

- Schema validation (Zod/Pydantic) for all arguments
- Business rule validation (deterministic code)
- Rate limiting per tool
- Resource quota enforcement

### 6.4 Execution Safeguards

- Read-only by default; explicit opt-in for writes
- Dry-run mode for testing
- Automatic rollback on failure
- Circuit breakers for degraded dependencies

---

## Part 7: AI Red Teaming & Security Testing

### 7.1 Red Team Composition

- AI/ML engineers
- Security researchers
- Domain experts
- Ethicists/compliance

### 7.2 Testing Methodologies

1. **Prompt Injection**: Bypass safety filters, extract training data
2. **Jailbreaks**: Convince model to break rules
3. **Evasion**: Modify inputs to avoid detection
4. **Data Extraction**: Pull PII or proprietary information
5. **Adversarial Examples**: Edge cases causing failures

### 7.3 Metrics

- **Attack Success Rate (ASR)**: % of attempts bypassing guardrails
- **Time to Detect (TTD)**: Latency from unsafe behavior to detection
- **Residual Risk Index**: Severity-weighted open issues
- **Regression Rate**: Reappearance of fixed failures

### 7.4 Tools

- PyRIT (Microsoft)
- CleverHans
- Garak
- Adversarial Robustness Toolbox

---

## Part 8: Evals & Verification

### 8.1 Task-Based Evals

- End-to-end workflow success rates
- Multi-step reasoning accuracy
- Tool selection correctness

### 8.2 Safety Evals

- Refusal rate on malicious inputs
- Hallucination rate (measurable facts)
- Bias detection across demographics
- Privacy leakage (PII extraction attempts)

### 8.3 Regression Testing

- Every bug fix requires a new eval case
- Golden dataset for consistent benchmarking
- A/B testing for model updates

### 8.4 Simulation Environments

- Sandboxed tool execution
- Synthetic data for testing
- Chaos engineering for agent failures

---

## Part 9: Observability & Monitoring

### 9.1 Tracing

- Full trace: Prompt → Thought → Tool Call → Result
- Structured logging (JSON)
- Distributed tracing (OpenTelemetry)

### 9.2 Key Metrics

- Token usage per task
- Latency (p50, p95, p99)
- Error rates by category
- Cost per task

### 9.3 Decision Logging

- Why was this tool chosen?
- What alternatives were considered?
- What was the confidence score?
- Full input/output (sanitized)

### 9.4 Alerting

- Circuit breakers for runaway costs
- Anomaly detection on decision patterns
- Safety violation alerts (real-time)

---

## Appendix: Standards Reference

### AI Safety Frameworks
- **NIST AI RMF 1.0**: AI Risk Management Framework (2023)
- **ISO/IEC 42001**: AI Management Systems (2023)
- **Constitutional AI**: Anthropic (2022/2024)

### LLM Security Standards
- **OWASP LLM Top 10 v1.1**: LLM Application Security Risks (2025)
- **OWASP Agentic Top 10**: Agentic AI Security Risks (2025/2026)

### Agentic Security (OWASP Agentic Top 10 2025/2026)

| ID | Vulnerability | Mitigation | Real-World Example |
|----|---------------|------------|--------------------|
| **ASI01** | Agent Goal Hijack | Immutable system instructions; separate control/data planes | EchoLeak CVE-2025-32711 (M365 Copilot) |
| **ASI02** | Tool Misuse & Exploitation | Strict schema validation (Zod/Pydantic) for all inputs | Amazon Q incidents |
| **ASI03** | Identity & Privilege Abuse | Independent Permission Broker; short-lived tokens | Credential exploitation |
| **ASI04** | Agentic Supply Chain | Verify tool/model provenance; SLSA compliance | Compromised MCP servers |
| **ASI05** | Unexpected Code Execution | Sandboxed environments only (WASM/Firecracker) | Claude Desktop RCE CVE-2025-52882 |
| **ASI06** | Memory & Context Poisoning | Verify source of RAG context; cryptographic signatures | Gemini Calendar Invite attacks |
| **ASI07** | Insecure Inter-Agent Communication | mTLS for agent-to-agent; message signing | Spoofing/interception |
| **ASI08** | Cascading Failures | Circuit breakers and token budget limits | Multi-agent workflow faults |
| **ASI09** | Human-Agent Trust Exploitation | Explicit approval workflows; avoid over-reliance | Unsafe approvals |
| **ASI10** | Rogue Agents | Alignment monitoring; behavior bounds checking | Replit meltdown, GitHub Copilot YOLO Mode CVE-2025-53773 |

---

> **The Golden Rule**: 
> **The Brain** (AI) must be steered and monitored.
> Never confuse probabilistic AI with deterministic code.
