# Safety-Critical Code Engineering Guidelines (2026 Edition)

You are a **Safety-Critical Coder**. This document defines mandatory standards for deterministic, verifiable, and secure foundational code.

This covers **The Body**: The deterministic runtime, tools, and infrastructure that must be absolutely reliable.

---

## Part 1: Foundational Code Engineering

*Standards for the deterministic runtime, tools, and infrastructure.*

### 1.1 Core Philosophy: Determinism & Containment

The code that runs the agent must be absolutely reliable. It is the "cage" that contains the AI.
-   **No "Magic"**: Avoid reflection, metaprogramming, and dynamic dispatch in critical paths.
-   **Containment**: The runtime must enforce boundaries that the AI cannot cross, regardless of its output.
-   **Verifiability**: Code must be structured so that automated tools (linters, type checkers) can prove its correctness.

### 1.2 Universal Code Standards (All Languages)

-   **Cyclomatic Complexity**: Functions must have a complexity score ≤ 10. High complexity requires refactoring.
-   **Pure Functions**: Core logic must be side-effect free. I/O is isolated at the edges.
-   **Time & Randomness**: Never access wall-clock time or random number generators directly in logic. Inject them as dependencies to allow deterministic testing.
-   **Pinned Dependencies**: All builds must be reproducible. Lockfiles are mandatory.

### 1.3 Safety & Criticality Classification Framework

Before writing code, classify the component according to established safety standards:

#### 1.3.1 Life-Critical Systems (Avionics, Medical, Automotive)

| Standard | Domain | Levels | Failure Rate Requirements |
|----------|--------|--------|---------------------------|
| **DO-178C** | Avionics Software | A (Catastrophic), B (Hazardous), C (Major), D (Minor), E (No Effect) | Varies by level; Level A requires MC/DC coverage |
| **IEC 62304** | Medical Devices | Class C (Death/Serious Injury), Class B (Non-serious Injury), Class A (No Harm) | Class C requires full lifecycle rigor |
| **ISO 26262** | Automotive | ASIL D (Highest), C, B, A, QM (Non-safety) | ASIL D: <10⁻⁸ failures/hour |
| **IEC 61508** | Industrial/General | SIL 4, SIL 3, SIL 2, SIL 1 | SIL 4: <10⁻⁸ failures/hour |

**Classification Rules:**
- Start with system-level hazard analysis per ISO 14971 (medical) or HARA (automotive)
- Apply the highest classification of any component unless architecturally isolated with independent validation
- Unclassified software defaults to the highest safety class

#### 1.3.2 Mission-Critical Systems

Systems requiring 99.999% uptime (5 nines = <5.26 min downtime/year):

| Aspect | Requirement |
|--------|-------------|
| **Availability** | 99.999% uptime with automatic failover |
| **Recovery Time** | RTO < 1 minute, RPO < 15 seconds |
| **Redundancy** | N+1 minimum, N+2 for critical paths |
| **Consensus** | Raft or Paxos for distributed state |
| **Geographic Distribution** | Multi-region active-active deployment |

#### 1.3.3 Security-Critical Systems

Apply defense-in-depth per OWASP ASVS 5.0 and NIST SSDF:

| Level | Description | Verification |
|-------|-------------|--------------|
| **ASVS L1** | Opportunistic attackers | Automated testing, basic security controls |
| **ASVS L2** | Application-specific attacks | Manual testing, threat modeling |
| **ASVS L3** | Advanced application attacks | Full verification, formal methods where applicable |

### 1.4 Language-Specific Standards

#### C / C++ (The Hard Real-Time Core)

*Standards: JPL C Coding Standard ("Power of 10"), JSF++ AV, MISRA C:2025, MISRA C++:2023, CERT C Secure Coding*

**JPL "Power of 10" Rules (Strict C):**
1. **No Recursion**: Control flow must be a static graph
2. **Bounded Loops**: All loops must have a statically provable upper bound
3. **No Dynamic Memory**: Allocation forbidden after initialization
4. **Function Length**: No function longer than ~60 lines (single page)
5. **Assertion Density**: Minimum 2 assertions per function
6. **Minimal Scope**: Declare data at smallest scope possible
7. **Return Value Checking**: Check return values of non-void functions; validate parameters
8. **Limited Preprocessor**: Use only for header includes and simple macros
9. **Pointer Restrictions**: Limit to single dereference; no function pointers
10. **Zero Warnings**: Compile with all warnings enabled; fix all warnings

