#!/bin/bash
# MOLECULE: Scroll Integrity (ML-DSA-65 signed manifests)
# Wraps scripts/scrolls/scroll_manifest.py per research/07-integration-contract.md
# C2-C4 and research/10-build-spec-integrity.md. Sourced from bin/ainish-coder
# next to deploy_scrolls.sh.
#
# Pipeline: manifest -> sign -> verify -> (operator confirm) -> deploy -> COMMS.
# Seeds arrive via AINISHCODER_SCROLL_SIGN_SEED / AINISHCODER_SCROLL_COUNCIL_SEED
# (hex 64); they are never echoed or written to disk.

_SCROLL_INTEGRITY_ENGINE="${REPO_DIR}/scripts/scrolls/scroll_manifest.py"
_SCROLL_UV_ARGS=(uv run --with 'cryptography>=46' python "${_SCROLL_INTEGRITY_ENGINE}")

# Run the engine, passing through all args.
_scroll_engine() {
    "${_SCROLL_UV_ARGS[@]}" "$@"
}

# scrolls_manifest <dir> — emit manifest.json for a payload dir.
scrolls_manifest() {
    local dir="${1:?usage: scrolls_manifest <dir>}"
    _scroll_engine manifest "$dir"
}

# scrolls_sign <dir> [--council] — sign manifest digest; echoes digest line.
scrolls_sign() {
    local dir="${1:?usage: scrolls_sign <dir> [--council]}"
    shift
    _scroll_engine sign "$dir" "$@"
}

# scrolls_verify <dir> — verify payload + signatures. Returns 0/1; prints
# the first failure reason when verification fails.
scrolls_verify() {
    local dir="${1:?usage: scrolls_verify <dir>}"
    local output rc
    output=$(_scroll_engine verify "$dir" 2>&1)
    rc=$?
    if [[ $rc -ne 0 ]]; then
        local first_failure
        first_failure=$(printf '%s\n' "$output" | grep -m1 '^  - ' | sed 's/^  - //')
        echo "${first_failure:-verification failed}"
        return 1
    fi
    echo "$output" | head -1
    return 0
}

# _scrolls_comms_append <file> <block> — append block with a leading blank
# line, creating the file's header if absent. Tolerates missing dirs/files.
_scrolls_comms_append() {
    local file="$1" block="$2"
    if [[ ! -d "$(dirname "$file")" ]]; then
        return 0
    fi
    touch "$file" 2>/dev/null || return 0
    {
        echo ""
        echo "$block"
    } >> "$file"
}

# scrolls_comms_log <event> <detail> — append a protocol block (format per
# AGENTS/{date}.COMMS.md PROTOCOL) to the durable ledger (worktree if present)
# AND the gitignored live board at the main repo path. Includes start:/end:
# ISO-8601 pairs, scope:.scrolls/, and the current manifest digest when one
# exists in the target dir (last arg, optional: <event> <detail> [payload_dir]).
scrolls_comms_log() {
    local event="${1:?usage: scrolls_comms_log <event> <detail> [payload_dir]}"
    local detail="${2:-}"
    local payload_dir="${3:-}"

    local now start_ts end_ts branch wt_path digest=""
    start_ts=$(date +%Y-%m-%dT%H:%M:%S%z)
    end_ts="$start_ts"

    # Ledger locations: durable copy lives in THIS worktree (if it has AGENTS/),
    # live board lives at the main repo path (gitignored, tolerate absence).
    local ledger_file live_file
    if [[ -d "${REPO_DIR}/AGENTS" ]]; then
        ledger_file="${REPO_DIR}/AGENTS/$(date +%Y-%m-%d).COMMS.md"
    else
        ledger_file=""
    fi
    # Main repo = worktree's parent project; the live board is per-DATE at the
    # main checkout's AGENTS/ dir.
    local main_repo_agents
    if git -C "${REPO_DIR}" rev-parse --git-common-dir > /dev/null 2>&1; then
        local common_dir
        common_dir=$(git -C "${REPO_DIR}" rev-parse --path-format=absolute --git-common-dir 2> /dev/null || echo "")
        main_repo_agents="$(cd "${common_dir}/.." 2> /dev/null && pwd)/AGENTS"
    else
        main_repo_agents="${REPO_DIR}/AGENTS"
    fi
    live_file="${main_repo_agents}/$(date +%Y-%m-%d).COMMS.live.md"

    branch=$(git -C "${REPO_DIR}" branch --show-current 2> /dev/null || echo "unknown")
    wt_path=$(git -C "${REPO_DIR}" rev-parse --show-toplevel 2> /dev/null || echo "${REPO_DIR}")

    # Manifest digest (SHA3-256 of manifest.json bytes) when a payload dir is
    # given and contains a manifest.
    if [[ -n "$payload_dir" && -f "$payload_dir/manifest.json" ]]; then
        digest=$(_scroll_engine verify --help > /dev/null 2>&1; python3 - "$payload_dir/manifest.json" <<'PYEOF'
import hashlib, sys
print(hashlib.sha3_256(open(sys.argv[1], "rb").read()).hexdigest())
PYEOF
        )
    fi

    local header_line="### [${start_ts}] ${event} | agent:IntegrityLayer | branch:${branch} | wt:${wt_path#${REPO_DIR%/}/}"
    local block="${header_line}
- start:${start_ts}
- end:${end_ts}
- scope:.scrolls/
- objective:${detail}"
    if [[ -n "$digest" ]]; then
        block+="
- manifest-digest:sha3-256:${digest}"
    fi

    _scrolls_comms_append "$ledger_file" "$block"
    _scrolls_comms_append "$live_file" "$block"
}
