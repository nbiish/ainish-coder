#!/bin/bash
# machine_run — capacity-aware peer selection (`--machine-pick`) and federated remote execution
# (`--machine-run`) for cross-machine agent hopping, SSH tasks, and multi-platform crons.
#
# WHY THIS EXISTS
# ---------------
# `machines.txt` already encodes each machine's platform and capacity (`mac-18gb`, `windows-128gb`,
# `wsl-94gb`, `cloud-a100-80gb`), and `--machine-sync` keeps git refs + PQC CoD ledgers aligned.
# Without a single command that bridges selection -> push -> remote exec -> pull, every agent or
# cron has to hand-roll SSH paths, forget to sync before/after, or collide on a peer's main tree.
#
# `--machine-pick` selects the highest-capacity reachable peer matching `--min-ram` / `--kind` /
# `--machine`. `--machine-run` wraps the full federated loop:
#   1. pick peer (by capacity, kind, or explicit name)
#   2. sync-before (`--push --branches --ff-peers`, plus `--bootstrap` for fresh cloud hosts)
#   3. execute `<command...>` inside the peer's repo (or an isolated `--worktree` on the peer)
#   4. sync-after (`--pull --branches`) even on non-zero command exit, then return the remote exit code

_mr_err()  { printf 'machine-run: %s\n' "$*" >&2; }
_mr_info() { printf '  %s\n' "$*" >&2; }

_mr_pick_usage() {
    cat <<'EOF'
ainish-coder --machine-pick — select the best reachable federated peer by capacity or platform

USAGE:
    ainish-coder --machine-pick [DIR] [OPTIONS]

OPTIONS:
    --machine NAME         Restrict to NAME (repeatable).
    --min-ram GB           Require peer capacity >= GB (parsed from <kind>[-<accel>]-<ram>gb).
    --kind KIND            Require peer kind (mac | windows | wsl | cloud | linux).
    --require-repo         Also require the target repository to exist at the resolved peer path.
    --peer-path NAME=PATH  Override peer repository path.
    --machines-file PATH   Registry file (default: ~/.config/ainish-coder/machines.txt).
    --links-file PATH      Links file (default: ~/.config/ainish-coder/links.txt).
    --json                 Emit structured JSON (ainish-coder/machine-pick/v1).
    -h, --help             This text.

EXIT: 0 peer selected · 1 no matching reachable peer
EOF
}

