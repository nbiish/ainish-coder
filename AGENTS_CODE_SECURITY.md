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
| **DO-178C** | Avionics Software | A (Catastrophic), B (Hazardous), C (Major), D (Minor), E (No Effect) | Level A requires MC/DC coverage |
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

*Standards: JPL C Coding Standard ("Power of 10"), JSF++ AV (2005), MISRA C:2025 (225 guidelines), MISRA C++:2023, CERT C Secure Coding*

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
- 225 total guidelines (March 2025)
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

**C++ Example (JSF++ AV):**
```cpp
// JSF++ AV Rule 1: No trigraphs
// JSF++ AV Rule 2: No implicit conversions
// JSF++ AV Rule 3: No multiple inheritance
// JSF++ AV Rule 142: All variables shall be initialized before use

#include <cstdint>

namespace avionics {
    class TelemetryFrame {
    public:
        explicit TelemetryFrame(uint16_t length) : length_(length) {}
        uint16_t length() const { return length_; }
    private:
        uint16_t length_;
    };
}
```

#### Rust (High-Assurance Core)

*Standards: Ferrocene (ISO 26262 ASIL-D / IEC 61508 SIL 3 / IEC 62304 Class C), SAE J3061*

**Certified Toolchain:**
- **Ferrocene 23.06.0+**: Qualified for ISO 26262 ASIL D, IEC 61508 SIL 3
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

**Rust Example (Ferrocene):**
```rust
#![forbid(unsafe_code)]
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};

pub struct Counter {
    value: AtomicUsize,
}

impl Counter {
    pub fn new() -> Self {
        Counter { value: AtomicUsize::new(0) }
    }
    
    pub fn increment(&self) -> usize {
        self.value.fetch_add(1, Ordering::SeqCst) + 1
    }
    
    pub fn get(&self) -> usize {
        self.value.load(Ordering::SeqCst)
    }
}
```

#### Python (The Agentic Glue)

*Standards: PEP 8, High-Integrity Python, ISO 26262 (Tool Qualification), IEC 62304*

**Role**: Orchestration and AI logic, NOT hard real-time control or safety-critical logic

**Type System (Mandatory):**
- Full type hints with strict mypy
- Pydantic for runtime validation
- No `any`, `cast` without justification

**Safety Bans:**
- `pickle` (RCE risk)
- `eval()`, `exec()`, `compile()`
- `__import__()` dynamic imports
- `subprocess` without strict allowlisting

**Determinism:**
- Avoid iteration over unordered sets/dicts where order matters
- Use `dict` insertion ordering (Python 3.7+) explicitly
- Pin all dependencies with `uv.lock` or `poetry.lock`
- Set `PYTHONHASHSEED=0` for reproducibility in tests

**Python Example (Strict Type Hints):**
```python
from typing import TypeVar, Generic, Protocol, Optional
from pydantic import BaseModel, Field, validator

class AgentInput(BaseModel):
    query: str = Field(..., min_length=1, max_length=10000)
    context_id: Optional[str] = None
    
    @validator('query')
    def validate_query(cls, v: str) -> str:
        if len(v) > 10000:
            raise ValueError("Query too long")
        return v.strip()

class AgentOutput(BaseModel):
    action: str
    result: dict
    reasoning: str

def process_agent(input_data: AgentInput) -> AgentOutput:
    """Process agent input with strict typing."""
    return AgentOutput(
        action="process",
        result={"input_length": len(input_data.query)},
        reasoning="Validated and processed"
    )
```

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

**TypeScript Example (Zod Runtime Validation):**
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
  throw new Error(`Invalid agent response: ${result.error.message}`);
}
```

#### Go (Cloud-Native Infrastructure)

*Standards: Effective Go, gofmt, go vet, golangci-lint*

**Role**: Cloud-native services, microservices, infrastructure tools

**Mandatory Tools:**
- `gofmt`: Format all code (tabs for indentation)
- `go vet`: Static analysis for common errors
- `golangci-lint`: Bundle of linters (staticcheck, revive, errcheck)

**Go Example (Idiomatic):**
```go
package telemetry

