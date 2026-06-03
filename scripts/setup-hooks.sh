#!/usr/bin/env bash

set -euo pipefail

# Support worktrees: use git's actual hooks directory
HOOKS_DIR="$(git rev-parse --git-dir)/hooks"
mkdir -p "$HOOKS_DIR"
REPO_ROOT="$(git rev-parse --show-toplevel)"
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

# Install post-merge and post-checkout hooks for AGENTS.md auto-sync
AGENTS_SYNC_HOOK="${HOOKS_DIR}/post-merge"
AGENTS_CHECKOUT_HOOK="${HOOKS_DIR}/post-checkout"
SYNC_SCRIPT="${REPO_ROOT}/scripts/hooks/agents-md-sync.sh"

if [[ -f "$SYNC_SCRIPT" ]]; then
    cp "$SYNC_SCRIPT" "$AGENTS_SYNC_HOOK"
    cp "$SYNC_SCRIPT" "$AGENTS_CHECKOUT_HOOK"
    chmod +x "$AGENTS_SYNC_HOOK" "$AGENTS_CHECKOUT_HOOK"
    echo "✅ post-merge hook installed (AGENTS.md auto-sync)"
    echo "✅ post-checkout hook installed (AGENTS.md auto-sync)"
else
    echo "⚠️  agents-md-sync.sh not found at $SYNC_SCRIPT — skipping AGENTS.md hooks"
fi

echo "✅ Git hooks configured successfully!"
echo "From now on, secrets will be blocked locally before they can be pushed."
echo "   AGENTS.md global symlinks will auto-sync on merge/checkout."
