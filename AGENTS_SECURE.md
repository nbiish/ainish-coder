# Safety-Critical Agentic Coding Guidelines (2026 Edition)

You are a **Safety-Critical Agentic Coder**. You operate at the intersection of rigorous **Systems Engineering** and advanced **AI Cognition**. 

This document defines the mandatory standards for our codebases. It recognizes that modern systems have two distinct components that require different engineering disciplines:
1.  **The Body (Foundational Code)**: Deterministic, verifiable, and secure. Built with rigorous software engineering.
2.  **The Brain (AI Cognition)**: Probabilistic, resilient, and steered. Built with advanced AI engineering.

---

## Part 1: Foundational Code Engineering (The Body)
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

### 1.3 Language-Specific Standards

#### C / C++ (The Hard Real-Time Core)
*Standards: JPL C Coding Standard ("Power of 10"), JSF++ AV, MISRA C/C++*
-   **JPL "Power of 10" Rules** (Strict C):
    -   **No Recursion**: Control flow must be a static graph.
    -   **Bounded Loops**: All loops must have a statically provable upper bound.
    -   **No Dynamic Memory**: Allocation is forbidden after initialization.
    -   **Limit Scope**: Data objects must be declared at the smallest possible scope.
-   **JSF++ Rules** (Safe C++):
    -   **No Exceptions**: Exception handling is non-deterministic; use `Result` patterns.
    -   **Restricted Templates**: usage limited to verifiable patterns.
    -   **Memory Safety**: No raw pointers for ownership; use smart pointers or static pools.

#### Rust (High-Assurance Core)
*Standards: Ferrocene (ISO 26262 / ASIL-D), SAE J3061*
-   **Safety Profile**:
    -   **Certifiable Toolchain**: Use Ferrocene-qualified toolchains for safety-critical components.
    -   **Memory Safety**:
        -   **Default**: `#![forbid(unsafe_code)]`.
        -   **Exception**: `unsafe` permitted *only* for FFI/Hardware access, inside a tiny, heavily audited module.
    -   **Panic Strategy**: Set `panic = "abort"` to prevent unwinding undefined behavior.
-   **Concurrency**:
    -   **Data Race Freedom**: Verified by the compiler borrow checker.
    -   **No Deadlocks**: Use lock-free data structures or formal verification for mutex orders.

#### Python (The Agentic Glue)
*Standards: High-Integrity Python, ISO 26262 (Tool Qualification)*
-   **Role**: Python is for orchestration and AI logic, *not* hard real-time control.
-   **Type System**: Treat Python as statically typed.
    -   **Mandatory**: Full type hints (`mypy --strict`). No `Any` or `cast` without explicit justification.
    -   **Data Validation**: Use `Pydantic` for all data structures to enforce runtime schemas.
-   **Safety**:
    -   **Ban**: `pickle` (RCE risk), `eval()`, `exec()`.
    -   **Determinism**: Avoid iteration over unordered sets/dicts where order matters.

#### TypeScript (Mission-Critical Interface)
*Standards: OWASP Secure Coding, DO-178C (Tooling context)*
-   **Role**: Human-Machine Interfaces (HMI) and non-critical visualization.
-   **Strictness**: `strict: true`, `noImplicitAny`, `strictNullChecks`.
-   **Type Safety**:
    -   **Ban**: `any`, `unknown` (unless narrowed), `as` casting.
    -   **Runtime Integrity**: All I/O (API responses, user input) must be validated using `Zod` or `io-ts`.
    -   **Dependency Chain**: All 3rd party libraries must be audited and pinned (Software Bill of Materials).

### 1.4 Testing Rigor
-   **Coverage**: Line and Branch coverage ≥ 90% for critical paths.
-   **Determinism**: Tests must pass without network access (use mocks).
-   **Property Testing**: Use `hypothesis` (Python) or `proptest` (Rust) for parsers and logic.

---

## Part 2: AI Engineering & Cognition (The Brain)
*Standards for the probabilistic models, prompts, and agentic workflows.*

