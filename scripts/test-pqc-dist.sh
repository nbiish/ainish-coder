#!/usr/bin/env bash
# test-pqc-dist.sh — hermetic proof for `--pqc-install` / `--pqc-status` /
# `--pqc-sync-targets` and the per-repo selection guard they depend on.
#
# Every run gets a throwaway $HOME, two fake target repos (one with the pack
# selected, one deselected) and a dead registry entry, so the operator's real
# store, launcher and fleet registry are never touched.
#
# Requires uv (the engine's declared dependencies are resolved by `uv run`).
# Usage: bash scripts/test-pqc-dist.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${REPO}/bin/ainish-coder"
PASS=0
FAIL=0
SKIP=0

if ! command -v uv >/dev/null 2>&1; then
    echo "SKIP: uv is required to resolve the engine's dependencies"
    exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pqc-dist-test.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

HOME_DIR="${WORK}/home"
TARGET_ON="${WORK}/target-on"
TARGET_OFF="${WORK}/target-off"
TARGET_MISSING="${WORK}/target-missing"
TARGET_BARE="${WORK}/target-bare"
mkdir -p "${HOME_DIR}/.config/ainish-coder" "$TARGET_ON/.agents/skills" "$TARGET_ON/bin" \
    "$TARGET_OFF/.agents/skills" "$TARGET_OFF/bin" "$TARGET_BARE/.agents/skills"

# Normalisation used by the CLI itself, so fixture keys match real lookups.
# shellcheck disable=SC1090
source "${REPO}/src/skills_selection.sh"

printf '%s\n%s\n%s\n' "$TARGET_ON" "$TARGET_OFF" "$TARGET_MISSING" \
    > "${HOME_DIR}/.config/ainish-coder/targets.txt"
KEY_ON="$(skills_selection_repo_key "$TARGET_ON")"
KEY_OFF="$(skills_selection_repo_key "$TARGET_OFF")"
cat > "${HOME_DIR}/.config/ainish-coder/skills-selection.json" <<JSON
{"repos": {"${KEY_ON}": {"pqc-secrets": true}, "${KEY_OFF}": {"pqc-secrets": false}}}
JSON

run_cli() {
    # Signing is exercised by the real manifests; the hermetic test asserts the
    # attestation fields and must never touch the operator's signing key.
    env HOME="$HOME_DIR" AINISH_NO_TRACKING=true AINISH_NON_INTERACTIVE=true \
        PQC_SKIP_MANIFEST_SIGN=1 bash "$CLI" "$@" 2>&1
}

ok() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
not_ok() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
check() { # check <label> <actual> <expected>
    if [[ "$2" == "$3" ]]; then ok "$1"; else not_ok "$1 (got '$2', want '$3')"; fi
}
contains() { # contains <label> <haystack> <needle>
    if [[ "$2" == *"$3"* ]]; then ok "$1"; else not_ok "$1 (missing '$3')"; fi
}

# Minimal JSON field reader (string or scalar). Fields may live on a nested
# one-line object (e.g. "summary": {...}), so the match is not line-anchored.
jget() {
    sed -n "s/.*\"$1\":[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p; s/.*\"$1\":[[:space:]]*\\(true\\|false\\|[0-9][0-9]*\\).*/\\1/p" "$2" \
        | head -n 1
}

# First occurrence on the line (jget is greedy and would read the last target).
jget_first() {
    grep -o "\"$1\": \"[^\"]*\"" "$2" | head -n 1 | sed 's/.*": "//; s/"$//'
}

echo "== selection guard =="
# shellcheck disable=SC1090
source "${REPO}/src/skills_selection.sh"
check "selected pack resolves on" "$(HOME="$HOME_DIR" skills_selection_state "$TARGET_ON" pqc-secrets)" "on"
check "deselected pack resolves off" "$(HOME="$HOME_DIR" skills_selection_state "$TARGET_OFF" pqc-secrets)" "off"

echo "== skill-selection contract (regression: --rules lost its selector) =="
# Unrecorded packs must default OFF, a repo must report whether it has been
# asked, and a headless/CI run must never prompt.
UNRECORDED="${WORK}/target-unrecorded"
mkdir -p "${UNRECORDED}/.agents/skills"
check "unrecorded pack defaults off" "$(HOME="$HOME_DIR" skills_selection_default_on && echo on || echo off)" "off"
if HOME="$HOME_DIR" skills_selection_repo_recorded "$UNRECORDED"; then
    not_ok "fresh repo is not yet recorded"
else
    ok "fresh repo is not yet recorded"
fi
if HOME="$HOME_DIR" skills_selection_repo_recorded "$TARGET_ON"; then
    ok "repo with a saved pack is recorded"
else
    not_ok "repo with a saved pack is recorded"
fi
check "ui mode never prompts when headless" \
    "$(HOME="$HOME_DIR" AINISH_HEADLESS=true skills_selection_ui_mode)" "never"
