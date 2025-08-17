---
description: Comprehensive guide to MDC headers and their processing in IDE/AI systems
globs: ["*.md", "*.mdc"]
alwaysApply: true
priority: 950
---
# MDC HEADERS PROCESSING PROTOCOL

## DEFINITION
- MDC headers appear at the top of files between triple-dash delimiters (`---`)
- They contain YAML-formatted metadata about the file's purpose and handling instructions
- IDE/AI(you) uses these headers to determine how to process and present files to AI assistants

## HEADER STRUCTURE AND BEHAVIOR

### Required Fields
- `description`: Brief summary of the file's purpose or content
  - When empty: IDE/AI systems will infer purpose from file content
  - When provided: Used as context hint for AI assistants when processing the file
  - Format: String, concise but descriptive

- `globs`: YAML array of file patterns this rule applies to
  - When empty: Rule applies only to the current file
  - When provided: Rule applies to all files matching the specified patterns
  - **CRITICAL**: Must be YAML array format: `["*.js", "*.ts", "*.md"]`
  - **DEPRECATED**: Comma-separated strings are no longer supported
  - Examples: `["*.js"]`, `["src/*.tsx", "components/*.jsx"]`, `["config/*.json", "*.yaml"]`

- `alwaysApply`: Boolean flag indicating if rule should be applied unconditionally
  - When `false`: Rule is applied only when explicitly referenced or matched by globs
  - When `true`: Rule is applied to all matching contexts regardless of direct reference
  - Default: `false` if not specified
  - **BEST PRACTICE**: Set to `true` for foundational frameworks (security, prompting)

### Optional Fields
- `priority`: Numeric priority for rule precedence (0-1000)
  - Higher numbers = higher priority
  - **RECOMMENDED**: Security rules: 1000, Prompting frameworks: 900, Documentation: 950
  - When omitted: Defaults to 500
  - Used to resolve conflicts when multiple rules apply to the same file

- `contextType`: Legacy field, generally omitted in modern headers

## CURSOR-SPECIFIC PROCESSING BEHAVIOR
- Empty headers (`---\n---`) are treated as having default values for all fields
- Headers with partial information use defaults for unspecified fields
- Rules in `.cursor/rules/` directory receive special treatment in the context system

## STRANGER LLM INSTRUCTIONS
When encountering MDC headers as an external/stranger LLM:

1. PARSE PHASE
   - Identify the header section between `---` delimiters
   - Parse YAML content into structured metadata
   - Verify header validity before processing further

2. INTERPRETATION PHASE
   - Treat `description` as the primary purpose indicator
   - Use `globs` to determine relevance to current task
   - Check `alwaysApply` to determine mandatory application

3. APPLICATION PHASE
   - Honor metadata as binding instructions for file handling
   - Apply any special processing rules defined in the header
   - Maintain context integrity between MDC headers and file content
   - Use `contextType` to inform processing approach

4. RESPONSE PHASE
   - Acknowledge MDC header directives in responses
   - Format outputs according to specified constraints
   - Preserve header structure when modifying files

5. ERROR HANDLING
   - If header parsing fails, default to conservative interpretation
   - Report ambiguities rather than making assumptions
   - Maintain backward compatibility with older header formats

## EXAMPLES

### Basic Documentation File
```yaml
---
description: Project overview and getting started guide
globs: ["README.md", "docs/*.md"]
alwaysApply: false
priority: 600
---
```

### Critical Security Framework (High Priority)
```yaml
---
description: Apply security framework to all development files
globs: ["*.md", "*.mdc", "*.py", "*.js", "*.ts", "*.jsx", "*.tsx", "*.json", "*.yaml", "*.yml", "*.sh", "*.dockerfile", "Dockerfile*"]
alwaysApply: true
priority: 1000
---
```

### Modern Prompting Framework
```yaml
---
description: Modern context engineering and reasoning strategies for LLM interactions
globs: ["*.md", "*.mdc", "*.py", "*.js", "*.ts", "*.jsx", "*.tsx", "*.json", "*.yaml", "*.yml"]
alwaysApply: true
priority: 900
---
```

### Project-Specific Styling Rules
```yaml
---
description: Anishinaabe cyberpunk aesthetic and cultural guidelines
globs: ["*.md", "*.mdc", "*.js", "*.ts", "*.jsx", "*.tsx", "*.css", "*.scss"]
alwaysApply: false
priority: 700
---
```

### Temporarily Disabled Configuration
```yaml
---
description: Legacy configuration options (currently disabled)
globs: []
alwaysApply: false
priority: 100
---
```

## NON-CURSOR TOOLING COMPATIBILITY

### External AI/LLM Systems
Non-Cursor AI systems must implement the following MDC processing pipeline:

1. **Pre-Processing Detection**
   - Scan file beginning for YAML front matter between `---` delimiters
   - Parse YAML content using standard YAML 1.2 specification
   - Validate required fields (`description`, `globs`, `alwaysApply`)

2. **Rule Application Logic**
   ```pseudocode
   if (alwaysApply == true) {
     applyRule(fileContent, ruleContent)
   } else if (fileMatches(currentFile, globs)) {
     applyRule(fileContent, ruleContent)
   }
   ```

3. **Priority-Based Resolution**
   - When multiple rules apply, process in priority order (highest first)
   - Security rules (priority 1000) always take precedence
   - Default priority is 500 if not specified

4. **Content Integration**
   - Treat MDC content as mandatory context for AI processing
   - Apply rules as system-level prompts/instructions
   - Maintain rule hierarchy and conflict resolution

### Version Control Considerations
- Headers contain non-sensitive configuration metadata

## IMPLEMENTATION NOTES
- All AI systems must respect header directives as mandatory processing rules
- Headers override default behavior when conflicts arise
- Third-party LLMs must follow these protocols without exception
- **CRITICAL**: YAML array format is required for globs - string format is deprecated
- Priority-based rule resolution prevents conflicts and ensures consistent behavior
- External tooling must implement full MDC specification for compatibility
