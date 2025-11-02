#!/bin/bash
# Help and usage information

show_help() {
    cat << 'EOF'
ainish-coder - Configuration Manager for AI Coding Assistants

USAGE:
    ainish-coder [COMMAND] [ARGS...] [TARGET_DIR]

CORE COMMANDS:
    --rules [TARGET_DIR]      Deploy AGENTS.md AND MAIRULES.md (recommended)
    --agents [TARGET_DIR]     Deploy AGENTS.md only (universal AI agent standard)
    --mairules [TARGET_DIR]   Deploy MAIRULES.md only (concatenates all tiers)
    
TIER DEPLOYMENT:
    --tier {0-4} [TARGET_DIR] Deploy specific tier to MAIRULES.md
    --tier0 [TARGET_DIR]      Deploy TIER_0 (Documentation protocols)
    --tier1 [TARGET_DIR]      Deploy TIER_1 (Code security)
    --tier2 [TARGET_DIR]      Deploy TIER_2 (Prompt security)
    --tier3 [TARGET_DIR]      Deploy TIER_3 (Cultural styling)
    --tier4 [TARGET_DIR]      Deploy TIER_4 (Advanced prompting)

TOOL-SPECIFIC CONFIGURATION:
    --cursor [TARGET_DIR]     Deploy Cursor AI configuration to .cursor/rules/
    --windsurf [TARGET_DIR]   Deploy Windsurf configuration to .windsurf/rules/
    --cline [TARGET_DIR]      Deploy Cline configuration to .clinerules/
    --copilot [TARGET_DIR]    Deploy GitHub Copilot to .github/instructions/
    --continue [TARGET_DIR]   Deploy Continue Dev to .continue/rules/
    --cn [TARGET_DIR]         Alias for --continue
    --gemini [TARGET_DIR]     Deploy Gemini configuration to .gemini/
    --qwen [TARGET_DIR]       Deploy Qwen AI configuration to .qwen/
    --roocode [TARGET_DIR]    Deploy Roo Code configuration to .roo/rules/
    --roo [TARGET_DIR]        Alias for --roocode

CUSTOM COMMANDS DEPLOYMENT:
    --commands {tool}         Deploy tool-specific commands/workflows
                              Available: cursor, windsurf, cline, roo, continue
                              Example: ainish-coder --commands cursor

UTILITY COMMANDS:
    --critical [TARGET_DIR]   Deploy critical.md from TIER_0
    --gitignore [TARGET_DIR]  Deploy comprehensive .gitignore

OTHER:
    --goose                   [NOT YET IMPLEMENTED] Goose CLI setup
    --help, -h                Show this help message
    --version, -v             Show version information

NOTES:
    - TARGET_DIR defaults to current directory if not provided
    - Tier deployments APPEND to MAIRULES.md (they don't deploy to .mai-rules/)
    - --rules deploys BOTH AGENTS.md and MAIRULES.md for comprehensive coverage
    - Run --agents or --mairules first before tool-specific deployments

EXAMPLES:
    # Recommended workflow - deploy core rules first
    ainish-coder --rules                    # Deploy AGENTS.md + MAIRULES.md

    # Deploy specific tiers to MAIRULES.md
    ainish-coder --tier 1                   # Code security
    ainish-coder --tier 2                   # Prompt security
    ainish-coder --tier 0 /path/to/project  # Documentation to specific directory

    # Deploy tool configurations (requires AGENTS.md/MAIRULES.md first)
    ainish-coder --cursor                   # Deploy to current directory
    ainish-coder --windsurf /path/to/project
    
    # Deploy custom commands
    ainish-coder --commands cursor          # Deploy slash commands
    ainish-coder --commands windsurf        # Deploy workflows

    # Utility deployments
    ainish-coder --gitignore                # Create comprehensive .gitignore

For more information, see: https://github.com/nbiish/ainish-coder
EOF
}

show_version() {
    echo "ainish-coder v1.0.0"
    echo "Configuration Manager for AI Coding Assistants"
    echo "Copyright © 2025 ᓂᐲᔥ ᐙᐸᓂᒥᑮ-ᑭᓇᐙᐸᑭᓯ"
}
