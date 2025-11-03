# Cline Rules System - Complete Documentation

**Date:** November 2, 2025  
**Status:** ✅ Verified from Official Documentation  
**Sources:**
- <https://docs.cline.bot/features/cline-rules>
- <https://docs.cline.bot/features/slash-commands/new-rule>
- <https://docs.cline.bot/exploring-clines-tools/new-task-tool>

---

## Executive Summary

**Cline does NOT use a slash command system for custom commands.** Instead, it uses **`.clinerules`** - markdown files that provide MANDATORY instructions Cline must follow.

### The Only Slash Commands

1. **`/newrule`** - Interactive rule creation helper
2. **`/newtask`** - Built-in task handoff tool

That's it. No custom slash commands like Cursor or Claude.

---

## The `.clinerules` System

### Single File Approach

**Location:** Project root  
**Filename:** `.clinerules` (no extension)  
**Format:** Plain markdown

```markdown
# Project Guidelines

## Documentation Requirements
- Update relevant documentation in /docs when modifying features
- Keep README.md in sync with new capabilities

## Code Style & Patterns
- Prefer composition over inheritance
- Use repository pattern for data access

## Testing Standards
- Unit tests required for business logic
- Integration tests for API endpoints
```

### Folder Approach (Recommended)

**Location:** `.clinerules/` directory  
**Files:** Multiple markdown files (`.md` extension)  
**Processing:** Cline loads ALL markdown files automatically

```text
your-project/
├── .clinerules/              # Active rules
│   ├── 01-coding.md          # Core coding standards
│   ├── 02-documentation.md   # Documentation requirements
│   └── current-sprint.md     # Context-specific rules
├── clinerules-bank/          # Inactive rule library
│   ├── clients/
│   │   ├── client-a.md
│   │   └── client-b.md
│   ├── frameworks/
│   │   ├── react.md
│   │   └── vue.md
│   └── project-types/
│       ├── api-service.md
│       └── frontend-app.md
└── src/
```

### Key Features

1. **Automatic Loading** - All files in `.clinerules/` are loaded on startup
2. **Version Controlled** - Part of project source code
3. **Team Consistency** - Shared across all team members
4. **Toggleable** - UI in Cline v3.13+ to enable/disable individual files
5. **Numeric Prefixes** - Optional, for logical ordering (e.g., `01-`, `02-`)

---

## Global vs. Workspace Rules

### Global Rules

**Location:**

| OS | Path |
|----|------|
| **Windows** | `Documents\Cline\Rules` |
| **macOS** | `~/Documents/Cline/Rules` |
| **Linux/WSL** | `~/Documents/Cline/Rules` or `~/Cline/Rules` |

**Usage:** Apply to ALL Cline conversations across all projects

### Workspace Rules

**Location:** `.clinerules` or `.clinerules/` in project root  
**Usage:** Apply only to current project

**Precedence:** Both global and workspace rules are active simultaneously

---

## The `/newtask` Tool

### Purpose

Manage context window and enable task continuity through handoffs.

### When to Use

- Context usage exceeds 50-80%
- Task needs to be broken into subtasks
- Natural stopping point reached
- Switching focus areas

### Workflow

1. **Monitor** - Check context window usage in environment details
2. **Propose** - Use `ask_followup_question` to ask user
3. **Handoff** - Use `new_task` tool with `<context>` block
4. **Continue** - New task starts with preloaded context

### Context Block Structure

```xml
<new_task>
<context>
# Task Continuation: [Title]

## Completed Work
- Detailed list of accomplishments
- Files modified/created
- Important decisions made

## Current State
- Project status
- Running processes
- Key file states

## Next Steps
- Detailed remaining tasks
- Specific implementation details
- Known challenges

## Reference Information
- Documentation links
- Code snippets/patterns
- User preferences

Please continue by [specific next action].
</context>
</new_task>
```

---

## Deployment Strategy for Ainish-Coder

### Current Problem

`deploy_cline_prompts.sh` incorrectly assumes:

