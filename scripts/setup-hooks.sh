#!/usr/bin/env bash

set -euo pipefail

HOOKS_DIR=".git/hooks"
PRE_COMMIT_HOOK="${HOOKS_DIR}/pre-commit"

echo "Setting up local Git hooks..."

# Create the pre-commit hook file
cat << 'EOF' > "$PRE_COMMIT_HOOK"
#!/usr/bin/env bash

# This hook performs a local secret scan before allowing a commit.
# It prevents sensitive data from ever leaving your machine.

set -e

echo "🔍 Running local secret scan (pre-commit hook)..."

# Define patterns based on the project's security rules
PATTERNS=(
  "BSA[a-zA-Z0-9]{27}"
  "tvly-[a-zA-Z0-9-]{30,}"
  "/Volumes/1tb-sandisk/"
  "BRAVE_API_KEY.*[\"'][^\"']{10,}[\"']"
  "tavilyApiKey=[^&\"\\s]{10,}"
)

FOUND=0

for pattern in "${PATTERNS[@]}"; do
  # Grep recursively in the staged files
  # Suppress errors, ignore test/template/setup files, and the setup script itself
  if git diff --cached --name-only -z | grep -zvE "scripts/setup-hooks.sh" | xargs -0 -r grep -HnE "$pattern" 2>/dev/null | grep -vE "YOUR_[A-Z_]+_HERE|BSAtestkey|example|template|your-key-here|\$\{BRAVE_API_KEY\}"; then
    echo "❌ Found sensitive pattern: $pattern"
    FOUND=1
  fi
done

if [ $FOUND -eq 1 ]; then
  echo ""
  echo "⚠️  Secrets detected in your staged changes!"
  echo "Please remove the secrets, or run 'python3 .github/scripts/sanitize.py <file>' locally."
  echo "Commit aborted."
  exit 1
fi

echo "✅ No secrets detected. Proceeding with commit."
EOF

# Make it executable
chmod +x "$PRE_COMMIT_HOOK"

echo "✅ Git hooks configured successfully!"
echo "From now on, secrets will be blocked locally before they can be pushed."
