# TOON: Token-Oriented Object Notation

## Protocol Directive
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
  user: developer
  mode: debug
  flags: --verbose --force
```

### Pattern B: High-Density Arrays (The Core Value)
```toon
# BAD (JSON/YAML): Repeats keys "id", "status", "agent"
# GOOD (TOON): Define keys once.
tasks[3]{id,status,agent}:
  1,DONE,agent_a
  2,IN_PROGRESS,agent_b
  3,PENDING,agent_c
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

### Core Files

| File | Purpose | Key Schemas |
|------|---------|-------------|
| `MEMORY.md` | Session context | `context{}`, `facts{topic,detail}` |
| `PRD.md` | Product requirements | `product{}`, `features{id,name,pri,status}` |
| `TODO.md` | Task management | `tasks{id,status,desc}` |

### Example `MEMORY.md`

```toon
context:
  user: developer
  role: admin
  project: my-project
  prefs:
    lang: typescript
    test: framework
    code_style: strict

# Session Facts
facts[4]{topic,detail,timestamp}:
  auth,OAuth2 implementation,2026-01-13T10:00:00Z
  deploy,Cloud Provider,2026-01-13T11:00:00Z
  db,SQL Database,2026-01-13T12:00:00Z
  api,REST endpoints,2026-01-13T13:00:00Z

# Last Session Summary
last_session:
  completed: 5
  failed: 0
  duration_minutes: 45
```

### Example `PRD.md`

```toon
product:
  name: ProjectAlpha
  ver: 1.0.0
  description: A sample application
  repository: github.com/org/project-alpha

# Features
features[5]{id,name,pri,status,dependencies}:
  FEAT-01,User Authentication,P0,Done,
  FEAT-02,Dashboard UI,P1,In Progress,FEAT-01
  FEAT-03,User Settings,P1,Pending,FEAT-01
  FEAT-04,Notifications,P2,Pending,
  FEAT-05,Reporting,P2,Pending,

# Technical Requirements
tech_req[3]{id,description,status}:
  SEC-01,TLS 1.3 + FIPS 203 PQC (ML-KEM-768),Done
  SEC-02,AES-256-GCM + Tenant-Specific Keys,Done
  SEC-03,OWASP ASI 2026 Zero Trust Compliance,PENDING
```

## Best Practices

### Do's ✓

```toon
# ✓ Use descriptive array names
users[3]{id,name,email,role}:
  1,alice,alice@example.com,admin
  2,bob,bob@example.com,editor
  3,charlie,charlie@example.com,viewer

# ✓ Include count in header
tasks[2]{id,title,status,assignee}:
  1,Setup Project,Done,alice
  2,Write Tests,Pending,bob

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

## Integration Points

### LLM Context Injection

```toon
# System prompt includes:
[TOON_SPECIFICATION]
[CONTEXT]
[MEMORY]
[TASK]
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

**Remember**: TOON is designed for AI-to-AI and AI-to-Human communication. Use it for state, memory, and configuration. Use JSON for external APIs, YAML for documentation, and TOON for everything in your framework.
