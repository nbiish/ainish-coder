#!/bin/bash
# machine_sync — federate a git repository across capacity-named machines.
#
# WHY THIS EXISTS
# ---------------
# The same repository is worked on several machines — by the operator and by agents. Git's own answer
# is a remote: commit, push, switch machine, pull. That is a round trip through a third party for
# work that never needed to leave the LAN, and it silently excludes the most valuable state on the
# machine: the uncommitted work. A dirty tree is where an agent's half-finished reasoning lives, and
# git has nowhere to put it, so it stays on one machine until someone remembers to commit.
#
# `--machine-sync` moves the repository directly to its peers over the SSH link that already exists,
# and treats uncommitted work as a first-class payload. Before bundling it snapshots the working tree
# into a commit on a per-machine ref, so a dirty tree here becomes a readable branch there.
#
# NOTHING ON THE PEER MOVES. No branch is updated, no working tree is touched, no checkout happens.
# What lands is refs and nothing else:
#
#   refs/remotes/<machine>/<branch>        every branch of the sender, as remote-tracking refs
#   refs/machine-sync/<machine>/<branch>   the sender's uncommitted work, as a snapshot commit
#   refs/machine-sync/<machine>/<branch>   (both directions use the same namespace)
#
# Ignored files never cross. A git bundle carries commits, not a directory tree, so build output,
# vector indexes, signing keys, and .env files stay where they were built. That is the whole reason
# this is a git operation and not `rsync`: a copy would move a Windows .exe onto a macOS host and a
# machine-local signing key into someone else's repository.
#
# MACHINE NAMES CARRY CAPACITY
# ----------------------------
# Peers are named `<kind>[-<accelerator>]-<ram>gb` (mac-18gb, windows-128gb, wsl-94gb,
# cloud-a100-80gb). The number is the RAM a job can actually be given, so a caller can select a peer
# by capacity instead of by remembering which host is big: `--min-ram 64`.

: "${AINISH_MACHINES_FILE:=${AINISH_SYNC_CONFIG:-$HOME/.config/ainish-coder/machines.txt}}"

_MS_NAMES=()
_MS_SPECS=()
_MS_AS=""
_MS_DIRECTION="both"
_MS_SELF=""
_MS_JSON=false
_MS_PEER_REF=""
_MS_PEER_BRANCH=""

_ms_err()  { printf 'machine-sync: %s\n' "$*" >&2; }
_ms_ok()   { [[ "$_MS_JSON" == "true" ]] || printf '  %b✓%b %s\n' "${GREEN:-}" "${RESET:-}" "$*"; }
_ms_skip() { [[ "$_MS_JSON" == "true" ]] || printf '  %b·%b %s\n' "${YELLOW:-}" "${RESET:-}" "$*"; }
_ms_head() { [[ "$_MS_JSON" == "true" ]] || printf '%b%s%b\n' "${BRIGHT_BLUE:-}" "$*" "${RESET:-}"; }

