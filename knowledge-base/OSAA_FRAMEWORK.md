# OSAA Framework - Documentation

> **OSAA (Orchestrator Sub-Agent Action)**: A systematic framework for complex task decomposition and multi-agent orchestration.

## Overview

The OSAA framework provides AI agents with a structured methodology for breaking down complex tasks into manageable sub-actions, assigning them to specialized sub-agents, and integrating results coherently.

**Command:** `ainish-coder --OSAA [target-directory]`

**Creates:** `OSAA.md` in the target directory root

---

## Quick Start

### Deploy OSAA Framework

```bash
# Deploy to current directory
ainish-coder --OSAA

# Deploy to specific project
ainish-coder --OSAA ~/my-project
```

### What Gets Deployed

- **OSAA.md** - Complete orchestration framework at project root
- Framework includes:
  - Task decomposition patterns
  - Sub-agent specialization definitions
  - Execution patterns (sequential, parallel, pipeline, feedback)
  - Communication protocols
  - Error handling strategies
  - Monitoring and metrics guidelines

---

## Core Concepts

### 1. Orchestrator Agent

**Role:** Master coordinator that manages the overall execution

**Responsibilities:**
- Analyze incoming requests
- Break down into sub-tasks
- Assign sub-tasks to specialized agents
- Monitor execution progress
- Integrate results
- Validate outputs
- Handle errors and retries

### 2. Sub-Agents

**Specialized agents with focused capabilities:**

- **Code Analysis Agent** - Pattern detection, dependency mapping, security scanning
- **Code Generation Agent** - Boilerplate, API implementation, test creation
- **Testing Agent** - Unit tests, integration tests, performance benchmarks
- **Documentation Agent** - API docs, README, code comments, tutorials
- **Deployment Agent** - Configuration, environment setup, service orchestration

### 3. Task Decomposition

**Break complex tasks into:**
- Discrete, actionable sub-tasks
- Clear input/output definitions
- Explicit success criteria
- Failure handling strategies
- Dependency relationships

---

## Execution Patterns

### Sequential Execution

```
Task A → Task B → Task C → Result
```

