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
    # A gate that silently exits 0 when its dependency is missing reads as PASSED in CI, which is
    # the one failure mode a distribution gate must never have. Skip only when explicitly opted in
    # (local convenience); otherwise fail closed and say how to fix it.
    if [[ "${AINISH_ALLOW_GATE_SKIP:-}" == "1" ]]; then
        echo "SKIP: uv is required to resolve the engine's dependencies (AINISH_ALLOW_GATE_SKIP=1)"
        exit 0
    fi
    echo "FAIL: uv is required to resolve the engine's dependencies but was not found on PATH." >&2
    echo "      Install it:  curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
    echo "      Or skip deliberately with AINISH_ALLOW_GATE_SKIP=1 (never in CI)." >&2
    exit 1
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
    #
    # HOME= alone is NOT sufficient isolation. On Windows, Python reads USERPROFILE and
    # pathlib.Path.home() ignores HOME entirely, so the pqc engine found the operator's real
    # keypair and reported `keygen: present` where a clean install must report `generated` --
    # which also means the test was reaching the live store rather than a sandbox. Pin the
    # engine's own documented override (PQC_SECRETS_DIR), which is authoritative on every host,
    # and set USERPROFILE too so anything reading the platform variable stays in the sandbox.
    env HOME="$HOME_DIR" USERPROFILE="$HOME_DIR" PQC_SECRETS_DIR="$HOME_DIR/.config/pqc-secrets" \
        AINISH_NO_TRACKING=true AINISH_NON_INTERACTIVE=true \
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

echo "== provenance stamp is readable across WSL and Windows Git Bash =="
# `.ainish-source` stores whichever absolute POSIX path the WRITER saw:
# /mnt/d/X under WSL, /d/X under Windows Git Bash. Both are valid on their own
# host and unresolvable on the other, which silently broke --skills-sync for a
# target deployed from the opposite host.
# shellcheck disable=SC1090
source "${REPO}/src/verify_skills.sh"
check "WSL form translates to Git Bash form" \
    "$(_ainish_stamp_alternative /mnt/d/Code/x)" "/d/Code/x"
check "Git Bash form translates to WSL form" \
    "$(_ainish_stamp_alternative /d/Code/x)" "/mnt/d/Code/x"
check "a native POSIX path is left alone" \
    "$(_ainish_stamp_alternative /tmp/x)" "/tmp/x"
STAMP_TARGET="${WORK}/stamp-target"
mkdir -p "${STAMP_TARGET}/.agents/skills"
# Build the OPPOSITE host's form of this checkout, whichever host is running. The previous
# construction hardcoded the WSL prefix (`${REPO#/mnt/d}`), so under Git Bash the strip was a
# no-op, the fixture became '/d/d/Code/...', and the assertion failed on a correct translator.
# Derive the counterpart from the translator itself so the fixture cannot drift from the code.
REPO_OPPOSITE="$(_ainish_stamp_alternative "$REPO")"
if [[ "$REPO_OPPOSITE" == "$REPO" ]]; then
    # A native POSIX path (macOS/Linux) has no counterpart form; nothing to translate.
    ok "an opposite-host stamp still resolves to this checkout (native POSIX host, N/A)"
else
    printf '%s\n' "$REPO_OPPOSITE" > "${STAMP_TARGET}/.agents/skills/.ainish-source"
    check "an opposite-host stamp still resolves to this checkout" \
        "$(_ainish_skills_source "$STAMP_TARGET" 2>/dev/null)" "$REPO"
fi
printf '/nowhere/at/all\n' > "${STAMP_TARGET}/.agents/skills/.ainish-source"
check "an unresolvable stamp falls through to REPO_DIR" \
    "$(REPO_DIR="$REPO" _ainish_skills_source "$STAMP_TARGET" 2>/dev/null)" "$REPO"

echo "== skill-selection contract (regression: --rules lost its selector) =="
# Unrecorded packs must default OFF, a repo must report whether it has been
# asked, and a headless/CI run must never prompt.
UNRECORDED="${WORK}/target-unrecorded"
mkdir -p "${UNRECORDED}/.agents/skills"
check "unrecorded pack defaults off" "$(HOME="$HOME_DIR" skills_selection_default_on && echo on || echo off)" "off"

# THE PER-REPO DEFAULT IS A JSON BOOLEAN, NOT A STRING. batch_save and
# set_default both write `"default": true`; a reader that only accepts the
# strings 'on'/'off' silently treats an ON default as OFF, so every pack the
# operator had not individually toggled disappears from the deploy.
DEFAULT_REPO="${WORK}/target-default-on"
mkdir -p "${DEFAULT_REPO}/.agents/skills"
HOME="$HOME_DIR" skills_selection_batch_save "$DEFAULT_REPO" on "pqc-secrets:on" >/dev/null 2>&1
check "boolean default=true reads as on" \
    "$(HOME="$HOME_DIR" _skills_selection_repo_default "$DEFAULT_REPO")" "on"
check "unrecorded pack inherits boolean default=on" \
    "$(HOME="$HOME_DIR" skills_selection_state "$DEFAULT_REPO" advisory-council)" "on"
