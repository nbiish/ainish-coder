#!/bin/bash
# machine_link — record that a repository is the SAME repository on another machine.
#
# WHY THIS EXISTS
# ---------------
# `--machine-sync` can move refs between machines, but it has no memory of intent. It resolves a
# peer's copy of a repo as `<peer-code-root>/<repo-name>`, which is only right when every machine
# keeps every repo under one root with the same directory name. That is not how a real workstation
# is laid out: this repository lives under a removable-volume code root on the Mac and under
# `D:/Code/goal-first-trillion` on the Windows box, so the peer was addressed at a path
# that does not exist and a sync either failed or silently skipped. The operator then re-typed a
# `--peer-path` on every run, and forgot it on the run that mattered.
#
# A LINK is that fact written down once:
#
#   <repo> | <peer> | <peer path>      one per line, in ~/.config/ainish-coder/links.txt
#
# `--machine-sync` consults the links file before it falls back to the name-based guess, so a linked
# repo is addressed correctly with no flags. `--machine-sync --all` walks every repo linked here.
#
# LINKS ARM A HOOK, AND THE HOOK ONLY SENDS
# -----------------------------------------
# A link also installs a post-commit/post-merge block in the repo: when you commit, the linked peers
# receive it immediately, so the other machine is current before you next sit down at it. That is
# the whole point — the alternative is remembering to run a command on each machine, which is the
# step that gets skipped.
#
# The hook sends and never receives. Receiving means moving this machine's branch, and doing that
# from inside a commit hook is how a machine ends up half-merged with nobody watching. `--pull` and
# `--both` stay explicit commands.
#
# A hook must never block a commit. Every probe is bounded (`ConnectTimeout`), the call is wrapped in
# `|| true`, and the env guard `AINISH_MACHINE_SYNC_ACTIVE` prevents a sync from re-entering itself.

: "${AINISH_LINKS_FILE:=${AINISH_SYNC_LINKS:-$HOME/.config/ainish-coder/links.txt}}"

_ML_HOOK_START="# --- AINISH-CODER MACHINE SYNC START ---"
_ML_HOOK_END="# --- AINISH-CODER MACHINE SYNC END ---"

_ml_err() { printf 'machine-link: %s\n' "$*" >&2; }

_ml_usage() {
    cat <<'EOF'
ainish-coder --machine-link — record that a repository is the same repository on another machine

USAGE:
    ainish-coder --machine-link [DIR] --peer NAME [--peer-path PATH] [OPTIONS]

    A link is written to ~/.config/ainish-coder/links.txt and is used automatically by
    --machine-sync, so the peer path is remembered instead of re-typed. By default the link also
    installs a post-commit/post-merge hook in DIR that SENDS to the linked peers on every commit.

OPTIONS:
    --peer NAME            Peer from machines.txt to link (repeatable).
    --peer-path PATH       Where NAME keeps this repository. Default: the machines.txt root for
                           that peer joined with this repo's directory name.
    --all-peers            Link every non-self peer in machines.txt.
    --no-hooks             Record the link only; install no git hooks.
    --list                 Print the links recorded on this machine.
    --remove               Remove the link(s) for --peer (and their hook blocks).
    --json                 Machine-readable output on stdout.
    --links-file PATH      Links registry to read/write.
    -h, --help             This text.

WHAT A LINK DOES NOT DO:
    it does not pull. The hook sends only. Use `--machine-sync DIR --pull` (or `--both`) to receive.
    it does not merge diverged histories. If a peer's branch is not an ancestor of yours it is
    reported, never rewritten.

EXIT: 0 recorded · 1 failed
EOF
}

# ── registry ─────────────────────────────────────────────────────────────────

# _ml_repo_key <dir> — the identity a link is recorded under.
#
# The toplevel, not the argument: a link recorded from a subdirectory must match a sync started
# anywhere else in the same checkout.
_ml_repo_key() {
    local dir="$1" top
    top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$top" ]] || return 1
    ( cd -P "$top" 2>/dev/null && pwd ) || printf '%s\n' "$top"
}

