#!/usr/bin/env bash
# post-merge / post-checkout hook: auto-refresh global AGENTS.md copies
# Ensures ~/.agents/AGENTS.md and ~/.config/AGENTS.md stay plain copies of
# the canonical AGENTS.md in the ainish-coder repo after pulls and checkouts.
# No symlinks are created: downstream/homedir files are independent copies so
# editing them can never touch the root contract.
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

# Re-sync global AGENTS.md copies (plain files, never symlinks)
SYNC_COUNT=0
for dest in "$HOME/.agents/AGENTS.md" "$HOME/.config/AGENTS.md"; do
    dest_dir="$(dirname "$dest")"
    mkdir -p "$dest_dir"

    # Already an up-to-date regular copy — skip
    if [[ -f "$dest" && ! -L "$dest" ]] && cmp -s "$AGENTS_SOURCE" "$dest" 2>/dev/null; then
        continue
    fi

    # Unlock destination if locked/read-only on macOS/Linux/Windows so mv/rm succeeds
    chflags nouchg "$dest" 2>/dev/null || true
    chmod u+w "$dest" 2>/dev/null || true

    # Existing customized regular file — back it up
    if [[ -f "$dest" && ! -L "$dest" ]]; then
        mv "$dest" "${dest}.backup.$(date +%Y%m%d%H%M%S)"
    fi

    # Remove stale file/legacy symlink (rm on a symlink removes the link only)
    rm -f "$dest"
    cp -f "$AGENTS_SOURCE" "$dest"
    SYNC_COUNT=$((SYNC_COUNT + 1))
done

if [[ $SYNC_COUNT -gt 0 ]]; then
    echo "📄 AGENTS.md global copies re-synced ($SYNC_COUNT updated)"
fi
