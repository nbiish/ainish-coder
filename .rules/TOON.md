# TOON: Token-Oriented Object Notation
> **Version**: 2.0.0 (SOTA 2026)
> **Status**: Core OSA Standard
> **Protocol**: REQUIRED for all Shared State

## Protocol Directive
**You MUST use TOON** for all shared state, logging, and high-density data exchange.
**Goal**: Maximize information density per token.
**Constraint**: Do not use JSON or YAML for lists > 3 items.

## 1. The Spec
TOON is a hybrid format:
- **Root**: Indented Key-Value (YAML-subset) for singular context.
- **Arrays**: Header-defined CSV blocks for repetitive data.

### Syntax Rules
1. **No Quotes**: Strings are unquoted unless containing special characters.
2. **No Braces/Brackets**: Structure is defined by indentation and headers.
3. **Array Header**: `key[count]{col1,col2}`.
4. **Zero-Count**: `key[0]{...}:` means empty list.

## 2. Examples (Copy These Patterns)

### Pattern A: Session Context (Root)
```toon
session:
  id: sess-123
  user: nbiish
  mode: yolo
  flags: --verbose --force
```

### Pattern B: High-Density Arrays (The Core Value)
```toon
# BAD (JSON/YAML): Repeats keys "id", "status", "agent"
# GOOD (TOON): Define keys once.
tasks[3]{id,status,agent}:
  1,DONE,gemini
  2,IN_PROGRESS,qwen
  3,PENDING,opencode
```

### Pattern C: Multi-line Content
Use `|` literal style.
```toon
prompt: |
  Analyze the following code.
  Return a summary.
```

## 3. Parsing Logic (Mental Model)
When reading TOON:
1. Scan for `key: value` -> Set `obj[key] = value`.
2. Scan for `key[N]{cols}:` -> Initialize array of size `N`.
3. For next `N` lines -> Split by comma -> Map to `cols`.

## 4. Writing Logic
1. **Count First**: You must know the count `N` before writing the header.
2. **Header**: Write `name[N]{col1,col2}:`.
3. **Rows**: Write `N` lines of CSV data.
4. **Update**: If adding a row, increment `N` in the header.

description: |
  This is a multi-line
  description that preserves
  line breaks.
```

## Advanced Syntax

### 7. Special Values

```toon
# Null/Empty
null_value: ~
empty_string: ""

# Booleans
enabled: true
disabled: false

# Numbers
integer: 42
float: 3.14
negative: -10
scientific: 1.5e-3

# Timestamps (ISO 8601)
created_at: 2026-01-14T01:00:00Z
last_login: 2026-01-13T15:30:00+00:00
```

### 8. Comments
Start with `#` for comments.

```toon
# This is a comment
version: 2.0.0  # Inline comment

# Multi-line comment
# that spans
# several lines
config:
  debug: true
```

### 9. Escape Sequences
For values containing delimiters.

```toon
# Escape comma with backslash
items[1]{name,price}:
  Widget\, Deluxe,19.99

# Escape special characters
note: value with \"quotes\" and \\backslash
```

## Comparison: JSON vs TOON

### Standard JSON (~140 tokens)
```json
{
  "logs": [
    { "ts": "2026-01-01", "level": "INFO", "msg": "Started" },
    { "ts": "2026-01-01", "level": "WARN", "msg": "Retrying" },
    { "ts": "2026-01-01", "level": "ERROR", "msg": "Failed" }
  ]
}
```

### TOON (~40 tokens) - 71% Reduction
```toon
logs[3]{ts,level,msg}:
  2026-01-01,INFO,Started
  2026-01-01,WARN,Retrying
  2026-01-01,ERROR,Failed
```

## OSA Framework Usage

In the Orchestrated System of Agents (OSA), TOON is used for:

### Core Files

| File | Purpose | Key Schemas |
|------|---------|-------------|
| `MEMORY.toon` | Session context | `context{}`, `facts{topic,detail}` |
| `PRD.toon` | Product requirements | `product{}`, `features{id,name,pri,status}` |
| `TODO.toon` | Task management | `tasks{id,status,desc}` |
| `llms.txt` | Protocol definitions | Documentation + schemas |

### Agent Handoffs
Passing high-density context between Gemini (Trunk) and sub-agents.

### Example `OSAVARS.toon` (Shared State Pattern)

```toon
# OSAVARS.toon
session:
  id: RUN-8821
  objective: Refactor Auth System
  started_at: 2026-01-14T01:00:00Z
  status: ACTIVE

# Kanban Backlog (Optional)
backlog[3]{id,task,status}:
  1,Create Login UI,DONE
  2,Add Zod Validation,PENDING
  3,Connect Auth API,PENDING

vars{key,val}:
  MAX_RETRIES,5
  TARGET_DIR,src/auth
  TEST_STATUS,PASSING
  API_BASE_URL,https://api.example.com

agents[2]{name,role,status}:
  Gemini,Implementation,IDLE
  Qwen,Review,ACTIVE

log[2]{ts,agent,msg}:
  10:00,Gemini,Started refactor loop
  10:05,Gemini,Updated login.ts
```

