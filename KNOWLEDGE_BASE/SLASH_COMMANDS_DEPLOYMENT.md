# Slash Commands Deployment Implementation

**Date:** November 2, 2025  
**Status:** ✅ Implemented  
**Source:** Web research via Tavily (verified current information)

## Overview

Successfully implemented deployment of `.github/prompts/*.prompt.md` files to slash command/prompt systems across 7 major AI coding tools. This enables consistent security and quality frameworks across all development environments.

## Research Findings (Verified November 2025)

### AI Coding Tools with Slash Command Support

#### IDE Extensions

| Tool | Configuration Location | Format | Status |
|------|----------------------|--------|--------|
| **GitHub Copilot** | `.github/prompts/` | `*.prompt.md` with YAML frontmatter | ✅ Already supported |
| **Cursor** | `.cursor/commands/` | Plain markdown `*.md` | ✅ Implemented |
| **Claude Code** | `.claude/commands/` | Plain markdown `*.md` | ✅ Implemented |
| **Continue.dev** | `.continue/prompts/` | Markdown with optional YAML | ✅ Implemented |
| **Windsurf** | `.windsurf/prompts/` + rules | Plain markdown | ✅ Implemented |
| **Cline** | `.cline/prompts/` | Markdown (MCP compatible) | ✅ Implemented |
| **Roo Code** | `.roo/prompts/` + rules | Plain markdown | ✅ Implemented |

#### CLI Tools

| Tool | Configuration Location | Format | Key Features | Status |
|------|----------------------|--------|--------------|--------|
| **Claude Code CLI** | `.claude/commands/` | Markdown with frontmatter | Slash commands, subagents, hooks | ✅ Uses same as IDE |
| **Gemini CLI** | `GEMINI.md` + extensions | Markdown + custom commands | Extensions bundle MCP + commands | 🔄 Needs specific impl |
| **Continue CLI (cn)** | `.continue/prompts/` + assistants | YAML config with prompts | Background agents, workflows | ✅ Uses same as IDE |
| **Cline CLI** | `.cline/prompts/` | Markdown (MCP) | Scriptable, persistent loop | ✅ Uses same as IDE |
| **Qwen Code** | Context files + prompts | Markdown | Forked from Gemini CLI | 🔄 Needs specific impl |
| **Goose** | `.goosehints` + context | Markdown | MCP integration, multi-model | 🔄 Needs specific impl |

## Implementation Details

### Created Deployment Molecules

All scripts follow the Atomic Design pattern and are located in `population/molecules/`:

1. **deploy_cursor_commands.sh**
   - Strips YAML frontmatter from source prompts
   - Deploys to `.cursor/commands/`
   - Access: `Cmd+K` in Cursor

2. **deploy_claude_commands.sh**
   - Strips YAML frontmatter
   - Deploys to `.claude/commands/`
   - Access: `/` in Claude Code chat

3. **deploy_continue_prompts.sh**
   - Keeps YAML frontmatter (Continue supports it)
   - Deploys to `.continue/prompts/`
   - Includes README with configuration examples

4. **deploy_windsurf_prompts.sh**
   - Strips YAML frontmatter
   - Deploys to `.windsurf/prompts/`
   - Creates rules file that references prompts
   - Cascade automatically uses patterns

5. **deploy_cline_prompts.sh**
   - Keeps YAML frontmatter
   - Deploys to `.cline/prompts/`
   - Includes README with CLI usage examples
   - MCP server compatible

6. **deploy_roocode_prompts.sh**
   - Strips YAML frontmatter
   - Deploys to `.roo/prompts/`
   - Creates rules file integration
   - Reference in custom instructions

### Updated Core Scripts

1. **deploy_commands.sh**
   - Completely rewritten to handle prompt deployments
   - Sources all prompt deployment molecules
   - Supports individual tool or "all" deployment
   - Provides helpful error messages and usage info

2. **bin/ainish-coder**
   - Added sourcing of all prompt deployment molecules
   - --commands flag now routes to deploy_commands()
   - Backward compatible with existing functionality

3. **help.sh**
   - Updated with comprehensive --commands documentation
   - Lists all supported tools
   - Shows target directories for each tool

## Usage

### Deploy to Specific Tool