**Use when:** Tasks have strict dependencies (B needs A's output)

**Example:** Code generation → Testing → Deployment

### Parallel Execution

```
Task A ↘
Task B → Merge → Result
Task C ↗
```

**Use when:** Tasks are independent and can run simultaneously

**Example:** Generate tests + Update docs + Security scan (all on same code)

### Pipeline Execution

```
Task A → Task B1 → Task C1 → Result 1
         Task B2 → Task C2 → Result 2
```

**Use when:** Multiple independent output streams needed

**Example:** API implementation → (Client SDK, Server code, Documentation)

### Feedback Loop

```
Task A → Task B → Validate
         ↑          ↓
         └─ Refine ─┘ → Result
```

**Use when:** Iterative refinement required

**Example:** Code generation → Test → Fix issues → Retest

---

## Communication Protocol

### Message Structure

```yaml
message:
  type: request | response | status | error
  sender: orchestrator | sub-agent-id
  receiver: orchestrator | sub-agent-id
  task_id: unique-task-identifier
  timestamp: ISO-8601
  payload:
    # Task-specific data
  metadata:
    priority: high | medium | low
    timeout: seconds
    retry_count: integer
```

### Status Codes

| Code | Meaning | Action |
|------|---------|--------|
| `pending` | Queued, not started | Wait |
| `in-progress` | Currently executing | Monitor |
| `blocked` | Waiting on dependency | Check blockers |
| `completed` | Successfully finished | Integrate result |
| `failed` | Execution failed | Retry or escalate |
| `cancelled` | Manually cancelled | Clean up |
| `timeout` | Exceeded time limit | Retry or fail |

---

## Error Handling Strategies

### Retry with Backoff

**Use for:** Transient failures (network, resource contention)

**Pattern:**
```
Attempt 1 → Wait 1s → Attempt 2 → Wait 2s → Attempt 3 → Wait 4s
```

### Fallback to Alternative

**Use for:** Agent-specific failures

**Pattern:**
```
Primary Agent fails → Switch to Backup Agent → Continue execution
```

### Graceful Degradation

**Use for:** Non-critical failures

**Pattern:**
```
Sub-task fails → Mark as partial → Continue with remaining tasks → Return partial result
```

### Escalation

**Use for:** Unrecoverable errors

**Pattern:**
```
Critical failure → Log context → Report to orchestrator → Request human intervention
```

---

## Real-World Example

### Task: "Refactor authentication module for better security"

#### Phase 1: Analysis & Planning

**Orchestrator breaks down into:**

1. **analyze_current_auth** (Code Analysis Agent)
   - Input: Current authentication code
   - Output: Security issues, performance bottlenecks
   - Dependencies: None

2. **research_best_practices** (Documentation Agent)
   - Input: Current security standards
   - Output: OWASP recommendations, industry patterns
   - Dependencies: None

3. **design_new_structure** (Code Generation Agent)
   - Input: Analysis results + best practices
   - Output: Architecture design, API specification
   - Dependencies: Tasks 1, 2

4. **implement_changes** (Code Generation Agent)
   - Input: Architecture design
   - Output: Refactored code
   - Dependencies: Task 3

5. **create_tests** (Testing Agent)
   - Input: Architecture design
   - Output: Comprehensive test suite
   - Dependencies: Task 3
   - **Parallel with:** Task 4

6. **run_tests** (Testing Agent)
   - Input: Refactored code + test suite
   - Output: Test results
   - Dependencies: Tasks 4, 5

7. **update_docs** (Documentation Agent)
   - Input: Refactored code
   - Output: Updated documentation
   - Dependencies: Task 4
   - **Parallel with:** Task 6

8. **validate_security** (Code Analysis Agent)
   - Input: Refactored code
   - Output: Security audit report
   - Dependencies: Task 4
   - **Parallel with:** Tasks 6, 7

#### Phase 2: Execution Order

```
Step 1: [analyze_current_auth, research_best_practices] (parallel)
Step 2: design_new_structure (sequential)
Step 3: [implement_changes, create_tests] (parallel)
Step 4: [run_tests, update_docs, validate_security] (parallel)
Step 5: Integration & validation (sequential)
```

#### Phase 3: Integration

**Orchestrator validates:**
- All tests pass ✓
- Security audit shows improvements ✓
- Documentation complete ✓
- No breaking changes ✓

#### Phase 4: Result

**Deliverables:**
- Refactored authentication module
- Comprehensive test suite (95%+ coverage)
- Security audit report (zero critical issues)
- Updated documentation
- Deployment instructions

---

## Best Practices

### For Orchestrators

✅ **DO:**
- Create detailed execution plans before starting
- Monitor all sub-agent actions continuously
- Handle errors gracefully with retry logic
- Maintain context across all phases
- Validate final outputs against success criteria
- Log comprehensive execution traces

❌ **DON'T:**
- Execute sub-tasks directly (always delegate)
- Ignore sub-agent failures
- Lose context between execution phases
- Skip validation steps
- Block indefinitely on non-critical tasks
- Make assumptions about sub-agent capabilities

### For Sub-Agents

✅ **DO:**
- Execute only assigned tasks within scope
- Report status regularly to orchestrator
- Return structured, validated outputs
- Handle errors locally when possible
- Respect resource and time limits
- Document any assumptions made

❌ **DON'T:**
- Make assumptions about broader context
- Communicate directly with other sub-agents
- Execute actions outside assigned scope
- Ignore timeout warnings
- Return unstructured or unvalidated data
- Fail silently without reporting

---

## Integration with ainish-coder

### Deployment Workflow

```bash
# 1. Deploy base rules
ainish-coder --rules ~/my-project

# 2. Deploy OSAA framework
ainish-coder --OSAA ~/my-project

# 3. Deploy tool-specific configs
ainish-coder --cursor ~/my-project
ainish-coder --copilot ~/my-project
```

### Compatible Tools

OSAA works with:
- GitHub Copilot
- Cursor AI
- Windsurf
- Cline
- Continue Dev
- Roo Code
- Custom CLI agents

### How Agents Use OSAA

Agents reading `OSAA.md` will:
1. Understand task decomposition patterns
2. Know when to delegate to sub-agents
3. Follow communication protocols
4. Apply appropriate error handling
5. Use correct execution patterns
6. Integrate results systematically

---

## Advanced Topics

### Hierarchical Orchestration

For very complex tasks:

```
Master Orchestrator
├── UI Orchestrator
│   ├── Component Agent
│   ├── Styling Agent
│   └── Accessibility Agent
└── Backend Orchestrator
    ├── API Agent
    ├── Database Agent
    └── Cache Agent
```

### Dynamic Agent Selection

Orchestrator selects sub-agents based on:
- Task complexity analysis
- Available resource capacity
- Historical performance data
- Specialized capability requirements
- Current system load

### Adaptive Execution

Orchestrator adjusts plan dynamically based on:
- Intermediate result quality
- Resource constraint changes
- Time budget remaining
- Observed failure patterns
- Emergency priority shifts

---

## Monitoring & Metrics

### Key Performance Indicators

**Execution Metrics:**
- Total task completion time
- Sub-task success rate
- Parallel execution efficiency
- Resource utilization (CPU, memory)

**Quality Metrics:**
- Error rate per sub-agent type
- Retry frequency by failure type
- Overall success rate
- Output validation pass rate

**Operational Metrics:**
- Average task queue depth
- Sub-agent availability percentage
- Response time per agent type
- Escalation frequency

---

## Security Considerations

### Agent Authentication
- Verify sub-agent identity before task assignment
- Use secure communication channels
- Implement role-based access control

### Data Protection
- Encrypt sensitive data in transit
- Sanitize all inputs and outputs
- Never expose credentials in logs
- Implement data retention policies

### Resource Limits
- Set memory/CPU caps per sub-agent
- Enforce timeout limits strictly
- Monitor for resource abuse patterns
- Implement rate limiting

### Audit Trail
- Log all agent actions with timestamps
- Track data access patterns
- Enable forensic analysis capabilities
- Maintain compliance records

---

## Troubleshooting

### Common Issues

**Problem:** Sub-agent not responding

**Solutions:**
1. Check sub-agent availability
2. Verify communication channel
3. Review timeout settings
4. Switch to fallback agent

**Problem:** Task dependencies blocked

**Solutions:**
1. Identify blocking task
2. Check dependency graph
3. Consider parallel alternatives
4. Adjust execution order

**Problem:** Integration failures

**Solutions:**
1. Validate output formats
2. Check success criteria
3. Review error logs
4. Re-execute failed sub-tasks

---

## Future Enhancements

Planned features for OSAA v2.0:

- [ ] Machine learning-based task decomposition
- [ ] Automated sub-agent performance optimization
- [ ] Real-time execution visualization dashboard
- [ ] Cross-repository orchestration support
- [ ] Distributed sub-agent execution
- [ ] Natural language task specification parser
- [ ] Automatic agent capability discovery
- [ ] One-click rollback on failure

---

## References

- **OSAA.md** - Complete framework specification
- **AGENTS.md** - Base agent configuration
- **MAIRULES.md** - Core operational rules
- **template-agent.md** - Agent customization template

---

**Version:** 1.0.0  
**Last Updated:** 2025-11-03  
**Status:** Production Ready

---

**Remember:** OSAA is about systematic problem-solving. Break complex tasks into manageable pieces, assign them to specialists, coordinate execution, and integrate results. Simple orchestration, powerful outcomes.
