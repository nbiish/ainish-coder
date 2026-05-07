#!/bin/bash
# Help and usage information

show_help() {
    cat << 'EOF'
ainish-coder - Configuration Manager for AI Coding Assistants

USAGE:
    ainish-coder [COMMAND] [ARGS...] [TARGET_DIR]

CORE COMMANDS:
    --rules [TARGET_DIR]      Deploy AGENTS.md, llms.txt/ directory, and .gitignore
    --agents [TARGET_DIR]     Deploy AGENTS.md only (universal AI agent standard)
    --secure [DIR]            Deploy AGENTS_LLM_SECURITY.md and AGENTS_CODE_SECURITY.md


TOOL-SPECIFIC CONFIGURATION:
    Each tool deployment now includes:
    • AGENTS.md (core rules)
    • Tool-specific commands/workflows/recipes
    • Ignore files for context optimization
    
    --claude [TARGET_DIR]     Deploy Claude Code - rules, commands, skills (skill-creator,
                              agent-creator for creating custom skills/agents), agents, MCP
    --copilot [TARGET_DIR]    Deploy GitHub Copilot to .github/instructions/
    --pi [TARGET_DIR]         Deploy Pi Coding Agent - extensions, agents, skills, themes

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

CUSTOM COMMANDS DEPLOYMENT:
    --commands {tool} [DIR]   Deploy slash commands/workflows for AI tools
                              
                              Other:
                              - copilot     (use --copilot flag instead)
                              - all         (deploy to all applicable tools)
                              
                              Example: ainish-coder --commands all

UTILITY COMMANDS:
    --critical [TARGET_DIR]   Deploy critical.md (Critical protocols)
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

    --scrolls [TARGET_DIR]    Deploy .scrolls directory (Vital texts & prompts)
                              Deploys:
                              - .scrolls/ (Vital texts, expanded prompts)
                              
                              Example: ainish-coder --scrolls ~/my-project

    --skills [TARGET_DIR]     Deploy all skills from .agents/skills/ directory
                              Deploys:
                              - .agents/skills/osa/         (Multi-agent orchestration)
                              - .agents/skills/skyvern/     (AI browser automation)
                              - .agents/skills/llm-security/ (LLM & agentic AI security)
                              - .agents/skills/code-security/ (Safety-critical code engineering)
                              - .agents/skills/anishinaabe-cyberpunk-style/ (Cultural aesthetic rules)
                              - .agents/skills/modern-prompting/ (OOReDAct advanced prompting)

                              Example: ainish-coder --skills ~/my-project

    --signals [TARGET_DIR]    Deploy Signals Detection Reference (Expert RF guide)
                              Deploys:
                              - .signals/signals.md (WiFi & BLE surveillance detection)

                              Features:
                              - RF signal fundamentals & spectrum analysis
                              - WiFi promiscuous mode detection techniques
                              - BLE advertisement scanning & fingerprinting
                              - Flock Safety, Raven/ShotSpotter detection patterns
                              - ESP32-S3 implementation guidance
                              - Kismet, Scapy, RTL-SDR integration

                              Example: ainish-coder --signals ~/my-project

    --llms-txt [TARGET_DIR]   Deploy llms.txt directory
                              Deploys:
                              - llms.txt/ (PRD, RULES, TODO)

                              Example: ainish-coder --llms-txt ~/my-project

    --mcp-recipes [DIR]       Deploy MCP recipes (e.g., Tavily CLI templates)
                              Deploys markdown templates to mcp_recipes/ in target directory.
                              Example: ainish-coder --mcp-recipes ~/my-project

IGNORE FILE DEPLOYMENT:
    --copilot-ignore [DIR]    Deploy .copilotignore for GitHub Copilot
    --all-ignores [DIR]       Deploy all ignore files at once
                              
                              Ignore files help AI tools focus on relevant code by
                              excluding dependencies, build artifacts, and sensitive files.

OTHER:
    --help, -h                Show this help message
    --version, -v             Show version information

NOTES:
    - TARGET_DIR defaults to current directory if not provided
    - --rules deploys AGENTS.md + llms.txt/ directory + .gitignore
    - --secure deploys AGENTS_LLM_SECURITY.md + AGENTS_CODE_SECURITY.md
    - Tool deployments include ALL configurations (rules + commands/recipes + ignores)
    - Run --rules first before tool-specific deployments

EXAMPLES:
    # Recommended workflow - deploy core rules first
    ainish-coder --rules                    # Deploy to current directory
    ainish-coder --rules ~/my-project       # Deploy to specific directory
    
    # Tool-specific deployments
    ainish-coder --rules                    # Deploy AGENTS.md + llms.txt/ + .gitignore

    # Deploy tool configurations (requires AGENTS.md first)
    ainish-coder --claude                   # Deploy to current directory
    ainish-coder --pi /path/to/project
    
    # Deploy custom commands
    ainish-coder --commands claude          # Deploy slash commands

    # Utility deployments
    ainish-coder --gitignore                # Create comprehensive .gitignore
    ainish-coder --local-security           # Deploy local-only secret protection
    ainish-coder --github-actions           # Deploy CI/CD secret protection
    
    # Deploy ignore files for AI tools
    ainish-coder --all-ignores              # Deploy all ignore files

For more information, see: https://github.com/nbiish/ainish-coder
EOF
}

show_version() {
    echo "ainish-coder v1.0.0"
    echo "Configuration Manager for AI Coding Assistants"
    echo "Copyright © 2025 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ"
}
