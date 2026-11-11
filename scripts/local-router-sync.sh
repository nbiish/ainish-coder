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
#   scripts/local-router-sync.sh --capture  # take this machine's live chain back into the repo
#   scripts/local-router-sync.sh --from-text=chain.txt
#                                           # adopt a pasted list (one model id per line, the format
#                                           # of the router's #fallbackModelsText textarea) as canonical
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
CAPTURE=false
FROM_TEXT=""
# Launcher override: on Windows the CLI is `local-router.cmd` and is not on a Git-Bash PATH, so
# `command -v local-router` says "not installed" about a machine that has it.
LR_BIN="${LOCAL_ROUTER_BIN:-}"
if [[ -z "$LR_BIN" ]] && command -v local-router >/dev/null 2>&1; then LR_BIN="local-router"; fi
if [[ -z "$LR_BIN" ]] && command -v local-router.cmd >/dev/null 2>&1; then LR_BIN="local-router.cmd"; fi

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY=true ;;
        --verify)  VERIFY_ONLY=true ;;
        --capture) CAPTURE=true ;;
        --from-text=*) FROM_TEXT="${arg#--from-text=}" ;;
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
    # The count of advertised models says nothing about the chain. Read the route back from the
    # router's own config file, which it rewrites from live state: an empty chain here is the exact
    # failure that looked like a working router.
    local chain=0
    if [[ -f "$TARGET" ]] && [[ -n "$PY" ]]; then
        chain="$(${PY} - "$TARGET" <<'PYEOF'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    for r in d.get("routes", []):
        if r.get("id") == "fallback-models":
            print(len(r.get("models") or [])); break
    else:
        print(0)
except Exception:
    print(0)
PYEOF
)"
    fi
    if [[ "${chain:-0}" == "0" ]]; then
        echo "  ✗ fallback-models chain is EMPTY in $TARGET — the router rejected or overwrote the config"
        return 1
    fi
    # Non-empty is not enough: the router rewrites this file from its own state, so a stale or
    # reordered chain passes a count check while serving the wrong models.
    if [[ -n "$PY" ]]; then
        match="$(${PY} - "$CANON_PY" "$TARGET" <<'PYEOF'
import json, sys
def chain(p):
    d = json.load(open(p))
    for r in d.get("routes", []):
        if r.get("id") == "fallback-models":
            return list(r.get("models") or [])
    return []
print("same" if chain(sys.argv[1]) == chain(sys.argv[2]) else "differs")
PYEOF
)"
        if [[ "${match:-}" != "same" ]]; then
            echo "  ✗ served chain DIFFERS from the canonical ($TARGET was rewritten by the router)"
            echo "    canonical: $CANON"
            echo "    re-run with the router stopped, or start it as: $LR_BIN start --config ${BOOT_CFG:-$TARGET}"
            return 1
        fi
    fi
    echo "  ✓ fallback-models chain carries ${chain} model(s) and matches the canonical"
    return 0
}

if [[ -n "$FROM_TEXT" ]]; then
    # The router's config page is a textarea with one model id per line, and a trailing token marks a
    # disabled entry. Adopting a pasted list directly means the operator never hand-rewrites JSON.
    [[ -f "$FROM_TEXT" ]] || { echo "local-router-sync: no such file: $FROM_TEXT" >&2; exit 1; }
    [[ -n "$PY" ]] || { echo "local-router-sync: no python interpreter for --from-text" >&2; exit 1; }
    ${PY} - "$CANON_PY" "$FROM_TEXT" <<'PYEOF'
import json, sys
canon, text = sys.argv[1], sys.argv[2]
models = []
for raw in open(text, encoding="utf-8"):
    for token in raw.split():
        if token.lower() in ("disabled", "off", "false"):
            continue
        models.append(token.strip().strip(","))
models = [m for m in models if m]
if not models:
    print("refusing: the pasted list is empty", file=sys.stderr); raise SystemExit(1)
d = json.load(open(canon))
for r in d.get("routes", []):
    if r.get("id") == "fallback-models":
        r["models"] = models
        break
else:
    print("refusing: no fallback-models route in the canonical file", file=sys.stderr); raise SystemExit(1)
open(canon, "w").write(json.dumps(d, indent=2) + "\n")
print("adopted %d model(s) from %s" % (len(models), text))
PYEOF
    echo "now run the installer (no flags) to deploy, or commit and --machine-sync to publish"
    exit 0
fi

if [[ "$CAPTURE" == "true" ]]; then
    # The workflow this exists for: edit the chain in the router's UI on one machine, then make that
    # edit the canonical one. Refuses to capture an empty chain — that is the failure, not the input.
    [[ -f "$TARGET" ]] || { echo "local-router-sync: no chain at $TARGET to capture" >&2; exit 1; }
    live="$(${PY} - "$TARGET" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