```bash
# Deploy slash commands to Cursor
ainish-coder --commands cursor

# Deploy to Claude Code
ainish-coder --commands claude

# Deploy to Continue.dev
ainish-coder --commands continue

# Deploy to Windsurf
ainish-coder --commands windsurf

# Deploy to Cline
ainish-coder --commands cline

# Deploy to Roo Code
ainish-coder --commands roocode
```

### Deploy to All Tools

```bash
# Deploy prompts to all supported tools at once
ainish-coder --commands all
```

### Deploy to Specific Directory

```bash
# Deploy to a specific project
ainish-coder --commands cursor /path/to/project
ainish-coder --commands all /path/to/project
```

## Prompt Files Deployed

From `.github/prompts/`:

1. **code-judge.prompt.md**
   - Critical thinking analysis
   - Code Judge Constitution
   - Fact-based decision making

2. **secure-code.prompt.md**
   - Security vulnerability analysis
   - OWASP Top 10 compliance
   - STRIDE threat modeling

3. **secure-prompts.prompt.md**
   - LLM security framework
   - Prompt injection defense
   - System prompt leakage prevention

## Format Handling

### YAML Frontmatter Stripping

Tools that prefer plain markdown (Cursor, Claude, Windsurf, Roo Code):
- Automatically strips YAML frontmatter using `sed`
- Keeps only the content portion
- Fallback to copying as-is if sed unavailable

### YAML Frontmatter Preservation

Tools that support metadata (Continue.dev, Cline):
- Preserves YAML frontmatter
- Enables richer configuration options
- Metadata can be used for categorization

## Tool-Specific Integration Notes

### IDE Extensions

### GitHub Copilot

- Already handled by existing `--copilot` flag
- Uses `copilot-instructions.md` + `.github/prompts/`
- No changes needed

### Cursor

- Commands appear in `Cmd+K` interface
- No additional configuration required
- Works with all Cursor models

### Claude Code

- Access via `/` in chat
- Automatically indexed on startup
- Works with Claude 4.x models

### Continue.dev

- Reference in assistant configs
- Can be used in slash commands
- Supports YAML metadata for routing

### Windsurf

- Cascade automatically discovers prompts
- Rules file provides context
- Memories can reference patterns

### Cline

- Can be invoked via CLI
- MCP server compatible
- VS Code extension support

### Roo Code

- Reference in custom instructions
- Rules integration
- Multi-mode support

---

### CLI Tools

### Claude Code CLI

**Configuration:** `.claude/commands/` (same as IDE extension)

**Key Features:**
- Slash commands with markdown frontmatter
- Subagents for specialized tasks
- Hooks for workflow customization
- MCP server integration

**Usage:**
```bash
# Interactive mode with slash commands
claude

# List available commands
/help

# Create custom command
echo "# My Command\nPrompt here" > .claude/commands/my-command.md

# Use in session
/my-command
```

**Integration:** Deploy using same scripts as IDE extension - prompts work in both contexts.

### Gemini CLI

**Configuration:** `GEMINI.md` + extensions

**Key Features:**
- Project context via `GEMINI.md` file
- Extensions bundle MCP servers + commands + context
- Custom slash commands in extensions
- Subagent support (coming soon)
- 1M token context window

**Usage:**
```bash
# Initialize project context
gemini /init

# Create GEMINI.md automatically
# Add custom commands via extensions

# Install extension with custom commands
gemini ext install <extension-url>

# Use custom slash commands
/my-custom-command
```

**Deployment Strategy:** 
- Deploy GEMINI.md with project context
- Create extensions that bundle our prompts as slash commands
- Reference security frameworks in GEMINI.md

### Continue CLI (cn)

**Configuration:** `.continue/prompts/` + assistant configs (same as IDE)

**Key Features:**
- Background agents that run asynchronously
- Workflow automation (PR opens, schedules)
- Headless operation for CI/CD
- Full assistant configuration support

**Usage:**
```bash
# Use with assistant that references prompts
cn --agent my-assistant "Task description"

# Headless mode with auto-approval
cn --agent security-review -p "Review code" --auto

# Reference prompts in config
# ~/.continue/config.yaml or assistant YAML
```

**Integration:** Same deployment as IDE - assistants can reference `.continue/prompts/` files.

### Cline CLI

**Configuration:** `.cline/prompts/` (same as IDE)

**Key Features:**
- Scriptable agent with persistent loop
- Delegates between IDE, CLI, and CI
- MCP server compatible
- Shares context with IDE extension