# _ml_read <repo> — print "peer<TAB>path" for every link of this repo.
_ml_read() {
    local repo="$1" line r p path
    [[ -f "$AINISH_LINKS_FILE" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="$(printf '%s' "$line" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        [[ -z "$line" ]] && continue
        IFS='|' read -r r p path <<< "$line"
        r="$(printf '%s' "$r" | sed 's/[[:space:]]*$//')"
        p="$(printf '%s' "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        path="$(printf '%s' "$path" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        [[ "$r" == "$repo" && -n "$p" ]] || continue
        printf '%s\t%s\n' "$p" "$path"
    done < "$AINISH_LINKS_FILE"
    return 0
}

# _ml_lookup <repo> <peer> — the recorded peer path, empty when the pair is not linked.
_ml_lookup() {
    local repo="$1" peer="$2" p path
    while IFS=$'\t' read -r p path; do
        [[ "$p" == "$peer" ]] && { printf '%s\n' "$path"; return 0; }
    done < <(_ml_read "$repo")
    printf '\n'
}

# _ml_write <repo> <peer> <path> — upsert one link. One line per (repo, peer) pair.
_ml_write() {
    local repo="$1" peer="$2" path="$3" dir tmp
    dir="$(dirname "$AINISH_LINKS_FILE")"
    mkdir -p "$dir" 2>/dev/null || { _ml_err "cannot create $dir"; return 1; }
    tmp="${AINISH_LINKS_FILE}.tmp.$$"
    {
        if [[ -f "$AINISH_LINKS_FILE" ]]; then
            local line r p
            while IFS= read -r line || [[ -n "$line" ]]; do
                # Drop the old row for this pair; keep every other line, comments included.
                if [[ "$line" != \#* && "$line" == *"|"* ]]; then
                    IFS='|' read -r r p _ <<< "$line"
                    r="$(printf '%s' "$r" | sed 's/[[:space:]]*$//')"
                    p="$(printf '%s' "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
                    [[ "$r" == "$repo" && "$p" == "$peer" ]] && continue
                fi
                printf '%s\n' "$line"
            done < "$AINISH_LINKS_FILE"
        fi
        printf '%s | %s | %s\n' "$repo" "$peer" "$path"
    } > "$tmp" || { rm -f "$tmp"; return 1; }
    mv "$tmp" "$AINISH_LINKS_FILE" || { rm -f "$tmp"; return 1; }
    chmod 600 "$AINISH_LINKS_FILE" 2>/dev/null || true
    return 0
}

# _ml_delete <repo> <peer> — drop one link; prints how many rows went.
_ml_delete() {
    local repo="$1" peer="$2" tmp line r p removed=0
    [[ -f "$AINISH_LINKS_FILE" ]] || { printf '0\n'; return 0; }
    tmp="${AINISH_LINKS_FILE}.tmp.$$"
    : > "$tmp" || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" != \#* && "$line" == *"|"* ]]; then
            IFS='|' read -r r p _ <<< "$line"
            r="$(printf '%s' "$r" | sed 's/[[:space:]]*$//')"
            p="$(printf '%s' "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
            if [[ "$r" == "$repo" && "$p" == "$peer" ]]; then
                removed=$((removed + 1)); continue
            fi
        fi
        printf '%s\n' "$line" >> "$tmp"
    done < "$AINISH_LINKS_FILE"
    mv "$tmp" "$AINISH_LINKS_FILE" || { rm -f "$tmp"; return 1; }
    printf '%s\n' "$removed"
}

# ── hooks ───────────────────────────────────────────────────────────────────

# _ml_hooks_dir <repo> — the hooks directory that owns this checkout, empty when nested.
#
# Same rule as the rules-sync installer: arming an enclosing repository's hook would fire for every
# sibling project, so a nested checkout gets no hook and the operator is told.
_ml_hooks_dir() {
    local repo="$1" top hooks
    top="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$top" ]] || return 0
    # A worktree or a submodule records its hooks in the common dir, not in .git/ of the checkout.
    hooks="$(git -C "$repo" rev-parse --path-format=absolute --git-path hooks 2>/dev/null || true)"
    [[ -n "$hooks" ]] || hooks="${top}/.git/hooks"
    printf '%s\n' "$hooks"
}

# _ml_install_hook_block <hook> <block> — idempotent, in-place block replacement.
_ml_install_hook_block() {
    local hook="$1" block="$2"
    mkdir -p "$(dirname "$hook")" 2>/dev/null || return 1
    if [[ ! -f "$hook" ]]; then
        printf '#!/bin/sh\n\n%s\n' "$block" > "$hook"
    elif grep -qF "$_ML_HOOK_START" "$hook" 2>/dev/null; then
        local tmp="${hook}.tmp.$$"
        BLOCK="$block" START="$_ML_HOOK_START" END="$_ML_HOOK_END" \
            awk '
                $0 == ENVIRON["START"] { inblock=1; printf "%s\n", ENVIRON["BLOCK"]; next }
                $0 == ENVIRON["END"]   { inblock=0; next }
                !inblock
            ' "$hook" > "$tmp" && mv "$tmp" "$hook"
    else
        # Append, so Husky/lefthook/custom logic in an existing hook survives.
        printf '\n%s\n' "$block" >> "$hook"
    fi
    chmod 755 "$hook" 2>/dev/null || chmod +x "$hook" 2>/dev/null || true
    return 0
}

# _ml_strip_hook_block <hook> — remove the managed block; delete the file when nothing else remains.
_ml_strip_hook_block() {
    local hook="$1" tmp
    [[ -f "$hook" ]] || return 0
    grep -qF "$_ML_HOOK_START" "$hook" 2>/dev/null || return 0
    tmp="${hook}.tmp.$$"
    START="$_ML_HOOK_START" END="$_ML_HOOK_END" awk '
        $0 == ENVIRON["START"] { inblock=1; next }
        $0 == ENVIRON["END"]   { inblock=0; next }
        !inblock
    ' "$hook" > "$tmp" || { rm -f "$tmp"; return 1; }
    # A hook left holding only a shebang and blank lines was ours; remove the file so the repo is
    # back to having no hook at all, rather than one that shells out and does nothing.
    if ! grep -qvE '^[[:space:]]*$|^#!.*$' "$tmp" 2>/dev/null; then
        rm -f "$tmp" "$hook"
    else
        mv "$tmp" "$hook" || { rm -f "$tmp"; return 1; }
        chmod 755 "$hook" 2>/dev/null || true
    fi
    return 0
}

# _ml_hook_block <cli> <repo> — the hook body, with paths quoted for sh.
#
# The registry paths are baked in when they are not the defaults: a git hook inherits the ambient
# environment of whatever invoked the commit (an IDE, an agent harness, a CI shell), and relying on
# `AINISH_MACHINES_FILE` surviving into that environment is how a hook silently syncs to the wrong
# peer set or to none. `--linked-only` is what keeps a commit here from pushing this repo to every
# machine in the registry.
_ml_hook_block() {
    local cli="$1" repo="$2" q_cli q_repo q_args=""
    printf -v q_cli "'%s'" "$(printf '%s' "$cli" | sed "s/'/'\\\\''/g")"
    printf -v q_repo "'%s'" "$(printf '%s' "$repo" | sed "s/'/'\\\\''/g")"
    if [[ -n "${AINISH_MACHINES_FILE:-}" ]]; then
        printf -v q_args "%s --machines-file '%s'" "$q_args" "$(printf '%s' "$AINISH_MACHINES_FILE" | sed "s/'/'\\\\''/g")"
    fi
    if [[ -n "${AINISH_LINKS_FILE:-}" ]]; then
        printf -v q_args "%s --links-file '%s'" "$q_args" "$(printf '%s' "$AINISH_LINKS_FILE" | sed "s/'/'\\\\''/g")"
    fi
    cat <<HOOK_BLOCK
$_ML_HOOK_START
# Send this repository's commits to its linked machines. Sends only — receiving is explicit.
if [ "\${AINISH_MACHINE_SYNC_ACTIVE:-0}" != "1" ] && [ -x ${q_cli} ]; then
    AINISH_MACHINE_SYNC_ACTIVE=1 ${q_cli} --machine-sync ${q_repo} --push --linked-only --quiet${q_args} >/dev/null 2>&1 || true
fi
$_ML_HOOK_END
HOOK_BLOCK
}

_ml_install_hooks() {
    local repo="$1" cli="$2" hooks block
    hooks="$(_ml_hooks_dir "$repo")"
    if [[ -z "$hooks" ]]; then
        _ml_err "no git hooks directory for ${repo}; the link is recorded but nothing will auto-send"
        return 0
    fi
    block="$(_ml_hook_block "$cli" "$repo")"
    _ml_install_hook_block "${hooks}/post-commit" "$block" || return 1
    _ml_install_hook_block "${hooks}/post-merge" "$block" || return 1
    return 0
}

_ml_remove_hooks() {
    local repo="$1" hooks
    hooks="$(_ml_hooks_dir "$repo")"
    [[ -n "$hooks" ]] || return 0
    _ml_strip_hook_block "${hooks}/post-commit" || return 1
    _ml_strip_hook_block "${hooks}/post-merge" || return 1
    return 0
}

# ── entry point ─────────────────────────────────────────────────────────────

machine_link() {
    local repo="" json=false list=false remove=false no_hooks=false all_peers=false
    local -a peers=() overrides=()
    local a

    while (( $# )); do
        case "$1" in
            --repo)        repo="${2:-}";        shift 2 ;;
            --peer)        peers+=("${2:-}");    shift 2 ;;
            --peer-path)   overrides+=("${2:-}"); shift 2 ;;
            --all-peers)   all_peers=true;       shift ;;
            --no-hooks)    no_hooks=true;        shift ;;
            --list)        list=true;            shift ;;
            --remove)      remove=true;          shift ;;
            --json)        json=true;            shift ;;
            --links-file)  AINISH_LINKS_FILE="${2:-}"; shift 2 ;;
            --machines-file) AINISH_MACHINES_FILE="${2:-}"; shift 2 ;;
            -h|--help)     _ml_usage; return 0 ;;
            -*)            _ml_err "unknown option: $1 (try --machine-link --help)"; return 1 ;;
            *)             [[ -z "$repo" ]] && repo="$1"; shift ;;
        esac
    done

    # --list without a repo prints the whole registry: that is the "what is linked?" question.
    if [[ "$list" == "true" && -z "$repo" ]]; then
        if [[ ! -f "$AINISH_LINKS_FILE" ]]; then
            [[ "$json" == "true" ]] && printf '{"format":"ainish-coder/machine-links/v1","links":[]}\n'
            return 0
        fi
        if [[ "$json" == "true" ]]; then
            local first=true line r p path
            printf '{"format":"ainish-coder/machine-links/v1","links":['
            while IFS= read -r line || [[ -n "$line" ]]; do
                [[ "$line" != \#* && "$line" == *"|"* ]] || continue
                IFS='|' read -r r p path <<< "$line"
                r="$(printf '%s' "$r" | sed 's/[[:space:]]*$//')"
                p="$(printf '%s' "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
                path="$(printf '%s' "$path" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
                [[ -n "$r" && -n "$p" ]] || continue
                [[ "$first" == "true" ]] || printf ','
                first=false
                printf '{"repo":"%s","peer":"%s","peer_path":"%s"}' "$r" "$p" "$path"
            done < "$AINISH_LINKS_FILE"
            printf ']}\n'
        else
            grep -v '^[[:space:]]*#' "$AINISH_LINKS_FILE" 2>/dev/null | grep '|' || true
        fi
        return 0
    fi

    [[ -n "$repo" ]] || repo="$(pwd)"
    local key
    key="$(_ml_repo_key "$repo")" || { _ml_err "not a git repository: $repo"; return 1; }
    repo="$key"

    if [[ "$list" == "true" ]]; then
        local p path found=false
        while IFS=$'\t' read -r p path; do
            found=true
            if [[ "$json" == "true" ]]; then
                printf '{"repo":"%s","peer":"%s","peer_path":"%s"}\n' "$repo" "$p" "$path"
            else
                printf '%s  ->  %s  (%s)\n' "$repo" "$p" "$path"
            fi
        done < <(_ml_read "$repo")
        [[ "$found" == "true" || "$json" == "true" ]] || printf '%s is not linked to any peer\n' "$repo"
        return 0
    fi

    if ! machine_sync_load_registry; then
        _ml_err "no machine registry at $AINISH_MACHINES_FILE"
        return 1
    fi

    if [[ "$all_peers" == "true" && ${#peers[@]} -eq 0 ]]; then
        local i n
        for i in "${!_MS_NAMES[@]}"; do
            n="${_MS_NAMES[$i]}"
            [[ "${_MS_SPECS[$i]}" == "self" ]] && continue
            peers+=("$n")
        done
    fi

    if [[ ${#peers[@]} -eq 0 ]]; then
        _ml_err "no --peer given (try --all-peers, or name one from $AINISH_MACHINES_FILE)"
        return 1
    fi

    local rc=0 peer path spec root
    for peer in "${peers[@]}"; do
        # Reject an unknown peer: a typo that records a link is worse than a failure here, because
        # every later sync silently addresses a machine that does not exist.
        spec=""
        local i
        for i in "${!_MS_NAMES[@]}"; do
            [[ "${_MS_NAMES[$i]}" == "$peer" ]] && { spec="${_MS_SPECS[$i]}"; break; }
        done
        if [[ -z "$spec" ]]; then
            _ml_err "$peer is not in $AINISH_MACHINES_FILE"
            rc=1; continue
        fi
        if [[ "$spec" == "self" ]]; then
            _ml_err "$peer is this machine; a repo cannot be linked to itself"
            rc=1; continue
        fi

        if [[ "$remove" == "true" ]]; then
            local removed
            removed="$(_ml_delete "$repo" "$peer")" || { rc=1; continue; }
            if (( removed > 0 )); then
                _ml_remove_hooks "$repo" || rc=1
                _ml_ok_link "$json" "unlinked $repo from $peer"
            else
                _ml_err "$repo was not linked to $peer"
                rc=1
            fi
            continue
        fi

        path="$(_ml_override_for "$peer" "${overrides[@]:-}")"
        if [[ -z "$path" ]]; then
            # Default: the peer's code root plus this repo's directory name. Correct only when the
            # peer uses the same layout — which is why --peer-path exists and why the resolved path
            # is printed back rather than assumed silently.
            if machine_sync_parse_spec "$spec"; then
                path="${_P_ROOT%/}/$(basename "$repo")"
            fi
        fi
        if [[ -z "$path" ]]; then
            _ml_err "$peer has no code root in $AINISH_MACHINES_FILE; pass --peer-path"
            rc=1; continue
        fi

        _ml_write "$repo" "$peer" "$path" || { rc=1; continue; }
        if [[ "$no_hooks" == "true" ]]; then
            _ml_ok_link "$json" "linked $repo -> $peer:$path (no hooks)"
        else
            local cli
            cli="$(_ml_cli_path)"
            if [[ -z "$cli" ]]; then
                _ml_err "cannot locate bin/ainish-coder to arm a hook; the link is recorded — re-run with --no-hooks to silence this"
                rc=1; continue
            fi
            _ml_install_hooks "$repo" "$cli" || rc=1
            _ml_ok_link "$json" "linked $repo -> $peer:$path (hook armed)"
        fi
    done
    return $rc
}

# _ml_cli_path — a launcher the hook can actually execute.
#
# Prefer an absolute path into this checkout. `command -v ainish-coder` would find whatever happens to
# be on PATH, which may be a different (or stale) install than the one the operator just used.
_ml_cli_path() {
    local self_dir
    self_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || return 1
    local candidate="${self_dir}/../bin/ainish-coder"
    if [[ -x "$candidate" ]]; then
        ( cd -P "$(dirname "$candidate")" && printf '%s/%s\n' "$(pwd)" "$(basename "$candidate")" )
        return 0
    fi
    command -v ainish-coder 2>/dev/null || return 1
}

# The registry lives in machine_sync.sh; these two thin wrappers keep the dependency in one place.
machine_sync_load_registry() { _ms_load_registry "$AINISH_MACHINES_FILE"; }
machine_sync_parse_spec()    { _ms_parse_spec "$1"; }

# _ml_override_for <peer> [NAME=PATH|PATH] — the recorded peer path for this peer.
#
# `--machine-link` takes `--peer-path PATH` (one peer per invocation is the common case), while
# `--machine-sync` takes `--peer-path NAME=PATH` because it may address several peers at once. Both
# forms are accepted here: a bare path applies to the peer being linked. Silently ignoring it — which
# is what happened when the value lacked `=` — made the flag look like it worked while the guessed
# path was used instead.
_ml_override_for() {
    local n="$1"; shift
    local ov
    for ov in "$@"; do
        [[ -z "$ov" ]] && continue
        if [[ "$ov" == *=* ]]; then
            [[ "${ov%%=*}" == "$n" ]] && { printf '%s\n' "${ov#*=}"; return 0; }
        else
            printf '%s\n' "$ov"; return 0
        fi
    done
    printf '\n'
}

_ml_ok_link() { # json message
    if [[ "$1" == "true" ]]; then printf '{"ok":true,"message":"%s"}\n' "$2"
    else printf '  %s✓%s %s\n' "${GREEN:-}" "${RESET:-}" "$2"; fi
}