- Cline has a workflows system (FALSE)
- Custom slash commands exist (FALSE)
- Should deploy to `.clinerules/workflows/` (DOESN'T EXIST)

### Correct Implementation

Deploy our security/quality prompts as **rules files** in `.clinerules/`:

```bash
# Proposed structure
.clinerules/
├── 00-ainish-security.md      # secure-code.prompt.md content
├── 01-ainish-code-judge.md    # code-judge.prompt.md content
├── 02-ainish-prompt-sec.md    # secure-prompts.prompt.md content
└── 99-ainish-context.md       # Task handoff strategies
```

### Rule File Format

Convert YAML frontmatter to markdown headings:

```markdown
# Code Judge: Critical Thinking Framework

**Description:** Apply systematic critical thinking to code review  
**Category:** Quality Assurance

## Instructions

You MUST follow the Code Judge Constitution:

1. **Find the facts** → Gather verified information
2. **Look for the issue** → Identify core problems
...
```

### Benefits Over Slash Commands

1. **Always Active** - Rules apply automatically, no need to invoke
2. **Mandatory** - Cline must follow them (not optional like slash commands)
3. **Composable** - Multiple rules work together
4. **Toggleable** - Can disable specific rules via UI when not needed
5. **Version Controlled** - Part of project history

---

## Implementation Plan

### Step 1: Rewrite `deploy_cline_prompts.sh`

**New Behavior:**

1. Create `.clinerules/` directory
2. Convert each `.prompt.md` file to rule format
3. Strip YAML frontmatter, convert to markdown sections
4. Add prefix numbers for ordering
5. Include context management template

### Step 2: Add Context Management Rule

Create `99-ainish-context.md` with:

- Task handoff strategies
- Context window monitoring instructions
- When to use `/newtask`
- Proper `<context>` block formatting

### Step 3: Test Deployment

```bash
./bin/ainish-coder cline /path/to/project
```

Verify:

- `.clinerules/` directory created
- All rule files present
- Cline loads rules automatically
- Rules visible in Cline UI

### Step 4: Update Documentation

- `SLASH_COMMANDS_DEPLOYMENT.md` - Correct Cline entry
- `SLASH_COMMANDS_CORRECTIONS.md` - Already updated
- `help.sh` - Update Cline description
- `deploy_commands.sh` - Update output messages

---

## Writing Effective Cline Rules

### Best Practices

1. **Be Clear and Concise** - Simple language, no ambiguity
2. **Focus on Outcomes** - Describe results, not specific steps
3. **Use Mandatory Language** - "MUST", "REQUIRED", "ALWAYS"
4. **Provide Examples** - Show what you want
5. **Test and Iterate** - Experiment to find what works

### Rule Structure Template

```markdown
# [Rule Category]: [Rule Title]

**Purpose:** Brief description  
**Applies to:** When this rule is relevant

## Core Requirements

- MUST: Mandatory actions
- SHOULD: Strong recommendations
- MAY: Optional enhancements

## Examples

### Good Example
[Show desired behavior]

### Bad Example
[Show what to avoid]

## Edge Cases

- Situation 1: How to handle
- Situation 2: How to handle

## References

- Documentation links
- Related standards
```

---

## Comparison: Tools with Rules Systems

| Tool | Rules File | Format | Custom Slash Commands |
|------|-----------|--------|----------------------|
| **Cline** | `.clinerules/` | Markdown | ❌ No (only `/newtask`, `/newrule`) |
| **Cursor** | `.cursorrules` | Plain text | ✅ Yes (`.cursor/commands/`) |
| **Windsurf** | `.windsurfrules` | Markdown | ✅ Yes (workflows) |
| **Roo Code** | `.roo-rules` | Markdown | ✅ Yes (`.roo/commands/`) |

---

## Key Takeaways

1. **No Custom Slash Commands** - Cline doesn't support them
2. **Rules Are Better** - Always active, mandatory, composable
3. **Folder System Preferred** - Multiple files more maintainable
4. **Context Management** - Use `/newtask` for handoffs
5. **Team Consistency** - Version control ensures alignment

---

## Next Actions

- [ ] Rewrite `deploy_cline_prompts.sh` → `deploy_cline.sh`
- [ ] Convert prompts to rules format
- [ ] Add context management rule
- [ ] Test deployment
- [ ] Update all documentation
- [ ] Create usage examples

---

## References

- **Cline Rules Documentation:** <https://docs.cline.bot/features/cline-rules>
- **New Rule Command:** <https://docs.cline.bot/features/slash-commands/new-rule>
- **New Task Tool:** <https://docs.cline.bot/exploring-clines-tools/new-task-tool>
- **Context Management:** <https://docs.cline.bot/prompting/understanding-context-management>
- **Cline System Prompt:** <https://github.com/cline/cline/blob/main/src/core/prompts/system.ts>
