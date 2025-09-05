# PRODUCT REQUIREMENTS DOCUMENT: ainish-coder

**Author:** ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ (Nbiish-Justin Waabanimikii-Kenwabikise) | **Date:** 2025-01-27 | **Version:** 1.0.0

## 1. EXAMPLES

1. ```ainish-coder``` distributes the `.ainish-coder/` directory where it is called.

```bash
.ainish-coder/
⮑ *.mdc
⮑ .gitignore
⮑ .cursorignore
⮑ .cursorindexignore
⮑ .github/
    ⮑ FUNDING.yml
```

2. ```ainish-coder --vscode``` distributes the `.ainish-coder/` directory where it is called.

```bash
.ainish-coder/
⮑ copilot-instructions.md # (*.mdc appended into this directory -> !{certain.mdc} files)
⮑ .gitignore
⮑ .copilotignore
⮑ .copilotindexignore
⮑ .github/
    ⮑ FUNDING.yml
    ⮑ instructions/
        ⮑ ainishinaabe-cyberpunk-style.instructions.md
        ⮑ prompt-security.instructions.md
        ⮑ critical.instructions.md
        ⮑ code-security.instructions.md
        ⮑ KNOWLEDGE_BASE.instructions.md
        ⮑ PRD.instructions.md
```

3. ```ainish-coder --markdown``` distributes the `.ainish-coder/` directory where it is called.

```bash
.ainish-coder/
⮑ cp ../*.mdc *.md
⮑ .gitignore
⮑ .github/
    ⮑ FUNDING.yml
```

4. ```ainish-coder --qwen``` distribution below:

```bash
~/.qwen/QWEN.md # -> (append all *.mdc this file QWEN.md !{certain.mdc} files)
# !{certain.mdc} files:
# .ainish-coder/
# ⮑ ainishinaabe-cyberpunk-style.md
# ⮑ prompt-security.md
# ⮑ critical.md
# ⮑ code-security.md
# ⮑ KNOWLEDGE_BASE.md
# ⮑ PRD.md
```

5. ```ainish-coder --gemini``` distribution below:

```bash
~/.gemini/GEMINI.md # -> (append all *.mdc this file GEMINI.md !{certain.mdc} files)
# !{certain.mdc} files:
# .ainish-coder/
# ⮑ ainishinaabe-cyberpunk-style.md
# ⮑ prompt-security.md
# ⮑ critical.md
# ⮑ code-security.md
# ⮑ KNOWLEDGE_BASE.md
# ⮑ PRD.md
```

6. ```ainish-coder --style``` distributes the `ainishinaabe-cyberpunk-style.mdc` as a .md file in the current directory.

```bash
ainishinaabe-cyberpunk-style.md
```

7. ```ainish-coder --security``` distributes the `prompt-security.mdc` & `code-security.mdc` as a .md file in the current directory.

```bash
prompt-security.md
code-security.md
critical.md
```

8. ```ainish-coder --license``` distributes the `critical.mdc` as a .md file in the current directory.

```bash
critical.md
```

9. ```ainish-coder --instructions``` distributes the `.ainish-coder/` directory where it is called.

```bash
.ainish-coder/
⮑ ainishinaabe-cyberpunk-style.md
⮑ prompt-security.md
⮑ critical.md
⮑ code-security.md
⮑ KNOWLEDGE_BASE.md
⮑ PRD.md
```

10. ```ainish-coder --help``` displays the help message.

```bash
Usage: ainish-coder [options]
Options:
  --vscode        Distribute for VSCode Copilot
  --markdown      Distribute as Markdown files
  --qwen          Distribute for QWEN
  --gemini        Distribute for Gemini
  --style         Distribute Ainshinaabe Cyberpunk Style Guide
  --security      Distribute Prompt & Code Security Guidelines
  --instructions  Distribute Instructions
  --license       Distribute Critical Reminders
  --help          Display this help message
```

## 2. Setup Instructions

All file copies from commands are pulled from the repository our setup script is ran in.
