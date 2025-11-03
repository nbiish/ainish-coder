#!/bin/bash
# Quick Reference - Secret Protection Commands

cat << 'EOF'

╔═══════════════════════════════════════════════════════════════╗
║            🔒 SECRET PROTECTION - QUICK REFERENCE             ║
║                   🆕 NOW WITH GITHUB ACTIONS!                 ║
╚═══════════════════════════════════════════════════════════════╝

📦 SETUP (Run Once)
  ./setup-secret-protection.sh          # Interactive setup
  ./.git-secrets-setup.sh               # Just install git-secrets
  
🆕 GITHUB ACTIONS (Automatic!)
  auto-sanitize.yml                     # Auto-cleans on every push!
  detect-secrets.yml                    # Blocks PRs with secrets
  See: .github/workflows/README.md      # Full setup guide

🧹 BEFORE COMMITTING
  ./sanitize-settings.sh                # Clean all settings.json files
  git secrets --scan                    # Test if secrets would be caught

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
  • Local paths (/Volumes/1tb-sandisk/)
  • Generic API_KEY patterns
  • Passwords and secrets

╔═══════════════════════════════════════════════════════════════╗
║  🆕 TIP: GitHub Actions now auto-clean secrets on push!      ║
║  💡 But still use git-secrets locally for instant feedback!  ║
╚═══════════════════════════════════════════════════════════════╝

🎯 PROTECTION LAYERS:
  1️⃣ git-secrets (local)      → Blocks commits with secrets
  2️⃣ Pre-commit hook (local)  → Double-checks before push
  3️⃣ GitHub Actions (cloud)   → Auto-sanitizes after push
  
  = Three layers of protection! 🛡️🛡️🛡️

EOF
