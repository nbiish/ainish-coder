# Quick Reference: AGENTS.md Workflow

## ⚠️ CRITICAL: Always run --agents first!

```bash
# Step 1: REQUIRED FIRST
ainish-coder --agents /path/to/project
```

## 🔗 Then deploy tool symlinks

```bash
# All of these REQUIRE AGENTS.md to exist
ainish-coder --copilot /path/to/project    # → .github/copilot-instructions.md
ainish-coder --cn /path/to/project         # → .continue/rules/AGENTS.md
ainish-coder --cline /path/to/project      # → .clinerules/AGENTS.md
ainish-coder --windsurf /path/to/project   # → .windsurf/rules/rules.md
ainish-coder --gemini /path/to/project     # → GEMINI.md
ainish-coder --qwen /path/to/project       # → QWEN.md
ainish-coder --roocode /path/to/project    # → .roo/AGENTS.md + .rooignore
```

## 📋 Optional supplementary files

```bash
ainish-coder --mairules /path/to/project  # → .mai-rules/MAIRULES.md
ainish-coder --critical /path/to/project  # → critical.md symlink
```

## ❌ What happens if you skip --agents?

```bash
$ ainish-coder --copilot /path/to/project

❌ Error: AGENTS.md not found in /path/to/project
💡 Run first: ainish-coder --agents /path/to/project
```

## ✅ Result

- **All tools read from single AGENTS.md**
- **Edit once, changes propagate everywhere**
- **No duplicate copies, no redundant intake**

## 🔍 Verify your setup

```bash
# Check what got deployed
ls -la /path/to/project/.github/copilot-instructions.md
ls -la /path/to/project/.clinerules/AGENTS.md
ls -la /path/to/project/AGENTS.md

# All symlinks should point to AGENTS.md
```

## 📚 Full help

```bash
ainish-coder --help
```