_mr_run_usage() {
    cat <<'EOF'
ainish-coder --machine-run — sync repo to a peer, run a command/agent task there, and sync results back

USAGE:
    ainish-coder --machine-run [DIR] [OPTIONS] -- <command...>

OPTIONS:
    --machine NAME         Run on NAME (default: auto-pick highest-capacity matching reachable peer).
    --min-ram GB           Only consider peers with capacity >= GB.
    --kind KIND            Only consider peers of kind (mac | windows | wsl | cloud | linux).
    --branch NAME          Branch to target when using --worktree (default: current branch).
    --worktree             Run inside an isolated temporary worktree on the peer (safe for parallel
                           SSH agent tasks without colliding on the peer's main checkout).
    --bootstrap            If the peer is SSH-reachable but lacks the repo, clone it from our bundle first.
    --peer-path NAME=PATH  Override peer repository path.
    --no-sync-before       Skip pre-run push sync.
    --no-sync-after        Skip post-run pull sync.
    --dry-run              Print the resolved peer, path, sync steps, and command without running.
    --machines-file PATH   Registry file (default: ~/.config/ainish-coder/machines.txt).
    --links-file PATH      Links file (default: ~/.config/ainish-coder/links.txt).
    --json                 Emit JSON execution summary on stdout (remote output goes to stderr).
    -h, --help             This text.

EXIT: remote command exit code (fail-closed; 1 if peer selection or pre-run sync fails)
EOF
}

# _mr_select_peer — populate _MR_SEL_{NAME,HOST,ROOT,PATH,RAM,KIND} for the highest-capacity
# reachable peer matching filters. Returns 0 on match, 1 when no peer qualifies.
_mr_select_peer() { # repo min_ram kind require_repo explicit_list...
    local repo="$1" min_ram="$2" kind_filter="$3" require_repo="$4"
    shift 4
    local -a explicit=("$@")

    _MR_SEL_NAME="" _MR_SEL_HOST="" _MR_SEL_ROOT="" _MR_SEL_PATH="" _MR_SEL_RAM="0" _MR_SEL_KIND=""

    if ! _ms_load_registry "$AINISH_MACHINES_FILE"; then
        _mr_err "no machine registry at $AINISH_MACHINES_FILE"
        return 1
    fi
    local self_name repo_name=""
    self_name="$(_ms_self_name)"
    [[ -n "$repo" ]] && repo_name="$(basename "$repo")"

    # Collect matching candidates and sort by descending RAM (numeric, bash 3.2 portable).
    local -a cand_lines=()
    local i name spec ram kind
    for i in "${!_MS_NAMES[@]}"; do
        name="${_MS_NAMES[$i]}"; spec="${_MS_SPECS[$i]}"
        [[ "$spec" == "self" || "$name" == "$self_name" ]] && continue
        if (( ${#explicit[@]} > 0 )); then
            local want=false e
            for e in "${explicit[@]}"; do [[ "$e" == "$name" ]] && want=true; done
            [[ "$want" == "true" ]] || continue
        fi
        kind="${name%%-*}"
        if [[ -n "$kind_filter" && "$kind" != "$kind_filter" ]]; then continue; fi
        ram="$(_ms_name_ram "$name")"
        [[ "$ram" =~ ^[0-9]+$ ]] || ram=0
        if (( min_ram > 0 && ram < min_ram )); then continue; fi
        cand_lines+=("$(printf '%08d|%s|%s|%s|%s' "$ram" "$name" "$spec" "$kind" "$ram")")
    done

    if (( ${#cand_lines[@]} == 0 )); then
        _mr_err "no peers match filters (min-ram=${min_ram}, kind=${kind_filter:-any})"
        return 1
    fi

    local sorted_line _pad cname cspec ckind cram host path probe_rc
    while IFS= read -r sorted_line; do
        [[ -n "$sorted_line" ]] || continue
        IFS='|' read -r _pad cname cspec ckind cram <<< "$sorted_line"
        _ms_parse_spec "$cspec" || continue
        host="$_P_HOST"
        path=""
        if [[ -n "$repo" ]]; then
            path="$(_ms_override_for "$cname")"
            [[ -n "$path" ]] || path="$(_ms_linked_path "$repo" "$cname")"
            [[ -n "$path" ]] || path="${_P_ROOT%/}/${repo_name}"
        else
            path="$_P_ROOT"
        fi

        if [[ "$require_repo" == "true" && -n "$repo" ]]; then
            probe_rc=0
            _ms_probe_peer "$host" "$path" || probe_rc=$?
            (( probe_rc == 0 )) || continue
        else
            if [[ -z "$host" ]]; then
                [[ -d "$_P_ROOT" ]] || continue
            else
                _ms_remote "$host" "echo OK" >/dev/null 2>&1 || continue
            fi
        fi

        _MR_SEL_NAME="$cname"
        _MR_SEL_HOST="$host"
        _MR_SEL_ROOT="$_P_ROOT"
        _MR_SEL_PATH="$path"
        _MR_SEL_RAM="$cram"
        _MR_SEL_KIND="$ckind"
        return 0
    done < <(printf '%s\n' "${cand_lines[@]}" | LC_ALL=C sort -r)

    _mr_err "no reachable peer matched (min-ram=${min_ram}, kind=${kind_filter:-any}, require-repo=${require_repo})"
    return 1
}

machine_pick() {
    local repo="" json=false min_ram=0 kind_filter="" require_repo=false
    local -a explicit=() overrides=()

    while (( $# )); do
        case "$1" in
            --repo)          repo="${2:-}";               shift 2 ;;
            --machine)       explicit+=("${2:-}");        shift 2 ;;
            --min-ram)       min_ram="${2:-0}";           shift 2 ;;
            --kind)          kind_filter="${2:-}";        shift 2 ;;
            --require-repo)  require_repo=true;           shift ;;
            --peer-path)     overrides+=("${2:-}");       shift 2 ;;
            --machines-file) AINISH_MACHINES_FILE="${2:-}"; shift 2 ;;
            --links-file)    AINISH_LINKS_FILE="${2:-}";  shift 2 ;;
            --json)          json=true;                   shift ;;
            -h|--help)       _mr_pick_usage; return 0 ;;
            -*)              _mr_err "unknown option: $1 (try --machine-pick --help)"; return 1 ;;
            *)               [[ -z "$repo" ]] && repo="$1"; shift ;;
        esac
    done

    if [[ -n "$repo" ]]; then
        repo="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$repo")"
    elif git rev-parse --show-toplevel >/dev/null 2>&1; then
        repo="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    fi

    _MS_OVERRIDES=(${overrides[@]+"${overrides[@]}"})
    if ! _mr_select_peer "$repo" "$min_ram" "$kind_filter" "$require_repo" ${explicit[@]+"${explicit[@]}"}; then
        return 1
    fi

    if [[ "$json" == "true" ]]; then
        printf '{"format":"ainish-coder/machine-pick/v1","peer":%s,"host":%s,"kind":%s,"ram_gb":%s,"root":%s,"repo_path":%s}\n' \
            "$(_ms_json_str "$_MR_SEL_NAME")" \
            "$(_ms_json_str "${_MR_SEL_HOST:-local}")" \
            "$(_ms_json_str "$_MR_SEL_KIND")" \
            "${_MR_SEL_RAM:-0}" \
            "$(_ms_json_str "$_MR_SEL_ROOT")" \
            "$(_ms_json_str "$_MR_SEL_PATH")"
    else
        printf '%s\n' "$_MR_SEL_NAME"
    fi
    return 0
}

