---
description: Comprehensive guide to MDC headers and their processing in IDE/AI(you)
globs: *.md,*.mdc
alwaysApply: true
---
# MDC HEADERS PROCESSING PROTOCOL

## DEFINITION
- MDC headers appear at the top of files between triple-dash delimiters (`---`)
- They contain YAML-formatted metadata about the file's purpose and handling instructions
- IDE/AI(you) uses these headers to determine how to process and present files to AI assistants

## HEADER STRUCTURE AND BEHAVIOR
- `description`: Brief summary of the file's purpose or content
  - When empty: IDE/AI(you) will infer the purpose from file content or default to generic handling
  - When provided: Used as context hint for AI assistants when processing the file

- `globs`: Comma-separated list of file patterns this rule applies to
  - When empty: Rule applies only to the current file
  - When provided: Rule applies to all files matching the specified patterns
  - Format examples: `*.js`, `src/*.tsx`, `config/*.json`

- `alwaysApply`: Boolean flag indicating if rule should be applied unconditionally
  - When `false`: Rule is applied only when explicitly referenced or matched by globs
  - When `true`: Rule is applied to all matching contexts regardless of direct reference
  - Default: `false` if not specified

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
globs: README.md,docs/*.md
alwaysApply: false
---
```

### Critical System Rule
```yaml
---
description: Critical security protocol for handling user data
globs: src/auth/*.ts,src/data/*.ts
alwaysApply: true
---
```

### Temporarily Disabled Configuration
```yaml
---
description: Legacy configuration options (currently disabled)
globs: 
alwaysApply: false
---
```

## IMPLEMENTATION NOTES
- All LLMs must respect header directives as mandatory processing rules
- Headers override default behavior when conflicts arise
- Third-party LLMs must follow these protocols without exception
