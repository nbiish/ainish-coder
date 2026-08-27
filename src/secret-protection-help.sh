#!/bin/bash
# Quick Reference - Secret Protection Commands

set -euo pipefail

cat << 'EOF'

╔═══════════════════════════════════════════════════════════════╗
║            🔒 SECRET PROTECTION - QUICK REFERENCE             ║
╚═══════════════════════════════════════════════════════════════╝

📦 SETUP (Run Once)
  ./setup-secret-protection.sh          # Interactive setup
  ./.git-secrets-setup.sh               # Just install git-secrets

🧹 BEFORE COMMITTING
  ./sanitize-settings.sh                # Clean all settings.json files (always safe to run)
  git secrets --scan                    # Test if secrets would be caught

🔍 LOCAL SCAN (Generates a report for your LLM)
  bash .github/scripts/scan_secrets.sh  # Generates SECURITY_REPORT.md if issues are found

🔍 SCANNING
  git secrets --scan <file>             # Scan specific file
  git secrets --scan-history            # Scan entire git history
  git secrets --list                    # Show configured patterns

🚨 IF BLOCKED
  # Review what was caught
  git diff CONFIGURATIONS/

  # Fix secrets, then commit normally
  git add .
  git commit -m "your message"

  # Emergency bypass (USE WITH CAUTION!)
  git commit --no-verify -m "message"

📝 TEMPLATES
  CONFIGURATIONS/MCP/settings.json.template    # Safe template to copy

📚 DOCUMENTATION
  CONFIGURATIONS/MCP/README.md                 # Full setup guide
  KNOWLEDGE_BASE/SECRET_PROTECTION_SETUP.md    # Implementation details

🔧 TROUBLESHOOTING
  # git-secrets not working?
  brew install git-secrets
  git secrets --install -f

  # Hook not running?
  chmod +x .git/hooks/pre-commit

  # Want to remove a pattern?
  git secrets --remove-pattern 'pattern'

🎯 DETECTED PATTERNS
  • Brave API keys (BSA...)
  • Tavily API keys (tvly-dev-...)
    • Local paths (/Volumes/<volume>/)
  • Generic API_KEY patterns
  • Passwords and secrets

EOF