_ms_usage() {
    cat <<'EOF'
ainish-coder --machine-sync — federate this repository with its peer machines

USAGE:
    ainish-coder --machine-sync [DIR] [OPTIONS]

OPTIONS:
    --machine NAME         Sync with NAME only (repeatable). Default: every peer in the registry.
    --min-ram GB           Only peers whose capacity name is at least GB (mac-18gb -> 18).
    --kind KIND            Only peers of this kind (mac | windows | wsl | cloud | linux).
    --as NAME              This machine's name in the registry (default: the line marked `self`).
    --peer-path NAME=PATH  Override where NAME keeps this repository (default: <root>/<repo name>).
    --push                 Send only: our branches and uncommitted work to the peers.
    --pull                 Receive only: peer branches and their uncommitted work to here.
    --both                 Send and receive (default).
    --status               Report what is already known here. No network, no transfer.
    --dry-run              Print the plan and exit without moving anything.
    --json                 Machine-readable summary on stdout.
    --machines-file PATH   Registry to read (default: ~/.config/ainish-coder/machines.txt).
    -h, --help             This text.

WHAT CROSSES:
    refs/remotes/<machine>/*      every branch the other machine has
    refs/machine-sync/<machine>/* its uncommitted work, snapshotted as a commit
    refs/tags/*                   tags

WHAT NEVER CROSSES:
    ignored files (build output, .exe, .env, vector indexes, signing keys) — they are not in git
    the peers' branch heads, HEAD, working tree, or index — nothing on the peer moves

EXIT: 0 every peer synced · 1 a peer failed (the others still ran)
EOF
}

# ── identity ─────────────────────────────────────────────────────────────────

_ms_kind() {
    case "$(uname -s 2>/dev/null)" in
        Darwin)                printf 'mac\n' ;;
        Linux)                 if grep -qi microsoft /proc/version 2>/dev/null; then printf 'wsl\n'; else printf 'linux\n'; fi ;;
        MINGW*|MSYS*|CYGWIN*)  printf 'windows\n' ;;
        *)                     printf 'unknown\n' ;;
    esac
}

_ms_ram_gb() {
    if [[ "$(_ms_kind)" == "mac" ]]; then
        sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0f", $1/1073741824}'
    else
        awk '/^MemTotal:/{printf "%.0f", $2/1048576}' /proc/meminfo 2>/dev/null
    fi
}

# Capacity number out of a machine name; empty when the name carries none.
_ms_name_ram() {
    local n="$1"
    if [[ "$n" =~ -([0-9]+)gb$ ]]; then printf '%s\n' "${BASH_REMATCH[1]}"; fi
}

# ── registry ─────────────────────────────────────────────────────────────────

_ms_load_registry() {
    local file="$1" line name spec
    _MS_NAMES=()
    _MS_SPECS=()
    [[ -f "$file" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="$(printf '%s' "$line" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        [[ -z "$line" ]] && continue
        [[ "$line" == *=* ]] || continue
        name="$(printf '%s' "${line%%=*}" | tr -d '[:space:]')"
        spec="$(printf '%s' "${line#*=}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        [[ -z "$name" || -z "$spec" ]] && continue
        _MS_NAMES+=("$name")
        _MS_SPECS+=("$spec")
    done < "$file"
    (( ${#_MS_NAMES[@]} > 0 ))
}

# Parse a transport spec into _P_LOCAL / _P_HOST / _P_ROOT.
#   self            -> this machine, no root recorded
#   /abs/root       -> another checkout on this machine
#   host:/abs/root  -> SSH peer, POSIX root
#   host:D:/root    -> SSH peer, Windows root
_ms_parse_spec() {
    local spec="$1"
    _P_LOCAL=false
    _P_HOST=""
    _P_ROOT=""
    case "$spec" in
        self) _P_LOCAL=true; return 0 ;;
    esac
    if [[ "$spec" == /* || "$spec" == "~"* ]]; then
        _P_LOCAL=true
        _P_ROOT="$spec"
        return 0
    fi
    if [[ "$spec" =~ ^([^/:]+):(.+)$ ]]; then
        local h="${BASH_REMATCH[1]}" r="${BASH_REMATCH[2]}"
        if [[ "$r" == /* || "$r" == "~"* || "$r" =~ ^[A-Za-z]: ]]; then
            _P_LOCAL=false
            _P_HOST="$h"
            _P_ROOT="$r"
            return 0
        fi
    fi
    _ms_err "cannot parse machine spec: $spec"
    return 1
}

_ms_self_name() {
    local i
    if [[ -n "${_MS_AS:-}" ]]; then printf '%s\n' "$_MS_AS"; return 0; fi
    for i in "${!_MS_NAMES[@]}"; do
        if [[ "${_MS_SPECS[$i]}" == "self" ]]; then printf '%s\n' "${_MS_NAMES[$i]}"; return 0; fi
    done
    printf '%s-%sgb\n' "$(_ms_kind)" "$(_ms_ram_gb)"
}

# ── git plumbing ─────────────────────────────────────────────────────────────

# Snapshot the working tree (tracked + untracked-not-ignored) into a commit without touching HEAD,
# the index, or the working tree. Echoes the commit. Returns 3 when there is nothing uncommitted.
_ms_wip_snapshot() {
    local repo="$1" branch="$2" ref="$3" idx tree head commit un em
    idx="$(mktemp "${TMPDIR:-/tmp}/ainish-ms-idx.XXXXXX" 2>/dev/null)" || return 1
    # Seed from the real index instead of starting empty. A fresh index re-derives every file's mode
    # from the filesystem, and on Windows (core.fileMode=false, no POSIX bits on NTFS) that turns a
    # clean tree into 50+ phantom "modified" entries with zero line changes. Copying the index keeps
    # the recorded modes and still captures staged edits.
    local real_idx
    real_idx="$(git -C "$repo" rev-parse --path-format=absolute --git-path index 2>/dev/null || echo "${repo}/.git/index")"
    if [[ -f "$real_idx" ]]; then
        cp -f "$real_idx" "$idx" 2>/dev/null || rm -f "$idx"
    else
        rm -f "$idx"
    fi
    if ! GIT_INDEX_FILE="$idx" git -C "$repo" add -A >/dev/null 2>&1; then
        rm -f "$idx"
        return 1
    fi
    tree="$(GIT_INDEX_FILE="$idx" git -C "$repo" write-tree 2>/dev/null)" || { rm -f "$idx"; return 1; }
    rm -f "$idx"
    [[ -n "$tree" ]] || return 1

    head="$(git -C "$repo" rev-parse -q --verify HEAD 2>/dev/null || true)"
    if [[ -n "$head" ]]; then
        local head_tree
        head_tree="$(git -C "$repo" rev-parse -q --verify "${head}^{tree}" 2>/dev/null || true)"
        [[ "$head_tree" == "$tree" ]] && return 3
    fi

    un="$(git -C "$repo" config user.name 2>/dev/null || true)"
    em="$(git -C "$repo" config user.email 2>/dev/null || true)"
    un="${un:-ainish-machine-sync}"
    em="${em:-machine-sync@ainish.local}"

    local -a parents=()
    [[ -n "$head" ]] && parents=(-p "$head")
    commit="$(git -C "$repo" -c user.name="$un" -c user.email="$em" \
        commit-tree "$tree" "${parents[@]}" \
        -m "wip(${_MS_SELF:-unknown}): uncommitted work on ${branch} at $(date -u +%Y-%m-%dT%H:%M:%SZ)")" || return 1
    git -C "$repo" update-ref "$ref" "$commit" || return 1
    printf '%s\n' "$commit"
}

# Create a self-contained bundle of branches, tags, and machine-sync snapshots.
# Returns 3 when there is nothing to send yet.
_ms_bundle_create() {
    local repo="$1" out="$2" any
    any="$(git -C "$repo" for-each-ref --count=1 --format='%(refname)' refs/heads 'refs/machine-sync/*' 2>/dev/null || true)"
    if [[ -z "$any" ]] && ! git -C "$repo" rev-parse -q --verify HEAD >/dev/null 2>&1; then
        return 3
    fi
    git -C "$repo" bundle create "$out" --branches --tags '--glob=refs/machine-sync/*' >/dev/null 2>&1
}

_ms_fetch_refspecs() { # machine
    printf '%s\n' \
        "+refs/heads/*:refs/remotes/$1/*" \
        "+refs/machine-sync/*:refs/machine-sync/*" \
        "+refs/tags/*:refs/tags/*"
}

_ms_remote() { # host command
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$1" "$2"
}

_ms_rm_cmd() { # path -> a remote-shell command that deletes it
    local p="$1"
    if [[ "$p" =~ ^[A-Za-z]: ]]; then
        printf "Remove-Item -LiteralPath '%s' -Force -ErrorAction SilentlyContinue\n" "$p"
    else
        printf "rm -f '%s'\n" "$p"
    fi
}

_ms_peer_reachable() { # host path
    local host="$1" path="$2"
    if [[ -z "$host" ]]; then
        [[ -d "${path}/.git" ]]
        return
    fi
    _ms_remote "$host" "git -C '${path}' rev-parse --git-dir" >/dev/null 2>&1
}

# ── remote snapshot ──────────────────────────────────────────────────────────
#
# The pull direction must snapshot the PEER's dirty tree, on the peer, without disturbing it. That
# cannot assume the peer runs this version of ainish-coder: a machine that has not synced yet is
# exactly the machine someone is pulling from. So it is done with plain git plumbing over three
# round trips, in the peer's own shell (POSIX sh, or PowerShell on Windows).

_ms_snap_cmd() { # path -> a command that writes a tree object and prints its SHA
    local path="$1"
    local idx="${path}/.git/ainish-ms.idx"
    if [[ "$path" =~ ^[A-Za-z]: ]]; then
        # Windows only: seed the temp index from the real one. NTFS has no POSIX exec bits and
        # core.fileMode is false there, so a from-scratch `git add -A` re-derives every mode and
        # reports a clean tree as 50+ phantom modifications with zero line changes. Copying the
        # recorded index keeps the modes and still captures staged edits.
        printf "\$src = git -C '%s' rev-parse --path-format=absolute --git-path index; Copy-Item -LiteralPath \$src -Destination '%s' -Force -ErrorAction SilentlyContinue; \$env:GIT_INDEX_FILE='%s'; git -C '%s' add -A 2>&1 | Out-Null; git -C '%s' write-tree; Remove-Item -LiteralPath '%s' -Force -ErrorAction SilentlyContinue\n" \
            "$path" "$idx" "$idx" "$path" "$path" "$idx"
    else
        # POSIX: exec bits are real, so a from-scratch index records the true modes.
        printf "GIT_INDEX_FILE='%s' git -C '%s' add -A >/dev/null 2>&1; GIT_INDEX_FILE='%s' git -C '%s' write-tree; rm -f '%s'\n" \
            "$idx" "$path" "$idx" "$path" "$idx"
    fi
}

# Drop the peer-side snapshot ref for a branch whose tree is now clean, and the local copy of it.
_ms_drop_stale_snapshot() { # host path ref
    local host="$1" path="$2" ref="$3"
    if [[ -z "$host" ]]; then
        git -C "$path" update-ref -d "$ref" 2>/dev/null || true
    else
        _ms_remote "$host" "git -C '${path}' update-ref -d '${ref}'" >/dev/null 2>&1 || true
    fi
    return 0
}

_ms_peer_branch() { # host path
    local host="$1" path="$2"
    if [[ -z "$host" ]]; then
        git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null
    else
        _ms_remote "$host" "git -C '${path}' rev-parse --abbrev-ref HEAD" 2>/dev/null | tr -d '\r'
    fi
}

# Snapshot the peer's working tree onto refs/machine-sync/<peer>/<branch> inside the PEER's repo.
# Returns 3 when the peer's tree is clean, 1 on failure.
_ms_snapshot_peer() { # host path peer
    local host="$1" path="$2" peer="$3"
    local branch ref tree head commit un em rc
    branch="$(_ms_peer_branch "$host" "$path")"
    branch="${branch:-detached}"
    ref="refs/machine-sync/${peer}/${branch}"
    _MS_PEER_REF="$ref"
    _MS_PEER_BRANCH="$branch"

    if [[ -z "$host" ]]; then
        _ms_wip_snapshot "$path" "$branch" "$ref" >/dev/null || rc=$?
        rc="${rc:-0}"
        (( rc == 3 )) && _ms_drop_stale_snapshot "" "$path" "$ref"
        return $rc
    fi

    tree="$(_ms_remote "$host" "$(_ms_snap_cmd "$path")" 2>/dev/null | tr -d '\r' | tail -1)"
    [[ "$tree" =~ ^[0-9a-f]{40}$ ]] || return 1
    head="$(_ms_remote "$host" "git -C '${path}' rev-parse -q --verify HEAD" 2>/dev/null | tr -d '\r')"
    if [[ -n "$head" ]]; then
        local head_tree
        head_tree="$(_ms_remote "$host" "git -C '${path}' rev-parse -q --verify '${head}^{tree}'" 2>/dev/null | tr -d '\r')"
        if [[ "$head_tree" == "$tree" ]]; then
            _ms_drop_stale_snapshot "$host" "$path" "$ref"
            return 3
        fi
    fi
    un="ainish-machine-sync"
    em="machine-sync@ainish.local"
    local parents=""
    [[ -n "$head" ]] && parents="-p ${head}"
    commit="$(_ms_remote "$host" "git -C '${path}' -c user.name='${un}' -c user.email='${em}' commit-tree '${tree}' ${parents} -m 'wip(${peer}): uncommitted work on ${branch}'" 2>/dev/null | tr -d '\r' | tail -1)"
    [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || return 1
    _ms_remote "$host" "git -C '${path}' update-ref '${ref}' '${commit}'" >/dev/null 2>&1 || return 1
    return 0
}

# ── transfer ─────────────────────────────────────────────────────────────────

_ms_push() { # repo host peer_path peer_name bundle
    local repo="$1" host="$2" path="$3" peer="$4" bundle="$5"
    local remote_bundle="${path}/.git/ainish-machine-sync.bundle"
    local -a specs=()
    local s
    while IFS= read -r s; do [[ -n "$s" ]] && specs+=("$s"); done < <(_ms_fetch_refspecs "$_MS_SELF")

    if [[ -z "$host" ]]; then
        cp -f "$bundle" "$remote_bundle" || return 1
        git -C "$path" fetch "$remote_bundle" "${specs[@]}" >/dev/null 2>&1
        local rc=$?
        rm -f "$remote_bundle"
        return $rc
    fi

    scp -q -o BatchMode=yes -o ConnectTimeout=10 "$bundle" "${host}:${remote_bundle}" || return 1
    _ms_remote "$host" "git -C '${path}' fetch '${remote_bundle}' $(printf "'%s' " "${specs[@]}")" >/dev/null 2>&1
    local rc=$?
    _ms_remote "$host" "$(_ms_rm_cmd "$remote_bundle")" >/dev/null 2>&1 || true
    return $rc
}

_ms_pull() { # repo host peer_path peer_name bundle
    local repo="$1" host="$2" path="$3" peer="$4" bundle="$5"
    local remote_bundle="${path}/.git/ainish-machine-sync.bundle"
    local -a specs=()
    local s
    while IFS= read -r s; do [[ -n "$s" ]] && specs+=("$s"); done < <(_ms_fetch_refspecs "$peer")

    # Snapshot the peer's uncommitted work first, so the bundle carries it.
    local snap_rc=0
    _ms_snapshot_peer "$host" "$path" "$peer" || snap_rc=$?
    if (( snap_rc == 1 )); then
        _ms_err "could not snapshot ${peer}'s working tree; pulling branches only"
    fi

    if [[ -z "$host" ]]; then
        _ms_bundle_create "$path" "$bundle"
        local brc=$?
        (( brc == 3 )) && return 3
        (( brc != 0 )) && return $brc
    else
        _ms_remote "$host" "git -C '${path}' bundle create '${remote_bundle}' --branches --tags '--glob=refs/machine-sync/*'" >/dev/null 2>&1 || return 1
        scp -q -o BatchMode=yes -o ConnectTimeout=10 "${host}:${remote_bundle}" "$bundle" || return 1
        _ms_remote "$host" "$(_ms_rm_cmd "$remote_bundle")" >/dev/null 2>&1 || true
    fi

    git -C "$repo" fetch "$bundle" "${specs[@]}" >/dev/null 2>&1 || return 1
    # The peer's tree is clean: forget the local copy of its old snapshot so nothing stale surfaces.
    if (( snap_rc == 3 )) && [[ -n "$_MS_PEER_REF" ]]; then
        git -C "$repo" update-ref -d "$_MS_PEER_REF" 2>/dev/null || true
    fi
    return 0
}

# ── reporting ────────────────────────────────────────────────────────────────

_ms_report_peer() { # repo peer
    local repo="$1" peer="$2" n=0 s sha subject ahead
    n="$(git -C "$repo" for-each-ref --format='%(refname)' "refs/remotes/${peer}/" 2>/dev/null | wc -l | tr -d ' ')"
    [[ "$_MS_JSON" == "true" ]] && return 0
    printf '  %b%s%b — %s branch ref(s)\n' "${BRIGHT_CYAN:-}" "$peer" "${RESET:-}" "$n"
    while IFS=$'\t' read -r sha subject; do
        [[ -n "$sha" ]] || continue
        ahead="$(git -C "$repo" rev-list --count "HEAD..${sha}" 2>/dev/null || echo 0)"
        printf '      %s  %s  (+%s not here)\n' "${sha:0:8}" "$subject" "$ahead"
    done < <(git -C "$repo" for-each-ref --format='%(objectname)%09%(refname:short)' "refs/remotes/${peer}/" 2>/dev/null)
    while IFS=$'\t' read -r sha subject; do
        [[ -n "$sha" ]] || continue
        printf '      wip %s  %s\n' "${sha:0:8}" "$subject"
    done < <(git -C "$repo" for-each-ref --format='%(objectname)%09%(contents:subject)' "refs/machine-sync/${peer}/" 2>/dev/null)
}

_ms_json_str() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '"%s"' "$s"; }

# ── entry point ──────────────────────────────────────────────────────────────

machine_sync() {
    local repo="" json=false dry=false status=false min_ram=0 kind_filter=""
    local -a explicit=() overrides=()
    local a

    while (( $# )); do
        case "$1" in
            --repo)        repo="${2:-}";        shift 2 ;;
            --as)          _MS_AS="${2:-}";      shift 2 ;;
            --machine)     explicit+=("${2:-}"); shift 2 ;;
            --peer-path)   overrides+=("${2:-}"); shift 2 ;;
            --min-ram)     min_ram="${2:-0}";    shift 2 ;;
            --kind)        kind_filter="${2:-}"; shift 2 ;;
            --machines-file) AINISH_MACHINES_FILE="${2:-}"; shift 2 ;;
            --push)        _MS_DIRECTION="push";  shift ;;
            --pull)        _MS_DIRECTION="pull";  shift ;;
            --both)        _MS_DIRECTION="both";  shift ;;
            --status)      status=true;           shift ;;
            --dry-run)     dry=true;              shift ;;
            --json)        json=true;             shift ;;
            -h|--help)     _ms_usage; return 0 ;;
            -*)            _ms_err "unknown option: $1 (try --machine-sync --help)"; return 1 ;;
            *)             [[ -z "$repo" ]] && repo="$1"; shift ;;
        esac
    done

    _MS_JSON="$json"

    [[ -n "$repo" ]] || repo="$(pwd)"
    if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
        _ms_err "not a git repository: $repo"
        return 1
    fi
    repo="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)"

    if ! _ms_load_registry "$AINISH_MACHINES_FILE"; then
        _ms_err "no machine registry at $AINISH_MACHINES_FILE"
        _ms_info "Create it with one line per machine, for example:"
        _ms_info "  $( _ms_kind )-$(_ms_ram_gb)gb=self"
        _ms_info "  windows-128gb=windows-128gb:D:/Code"
        return 1
    fi

    _MS_SELF="$(_ms_self_name)"
    local repo_name
    repo_name="$(basename "$repo")"

    # Which peers does this run cover?
    local -a peer_names=() peer_specs=()
    local i name spec
    for i in "${!_MS_NAMES[@]}"; do
        name="${_MS_NAMES[$i]}"
        spec="${_MS_SPECS[$i]}"
        [[ "$name" == "$_MS_SELF" ]] && continue
        if (( ${#explicit[@]} > 0 )); then
            local want=false e
            for e in "${explicit[@]}"; do [[ "$e" == "$name" ]] && want=true; done
            [[ "$want" == "true" ]] || continue
        fi
        if [[ -n "$kind_filter" && "${name%%-*}" != "$kind_filter" ]]; then continue; fi
        local ram
        ram="$(_ms_name_ram "$name")"
        if (( min_ram > 0 )); then
            if [[ -z "$ram" ]] || (( ram < min_ram )); then continue; fi
        fi
        peer_names+=("$name")
        peer_specs+=("$spec")
    done

    if (( ${#peer_names[@]} == 0 )); then
        _ms_err "no peers selected (registry: $AINISH_MACHINES_FILE)"
        return 1
    fi

    if [[ "$json" != "true" ]]; then
        _ms_head "machine-sync — $repo_name on $_MS_SELF"
        printf '  repo:     %s\n' "$repo"
        printf '  peers:    %s\n' "${peer_names[*]}"
        printf '  direction:%s\n' "$_MS_DIRECTION"
    fi

    # Snapshot uncommitted work once, so every peer receives the same commit.
    local branch self_ref wip_state="clean"
    branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")"
    [[ "$branch" == "HEAD" ]] && branch="detached-$(git -C "$repo" rev-parse --short HEAD 2>/dev/null)"
    self_ref="refs/machine-sync/${_MS_SELF}/${branch}"
    if [[ "$dry" == "true" ]]; then
        if [[ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]]; then wip_state="uncommitted work present"; fi
    else
        local snap rc=0
        snap="$(_ms_wip_snapshot "$repo" "$branch" "$self_ref")" || rc=$?
        case "$rc" in
            0) wip_state="snapshot $snap" ;;
            3) wip_state="clean" ;;
            *) wip_state="snapshot FAILED"; _ms_err "could not snapshot the working tree; nothing leaves this machine" ;;
        esac
        if [[ "$json" != "true" ]]; then
            printf '  wip:      %s\n' "$wip_state"
        fi
        [[ "$rc" == "1" ]] && return 1
    fi

    local -a failures=()
    local bundle
    bundle="$(mktemp "${TMPDIR:-/tmp}/ainish-ms-bundle.XXXXXX" 2>/dev/null)" || { _ms_err "mktemp failed"; return 1; }
    rm -f "$bundle"

    if [[ "$status" != "true" && "$dry" != "true" && "$_MS_DIRECTION" != "pull" ]]; then
        if [[ "$json" != "true" ]]; then printf '  bundling…\n'; fi
        local brc=0
        _ms_bundle_create "$repo" "$bundle" || brc=$?
        case "$brc" in
            3) bundle="" ;;
            0) : ;;
            *) _ms_err "bundle creation failed"; rm -f "$bundle"; return 1 ;;
        esac
    fi

    local k
    for k in "${!peer_names[@]}"; do
        name="${peer_names[$k]}"
        spec="${peer_specs[$k]}"

        if ! _ms_parse_spec "$spec"; then
            failures+=("$name")
            continue
        fi

        local host="" path=""
        host="$_P_HOST"
        if [[ "$_P_LOCAL" == "true" && -z "$_P_ROOT" ]]; then
            _ms_skip "$name — self entry with no root; nothing to sync"
            continue
        fi
        # An explicit --peer-path wins; otherwise the peer keeps this repo under its code root.
        path="$(_ms_override_for "$name")"
        if [[ -z "$path" ]]; then path="${_P_ROOT%/}/${repo_name}"; fi

        if [[ "$json" != "true" ]]; then
            printf '\n%b%s%b  (%s%s)\n' "${BRIGHT_CYAN:-}" "$name" "${RESET:-}" \
                "$([[ -n "$host" ]] && echo "ssh $host" || echo local):$path"
        fi

        if [[ "$status" == "true" ]]; then
            _ms_report_peer "$repo" "$name"
            continue
        fi

        if [[ "$dry" == "true" ]]; then
            _ms_skip "dry-run — would sync $_MS_DIRECTION with $path"
            continue
        fi

        if ! _ms_peer_reachable "$host" "$path"; then
            _ms_err "$name — no git repository at $path"
            failures+=("$name")
            continue
        fi

        # Start optimistic per direction: a direction that was not requested cannot fail.
        local sent=true recv=true
        if [[ "$_MS_DIRECTION" == "push" || "$_MS_DIRECTION" == "both" ]]; then
            if [[ -n "$bundle" ]]; then
                if _ms_push "$repo" "$host" "$path" "$name" "$bundle"; then sent=true; else sent=false; fi
            else
                sent=true   # nothing to send
            fi
        fi
        if [[ "$_MS_DIRECTION" == "pull" || "$_MS_DIRECTION" == "both" ]]; then
            local prc=0
            _ms_pull "$repo" "$host" "$path" "$name" "$bundle" || prc=$?
            case "$prc" in
                0|3) recv=true ;;
                *) recv=false ;;
            esac
        fi

        if [[ "$sent" == "true" && "$recv" == "true" ]]; then
            [[ "$json" != "true" ]] && _ms_ok "$name synced"
            _ms_report_peer "$repo" "$name"
        else
            _ms_err "$name — sync failed (sent=$sent received=$recv)"
            failures+=("$name")
        fi
    done

    if [[ "$json" == "true" ]]; then
        printf '{"repo":%s,"self":%s,"direction":%s,"wip":%s,"peers":[' \
            "$(_ms_json_str "$repo")" "$(_ms_json_str "$_MS_SELF")" \
            "$(_ms_json_str "$_MS_DIRECTION")" "$(_ms_json_str "$wip_state")"
        local first=true p
        for p in "${peer_names[@]}"; do
            [[ "$first" == "true" ]] || printf ','
            first=false
            printf '{"name":%s,"ram_gb":%s,"ok":%s}' "$(_ms_json_str "$p")" \
                "$( [ -n "$(_ms_name_ram "$p")" ] && printf '%s' "$(_ms_name_ram "$p")" || printf 'null')" \
                "$( _ms_in_list "$p" "${failures[@]:-}" && printf false || printf true )"
        done
        printf ']}\n'
    fi

    rm -f "$bundle"
    if (( ${#failures[@]} > 0 )); then
        _ms_err "failed peers: ${failures[*]}"
        return 1
    fi
    return 0
}

_ms_override_for() { # name -> the override value, empty when absent
    local n="$1" ov
    for ov in "${overrides[@]:-}"; do
        [[ "${ov%%=*}" == "$n" ]] && { printf '%s\n' "${ov#*=}"; return 0; }
    done
    printf '\n'
}

_ms_in_list() { # needle haystack...
    local needle="$1"; shift
    local x
    for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
    return 1
}
