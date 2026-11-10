#!/usr/bin/env bash
# Hermetic check for the repo-local deny-list guard in src/deploy_rules_sync.sh.
# Verifies that a manifest naming .agents/rag or .agents/wiki is refused, and that a clean
# manifest passes through unchanged.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source the module itself rather than extracting function bodies by text: extraction is brittle
# (a nested brace ends the slice) and a partial definition fails in a way that looks like a guard
# bug. A stub REPO_DIR points at the real tree and AINISH_* switches keep it inert — sourcing only
# defines functions here; nothing is deployed until one is called.
REPO_DIR="$REPO_ROOT"
export AINISH_SKILLS_PROMPT=off
export AINISH_HEADLESS=true
export AINISH_NON_INTERACTIVE=true
# shellcheck disable=SC1091
source "${REPO_ROOT}/src/deploy_rules_sync.sh" 2>/dev/null || {
    echo "FAIL: could not source src/deploy_rules_sync.sh" >&2
    exit 1
}
if ! declare -F _ainish_rules_assert_no_repo_local_paths >/dev/null 2>&1; then
    echo "FAIL: _ainish_rules_assert_no_repo_local_paths is not defined" >&2
    exit 1
fi

fail=0

clean='{"managed_paths":["AGENTS.md",".agents/skills",".agents/comms"]}'
if printf '%s' "$clean" | _ainish_rules_assert_no_repo_local_paths >/dev/null 2>&1; then
    echo "PASS clean manifest accepted"
else
    echo "FAIL clean manifest was refused"
    fail=1
fi

# A prefix violation: the index directory itself.
dirty_rag='{"managed_paths":["AGENTS.md",".agents/rag/lancedb"]}'
if printf '%s' "$dirty_rag" | _ainish_rules_assert_no_repo_local_paths >/dev/null 2>&1; then
    echo "FAIL .agents/rag/lancedb was accepted"
    fail=1
else
    echo "PASS .agents/rag prefix refused"
fi

# An exact violation.
dirty_wiki='{"managed_paths":[".agents/wiki"]}'
if printf '%s' "$dirty_wiki" | _ainish_rules_assert_no_repo_local_paths >/dev/null 2>&1; then
    echo "FAIL .agents/wiki was accepted"
    fail=1
else
    echo "PASS .agents/wiki refused"
fi

# Every declared repo-local path must be refused, or the list and the guard disagree.
while IFS= read -r p; do
    [ -n "$p" ] || continue
    if printf '{"managed_paths":["%s"]}' "$p" | _ainish_rules_assert_no_repo_local_paths >/dev/null 2>&1; then
        echo "FAIL declared repo-local path was accepted: $p"
        fail=1
    fi
done < <(_ainish_rules_repo_local_paths)
[ "$fail" -eq 0 ] && echo "PASS every declared repo-local path is refused"

# The declaration block itself must not trip the guard. This is the regression that shipped once:
# the guard scanned the whole manifest, found `repo_local_paths`'s own entries, and refused every
# valid deploy with "managed_paths must not distribute repo-local state".
full_manifest='{"managed_paths":["AGENTS.md",".agents/skills"],"repo_local_paths":[".agents/rag",".agents/wiki"]}'
if printf '%s' "$full_manifest" | _ainish_rules_assert_no_repo_local_paths >/dev/null 2>&1; then
    echo "PASS repo_local_paths declaration does not trip the guard"
else
    echo "FAIL the guard scans beyond managed_paths"
    fail=1
fi

# The shipped manifest template must itself satisfy the guard: apply the same bracket-matching
# extraction to the heredoc the writer actually emits.
actual_manifest="$(sed -n '/^_ainish_rules_manifest_write()/,/^}$/p' "${REPO_ROOT}/src/deploy_rules_sync.sh")"
managed_block="$(_ainish_rules_managed_paths_block "$actual_manifest")"
if [ -z "$managed_block" ]; then
    echo "FAIL could not locate managed_paths in the manifest writer"
    fail=1
elif printf '%s' "$managed_block" | _ainish_rules_assert_no_repo_local_paths >/dev/null 2>&1; then
    echo "PASS manifest writer does not distribute repo-local state"
else
    echo "FAIL the manifest writer names repo-local state in managed_paths"
    fail=1
fi

exit "$fail"
