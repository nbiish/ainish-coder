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
# A deployed AGENTS.md is write-protected on purpose (BSD `uchg` on macOS, `+i` on Linux), so a
# plain removal leaves the temp tree behind on every run. Clear the flags best-effort, then delete.
cleanup() {
    if command -v chflags >/dev/null 2>&1; then
        find "$WORK" -type f -exec chflags nouchg {} + 2>/dev/null || true
    fi
    if command -v chattr >/dev/null 2>&1; then
        find "$WORK" -type f -exec chattr -i {} + 2>/dev/null || true
    fi
    chmod -R u+w "$WORK" 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

HOME_DIR="${WORK}/home"
TARGET_ON="${WORK}/target-on"
TARGET_OFF="${WORK}/target-off"
TARGET_MISSING="${WORK}/target-missing"
TARGET_BARE="${WORK}/target-bare"
mkdir -p "${HOME_DIR}/.config/ainish-coder" "$TARGET_ON/.agents/skills" "$TARGET_ON/bin" \
    "$TARGET_OFF/.agents/skills" "$TARGET_OFF/bin" "$TARGET_BARE/.agents/skills"

# Normalisation used by the CLI itself, so fixture keys match real lookups.
# paths.sh owns the skill payload constants and resolvers that skills_selection.sh
# and verify_skills.sh call; source it first, or those calls are unbound functions
# in a standalone (non-CLI) test run.
# shellcheck disable=SC1090
source "${REPO}/src/paths.sh"
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
#
# Extended regex (-E) rather than `\(a\|b\)` alternation: BSD sed (the macOS
# default) does not support `\|` in a basic regex, so the alternation form
# silently matched nothing there and every boolean/scalar assertion read as
# empty — a gate that looked green while verifying nothing.
jget() {
    sed -n -E "s/.*\"$1\":[[:space:]]*\"([^\"]*)\".*/\1/p; s/.*\"$1\":[[:space:]]*(true|false|[0-9]+).*/\1/p" "$2" \
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
# The config lookup above is intentionally raw. Distribution must ignore it for a
# mandatory pack, which is the whole difference between "stored off" and "not shipped".
# THE mandatory list is one predicate, and the selector hides packs by asking it. Both halves are
# pinned so an addition cannot be made in one path and forgotten in another: the previous release
# carried the same two names in _skill_mandatory AND _skill_channel_excluded, so a pack added to the
# first stayed selectable, while _skills_mandatory_names named a third, shorter set.
mandatory_ok=1
for _p in pqc-secrets ainish-security; do
    _skill_mandatory "$_p" || mandatory_ok=0
done
check "mandatory set is pqc-secrets, ainish-security" "$mandatory_ok" "1"
if _skill_mandatory typesafe-jev; then
    not_ok "an optional pack is not mandatory"
else
    ok "an optional pack is not mandatory"
fi
if _skill_mandatory security-first-agent; then
    not_ok "the retired pack is not mandatory"
else
    ok "the retired pack is not mandatory"
fi
channel_dupes=0
for _p in pqc-secrets ainish-security; do
    _skill_channel_excluded "$_p" && channel_dupes=1
done
check "channel exclusion carries no mandatory pack" "$channel_dupes" "0"
_mand_names="$(_skills_mandatory_names | tr '\n' ' ')"
check "mandatory names derive from the payload" "${_mand_names% }" "ainish-security pqc-secrets"
selector_leaks=0
_selection_list="$(HOME="$HOME_DIR" skills_selection_list "$TARGET_ON" 2>/dev/null)"
for _p in pqc-secrets ainish-security; do
    printf '%s\n' "$_selection_list" | grep -q "[[:space:]]${_p}\$" && selector_leaks=1
done
check "selector list hides every mandatory pack" "$selector_leaks" "0"
if printf '%s\n' "$_selection_list" | grep -q '[[:space:]]typesafe-jev$'; then
    ok "selector list still shows optional packs"
else
    not_ok "selector list still shows optional packs"
fi

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
# pqc-secrets is mandatory, so it is not a toggle target: the command must refuse
# it with a clear reason rather than saving an `off` that --rules would ignore.
OPT_TARGET="${WORK}/target-skills-opt"
mkdir -p "${OPT_TARGET}"
if HOME="$HOME_DIR" AINISH_NON_INTERACTIVE=true bash "$CLI" --skills "$OPT_TARGET" --off pqc-secrets >/dev/null 2>&1; then
    not_ok "skills refuses to toggle a mandatory pack"
else
    ok "skills refuses to toggle a mandatory pack"
fi
HOME="$HOME_DIR" AINISH_NON_INTERACTIVE=true bash "$CLI" --skills "$OPT_TARGET" --off typesafe-jev >/dev/null 2>&1
check "skills --off persists for a selectable pack" \
    "$(HOME="$HOME_DIR" skills_selection_state "$OPT_TARGET" typesafe-jev)" "off"
check "skills --off does not touch another repo" \
    "$(HOME="$HOME_DIR" skills_selection_state "$OPT_TARGET" typesafe-jev)" "off"
check "skills --off left the other repo alone" \
    "$(HOME="$HOME_DIR" skills_selection_state "$SD_TARGET" typesafe-jev)" "on"

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
pqc_packs=( "$REPO"/skills-to-distribute/skills/pqc* )
check "source ships exactly one pqc pack" "${#pqc_packs[@]}" "1"

echo "== --pqc-sync-targets =="
sync_json="${WORK}/sync.json"
run_cli --pqc-sync-targets --all --json > "$sync_json"
# pqc-secrets is mandatory: a target carrying a stale `off` entry is synced anyway,
# because --rules deploys the pack regardless and a skipped target would be left
# without the engine its contract resolves every secret through.
check "both enrolled targets synced" "$(jget synced "$sync_json")" "2"
check "no target skipped as deselected" "$(jget deselected "$sync_json")" "0"
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
# A stale `off` entry is ignored, but it must not be *erased* from the config:
# the entry is the operator's history, and --rules is what actually governs.
[[ -x "${TARGET_OFF}/bin/pqc-secrets" ]] && ok "stale-off target still received the mandatory pack" || not_ok "stale-off target still received the mandatory pack"

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
          "${REPO}/skills-to-distribute/skills/pqc-secrets/references/signatures-security.md"; then
    ok "reference restored byte-for-byte"
else
    not_ok "reference restored byte-for-byte"
fi

run_cli --pqc-sync-targets --all --json > "${WORK}/sync2.json"
check "second sync leaves both targets current" "$(jget current "${WORK}/sync2.json")" "2"
check "second sync reuses the attested manifest" "$(jget_first manifest "${WORK}/sync2.json")" "attested"

echo "== --pqc-status =="
run_cli --pqc-status --json --no-wsl > "${WORK}/status.json"
status_rc=$?
check "status exits 0 when only optional packs are missing" "$status_rc" "0"
check "both targets report current" "$(jget current "${WORK}/status.json")" "2"
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

echo "== advisory masters are defined and reachable =="
# The nine niches are a reasoning device, not a rules-file obligation: their definitions live in
# .agents/templates/masters.md and the packet emits them inline, so an agent gets them without a
# second file read. AGENTS.md stays short and only points at the definitions.
MASTERS_DOC="${REPO}/.agents/templates/masters.md"
if [[ -f "$MASTERS_DOC" ]]; then
    ok "masters definition file exists"
else
    not_ok "masters definition file exists"
fi
masters_defined=0
for n in 1 2 3 4 5 6 7 8 9; do
    grep -qE "^\| $n \|" "$MASTERS_DOC" && masters_defined=$((masters_defined + 1))
done
check "all nine masters defined in the template" "$masters_defined" "9"
contains "contract points at the definitions" "$(cat "${REPO}/AGENTS.md")" "templates/masters.md"
# A skill index or a pack table that names a directory which does not exist is worse than silent: it
# sends a reader looking for a file that is not there. This has drifted twice (README advertised three
# deleted browser packs and omitted four real ones, plus two packs that never existed).
stale_pack_refs=0
for surfacedoc in "${REPO}/README.md" "${REPO}/skills-to-distribute/skills/llms.txt" "${REPO}/src/help.sh" \
                  "${REPO}/.agents/llms.txt" "${REPO}/llms.txt"; do
    [[ -f "$surfacedoc" ]] || continue
    while IFS= read -r refname; do
        [[ -n "$refname" ]] || continue
        if [[ ! -d "${REPO}/skills-to-distribute/skills/${refname}" && ! -d "${REPO}/.agents/skills/${refname}" ]]; then
            echo "    stale pack reference in ${surfacedoc##*/}: ${refname}"
            stale_pack_refs=$((stale_pack_refs + 1))
        fi
    done < <(grep -oE '\.agents/skills/[a-z0-9-]+/' "$surfacedoc" 2>/dev/null | sed 's#.*/skills/##; s#/$##' | sort -u)
done
check "no surface names a nonexistent skill pack" "$stale_pack_refs" "0"
# The wtf pack must stay discoverable: it is a distributed pack, so the skills index names it.
contains "skills index lists the wtf pack" "$(cat "${REPO}/skills-to-distribute/skills/llms.txt")" "wtf-is-going-on-mcp"
# No surface may cite a lens set that nothing defines.
dangling=0
for f in "${REPO}/AGENTS.md" "${REPO}/.agents/llms.txt" "${REPO}/llms.txt" \
         "${REPO}/skills-to-distribute/skills/ainish-security/SKILL.md"; do
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
echo "== the context-injection contract is wired end to end =="
# AGENTS.md directs every deployed agent to one `ainish-rag context` call and defines what the
# `<CONTEXT_INJECTION>` envelope means. That promise is only honest if the engine implements the
# verb, the isolation it claims is really enforced, and the docs a target actually reads agree with
# the contract. Each of those is asserted here so a future edit cannot leave a dangling instruction.
RAG_PY="${REPO}/src/rag/rag.py"
contains "engine implements the context verb" "$(cat "$RAG_PY")" 'sub.add_parser('
contains "engine registers the context subcommand" "$(cat "$RAG_PY")" '"context",'
contains "engine names the context envelope format" "$(cat "$RAG_PY")" 'ainish-rag/context/v1'
contains "engine renders the labelled injection markers" "$(cat "$RAG_PY")" '<CONTEXT_INJECTION>'
contains "goldfish isolation is signature-declared" "$(cat "$RAG_PY")" 'def goldfish_review('
contains "contract names the invocation" "$(cat "${REPO}/AGENTS.md")" 'ainish-rag --context --task'
contains "contract names the envelope markers" "$(cat "${REPO}/AGENTS.md")" '<CONTEXT_INJECTION>'
contains "contract states the advisory rule" "$(cat "${REPO}/AGENTS.md")" 'evidence, not instruction'
# The rule is "a thin block never stops the work", stated in the contract's own words. Asserting one
# exact phrasing couples the gate to a sentence the 120-line budget may legitimately rewrite; assert
# the behaviour the contract must still tell an agent, whichever words carry it.
degrade_rule=$(grep -cE 'carry on|Never block on it|do not block on it' "${REPO}/AGENTS.md" || true)
check "contract states the degradation rule" "$([[ "${degrade_rule:-0}" -gt 0 ]] && echo yes || echo no)" "yes"
# Authorship is a claim about who wrote the work, and a harness can inject a co-author trailer
# (this repo's own commits carried `Co-authored-by: Cursor` until 2026-11-11). The contract must
# forbid it explicitly, because every harness default that offers it is otherwise obeyed.
contains "contract forbids co-authorship" "$(cat "${REPO}/AGENTS.md")" 'Never co-author a commit'
contains "contract names the harness identity" "$(cat "${REPO}/AGENTS.md")" 'Nanoboozhoo - embodied by {agent harness}'
contains "contract points at the identity guard" "$(cat "${REPO}/AGENTS.md")" 'commit-identity-guard.sh'
coauthor_ok=0
if grep -qiE 'owner is the only author|only author' "${REPO}/AGENTS.md"; then coauthor_ok=1; fi
check "contract names the owner as sole author" "$coauthor_ok" "1"
# The contract must NOT describe models, providers, or the driver chain: those are engine facts that
# belong in llms.txt and the engine's own report, and naming them in an always-read file costs every
# agent tokens for information it cannot act on.
contract_model_refs=$(grep -cE 'local-router|openrouter|zenmux|nous-portal|nebius|zai|xiaomi-mimo|deepseek|glm-|mimo-|fallback-models' "${REPO}/AGENTS.md" || true)
check "contract names no model or provider" "$contract_model_refs" "0"
# The driver chain is an operator-specified order (2026-11-13): local router, then three DIRECT
# provider calls. Assert the order AND the direct transports, because the failure this fixed was
# steps that looked right by name but were router routes pointed at a vendor the operator did not
# choose. A chain that regresses to routes still contains all four strings, so the transport pairing
# is what must be pinned.
contains "prd documents the operator's chain order" "$(cat "${REPO}/llms.txt")" 'local-router/fallback-models` at `localhost:11434'
contains "prd documents the direct steps" "$(cat "${REPO}/llms.txt")" 'direct transports, not router routes'
contains "engine sends the literal route id to the router" \
    "$(cat "${REPO}/src/rag/rag.py")" '"id": "local-router/fallback-models"'
check "chain step 2 is a direct zai call" \
    "$(grep -A 3 '"id": "glm-5.3-flash"' "${REPO}/src/rag/rag.py" | grep -c '"transport": "zai"')" "1"
check "chain step 3 is a direct xiaomi call" \
    "$(grep -A 3 '"id": "mimo-v2.6-pro"' "${REPO}/src/rag/rag.py" | grep -c '"transport": "xiaomi-mimo"')" "1"
check "chain step 4 is a direct openrouter call" \
    "$(grep -A 3 '"id": "deepseek/deepseek-v4.1-flash-1017"' "${REPO}/src/rag/rag.py" | grep -c '"transport": "openrouter"')" "1"
contains "z.ai endpoint is the operator's URL" "$(cat "${REPO}/src/rag/rag.py")" 'https://api.z.ai/api/coding/paas/v4'
contains "xiaomi endpoint is the operator's URL" "$(cat "${REPO}/src/rag/rag.py")" 'https://token-plan-sgp.xiaomimimo.com/v1'
contains "openrouter endpoint is the operator's URL" "$(cat "${REPO}/src/rag/rag.py")" 'https://openrouter.ai/api/v1'
# A mandatory pack must be invisible to the selector and still be deployed. Both halves are pinned:
# hiding it alone would let --rules silently ship nothing, and deploying it alone would put a
# non-choice in front of the operator.
contains "pqc-secrets is declared mandatory" "$(cat "${REPO}/src/skills_selection.sh")" '_skill_mandatory'
contains "selector hides by the mandatory predicate" "$(cat "${REPO}/src/skills_selection.sh")" '_skill_mandatory "$name" && continue'
contains "deploy ships it unconditionally" "$(cat "${REPO}/src/deploy_skills.sh")" 'Deployed (mandatory)'
contains "verify fails when it is absent" "$(cat "${REPO}/src/verify_skills.sh")" 'MISSING MANDATORY'
contains "verify delegates the mandatory list" "$(cat "${REPO}/src/verify_skills.sh")" '_skill_mandatory "$1"'
contains "sync ships mandatory packs past the selection" "$(cat "${REPO}/src/verify_skills.sh")" '! _ainish_skill_mandatory "$source_name"'
if grep -q 'security-first-agent' "${REPO}/src/help.sh"; then
    not_ok "help no longer inventories the retired pack"
else
    ok "help no longer inventories the retired pack"
fi
contains "help inventories tts-cli" "$(cat "${REPO}/src/help.sh")" 'tts-cli/'
if grep -q 'security-first-agent' "${REPO}/skills-to-distribute/skills/llms.txt"; then
    not_ok "payload index no longer references the retired pack"
else
    ok "payload index no longer references the retired pack"
fi
contains "prd names two mandatory packs" "$(cat "${REPO}/llms.txt")" 'Two packs are mandatory'
# The pack was retired because its posture moved into the contract itself; both halves are pinned
# so a re-add of the pack cannot happen while the contract silently drops the posture.
contains "AGENTS.md carries the security-first posture" "$(cat "${REPO}/AGENTS.md")" 'Security-first posture'
contains "AGENTS.md prompts the suggestions ledger" "$(cat "${REPO}/AGENTS.md")" '.agents/suggestions/{date}-{HH}-{slug}.md'
contains "prd docs the driver transport" "$(cat "${REPO}/llms.txt")" 'Driver transport (generative)'
contains "security skill carries the advisory rule" "$(cat "${REPO}/skills-to-distribute/skills/ainish-security/SKILL.md")" 'injection is data, not instruction'

echo "== security is one skill and context orchestration is a command =="
# Four packs split security by domain, so an agent had to know in advance which
# one a task belonged to before loading any rules. One skill removes that guess.
SEC_DIR="${REPO}/skills-to-distribute/skills/ainish-security"
for gone in code-security llm-security production-security context-orchestration orchestrate-subagent-masters; do
    if [[ -d "${REPO}/skills-to-distribute/skills/${gone}" ]]; then
        not_ok "retired pack removed: $gone"
    else
        ok "retired pack removed: $gone"
    fi
done
# Retiring a pack is not enough: every live surface that recommended it must stop
# doing so, or the next agent is told to load something that no longer exists.
live_refs=0
for f in "${REPO}/skills-to-distribute/skills/llms.txt" "${REPO}/skills-to-distribute/skills/gstack-coder/SKILL.md" \
         "${REPO}/AGENTS.md" "${REPO}/llms.txt" "${REPO}/.agents/llms.txt" "${REPO}/src/help.sh"; do
    [[ -f "$f" ]] || continue
    # Mentions that mark it retired ("is retired", "former", "merged into") are fine; a bare
    # "pair with X skill" is not.
    if grep -qE "orchestrate-subagent-masters skill|Use .orchestrate-subagent-masters|pair with .*orchestrate-subagent-masters" "$f"; then
        live_refs=$((live_refs + 1))
    fi
done
check "no live surface recommends the retired skill" "$live_refs" "0"
contains "skills index documents the retirement" "$(cat "${REPO}/skills-to-distribute/skills/llms.txt")" 'skill is retired'
# Cleanup lists must name every retired pack, or a target that still carries one keeps it forever.
contains "deploy sweeps context-orchestration" "$(cat "${REPO}/src/deploy_skills.sh")" "context-orchestration orchestrate-subagent-masters"
contains "selection excludes context-orchestration" "$(cat "${REPO}/src/skills_selection.sh")" "context-orchestration|orchestrate-subagent-masters"
for kept in SKILL.md references/code-and-infrastructure.md references/ai-and-agentic.md \
            references/governance-and-cryptography.md references/deployable-standards.md; do
    if [[ -f "${SEC_DIR}/${kept}" ]]; then
        ok "consolidated security carries ${kept}"
    else
        not_ok "consolidated security carries ${kept}"
    fi
done
# The instructional must actually span the fields, not just claim to.
sec_skill="$(cat "${SEC_DIR}/SKILL.md")"
contains "covers input handling" "$sec_skill" "SQL injection"
contains "covers authn/authz" "$sec_skill" "Deny by default"
contains "covers AI/agentic" "$sec_skill" "blast-radius"
contains "covers PQC" "$sec_skill" "ML-KEM-768"
contains "covers supply chain" "$sec_skill" "SBOM"
contains "covers compiler integrity" "$sec_skill" "source is not binary"
contains "covers governance" "$sec_skill" "EU AI Act"
# Mandatory because the always-on rail links to it: an optional pack leaves that link dangling.
contains "ainish-security is mandatory" "$(cat "${REPO}/src/skills_selection.sh")" 'pqc-secrets|ainish-security'
contains "verify treats it as mandatory" "$(cat "${REPO}/src/verify_skills.sh")" '_skill_mandatory "$1"'
# --secure must ship one file, and must not still reference the deleted pair.
secure_block="$(sed -n '/--secure)/,/;;/p' "${REPO}/bin/ainish-coder")"
contains "secure deploys the consolidated standard" "$secure_block" "deployable-standards.md"
contains "secure writes AGENTS_SECURITY.md" "$secure_block" "AGENTS_SECURITY.md"
# Orientation is the mechanical half of the retired skill; it must be in the envelope.
contains "engine emits an orientation section" "$(cat "${REPO}/src/rag/rag.py")" 'def render_orientation_section'
contains "orientation is a labelled section" "$(cat "${REPO}/src/rag/rag.py")" '"source": "orientation"'
contains "prd documents the orientation section" "$(cat "${REPO}/llms.txt")" '| `orientation` |'
# A verb the compiled binary answers with a SHORTER report reads as a regression, so the launchers
# must route it to the Python engine even though the binary advertises it.
contains "bash launcher routes secrets to python" "$(cat "${REPO}/bin/ainish-rag")" 'PY_ONLY_SUBCOMMANDS=" context secrets "'
contains "cmd launcher routes secrets to python" "$(cat "${REPO}/bin/ainish-rag.cmd")" 'PY_ONLY_SUBCOMMANDS= context secrets '
# The native engine writes UTF-8; decoding with the platform default crashed every native search.
contains "native query decode is explicit" "$(cat "${REPO}/src/rag/rag.py")" 'errors="replace"'
# The pair is two calls with two model choices. Pin both halves: that the engine scopes a chain by
# role, and that the contract tells the reader the roles can diverge.
contains "engine scopes the chain by role" "$(cat "${REPO}/src/rag/rag.py")" "def chain_steps(self, role"
contains "roles rotate to a distinct model" "$(cat "${REPO}/src/rag/rag.py")" "def _rotate_for_role"
contains "both role pins resolve" "$(cat "${REPO}/src/rag/rag.py")" 'AINISH_RAG_ELEPHANT_MODEL'
contains "goldfish pin resolves" "$(cat "${REPO}/src/rag/rag.py")" 'AINISH_RAG_GOLDFISH_MODEL'
contains "provenance reports reviewer isolation" "$(cat "${REPO}/src/rag/rag.py")" '"reviewer_isolation"'
contains "render names the pair" "$(cat "${REPO}/src/rag/rag.py")" "<!-- pair: elephant="
contains "context exposes a per-role model flag" "$(cat "${REPO}/src/rag/rag.py")" '"--elephant-model"'
contains "prd documents the per-role pins" "$(cat "${REPO}/llms.txt")" 'AINISH_RAG_GOLDFISH_MODEL'
# `--context` is the spelling the contract and muscle memory use; argparse needs the subcommand.
contains "engine normalizes the --context alias" "$(cat "${REPO}/src/rag/rag.py")" "def normalize_argv"
contains "argparse receives normalized argv" "$(cat "${REPO}/src/rag/rag.py")" "parse_args(normalize_argv"
contains "contract shows the --context form" "$(cat "${REPO}/AGENTS.md")" 'ainish-rag --context --task'
# The section table and role mechanics moved to llms.txt: an always-read file needs the invocation
# and the one rule about how to read the output, not a catalogue of what each section contains.
contains "prd documents the envelope sections" "$(cat "${REPO}/llms.txt")" '| `orientation` |'
contains "prd documents the refused-review rule" "$(cat "${REPO}/llms.txt")" 'EGM stops the review'
contains "prd documents the three-step goldfish" "$(cat "${REPO}/llms.txt")" 'comprehension check'
# AGENTS.md must stay short enough to read without hesitation. The budget was 120 until
# 2026-11-12, when the security-first-agent pack was retired into the contract itself — the
# posture has to live in the one file every session reads whole, so the budget grew to 160
# by operator decision rather than the section drifting in unbounded.
contract_lines=$(wc -l < "${REPO}/AGENTS.md" | tr -d ' ')
if (( contract_lines <= 160 )); then
    ok "contract stays under 160 lines (${contract_lines})"
else
    not_ok "contract stays under 160 lines (${contract_lines})"
fi
# Every file the contract links to must be deployed by --rules. A pointer to a file the target never
# receives is worse than no pointer: the agent is told to read something that is absent. The .agents
# map and the skills index come from different trees now (the index describes DISTRIBUTED packs), so
# both copy paths are pinned and both are checked below.
DEPLOY_TMPL_LINE='for _tpl in llms.txt templates/llms.txt templates/masters.md templates/egm-design.md templates/plan.md plans/llms.txt; do'
contains "deploy copies the .agents map" "$(cat "${REPO}/bin/ainish-coder")" "${DEPLOY_TMPL_LINE}"
contains "deploy copies the skills index from the payload" "$(cat "${REPO}/bin/ainish-coder")" '_src="${REPO_DIR}/${AINISH_SKILLS_SOURCE_REL}/llms.txt"'
linked_shipped=0
for linked in llms.txt templates/masters.md templates/plan.md plans/llms.txt skills/llms.txt; do
    if grep -qF "${linked}" "${REPO}/bin/ainish-coder"; then
        linked_shipped=$((linked_shipped + 1))
    fi
done
check "deploy names every contract-linked .agents file" "$linked_shipped" "5"
# The manifest must describe what is actually deployed. `--rules-status`,
# `--rules-verify`, and `--rules-doctor` all reason from `managed_paths`, so a
# manifest that omits a surface it ships makes those tools blind to drift in it.
# Assert the two template/plan surfaces added with the plans work are declared.
for declared in ".agents/templates" ".agents/plans/llms.txt"; do
    contains "manifest declares ${declared}" "$(cat "${REPO}/src/deploy_rules_sync.sh")" "\"${declared}\""
done
# Runtime bytecode must never distribute. Packs nest Python, so a top-level-only
# filter is not enough; the prune runs over the copied tree.
contains "deploy prunes nested bytecode caches" "$(cat "${REPO}/src/file_operations.sh")" 'ainish_prune_runtime_junk "$dest_dir"'
# Every path named in the .agents Child DOX index must exist. This is the dangling-pointer class the
# check above only covers for the contract's own links: an index entry pointing at a filename the
# target never receives tells the next agent to read something that is not there.
index_missing=0
index_checked=0
while IFS= read -r index_rel; do
    [[ -z "${index_rel}" ]] && continue
    index_checked=$((index_checked + 1))
    [[ -e "${REPO}/.agents/${index_rel}" ]] || { index_missing=$((index_missing + 1)); echo "  missing index target: .agents/${index_rel}"; }
done < <(awk '/^## Child DOX index/{inside=1; next} inside && /^## /{exit} inside' "${REPO}/.agents/llms.txt" \
            | grep -oE '\]\(\./[^)]+\)' | sed 's/^](\.\///; s/)$//')
# A parse that silently finds nothing passes vacuously; assert the count too.
check "child index entries were found to check" "$([[ ${index_checked} -ge 5 ]] && echo yes || echo no)" "yes"
check "every .agents child index entry exists" "$index_missing" "0"
# The plan artifact is only real if its template, its directory contract, and its deploy wiring all
# exist: a skill that writes plans into a directory no target receives is a skill that fails silently.
check "plan template ships" "$([[ -f "${REPO}/.agents/templates/plan.md" ]] && echo yes || echo no)" "yes"
check "plans directory contract ships" "$([[ -f "${REPO}/.agents/plans/llms.txt" ]] && echo yes || echo no)" "yes"
contains "plan template declares the frontmatter contract" "$(cat "${REPO}/.agents/templates/plan.md")" 'plan_format: ainish/plan/v1'
contains "question-me writes plans of record" "$(cat "${REPO}/skills-to-distribute/skills/question-me/SKILL.md")" '.agents/plans/{YYYY-MM-DD}-{HH}-{slug}.md'
# No key, model id, or endpoint may leak into the always-on contract or be duplicated from the code.
contract_secrets=$(grep -cE 'sk-[A-Za-z0-9]{8,}|https://(openrouter|zenmux)\.ai' "${REPO}/AGENTS.md" || true)
check "contract embeds no key or provider endpoint" "$contract_secrets" "0"

echo "== the distributable payload is split from this repo's readable packs =="
# The whole point of the split: agent harnesses auto-discover `**/.agents/skills`, so every pack kept
# there is standing prompt surface in THIS repository. Distribution therefore reads one tree
# (skills-to-distribute/skills/) and writes another (.agents/skills/ in the consumer). Three things
# must hold, and each has a distinct failure it prevents.
check "payload tree exists" \
    "$([[ -d "${REPO}/skills-to-distribute/skills" ]] && echo yes || echo no)" "yes"
# 1. The payload must be the complete set, or a deploy silently ships fewer packs than the index lists.
payload_packs=$(find "${REPO}/skills-to-distribute/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
check "payload carries every pack" "$(( payload_packs >= 20 ))" "1"
# 2. This repo's own .agents/skills must stay a small curated subset. A drifting re-add (the failure
#    mode this refactor exists to fix) shows up here as a count that creeps back toward the payload.
local_packs=0
[[ -d "${REPO}/.agents/skills" ]] && local_packs=$(find "${REPO}/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
check "local .agents/skills is a curated subset (<=6 packs)" "$(( local_packs <= 6 ))" "1"
check "local subset is a strict subset of the payload" \
    "$(( local_packs < payload_packs ))" "1"
# 3. Every contract-critical pack an agent here is told to read must actually be readable locally.
for required in ainish-security pqc-secrets question-me; do
    check "contract-critical pack readable locally: ${required}" \
        "$([[ -d "${REPO}/.agents/skills/${required}" ]] && echo yes || echo no)" "yes"
    check "contract-critical pack also distributable: ${required}" \
        "$([[ -d "${REPO}/skills-to-distribute/skills/${required}" ]] && echo yes || echo no)" "yes"
    # The local copy exists so agents can READ it; the payload copy is what ships. Two copies of one
    # pack is the drift surface this design introduces, so pin byte-identity: an edit to either side
    # alone must fail here rather than silently publish a pack nobody re-read.
    if diff -r -x ".env" -x "__pycache__" -x "*.pyc" -x ".DS_Store" \
            "${REPO}/skills-to-distribute/skills/${required}" "${REPO}/.agents/skills/${required}" \
            >/dev/null 2>&1; then
        ok "local copy matches the payload byte-for-byte: ${required}"
    else
        not_ok "local copy drifted from the payload: ${required} (re-copy from skills-to-distribute/skills/)"
    fi
done
# 4. No script may resolve the SOURCE tree from a hardcoded literal. One shared constant is what keeps
#    src/deploy_skills.sh, the selector, verify, sync, pqc, scrolls, and unlock in step.
# 5. The local skills INDEX is a copy of the payload's, because the contract links to it by path and
#    this repo must be able to follow its own contract. Two copies means drift, so pin byte-identity —
#    an index that silently diverges would describe packs differently depending on which side you read.
if [[ -f "${REPO}/skills-to-distribute/skills/llms.txt" ]] && cmp -s \
        "${REPO}/skills-to-distribute/skills/llms.txt" "${REPO}/.agents/skills/llms.txt"; then
    ok "local skills index matches the payload index"
else
    not_ok "local skills index is missing or drifted from skills-to-distribute/skills/llms.txt"
fi
# And every contract link that points INTO .agents/skills must resolve here, or the contract tells an
# agent in this repo to read a file that was never placed.
contract_skill_links_missing=0
while IFS= read -r lk; do
    [[ -z "$lk" ]] && continue
    [[ -e "${REPO}/${lk}" ]] || { contract_skill_links_missing=$((contract_skill_links_missing + 1)); echo "  dangling contract link: ${lk}"; }
done < <(grep -oE '\.agents/skills/[A-Za-z0-9._/-]+' "${REPO}/AGENTS.md" 2>/dev/null | sort -u)
check "every AGENTS.md skills link resolves in this repo" "$contract_skill_links_missing" "0"
hardcoded=$(grep -rn 'REPO_DIR}/\.agents/skills\|REPO_DIR}/\.agents/skills/\${' \
    "${REPO}/src" "${REPO}/bin/ainish-coder" 2>/dev/null \
    | grep -v 'AINISH_SKILLS_TARGET_REL' | grep -v '^.*#' | wc -l | tr -d ' ')
check "no script hardcodes the payload source path" "$hardcoded" "0"
contains "the shared source constant is defined once" "$(cat "${REPO}/src/paths.sh")" 'AINISH_SKILLS_SOURCE_REL="skills-to-distribute/skills"'
contains "the shared target constant is defined once" "$(cat "${REPO}/src/paths.sh")" 'AINISH_SKILLS_TARGET_REL=".agents/skills"'

echo "== plan-first gate =="
# AGENTS.md non-negotiable #1 is prose; --plan-check is the deterministic half. A gate that
# cannot fail is decoration, so both directions are asserted: refusal without a plan, and
# acceptance with one whose `branch:` key names this branch.
echo "== federation predicts and verifies =="
# Transport delivering refs is not the same as a peer being USABLE. These pin the three things that
# were missing: a dry run that can predict the outcome, a post-sync proof the peer can execute, and
# de-duplication of two registry entries that are one working tree.
MS="$(cat "${REPO}/src/machine_sync.sh")"
contains "dry run forecasts commit delta" "$MS" 'forecast: '
contains "forecast names the blocking paths" "$MS" 'would NOT advance'
contains "forecast states when a peer would fast-forward" "$MS" 'would fast-forward'
contains "a synced peer is smoke-probed" "$MS" '_ms_smoke_peer'
contains "the smoke probe reports a version" "$MS" '--version'
# `bin/ainish-coder` is a bash script. Probing it on a Windows peer (PowerShell login shell) fails
# and reports a healthy machine as unverified; the `.cmd` wrapper is the entry point there.
contains "the smoke probe picks a Windows launcher" "$MS" 'ainish-coder.cmd'
# `>/dev/null` and `&&` are PowerShell syntax errors, so the plan-check status must come from ssh.
contains "plan-check status comes from ssh, not a remote redirect" "$MS" 'plan_rc=$?'
contains "two entries resolving to one checkout are de-duplicated" "$MS" 'same checkout as'
# The peer's login shell may be PowerShell, where `&&` and `>/dev/null` are syntax errors. Every
# remote command must be shell-agnostic (`git -C`), which is why the snapshot plumbing already did.
remote_cd_forms=$(grep -c "cd '\$path' 2>/dev/null &&" "${REPO}/src/machine_sync.sh" || true)
check "no remote command assumes a POSIX login shell" "${remote_cd_forms:-0}" "0"
# De-duplication is only possible if the two spellings of one NTFS path normalize together.
contains "checkout identity normalizes the WSL path form" "$MS" '/mnt/[a-z]/*'
contains "checkout identity normalizes the Windows drive form" "$MS" '[A-Za-z]:/*'

contains "contract states the plan-first rule" "$(cat "${REPO}/AGENTS.md")" 'Plan first'
# Discoverability is a capability, and an ungated claim decays back to zero. The federation verbs
# exist, are tested, and are useless to a future agent that never learns they are there. These pin
# the two surfaces an agent actually reads before acting: the contract, and `ainish-rag --help`.
contains "contract points at the federation tooling" "$(cat "${REPO}/AGENTS.md")" 'machine-sync'
# --help is rendered from rag.py's argparse description; grep the source so the assertion does not
# depend on a built binary or a slow subprocess. The range is anchored on the description's own
# opening line rather than a fixed line number: a hardcoded window silently stopped covering the
# help text the moment an unrelated paragraph was added above it, which reported three real verbs
# as missing. Anchor on content, not on an offset.
RAG_HELP_SRC="$(sed -n "$(grep -n 'The command agents call is:' "${REPO}/src/rag/rag.py" | head -1 | cut -d: -f1),+95p" "${REPO}/src/rag/rag.py")"
contains "rag help teaches the machine-link setup command" "$RAG_HELP_SRC" 'machine-link'
contains "rag help teaches the newest-copy query" "$RAG_HELP_SRC" 'machine-sync DIR --latest'
contains "rag help says how to check the background watcher" "$RAG_HELP_SRC" 'machine-watch --status'
contains "contract names the plan of record path" "$(cat "${REPO}/AGENTS.md")" '.agents/plans/{date}-{HH}-{slug}.md'
check "AGENTS.md stays within the 160-line gate" \
    "$([[ "$(wc -l < "${REPO}/AGENTS.md" | tr -d ' ')" -le 160 ]] && echo yes || echo no)" "yes"
PLAN_REPO="${WORK}/plan-gate-repo"
mkdir -p "${PLAN_REPO}/.agents/plans"
git -C "${PLAN_REPO}" init -q 2>/dev/null
git -C "${PLAN_REPO}" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null
git -C "${PLAN_REPO}" checkout -qb feat/gated 2>/dev/null
plan_verdict() { (cd "$PLAN_REPO" && env HOME="$HOME_DIR" AINISH_NO_TRACKING=true bash "$CLI" --plan-check . >/dev/null 2>&1; echo $?); }
check "no plan on a feature branch is refused" "$(plan_verdict)" "1"
printf -- '---\nbranch: feat/gated\nstatus: designing\n---\n' > "${PLAN_REPO}/.agents/plans/2026-01-01-gated.plan.md"
check "a still-designing plan is refused" "$(plan_verdict)" "1"
printf -- '---\nbranch: feat/other-branch\nstatus: ready\n---\n' > "${PLAN_REPO}/.agents/plans/2026-01-01-gated.plan.md"
check "a plan for a different branch does not count" "$(plan_verdict)" "1"
printf -- '---\nbranch: feat/gated\nstatus: ready\n---\n' > "${PLAN_REPO}/.agents/plans/2026-01-01-gated.plan.md"
check "a ready plan names and clears the branch" "$(plan_verdict)" "0"

# The hour-stamp cutover drops the `.plan.md` suffix. If the gate still globbed `*.plan.md`, every
# new-scheme branch would be refused with "no plan of record" — the gate blocking the very change
# that renamed its input. Both schemes must clear a ready plan and refuse a designing one.
rm -f "${PLAN_REPO}/.agents/plans/2026-01-01-gated.plan.md"
printf -- '---\nbranch: feat/gated\nstatus: ready\n---\n' > "${PLAN_REPO}/.agents/plans/2026-01-01-09-gated.md"
check "a new-scheme hour-stamped plan clears the branch" "$(plan_verdict)" "0"
printf -- '---\nbranch: feat/gated\nstatus: designing\n---\n' > "${PLAN_REPO}/.agents/plans/2026-01-01-09-gated.md"
check "a new-scheme plan still refuses while designing" "$(plan_verdict)" "1"
printf -- '# plans of record\nnot a plan\n' > "${PLAN_REPO}/.agents/plans/llms.txt"
printf -- '---\nbranch: feat/gated\nstatus: ready\n---\n' > "${PLAN_REPO}/.agents/plans/2026-01-01-09-gated.md"
check "the plans index is not mistaken for a plan" "$(plan_verdict)" "0"

git -C "${PLAN_REPO}" checkout -q main 2>/dev/null
check "the default branch is never gated" "$(plan_verdict)" "0"

echo "== coordination records carry a UTC hour (2026-11-12 cutover) =="
# Two naming schemes are live at once, and every reader must accept both. A reader that filters on
# one suffix does not fail loudly — it silently matches nothing, which reads as "no plan of record"
# or "no memory". These pin the predicates, not the prose, because the prose is not what runs.
COMMS_DEPLOY="${WORK}/comms-deploy"
mkdir -p "${COMMS_DEPLOY}"
( . "${REPO}/src/paths.sh" 2>/dev/null; REPO_DIR="${REPO}"; . "${REPO}/src/deploy_agents_comms.sh" ) >/dev/null 2>&1 || true
today="$(date +%F)"
if command -v bash >/dev/null 2>&1; then
    ( cd "${COMMS_DEPLOY}" && REPO_DIR="${REPO}" bash -c '
        set -e
        . "'"${REPO}"'/src/paths.sh" 2>/dev/null || true
        REPO_DIR="'"${REPO}"'"
        validate_target_dir() { return 0; }
        ainish_temp_beside() { printf "%s.tmp" "$1"; }
        confirm_action() { return 1; }
        BRIGHT_RED="" RESET="" BRIGHT_BLUE="" GREEN="" BRIGHT_GREEN="" YELLOW=""
        . "'"${REPO}"'/src/deploy_agents_comms.sh"
        deploy_agents_comms .
      ' >/dev/null 2>&1 ) || true
fi
check "deploy writes a markdown comms ledger" \
    "$([[ -f "${COMMS_DEPLOY}/.agents/comms/${today}-team.md" ]] && echo yes || echo no)" "yes"
check "deploy no longer writes the legacy txt ledger" \
    "$([[ -f "${COMMS_DEPLOY}/.agents/comms/${today}-team.txt" ]] && echo yes || echo no)" "no"
contains "comms template names the markdown ledger" \
    "$(cat "${REPO}/src/templates/AGENTS.COMMS.md")" '.agents/comms/{date}-team.md'

# Legacy adoption: a target that deployed before the cutover must keep its existing ledger rather
# than starting a second file for the same UTC date.
LEGACY_DEPLOY="${WORK}/comms-legacy"
mkdir -p "${LEGACY_DEPLOY}/.agents/comms"
printf '<PROTOCOL>\nold\n</PROTOCOL>\n### [10:00Z] feat | branch:main\n- agent entry\n' \
    > "${LEGACY_DEPLOY}/.agents/comms/${today}-team.txt"
( cd "${LEGACY_DEPLOY}" && REPO_DIR="${REPO}" bash -c '
    . "'"${REPO}"'/src/paths.sh" 2>/dev/null || true
    REPO_DIR="'"${REPO}"'"
    validate_target_dir() { return 0; }
    ainish_temp_beside() { printf "%s.tmp" "$1"; }
    confirm_action() { return 1; }
    BRIGHT_RED="" RESET="" BRIGHT_BLUE="" GREEN="" BRIGHT_GREEN="" YELLOW=""
    . "'"${REPO}"'/src/deploy_agents_comms.sh"
    deploy_agents_comms .
  ' >/dev/null 2>&1 ) || true
check "a legacy txt ledger for today is adopted, not duplicated" \
    "$([[ -f "${LEGACY_DEPLOY}/.agents/comms/${today}-team.md" ]] && echo yes || echo no)" "no"
check "the legacy ledger's agent entry survives the refresh" \
    "$(grep -c 'agent entry' "${LEGACY_DEPLOY}/.agents/comms/${today}-team.txt" 2>/dev/null || echo 0)" "1"

# Engine predicates: both suffixes must be accepted, the index and the live board must not be.
check "python engine accepts both memory suffixes" \
    "$(grep -c '"\-memory.txt", "\-memory.md"' "${REPO}/src/rag/rag.py")" "1"
check "rust engine shares one memory-ledger predicate" \
    "$(grep -c 'pub fn is_memory_ledger' "${REPO}/src/rag/src/wiki.rs")" "1"
check "python memory discovery orders by mtime, not filename" \
    "$(grep -A 30 'def _coordination_files' "${REPO}/src/rag/rag.py" | grep -c 'stat().st_mtime')" "1"
check "rust memory discovery orders by mtime, not filename" \
    "$(grep -c 'm_files.sort_by_key' "${REPO}/src/rag/src/main.rs")" "1"
contains "comms discipline check sees the markdown scheme" \
    "$(cat "${REPO}/bin/security_gate.py")" 'endswith(("-team.txt", "-team.md"))'
check "git-context finds a markdown comms ledger" \
    "$(grep -c 'comms/\*-team.md' "${REPO}/bin/git-context.sh")" "1"
check "context-packet finds an hour-stamped plan" \
    "$(grep -c 'plans/\*\.md' "${REPO}/bin/context-packet.sh")" "1"
check "live boards are gitignored in both suffixes" \
    "$(grep -c 'comms/\*\.live\.md' "${REPO}/.gitignore")" "1"

# A nested `.agents/` (engine output written to the wrong tree) must never be committable: the one
# under `src/rag/` carried a private ML-DSA-65 key and a session PSK before it was noticed.
_nested_probe="$(mktemp -d "${TMPDIR:-/tmp}/nested-agents.XXXXXX")"
mkdir -p "${_nested_probe}/src/rag/.agents/audit"
touch "${_nested_probe}/src/rag/.agents/audit/signer.mldsa65.priv"
cp "${REPO}/.gitignore" "${_nested_probe}/.gitignore"
git -C "${_nested_probe}" init -q 2>/dev/null
if git -C "${_nested_probe}" check-ignore -q "src/rag/.agents/audit/signer.mldsa65.priv"; then
    ok "a nested .agents/ tree is gitignored (keys cannot be committed)"
else
    not_ok "a nested .agents/ tree is gitignored (keys cannot be committed)"
fi
rm -rf "${_nested_probe}"

# The reachable engine (rag.py) writes plain markdown and cannot produce the Obsidian vault, so it
# must refuse rather than overwrite one. Without this guard, a single `ainish-rag wiki` on a stock
# checkout strips frontmatter and every wikilink — deleting the graph retrieval depends on — and
# still reports success.
contains "python engine refuses to clobber an Obsidian vault" \
    "$(cat "${REPO}/src/rag/rag.py")" 'refusing to overwrite an Obsidian vault'
contains "the refusal names the vault tag it detected" \
    "$(cat "${REPO}/src/rag/rag.py")" 'VAULT_TAG = "ainish/wiki"'
check "wiki vector indexing is opt-in, not forced" \
    "$(grep -A 8 'Also index the generated wiki' "${REPO}/src/rag/src/main.rs" | grep -E '^\s*#\[arg' | grep -c 'default_value_t')" "0"

echo "== the vector subsystem is deleted, not dormant =="
# A retired path that is merely unreachable drifts back. These pin the deletion itself: no module,
# no crate, no subcommand, no embedding call — in either engine.
for gone in embed store ingest; do
    check "rust vector module removed: ${gone}.rs" \
        "$([[ -f "${REPO}/src/rag/src/${gone}.rs" ]] && echo present || echo absent)" "absent"
done
check "no vector crates remain in Cargo.toml" \
    "$(grep -cE '^(lancedb|arrow-schema|arrow-array) ' "${REPO}/src/rag/Cargo.toml")" "0"
check "python engine makes no embedding calls" \
    "$(grep -cE 'embed_one\(|embed_batch\(|search_vector\(|\.embed_one|LanceStore|EmbedClient' "${REPO}/src/rag/rag.py")" "0"
check "python engine has no local-model server startup" \
    "$(grep -cE 'def start_server|start_server\(' "${REPO}/src/rag/rag.py")" "0"
check "retrieval has no vector fallback branch" \
    "$(grep -c 'AINISH_RAG_VECTOR_FALLBACK' "${REPO}/src/rag/rag.py")" "0"
# A retired verb must explain itself rather than read as a typo.
contains "python names a retired verb as retired" \
    "$(cat "${REPO}/src/rag/rag.py")" 'was retired 2026-11-12'
contains "rust names a retired verb as retired" \
    "$(cat "${REPO}/src/rag/src/main.rs")" 'was retired 2026-11-12'

echo "== EGM reviewer independence (Google Elephant-Goldfish) =="
# The load-bearing rule: a reviewer with no independent model is not a reviewer. Refusing is the only
# report that cannot mislead; opt-in self-review is the recorded downgrade.
contains "reviewer separation is enforced before the call" \
    "$(cat "${REPO}/src/rag/rag.py")" 'def plan_reviewer_model'
contains "a collision is reported, not honoured" \
    "$(cat "${REPO}/src/rag/rag.py")" 'resolves to the same model the drafter used'
contains "self-review requires an explicit opt-in" \
    "$(cat "${REPO}/src/rag/rag.py")" 'AINISH_RAG_ALLOW_SELF_REVIEW'
check "self-review is not the default" \
    "$(grep -c 'AINISH_RAG_DISTINCT_REVIEWER' "${REPO}/src/rag/rag.py")" "0"
contains "the three-step protocol is present" \
    "$(cat "${REPO}/src/rag/rag.py")" '1. Comprehension check'
contains "readiness ends in a verdict" \
    "$(cat "${REPO}/src/rag/rag.py")" 'VERDICT: ready|not-ready'
contains "a failed step is named, not hidden" \
    "$(cat "${REPO}/src/rag/rag.py")" 'returned nothing'
contains "reviews get their own timeout" \
    "$(cat "${REPO}/src/rag/rag.py")" 'AINISH_RAG_REVIEW_TIMEOUT'
contains "context can refresh the vault before retrieval" \
    "$(cat "${REPO}/src/rag/rag.py")" '"--refresh-wiki"'

echo "== EGM roles run as pi agents =="
# The roles moved from an in-process chat call to pi subprocesses. The guards that make that safe are
# what this pins: no session (freshness), no tools (authority), thinking discarded (cost + honesty),
# attachments confined to the repo, and a missing pi degrading rather than crashing.
contains "roles call the pi agent runtime" \
    "$(cat "${REPO}/src/rag/rag.py")" 'def pi_agent_call('
contains "pi runs without a session so reviews are genuinely fresh" \
    "$(cat "${REPO}/src/rag/rag.py")" '"--no-session"'
contains "pi runs without tools so a context call cannot act" \
    "$(cat "${REPO}/src/rag/rag.py")" '"--no-tools"'
contains "thinking blocks are filtered out of the prime" \
    "$(cat "${REPO}/src/rag/rag.py")" 'block.get("type") == "text"'
contains "attachment paths are confined to the repo" \
    "$(cat "${REPO}/src/rag/rag.py")" 'candidate.relative_to(root)'
contains "attachments are size-capped" \
    "$(cat "${REPO}/src/rag/rag.py")" 'PI_MAX_ATTACH_BYTES'
contains "a missing pi degrades with a reason" \
    "$(cat "${REPO}/src/rag/rag.py")" 'pi not found'
contains "role briefs are full operating instructions" \
    "$(cat "${REPO}/src/rag/rag.py")" 'HARD RULES'
contains "the reviewer gets its own output ceiling" \
    "$(cat "${REPO}/src/rag/rag.py")" 'REVIEW_MAX_TOKENS'
contains "prd documents the pi-backed roles" \
    "$(cat "${REPO}/llms.txt")" 'run as `pi` agents'
check "the contract still names no engine internals" \
    "$(grep -cE '\bpi\b|local-router|openrouter' "${REPO}/AGENTS.md")" "0"

echo "== both EGM roles run on the local router =="
# Operator direction 2026-11-14: one model, two fresh contexts. What matters is that a same-model
# review is REPORTED as fresh-context rather than dressed up as independent-model, that a pin can
# still buy genuine independence, and that the served model is recorded when the request was a route.
contains "the default role model is the local router" \
    "$(cat "${REPO}/src/rag/rag.py")" 'PI_DEFAULT_MODEL = "local-router/fallback-models"'
contains "role resolution ignores the per-role rotation" \
    "$(cat "${REPO}/src/rag/rag.py")" 'deliberately NOT consulted here'
contains "same-model review is labelled fresh-context" \
    "$(cat "${REPO}/src/rag/rag.py")" '"fresh-context"'
contains "the router path runs with thinking off" \
    "$(cat "${REPO}/src/rag/rag.py")" 'PI_THINKING_IN_ROUTER'
contains "the served model is recorded, not assumed" \
    "$(cat "${REPO}/src/rag/rag.py")" '"served_model": served_model or model'
contains "the pair line names who actually served the review" \
    "$(cat "${REPO}/src/rag/rag.py")" 'served by'

echo "== wiki vault is Obsidian-native =="
# The vault format is a retrieval contract: without frontmatter and wikilinks Obsidian shows
# orphan files, and without a wikilink-aware reader `--context` loses every explicit edge.
contains "wiki pages emit frontmatter tags" "$(cat "${REPO}/src/rag/src/wiki.rs")" 'ainish/wiki'
contains "wiki pages emit wikilinks" "$(cat "${REPO}/src/rag/src/wiki.rs")" '[[{}|{}]]'
contains "the graph reader parses wikilinks" "$(cat "${REPO}/src/rag/rag.py")" 'WIKILINK_RE'
# A reader that ignores `[[...]]` is the exact regression this pair of patterns prevents.
contains "the graph reader still parses markdown links" "$(cat "${REPO}/src/rag/rag.py")" 'MDLINK_RE'
contains "navigation headings are excluded from nodes" "$(cat "${REPO}/src/rag/rag.py")" 'GRAPH_NAV_HEADINGS'
contains "code spans never count as links" "$(cat "${REPO}/src/rag/rag.py")" '_strip_code_spans'
contains "vault config is written once" "$(cat "${REPO}/src/rag/src/wiki.rs")" 'fn ensure_vault_config'
contains "a Rust test pins the vault format" "$(cat "${REPO}/src/rag/src/wiki.rs")" 'generated_vault_is_obsidian_native'
# The ledger is operator-owned and signed; generation must never rewrite it.
contains "ledger is spliced, not regenerated" "$(cat "${REPO}/src/rag/src/wiki.rs")" 'read_operator_ledger'


echo "== rules deploy verifies the manifest, not everything beside it =="
# At $HOME, `.agents/` also holds mcp-settings, a skill lock and contract history. Gating a rules
# deploy on the whole directory made `ainish-coder --rules ~` impossible: unrelated receipts failed
# and `ainish-deploy.json` was itself among the failures. A deploy answers only for what it wrote.
RULES_SYNC="${REPO}/src/deploy_rules_sync.sh"
contains "the gate verifies the manifest file" "$(cat "$RULES_SYNC")" 'verify_target="$(_ainish_rules_sign_arg "$rag" "$manifest")"'
if grep -qF 'verify_target="$(_ainish_rules_sign_arg "$rag" "$(dirname "$manifest")")"' "$RULES_SYNC"; then
    not_ok "the gate no longer sweeps the manifest's directory"
else
    ok "the gate no longer sweeps the manifest's directory"
fi

echo "== audit verify --path <file> verifies one file =="
# The gate above is only possible if a single-file verify exists: passing a file used to fall
# through to read_dir and die with NotADirectory, so no caller could check one artifact.
RAG_MAIN="${REPO}/src/rag/src/main.rs"
contains "a file path takes the single-file branch" "$(cat "$RAG_MAIN")" 'if audit_dir.is_file() {'
contains "a missing envelope fails that file" "$(cat "$RAG_MAIN")" 'missing signature envelope for {}'

echo "== a signer/anchor mismatch is named, never silently accepted =="
# resolve_or_create_seed invents a random, gitignored seed when neither the env var nor the vault
# has one, while the anchor stays committed. Every signature from such a machine is unverifiable,
# and the deploy must say so with both fingerprints instead of reporting integrity it lacks.
contains "anchor-check is a command" "$(cat "$RAG_MAIN")" 'AnchorCheck'
contains "the comparison exposes both keys" "$(cat "${REPO}/src/rag/src/pqc.rs")" 'fn anchor_signer_mismatch'
contains "the deploy reports the signer" "$(cat "$RULES_SYNC")" 'Signing key does not match the committed trust anchor'
# Rotation is a deliberate, reviewed act. A deploy that re-anchored itself would let any machine
# become the trust root as a side effect of installing rules.
if grep -qE 'chflags|write_anchor' <(echo "$(cat "$RULES_SYNC")"); then
    not_ok "the mismatch report never rotates the anchor"
else
    ok "the mismatch report never rotates the anchor"
fi

# ── the per-repo context harness ────────────────────────────────────────────
# Learning machinery is the easiest thing in this repository to let rot: it is opt-in, so nothing
# fails loudly when it stops working. These pin the properties the design turns on.
CH_MOD="${REPO}/src/rag/context_harness.py"
CH_TEST_REPO="${WORK}/context-harness-repo"
mkdir -p "${CH_TEST_REPO}/.agents/tasks" "${CH_TEST_REPO}/.agents/wiki"
git -C "${CH_TEST_REPO}" init -q 2>/dev/null
printf -- '- objective: make the parser read the sixteen byte header\n' \
    > "${CH_TEST_REPO}/.agents/tasks/2026-01-01-seed.md"
printf -- '# W\n\n## Parser header\nThe header holds the magic number.\n' \
    > "${CH_TEST_REPO}/.agents/wiki/01-a.md"

contains "harness bounds are declared as data" "$(cat "$CH_MOD")" 'BOUNDS: Dict[str, Tuple[float, float]]'
contains "harness state lives in a tracked path" "$(cat "$CH_MOD")" '"context-harness"'
# The tracked-path claim is only true if git agrees; `.agents/rag/` is ignored and would silently
# lose every learned generation on clone.
check "harness state is not gitignored" \
    "$(git -C "${REPO}" check-ignore -q .agents/context-harness/prime-profile.json && echo ignored || echo tracked)" \
    "tracked"
# A learned pack must never be swept by the rules deploy: it is absent from source BY DESIGN.
contains "the deploy sweep knows about learned packs" "$(cat "${REPO}/src/deploy_skills.sh")" '_skill_learned'
contains "the learned predicate matches the writing prefix" \
    "$(cat "${REPO}/src/skills_selection.sh")" 'learned-*'
# Skill authoring: the improver's skills arrive as literal text in <skill> blocks, never inside
# JSON. Requiring a model to escape newlines correctly inside a JSON string failed on every attempt,
# so the delimiter is part of the contract and is pinned here.
contains "skill bodies arrive as literal text blocks" "$(cat "${REPO}/src/rag/rag.py")" '<skill\s+name='
contains "a skill naming a measurement is refused" "$(cat "$CH_MOD")" 'names the measurement'
check "the skill cap is enforced in code" \
    "$(grep -c 'MAX_LIVE_SKILLS' "$CH_MOD")" "3"
check "learned scripts are restricted to an import allowlist" \
    "$(python3 -c '
import importlib.util, sys
spec = importlib.util.spec_from_file_location("ch", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print("yes" if m.SCRIPT_ALLOWED_IMPORTS and "subprocess" not in m.SCRIPT_ALLOWED_IMPORTS
      and "socket" not in m.SCRIPT_ALLOWED_IMPORTS else "no")' "$CH_MOD" 2>/dev/null)" \
    "yes"

seed_out=$( cd "${CH_TEST_REPO}" && python3 "${REPO}/src/rag/rag.py" context-seed --json 2>/dev/null )
check "context-seed reports success" \
    "$(printf '%s' "$seed_out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("seeded"))' 2>/dev/null)" \
    "True"
# Idempotency: a re-run must not overwrite a repository's own tuning.
seed_before=$(sha256sum "${CH_TEST_REPO}/.agents/context-harness/prime-profile.json" 2>/dev/null | cut -d' ' -f1)
( cd "${CH_TEST_REPO}" && python3 "${REPO}/src/rag/rag.py" context-seed >/dev/null 2>&1 )
seed_after=$(sha256sum "${CH_TEST_REPO}/.agents/context-harness/prime-profile.json" 2>/dev/null | cut -d' ' -f1)
check "context-seed is idempotent" "$([[ -n "$seed_before" && "$seed_before" == "$seed_after" ]] && echo yes || echo no)" "yes"

# The gate that makes rollout safe: with no profile, `--context` must be byte-identical to the
# shipped behaviour. Any added field except `provenance.harness` is a behaviour change to every repo.
cp "${CH_TEST_REPO}/.agents/context-harness/prime-profile.json" "${WORK}/profile.bak" 2>/dev/null
rm -f "${CH_TEST_REPO}/.agents/context-harness/prime-profile.json"
cp_before=$( cd "${CH_TEST_REPO}" && python3 "${REPO}/src/rag/rag.py" context --task "parser header" --retrieval-only --json 2>/dev/null )
cp_after=$( cd "${CH_TEST_REPO}" && python3 "${REPO}/src/rag/rag.py" context --task "parser header" --retrieval-only --json 2>/dev/null )
check "a repo with no profile reports source absent" \
    "$(printf '%s' "$cp_after" | python3 -c 'import json,sys; print(json.load(sys.stdin)["provenance"]["harness"]["source"])' 2>/dev/null)" \
    "absent"
check "the harness block is additive only" \
    "$(printf '%s' "$cp_after" | python3 -c '
import json,sys
d=json.load(sys.stdin)
p=d["provenance"]; p.pop("harness",None)
print(sorted(p))' 2>/dev/null | tr -d ' ')" \
    "$(printf '%s' "$cp_before" | python3 -c '
import json,sys
d=json.load(sys.stdin)
p=d["provenance"]; p.pop("harness",None)
print(sorted(p))' 2>/dev/null | tr -d ' ')"

# An out-of-bounds profile must be REFUSED and reported, never silently accepted.
python3 - "${CH_TEST_REPO}" <<'PYEOF' 2>/dev/null
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".agents" / "context-harness" / "prime-profile.json"
p.parent.mkdir(parents=True, exist_ok=True)
d = {"format": "ainish-rag/prime-profile/v1", "generation": 0,
     "graph": {"max_wiki_pages": 999, "max_artifacts": 2, "chapter_chars": 1400,
               "hop_bonus": 5.0, "recency_floor": 0.55, "shared_term_threshold": 3}}
p.write_text(json.dumps(d))
PYEOF
bad_out=$( cd "${CH_TEST_REPO}" && python3 "${REPO}/src/rag/rag.py" context --task "parser header" --retrieval-only --json 2>/dev/null )
check "an out-of-bounds profile is refused" \
    "$(printf '%s' "$bad_out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["provenance"]["harness"]["source"])' 2>/dev/null)" \
    "invalid: failed validation"
check "an invalid profile degrades the call, it does not fail it" \
    "$(printf '%s' "$bad_out" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["sections"]) > 0)' 2>/dev/null)" \
    "True"
check "an invalid profile falls back to the shipped tuning" \
    "$(printf '%s' "$bad_out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["provenance"]["harness"]["tuning"]["max_wiki_pages"])' 2>/dev/null)" \
    "8"

# Criterion leakage: a learned artefact naming the measurement must be refused. This is the
# practitioner video's round-3 failure, and the reason the improver is never told the signals.
contains "the leakage guard names the markers" "$(cat "$CH_MOD")" 'ACCEPTANCE_MARKERS'
check "a profile hint naming a measurement is refused" \
    "$(python3 -c '
import sys, importlib.util, pathlib
spec = importlib.util.spec_from_file_location("ch", "'"${CH_MOD}"'")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
prof = {"format": m.PROFILE_FORMAT, "generation": 1,
        "graph": {"max_wiki_pages": 8, "max_artifacts": 2, "chapter_chars": 1400,
                  "hop_bonus": 0.35, "recency_floor": 0.55, "shared_term_threshold": 3},
        "domain_prior": {"codebase_symbols": ["coverage"]}}
print("refused" if m.validate_profile(prof) else "accepted")' 2>/dev/null)" \
    "refused"
check "a skill body naming a measurement is refused" \
    "$(python3 -c '
import sys, importlib.util, pathlib
spec = importlib.util.spec_from_file_location("ch", "'"${CH_MOD}"'")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print("refused" if m._contains_acceptance_marker("raise the coverage number") else "accepted")' 2>/dev/null)" \
    "refused"

# The non-circular gate. Phase 0 proved prime-derived statistics are monotone in the knobs that
# produce them, so acceptance must consult an OUTCOME. If this function disappears, the loop has
# silently reverted to the circular design.
contains "acceptance consults an outcome signal" "$(cat "$CH_MOD")" 'def outcome_signal'
check "stale hints expire after enough unsupported generations" \
    "$(python3 -c '
import importlib.util, sys
spec = importlib.util.spec_from_file_location("ch", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
aged = m.age_hints(
    {"domain_prior": {"codebase_symbols": ["stale", "live"]},
     "hint_age": {"codebase_symbols": {"stale": 4, "live": 0}}},
    {"domain_prior": {"codebase_symbols": ["stale", "live"]}, "hint_age": {}})
out, dropped = m.expire_unsupported(aged, max_unsupported=5)
print("yes" if dropped and "stale" not in (out["domain_prior"]["codebase_symbols"]) else "no")' "$CH_MOD" 2>/dev/null)" \
    "yes"
contains "the learner refuses without an outcome signal" "$(cat "${REPO}/src/rag/rag.py")" 'no outcome signal available for this task'
# A malformed improver reply is an unusable answer, never a considered no-op.
contains "a malformed reply is not a KEEP_BASE" "$(cat "${REPO}/src/rag/rag.py")" 'followed neither protocol tag'

contains "rag help advertises the harness verbs" \
    "$(sed -n "$(grep -n 'The command agents call is:' "${REPO}/src/rag/rag.py" | head -1 | cut -d: -f1),+130p" "${REPO}/src/rag/rag.py")" \
    'context-learn'
check "the context-harness docs exist" \
    "$([[ -f "${REPO}/research/context-priming-master/08-phase0-findings.md" ]] && echo yes || echo no)" "yes"

# ── the whole corpus, and wiki pseudo-skills ────────────────────────────────
# The prime used to read 10 of 115 .agents files. These pin the coverage, the tracking that makes
# learned pages survive a clone, and the ranking that keeps a bigger corpus an improvement.
contains "the corpus includes the whole coordination history" "$(cat "${REPO}/src/rag/rag.py")" 'GRAPH_MAX_ARTIFACTS = 0'
contains "the corpus includes research and templates" "$(cat "${REPO}/src/rag/rag.py")" 'GRAPH_EXTRA_SOURCES'
contains "pseudo-skills live inside the wiki" "$(cat "$CH_MOD")" '.agents" / "wiki" / "skills'
contains "kinds are weighted so a wider corpus does not dilute" "$(cat "${REPO}/src/rag/rag.py")" 'GRAPH_KIND_WEIGHTS'
contains "recency is ranked per kind, not globally" "$(cat "${REPO}/src/rag/rag.py")" 'recency_kind'
# The gitignore rule that used to swallow every learned wiki page. If this negation disappears, a
# learner's work is silently untracked and dies on clone.
check "the root wiki is trackable" \
    "$(git -C "${REPO}" check-ignore -q .agents/wiki/skills/cheap-form-first.md && echo ignored || echo tracked)" \
    "tracked"
check "a nested wiki stays ignored" \
    "$(mkdir -p "${REPO}/src/rag/.agents/wiki" && touch "${REPO}/src/rag/.agents/wiki/probe.md" && \
       git -C "${REPO}" check-ignore -q src/rag/.agents/wiki/probe.md && echo ignored || echo tracked; \
       rm -rf "${REPO}/src/rag/.agents")" \
    "ignored"
check "every pseudo-skill validates" \
    "$(python3 -c '
import importlib.util, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location("ch", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
errs = m.validate_pseudo_skill_tree(Path(sys.argv[2]))
print("clean" if not errs else f"{len(errs)} error(s): {errs[0][:80]}")' "$CH_MOD" "${REPO}" 2>/dev/null)" \
    "clean"
check "at least six pseudo-skills abstracted from the sources" \
    "$(ls "${REPO}/.agents/wiki/skills"/*.md 2>/dev/null | wc -l | tr -d ' ')" \
    "6"
check "the corpus answers research questions it could not before" \
    "$(python3 "${REPO}/research/context-priming-master/probe_answer.py" 2>/dev/null | tail -1 | grep -c 'net +')" \
    "1"

# ── ONE COMMAND, and it improves itself ─────────────────────────────────────
# The contract tells an agent to call exactly one command. That command must therefore (a) surface the
# rules, and (b) keep the harness improving without a second invocation. Both are pinned here because
# either one silently regressing makes the single-command promise false.
contains "the contract is retrieval corpus" "$(cat "${REPO}/src/rag/rag.py")" 'GRAPH_CONTRACT_FILES'
check "AGENTS.md sections are retrievable as nodes" \
    "$(python3 -c '
import sys, importlib.util
from pathlib import Path
spec = importlib.util.spec_from_file_location("rag", sys.argv[1])
m = importlib.util.module_from_spec(spec); sys.modules["rag"] = m; spec.loader.exec_module(m)
g = m.build_wiki_graph(Path(sys.argv[2]))
print("yes" if any(n["kind"] == "contract" and "AGENTS.md" in n["path"] for n in g["nodes"]) else "no")' \
      "${REPO}/src/rag/rag.py" "${REPO}" 2>/dev/null)" \
    "yes"
contains "the contract states one command is the whole system" \
    "$(cat "${REPO}/AGENTS.md")" 'one command is the whole context system'
contains "the contract forbids a second priming command" \
    "$(cat "${REPO}/AGENTS.md")" 'Never call a second command to prime yourself'
contains "a context call spawns the learning pass" "$(cat "${REPO}/src/rag/rag.py")" 'def spawn_autolearn'
contains "the learning pass is detached, never awaited" "$(cat "${REPO}/src/rag/rag.py")" 'start_new_session'
check "the learning pass is throttled" \
    "$(python3 -c '
import importlib.util, sys
spec = importlib.util.spec_from_file_location("ch", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print("yes" if m.LEARN_MIN_INTERVAL_S > 0 and m.LEARN_MIN_NEW_COMMITS > 0 else "no")' "$CH_MOD" 2>/dev/null)" \
    "yes"
check "the spawned child cannot pollute the prime" \
    "$(grep -c '"stdout": subprocess.DEVNULL' "${REPO}/src/rag/rag.py")" "1"
check "a failed background pass still records its attempt" \
    "$(grep -c 'context_harness.record_autolearn(repo_root)' "${REPO}/src/rag/rag.py")" "2"
contains "no evidence means no learning pass" "$(cat "${REPO}/src/rag/rag.py")" 'no retrieved evidence to learn from'

# COMMS entries come in two delimiter styles, and orientation only understood one. A `---`-delimited
# ledger made it report its own frontmatter fence as "last entry", which is worse than silence: an
# agent reading that learns nothing about what just happened.
check "orientation parses both COMMS entry delimiters" \
    "$(python3 -c '
import sys, importlib.util, tempfile, pathlib
spec = importlib.util.spec_from_file_location("rag", sys.argv[1])
m = importlib.util.module_from_spec(spec); sys.modules["rag"] = m; spec.loader.exec_module(m)
with tempfile.TemporaryDirectory() as t:
    root = pathlib.Path(t)
    (root / ".agents" / "comms").mkdir(parents=True)
    from datetime import datetime, timezone
    day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    (root / ".agents" / "comms" / f"{day}-team.md").write_text(
        "---\nagent: x\n---\n- objective: do the thing\n- status: done\n")
    out = m.render_orientation_section(root, 2000)
    print("yes" if "status: done" in out and "objective: do the thing" in out else "no")' \
      "${REPO}/src/rag/rag.py" 2>/dev/null)" \
    "yes"
check "evidence and refusals are pruned, not accumulated" \
    "$(python3 -c '
import importlib.util, sys, tempfile, pathlib
spec = importlib.util.spec_from_file_location("ch", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
with tempfile.TemporaryDirectory() as t:
    root = pathlib.Path(t)
    work = root / "work"
    rej = root / "rejected"
    work.mkdir(); rej.mkdir()
    for i in range(14):
        (work / f"{i:04d}").mkdir()
    for i in range(60):
        (rej / f"{i:04d}.md").write_text("x")
    m.prune_work(root, keep=10, keep_rejected=50)
    print(len(list(work.iterdir())), len(list(rej.iterdir())))' "$CH_MOD" 2>/dev/null)" \
    "10 50"
contains "harness operational traces are gitignored" \
    "$(cat "${REPO}/.agents/context-harness/.gitignore" 2>/dev/null)" 'work/'

# ── commit identity: the operator is the only author ────────────────────────
# Two real failures on 2026-11-18, both in the guard itself:
#   * `ainish-coder bot` matched none of the harness names, so six merges kept a tool as their author.
#   * the guard's amend omitted `-S`, so it stripped the signature off every commit it repaired —
#     15 of 16 commits that day were unsigned, and the guard's own fix destroyed the evidence.
GUARD="${REPO}/scripts/commit-identity-guard.sh"
contains "the guard recognises our own tool as a harness" "$(cat "$GUARD")" 'ainish-coder'
contains "the guard re-signs the commit it rewrites" "$(cat "$GUARD")" 'sign_flag="-S"'
contains "a tool-shaped author is caught without a known name" "$(cat "$GUARD")" 'bot_email_pattern'

# Behavioural proof, not a grep: a repo authored by a tool must come out as the operator AND signed.
IDTEST="${WORK}/identity-guard-test"
rm -rf "$IDTEST"; mkdir -p "$IDTEST/scripts"; cd "$IDTEST" || exit 1
git init -q
git config user.name "ainish-coder bot"; git config user.email "bot@local"
git config commit.gpgsign false   # CI has no signing key; the re-author must still happen
cp "$GUARD" scripts/
printf '#!/bin/bash\nexec "$(git rev-parse --show-toplevel)/scripts/commit-identity-guard.sh"\n' > .git/hooks/post-commit
chmod +x .git/hooks/post-commit scripts/commit-identity-guard.sh
git add -A >/dev/null 2>&1
git commit -qm "tool-authored" >/dev/null 2>&1
check "a tool-authored commit is re-authored as the operator" \
    "$(git log -1 --format='%an')" "Nanoboozhoo - embodied by cursor"
check "an already-correct commit is left alone (no amend loop)" \
    "$(git commit --allow-empty -qm second >/dev/null 2>&1; git rev-list --count HEAD)" "2"
cd "$REPO" || exit 1

# ── the audit checker fails CLOSED ──────────────────────────────────────────
# The first version of this check was an indented heredoc inside the YAML `run:` block. YAML indents
# every line, so Python raised IndentationError, printed nothing, and the shell read that as
# "unparseable" — then exited 0. It passed a run while cargo-audit was reporting RUSTSEC-2026-0385 in
# a cryptography crate. Every branch is pinned here, because the failure mode is invisible.
CHECKER="${REPO}/.github/scripts/check_cargo_audit.py"
tmp_audit="${WORK}/audit-probe.json"

printf '%s' '{"database":{"advisory-count":1},"lockfile":{"dependency-count":5},"vulnerabilities":{"found":false,"count":0,"list":[]}}' > "$tmp_audit"
check "audit checker passes a clean tree" \
    "$(python3 "$CHECKER" "$tmp_audit" >/dev/null 2>&1; echo $?)" "0"

printf '%s' '{"database":{"advisory-count":1},"lockfile":{"dependency-count":5},"vulnerabilities":{"found":true,"count":1,"list":[{"advisory":{"id":"RUSTSEC-0000-0001"},"package":{"name":"badcrate","version":"1.0.0"}}]}}' > "$tmp_audit"
check "audit checker FAILS a vulnerable tree" \
    "$(python3 "$CHECKER" "$tmp_audit" >/dev/null 2>&1; echo $?)" "1"

: > "$tmp_audit"
check "audit checker fails closed on empty output" \
    "$(python3 "$CHECKER" "$tmp_audit" >/dev/null 2>&1; echo $?)" "2"

printf '%s' 'not json at all' > "$tmp_audit"
check "audit checker fails closed on unparseable output" \
    "$(python3 "$CHECKER" "$tmp_audit" >/dev/null 2>&1; echo $?)" "2"

contains "the audit decision is a real script, not a YAML heredoc" \
    "$(cat "${REPO}/.github/workflows/security.yml")" 'check_cargo_audit.py'
check "no python heredoc remains in the workflow" \
    "$(grep -cE '^[[:space:]]*python3 - <<' "${REPO}/.github/workflows/security.yml")" "0"

if (( FAIL > 0 )); then
    echo "FAILED: ${FAIL} assertion(s), ${PASS} passed"
    exit 1
fi
echo "PASS: ${PASS} assertion(s)"