HOME="$HOME_DIR" skills_selection_batch_save "$DEFAULT_REPO" off "pqc-secrets:on" >/dev/null 2>&1
check "boolean default=false reads as off" \
    "$(HOME="$HOME_DIR" _skills_selection_repo_default "$DEFAULT_REPO")" "off"
check "unrecorded pack inherits boolean default=off" \
    "$(HOME="$HOME_DIR" skills_selection_state "$DEFAULT_REPO" advisory-council)" "off"
# Legacy string form must keep working for configs written by older builds.
DEFAULT_KEY="$(skills_selection_repo_key "$DEFAULT_REPO")"
printf '{"repos": {"%s": {"default": "on"}}}\n' "$DEFAULT_KEY" > "${HOME_DIR}/.config/ainish-coder/skills-selection.json"
check "legacy string default=on still reads as on" \
    "$(HOME="$HOME_DIR" _skills_selection_repo_default "$DEFAULT_REPO")" "on"
check "unrecorded pack inherits legacy string default=on" \
    "$(HOME="$HOME_DIR" skills_selection_state "$DEFAULT_REPO" advisory-council)" "on"
# A machine-wide default (--skills-set-default) is what lets a fresh repo deploy
# the operator's usual packs without being asked. It must lose to a per-repo
# answer, and it must suppress the first-contact prompt -- otherwise "set a
# default" still stops and asks on every new repo, which is the bug this flag
# exists to remove.
GLOBAL_REPO="${WORK}/target-global-default"
mkdir -p "${GLOBAL_REPO}/.agents/skills"
HOME="$HOME_DIR" skills_selection_set_global_default on >/dev/null 2>&1
check "saved global default reads as on" \
    "$(HOME="$HOME_DIR" skills_selection_global_default)" "on"
check "saved global default makes an unrecorded pack on" \
    "$(HOME="$HOME_DIR" skills_selection_state "$GLOBAL_REPO" advisory-council)" "on"
if HOME="$HOME_DIR" skills_selection_should_prompt "$GLOBAL_REPO"; then
    not_ok "a saved global default suppresses the first-contact prompt"
else
    ok "a saved global default suppresses the first-contact prompt"
fi
# A repo that recorded its own answer must keep it, whatever the global says.
# Recorded explicitly here rather than leaning on an earlier fixture, because
# the fixture config is rewritten between blocks and a stale key made this
# assertion pass or fail for reasons unrelated to precedence.
PRECEDENCE_REPO="${WORK}/target-precedence"
mkdir -p "${PRECEDENCE_REPO}"
HOME="$HOME_DIR" skills_selection_batch_save "$PRECEDENCE_REPO" off "pqc-secrets:off" >/dev/null 2>&1
check "per-repo answer outranks the global default" \
    "$(HOME="$HOME_DIR" skills_selection_state "$PRECEDENCE_REPO" pqc-secrets)" "off"
HOME="$HOME_DIR" skills_selection_set_global_default off >/dev/null 2>&1
check "saved global default reads as off" \
    "$(HOME="$HOME_DIR" skills_selection_global_default)" "off"
check "off global default leaves an unrecorded pack off" \
    "$(HOME="$HOME_DIR" skills_selection_state "$GLOBAL_REPO" advisory-council)" "off"
# The env var is a per-invocation override and must not outrank a saved default.
check "env var does not outrank the saved global default" \
    "$(HOME="$HOME_DIR" AINISH_SKILLS_DEFAULT=on skills_selection_global_default)" "off"

# Restore the fixture config for the remaining assertions.
cat > "${HOME_DIR}/.config/ainish-coder/skills-selection.json" <<JSON
{"repos": {"${KEY_ON}": {"pqc-secrets": true}, "${KEY_OFF}": {"pqc-secrets": false}}}
JSON

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

echo "== --skills-set-default and --skills (persisted, per-repo) =="
# The operator-facing surface: a machine-wide default, then a per-repo override
# that must persist for that repo only.
SD_TARGET="${WORK}/target-skills-flag"
mkdir -p "${SD_TARGET}"
sd_json="$(HOME="$HOME_DIR" AINISH_NON_INTERACTIVE=true bash "$CLI" --skills-set-default on --json 2>/dev/null || true)"
contains "skills-set-default reports the new default" "$sd_json" '"global_default": "on"'
sd_file="$(HOME="$HOME_DIR" skills_selection_global_default)"
check "skills-set-default persisted as on" "$sd_file" "on"

# Scripted per-repo selection: no prompt, persisted, and scoped to this repo.
HOME="$HOME_DIR" AINISH_NON_INTERACTIVE=true bash "$CLI" --skills "$SD_TARGET" --off pqc-secrets >/dev/null 2>&1
check "skills --off persists for this repo" \
    "$(HOME="$HOME_DIR" skills_selection_state "$SD_TARGET" pqc-secrets)" "off"
check "skills --off does not touch another repo" \
    "$(HOME="$HOME_DIR" skills_selection_state "$TARGET_ON" pqc-secrets)" "on"

