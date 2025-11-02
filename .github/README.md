# GitHub Copilot Configuration for Ainish-Coder

This directory contains custom configurations for GitHub Copilot in VS Code, including custom chat modes, reusable prompts, and global instructions.

## Structure

```
.github/
├── copilot-instructions.md  # Global instructions applied to all chat requests
├── chatmodes/               # Custom AI personas for specialized tasks
│   ├── security-reviewer.chatmode.md
│   ├── code-judge.chatmode.md
│   └── deployment-architect.chatmode.md
└── prompts/                 # Reusable slash command prompts
    ├── critical-setup.prompt.md
    ├── deploy-ai-tool.prompt.md
    └── tier-deployment.prompt.md
```

## Global Instructions

**File**: `copilot-instructions.md`

This file contains project-wide instructions that automatically apply to all GitHub Copilot chat interactions in this workspace. It includes:
- Atomic Design architecture patterns
- Critical thinking framework
- Security principles
- Bash scripting standards
- Python package management
- Documentation requirements

## Custom Chat Modes

Chat modes create specialized AI personas for specific development tasks. Access them via the chat mode dropdown in the Chat view.

### Security Reviewer
**File**: `chatmodes/security-reviewer.chatmode.md`
**Model**: Claude Sonnet 4
**Tools**: search/codebase, fetch, usages

Expert in:
- OWASP Top 10 vulnerabilities
- STRIDE threat modeling
- LLM security and prompt injection defense
- Compliance (GDPR, HIPAA)
- Code security review

Use for: Security audits, vulnerability assessments, compliance checks

### Code Judge
**File**: `chatmodes/code-judge.chatmode.md`
**Model**: GPT-4o
**Tools**: search/codebase, fetch, usages

Expert in:
- Fact-based decision making
- Code Judge Constitution application
- Critical thinking framework
- Evidence-based recommendations
- Architecture evaluation

Use for: Code reviews, architecture decisions, design evaluations

### Deployment Architect
**File**: `chatmodes/deployment-architect.chatmode.md`
**Model**: GPT-4o
**Tools**: search/codebase, usages

Expert in:
- Atomic Design pattern (Atoms → Molecules → Organisms)
- Deployment script architecture
- Multi-tool AI assistant deployment
- Error handling and validation
- Modular, reusable infrastructure

Use for: Deployment strategy, infrastructure design, script architecture

## Reusable Prompts (Slash Commands)

Prompts are invoked with `/` commands in the chat input field.

### `/critical-setup`
**File**: `prompts/critical-setup.prompt.md`
**Mode**: Agent (autonomous)
**Model**: GPT-4o

Executes critical repository setup tasks:
1. Update LICENSE from canonical source
2. Update CONTRIBUTING.md
3. Add scholarly citation to README
4. Download donation QR code
5. Add donation section
6. Add copyright notice
7. Verify repository structure
8. Update .mai-rules/critical.md

Usage: `/critical-setup`

### `/deploy-ai-tool`
**File**: `prompts/deploy-ai-tool.prompt.md`
**Mode**: Agent (autonomous)
**Model**: GPT-4o

Deploy ainish-coder rules to AI coding assistants:
- Cursor
- GitHub Copilot
- Cline
- Continue
- Windsurf
- Roo Code

Usage: `/deploy-ai-tool tool=cursor` or `/deploy-ai-tool tool=all`

### `/tier-deployment`
**File**: `prompts/tier-deployment.prompt.md`
**Mode**: Agent (autonomous)
**Model**: GPT-4o

Deploy hierarchical tiered rule system:
- TIER_0: Documentation Protocol
- TIER_1: Code Security
- TIER_2: Prompt Security
- TIER_3: Anishinaabe Cyberpunk Style
- TIER_4: Modern Prompting

Usage: `/tier-deployment tiers=all` or `/tier-deployment tiers=1,2`

## How to Use

### Switching Chat Modes

1. Open the Chat view (Ctrl+Alt+I / ⌃⌘I)
2. Click the chat mode dropdown at the top
3. Select your desired custom mode:
   - Security Reviewer
   - Code Judge
   - Deployment Architect

### Using Slash Commands

In the Chat view input field:
1. Type `/` to see available prompts
2. Type prompt name: `/critical-setup`, `/deploy-ai-tool`, etc.
3. Add parameters if needed: `/deploy-ai-tool tool=cursor`
4. Press Enter to execute

### Global Instructions

The `copilot-instructions.md` file automatically applies to all chat interactions in this workspace. You don't need to do anything - Copilot reads it automatically.

## Customization

### Creating New Chat Modes

1. In Chat view, select **Configure Chat** > **Modes** > **Create new custom chat mode file**
2. Choose **Workspace** to save in `.github/chatmodes/`
3. Define the mode with YAML frontmatter:
   ```yaml
   ---
   description: Your mode description
   tools: ['search/codebase', 'fetch', 'usages']
   model: GPT-4o
   ---
   ```
4. Add instructions in Markdown format

### Creating New Prompts

1. In Chat view, select **Configure Chat** > **Prompt Files** > **New prompt file**
2. Choose **Workspace** to save in `.github/prompts/`
3. Define the prompt with YAML frontmatter:
   ```yaml
   ---
   mode: 'agent'
   model: GPT-4o
   tools: ['search/codebase']
   description: 'Your prompt description'
   ---
   ```
4. Add prompt instructions in Markdown format

## Integration with Ainish-Coder

These configurations integrate with the broader ainish-coder system:

- **AGENTS.md**: Rules location hierarchy and code architecture
- **MAIRULES.md**: Project-specific coding rules
- **TIER_*_RULES/**: Hierarchical security and style rules
- **population/**: Atomic design deployment system

All chat modes and prompts reference these core files to ensure consistency across AI assistants.

## References

- [VS Code Copilot Documentation](https://code.visualstudio.com/docs/copilot)
- [Custom Instructions Guide](https://code.visualstudio.com/docs/copilot/customization/custom-instructions)
- [Custom Chat Modes Guide](https://code.visualstudio.com/docs/copilot/customization/custom-chat-modes)
- [Prompt Files Guide](https://code.visualstudio.com/docs/copilot/customization/prompt-files)
- [Awesome Copilot Repository](https://github.com/github/awesome-copilot)

## Indigenous Intellectual Property Notice

This configuration embodies Traditional Knowledge (TK) and Traditional Cultural Expressions (TCE) protected under tribal sovereignty and Indigenous Data Sovereignty principles.

Copyright © 2025 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish Waabanimikii-Kinawaabakizi). All rights reserved.

See [LICENSE](../LICENSE) for complete terms.
