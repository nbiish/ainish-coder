# Template Agent System - Documentation

> **Purpose:** Guide for using the Template Agent System to craft effective AI agent system prompts.

## Overview

The Template Agent System provides a comprehensive framework for creating custom system prompts that serve as your agent's "constitution" - the core instructions that guide every interaction.

**Key Philosophy:** Start simple, iterate based on real behavior. No A/B testing needed on day one.

---

## Quick Start

### 1. Deploy the Template

```bash
# Deploy to current directory
ainish-coder --template-agent

# Deploy to specific project
ainish-coder --template-agent ~/my-project
```

This creates: `.mai-rules/template-agent.md`

### 2. Open and Edit

Open the template file and replace all `[FILL_IN: ...]` markers with your specific requirements.

### 3. Test and Iterate

Use your agent with the new system prompt and observe:
- Hallucinations
- Off-track responses
- Inconsistent outputs
- Misunderstandings

### 4. Refine Incrementally

Make small, targeted changes to specific sections and test each one.

---

## Template Structure

The template is organized into four main sections based on the OCR content:

### 1. 🎭 Persona and Goals

**Purpose:** Define your agent's identity, expertise, and primary objectives.

**What to fill in:**
- Agent name/role
- Primary function
- Core competencies (primary skills)
- Supporting competencies (secondary skills)
- Operating principles and values
- Behavioral guidelines

**Example Use Cases:**
- "Expert Python Development Assistant"
- "Security-Focused Code Reviewer"
- "Technical Documentation Generator"
- "Legacy System Refactoring Specialist"

### 2. 🛠️ Tool Instructions and Examples

**Purpose:** Specify how your agent should use available tools and capabilities.

**What to fill in:**
- Tool usage philosophy
- When to use specific tools
- Tool prioritization order
- Step-by-step usage instructions
- Real-world usage scenarios
- Expected outcomes

**Example Tools:**
- Code analysis
- Documentation search
- Testing frameworks
- Linting and formatting
- Package management
- Version control

### 3. 📋 Output Format

**Purpose:** Define consistent output structure for predictable, parseable responses.

**What to fill in:**
- Standard response template
- Code block formatting rules
- Comment requirements
- Explanation style (concise/detailed)
- Technical level and audience
- Error reporting format

**Benefits:**
- Consistent structure across responses
- Easy parsing and automation
- Clear communication
- Professional documentation

### 4. 🎯 Miscellaneous Instructions

**Purpose:** Additional context, edge cases, and fine-tuning guidelines.

**What to fill in:**
- Iteration strategy
- Edge case handling
- Knowledge gap responses
- Conflicting requirement resolution
- Constraints and boundaries
- Quality assurance checklist

**Includes:**
- Ambiguous request handling
- Unknown information policies
- Prohibited actions
- Required actions
- Context awareness factors

---

## Advanced Features

### Iterative Improvement Log

The template includes a version history section to track:
- Changes made to the prompt
- Observed issues and fixes
- Performance metrics
- Effectiveness improvements

**Example Tracking:**
```
v1.0 - Initial template
v1.1 - Added error handling after hallucination incident
v1.2 - Refined code output format
v1.3 - Added security validation checklist
```

### Quality Assurance Checklist

Built-in checklist for verifying output quality:
- Code compiles/runs without errors
- Follows project style guidelines
- Includes necessary error handling
- Documentation is clear and accurate

### Best Practices Section

Embedded guidance for effective prompt engineering:
- ✅ Do This: Specific, example-driven, boundary-setting
- ❌ Avoid This: Vague, conflicting, overly complex

---

## Common Refinement Patterns

### Issue: Agent Provides Outdated Information

**Solution:** Add instruction to check documentation dates

```markdown
### Tool-Specific Instructions

#### Documentation Search

When to use: Before implementing any feature
How to use:
  1. Search official documentation first
  2. **Check documentation date and version**
  3. Verify information is current
  4. Cross-reference with changelog
```

### Issue: Agent Makes Assumptions

**Solution:** Add requirement to state assumptions explicitly

```markdown
### Edge Cases and Special Handling

**Ambiguous Requests:**

When user intent is unclear:
1. State the ambiguity explicitly
2. **List all assumptions you're making**
3. Provide interpretation options
4. Ask clarifying question
```

### Issue: Agent Provides Too Much Code

**Solution:** Add constraint for incremental changes

```markdown
### Code Output Standards

**Code Blocks:**
- **Maximum size: 50 lines per block**
- **For larger changes: break into steps**
- **Explain each step before providing code**
```

---

## Integration with Existing Rules

The Template Agent System works alongside your existing rule tiers:

### Rule Precedence

```
1. TIER_0_RULES (docs-protocol.md)
2. TIER_1_RULES (code-security.md)
3. TIER_2_RULES (prompt-security.md)
4. template-agent.md (your custom agent)
5. TIER_3_RULES (anishinaabe-cyberpunk-style.md)
6. TIER_4_RULES (modern-prompting.md)
```

