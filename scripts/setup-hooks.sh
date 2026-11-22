#!/usr/bin/env bash

set -euo pipefail

# Hooks live in the COMMON git directory, not the per-worktree one.
#
# `git rev-parse --git-dir` inside a worktree returns `.git/worktrees/<name>`, and this script used to
# append `/hooks` to that — so it installed a hook git never looks at. Measured 2026-11-20: the
# worktree reported the hook as installed while `git rev-parse --git-path hooks/commit-msg` resolved
# to the MAIN checkout's hooks directory, and commits kept their trailers. `--git-common-dir` is the
# one directory every checkout of this repository shares, and it is where git actually runs hooks from.
HOOKS_DIR="$(git rev-parse --git-common-dir)/hooks"
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
  "/Volumes/[A-Za-z0-9._-]+/"
  "BRAVE_API_KEY.*[\"'][^\"']{10,}[\"']"
  "tavilyApiKey=[^&\"\\s]{10,}"
)

FOUND=0

for pattern in "${PATTERNS[@]}"; do
  # Grep recursively in the staged files.
  # Suppress errors, ignore test/template/setup files, and the setup script itself.
  # Signature artifacts (*.sig) are base64 ML-DSA-65 payloads: scanning them for
  # key-shaped substrings only yields false positives (e.g. "BSA" + 27 alnum chars
  # occurring by chance inside the signature), so they are excluded from the scan.
  staged_files=$(git diff --cached --name-only 2>/dev/null | grep -vE "^(scripts/setup-hooks\.sh|.*\.sig)$" || true)
  if [ -n "$staged_files" ]; then
    if echo "$staged_files" | while IFS= read -r file; do
        [ -f "$file" ] && [ ! -L "$file" ] && grep -HnE "$pattern" "$file" 2>/dev/null
    done | grep -vE "YOUR_[A-Z_]+_HERE|BSAtestkey|example|template|your-key-here|\$\{BRAVE_API_KEY\}"; then
      echo "❌ Found sensitive pattern: $pattern"
      FOUND=1
    fi
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
echo "   AGENTS.md global copies will auto-sync on merge/checkout."

# ── commit identity ─────────────────────────────────────────────────────────
# Two hooks, and the SPLIT between them is the whole point:
#
#   commit-msg   strips harness attribution BEFORE the commit object exists. Edit here is free — no
#                amend, no re-sign, no rewritten history.
#   post-commit  re-authors a commit whose AUTHOR is a harness. It has to amend, so it re-signs.
#
# Installing only the post-commit guard is what let 82 commits carry `Co-authored-by: Cursor`: the
# guard repairs the author and exits, and a correctly-authored commit with a dirty message was skipped
# entirely. Installing the strip first means the guard usually has nothing to amend.
#
# Both blocks are delimited by their OWN markers and replaced in place, so re-running this script is
# idempotent. The guard block previously deduplicated on the rules-sync marker, which is why one
# checkout accumulated 12 copies of it.
_install_block() {
    local hook_path="$1" start_marker="$2" end_marker="$3" block="$4"
    mkdir -p "$(dirname "$hook_path")" 2>/dev/null || return 1
    if [[ ! -f "$hook_path" ]]; then
        printf '#!/usr/bin/env bash\n\n%s\n' "$block" > "$hook_path"
    elif grep -qF "$start_marker" "$hook_path" 2>/dev/null; then
        local tmp="${hook_path}.tmp.$$"
        BLOCK="$block" START="$start_marker" END="$end_marker" awk '
            $0 == ENVIRON["START"] { inblock=1; printf "%s\n", ENVIRON["BLOCK"]; next }
            $0 == ENVIRON["END"]   { inblock=0; next }
            !inblock
        ' "$hook_path" > "$tmp" && mv "$tmp" "$hook_path"
    else
        printf '\n%s\n' "$block" >> "$hook_path"
    fi
    chmod +x "$hook_path" 2>/dev/null || true
}

STRIP_SCRIPT="${REPO_ROOT}/scripts/strip-harness-trailers.sh"
GUARD_SCRIPT="${REPO_ROOT}/scripts/commit-identity-guard.sh"

if [[ -x "$STRIP_SCRIPT" ]]; then
    printf -v _strip_q "'%s'" "$(printf '%s' "$STRIP_SCRIPT" | sed "s/'/'\\\\''/g")"
    _install_block "${HOOKS_DIR}/commit-msg" \
        "# --- AINISH-CODER IDENTITY STRIP START ---" \
        "# --- AINISH-CODER IDENTITY STRIP END ---" \
"# --- AINISH-CODER IDENTITY STRIP START ---
# Remove tool self-attribution before the commit object exists (AGENTS.md rule 4).
if [ -x ${_strip_q} ]; then
    ${_strip_q} \"\$1\" || true
fi
# --- AINISH-CODER IDENTITY STRIP END ---"
    echo "✅ commit-msg hook installed (strip harness attribution)"
else
    echo "⚠️  strip-harness-trailers.sh not found at $STRIP_SCRIPT — skipping the commit-msg hook"
fi

if [[ -x "$GUARD_SCRIPT" ]]; then
    printf -v _guard_q "'%s'" "$(printf '%s' "$GUARD_SCRIPT" | sed "s/'/'\\\\''/g")"
    _install_block "${HOOKS_DIR}/post-commit" \
        "# --- AINISH-CODER IDENTITY GUARD START ---" \
        "# --- AINISH-CODER IDENTITY GUARD END ---" \
"# --- AINISH-CODER IDENTITY GUARD START ---
if [ \"\${AINISH_IDENTITY_GUARD_ACTIVE:-0}\" != \"1\" ] && [ -x ${_guard_q} ]; then
    AINISH_IDENTITY_GUARD=on ${_guard_q} >/dev/null 2>&1 || true
fi
# --- AINISH-CODER IDENTITY GUARD END ---"
    echo "✅ post-commit hook installed (re-author harness commits)"
else
    echo "⚠️  commit-identity-guard.sh not found at $GUARD_SCRIPT — skipping the post-commit hook"
fi