import (
    "context"
    "fmt"
    "time"
)

// Frame represents a telemetry data packet
type Frame struct {
    Length uint16
    Data   []byte
}

// NewFrame creates a new telemetry frame
func NewFrame(length uint16) *Frame {
    return &Frame{Length: length, Data: make([]byte, length)}
}

// Validate checks frame integrity
func (f *Frame) Validate() error {
    if f.Length == 0 {
        return fmt.Errorf("frame length cannot be zero")
    }
    if len(f.Data) != int(f.Length) {
        return fmt.Errorf("data length mismatch")
    }
    return nil
}

// Process processes the frame with timeout
func (f *Frame) Process(ctx context.Context) error {
    select {
    case <-ctx.Done():
        return ctx.Err()
    case <-time.After(100 * time.Millisecond):
        return f.Validate()
    }
}
```

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

**MC/DC Example (C):**
```c
// Condition A AND Condition B → Decision
// Test cases needed:
// 1. A=0, B=0 → Decision=0 (A independently affects outcome)
// 2. A=1, B=0 → Decision=0 (B independently affects outcome)
// 3. A=1, B=1 → Decision=1

int decision(int a, int b) {
    return a && b;  // Each condition must independently flip outcome
}
```

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
- **Go**: go vet, golangci-lint (staticcheck, revive)

**Go Static Analysis Example:**
```bash
# Run go vet on all packages
go vet ./...

# Run golangci-lint with strict settings
golangci-lint run --enable gofmt --fix ./...

# Run with specific linters
golangci-lint run --enable staticcheck,revive,errcheck ./...
```

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

**SLSA GitHub Actions Example:**
```yaml
name: Build with SLSA 3
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: |
          go build -o myapp ./cmd/myapp
      - name: Generate SBOM
        run: syft . -o cyclonedx-json=sbom.json
      - name: Sign artifact
        uses: sigstore/cosign-installer@v3
        with:
          cosign-release: 'v2.2.0'
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: myapp
          path: myapp
```

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

**OPA/Rego Example:**
```rego
package system.zta

default allow = false

# Never trust, always verify
allow if {
    input.token.valid
    input.token.expires > time.now_ns()
    input.subject == input.token.sub
    input.resource.allowed[input.subject]
}

# Least privilege
allow if {
    input.action == "read"
    input.resource.readable[input.subject]
}

# Continuous verification
allow if {
    input.device.posture.compliant
    input.network.segment == input.resource.segment
}
```

### 2.5 CWE Top 25 Prevention (2026)

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

**Notable 2026 Changes:**
- CWE-120 (Buffer Overflow) and CWE-121/122 (Stack/Heap Overflow) re-entered Top 25
- CWE-476 (NULL Pointer Dereference) jumped from #21 to #13
- CWE-862 (Missing Authorization) rose from #9 to #4
- 2026 list based on real-world vulnerabilities (not surveys)

**Integration:**
- SAST tools configured for CWE detection
- Pre-commit hooks for common issues
- Security training on top 25

**Python CWE Prevention Example:**
```python
# CWE-79 XSS Prevention
from html import escape

def safe_render(user_input: str) -> str:
    return escape(user_input)  # HTML entity encoding

# CWE-89 SQL Injection Prevention
import sqlite3

def safe_query(db: sqlite3.Connection, user_id: int) -> list:
    cursor = db.execute("SELECT * FROM users WHERE id = ?", (user_id,))
    return cursor.fetchall()

# CWE-78 Command Injection Prevention
import subprocess

def safe_run(command: str) -> str:
    # Never use shell=True with user input
    result = subprocess.run(
        ["echo", command],
        capture_output=True,
        text=True,
        check=True
    )
    return result.stdout
```

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

**Go Circuit Breaker Example:**
```go
package circuitbreaker

import (
    "context"
    "errors"
    "sync"
    "time"
)

type State int

const (
    Closed State = iota
    Open
    HalfOpen
)

type CircuitBreaker struct {
    state     State
    failures  int
    threshold int
    timeout   time.Duration
    lastFail  time.Time
    mu        sync.Mutex
}

