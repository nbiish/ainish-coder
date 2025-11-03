#!/bin/bash
# Quick Setup - Choose your preferred secret protection method

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Secret Protection Setup for ainish-coder              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

PS3='Select your preferred method: '
options=("git-secrets (Recommended - Local Protection)" "Manual Sanitization Script" "GitHub Actions Only" "All of the Above" "Skip Setup")
select opt in "${options[@]}"
do
    case $opt in
        "git-secrets (Recommended - Local Protection)")
            echo -e "${GREEN}Installing git-secrets...${NC}"
            ./.git-secrets-setup.sh
            break
            ;;
        "Manual Sanitization Script")
            echo -e "${GREEN}Manual sanitization ready!${NC}"
            echo -e "${YELLOW}Run './sanitize-settings.sh' before each commit${NC}"
            break
            ;;
        "GitHub Actions Only")
            echo -e "${GREEN}GitHub Actions already configured in .github/workflows/secret-scan.yml${NC}"
            echo -e "${YELLOW}Will scan on push/PR to GitHub${NC}"
            break
            ;;
        "All of the Above")
            echo -e "${GREEN}Installing complete protection...${NC}"
            ./.git-secrets-setup.sh
            echo -e "${GREEN}✅ All protection methods enabled!${NC}"
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
echo -e "2. If they contain secrets, run: ${YELLOW}./sanitize-settings.sh${NC}"
echo -e "3. Use the template at: ${YELLOW}CONFIGURATIONS/MCP/settings.json.template${NC}"
echo -e "4. Read the README: ${YELLOW}CONFIGURATIONS/MCP/README.md${NC}"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
