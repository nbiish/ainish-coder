#!/bin/bash
# Help and usage information

show_help() {
    cat << 'EOF'
ainish-coder - Configuration Manager for AI Coding Assistants

USAGE:
    ainish-coder [GLOBAL_FLAGS] [COMMAND] [ARGS...] [TARGET_DIR]

GLOBAL FLAGS:
    -n, --no-overwrite   Skip existing files; only add new ones (safe mode)
    -l, --link           Force symlink mode (now the default — use to override
                         any saved preference)
    -y, --yes            Non-interactive mode (skip all prompts; defaults to
                         symlink for single source of truth)

CORE COMMANDS:
    --rules [TARGET_DIR]      Deploy AGENTS.md (defaults to symlink — single source
                              of truth) and .gitignore (symlink or copy, your choice).
                              Also ensures global symlinks:
                                ~/.agents/AGENTS.md → repo AGENTS.md
                                ~/.config/AGENTS.md → repo AGENTS.md
    --agents [TARGET_DIR]     Deploy AGENTS.md only (defaults to symlink — single source
                              of truth).
                              Also ensures global symlinks:
                                ~/.agents/AGENTS.md → repo AGENTS.md
                                ~/.config/AGENTS.md → repo AGENTS.md
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
                              Deploys 19 skill packs:
                              - advisory-council/          (Multi-expert advisory council)
                              - anishinaabe-cyberpunk-style/ (Cultural aesthetic rules)
                              - browser-harness/           (CDP browser automation)
                              - camofox-stack/             (Anti-detection browser stack)
                              - code-security/             (Safety-critical code engineering)
                              - ghost-layer-injector/      (Covert AI context injection)
                              - gstack-coder/              (Multi-tool coding orchestration)
                              - llm-security/              (LLM & agentic AI security)
                              - modern-prompting/          (OOReDAct advanced prompting)
                              - document-enhancer/         (Knowledge fusion & document hardening)
                              - video-knowledge-extractor/ (YouTube video knowledge extraction)
                              - openscad-generator/        (Parametric 3D model generation)
                              - pliny-research/            (AI transparency research)
                              - pqc-secrets/               (PQC secrets: API key encryption, ML-KEM-768)
                              - pqc-signatures-security/   (PQC signatures: ML-DSA-65 code signing & integrity)
                              - production-security/       (Core security policies & PQC mandates)
                              - remotion-video/            (Programmatic video creation)
                              - skyvern/                   (AI browser automation)
                              - pi-mini-orchestrator/     (Pi+Mini orchestration with MCP scoping & provider fallback)

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

OTHER:
    --help, -h                Show this help message
    --version, -v             Show version information

ENVIRONMENT VARIABLES:
    AINISH_NON_INTERACTIVE=true   Equivalent to -y; skip all interactive prompts
    AINISH_NO_OVERWRITE=true      Equivalent to -n; skip existing files
    AINISH_LINK_MODE=true         Equivalent to -l; force symlink mode
    AINISH_NO_TRACKING=true       Disable usage tracking (cmd-tracker integration)
    AINISH_PROVIDERS=path         Override default ~/.config/ainish-coder/providers.json

NOTES:
    - TARGET_DIR defaults to current directory if not provided
    - Deployments default to symlink (single source of truth) — opt out at the prompt
    - --rules deploys AGENTS.md + .gitignore + global symlinks
    - --agents deploys AGENTS.md + global symlinks
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
    echo "ainish-coder v1.5.1"
    echo "Configuration Manager for AI Coding Assistants"
    echo "Copyright © 2025 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ"
}