func New(threshold int, timeout time.Duration) *CircuitBreaker {
    return &CircuitBreaker{
        state:     Closed,
        threshold: threshold,
        timeout:   timeout,
    }
}

func (cb *CircuitBreaker) Call(ctx context.Context, fn func() error) error {
    cb.mu.Lock()
    if cb.state == Open && time.Since(cb.lastFail) > cb.timeout {
        cb.state = HalfOpen
    }
    if cb.state == Open {
        cb.mu.Unlock()
        return errors.New("circuit breaker open")
    }
    cb.mu.Unlock()

    err := fn()
    
    cb.mu.Lock()
    if err != nil {
        cb.failures++
        if cb.failures >= cb.threshold {
            cb.state = Open
            cb.lastFail = time.Now()
        }
    } else {
        cb.failures = 0
        cb.state = Closed
    }
    cb.mu.Unlock()
    
    return err
}
```

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

**Go Retry Example:**
```go
package retry

import (
    "context"
    "math/rand"
    "time"
)

func WithBackoff(ctx context.Context, fn func() error) error {
    const (
        baseDelay  = 100 * time.Millisecond
        maxDelay   = 5 * time.Second
        maxRetries = 5
    )
    
    var lastErr error
    for attempt := 0; attempt < maxRetries; attempt++ {
        if err := fn(); err == nil {
            return nil
        } else {
            lastErr = err
        }
        
        delay := baseDelay * (1 << uint(attempt)) // exponential
        delay = min(delay, maxDelay)
        
        // Add jitter
        jitter := float64(delay) * (0.5 + rand.Float64()*0.5)
        delay = time.Duration(jitter)
        
        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-time.After(delay):
        }
    }
    return lastErr
}
```

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
- **MISRA C:2025**: Motor Industry Software Reliability Association (225 guidelines, March 2025)
- **MISRA C++:2023**: Safe C++17 programming (October 2023)
- **CERT C**: SEI CERT C Coding Standard (2016)
- **JPL C**: NASA/JPL Power of 10 Rules (2006)
- **JSF++**: Joint Strike Fighter Air Vehicle C++ (Doc. 2RDU00001 Rev C, December 2005)

### Security Standards
- **OWASP ASVS 5.0**: Application Security Verification Standard (2025)
- **NIST SSDF**: Secure Software Development Framework (2023)
- **NIST SP 800-207**: Zero Trust Architecture (August 2020)
- **SLSA 1.2**: Supply-chain Levels for Software Artifacts (Build Track, v1.2 November 2025)
- **CWE Top 25**: MITRE Most Dangerous Software Weaknesses (2026, real-world data)

### Post-Quantum Cryptography (NIST FIPS)
| Purpose | Standard | Algorithm |
|---------|----------|-----------|
| Key Encapsulation (Primary) | FIPS 203 | ML-KEM-768/1024 |
| Key Encapsulation (Backup) | TBD | HQC |
| Digital Signatures (Primary) | FIPS 204 | ML-DSA-65/87 |
| Hash-Based Sig (Backup) | FIPS 205 | SLH-DSA |
| Digital Signatures (Alt) | FIPS 206 | FN-DSA (FALCON) |

**PQC CLI Examples (OpenSSL 3.5+ with oqs-provider):**
```bash
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
```

**Deprecation Schedule:**
- RSA, ECDSA, ECDH → Deprecate by 2030, Remove by 2035 (NIST IR 8547)

---

> **The Golden Rule**:  
> The Body (Code) **must** be deterministic and verifiable.  
> **Never** confuse deterministic code with probabilistic AI.  
#### Bash (Infrastructure Automation)

*Standards: Secure scripting, SSH remoting, multi-server orchestration*

**Role**: Infrastructure automation, CI/CD pipelines, multi-server orchestration

**Mandatory Flags:**
- `set -euo pipefail`: Exit on error, undefined variables, and pipeline failures
- `[[ ]]`: Use for conditionals (safer than `[ ]`)
- `"${var}"`: Always quote variables

**SSH Security:**
- Use SSH keys instead of passwords
- Set strict SSH options: `ssh -o BatchMode=yes -o ConnectTimeout=10`
- Use `ControlMaster` and `ControlPersist` for connection reuse

**Multi-Server Orchestration:**
- **Ansible**: Declarative YAML playbooks with parallel execution
- **PSSH (Parallel SSH)**: Run commands on multiple hosts simultaneously
- **Bash loops**: Simple iteration with proper error handling

**Bash Example (Secure Scripting):**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Input validation
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <hostname>" >&2
    exit 1
fi

HOST="${1}"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10"

# Validate host parameter
if [[ -z "${HOST}" ]]; then
    echo "Error: Host cannot be empty" >&2
    exit 1
fi

# Secure file transfer with rsync over SSH
rsync -avz -e "ssh ${SSH_OPTS}" /local/data/ "${HOST}:/remote/path/"

# Parallel execution with PSSH
pssh -h hosts.txt -t 30 "systemctl restart myservice"

# Ansible ad-hoc command for quick orchestration
ansible all -m ping --private-key ~/.ssh/ansible_key

# Safe variable usage with parameter expansion
OUTPUT="${RESULT:-default_value}"
```