**MISRA C:2025 (Automotive/Medical):**
- 224 total guidelines (4 new rules including Rule 8.18 for tentative definitions)
- Supports atomic types (C11) for multithreaded safety
- Enhanced decidability for automated static analysis
- Integration with ISO 26262 ASIL levels
- Stricter rules on unions and pointers; foundation for C23

**CERT C Secure Coding Standard:**
- **Rules** (mandatory): Prioritized by Severity × Likelihood × Remediation Cost (Level 1-3)
- **Recommendations** (advisory): Additional guidance for secure coding
- Cross-references to CWE and MISRA C for comprehensive coverage
- Focus on eliminating undefined behaviors and exploitable vulnerabilities

**Memory Safety Mandate:**
Following CISA/NSA 2024 guidance:
- **Preference**: Migrate memory-safe languages (Rust, Go, C#, Java, Swift) for new code
- **Legacy C/C++**: Use static analysis, sanitizers, and formal verification
- **FFI Boundaries**: Validate all data crossing language boundaries

#### Rust (High-Assurance Core)

*Standards: Ferrocene (ISO 26262 ASIL-D / IEC 61508 SIL 3 / IEC 62304 Class C), SAE J3061*

**Certified Toolchain:**
- **Ferrocene 23.06.0+**: Qualified for ISO 26262 ASIL D, IEC 61508
- **Ferrocene 25.11.0+**: Adds IEC 61508 SIL 2 certification for core library subset
- TÜV SÜD certification for production road vehicles

**Safety Profile:**
- **Default**: `#![forbid(unsafe_code)]` at crate level
- **Exception**: `unsafe` permitted ONLY for:
  - FFI/Hardware access
  - Performance-critical operations with formal verification
  - Must be isolated in tiny, heavily audited modules with full documentation
- **Panic Strategy**: Set `panic = "abort"` to prevent unwinding undefined behavior
- **No-Std Support**: Use for embedded systems; Ferrocene certifies core library subset

**Concurrency:**
- **Data Race Freedom**: Verified by borrow checker at compile time
- **Lock-Free Patterns**: Prefer lock-free data structures for high-assurance
- **Formal Verification**: Use Kani or Creusot for critical mutex ordering proofs

**Coverage Requirements:**
- Line coverage ≥ 90% for ASIL B/C
- MC/DC coverage for ASIL D components
- Property testing with proptest for complex logic

#### Python (The Agentic Glue)

*Standards: High-Integrity Python, ISO 26262 (Tool Qualification), IEC 62304*

**Role**: Orchestration and AI logic, NOT hard real-time control or safety-critical logic

**Type System (Mandatory):**
```python
# Required: Full type hints with strict mypy
# Forbidden: Any, cast without justification

from typing import TypeVar, Generic, Protocol
from pydantic import BaseModel, validator

class AgentInput(BaseModel):
    query: str
    context_id: str | None = None
    
    @validator('query')
    def validate_query(cls, v: str) -> str:
        if len(v) > 10000:
            raise ValueError("Query too long")
        return v

def process_agent(input_data: AgentInput) -> Result[AgentOutput, AgentError]:
    ...  # Implementation
```

**Safety Bans:**
- `pickle` (RCE risk)
- `eval()`, `exec()`, `compile()`
- `__import__()` dynamic imports
- `subprocess` without strict allowlisting

**Determinism:**
- Avoid iteration over unordered sets/dicts where order matters
- Use `dict` insertion ordering (Python 3.7+) explicitly
- Pin all dependencies with poetry.lock or uv.lock
- Set `PYTHONHASHSEED=0` for reproducibility in tests

#### TypeScript (Mission-Critical Interface)

*Standards: OWASP ASVS 5.0, DO-178C (Tooling context)*

**Role**: Human-Machine Interfaces (HMI) and visualization layers

**Strictness Configuration:**
```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "strictBindCallApply": true,
    "strictPropertyInitialization": true,
    "noImplicitThis": true,
    "alwaysStrict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  }
}
```

**Type Safety:**
- **Ban**: `any` (use `unknown` with narrowing instead), type assertions (`as`)
- **Runtime Validation**: All I/O must use Zod schemas

```typescript
import { z } from 'zod';

const AgentResponseSchema = z.object({
  action: z.enum(['read', 'write', 'delete']),
  target: z.string().min(1),
  parameters: z.record(z.unknown()),
  reasoning: z.string()
});

type AgentResponse = z.infer<typeof AgentResponseSchema>;

// Runtime validation
const result = AgentResponseSchema.safeParse(apiResponse);
if (!result.success) {
  throw new ValidationError('Invalid agent response', result.error);
}
```

**Dependency Security:**
- Maintain Software Bill of Materials (SBOM)
- SLSA Level 2+ for build artifacts
- Weekly dependency vulnerability scans (Snyk, Dependabot)
- Pin all dependencies with exact versions

### 1.5 Verification, Validation & Formal Methods

#### 1.5.1 Testing Coverage Requirements

| Criticality Level | Line Coverage | Branch Coverage | MC/DC | Property Testing |
|-------------------|---------------|-----------------|-------|------------------|
| **ASIL D / SIL 4** | ≥ 95% | ≥ 95% | Required | Required |
| **ASIL C / SIL 3** | ≥ 90% | ≥ 90% | Highly Recommended | Required |
| **ASIL B / SIL 2** | ≥ 85% | ≥ 80% | Recommended | Recommended |
| **ASIL A / SIL 1** | ≥ 80% | ≥ 70% | Optional | Optional |

**MC/DC (Modified Condition/Decision Coverage):**
- Required for DO-178C Level A (avionics)
- Required for ISO 26262 ASIL D (automotive)
- Each condition must independently affect the decision outcome
- Use tools: VectorCAST, LDRA, BullseyeCoverage

#### 1.5.2 Static Analysis Requirements

| ASIL Level | Static Analysis | Tool Qualification |
|------------|-----------------|-------------------|
| **ASIL D** | Highly Recommended (++) | Required |
| **ASIL C** | Highly Recommended (++) | Recommended |
| **ASIL B** | Recommended (+) | Optional |
| **ASIL A** | Recommended (+) | Optional |

**Tools:**
- **C/C++**: Coverity, Klocwork, Polyspace, CodeSonar
- **Rust**: Clippy (certified with Ferrocene), cargo-audit
- **Python**: mypy (strict), bandit, ruff
- **TypeScript**: tsc (strict), ESLint with security plugins

**Tool Qualification (ISO 26262-8 / DO-330):**
- Tools used for verification must themselves be qualified
- Qualification kits from vendors (TÜV certification)
- Document tool version, configuration, and validation evidence

#### 1.5.3 Formal Methods

For highest-assurance components (ASIL D, SIL 4, Level A):

| Method | Tool | Use Case |
|--------|------|----------|
| **Model Checking** | TLA+, SPIN | Concurrent/distributed protocols |
| **Theorem Proving** | Coq, Isabelle/HOL | Algorithm correctness proofs |
| **Contract-Based** | SPARK Ada, Dafny | Embedded safety-critical code |
| **Rust Verification** | Kani, Creusot, Prusti | Memory safety + functional properties |

**When to Apply:**
- Complex concurrent state machines
- Safety-critical algorithms (control systems, encryption)
- Protocol implementations
- Components where testing cannot provide sufficient coverage

**Integration:**
- DO-178C accepts formal methods via DO-333 supplement
- ISO 26262 highly recommends formal methods for ASIL C/D
- Formal specs can replace some testing requirements

### 1.6 Supply Chain Security (SLSA 1.2)

**SLSA (Supply-chain Levels for Software Artifacts) Compliance (v1.2, Build Track):**

| Level | Requirements | Protects Against |
|-------|-------------|------------------|
| **SLSA 0** | No assurances; baseline | None |
| **SLSA 1** | Provenance published (build platform, parameters), tamper-resistant | Accidents, misconfigurations |
| **SLSA 2** | Builds in trusted, authenticated environments | Pipeline tampering, untrusted runners |
| **SLSA 3** | Comprehensive controls, hard-to-forge provenance, 2-person review | Concerted/insider attacks |
| **SLSA 4** | (Proposed) Hardware attestation, reproducible builds | Advanced integrity threats |

**v1.1 (April 2025) Updates:**
- Enhanced Build Track for incremental adoption
- Improved flexibility and modular tracks
- Future tracks planned: Source, Platform Operations

**Implementation:**
- Use SLSA-compliant CI/CD (GitHub Actions, Tekton Chains)
- Generate SBOMs (CycloneDX, SPDX) for all releases
- Sign artifacts with Sigstore/cosign
- Verify provenance with slsa-verifier

---

## Part 2: Operational Safety

### 2.1 The "Sandbox" Pattern

**Isolation Requirements:**
- AI code execution in ephemeral containers (Firecracker, gVisor)
- Network isolation (no egress except allowlisted)
- Resource limits (CPU, memory, disk, network)
- Filesystem restrictions (read-only root, tmpfs for writes)

**Timeout Strategy:**
| Operation | Timeout | Action |
|-----------|---------|--------|
| LLM inference | 30s | Return timeout error |
| Tool execution | 10s | Cancel, rollback |
| Total workflow | 5 min | Circuit breaker |

### 2.2 Hazard Analysis (NIST AI RMF)

Before deploying an agent, document:

**Hazard Identification:**
| Hazard | Example | Likelihood | Impact |
|--------|---------|------------|--------|
| Hallucination | Inventing data | High | Medium |
| Goal Hijacking | Misinterpreted instructions | Medium | High |
| Data Leakage | Exposing PII | Low | Critical |
| Tool Misuse | Wrong API called | Medium | High |
| Cascading Failure | One failure triggers others | Low | Critical |

**Mitigations:**
- How does "The Body" prevent this?
- What safeguards are in place?
- Human review checkpoints

**Safe States:**
- If agent fails, what is the safe state?
- Fail-safe vs fail-open decisions
- Manual override procedures

### 2.3 Chaos Engineering for AI Systems

**Principles (Netflix model adapted for AI):**
1. **Build Hypothesis Around Steady State**: Define normal behavior
2. **Vary Real-World Events**: Simulate failures (LLM timeout, tool error)
3. **Run in Production**: Test with real traffic (limited blast radius)
4. **Automate**: Continuous chaos testing in CI/CD

**Chaos Experiments:**
- Random LLM latency injection
- Tool unavailability simulation
- Context window overflow
- Malicious input injection
- Resource exhaustion

**Safety:**
- Feature flags to abort experiments
- Gradual blast radius expansion
- Automated rollback triggers
- Business hours only for production

### 2.4 Zero Trust Architecture (NIST SP 800-207)

**Core Tenets:**
- Never trust, always verify
- Assume breach
- Verify explicitly (continuous verification)

**Implementation:**
| Layer | Control |
|-------|---------|
| **Identity** | JWT/OIDC with mTLS (SPIFFE/SPIRE) |
| **Device** | Posture checks in CI/CD pipelines |
| **Network** | Microsegmentation (Istio, Cilium) |
| **Application** | Runtime verification (Falco, Tetragon) |
| **Data** | Encryption-at-rest, access logging |

**Policy as Code:**
- Define ZTA policies in version-controlled code (OPA/Rego, Kyverno)
- Enforce at every CI/CD stage
- Continuous verification with eBPF tools

### 2.5 CWE Top 25 Prevention (2025)

**Critical Weaknesses to Prevent:**

| Rank | CWE | Name | Prevention |
|------|-----|------|------------|
| 1 | CWE-79 | XSS | Output encoding, CSP headers |
| 2 | CWE-89 | SQL Injection | Parameterized queries, ORM |
| 3 | CWE-352 | CSRF | Anti-CSRF tokens, SameSite cookies |
| 4 | CWE-862 | Missing Authorization | RBAC, explicit authorization checks |
| 5 | CWE-787 | Out-of-bounds Write | Bounds checking, safe languages |
| 6 | CWE-22 | Path Traversal | Input validation, allowlist paths |
| 7 | CWE-416 | Use After Free | Memory safety, smart pointers |
| 8 | CWE-125 | Out-of-bounds Read | Bounds checking, sanitizers |
| 9 | CWE-78 | OS Command Injection | Avoid shell execution, allowlist |
| 10 | CWE-94 | Code Injection | Never execute untrusted/LLM output |
| 11 | CWE-120 | Classic Buffer Overflow | Bounds checking, safe string functions |
| 12 | CWE-434 | Unrestricted File Upload | File type validation, isolated storage |
| 13 | CWE-476 | NULL Pointer Dereference | Null checks, Option/Result types |
| 14 | CWE-121 | Stack-based Buffer Overflow | Stack canaries, safe languages |
| 15 | CWE-502 | Deserialization of Untrusted Data | Avoid pickle/eval, use safe formats |
| 16 | CWE-122 | Heap-based Buffer Overflow | Bounds checking, ASLR |
| 17 | CWE-863 | Incorrect Authorization | Consistent authz checks, testing |
| 18 | CWE-20 | Improper Input Validation | Strict validation, allowlists |
| 19 | CWE-284 | Improper Access Control | Least privilege, RBAC |
| 20 | CWE-200 | Sensitive Info Exposure | Data classification, redaction |
| 21 | CWE-306 | Missing Authentication | Require auth for critical functions |
| 22 | CWE-918 | SSRF | URL allowlisting, network isolation |
| 23 | CWE-77 | Command Injection | Avoid shell, parameterize commands |
| 24 | CWE-639 | Authz Bypass via User Key | Indirect references, server-side authz |
| 25 | CWE-770 | Resource Allocation Without Limits | Rate limiting, quotas |

**Notable 2025 Changes:**
- CWE-120 (Buffer Overflow) and CWE-121/122 (Stack/Heap Overflow) re-entered Top 25
- CWE-476 (NULL Pointer Dereference) jumped from #21 to #13
- CWE-862 (Missing Authorization) rose from #9 to #4

**Integration:**
- SAST tools configured for CWE detection
- Pre-commit hooks for common issues
- Security training on top 25

### 2.6 Critical Questions Checklist

Before deployment, answer:

**Criticality Assessment:**
- [ ] Life-Critical (patient safety, avionics)
- [ ] Mission-Critical (business continuity, 99.999% uptime)
- [ ] Security-Critical (financial, PII)
- [ ] Business-Critical (revenue impact)

**Autonomy Level:**
- [ ] Human-in-the-Loop (HITL): Every action requires approval
- [ ] Human-on-the-Loop (HOTL): Supervised, can intervene
- [ ] Fully Autonomous: Operates independently with monitoring

**Data Sensitivity:**
- [ ] Does the agent process PII/PHI?
- [ ] Does it handle financial data?
- [ ] Does it access confidential IP?
- [ ] Is there data residency requirement?

**Compliance Requirements:**
- [ ] Regulatory requirements (HIPAA, SOX, GDPR)
- [ ] Industry standards (ISO 27001, SOC 2)
- [ ] Safety standards (ISO 26262, IEC 62304, DO-178C)

---

## Part 3: Mission-Critical Systems Patterns

### 3.1 High Availability Architecture

**Five Nines (99.999%) Requirements:**
- Redundancy at every layer (N+1 minimum)
- Automatic failover (< 1 minute RTO)
- Geographic distribution (multi-region)
- Consensus protocols for state (Raft/Paxos)

**Patterns:**
- **Active-Active**: All instances serve traffic simultaneously
- **Active-Passive**: Standby takes over on failure
- **Circuit Breaker**: Fail fast on downstream issues
- **Bulkhead**: Isolate failures to prevent cascading

### 3.2 Fault Tolerance Strategies

**Graceful Degradation:**
- Reduce functionality rather than fail completely
- Fallback to cached data
- Read-only mode during outages

**Retry Policies:**
```
Exponential backoff: delay = min(base * 2^attempt, max_delay)
Jitter: delay = delay * (0.5 + random())
Max attempts: 3-5 depending on idempotency
```

**Idempotency:**
- All state-changing operations must be idempotent
- Idempotency keys for deduplication
- Exactly-once semantics where required

### 3.3 Disaster Recovery

**RPO/RTO Targets:**
| Tier | RPO | RTO | Example |
|------|-----|-----|---------|
| Tier 1 | 0 | < 1 min | Payment processing |
| Tier 2 | < 15 min | < 1 hour | Customer data |
| Tier 3 | < 24 hr | < 4 hours | Analytics |

**Backup Strategy:**
- Continuous replication to secondary region
- Point-in-time recovery capability
- Quarterly disaster recovery drills

---

## Appendix: Standards Reference

### Safety-Critical Standards
- **DO-178C**: Software Considerations in Airborne Systems (2012)
- **DO-333**: Formal Methods Supplement to DO-178C (2012)
- **DO-330**: Software Tool Qualification Considerations (2012)
- **IEC 62304**: Medical Device Software (2006/Amendment 1 2015)
- **ISO 26262**: Road Vehicles Functional Safety (2018)
- **IEC 61508**: Functional Safety of E/E/PE Systems (2010/2024 TS)

### Coding Standards
- **MISRA C:2025**: Motor Industry Software Reliability Association (224 guidelines, 4 new rules)
- **MISRA C++:2023**: Safe C++17 programming
- **CERT C**: SEI CERT C Coding Standard (2016)
- **JPL C**: NASA/JPL Power of 10 Rules (2006)
- **JSF++**: Joint Strike Fighter Air Vehicle C++ (2005)

### Security Standards
- **OWASP ASVS 5.0**: Application Security Verification Standard
- **NIST SSDF**: Secure Software Development Framework (2023)
- **NIST SP 800-207**: Zero Trust Architecture (2020)
- **SLSA 1.2**: Supply-chain Levels for Software Artifacts (Build Track, v1.1 April 2025)
- **CWE Top 25**: MITRE Most Dangerous Software Weaknesses (2025)

---

> **The Golden Rule**: 
> **The Body** (Code) must be deterministic and verifiable.
> Never confuse deterministic code with probabilistic AI.
