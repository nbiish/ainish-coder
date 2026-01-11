# TOON: Token-Oriented Object Notation
> **Version**: 1.0.0 (SOTA 2026)
> **Status**: Core OSA Standard
> **MIME**: `application/toon`

## Overview

**TOON** is an ultra-compact data serialization format designed specifically for AI and Large Language Model (LLM) applications. It replaces JSON for logging and state management in the OSA framework, offering **50-70% token savings** by eliminating redundant syntax (quotes, braces, repeated keys).

## Core Syntax

TOON combines YAML-like indentation with schema-based array declarations.

### 1. Simple Key-Value
No quotes. No braces. Colon separates key and value.

```toon
project: My Cool App
version: 1.0.0
status: ACTIVE
```

### 2. Schema-Defined Arrays (The "Token Saver")
Instead of repeating keys for every object in a list, define the schema once in the header.

**Syntax:** `name[count]{field1,field2,...}:`

```toon
# JSON equivalent would repeat "id", "name", "role" for every row
users[3]{id,name,role}:
  1,Alice,admin
  2,Bob,user
  3,Charlie,auditor
```

### 3. Nested Objects
Use indentation (2 spaces).

```toon
config:
  database:
    host: localhost
    port: 5432
  api:
    timeout: 30s
```

### 4. Hybrid Lists
Standard YAML-style lists are also supported for unstructured data.

```toon
tags:
  - production
  - stable
  - v1
```

## Comparison: JSON vs TOON

**Standard JSON (~140 tokens):**
```json
{
  "logs": [
    { "ts": "2026-01-01", "level": "INFO", "msg": "Started" },
    { "ts": "2026-01-01", "level": "WARN", "msg": "Retrying" },
    { "ts": "2026-01-01", "level": "ERROR", "msg": "Failed" }
  ]
}
```

**TOON (~40 tokens):**
```toon
logs[3]{ts,level,msg}:
  2026-01-01,INFO,Started
  2026-01-01,WARN,Retrying
  2026-01-01,ERROR,Failed
```

## Usage in OSA Framework

In the Orchestrated System of Agents (OSA), TOON is used for:

1.  **`OSAVARS.toon`**: Global state tracking.
    *   **`vars{key,val}`**: Shared variables between agents.
    *   **`log[n]{ts,agent,event}`**: Persistent audit trail.
2.  **`llms.txt`**: Protocol definitions.
3.  **Agent Handoffs**: Passing high-density context between Ralph (Trunk) and sub-agents.

### Example `OSAVARS.toon`

```toon
session:
  id: RUN-8821
  objective: Refactor Auth System

# Kanban Backlog (Optional)
backlog[3]{id,task,status}:
  1,Create Login UI,DONE
  2,Add Zod Validation,PENDING
  3,Connect Auth API,PENDING

vars{key,val}:
  MAX_RETRIES,5
  TARGET_DIR,src/auth
  TEST_STATUS,PASSING

agents[2]{name,role,status}:
  Gemini,Implementation,IDLE
  Qwen,Review,ACTIVE

log[2]{ts,agent,msg}:
  10:00,Ralph,Started refactor loop
  10:05,Gemini,Updated login.ts
```

## Best Practices

*   **Comma Separation**: Use commas for fields in schema arrays. If a value contains a comma, escape it `\,` or use a different delimiter (pipe `|`) if defined in schema (advanced).
*   **No Trailing Commas**: Keep rows clean.
*   **Comments**: Start with `#`.
*   **Extension**: `.toon`