machine_run() {
    local repo="" json=false dry=false min_ram=0 kind_filter="" target_branch=""
    local use_worktree=false bootstrap=false sync_before=true sync_after=true
    local -a explicit=() overrides=() cmd_args=()

    while (( $# )); do
        case "$1" in
            --)              shift; cmd_args=("$@"); break ;;
            --repo)          repo="${2:-}";                 shift 2 ;;
            --machine)       explicit+=("${2:-}");          shift 2 ;;
            --min-ram)       min_ram="${2:-0}";             shift 2 ;;
            --kind)          kind_filter="${2:-}";          shift 2 ;;
            --branch)        target_branch="${2:-}";        shift 2 ;;
            --worktree)      use_worktree=true;             shift ;;
            --bootstrap)     bootstrap=true;                shift ;;
            --peer-path)     overrides+=("${2:-}");         shift 2 ;;
            --no-sync-before) sync_before=false;            shift ;;
            --no-sync-after)  sync_after=false;             shift ;;
            --dry-run)       dry=true;                      shift ;;
            --machines-file) AINISH_MACHINES_FILE="${2:-}"; shift 2 ;;
            --links-file)    AINISH_LINKS_FILE="${2:-}";    shift 2 ;;
            --json)          json=true;                     shift ;;
            -h|--help)       _mr_run_usage; return 0 ;;
            -*)              _mr_err "unknown option: $1 (try --machine-run --help)"; return 1 ;;
            *)               if [[ -z "$repo" && -d "$1" ]]; then repo="$1"; shift
                             else cmd_args=("$@"); break; fi ;;
        esac
    done

    if (( ${#cmd_args[@]} == 0 )); then
        _mr_err "no command given (usage: ainish-coder --machine-run [DIR] [OPTIONS] -- <command...>)"
        return 1
    fi

    [[ -n "$repo" ]] || repo="$(pwd)"
    if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
        _mr_err "not a git repository: $repo"
        return 1
    fi
    repo="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)"
    [[ -n "$target_branch" ]] || target_branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"

    _MS_OVERRIDES=(${overrides[@]+"${overrides[@]}"})
    local req_repo=true
    [[ "$bootstrap" == "true" || "$sync_before" == "false" ]] && req_repo=false
    if ! _mr_select_peer "$repo" "$min_ram" "$kind_filter" "$req_repo" ${explicit[@]+"${explicit[@]}"}; then
        return 1
    fi

    local peer="$_MR_SEL_NAME" host="$_MR_SEL_HOST" peer_path="$_MR_SEL_PATH"
    local self_name
    self_name="$(_ms_self_name)"

    # Build a single command string from cmd_args.
    local remote_cmd=""
    if (( ${#cmd_args[@]} == 1 )); then
        remote_cmd="${cmd_args[0]}"
    else
        local arg qarg
        for arg in "${cmd_args[@]}"; do
            printf -v qarg '%q' "$arg"
            remote_cmd="${remote_cmd:+${remote_cmd} }${qarg}"
        done
    fi

    if [[ "$dry" == "true" ]]; then
        if [[ "$json" == "true" ]]; then
            printf '{"format":"ainish-coder/machine-run/v1","dry_run":true,"peer":%s,"host":%s,"repo_path":%s,"branch":%s,"worktree":%s,"sync_before":%s,"sync_after":%s,"command":%s}\n' \
                "$(_ms_json_str "$peer")" "$(_ms_json_str "${host:-local}")" "$(_ms_json_str "$peer_path")" \
                "$(_ms_json_str "$target_branch")" "$use_worktree" "$sync_before" "$sync_after" "$(_ms_json_str "$remote_cmd")"
        else
            printf 'machine-run (dry-run)\n'
            printf '  peer:        %s (%s:%s)\n' "$peer" "${host:-local}" "$peer_path"
            printf '  branch:      %s (worktree=%s)\n' "$target_branch" "$use_worktree"
            printf '  sync_before: %s (bootstrap=%s)\n' "$sync_before" "$bootstrap"
            printf '  sync_after:  %s\n' "$sync_after"
            printf '  command:     %s\n' "$remote_cmd"
        fi
        return 0
    fi

    # 1. Sync-before: push latest commits, branches, and PQC CoD to peer.
    if [[ "$sync_before" == "true" ]]; then
        local -a pre_args=(--repo "$repo" --machine "$peer" --push --branches --ff-peers --quiet)
        [[ "$bootstrap" == "true" ]] && pre_args+=(--bootstrap)
        [[ -n "${AINISH_MACHINES_FILE:-}" ]] && pre_args+=(--machines-file "$AINISH_MACHINES_FILE")
        [[ -n "${AINISH_LINKS_FILE:-}" ]] && pre_args+=(--links-file "$AINISH_LINKS_FILE")
        local ov
        for ov in ${overrides[@]+"${overrides[@]}"}; do pre_args+=(--peer-path "$ov"); done
        if ! ( machine_sync "${pre_args[@]}" ); then
            _mr_err "pre-run sync to $peer failed; aborting remote execution"
            return 1
        fi
    fi

    # 2. Execute command on peer (in peer_path or isolated temporary worktree).
    local cmd_rc=0 wt_dir="" exec_dir="$peer_path"
    if [[ "$use_worktree" == "true" ]]; then
        local peer_tmp safe_br
        peer_tmp="$(_ms_peer_tmp "$host" "$peer_path")"
        safe_br="$(printf '%s' "$target_branch" | tr '/: ' '---')"
        wt_dir="${peer_tmp}/ainish-run-${safe_br}-$$-${RANDOM}"
        local wt_ref="refs/remotes/${self_name}/${target_branch}"
        if [[ -z "$host" ]]; then
            git -C "$peer_path" worktree add --detach "$wt_dir" "$wt_ref" >/dev/null 2>&1 \
                || git -C "$peer_path" worktree add --detach "$wt_dir" HEAD >/dev/null 2>&1 \
                || { _mr_err "could not create isolated worktree on $peer"; return 1; }
        else
            if [[ "$peer_path" =~ ^[A-Za-z]: ]]; then
                _ms_remote "$host" "git -C '${peer_path}' worktree add --detach '${wt_dir}' '${wt_ref}' 2>\$null; if (\$LASTEXITCODE -ne 0) { git -C '${peer_path}' worktree add --detach '${wt_dir}' HEAD }" >/dev/null 2>&1 \
                    || { _mr_err "could not create isolated worktree on $peer"; return 1; }
            else
                _ms_remote "$host" "git -C '${peer_path}' worktree add --detach '${wt_dir}' '${wt_ref}' >/dev/null 2>&1 || git -C '${peer_path}' worktree add --detach '${wt_dir}' HEAD >/dev/null 2>&1" \
                    || { _mr_err "could not create isolated worktree on $peer"; return 1; }
            fi
        fi
        exec_dir="$wt_dir"
    fi

    local run_cmd=""
    if [[ -z "$host" ]]; then
        run_cmd="cd '${exec_dir}' && ${remote_cmd}"
    elif [[ "$exec_dir" =~ ^[A-Za-z]: ]]; then
        run_cmd="Set-Location -LiteralPath '${exec_dir}'; ${remote_cmd}"
    else
        run_cmd="cd '${exec_dir}' && ${remote_cmd}"
    fi

    if [[ "$json" == "true" ]]; then
        _ms_remote "$host" "$run_cmd" >&2 || cmd_rc=$?
    else
        _ms_remote "$host" "$run_cmd" || cmd_rc=$?
    fi

    # Clean up temporary worktree if created (preserving any branches/commits written to git object db).
    if [[ -n "$wt_dir" ]]; then
        if [[ -z "$host" ]]; then
            git -C "$peer_path" worktree remove --force "$wt_dir" >/dev/null 2>&1 || true
        else
            _ms_remote "$host" "git -C '${peer_path}' worktree remove --force '${wt_dir}'" >/dev/null 2>&1 || true
        fi
    fi

    # 3. Sync-after: pull back any commits, branches, uncommitted snapshots, and PQC CoD from peer.
    local pull_ok=true
    if [[ "$sync_after" == "true" ]]; then
        local -a post_args=(--repo "$repo" --machine "$peer" --pull --branches --ff-peers --quiet)
        [[ -n "${AINISH_MACHINES_FILE:-}" ]] && post_args+=(--machines-file "$AINISH_MACHINES_FILE")
        [[ -n "${AINISH_LINKS_FILE:-}" ]] && post_args+=(--links-file "$AINISH_LINKS_FILE")
        local ov
        for ov in ${overrides[@]+"${overrides[@]}"}; do post_args+=(--peer-path "$ov"); done
        if ! ( machine_sync "${post_args[@]}" ); then
            pull_ok=false
            _mr_err "warning: post-run pull from $peer failed"
        fi
    fi

    if [[ "$json" == "true" ]]; then
        printf '{"format":"ainish-coder/machine-run/v1","peer":%s,"host":%s,"repo_path":%s,"branch":%s,"worktree":%s,"exit_code":%d,"sync_after_ok":%s}\n' \
            "$(_ms_json_str "$peer")" "$(_ms_json_str "${host:-local}")" "$(_ms_json_str "$peer_path")" \
            "$(_ms_json_str "$target_branch")" "$use_worktree" "$cmd_rc" "$pull_ok"
    fi
    return "$cmd_rc"
}