for r in d.get("routes", []):
    if r.get("id") == "fallback-models":
        print(len(r.get("models") or [])); break
else:
    print(0)
PYEOF
)"
    if [[ "${live:-0}" == "0" ]]; then
        echo "local-router-sync: refusing to capture an empty fallback-models chain from $TARGET" >&2
        exit 1
    fi
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    cp -f "$CANON" "${CANON}.bak.${stamp}" 2>/dev/null || true
    cp -f "$TARGET" "$CANON" || { echo "local-router-sync: could not write $CANON" >&2; exit 1; }
    echo "captured ${live} model(s) from $TARGET -> $CANON"
    echo "commit config/local-router/fallback-models.json and run --machine-sync to publish it"
    exit 0
fi

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

# Mirror into the router's real settings file when it is a checkout install.
if [[ -n "$PY" ]]; then
    SETTINGS="$(lr_settings_file "$LR_BIN" 2>/dev/null || true)"
    if [[ -n "$SETTINGS" ]]; then
        ${PY} - "$CANON_PY" "$SETTINGS" <<'PYEOF'
import json, sys
canon, settings = sys.argv[1], sys.argv[2]
models = []
for r in json.load(open(canon)).get("routes", []):
    if r.get("id") == "fallback-models":
        models = list(r.get("models") or []); break
d = json.load(open(settings))
d["fallbackModelsText"] = "\n".join(models)
for r in d.get("routes", []):
    if r.get("id") == "fallback-models":
        r["models"] = models
open(settings, "w").write(json.dumps(d, indent=2) + "\n")
print("  ✓ wrote the chain into the router's own settings: %s" % settings)
PYEOF
    fi
fi

# The router's `--config`/LOCAL_ROUTER_ROUTES_CONFIG takes the DECLARATIVE shape
# {"fallbackModels": {"<route>": {"models": [...]}}} — not the persisted {"version":1,"routes":[...]}
# file. Handing it the persisted shape is silently ignored, and the router then rewrites the persisted
# file from its own (empty) state, which is how a machine ends up serving `fallback-models: []`.
# Derive the boot config from the one human-edited file so there is still a single source of truth.
BOOT_CFG=""
if [[ -n "$PY" ]]; then
    BOOT_CFG="${TARGET_DIR}/routes.boot.json"
    ${PY} - "$CANON_PY" "$BOOT_CFG" <<'PYEOF'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
d = json.load(open(src))
# A route with fewer than two unique models is invalid and the router rejects the ENTIRE config for
# it ("Fallback route requires at least two unique model entries") — which is why an otherwise good
# boot file silently fell back to `ensure`. Only ship routes that can pass validation.
routes = {}
for r in d.get("routes", []):
    models = list(dict.fromkeys(r.get("models") or []))
    if len(models) >= 2:
        routes[r["id"]] = {"models": models}
boot = {"fallbackModels": routes}
open(dst, "w").write(json.dumps(boot, indent=2) + "\n")
print("  boot config: %s routes -> %s" % (len(routes), dst))
PYEOF
fi

if [[ -n "$LR_BIN" ]]; then
    port="${LOCAL_ROUTER_PORT:-11434}"
    wait_port_free() {
        local i
        for i in 1 2 3 4 5 6 7 8 9 10; do
            if ! curl -sS -m 1 -o /dev/null "http://127.0.0.1:${port}/v1/models" 2>/dev/null; then return 0; fi
            sleep 1
        done
        return 1
    }
    "$LR_BIN" stop >/dev/null 2>&1 || true
    wait_port_free || echo "  · port ${port} still answering after stop; restarting anyway"

    boot_arg="${BOOT_CFG:-$TARGET}"
    [[ "$LR_BIN" == *.cmd ]] && boot_arg="$(cygpath -w "$boot_arg")"

    started=false
    for attempt in 1 2; do
        if "$LR_BIN" start --config "$boot_arg" >/dev/null 2>&1; then started=true; break; fi
        # A start that races the port closing loses; give it a moment and try once more before
        # falling back to `ensure`, which DROPS --config and lets the router rewrite the file from
        # its own state. That fallback is what silently served a stale chain.
        sleep 2
    done

    if [[ "$started" == "true" ]]; then
        echo "  ✓ router restarted with --config $boot_arg"
    elif "$LR_BIN" ensure >/dev/null 2>&1; then
        echo "  ! restarted with 'local-router ensure' — NO --config, the served chain may differ" >&2
    else
        echo "  ! router did not restart; run '$LR_BIN start --config $boot_arg' so the chain reloads" >&2
    fi
fi

sleep 2
verify_chain
