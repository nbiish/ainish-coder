#!/bin/bash
# Help and usage information

show_help() {
    cat << 'EOF'
ainish-coder - Configuration Manager for AI Coding Assistants

USAGE:
    ainish-coder [COMMAND] [TARGET_DIR]

COMMANDS:
    --agents TARGET_DIR       Deploy AGENTS.md (universal standard) - REQUIRED FIRST
    --rules TARGET_DIR        Alias for --agents
    --mairules TARGET_DIR     Deploy MAIRULES.md rules
    --critical TARGET_DIR     Deploy critical.md (LICENSE, etc.)
    --gitignore TARGET_DIR    Deploy comprehensive .gitignore

    --cursor TARGET_DIR       Deploy Cursor AI configuration
    --copilot TARGET_DIR      Deploy GitHub Copilot configuration  
    --cline TARGET_DIR        Deploy Cline configuration
    --windsurf TARGET_DIR     Deploy Windsurf configuration
    --cn TARGET_DIR           Deploy Continue Dev configuration
    --gemini TARGET_DIR       Deploy Gemini configuration
    --qwen TARGET_DIR         Deploy Qwen AI configuration
    --roocode TARGET_DIR      Deploy Roo Code configuration

    --commands ARG            Deploy commands configuration to ARG/commands
    --tier0 TARGET_DIR        Deploy TIER_0 rules
    --tier1 TARGET_DIR        Deploy TIER_1 rules  
    --tier2 TARGET_DIR        Deploy TIER_2 rules
    --tier3 TARGET_DIR        Deploy TIER_3 rules
    --tier4 TARGET_DIR        Deploy TIER_4 rules

    --install-global          Install global configurations
    --install-global-mai      Install MAI RULES globally
    --install-global-qwen     Install Qwen rules globally
    --install-global-gemini   Install Gemini rules globally
    --install-global-continue Install Continue rules globally

    --help, -h                Show this help message
    --version, -v             Show version information

EXAMPLES:
    # Deploy AGENTS.md (always do this first!)
    ainish-coder --agents /path/to/project

    # Deploy tool configurations
    ainish-coder --cursor /path/to/project
    ainish-coder --copilot /path/to/project

    # Deploy commands to specific location
    ainish-coder --commands /path/to/config

    # Deploy tiered rules
    ainish-coder --tier1 /path/to/project

For more information, see: https://github.com/nbiish/ainish-coder
EOF
}

show_version() {
    echo "ainish-coder v1.0.0"
    echo "Configuration Manager for AI Coding Assistants"
    echo "Copyright © 2025 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ"
}
