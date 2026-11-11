#!/bin/bash
# Path utilities and constants

# Repository root directory (ainish-coder installation)
# This should be set by the main script that sources this file
if [[ -z "${REPO_DIR:-}" ]]; then
    # Try to detect it from the script location
    REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
export REPO_DIR

# ── Distributed skill payload ────────────────────────────────────────────────
# The packs this tool SHIPS live in one tree, separate from the packs THIS REPO'S
# agents read. Two constants, because the two paths are not interchangeable:
#
#   AINISH_SKILLS_SOURCE_REL  where the distributable payload lives in the
#                             checkout (the source of every deploy/sync/digest)
#   AINISH_SKILLS_TARGET_REL  where a consumer repo receives them (always
#                             .agents/skills/, because that is what agent
#                             harnesses discover in the repo being worked on)
#
# Keeping them distinct is the whole point of the split: this repository's own
# `.agents/skills/` holds only the few packs its agents must read, so agent
# tooling that auto-discovers `**/.agents/skills` does not load all 20+ packs as
# standing prompt surface.
AINISH_SKILLS_SOURCE_REL="skills-to-distribute/skills"
AINISH_SKILLS_TARGET_REL=".agents/skills"
export AINISH_SKILLS_SOURCE_REL AINISH_SKILLS_TARGET_REL

# ainish_skills_source_root [repo_root] — absolute path of the distributable
# payload. Fails when the tree is absent so callers can report a packaging
# error instead of silently deploying nothing.
ainish_skills_source_root() {
    local root="${1:-${REPO_DIR}}"
    local dir="${root}/${AINISH_SKILLS_SOURCE_REL}"
    [[ -d "$dir" ]] || return 1
    printf '%s\n' "$dir"
}

# ainish_skills_target_root <repo_root> — absolute path where a consumer repo
# receives the packs.
ainish_skills_target_root() {
    printf '%s\n' "${1:-.}/${AINISH_SKILLS_TARGET_REL}"
}

# Get the absolute path of the script directory
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
}

# Get the project root directory (ainish-coder repository root)
get_project_root() {
    echo "$REPO_DIR"
}

# Check if a path is absolute
is_absolute_path() {
    [[ "$1" = /* ]] && return 0 || return 1
}

# Convert relative path to absolute
to_absolute_path() {
    local path="$1"
    if is_absolute_path "$path"; then
        echo "$path"
    else
        echo "$(pwd)/$path"
    fi
}

# Ensure directory exists
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || return 1
    fi
    return 0
}