**SSH Hardening (sshd_config):**
```bash
# /etc/ssh/sshd_config - Hardened configuration
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

# Authentication
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 30

# Security
AllowUsers admin deploy
X11Forwarding no
PermitEmptyPasswords no
ClientAliveInterval 300
ClientAliveCountMax 2

# Logging
SyslogFacility AUTH
LogLevel INFO
```

**Multi-Server Orchestration Examples:**

**Ansible Playbook (Parallel Execution):**
```yaml
---
- name: Deploy to multiple servers
  hosts: all
  strategy: free
  serial: 5
  gather_facts: false
  vars:
    ansible_ssh_common_args: '-o ControlMaster=auto -o ControlPersist=60s'
  tasks:
    - name: Deploy application
      ansible.builtin.copy:
        src: /local/app.tar.gz
        dest: /opt/app/app.tar.gz
      notify: Restart Service

  handlers:
    - name: Restart Service
      ansible.builtin.systemd:
        name: myservice
        state: restarted
```

**PSSH (Parallel SSH) Example:**
```bash
# Create host list
echo -e "server1.example.com\nserver2.example.com\nserver3.example.com" > hosts.txt

# Run command on all hosts in parallel
pssh -h hosts.txt -t 30 -p 10 "systemctl status myservice"

# Copy files to multiple hosts
pscp -h hosts.txt -p 10 config.yaml /etc/myservice/

# Run with SSH key
pssh -h hosts.txt -i ~/.ssh/deploy_key "uptime"
```

**Bash Loop with Error Handling:**
```bash
#!/usr/bin/env bash
set -euo pipefail

HOSTS=("server1" "server2" "server3")
SSH_KEY="/path/to/deploy_key"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10 -o IdentityFile=${SSH_KEY}"

for host in "${HOSTS[@]}"; do
    echo "Deploying to ${host}..."
    if ! ssh ${SSH_OPTS} "${host}" "systemctl stop myservice"; then
        echo "Failed to stop service on ${host}" >&2
        continue
    fi
    
    if ! rsync -avz -e "ssh ${SSH_OPTS}" ./app/ "${host}:/opt/app/"; then
        echo "Failed to sync app to ${host}" >&2
        continue
    fi
    
    ssh ${SSH_OPTS} "${host}" "systemctl start myservice"
    echo "Deployed to ${host} successfully"
done
```

**SSH Key Management:**
```bash
# Generate Ed25519 key (2026 best practice)
ssh-keygen -t ed25519 -C "deploy@2026" -f ~/.ssh/deploy_key

# Add key to remote server
ssh-copy-id -i ~/.ssh/deploy_key.pub user@remote-server

# Use SSH config for simplified connections
cat << EOF > ~/.ssh/config
Host production-*
    User deploy
    IdentityFile ~/.ssh/deploy_key
    BatchMode yes
    ConnectTimeout 10
    ServerAliveInterval 30
    ServerAliveCountMax 3
EOF

# Restrict key permissions
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/deploy_key
chmod 644 ~/.ssh/deploy_key.pub
```