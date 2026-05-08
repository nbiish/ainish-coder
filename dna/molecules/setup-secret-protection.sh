#!/bin/bash
# Quick Setup - Choose your preferred secret protection method

set -euo pipefail

# Get script directory and root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source colors from atoms
source "$SCRIPT_DIR/../atoms/colors.sh"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Secret Protection Setup for ainish-coder              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

PS3='Select your preferred method: '
options=("git-secrets (Recommended - Local Protection)" "Manual Sanitization + Local Scan (No Hooks)" "Skip Setup")
select opt in "${options[@]}"
do
    case $opt in
        "git-secrets (Recommended - Local Protection)")
            echo -e "${GREEN}Installing git-secrets...${NC}"
            bash "$ROOT_DIR/.git-secrets-setup.sh"
            break
            ;;
        "Manual Sanitization + Local Scan (No Hooks)")
            echo -e "${GREEN}Manual sanitization + local scanning ready!${NC}"
            echo -e "${YELLOW}Before committing, run:${NC}"
            echo -e "  - ${CYAN}bash dna/atoms/sanitize-settings.sh${NC}"
            echo -e "  - ${CYAN}bash .github/scripts/scan_secrets.sh${NC}  ${YELLOW}(generates SECURITY_REPORT.md if issues found)${NC}"
            break
            ;;
        "Skip Setup")
            echo -e "${YELLOW}Skipped. You can run this again later.${NC}"
            break
            ;;
        *) echo -e "${RED}Invalid option $REPLY${NC}";;
    esac
done

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}📋 Next Steps:${NC}"
echo ""
echo -e "1. Review your current settings.json files for secrets"
echo -e "2. If they contain secrets, run: ${YELLOW}bash dna/atoms/sanitize-settings.sh${NC}"
echo -e "3. Configure your MCP server settings directly in your tool's config"
echo -e "4. See .agents/skills/llm-security/SKILL.md for MCP hardening guidance"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
