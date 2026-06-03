#!/usr/bin/env bash
# post-merge / post-checkout hook: auto-sync AGENTS.md global symlinks
# Ensures ~/.agents/AGENTS.md and ~/.config/AGENTS.md always point to the
# canonical AGENTS.md in the ainish-coder repo after pulls and checkouts.
#
# Install: cp scripts/hooks/agents-md-sync.sh .git/hooks/post-merge
#          cp scripts/hooks/agents-md-sync.sh .git/hooks/post-checkout
#          chmod +x .git/hooks/post-merge .git/hooks/post-checkout
# Or run:  scripts/setup-hooks.sh (installs all hooks including this one)

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
    exit 0
fi

AGENTS_SOURCE="${REPO_ROOT}/AGENTS.md"

# Only act if AGENTS.md exists in the repo
if [[ ! -f "$AGENTS_SOURCE" ]]; then
    exit 0
fi

# For post-merge: check if AGENTS.md was part of the merge diff
# For post-checkout: always re-validate (branch may have different AGENTS.md)
HOOK_NAME="$(basename "$0")"
if [[ "$HOOK_NAME" == "post-merge" ]]; then
    # $1 = squash flag (unused). Check if AGENTS.md changed in the merge.
    CHANGED_FILES="$(git diff-tree -r --name-only --no-commit-id HEAD 2>/dev/null || true)"
    if ! echo "$CHANGED_FILES" | grep -qxF "AGENTS.md"; then
        exit 0  # AGENTS.md not part of this merge — nothing to do
    fi
fi

# Re-create global symlinks pointing to the repo's AGENTS.md
SYNC_COUNT=0
for dest in "$HOME/.agents/AGENTS.md" "$HOME/.config/AGENTS.md"; do
    dest_dir="$(dirname "$dest")"
    mkdir -p "$dest_dir"

    # Already a correct symlink — skip
    if [[ -L "$dest" && "$(readlink "$dest")" == "$AGENTS_SOURCE" ]]; then
        continue
    fi

    # Existing regular file — back it up
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        mv "$dest" "${dest}.backup.$(date +%Y%m%d%H%M%S)"
    fi

    # Remove stale symlink if target changed
    rm -f "$dest"
    ln -s "$AGENTS_SOURCE" "$dest"
    SYNC_COUNT=$((SYNC_COUNT + 1))
done

if [[ $SYNC_COUNT -gt 0 ]]; then
    echo "🔗 AGENTS.md global symlinks re-synced ($SYNC_COUNT updated)"
fi
