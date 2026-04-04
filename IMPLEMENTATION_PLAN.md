# Implementation Plan: Claude Code Deployment Enhancement

**Goal**: Add `ainish-coder --claude` command that deploys comprehensive Claude Code configuration including skills, agents, MCP servers, and settings.

**Created**: 2026-02-26
**Status**: Ready for Implementation

---

## Phase 0: Documentation Discovery (COMPLETED)

### Sources Consulted

1. **Official Claude Code Documentation**
   - https://docs.anthropic.com/en/docs/claude-code/skills (Skills API)
   - https://github.com/anthropics/claude-code (Official repository)
   - https://github.com/anthropics/skills (Official skills examples)
   - https://agentskills.io (Agent Skills Open Standard)

2. **Local Codebase Analysis**
   - `/bin/ainish-coder` - Main CLI entry point
   - `/dna/molecules/deploy_claude.sh` - Existing Claude deployment
   - `/dna/molecules/help.sh` - Help system
   - `/.configs/.claude/commands/` - Existing command structure
   - `/.configs/MCP/` - MCP server configurations

### Allowed APIs List

#### Skills (Claude Code)
- **Directory**: `~/.claude/skills/` (personal) or `.claude/skills/` (project)
- **Required File**: `SKILL.md` with YAML frontmatter
- **Frontmatter Schema**:
  ```yaml
  ---
  name: skill-name              # Required: kebab-case, max 64 chars
  description: What it does     # Required: max 1024 chars, critical for auto-discovery
  allowed-tools: Read, Grep     # Optional: restrict tools
  ---
  ```
- **Invocation**: `/skill-name` (manual) or automatic based on description

#### Agents (Subagents)
- **Directory**: `~/.claude/agents/` (personal) or `.claude/agents/` (project)
- **Required File**: Single `.md` file with YAML frontmatter
- **Frontmatter Schema**:
  ```yaml
  ---
  name: agent-name              # Required: lowercase + hyphens
  description: What it does     # Required
  tools: Read, Grep, Glob       # Allowed tools
  model: sonnet                 # haiku/sonnet/opus/inherit
  permissionMode: default       # default/acceptEdits/dontAsk/bypassPermissions/plan
  skills: skill-name            # Inject specific skills
  ---
  ```
- **Invocation**: `@agent-name` (manual) or automatic delegation

#### MCP Configuration
- **File**: `.claude/settings.json` or `.mcp.json`
- **Schema**:
  ```json
  {
    "mcpServers": {
      "server-name": {
        "disabled": false,
        "timeout": 300,
        "type": "stdio",              // or "sse"
        "command": "npx",
        "args": ["-y", "@package/name"],
        "env": {"API_KEY": "value"},
        "cwd": "/optional/path"
      }
    }
  }
  ```

#### Claude Settings
- **File**: `.claude/settings.json`
- **Schema**:
  ```json
  {
    "env": {
      "ANTHROPIC_API_KEY": "sk-...",
      "CLAUDE_MODEL": "claude-4-sonnet",
      "CLAUDE_CODE_MAX_OUTPUT_TOKENS": 64000
    },
    "permissions": {
      "allow": ["Bash(./bin/*)", "WebSearch"],
      "deny": []
    }
  }
  ```

### Anti-Patterns to Avoid
- DO NOT invent YAML fields not in official docs
- DO NOT use tabs in YAML frontmatter (spaces only)
- DO NOT exceed max lengths (name: 64, description: 1024)
- DO NOT use reserved words ("anthropic", "claude") in skill names
- DO NOT create agents without proper permission modes
- DO NOT deploy MCP servers without proper environment variable placeholders

---

## Phase 1: Create Claude Code Configuration Structure

### Objective
Create the configuration directory structure and files that will be deployed by `--claude` command.

### Tasks

#### 1.1 Create Skills Directory Structure
**Copy from**: None (new structure)
**Create at**: `.configs/.claude/skills/`

**Status**: COMPLETED - Meta-creator skills already created

```
.configs/.claude/skills/
├── skill-creator/          # META: Creates new skills
│   └── SKILL.md            # ✅ ALREADY CREATED
├── agent-creator/          # META: Creates new agents
│   └── SKILL.md            # ✅ ALREADY CREATED
├── commit-helper/          # TODO: Basic commit helper
│   └── SKILL.md
├── code-reviewer/          # TODO: Code review patterns
│   └── SKILL.md
└── test-runner/            # TODO: Test execution patterns
    └── SKILL.md
```

**Meta-Creator Skills (Already Created)**:

1. **skill-creator** - Expert skill creation specialist
   - Location: `.configs/.claude/skills/skill-creator/SKILL.md`
   - Purpose: Guides creation of production-ready Claude Code skills
   - Features:
     - Official Agent Skills Open Standard compliance
     - Frontmatter validation (name, description, allowed-tools)
     - Best practices from anthropics/skills repository
     - Anti-pattern detection
     - Verification checklists
     - Enterprise deployment guidelines

2. **agent-creator** - Expert agent (subagent) creation specialist
   - Location: `.configs/.claude/skills/agent-creator/SKILL.md`
   - Purpose: Guides creation of production-ready Claude Code agents
   - Features:
     - Multi-agent coordination patterns
     - Permission mode best practices
     - Model selection guidelines (haiku/sonnet/opus)
     - Tool selection strategies
     - Agent team configuration (2026 features)
     - Enterprise security patterns
     - Production-ready agent templates

**Verification**:
```bash
# Verify meta-creator skills exist
ls -la .configs/.claude/skills/skill-creator/SKILL.md
ls -la .configs/.claude/skills/agent-creator/SKILL.md

# Verify content
head -n 20 .configs/.claude/skills/skill-creator/SKILL.md
head -n 20 .configs/.claude/skills/agent-creator/SKILL.md
```

**SKILL.md Template** (copy this format for each skill):
```markdown
---
name: skill-name
description: Brief description. Use when [specific trigger].
allowed-tools: Read, Grep, Glob
---

# Skill Name

## Instructions
[Step-by-step guidance]
```

**Files to create**:
1. `.configs/.claude/skills/commit-helper/SKILL.md`
2. `.configs/.claude/skills/code-reviewer/SKILL.md`
3. `.configs/.claude/skills/test-runner/SKILL.md`

**Verification**:
```bash
ls -la .configs/.claude/skills/*/SKILL.md
cat .configs/.claude/skills/*/SKILL.md | head -n 10
```

#### 1.2 Create Agents Directory Structure
**Copy from**: None (new structure)
**Create at**: `.configs/.claude/agents/`

```
.configs/.claude/agents/
├── architect.md
├── planner.md
└── security-analyst.md
```

**Agent Template** (copy this format):
```markdown
---
name: agent-name
description: What this agent does
tools: Read, Grep, Glob, Bash
model: sonnet
permissionMode: default
---

# Agent Name

## Responsibilities
[What this agent handles]
```

**Files to create**:
1. `.configs/.claude/agents/architect.md`
2. `.configs/.claude/agents/planner.md`
3. `.configs/.claude/agents/security-analyst.md`

**Verification**:
```bash
ls -la .configs/.claude/agents/*.md
cat .configs/.claude/agents/*.md | head -n 15
```

#### 1.3 Update Claude Settings Template
**Copy from**: `.configs/MCP/settings.json.template`
**Create at**: `.configs/.claude/settings.json`

**Changes needed**:
- Combine MCP servers from existing template
- Add permissions section
- Add environment variables section

**Verification**:
```bash
cat .configs/.claude/settings.json | jq .
```

---

## Phase 2: Enhance deploy_claude.sh Molecule

### Objective
Update the existing Claude deployment molecule to handle new configuration types.

### Tasks

#### 2.1 Add Skills Deployment
**Copy pattern from**: `/dna/molecules/deploy_claude_commands.sh` (command deployment pattern)

**Add to**: `/dna/molecules/deploy_claude.sh`

```bash
# Deploy skills
local claude_skills_dir="$target_dir/.claude/skills"
if [[ -d "$source_dir/.configs/.claude/skills" ]]; then
    safe_mkdir "$claude_skills_dir" || return 1
    local skill_count=0
    for skill_dir in "$source_dir/.configs/.claude/skills"/*; do
        if [[ -d "$skill_dir" ]]; then
            local skill_name=$(basename "$skill_dir")
            local target_skill_dir="$claude_skills_dir/$skill_name"
            safe_mkdir "$target_skill_dir" || return 1
            cp -r "$skill_dir"/* "$target_skill_dir/"
            ((skill_count++))
            echo -e "${GREEN}✓ Deployed: .claude/skills/$skill_name${RESET}"
        fi
    done
    if [[ $skill_count -gt 0 ]]; then
        echo -e "${BRIGHT_GREEN}✅ Deployed $skill_count skill(s)${RESET}"
    fi
fi
```

**Location**: After line 50 (after commands deployment)

**Verification**:
```bash
# Test deployment
ainish-coder --claude /tmp/test-claude
ls -la /tmp/test-claude/.claude/skills/
```

#### 2.2 Add Agents Deployment
**Copy pattern from**: Same as skills deployment

**Add to**: `/dna/molecules/deploy_claude.sh`