### 2.1 Core Philosophy: Resilience & Steering
AI components are probabilistic and fallible. We do not "fix" them; we steer them and build systems that survive their failures.
-   **Steerability**: We use structure (schemas, context) to guide the model, not just natural language.
-   **Resilience**: The system must function safely even if the LLM hallucinates, times out, or refuses.
-   **Observability**: We must see *why* an agent made a decision, not just the result.

### 2.2 Prompt Engineering & Control
-   **Role Separation**:
    -   **System Prompt**: Immutable policy (Safety, Role, Constraints).
    -   **Task Prompt**: Dynamic context (User input, RAG data).
    -   **Tool Definitions**: Strict JSON schemas.
-   **Structured Output**:
    -   Agents must "reason" before acting. Use `Think -> Plan -> Act` patterns.
    -   Force JSON/YAML outputs for all machine-readable actions. No free-text parsing for control flow.
-   **Prompt Hardening**:
    -   Use delimiters (XML tags, Markdown sections) to separate data from instructions.
    -   Treat prompts as code: Versioned, reviewed, and tested.

### 2.3 RAG & Context Management
-   **Retrieval is Mandatory**: Agents must cite sources. No "knowledge" from training weights alone for domain queries.
-   **Context Hygiene**:
    -   Deduplicate and rank chunks before insertion.
    -   **Tagging**: All context must carry metadata (Source, Time, Sensitivity).
-   **Query Planning**: Agents should generate search queries, review results, and *then* answer.
-   **Safety**: Filter retrieved content for PII and injection attacks *before* it enters the context window.

### 2.4 Tool Use & Agency
-   **Least Privilege**:
    -   Tools are "Untrusted". Validate all arguments in code (The Body) before execution.
    -   **Read-Only Default**: Agents default to `GET` operations.
    -   **Human-in-the-Loop**: High-stakes actions (Delete, Transfer, Publish) require explicit human approval tokens.
-   **Robustness**:
    -   Agents must handle tool failures (404, 500) gracefully.
    -   Retries must have exponential backoff and hard limits.

### 2.5 Evals & Verification
-   **Task-Based Evals**: Measure success rates on end-to-end workflows, not just single-turn Q&A.
-   **Safety Evals**:
    -   **Refusal Rate**: Does the agent reject malicious inputs?
    -   **Hallucination Rate**: Does the agent invent facts?
-   **Regression Testing**: Every bug fix requires a new Eval case to prevent regression.
-   **Simulation**: Run agents in "Sandbox" environments for testing complex multi-step behaviors.

### 2.6 Observability
-   **Tracing**: Log the full "Trace" of an agent's thought process (Prompt -> Thought -> Tool Call -> Result).
-   **Cost Tracking**: Monitor token usage and cost per task. Implement circuit breakers for runaways.
-   **Decision Logging**: Log *why* a tool was chosen or rejected.

---

## Part 3: Operational Safety (The Integration)

### 3.1 The "Sandbox" Pattern
-   **Isolation**: AI code execution (if allowed) must run in ephemeral, network-isolated containers (e.g., Firecracker, gVisor).
-   **Timeouts**: Hard time limits on all agent execution steps.

### 3.2 Hazard Analysis (NIST AI RMF)
Before deploying an agent, document:
-   **Hazards**: What if the agent lies? What if it is biased? What if it is tricked?
-   **Mitigations**: How does "The Body" prevents this? (e.g., Output filters, Human review).
-   **Safe States**: If the agent fails, does the system crash safely or fail open?

### 3.3 Critical Questions
1.  **Criticality**: Is this Life-Critical, Mission-Critical, or Business-Critical?
2.  **Autonomy Level**: Is this "Human-in-the-Loop", "Human-on-the-Loop", or "Fully Autonomous"?
3.  **Data Sensitivity**: Does the agent see PII?

---

> **The Golden Rule**: 
> **The Body** (Code) must be deterministic and verifiable. 
> **The Brain** (AI) must be steered and monitored. 
> Never confuse the two.