**Usage:**
```bash
# Reference prompts in tasks
cline "Use code-judge prompt to review this"

# With MCP and prompt reference
cline --prompt "$(cat .cline/prompts/secure-code.prompt.md)" "Audit security"

# Interactive with slash commands available
cline
```

**Integration:** Same deployment as IDE extension - prompts accessible in both.

### Qwen Code

**Configuration:** Context files + custom prompts (forked from Gemini CLI)

**Key Features:**
- Adapted from Gemini CLI for Qwen models
- Enhanced parser for Qwen-specific features
- Agentic coding capabilities
- Tool support via MCP

**Usage:**
```bash
# Similar to Gemini CLI patterns
qwen-code /init

# Reference context in prompts
# Use @file syntax for context

# Install via npm
npm install -g qwen-code
```

**Deployment Strategy:**
- Create Qwen-specific context files
- Adapt GEMINI.md patterns for Qwen
- Bundle prompts as commands

### Goose

**Configuration:** `.goosehints` + context files

**Key Features:**
- Open source, extensible agent
- Multi-model support (lead/worker pattern)
- Planning mode for complex tasks
- MCP extension support
- Automatic model switching

**Usage:**
```bash
# Interactive mode
goose

# With context hints
# Create .goosehints in project

# Multi-model configuration
# Lead model for planning, worker for execution

# Use MCP tools
goose mcp list
```

**Deployment Strategy:**
- Create `.goosehints` file with prompt patterns
- Deploy context files for security frameworks
- Configure MCP servers for tool access

---

## Security Considerations

All deployment scripts:
- ✅ Validate target directories
- ✅ Use `safe_mkdir` from atoms
- ✅ Handle missing source gracefully
- ✅ Provide clear error messages
- ✅ Follow principle of least surprise

No sensitive data included in prompts:
- ✅ No API keys
- ✅ No credentials
- ✅ No PII
- ✅ Public security frameworks only

## Testing Recommendations

For each tool deployment:

1. **Verify Files Created**
   ```bash
   ls -la .cursor/commands/
   ls -la .claude/commands/
   # etc.
   ```

2. **Check File Contents**
   ```bash
   cat .cursor/commands/code-judge.md
   # Verify YAML stripped correctly
   ```

3. **Test in Tool**
   - Open the tool (Cursor, Claude Code, etc.)
   - Try invoking the command
   - Verify prompt loads correctly

4. **Verify Integration**
   - Check that tool recognizes commands
   - Confirm slash command completion works
   - Test with actual coding tasks

## Future Enhancements

Potential improvements:

1. **Auto-sync on AGENTS.md changes**
   - Watch for updates to source prompts
   - Automatically redeploy to all tools

2. **Tool-specific prompt variations**
   - Customize prompts per tool's strengths
   - Optimize for different AI models

3. **Interactive mode**
   - Ask user which tools to deploy to
   - Provide deployment preview

4. **Validation testing**
   - Automated tests for each tool
   - Verify command accessibility

5. **Telemetry (opt-in)**
   - Track which commands are most used
   - Improve based on usage patterns

## References

### Documentation Sources
- [GitHub Copilot prompts](https://code.visualstudio.com/docs/copilot/reference/copilot-vscode-features)
- [Cursor commands](https://github.com/hamzafer/cursor-commands)
- [Claude Code slash commands](https://blog.sshh.io/p/how-i-use-every-claude-code-feature)
- [Continue.dev config](https://docs.continue.dev/)
- [Windsurf cascade](https://windsurf.com/changelog)
- [Cline prompts](https://cline.bot/blog)
- [Roo Code custom instructions](https://docs.roocode.com/features/custom-instructions)

### Research Method
- Web searches via Tavily MCP server
- Verified current (November 2025) documentation
- Cross-referenced multiple sources
- Tested format requirements

## Conclusion

Successfully implemented comprehensive slash command deployment across 7 major AI coding tools. The implementation:

✅ **Follows established patterns** - Uses atomic design with molecules  
✅ **Maintains consistency** - Same prompts across all tools  
✅ **Handles edge cases** - Graceful fallbacks, clear errors  
✅ **Documented thoroughly** - Help text, README files, this doc  
✅ **Security-focused** - Validates inputs, no sensitive data  
✅ **User-friendly** - Simple commands, helpful messages  

All tools can now use the security and quality frameworks defined in `.github/prompts/` as slash commands or prompt references in their native format.