check "ui mode honours an explicit request" \
    "$(HOME="$HOME_DIR" AINISH_SKILLS_PROMPT=always skills_selection_ui_mode)" "always"
check "ui mode honours an explicit opt-out" \
    "$(HOME="$HOME_DIR" AINISH_SKILLS_PROMPT=off skills_selection_ui_mode)" "never"
# A bounded idle read is what keeps an abandoned terminal from stalling a deploy.
check "selector idle timeout is bounded and non-zero" \
    "$(HOME="$HOME_DIR" AINISH_SKILLS_PROMPT_TIMEOUT=2 skills_selection_prompt_timeout)" "2"
check "invalid timeout falls back to the default" \
    "$(HOME="$HOME_DIR" AINISH_SKILLS_PROMPT_TIMEOUT=abc skills_selection_prompt_timeout)" "120"
# The first-contact decision itself: never on CI, yes on an interactive TTY.
if HOME="$HOME_DIR" AINISH_HEADLESS=true skills_selection_should_prompt "$UNRECORDED"; then
    not_ok "headless never asks on first contact"
else
    ok "headless never asks on first contact"
fi
if HOME="$HOME_DIR" AINISH_SKILLS_PROMPT=always skills_selection_should_prompt "$TARGET_ON"; then
    ok "explicit request asks even for a recorded repo"
else
    not_ok "explicit request asks even for a recorded repo"
fi
if HOME="$HOME_DIR" AINISH_SKILLS_PROMPT=always skills_selection_should_prompt "$UNRECORDED"; then
    ok "explicit request asks on first contact"
else
    not_ok "explicit request asks on first contact"
fi
# The report is the read-only surface operators and CI use to see the choice.
report_json="$(HOME="$HOME_DIR" AINISH_SKILLS_PROMPT=off bash "$CLI" --skills-list "$TARGET_ON" --json 2>/dev/null || true)"
contains "skills-list reports the recorded pack" "$report_json" '"pqc-secrets"'
contains "skills-list marks the repo recorded" "$report_json" '"recorded": true'
report_fresh="$(HOME="$HOME_DIR" bash "$CLI" --skills-list "$UNRECORDED" --json 2>/dev/null || true)"
contains "skills-list marks a fresh repo unrecorded" "$report_fresh" '"recorded": false'

echo "== --pqc-install =="
install_json="${WORK}/install.json"
run_cli --pqc-install --json --no-wsl > "$install_json"
check "install ok" "$(jget ok "$install_json")" "true"
check "launcher installed" "$(jget state "$install_json")" "installed"
# A fresh install has an identity but no bundle: bundles appear when the first
# secret is packed, so requiring one here would fail every clean install.
check "keygen produced an identity or found one" "$(jget keygen "$install_json")" "generated"
check "no secrets packed yet (bundle absent by design)" "$(jget bundleExists "$install_json")" "false"
[[ -x "${HOME_DIR}/.local/bin/pqc-secrets" ]] && ok "launcher is executable" || not_ok "launcher is executable"
[[ -s "${HOME_DIR}/.config/ainish-coder/pqc-root" ]] && ok "root marker written" || not_ok "root marker written"

installed_store="$(cd / && env HOME="$HOME_DIR" "${HOME_DIR}/.local/bin/pqc-secrets" store --json 2>/dev/null || true)"
contains "installed launcher resolves a store from /" "$installed_store" '"bundle"'
if [[ -f "${HOME_DIR}/.local/bin/pqc-secrets.cmd" || ! -d /c/Users ]]; then
    ok "windows launcher present when applicable"
else
    not_ok "windows launcher present when applicable"
fi

echo "== consolidation fixture =="
# A target that predates the merge still carries the standalone signature pack.
mkdir -p "${TARGET_ON}/.agents/skills/pqc-signatures-security"
printf "legacy\n" > "${TARGET_ON}/.agents/skills/pqc-signatures-security/SKILL.md"
# A pre-attestation deploy: signed manifest template without a pack digest.
mkdir -p "${TARGET_ON}/.agents"
cat > "${TARGET_ON}/.agents/ainish-deploy.json" <<'JSON'
{
  "format": "ainish-coder/rules-deploy/v1",
  "source_repo": "/tmp/source",
  "source_commit": "deadbeef",
  "source_agents_sha256": "0",
  "deployed_at": "2026-10-29T00:00:00Z"
}
JSON
pqc_packs=( "$REPO"/.agents/skills/pqc* )
check "source ships exactly one pqc pack" "${#pqc_packs[@]}" "1"