```bash
# Deploy agents
local claude_agents_dir="$target_dir/.claude/agents"
if [[ -d "$source_dir/.configs/.claude/agents" ]]; then
    safe_mkdir "$claude_agents_dir" || return 1
    local agent_count=0
    for agent_file in "$source_dir/.configs/.claude/agents"/*.md; do
        if [[ -f "$agent_file" ]]; then
            local filename=$(basename "$agent_file")
            cp "$agent_file" "$claude_agents_dir/$filename"
            ((agent_count++))
            echo -e "${GREEN}✓ Deployed: .claude/agents/$filename${RESET}"
        fi
    done
    if [[ $agent_count -gt 0 ]]; then
        echo -e "${BRIGHT_GREEN}✅ Deployed $agent_count agent(s)${RESET}"
    fi
fi
```

**Location**: After skills deployment code

**Verification**:
```bash
# Test deployment
ainish-coder --claude /tmp/test-claude
ls -la /tmp/test-claude/.claude/agents/
```

#### 2.3 Add Settings.json Deployment
**Copy pattern from**: `/dna/molecules/deploy_mcp.sh` (settings deployment pattern)

**Add to**: `/dna/molecules/deploy_claude.sh`

```bash
# Deploy settings.json template
local settings_source="$source_dir/.configs/.claude/settings.json"
local settings_target="$target_dir/.claude/settings.json"
if [[ -f "$settings_source" ]]; then
    if [[ ! -f "$settings_target" ]]; then
        cp "$settings_source" "$settings_target"
        echo -e "${GREEN}✓ Created: .claude/settings.json (configure your API keys)${RESET}"
    else
        echo -e "${YELLOW}⚠ .claude/settings.json already exists, skipping${RESET}"
    fi
fi
```

**Location**: After agents deployment code

**Verification**:
```bash
# Test deployment
ainish-coder --claude /tmp/test-claude
cat /tmp/test-claude/.claude/settings.json | jq . 2>/dev/null || cat /tmp/test-claude/.claude/settings.json
```

#### 2.4 Update Success Messages
**Copy from**: Lines 52-54 of existing file

**Change from**:
```bash
echo -e "${BRIGHT_GREEN}✅ Claude Code fully configured${RESET}"
echo -e "${BLUE}💡 Commands available via / in Claude Code${RESET}"
```

**Change to**:
```bash
echo -e "${BRIGHT_GREEN}✅ Claude Code fully configured${RESET}"
echo -e "${BLUE}💡 Features:${RESET}"
echo -e "${BLUE}   • Commands via / (slash commands)${RESET}"
echo -e "${BLUE}   • Agents via @ (delegation)${RESET}"
echo -e "${BLUE}   • Skills (auto-loaded)${RESET}"
echo -e "${BLUE}   • MCP servers (configure in .claude/settings.json)${RESET}"
```

---

## Phase 3: Update Help Documentation

### Objective
Document the new `--claude` command capabilities in the help system.

### Tasks

#### 3.1 Update help.sh
**Copy from**: `/dna/molecules/help.sh` lines 34-35

**Change from**:
```
    --claude [TARGET_DIR]     Deploy Claude Code - rules, commands
```

**Change to**:
```
    --claude [TARGET_DIR]     Deploy Claude Code - rules, commands, skills, agents,
                              MCP configuration, and settings.json template
```

**Location**: Line 35

**Verification**:
```bash
ainish-coder --help | grep -A 2 "claude"
```

---

## Phase 4: Verification

### Objective
Ensure all implementations work correctly and follow best practices.

### Verification Checklist

#### 4.1 Structure Verification
```bash
# Verify all config files exist
ls -la .configs/.claude/skills/*/SKILL.md
ls -la .configs/.claude/agents/*.md
ls -la .configs/.claude/settings.json

# Verify YAML syntax
for f in .configs/.claude/skills/*/SKILL.md; do
    echo "Checking $f"
    head -n 10 "$f"
done

# Verify JSON syntax
cat .configs/.claude/settings.json | jq .
```

#### 4.2 Deployment Verification
```bash
# Clean test
rm -rf /tmp/test-claude-deploy
mkdir -p /tmp/test-claude-deploy

# Deploy (requires AGENTS.md first)
echo "# Test AGENTS.md" > /tmp/test-claude-deploy/AGENTS.md
ainish-coder --claude /tmp/test-claude-deploy

# Verify structure
tree /tmp/test-claude-deploy/.claude/ || find /tmp/test-claude-deploy/.claude/

# Verify content
ls -la /tmp/test-claude-deploy/.claude/
ls -la /tmp/test-claude-deploy/.claude/rules/
ls -la /tmp/test-claude-deploy/.claude/commands/
ls -la /tmp/test-claude-deploy/.claude/skills/
ls -la /tmp/test-claude-deploy/.claude/agents/
cat /tmp/test-claude-deploy/.claude/settings.json
```