### Recommendation

**Start with:**
```bash
# Deploy base rules
ainish-coder --rules ~/my-project

# Deploy TIER_1 (security)
ainish-coder --tier 1 ~/my-project

# Deploy template agent
ainish-coder --template-agent ~/my-project
```

**Then customize** `template-agent.md` for your specific needs.

---

## Use Cases

### Use Case 1: Python Web API Development

**Persona:**
- Expert Python FastAPI developer
- Async patterns specialist
- PostgreSQL optimization focus

**Tools:**
- Poetry for dependencies
- pytest for testing
- Black for formatting
- mypy for type checking

**Output:**
- PEP 8 compliant
- Type hints required
- Docstrings in Google style
- Include curl examples for API endpoints

### Use Case 2: Security Code Review

**Persona:**
- Security-focused code auditor
- OWASP compliance expert
- Risk assessment specialist

**Tools:**
- Bandit for Python security
- OWASP ZAP for web scanning
- git-secrets for credential detection

**Output:**
- Severity ratings (Critical/High/Medium/Low)
- CWE references
- Remediation steps
- Prevention guidance

### Use Case 3: Technical Documentation

**Persona:**
- Technical writer for developers
- API documentation specialist
- Tutorial creator

**Tools:**
- Markdown linting
- Code example testing
- Screenshot generation

**Output:**
- Clear headings and structure
- Code examples with explanations
- Step-by-step instructions
- Troubleshooting sections

---

## Troubleshooting

### Problem: Agent Ignores Template

**Possible Causes:**
1. Template not in `.mai-rules/` directory
2. Syntax errors in markdown
3. Conflicting instructions in other rules

**Solutions:**
1. Verify file location: `.mai-rules/template-agent.md`
2. Check markdown syntax
3. Review AGENTS.md for rule loading order

### Problem: Template Too Complex

**Solution:** Simplify incrementally
1. Start with just Persona and Goals
2. Add Tool Instructions after a week
3. Add Output Format after two weeks
4. Add Misc Instructions as needed

### Problem: Inconsistent Behavior

**Debugging Steps:**
1. Check for conflicting instructions
2. Review all `[FILL_IN]` sections are completed
3. Verify examples are clear
4. Simplify complex sections

---

## Maintenance

### Weekly Review

- Monitor agent outputs
- Note any hallucinations
- Track off-track responses
- Identify patterns

### Monthly Updates

- Review improvement log
- Update outdated instructions
- Add new tool examples
- Refine output formats

### Quarterly Audit

- Major version update
- Performance metrics review
- Complete section overhaul if needed
- Document lessons learned

---

## Best Practices

### ✅ Do This

1. **Start Simple** - Begin with basic instructions
2. **Use Real Examples** - Show actual code and scenarios
3. **Be Specific** - "Validate all user inputs" not "be careful"
4. **Document Changes** - Keep improvement log updated
5. **Test Incremental** - One change at a time

### ❌ Avoid This

1. **Over-Engineering** - Don't add complexity without need
2. **Vague Language** - "Be helpful" is not actionable
3. **Contradictions** - Check for conflicting rules
4. **Stale Examples** - Keep code examples current
5. **Assuming Behavior** - Test, don't assume it works

---

## FAQ

### Q: How long should my template be?

**A:** Start small (500-1000 words), grow organically. The included template is comprehensive but you don't need to fill every section immediately.

### Q: Can I use this with multiple AI tools?

**A:** Yes! Deploy the template, then also deploy tool-specific configs:
```bash
ainish-coder --template-agent
ainish-coder --cursor
ainish-coder --copilot
ainish-coder --cline
```

### Q: Should I version control the template?

**A:** Yes! Commit it to your repository so your team uses the same agent behavior.

### Q: How often should I update it?

**A:** Update when you notice consistent issues. Weekly reviews, monthly updates is a good rhythm.

### Q: What if my team disagrees on behavior?

**A:** Create multiple templates in different directories, or use branches to test variations.

---

## Related Documentation

- [AGENTS.md](../AGENTS.md) - Global agent rules
- [MAIRULES.md](../MAIRULES.md) - Core operational rules
- [TIER_0_RULES/](../TIER_0_RULES/) - Documentation protocols
- [TIER_1_RULES/](../TIER_1_RULES/) - Security standards
- [TIER_2_RULES/](../TIER_2_RULES/) - Prompt security

---

## Support and Feedback

**Found an issue?** Open an issue on GitHub
**Have improvements?** Submit a pull request
**Questions?** Check existing documentation or ask in discussions

---

**Remember:** Your template is a living document. Craft it carefully, iterate ruthlessly, and document everything. Start simple and evolve based on real-world behavior.
