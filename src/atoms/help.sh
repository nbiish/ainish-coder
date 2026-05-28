#!/bin/bash
# Help and usage information

show_help() {
    cat << 'EOF'
ainish-coder - Configuration Manager for AI Coding Assistants

USAGE:
    ainish-coder [COMMAND] [ARGS...] [TARGET_DIR]
    ainish-coder --cli                       (interactive menu)

INTERACTIVE MODE:
    --cli                   Launch interactive CLI menu to pick a tool, pick a
                            provider, verify configs, and hot-swap. Reads providers
                            from ~/.config/ainish-coder/providers.json.

                            Menu options:
                              - Pick a tool + provider → hot-swap & launch
                              - Verify config files for any/all tools
                              - Show provider ↔ tool compatibility matrix
                              - View provider details and which config files are modified

CORE COMMANDS:
    --rules [TARGET_DIR]      Deploy AGENTS.md and .gitignore
    --agents [TARGET_DIR]     Deploy AGENTS.md only (universal AI agent standard)
    --secure [DIR]            Deploy AGENTS_CODE_SECURITY.md and AGENTS_LLM_SECURITY.md
                              (files must exist in the ainish-coder repo root)


TOOL-SPECIFIC CONFIGURATION:
    All tool-specific configs have been consolidated into .agents/skills/.
    Use --rules to deploy AGENTS.md + .gitignore.
    Use --llms-txt to deploy llms.txt.
    Use --skills to deploy all skill packs.

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
                              Deploys 18 skill packs:
                              - advisory-council/          (Multi-expert advisory council)
                              - anishinaabe-cyberpunk-style/ (Cultural aesthetic rules)
                              - browser-harness/           (CDP browser automation)
                              - camofox-stack/             (Anti-detection browser stack)
                              - code-security/             (Safety-critical code engineering)
                              - ghost-layer-injector/      (Covert AI context injection)
                              - gstack-coder/              (Multi-tool coding orchestration)
                              - llm-security/              (LLM & agentic AI security)
                              - modern-prompting/          (OOReDAct advanced prompting)
                              - omni-integrator/           (Recursive optimization pipeline)
                              - omni-knowledge-extractor/  (YouTube knowledge extraction)
                              - openscad-generator/        (Parametric 3D model generation)
                              - osa/                       (Multi-agent orchestration)
                              - pi/                        (Pi Coding Agent expertise)
                              - pliny-research/            (AI transparency research)
                              - production-security/       (Core security policies & PQC)
                              - remotion-video/            (Programmatic video creation)
                              - skyvern/                   (AI browser automation)

                              Example: ainish-coder --skills ~/my-project

    --unlock [TARGET_DIR]     Deploy Pliny Research collection (AI transparency)
                              Deploys:
                              - .agents/skills/pliny-research/SKILL.md (Skill documentation)
                              - pliny-research/CL4R1T4S/  (System prompt extractions)
                              - pliny-research/L1B3RT4S/  (Liberation techniques)
                              - pliny-research/G0DM0D3/   (Advanced jailbreak methods)
                              - pliny-research/OBLITERATUS/ (Refusal removal research)

                              Example: ainish-coder --unlock ~/my-project

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

    --llms-txt [TARGET_DIR]   Deploy llms.txt file
                              Deploys:
                              - llms.txt (project context template)

                              Example: ainish-coder --llms-txt ~/my-project

    --mcp-recipes [DIR]       Deploy MCP recipes (e.g., Tavily CLI templates)
                              Deploys markdown templates to mcp_recipes/ in target directory.
                              Example: ainish-coder --mcp-recipes ~/my-project

PROVIDER-SWITCHING WRAPPERS:
    pi <provider> [args...]      Run pi coding agent with a provider
    mini <provider> [args...]    Run mini-swe-agent with a provider

    Providers: openrouter, zenmux, zai, nvidia, wafer, opencode, kimi

    The wrapper injects the right provider config (API key, base URL,
    default model) from ~/.config/ainish-coder/providers.json.
    Pass --model or -m to override the default model.

    No provider arg = passthrough to the real binary.

    Provider compatibility:
                  OpenRouter   ZenMux   ZAI   NVIDIA   Wafer   OpenCode   Kimi
        pi            ✓          ✓       ✓      ✓        ✓        ✓         ✓
        mini          ✓          ✓       ✓      ✓        ✓        ✓         ✓

    Examples:
        pi openrouter                    # deepseek-v4-pro via openrouter
        pi zai "fix the bug"             # glm-5.1 via ZAI coding plan
        mini openrouter -t "fix tests"   # deepseek-v4-pro via openrouter
        pi nvidia                        # Llama-3.1 via NVIDIA NIM
        mini opencode -t "run tests"     # Kimi-k2.6 via OpenCode Go

OTHER:
    --help, -h                Show this help message
    --version, -v             Show version information

NOTES:
    - TARGET_DIR defaults to current directory if not provided
    - --rules deploys AGENTS.md + .gitignore
    - --llms-txt deploys llms.txt (separate from --rules)
    - --secure deploys AGENTS_CODE_SECURITY.md + AGENTS_LLM_SECURITY.md
    - All tool-specific flags consolidated into .agents/skills/
    - Provider API keys stored in ~/.config/ainish-coder/providers.json

EXAMPLES:
    # Recommended workflow - deploy core rules first
    ainish-coder --rules                    # Deploy to current directory
    ainish-coder --rules ~/my-project       # Deploy to specific directory

    # Tool-specific deployments
    ainish-coder --rules                    # Deploy AGENTS.md + .gitignore

    # Deploy tool configurations (requires AGENTS.md first)
    # (No tools currently have standalone configs outside of agents system)

    # Deploy custom commands
    # (Commands logic now handled by agent skills)

    # Utility deployments
    ainish-coder --gitignore                # Create comprehensive .gitignore
    ainish-coder --local-security           # Deploy local-only secret protection
    ainish-coder --github-actions           # Deploy CI/CD secret protection

    ainish-coder --skills                    # Deploy all skill packs
    ainish-coder --unlock                   # Deploy Pliny Research collection

For more information, see: https://github.com/nbiish/ainish-coder
EOF
}

show_version() {
    echo "ainish-coder v1.0.0"
    echo "Configuration Manager for AI Coding Assistants"
    echo "Copyright © 2025 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ"
}