#### 4.3 Anti-Pattern Verification
```bash
# Check for tabs in YAML (forbidden)
grep -P '\t' .configs/.claude/skills/*/SKILL.md && echo "ERROR: Tabs found!" || echo "OK: No tabs"

# Check for reserved words in skill names
grep -r 'name:.*\(anthropic\|claude\)' .configs/.claude/skills/ && echo "ERROR: Reserved words!" || echo "OK: No reserved words"

# Check for missing closing --- in frontmatter
for f in .configs/.claude/skills/*/SKILL.md .configs/.claude/agents/*.md; do
    if ! head -n 15 "$f" | grep -q '^---$'; then
        echo "ERROR: Missing closing --- in $f"
    fi
done

# Check description length (max 1024)
for f in .configs/.claude/skills/*/SKILL.md .configs/.claude/agents/*.md; do
    desc=$(grep '^description:' "$f" | cut -d':' -f2- | xargs)
    if [[ ${#desc} -gt 1024 ]]; then
        echo "ERROR: Description too long in $f (${#desc} chars)"
    fi
done

# Check name length (max 64) and format (kebab-case)
for f in .configs/.claude/skills/*/SKILL.md .configs/.claude/agents/*.md; do
    name=$(grep '^name:' "$f" | cut -d':' -f2- | xargs)
    if [[ ${#name} -gt 64 ]]; then
        echo "ERROR: Name too long in $f (${#name} chars)"
    fi
    if ! [[ "$name" =~ ^[a-z0-9-]+$ ]]; then
        echo "ERROR: Name not kebab-case in $f: $name"
    fi
done
```

#### 4.4 Integration Verification
```bash
# Verify CLI loads the molecule
grep -q "deploy_claude.sh" bin/ainish-coder && echo "OK: Molecule loaded" || echo "ERROR: Molecule not loaded"

# Verify help mentions new features
ainish-coder --help | grep -q "skills, agents" && echo "OK: Help updated" || echo "ERROR: Help not updated"

# Verify molecule has new functions
grep -q "skills" dna/molecules/deploy_claude.sh && echo "OK: Skills code present" || echo "ERROR: Skills code missing"
grep -q "agents" dna/molecules/deploy_claude.sh && echo "OK: Agents code present" || echo "ERROR: Agents code missing"
grep -q "settings.json" dna/molecules/deploy_claude.sh && echo "OK: Settings code present" || echo "ERROR: Settings code missing"
```

---

## Summary

This plan adds comprehensive Claude Code deployment support to `ainish-coder --claude`:

1. **Meta-Creator Skills** (✅ COMPLETED):
   - **skill-creator**: Expert skill creation specialist with enterprise best practices
   - **agent-creator**: Expert agent creation specialist with 2026 multi-agent patterns
   - These meta-skills embody industry-proven production knowledge for creating custom skills and agents

2. **Skills**: Auto-loaded capabilities that extend Claude's knowledge
3. **Agents**: Task-specialized subagents with specific tools and permissions
4. **Settings**: Complete Claude Code configuration template with MCP servers
5. **Commands**: Existing slash command deployment (already implemented)

### Key Features

**Meta-Creator Skills Enable**:
- Instant access to enterprise-grade skill/agent creation knowledge in every deployed project
- Self-service creation of specialized skills and agents for project-specific needs
- Validation against official Anthropic standards and best practices
- Anti-pattern detection and verification checklists

**Deployment Includes**:
- Production-ready skill and agent templates
- Multi-agent coordination patterns (orchestrator, P2P, hierarchical)
- Agent Teams configuration (2026 feature)
- MCP server integration templates
- Enterprise security patterns (Zero Trust, PQC compliance)

**Execution Order**: Phase 1 (partially complete) → Phase 2 → Phase 3 → Phase 4

### Research Sources

**Official Documentation**:
- Skills: https://docs.anthropic.com/en/docs/claude-code/skills
- Agents: https://github.com/anthropics/claude-code
- Open Standard: https://agentskills.io
- MCP: https://modelcontextprotocol.io
- Official Skills Repo: https://github.com/anthropics/skills

**Community Resources (February 2026)**:
- [Claude Code 官方最佳实践仓库上线了](https://m.toutiao.com/w/1857885021073411/)
- [Claude Code最佳实践：3.4k星的"官方心法"来了！](https://m.toutiao.com/a1857869114241417/)
- [Everything Claude Code](https://github.com/affaan-m/everything-claude-code) - 50K+ stars, hackathon winner
- [50条Claude Code实战心法](https://m.toutiao.com/w/1855247575707660/)
- [Claude 多 Agent 系统的技术实现原理](https://www.langchain.cn/t/topic/842)
- [Claude Code的隐藏技能：Subagent 全流程实操](https://blog.csdn.net/qq_32483009/article/details/157183611)