### Example `MEMORY.toon`

```toon
context:
  user: nbiish
  role: admin
  project: ainish-coder
  prefs:
    lang: typescript
    test: framework
    code_style: strict

# Session Facts
facts[4]{topic,detail,timestamp}:
  auth,JWT with 15min expiry,2026-01-13T10:00:00Z
  deploy,Vercel frontend,2026-01-13T11:00:00Z
  db,PostgreSQL with Prisma ORM,2026-01-13T12:00:00Z
  api,REST endpoints with OpenAPI,2026-01-13T13:00:00Z

# Last Session Summary
last_session:
  completed: 5
  failed: 0
  duration_minutes: 45
```

### Example `PRD.toon`

```toon
product:
  name: SecureChat
  ver: 2.0.0
  description: End-to-end encrypted messaging app
  repository: github.com/org/securechat

# Features
features[5]{id,name,pri,status,dependencies}:
  AUTH-01,MFA Implementation,P0,Done,
  AUTH-02,Passwordless Login,P1,In Progress,AUTH-01
  CHAT-01,Message Editing,P1,Pending,
  CHAT-02,Message Reactions,P2,Pending,CHAT-01
  ADMIN-01,Audit Logs,P2,Pending,

# Technical Requirements
tech_req[3]{id,description,status}:
  SEC-01,TLS 1.3 for all connections,Done
  SEC-02,End-to-end encryption,Done
  SEC-03,GDPR compliance,PENDING
```

## Best Practices

### Do's ✓

```toon
# ✓ Use descriptive array names
users[3]{id,name,email,role}:

# ✓ Include count in header
tasks[5]{id,title,status,assignee}:

# ✓ Use consistent indentation (2 spaces)
config:
  database:
    host: localhost

# ✓ Use comments to explain non-obvious data
vars{key,val}:
  # Rate limits per service
  RATE_LIMIT,100

# ✓ Escape special characters
message: Hello\, World!
```

### Don'ts ✗

```toon
# ✗ Don't use quotes
name: "John"  # Wrong

# ✗ Don't use trailing commas
items[2]{a,b}:
  1,2,  # Wrong

# ✗ Don't mix spaces and tabs
config:
	tab: wrong  # Wrong - use spaces

# ✗ Don't create inconsistent schemas
data[3]{name,id}:  # First entry has different schema
  Alice,1
  Bob,2,developer  # Extra field - wrong
```

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Arrays | plural, snake_case | `users`, `task_items` |
| Scalars | singular, snake_case | `user_id`, `task_title` |
| Booleans | is/are/has prefix | `is_active`, `has_error` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRIES`, `API_BASE_URL` |

## File Extension & MIME

| Attribute | Value |
|-----------|-------|
| File Extension | `.toon` |
| MIME Type | `application/toon` |
| Editor Support | VS Code, Vim, Neovim |

## Tooling Support

### Parsers

```python
# Example Python parser
import re

def parse_toon(content):
    """Parse TOON format into Python dict."""
    lines = content.strip().split('\n')
    result = {}
    # Implementation...
    return result
```

### Validators

```python
def validate_toon(content):
    """Validate TOON format and schema consistency."""
    # Check array counts match entries
    # Check schema consistency
    # Return (is_valid, errors)
    pass
```

### Formatters

```bash
# Format and sort TOON file
toon format --sort config.toon
toon validate file.toon
```

## Integration Points

### LLM Context Injection

```toon
# System prompt includes:
[TOON_SPECIFICATION]
[CONTEXT]
[MEMORY]
[TASK]
```

### Agent Communication

```toon
# Agent handoff format
handoff:
  from: Gemini
  to: Qwen
  task: Generate API routes
  context: |
    {previous_context}
  output_format: toon
```

### State Persistence

```toon
# Checkpoint format
checkpoint:
  id: cp-001
  timestamp: 2026-01-14T01:00:00Z
  session_state: {}
  task_progress: 75%
  agents: []
```

## Summary

| Feature | TOON | JSON | YAML |
|---------|------|------|------|
| Token Efficiency | ★★★★★ | ★★☆☆☆ | ★★★☆☆ |
| Human Readable | ★★★★☆ | ★★★☆☆ | ★★★★★ |
| Schema Support | Built-in | External | Partial |
| LLM Optimization | ★★★★★ | ★★☆☆☆ | ★★★☆☆ |
| File Size (1000 rows) | ~30KB | ~100KB | ~85KB |

**Remember**: TOON is designed for AI-to-AI and AI-to-Human communication. Use it for state, memory, and configuration. Use JSON for external APIs, YAML for documentation, and TOON for everything in the OSA framework.
