#!/bin/bash
# Help and usage information

show_help() {
    cat << 'EOF'
ainish-coder - Configuration Manager for AI Coding Assistants

USAGE:
    ainish-coder [COMMAND] [ARGS...] [TARGET_DIR]

CORE COMMANDS:
    --rules [TARGET_DIR]      Deploy AGENTS.md + empty MAIRULES.md + critical.md + .gitignore
    --agents [TARGET_DIR]     Deploy AGENTS.md only (universal AI agent standard)
    --mairules [TARGET_DIR]   Deploy MAIRULES.md with ALL tiers (0-4 concatenated)
    
TIER DEPLOYMENT:
    --tier {0-4} [TARGET_DIR] Append specific tier to MAIRULES.md
    --tier all [TARGET_DIR]   Append all tiers (0-4) to MAIRULES.md
    --tier0 [TARGET_DIR]      Append TIER_0 (Documentation protocols)
    --tier1 [TARGET_DIR]      Append TIER_1 (Code security)
    --tier2 [TARGET_DIR]      Append TIER_2 (Prompt security)
    --tier3 [TARGET_DIR]      Append TIER_3 (Cultural styling)
    --tier4 [TARGET_DIR]      Append TIER_4 (Advanced prompting)

TOOL-SPECIFIC CONFIGURATION:
    Each tool deployment now includes:
    • AGENTS.md and MAIRULES.md (core rules)
    • Tool-specific commands/workflows/recipes
    • Ignore files for context optimization
    
    --cursor [TARGET_DIR]     Deploy Cursor AI - rules, commands, ignore files
    --windsurf [TARGET_DIR]   Deploy Windsurf - rules, workflows
    --cline [TARGET_DIR]      Deploy Cline - single .clinerules file (merged rules), ignore files
    --claude [TARGET_DIR]     Deploy Claude Code - rules, commands
    --copilot [TARGET_DIR]    Deploy GitHub Copilot to .github/instructions/
    --continue [TARGET_DIR]   Deploy Continue.dev - rules, prompts, ignore files
    --cn [TARGET_DIR]         Alias for --continue
    --gemini [TARGET_DIR]     Deploy Gemini CLI - rules, commands (TOML)
    --qwen [TARGET_DIR]       Deploy Qwen AI - rules, commands (TOML), QWEN.md
    --roocode [TARGET_DIR]    Deploy Roo Code - rules, commands, ignore files
    --roo [TARGET_DIR]        Alias for --roocode
    --trae [TARGET_DIR]       Deploy TRAE rules by copying repository AGENTS.md into
                              TARGET_DIR/.trae/rules/AGENTS.md (defaults to current dir)
                              Example: --trae ./my-project

AGENT CUSTOMIZATION:
    --template-agent [DIR]    Deploy template-agent.md for crafting custom system prompts
                              
                              Creates: .mai-rules/template-agent.md
                              
                              Features:
                              - Comprehensive system prompt framework
                              - Persona and goals section
                              - Tool instructions with examples
                              - Output format standards
                              - Iteration and refinement guidance
                              - Clearly marked [FILL_IN] sections
                              
                              Use this to create your agent's "constitution" - the core
                              instructions that guide every interaction. Start simple,
                              iterate based on behavior. No A/B testing needed on day one.
                              
                              Example: ainish-coder --template-agent ~/my-project

    --OSAA [DIR]              Deploy OSAA.md framework for orchestrated agent actions
                              
                              Creates: OSAA.md (Orchestrator Sub-Agent Action)
                              
                              Features:
                              - Task decomposition patterns
                              - Agent orchestration guidelines
                              - Sub-agent specialization (Code, Test, Doc, Deploy)
                              - Execution patterns (Sequential, Parallel, Pipeline)
                              - Communication protocols
                              - Error handling strategies
                              - Monitoring and metrics
                              
                              Use this for complex tasks requiring multiple specialized
                              agents working together under a master orchestrator.
                              
                              Example: ainish-coder --OSAA ~/my-project

    --osa [DIR]               Deploy full OSA (Ralph-First) Framework
                              
                              Creates: OSA.md, OSAVARS.toon, llms.txt, TODO.md
                              
                              Features:
                              - Ralph Loop Trunk Orchestrator (Claude)
                              - Sub-agent priority (Gemini -> Qwen -> Opencode)
                              - Autonomous state tracking via OSAVARS.toon
                              - Unified task checklist via TODO.md
                              
                              Example: ainish-coder --osa ~/my-project

CUSTOM COMMANDS DEPLOYMENT:
    --commands {tool} [DIR]   Deploy slash commands/workflows for AI tools
                              
                              IDE Extensions (File-Based):
                              - cursor      (.cursor/commands/*.md - plain markdown)
                              - roocode     (.roo/commands/*.md - with frontmatter)
                              
                              IDE Extensions (Workflows):
                              - windsurf    (.windsurf/workflows/*.md)
                              
                              IDE Extensions (Rules - NOT Slash Commands):
                              - cline       (.clinerules/*.md - rules files, NOT slash commands!)
                                            Note: Cline only has /newtask and /newrule (built-in)
                              
                              IDE Extensions (Config-Based):
                              - continue    (provides config.yaml setup guide)
                              
                              CLI Tools (TOML Commands):
                              - gemini-cli  (.gemini/commands/*.toml)
                              - qwen        (.qwen/commands/*.toml)
                              
                              Other:
                              - copilot     (use --copilot flag instead)
                              - all         (deploy to all applicable tools)
                              
                              Example: ainish-coder --commands all

UTILITY COMMANDS:
    --critical [TARGET_DIR]   Deploy critical.md from TIER_0
    --license [TARGET_DIR]    Deploy LICENSE file
    --gitignore [TARGET_DIR]  Deploy comprehensive .gitignore
    --local-security [DIR]    Deploy LOCAL secret protection (git hooks + scripts)
                              Deploys:
                              - .ainish/scripts/ (sanitize.py, scan_secrets.sh)
                              - Pre-commit & Pre-push hooks (auto-sanitizes)
                              
                              Recommended for super-simple local orchestration.
                              Example: ainish-coder --local-security ~/my-project

    --github-actions [DIR]    Deploy GitHub Actions workflows (CI/CD integration)
                              Deploys:
                              - .github/workflows/ (CI secret scanning, CodeQL, ZAP, PQC audit)
                              - .github/scripts/ (sanitize.py, scan_secrets.sh)
                              - Pre-commit & Pre-push hooks (backup layer)
                              
                              Note: Requires GitHub repo settings for full functionality.
                              Example: ainish-coder --github-actions ~/my-project

    --mcp-recipes [DIR]       Deploy MCP recipes (e.g., Tavily CLI templates)
                              Deploys markdown templates to mcp_recipes/ in target directory.
                              Example: ainish-coder --mcp-recipes ~/my-project

IGNORE FILE DEPLOYMENT:
    --cursor-ignore [DIR]     Deploy .cursorignore for Cursor AI
    --cline-ignore [DIR]      Deploy .clineignore for Cline VSCode extension
    --continue-ignore [DIR]   Deploy .continueignore for Continue.dev
    --copilot-ignore [DIR]    Deploy .copilotignore for GitHub Copilot
    --roocode-ignore [DIR]    Deploy .rooignore for Roo Code
    --roo-ignore [DIR]        Alias for --roocode-ignore
    --all-ignores [DIR]       Deploy all ignore files at once
                              
                              Ignore files help AI tools focus on relevant code by
                              excluding dependencies, build artifacts, and sensitive files.

OTHER:
    --help, -h                Show this help message
    --version, -v             Show version information

NOTES:
    - TARGET_DIR defaults to current directory if not provided
    - Tier deployments APPEND to MAIRULES.md (they don't deploy to .mai-rules/)
    - --rules deploys AGENTS.md + empty MAIRULES.md + critical.md + .gitignore
    - Tool deployments now include ALL configurations (rules + commands/recipes + ignores)
NOTES:
    - TARGET_DIR defaults to current directory if not provided
    - Tier deployments APPEND to MAIRULES.md (they don't overwrite)
    - --rules deploys AGENTS.md + empty MAIRULES.md + critical.md + .gitignore
    - Use --mairules for ALL tiers or --tier {1-4} to add specific tiers
    - Run --rules first before tool-specific deployments

EXAMPLES:
    # Recommended workflow - deploy core rules first
    ainish-coder --rules                    # Deploy to current directory
    ainish-coder --rules ~/my-project       # Deploy to specific directory
    
    # Tool-specific deployments
    ainish-coder --rules                    # Deploy AGENTS.md + empty MAIRULES.md + critical.md + .gitignore

    # Add more tiers as needed
    ainish-coder --tier 1                   # Append code security
    ainish-coder --tier 2                   # Append prompt security
    ainish-coder --tier all                 # Append all remaining tiers (1-4)

    # OR deploy all tiers at once
    ainish-coder --mairules                 # Deploy MAIRULES.md with ALL tiers

    # Deploy tool configurations (requires AGENTS.md/MAIRULES.md first)
    ainish-coder --cursor                   # Deploy to current directory
    ainish-coder --windsurf /path/to/project
    
    # Deploy custom commands
    ainish-coder --commands cursor          # Deploy slash commands
    ainish-coder --commands windsurf        # Deploy workflows
    ainish-coder --commands cline           # Deploy rules files (NOT slash commands)

    # Utility deployments
    ainish-coder --gitignore                # Create comprehensive .gitignore
    ainish-coder --local-security           # Deploy local-only secret protection
    ainish-coder --github-actions           # Deploy CI/CD secret protection
    
    # Deploy ignore files for AI tools
    ainish-coder --cursor-ignore            # Deploy .cursorignore
    ainish-coder --all-ignores              # Deploy all ignore files
    ainish-coder --continue-ignore ~/project # Deploy to specific directory

IMPORTANT NOTES:
    ⚠️  Cline does NOT support custom slash commands! It only has /newtask and /newrule
        built-in. The --commands cline deployment creates .clinerules files with MANDATORY
        instructions, not slash commands. See KNOWLEDGE_BASE/CLINE_RULES_SYSTEM.md

For more information, see: https://github.com/nbiish/ainish-coder
EOF
}

show_version() {
    echo "ainish-coder v1.0.0"
    echo "Configuration Manager for AI Coding Assistants"
    echo "Copyright © 2025 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ"
}
