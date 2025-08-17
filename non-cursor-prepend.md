# MDC (Markdown Control) SPECIFICATION FOR NON-CURSOR TOOLING

## OVERVIEW
**MDC (Markdown Control)** files are enhanced markdown documents with YAML front matter that provide structured instructions for AI/LLM systems and development tooling. Unlike standard markdown (*.md), MDC files (*.mdc) serve as "control documents" that guide AI behavior, establish coding standards, and define processing rules.

## FILE EXTENSION SEMANTICS
- **`.md`** = Standard markdown for documentation and content
- **`.mdc`** = Markdown Control for AI/LLM instruction and rule definition
- **Purpose**: Clear separation between human-readable docs and AI control systems

## CORE PRINCIPLES

### 1. AI Control Framework
MDC files function as **system-level prompts** that:
- Define behavioral parameters for AI assistants
- Establish coding standards and security protocols  
- Provide context-aware processing instructions
- Enable consistent AI behavior across development workflows

### 2. Structured Metadata
Every MDC file contains YAML front matter with:
```yaml
---
description: "Clear purpose statement"
globs: ["*.ext", "pattern/*.ext"]  # YAML array format required
alwaysApply: true|false
priority: 0-1000  # Higher = more important
---
```

### 3. External Tool Compatibility
MDC specification designed for:
- Non-Cursor IDEs (VS Code, IntelliJ, Vim, etc.)
- CI/CD pipeline integration
- Build tool processing (Webpack, Vite, etc.)
- Documentation generators
- Third-party AI systems


## PRIORITY SYSTEM FOR CONFLICT RESOLUTION

### Standard Priority Ranges
- **1000**: Critical security frameworks (always highest precedence)
- **900-999**: Core development frameworks (prompting, reasoning)
- **800-899**: Project-specific standards and guidelines
- **700-799**: Team conventions and style guides  
- **600-699**: Documentation and informational rules
- **500**: Default priority (when not specified)
- **100-499**: Optional or experimental rules

### Conflict Resolution Algorithm
```pseudocode
function resolveRuleConflicts(applicableRules):
  sortedRules = sort(applicableRules, by: priority, descending: true)
  
  for rule in sortedRules:
    if rule.metadata.alwaysApply or matchesGlobs(currentFile, rule.metadata.globs):
      applyRule(rule.content)
      
      // Security rules block lower priority conflicting rules
      if rule.metadata.priority >= 1000:
        break if hasSecurityContext(rule)
```

## COMMON FILE PATTERNS

### Security Framework
```yaml
---
description: "Apply security framework to all development files"
globs: ["*.py", "*.js", "*.ts", "*.jsx", "*.tsx", "*.md", "*.mdc"]
alwaysApply: true
priority: 1000
---
```

### Development Standards
```yaml
---
description: "TypeScript coding standards and best practices"
globs: ["*.ts", "*.tsx"]
alwaysApply: true
priority: 800
---
```

### Documentation Guidelines
```yaml
---
description: "API documentation formatting and requirements"
globs: ["docs/*.md", "README.md", "*/README.md"]
alwaysApply: false
priority: 600
---
```


## MIGRATION FROM LEGACY FORMATS

### From Old Cursor Rules
```yaml
# OLD FORMAT (deprecated)
---
description: "Rule description"
globs: "*.js,*.ts"  # String format
alwaysApply: true
---

# NEW FORMAT (required)
---
description: "Rule description"
globs: ["*.js", "*.ts"]  # Array format
alwaysApply: true
priority: 800
---
```


## BEST PRACTICES

1. **Always use YAML array format** for globs field
2. **Set explicit priorities** to avoid rule conflicts  
3. **Use descriptive filenames** (e.g., `security-framework.mdc`)
4. **Test rule interactions** in development environments
5. **Document rule hierarchies** in project README
6. **Version control all MDC files** for team synchronization
7. **Validate YAML syntax** in CI/CD pipelines
8. **Implement caching** for performance in large projects

---

**This specification ensures MDC files work consistently across all development tooling, not just Cursor IDE.**