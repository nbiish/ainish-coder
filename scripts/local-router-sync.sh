#!/usr/bin/env bash
# local-router-sync.sh — make every machine resolve local-router/fallback-models to the SAME chain.
#
# WHY
# ---
# `ainish-rag`'s driver chain head is `local-router/fallback-models`, i.e. a route whose contents live
# in the router's own config, not in the repo. So the rules were synced across machines while the
# model chain they depend on was not: the Windows box ended up with `fallback-models: []` — a route
# that resolves to nothing — and its embedding order reversed against the Mac's. The agent pair then
# ran on whatever the machine happened to have, or on nothing.
#
# The chain is configuration, not a secret: it is model ids. Keys stay per-machine, entered through
# the router's own config page, and are never copied by this script. The repo copy is authoritative;
# each machine installs it into the router's user config and restarts, so `local-router/fallback-models`
# means the same thing everywhere `--machine-sync` has been run.
#
# USAGE
#   scripts/local-router-sync.sh            # install repo chain, restart router, verify
#   scripts/local-router-sync.sh --dry-run  # show what would change
#   scripts/local-router-sync.sh --verify   # verify only, no writes
#
# A machine with no `local-router` binary is reported and skipped, not failed: the repo is the source
# of truth and an unrelated host should not be marked broken for not running the router.
set -uo pipefail

# Interpreter probe: Git-for-Windows has no `python3`, and a guard that fails because it could not
# find an interpreter reads as "the chain is empty" — the opposite of the truth.
lr_py() {
    local c
    # `command -v` is not proof: Windows ships Microsoft Store shims named python3/python that exist,
    # fail on every invocation, and would make this script report an empty chain. Test, then trust.
    for c in python3 python; do
        if command -v "$c" >/dev/null 2>&1 && "$c" -c 'print(1)' >/dev/null 2>&1; then
            printf '%s\n' "$c"; return 0
        fi
    done
    if command -v py >/dev/null 2>&1 && py -3 -c 'print(1)' >/dev/null 2>&1; then
        printf 'py -3\n'; return 0
    fi
    return 1
}
PY="$(lr_py || true)"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANON="${REPO}/config/local-router/fallback-models.json"
TARGET_DIR="${LOCAL_ROUTER_CONFIG_DIR:-${HOME}/.config/local-router}"
TARGET="${TARGET_DIR}/fallback-models.json"
BACKUP_DIR="${TARGET_DIR}/backups"
DRY=false
VERIFY_ONLY=false
# Launcher override: on Windows the CLI is `local-router.cmd` and is not on a Git-Bash PATH, so
# `command -v local-router` says "not installed" about a machine that has it.
LR_BIN="${LOCAL_ROUTER_BIN:-}"
if [[ -z "$LR_BIN" ]] && command -v local-router >/dev/null 2>&1; then LR_BIN="local-router"; fi
if [[ -z "$LR_BIN" ]] && command -v local-router.cmd >/dev/null 2>&1; then LR_BIN="local-router.cmd"; fi

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY=true ;;
        --verify)  VERIFY_ONLY=true ;;
        -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "local-router-sync: unknown option $arg" >&2; exit 1 ;;
    esac
done

[[ -f "$CANON" ]] || { echo "local-router-sync: canonical chain missing: $CANON" >&2; exit 1; }

if [[ -z "${PY:-}" ]]; then
    echo "local-router-sync: no python interpreter found (python3/python/py)" >&2
    exit 1
fi

# Native Windows python cannot open a /d/... path; hand it a Windows path.
CANON_PY="$CANON"
if command -v cygpath >/dev/null 2>&1; then CANON_PY="$(cygpath -w "$CANON")"; fi

canon_models="$(${PY} -c "
import json,sys
d=json.load(open(sys.argv[1]))
for r in d['routes']:
    if r['id']=='fallback-models':
        print(len(r['models']))
        break
" "$CANON_PY" 2>/dev/null)"

if [[ -z "${canon_models:-}" || "$canon_models" == "0" ]]; then
    echo "local-router-sync: canonical chain has no models — refusing to deploy an empty route" >&2
    exit 1
fi
echo "canonical: $canon_models models from $CANON"

verify_chain() { # 0 when the live router serves the canonical route
    [[ -n "$LR_BIN" ]] || { echo "  · local-router not installed here — skipped"; return 3; }
    local port="${LOCAL_ROUTER_PORT:-11434}"
    local ids
    ids="$(curl -sS -m 6 "http://127.0.0.1:${port}/v1/models" 2>/dev/null | ${PY:-python3} -c "
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    print(''); raise SystemExit(0)
print(len(d.get('data') or []))
" 2>/dev/null)"
    if [[ -z "$ids" ]]; then
        echo "  · router not answering on :${port} — start it with 'local-router ensure'"
        return 1
    fi
    echo "  ✓ router on :${port} advertises ${ids} model(s)"
    return 0
}

if [[ "$VERIFY_ONLY" == "true" ]]; then
    verify_chain
    exit $?
fi

[[ -n "$LR_BIN" ]] || { echo "local-router not installed on this machine — config staged, nothing to restart"; exit 0; }

if [[ "$DRY" == "true" ]]; then
    echo "would back up ${TARGET} -> ${BACKUP_DIR}/fallback-models.json.$(date -u +%Y%m%dT%H%M%SZ)"
    echo "would write ${CANON} -> ${TARGET} and restart the router"
    exit 0
fi

mkdir -p "$TARGET_DIR" "$BACKUP_DIR"
if [[ -f "$TARGET" ]]; then
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    cp -f "$TARGET" "${BACKUP_DIR}/fallback-models.json.${stamp}" && echo "  · backed up previous chain -> ${BACKUP_DIR}/fallback-models.json.${stamp}"
fi

# Copy, not symlink: Windows cannot create one without elevation, and the router rewrites this file
# when the operator edits chains in its UI — a copy keeps the router's writes local and the repo clean.
cp -f "$CANON" "$TARGET" || { echo "local-router-sync: could not write $TARGET" >&2; exit 1; }
echo "  ✓ installed canonical chain -> $TARGET"

if [[ -n "$LR_BIN" ]]; then
    if [[ "$LR_BIN" == *.cmd ]]; then
        "$LR_BIN" stop >/dev/null 2>&1 || true
        if "$LR_BIN" start --config "$(cygpath -w "$TARGET")" >/dev/null 2>&1; then
            echo "  ✓ router restarted with --config $TARGET"
        else
            echo "  ! router did not restart; run '$LR_BIN start --config $TARGET' so the chain reloads" >&2
        fi
    else
        "$LR_BIN" stop >/dev/null 2>&1 || true
        if "$LR_BIN" start --config "$TARGET" >/dev/null 2>&1; then
            echo "  ✓ router restarted with --config $TARGET"
        elif "$LR_BIN" ensure >/dev/null 2>&1; then
            echo "  ✓ router restarted with 'local-router ensure'"
        else
            echo "  ! router did not restart; start it manually so /fallback-models reloads" >&2
        fi
    fi
fi

sleep 2
verify_chain