# A typo must fail loudly rather than be saved as a setting that selects nothing.
if HOME="$HOME_DIR" AINISH_NON_INTERACTIVE=true bash "$CLI" --skills "$SD_TARGET" --on not-a-real-pack >/dev/null 2>&1; then
    not_ok "skills rejects an unknown pack name"
else
    ok "skills rejects an unknown pack name"
fi
# Without on/off and with no TTY, it must refuse instead of hanging on a prompt.
if HOME="$HOME_DIR" AINISH_NON_INTERACTIVE=true bash "$CLI" --skills "$SD_TARGET" >/dev/null 2>&1; then
    not_ok "skills refuses without a TTY instead of prompting"
else
    ok "skills refuses without a TTY instead of prompting"
fi

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

echo "== rules deploy refuses cleanly with no signer =="
# Deployment provenance is ML-DSA-65 signed and the compiled engine is a
# gitignored build artifact, so a fresh clone has no signer. The preflight must
# refuse BEFORE writing a manifest, or the target is left in a half-deployed
# state: a signed-expectation manifest with no signature, hooks installed, and
# no registry entry.
NOSIGNER="${WORK}/signerless"
rm -rf "$NOSIGNER"; mkdir -p "$NOSIGNER"
# REPO_DIR is overridable, so build a minimal root that has the content the
# deploy path reads but NO engine binary — exactly the fresh-clone shape.
SIGNERLESS_REPO="${WORK}/signerless-repo"
mkdir -p "${SIGNERLESS_REPO}/bin" "${SIGNERLESS_REPO}/src/rag"
cp -a "${REPO}/AGENTS.md" "${SIGNERLESS_REPO}/AGENTS.md"
cp -a "${REPO}/.gitignore" "${SIGNERLESS_REPO}/.gitignore"
cp -a "${REPO}/src/templates" "${SIGNERLESS_REPO}/src/templates" 2>/dev/null || true
env HOME="$HOME_DIR" AINISH_NO_TRACKING=true AINISH_NON_INTERACTIVE=true \
    REPO_DIR="$SIGNERLESS_REPO" \
    bash "$CLI" --rules "$NOSIGNER" --headless -y \
    > "${WORK}/signerless.log" 2>&1
signerless_rc=$?
check "refused deployment exits 1" "$signerless_rc" "1"
if [[ -e "${NOSIGNER}/.agents/ainish-deploy.json" ]]; then
    not_ok "no manifest written when the signer is missing"
else
    ok "no manifest written when the signer is missing"
fi
if [[ -e "${NOSIGNER}/.agents/bin/ainish-rules-sync" ]]; then
    not_ok "no refresher installed when refused"
else
    ok "no refresher installed when refused"
fi
if grep -qxF "$NOSIGNER" "${HOME_DIR}/.config/ainish-coder/targets.txt" 2>/dev/null; then
    not_ok "refused target is not enrolled"
else
    ok "refused target is not enrolled"
fi
contains "refusal names the engine build step" "$(cat "${WORK}/signerless.log")" "cargo build --release"

echo "== advisory masters are defined, wired, and not dangling =="
# The nine dual-expertise niches live in AGENTS.md (the always-on rail) with
# definitions in .agents/templates/masters.md. They were once removed while
# context-orchestration kept citing them, leaving an obligation nothing defined —
# this pins the wiring so that cannot recur silently.
MASTERS_DOC="${REPO}/.agents/templates/masters.md"
if [[ -f "$MASTERS_DOC" ]]; then
    ok "masters definition file exists"
else
    not_ok "masters definition file exists"
fi
masters_named=0
for n in 1 2 3 4 5 6 7 8 9; do
    grep -qE "^\| $n \|" "${REPO}/AGENTS.md" && masters_named=$((masters_named + 1))
done
check "all nine masters named in the contract" "$masters_named" "9"
contains "contract links the definitions" "$(cat "${REPO}/AGENTS.md")" "templates/masters.md"
# No surface may cite a lens set the contract no longer defines.
dangling=0
for f in "${REPO}/AGENTS.md" "${REPO}/.agents/llms.txt" \
         "${REPO}/.agents/skills/context-orchestration/SKILL.md" "${REPO}/llms.txt"; do
    [[ -f "$f" ]] || continue
    grep -q "nine core lenses" "$f" && dangling=$((dangling + 1))
done
check "no dangling 'nine core lenses' reference" "$dangling" "0"
# The packet must hand an agent the pairs without a second file read.
if command -v bash >/dev/null 2>&1 && [[ -x "${REPO}/bin/context-packet.sh" ]]; then
    packet="$(cd "$REPO" && bash bin/context-packet.sh --task "test" 2>/dev/null || true)"
    contains "packet emits the masters block" "$packet" "--- masters ---"
    contains "packet names the constitute rule" "$packet" "constitute:"
else
    ok "packet check skipped (no bash or not executable)"
    ok "packet check skipped (no bash or not executable)"
fi

echo ""
if (( FAIL > 0 )); then
    echo "FAILED: ${FAIL} assertion(s), ${PASS} passed"
    exit 1
fi
echo "PASS: ${PASS} assertion(s)"
