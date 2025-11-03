# AGENTS.md: RULES LOCATION HIERARCHY

## RULES LOCATION HIERARCHY

READ:

- MAIRULES.md → {Apply to all requests}
- .mai-rules/MAIRULES.md → {Apply to all requests}
- .mai-rules/*.md → {Apply to all requests !.mai-rules/critical.md}

## Create and follow the **Atomic Design** pattern in `population/`

- **Atoms** (`population/atoms/`) - Core utilities, data types, state management
- **Molecules** (`population/molecules/`) - Composite components, deployment scripts
- **Organisms** (`population/organisms/`) - High-level flows and orchestration

## KNOWLEDGE_BASE/* Structure

- KNOWLEDGE_BASE/PRD.md
- KNOWLEDGE_BASE/TODO.md
- KNOWLEDGE_BASE/DOCS/*

**Package Management Commands:**

```bash
- ```uv venv``` → Creates ```.venv``` in the current directory
- ```uv pip install some-package``` → Installs packages into the current directory's ```.venv```
- ```uv run needs-some-package.py``` → Runs python files with the current directory's ```.venv``` dependencies
- ```uv tool install some-package``` → Installs packages as isolated tools (not in the current directory's ```.venv```)
```

## Fact-Based Decision Making

**All code decisions must be supported by verified facts.**

- Gather verified facts from documentation
- Base decisions on evidence, not assumptions
- Create and maintain KNOWLEDGE_BASE/*
- KNOWLEDGE_BASE/DOCS/* for known verified facts which are timestamped and sourced from the internet or mcp tools
- No valid conclusion without supporting facts

## Critical Thinking Framework

**Code Judge Constitution:**

1. **Find the facts** → Gather verified information
2. **Look for the issue** → Identify core problems
3. **Identify knowledge sources** → Document references
4. **Locate rules/standards** → Follow specifications
5. **Apply critical thinking** → Examine reasoning

**Critical Thinking Checklist:**

- ✓ Ambiguity check → Ensure clear meaning
- ✓ Fact verification → Verify information is factual
- ✓ Knowledge quality → Assess evidence reliability
- ✓ Missing information → Identify gaps
- ✓ Alternative causes → Consider other explanations
- ✓ Fact requirement → Support with evidence

## SECURITY & SAFETY

### Code Security

**Always check for:**

- Input validation and sanitization
- Authentication and authorization
- Encryption for sensitive data
- SQL injection prevention
- XSS (Cross-Site Scripting) prevention
- CSRF (Cross-Site Request Forgery) protection
- Secure dependency versions
- Environment variable protection
- Error handling without information leakage
- Rate limiting and DoS prevention

### Prompt Security

**Guard against:**

- Prompt injection attacks
- Data exfiltration attempts
- Social engineering
- Jailbreak attempts
- Malicious instructions
- Unauthorized data access

**Best Practices:**

- Validate and sanitize all inputs
- Use role-based prompting
- Implement output filtering
- Monitor for suspicious patterns
- Maintain context boundaries

## Code Quality Standards

**Must follow:**

- Single Responsibility Principle
- DRY (Don't Repeat Yourself)
- KISS (Keep It Simple, Stupid)
- Proper error handling
- Comprehensive logging
- Clear naming conventions
- Commented logic flow summary for complex code
- Type safety where applicable

## Documentation Requirements

**Every module/function should have:**

- Purpose description
- Input parameters
- Return values
- Example usage
- Edge cases
- Error conditions

## 🐍 Python Package Management

**Always use:**

- Virtual environments to isolate component dependencies
- Requirements files with pinned versions
- Type hints for better code clarity

## Documentation Usage

**Always search documentation for:**

- Current API versions
- Recent feature updates
- Deprecation notices
- Security advisories
- Best practices
- Breaking changes

**Preferred Documentation Sources:**

1. **Official documentation** (highest priority)
2. **GitHub repositories** (source of truth)
3. **Stack Overflow** (community solutions)
4. **Technical blogs** (implementation guides)
5. **API references** (detailed specifications)

## Date & Time Verification

**Always verify current date/time context when:**

- Web search requests
- Questions about "current", "latest", "recent" information
- Time-relative data ("today's", "this year's")
- News, events, statistics, prices, weather
- Software versions, technology updates
- Market data

**Important Context:**

- AI models have training data cutoffs
- Without current time data, responses may contain outdated information
- Always establish current date/time before providing time-sensitive answers

**Remember:** These rules are designed to ensure consistency, security, and quality across all AI-assisted coding work. Adapt as needed for specific projects while maintaining core principles.
