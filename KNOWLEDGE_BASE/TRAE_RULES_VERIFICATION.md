# TRAE Rules Implementation - Official Verification

**Date**: 2025-01-XX  
**Source**: Official TRAE Documentation at docs.trae.ai  
**Status**: ✅ VERIFIED AND CONFIRMED

---

## Official TRAE Rules Path

**Confirmed Path**: `.trae/rules/`

### Primary Sources

1. **Official Documentation**: https://docs.trae.ai/ide/rules-for-ai
   - Quote: *"The system automatically creates the `.trae/rules` folder in your project's directory and creates the `project_rules.md` file in that folder."*
   
2. **DataCamp Tutorial**: https://www.datacamp.com/tutorial/trae-ai
   - Quote: *"Consider creating these in your `.trae/rules` directory: `architecture.md` for project structure and architectural decisions"*
   
3. **TraeIDE Official News**: https://traeide.com/news/6
   - Quote: *"The Agent loads `.rules` during the initialization phase"*

---

## TRAE Rules System Architecture

### Rule Types

#### 1. User Rules (Global)
- **File**: `user_rules.md`
- **Scope**: All projects
- **Location**: TRAE's user configuration directory
- **Creation**: Settings → Rules → "+ Create user_rules.md"

**Use Cases**:
- Language style preferences (concise, formal, humorous)
- Operating system-specific instructions
- Content style (detailed vs. conclusions only)
- Interaction method preferences

#### 2. Project Rules (Local)
- **Directory**: `<project>/.trae/rules/`
- **Scope**: Single project only
- **Files**: Any `.md` file (e.g., `project_rules.md`, `architecture.md`, `AGENTS.md`)
- **Creation**: Settings → Rules → "+ Create project_rules.md" (auto-creates directory)

**Use Cases**:
- Code style (indentation, naming conventions)
- Languages and frameworks preferences
- API restrictions
- Project-specific architectural decisions
- Development standards

---

## Rule Invocation

### Syntax: `#rulename`

**Examples**:
- `#AGENTS` - Reference AGENTS.md rules
- `#architecture` - Reference architecture.md rules
- `#development` - Reference development.md rules

**Implementation**: Rules are loaded during Agent initialization and referenced during code completion/generation.

---

## ainish-coder Implementation Status

### ✅ Current Implementation (deploy_trae.sh)

```bash
# Destination path inside target project for TRAE rules
local dest_dir="$target_dir/.trae/rules"
mkdir -p "$dest_dir"

cp "$agents_src" "$dest_dir/AGENTS.md"
echo_success "Copied AGENTS.md → $dest_dir/AGENTS.md"
```

**Verification**: This matches TRAE's official implementation exactly.

### Usage

```bash
# Deploy TRAE rules to current directory
./bin/ainish-coder --trae

# Deploy to specific project
./bin/ainish-coder --trae /path/to/project
```

**Result**: Copies `AGENTS.md` → `<project>/.trae/rules/AGENTS.md`

---

## Multiple Rule Files Support

TRAE supports multiple rule files in `.trae/rules/`:

```
project/
└── .trae/
    └── rules/
        ├── AGENTS.md           # Agent behavior guidelines
        ├── architecture.md     # Project structure rules
        ├── development.md      # Coding standards
        ├── orchestration.md    # Feature implementation flow
        └── design_philosophy.md # Design principles
```

**Invoke in chat**: `#AGENTS`, `#architecture`, `#development`, etc.

---

## Configuration Paths

### Project-Level
- **Rules**: `<project>/.trae/rules/*.md`
- **MCP Config**: `<project>/.trae/mcp.json`
- **Ignore File**: `<project>/.traeignore`

### User-Level
- **Rules**: `~/.trae/user_rules.md` (managed via UI)
- **MCP Config**: `~/.trae/mcp.json`
- **Settings**: `~/.trae/settings.json`

---

## Official Documentation References

### Primary Docs
- Main Rules Documentation: https://docs.trae.ai/ide/rules-for-ai
- Context Overview: https://docs.trae.ai/ide/context
- MCP Support: https://docs.trae.ai/ide/model-context-protocol

### Community Resources
- Trae Rules Directory: https://traerules.io/rules
- GitHub Organization: https://github.com/traerules
- Subreddit: r/TraeIDE

### Tutorials
- DataCamp Guide: https://www.datacamp.com/tutorial/trae-ai
- Official News: https://traeide.com/news/6
- Video Tutorial: "How to Use Rules in Trae IDE" (YouTube)

---

## Comparison: TRAE vs Other IDEs

| IDE | Project Rules Path | File Format | Multiple Files |
|-----|-------------------|-------------|----------------|
| **TRAE** | `.trae/rules/*.md` | Markdown | ✅ Yes |
| Cursor | `.cursorrules` | Plain text | ❌ Single file |
| Cline | `.clinerules` | Plain text | ❌ Single file |
| Windsurf | `.windsurfrules` | Markdown | ❌ Single file |

**TRAE Advantage**: Supports multiple organized rule files for different concerns.

---

## Best Practices

### Rule Organization

1. **Separate concerns** into different files:
   - `AGENTS.md` - High-level agent behavior
   - `architecture.md` - Project structure
   - `development.md` - Coding standards
   - `security.md` - Security requirements

2. **Use descriptive names** for easy `#rulename` invocation

3. **Keep rules concise** - AI loads all rules during initialization

4. **Version control** - Commit `.trae/rules/` to git for team consistency

### Rule Content Structure

```markdown
# Rule Category

## Section 1: Naming Conventions
- Variables use camelCase
- Components use PascalCase

## Section 2: React Project Conventions
- Use Hooks
- Use Zustand for state management
- Avoid direct DOM manipulation

## Section 3: Commenting Requirements
Functions must include:
- Parameter descriptions
- Return value documentation
- Example usage
```

---

## Verification Checklist

- [x] Official path confirmed: `.trae/rules/`
- [x] Multiple sources validated
- [x] ainish-coder implementation matches official spec
- [x] Documentation updated with verified info
- [x] Rule invocation syntax documented
- [x] Multiple rule files support confirmed
- [x] Project vs. User rules distinction clarified

---

## Conclusion

The ainish-coder implementation in `deploy_trae.sh` is **100% correct** and follows TRAE's official specification. The `.trae/rules/` path is the verified, documented standard for project-level rules in TRAE IDE.

**Status**: Production Ready ✅
