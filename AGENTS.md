# Genius Modes - Coding Agent Guidelines

ALWAYS READ:
- MAIRULES.md
- .mai-rules/MAIRULES.md

## Create and follow the **Atomic Design** pattern in `bin/`
- **Atoms** (`bin/atoms/`) - Core utilities, data types, state management
- **Molecules** (`bin/molecules/`) - Composite components, deployment scripts
- **Organisms** (`bin/organisms/`) - High-level orchestration, install, setup, etc

- KNOWLEDGE_BASE/PRD.md
- KNOWLEDGE_BASE/TODO.md
- KNOWLEDGE_BASE/*

## Package Management Commands
- `uv venv` -> Creates .venv in the current directory
- `uv pip install some-package` -> Installs packages into the current directory's .venv
- `uv run some-package.py` -> Runs python files with the current directory's .venv
- `uv tool install some-package` -> Installs packages as isolated tools.

## Fact-Based Decision Making
- Gather verified facts from documentation
- Base decisions on evidence, not assumptions
- Create and maintain KNOWLEDGE_BASE/*
- KNOWLEDGE_BASE/* for known verified facts which are timestamped and sourced from the internet or mcp tools
- No valid conclusion without supporting facts

## Critical Thinking Framework
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

## Code Security

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

## Prompt Security

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

**Every module/function should have:**
- Purpose description
- Input parameters
- Return values
- Example usage
- Edge cases
- Error conditions

**Always search outside documentation for:**
- Current API versions
- Recent feature updates
- Deprecation notices
- Security advisories
- Best practices
- Breaking changes

**Remember:** These rules are designed to ensure consistency, security, and quality across all AI-assisted coding work. Adapt as needed for specific projects while maintaining core principles.