echo "== --pqc-sync-targets =="
sync_json="${WORK}/sync.json"
run_cli --pqc-sync-targets --all --json > "$sync_json"
check "one target synced" "$(jget synced "$sync_json")" "1"
check "deselected target skipped" "$(jget deselected "$sync_json")" "1"
check "missing target reported" "$(jget missing "$sync_json")" "1"
check "no failures" "$(jget failed "$sync_json")" "0"
check "legacy signature pack pruned" "$(jget legacyPruned "$sync_json")" "1"
check "manifest stamped with the pack digest" "$(jget_first manifest "$sync_json")" "stamped"
pack_digest="$(jget sourcePackSha256 "$sync_json")"
grep -q "\"source_pack_sha256\": \"${pack_digest}\"" "${TARGET_ON}/.agents/ainish-deploy.json" \
    && ok "manifest attests the source pack digest" || not_ok "manifest attests the source pack digest"
if [[ ! -d "${TARGET_ON}/.agents/skills/pqc-signatures-security" ]]; then
    ok "legacy pack removed from target"
else
    not_ok "legacy pack removed from target"
fi
if [[ -f "${TARGET_ON}/.agents/skills/pqc-secrets/references/signatures-security.md" ]]; then
    ok "merged signing reference distributed"
else
    not_ok "merged signing reference distributed"
fi
if [[ "$(find "${TARGET_ON}/.agents/skills" -maxdepth 1 -type d -name 'pqc*' | wc -l | tr -d ' ')" == "1" ]]; then
    ok "target keeps one pqc pack"
else
    not_ok "target keeps one pqc pack"
fi

source_sha="$(sed -n 's/^[[:space:]]*"sourceSha256":[[:space:]]*"\([^"]*\)".*/\1/p' "$sync_json" | head -n 1)"
target_engine="${TARGET_ON}/.agents/skills/pqc-secrets/scripts/pqc_secrets.py"
if command -v sha256sum >/dev/null 2>&1; then
    target_sha="$(sha256sum "$target_engine" | awk '{print $1}')"
else
    target_sha="$(shasum -a 256 "$target_engine" | awk '{print $1}')"
fi
check "target engine digest matches source" "$target_sha" "$source_sha"
[[ -x "${TARGET_ON}/bin/pqc-secrets" ]] && ok "launcher copied with the pack" || not_ok "launcher copied with the pack"
[[ ! -e "${TARGET_OFF}/bin/pqc-secrets" ]] && ok "deselected target untouched" || not_ok "deselected target untouched"

echo "== documentation-only drift =="
# The engine is untouched; only the merged reference changes. Freshness must be
# pack-level, otherwise the consolidation silently skips doc updates.
printf '\nlocal drift marker\n' >> "${TARGET_ON}/.agents/skills/pqc-secrets/references/signatures-security.md"
run_cli --pqc-status --json --no-wsl > "${WORK}/drift-status.json"
drift_rc=$?
check "doc-only drift exits 1" "$drift_rc" "1"
check "doc-only drift is stale" "$(jget stale "${WORK}/drift-status.json")" "1"
run_cli --pqc-sync-targets --all --json > "${WORK}/repair.json"
check "doc-only drift re-synced" "$(jget synced "${WORK}/repair.json")" "1"
if cmp -s "${TARGET_ON}/.agents/skills/pqc-secrets/references/signatures-security.md" \
          "${REPO}/.agents/skills/pqc-secrets/references/signatures-security.md"; then
    ok "reference restored byte-for-byte"
else
    not_ok "reference restored byte-for-byte"
fi

run_cli --pqc-sync-targets --all --json > "${WORK}/sync2.json"
check "second sync is a no-op" "$(jget current "${WORK}/sync2.json")" "1"
check "second sync reuses the attested manifest" "$(jget_first manifest "${WORK}/sync2.json")" "attested"

echo "== --pqc-status =="
run_cli --pqc-status --json --no-wsl > "${WORK}/status.json"
status_rc=$?
check "status exits 0 when only optional packs are missing" "$status_rc" "0"
check "target reports current" "$(jget current "${WORK}/status.json")" "1"
check "deselected target is not a required miss" "$(jget missingRequired "${WORK}/status.json")" "0"
check "status reports no legacy packs" "$(jget legacyPacks "${WORK}/status.json")" "0"
check "status binds the pack to the signed manifest" "$(jget_first packAuth "${WORK}/status.json")" "bound"

# A selected target with no vendored engine must fail the check closed.
printf '{"repos": {"%s": {"pqc-secrets": true}}}\n' "$(skills_selection_repo_key "$TARGET_BARE")" \
    > "${HOME_DIR}/.config/ainish-coder/skills-selection.json"
printf '%s\n' "$TARGET_BARE" > "${HOME_DIR}/.config/ainish-coder/targets.txt"
run_cli --pqc-status --json --no-wsl > "${WORK}/status-missing.json"
status_rc=$?
check "status exits 1 for a required target without an engine" "$status_rc" "1"
check "missingRequired counts it" "$(jget missingRequired "${WORK}/status-missing.json")" "1"

echo ""
if (( FAIL > 0 )); then
    echo "FAILED: ${FAIL} assertion(s), ${PASS} passed"
    exit 1
fi
echo "PASS: ${PASS} assertion(s)"
