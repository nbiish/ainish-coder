# Slash Commands Deployment - Corrections Summary

**Date**: November 2, 2025
**Issue**: Initial deployment scripts were based on incorrect assumptions about how each tool implements custom commands/workflows

## What Was Wrong

Our initial implementation assumed most tools used file-based markdown slash commands similar to GitHub Copilot. This was **incorrect**. After thorough research, we discovered each tool has its own unique implementation pattern.

## Corrected Implementations

### ✅ File-Based Slash Commands (Markdown)

#### 1. **Cursor** - `.cursor/commands/`
- **Format**: Plain markdown files
- **Filename**: Becomes command name (`review.md` → `/review`)
- **YAML Frontmatter**: **Strip it** (Cursor expects plain markdown)
- **Status**: Was already correct in initial implementation

#### 2. **Roo Code** - `.roo/commands/`
- **Format**: Markdown files with optional YAML frontmatter
- **Filename**: Becomes command name
- **YAML Frontmatter**: **KEEP it** (supports `description:` and `argument-hint:`)
- **Status**: **FIXED** - Was stripping YAML, now preserves it

### 🔧 File-Based Slash Commands (TOML)

#### 3. **Gemini CLI** - `.gemini/commands/`
- **Format**: **TOML files only** (NOT markdown!)
- **Structure**: 
  ```toml
  description = "Command description"
  prompt = """
  Multi-line prompt content
  """
  ```
- **Namespacing**: Supports subdirectories (`git/commit.toml` → `/git:commit`)
- **Status**: **COMPLETELY REWRITTEN** - Was creating markdown, now creates TOML

#### 4. **Qwen Code** - `.qwen/commands/`
- **Format**: **TOML files** (forked from Gemini CLI)
- **Structure**: Same as Gemini
- **Status**: **COMPLETELY REWRITTEN** - Was creating QWEN.md context file, now creates TOML commands

### 📋 Workflow-Based Systems (Markdown)

#### 5. **Windsurf** - `.windsurf/workflows/`
- **Format**: Markdown files (title, description, steps)
- **Invocation**: `/[workflow-name]` (without .md extension)
- **YAML Frontmatter**: **Strip it**
- **Discovery**: Auto-discovers from workspace, subdirs, and git root
- **Limit**: 12,000 characters per workflow
- **Status**: **UPDATED** - Now properly formats as workflows, not generic prompts

#### 6. **Cline** - `.clinerules/workflows/`
- **Format**: Markdown files
- **Invocation**: `/[workflow-name].md` (WITH .md extension)
- **YAML Frontmatter**: **Keep it** (if supported)
- **Integration**: Lives alongside Cline rules
- **Can leverage**: Built-in tools like `read_file`, `search_files`, `ask_followup_question`
- **Status**: **COMPLETELY REWRITTEN** - Was deploying to `.cline/prompts/`, now deploys to `.clinerules/workflows/`

### ⚙️ Config-Based Systems

#### 7. **Continue.dev** - `config.yaml`
- **Format**: **NOT file-based!** Prompts defined in `~/.continue/config.yaml`
- **Structure**:
  ```yaml
  prompts:
    - name: Command Name
      description: What it does
      invokable: true
      content: |
        Prompt content here
  ```
- **Alternative**: Use Continue Hub to add pre-built prompts
- **Status**: **COMPLETELY REWRITTEN** - Now provides SETUP_GUIDE.md explaining config.yaml approach

### 📄 Recipe-Based Systems

#### 8. **Goose** - `.goose/recipes/`
- **Format**: **YAML or JSON recipe files** (NOT .goosehints!)
- **Structure**:
  ```yaml
  version: "1.0.0"
  title: "Recipe Title"
  description: "What the recipe does"
  instructions: |
    Multi-line instructions
  prompt: "Initial prompt"
  extensions: []
  ```
- **Usage**: 
  - CLI: `goose run --recipe .goose/recipes/recipe-name.yaml`
  - Desktop: Import from Recipe Library
- **Features**: Supports parameters, activities (clickable buttons), MCP extensions, subrecipes
- **Status**: **COMPLETELY REWRITTEN** - Was creating .goosehints file, now creates YAML recipes

## Impact on Deployment Scripts

### Scripts Completely Rewritten:
1. `deploy_gemini_cli_prompts.sh` - Now creates TOML files
2. `deploy_qwen_cli_prompts.sh` - Now creates TOML files
3. `deploy_continue_prompts.sh` - Now provides config.yaml guide
4. `deploy_cline_prompts.sh` - Now deploys to workflows directory
5. `deploy_windsurf_prompts.sh` - Now properly formats as workflows
6. `deploy_goose_prompts.sh` - Now creates YAML recipe files

### Scripts Updated:
1. `deploy_roocode_prompts.sh` - Now preserves YAML frontmatter

### Scripts Already Correct:
1. `deploy_cursor_commands.sh` - Was already correct

## Key Learnings

1. **Research is Critical**: Initial assumptions based on one tool (GitHub Copilot) didn't apply to others
2. **Tool Diversity**: Each AI coding tool has evolved its own approach:
   - File-based commands (Cursor, Roo)
   - TOML configs (Gemini, Qwen)
   - Workflows (Windsurf, Cline)
   - YAML configs (Continue)
   - Recipe systems (Goose)
3. **YAML Frontmatter Handling**: Varies by tool - some need it, some don't, some can't use it
4. **Documentation Matters**: Official docs were essential for correct implementation
5. **User Corrections Essential**: Community feedback (like the Goose recipes correction) is invaluable

## Next Steps

- [ ] Update SLASH_COMMANDS_DEPLOYMENT.md with accurate tool descriptions
- [ ] Update help.sh with corrected tool descriptions
- [ ] Update deploy_commands.sh output messages
- [ ] Test each deployment script
- [ ] Create examples showing proper usage for each tool

## References

- Cursor: https://cursor.com/docs/agent/chat/commands
- Roo Code: https://docs.roocode.com/features/slash-commands
- Gemini CLI: https://cloud.google.com/blog/topics/developers-practitioners/gemini-cli-custom-slash-commands
- Qwen Code: https://github.com/QwenLM/Qwen-Code
- Windsurf: https://docs.windsurf.com/windsurf/cascade/workflows
- Cline: https://docs.cline.bot/features/slash-commands/workflows
- Continue.dev: https://docs.continue.dev/customize/deep-dives/prompts
- Goose: https://block.github.io/goose/docs/guides/recipes
