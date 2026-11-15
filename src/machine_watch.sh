#!/bin/bash
# machine_watch — keep federated repositories current without the operator thinking about it.
#
# WHY THIS EXISTS
# ---------------
# `--machine-link` arms a post-commit hook, so committing on one machine delivers to the others. But
# people do not work in commits; they work in saves. An edit that has not been committed is not a git
# object, so it has no transport at all, and the operator's real loop — edit here, walk to the other
# machine — was the one loop that did not sync.
#
# This closes it with a supervisor that watches the linked repositories and runs the SAME sync path
# the hooks use (`--machine-sync --both --branches --auto-commit --linked-only`). Nothing new moves
# bytes here; the watcher only decides WHEN. That matters: every safety property the sync path already
# has — a peer is only fast-forwarded when it is clean and on the same branch, divergence is reported
# and never merged, ignored files never cross — applies unchanged.
#
# WHAT "INSTANT" ACTUALLY MEANS
# -----------------------------
# This host has neither `fswatch` nor `inotifywait`, and adding a platform-specific dependency to a
# script that ships to macOS, Linux, and Windows is a worse trade than polling. So a change is noticed
# on a short poll (default 2s) and acted on after the tree has been quiet for a debounce window
# (default 1.5s), which coalesces the burst of saves an editor emits when you type-and-save. The
# honest statement is "seconds", not "instantaneous", and the docs say so.
#
# WHY IT NEVER OVERWRITES A DIRTY PEER
# ------------------------------------
# Two machines editing the same file is the normal case this tool exists to serve, and it is exactly
# the case where a blind push destroys work. A peer whose tree is dirty is reported and skipped. Its
# owner decides. That is the one place this design deliberately prefers a pause to a guess.

: "${AINISH_WATCH_INTERVAL:=2}"
: "${AINISH_WATCH_DEBOUNCE:=2}"

_MW_STATE_DIR="${HOME}/.config/ainish-coder"
_MW_STATE_FILE="${_MW_STATE_DIR}/watch.state"
_MW_LOG="${_MW_STATE_DIR}/watch.log"
_MW_LABEL="ai.nanoboozhoo.ainish-machine-watch"

_mw_err()  { printf 'machine-watch: %s\n' "$*" >&2; }
_mw_say()  { printf 'machine-watch: %s\n' "$*"; }
_mw_log()  { mkdir -p "$_MW_STATE_DIR" 2>/dev/null; printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$_MW_LOG" 2>/dev/null || true; }

_mw_usage() {
    cat <<'EOF'
ainish-coder --machine-watch — keep linked repositories synced in the background

USAGE:
    ainish-coder --machine-link DIR --peer NAME --watch    link AND install the watcher
    ainish-coder --machine-watch [OPTIONS]                 run the loop in the foreground
    ainish-coder --machine-watch --status                  is it installed, running, last cycle?
    ainish-coder --machine-watch --uninstall               stop and remove it (links stay)

OPTIONS:
    --interval SECONDS     How often to look for changes (default 2).
    --debounce SECONDS     How long a tree must be quiet before syncing (default 2). A burst of
                           saves becomes one commit, not twenty.
    --once                 Run a single cycle and exit. Useful in CI and for testing.
    --foreground           Run in the foreground even when a service is installed.
    --transport MODE       auto (default) | direct | ssh. Auto probes whether this process can read
                           the repository and, when macOS TCC denies it, runs the whole cycle over
                           `ssh localhost` (which executes under sshd's authority). Needed for repos
                           on external volumes; requires passwordless loopback ssh.
    --event-watch          Use fswatch file events instead of polling. Optional: if fswatch is not
                           installed this falls back to polling rather than failing.
    --poll                 Force polling (the portable default).
    --verbose              Print every cycle, not only the ones that did something.
    --json                 Machine-readable status on stdout.
    -h, --help             This text.

WHAT IT DOES
    For every linked repo, when the working tree or HEAD has changed and has stopped changing, it
    runs: --machine-sync <repo> --both --branches --auto-commit --linked-only
    That commits the save with an honest wip(<machine>) message, delivers it, receives the peers'
    work, and materialises their branches. The same path the git hooks use.

WHAT IT WILL NOT DO
    Overwrite a peer whose working tree is dirty — that is reported and skipped, because that peer
    has unsaved work and this tool must never be the reason it disappears.
    Merge diverged histories — that is a human decision, reported every cycle until resolved.

INSTALLED AS
    macOS  ~/Library/LaunchAgents/ai.nanoboozhoo.ainish-machine-watch.plist  (RunAtLoad, KeepAlive)
    Linux  ~/.config/systemd/user/ainish-machine-watch.service
    State  ~/.config/ainish-coder/watch.state, log at ~/.config/ainish-coder/watch.log

EXIT: 0 ok · 1 failure (a cycle that failed, or a service that would not install)
EOF
}

# ── transport ───────────────────────────────────────────────────────────────
#
# macOS TCC refuses a launchd-spawned process read access to an external volume: the repo stats fine
# but every read returns "Operation not permitted". The same user's terminal has access, which is why
# a foreground loop works and a daemon does not — and the Full Disk Access picker will not navigate to
# /bin/bash, while copying bash elsewhere is killed by code signing (exit 137).
#
# The way through is that `ssh localhost` runs under sshd's authority, not the agent's. Verified with a
# probe agent that failed a direct read and succeeded over loopback ssh in the same process, seconds
# apart.
#
# Because a denied agent cannot read the repo AT ALL, the fallback is not a per-command shim: the whole
# cycle — detection, debounce, sync — runs on the far side of the ssh. The agent's only job then is to
# invoke it on an interval and surface the result. That keeps one implementation of the cycle instead
# of two that could drift.

_MW_TRANSPORT="${AINISH_WATCH_TRANSPORT:-auto}"

# _mw_can_read <repo> — can THIS process read the repo directly?
_mw_can_read() { # repo
    local repo="$1"
    ( cd "$repo" 2>/dev/null && git rev-parse --git-dir >/dev/null 2>&1 )
}

# _mw_can_read_via_ssh <repo> — can the same user, through loopback ssh, read it?
_mw_can_read_via_ssh() { # repo
    ssh -o BatchMode=yes -o ConnectTimeout=5 localhost \
        "git -C '$1' rev-parse --git-dir" >/dev/null 2>&1
}

# Decide this machine's transport once and record it. Echoes: direct | ssh | none
_mw_detect_transport() {
    local repo="$1"
    case "$_MW_TRANSPORT" in
        direct) _mw_can_read "$repo" && { printf 'direct\n'; return 0; }; printf 'none\n'; return 0 ;;
        ssh)    _mw_can_read_via_ssh "$repo" && { printf 'ssh\n'; return 0; }; printf 'none\n'; return 0 ;;
    esac
    _mw_can_read "$repo" && { printf 'direct\n'; return 0; }
    if _mw_can_read_via_ssh "$repo"; then
        _mw_log "transport: TCC denies direct reads here; delegating the cycle to loopback ssh"
        printf 'ssh\n'
        return 0
    fi
    printf 'none\n'
}

# Run the whole cycle through ssh. Used only when this process cannot read the repo itself.
# The inner invocation is the SAME command, guarded against re-entering the ssh branch.
_mw_cycle_via_ssh() { # cli interval debounce verbose
    local cli="$1" interval="$2" debounce="$3" verbose="$4"
    local -a extra=()
    [[ -n "${AINISH_MACHINES_FILE:-}" ]] && extra+=(--machines-file "$AINISH_MACHINES_FILE")
    [[ -n "${AINISH_LINKS_FILE:-}" ]] && extra+=(--links-file "$AINISH_LINKS_FILE")
    [[ "$verbose" == "true" ]] && extra+=(--verbose)

    local q_cli
    printf -v q_cli "'%s'" "$(printf '%s' "$cli" | sed "s/'/'\\\\''/g")"
    local argstr=""
    local x
    for x in "${extra[@]:-}"; do
        [[ -z "$x" ]] && continue
        argstr="${argstr} $(printf "'%s'" "$(printf '%s' "$x" | sed "s/'/'\\\\''/g")")"
    done

    # AINISH_WATCH_TRANSPORT=direct on the far side forces the direct path there: sshd has the access,
    # so the inner process must not rediscover the same denial and try ssh again (an infinite fork).
    ssh -o BatchMode=yes -o ConnectTimeout=5 localhost \
        "AINISH_WATCH_TRANSPORT=direct ${q_cli} --machine-watch --once --interval ${interval} --debounce ${debounce}${argstr}" 2>&1
}

# ── change detection ────────────────────────────────────────────────────────

# A cheap fingerprint of everything that would make a sync necessary: HEAD, the branch, and the exact
# porcelain output (which names every changed path). Hashing the porcelain rather than the file
# mtimes matters: `git status` already honours the repo's own ignore rules, so a build directory
# churning underneath us is not a change worth syncing.
_mw_fingerprint() { # repo
    local repo="$1"
    {
        git -C "$repo" rev-parse -q --verify HEAD 2>/dev/null || printf 'no-head'
        git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'no-branch'
        git -C "$repo" status --porcelain 2>/dev/null | LC_ALL=C sort
    } | cksum 2>/dev/null | awk '{print $1 "-" $2}'
}

# Every repo linked on this machine, one absolute path per line.
_mw_linked_repos() {
    local links_file="${AINISH_LINKS_FILE:-${_MW_STATE_DIR}/links.txt}"
    [[ -f "$links_file" ]] || return 0
    local line r
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" != \#* && "$line" == *"|"* ]] || continue
        r="${line%%|*}"
        r="$(printf '%s' "$r" | sed 's/[[:space:]]*$//')"
        [[ -d "$r" ]] && printf '%s\n' "$r"
    done < "$links_file" | sort -u
}

# ── the cycle ───────────────────────────────────────────────────────────────

# _mw_sync_repo <repo> — one sync, via the path the hooks already use.
#
# Deliberately a separate process invocation rather than a sourced function call: a long-lived watcher
# sourcing the sync code would keep its own globals (`_MS_*`) alive across cycles, and a bad cycle
# would poison the next one. A subprocess starts clean every time.
_mw_sync_repo() { # repo
    local repo="$1" cli="$2"
    local -a args=(--machine-sync "$repo" --both --branches --auto-commit --linked-only --quiet)
    [[ -n "${AINISH_MACHINES_FILE:-}" ]] && args+=(--machines-file "$AINISH_MACHINES_FILE")
    [[ -n "${AINISH_LINKS_FILE:-}" ]] && args+=(--links-file "$AINISH_LINKS_FILE")
    AINISH_MACHINE_SYNC_ACTIVE=1 "$cli" "${args[@]}" 2>&1
}

# _mw_resolve_stable_cli — a launcher path that survives the way this repo is developed.
#
# AGENTS.md mandates a worktree per task, so `ainish-coder` is usually run from
# `<worktree>/bin/ainish-coder`. Recording that path in a login item is a time bomb: the worktree is
# removed when the task merges, and the daemon then fails every cycle with
# `no such file or directory: .../<worktree>/bin/ainish-coder`. That happened live.
#
# A worktree reports its own `--git-dir` but a shared `--git-common-dir`; when those differ, the
# checkout is disposable and the durable path is the one owning the common dir. Resolve to that, and
# say so, rather than silently recording something that will vanish.
_mw_resolve_stable_cli() {
    local self_dir candidate common gitdir main_checkout
    self_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || return 1
    candidate="${self_dir}/../bin/ainish-coder"
    if [[ ! -x "$candidate" ]]; then
        command -v ainish-coder 2>/dev/null || return 1
        return 0
    fi
    candidate="$( cd -P "$(dirname "$candidate")" 2>/dev/null && printf '%s/%s\n' "$(pwd)" "$(basename "$candidate")" )"

    local repo_root
    repo_root="$( cd -P "${self_dir}/.." 2>/dev/null && pwd )" || { printf '%s\n' "$candidate"; return 0; }
    gitdir="$(git -C "$repo_root" rev-parse --git-dir 2>/dev/null || true)"
    common="$(git -C "$repo_root" rev-parse --git-common-dir 2>/dev/null || true)"

    if [[ -n "$gitdir" && -n "$common" ]]; then
        local gd cd_abs
        gd="$( cd -P "$repo_root" 2>/dev/null && cd "$gitdir" 2>/dev/null && pwd )" || gd=""
        cd_abs="$( cd -P "$repo_root" 2>/dev/null && cd "$common" 2>/dev/null && pwd )" || cd_abs=""
        if [[ -n "$gd" && -n "$cd_abs" && "$gd" != "$cd_abs" ]]; then
            # This is a worktree. The main checkout is the parent of the common git dir.
            main_checkout="$(dirname "$cd_abs")"
            if [[ -x "${main_checkout}/bin/ainish-coder" ]]; then
                _mw_log "install path: resolved worktree ${repo_root} -> main checkout ${main_checkout}"
                printf '%s/bin/ainish-coder\n' "$main_checkout"
                return 0
            fi
            _mw_err "this is a worktree and the main checkout has no bin/ainish-coder;"
            _mw_err "recording ${candidate}, which will break when the worktree is removed."
        fi
    fi
    printf '%s\n' "$candidate"
}

_mw_cli() {
    _mw_resolve_stable_cli
}

# _mw_ssh_health — is loopback ssh usable right now? Echoes ok | broken | unknown.
#
# Only called when a delegated cycle FAILS. Probing every cycle would add a round trip to a loop whose
# cost is already dominated by ssh; probing never would leave the operator reading "sync failed" and
# hunting a repo problem when the actual cause is an expired key or a stopped sshd.
_mw_ssh_health() {
    local out rc=0
    out="$(ssh -o BatchMode=yes -o ConnectTimeout=5 localhost 'echo MW_OK' 2>&1)" || rc=$?
    if (( rc == 0 )) && printf '%s' "$out" | grep -q 'MW_OK'; then
        printf 'ok\n'
        return 0
    fi
    _MW_SSH_ERROR="$out"
    printf 'broken\n'
}

# Explain a broken loopback ssh in terms the operator can act on. The raw error is kept because a
# host-key change and a permission denial need different fixes, and guessing between them would send
# the operator down the wrong path.
_mw_explain_ssh_failure() {
    local detail="${_MW_SSH_ERROR:-no output}"
    _mw_err "background sync could not reach this machine over loopback ssh."
    _mw_err "This is NOT a problem with the repository — it is the transport the watcher uses because"
    _mw_err "macOS TCC will not let a launchd agent read an external volume directly."
    _mw_err ""
    case "$detail" in
        *"Permission denied"*|*"publickey"*)
            _mw_err "Cause: this machine cannot ssh to itself without a password."
            _mw_err "Fix:   ssh-copy-id localhost      (then re-run --machine-watch --install)" ;;
        *"Host key verification failed"*)
            _mw_err "Cause: localhost's host key changed or is not trusted."
            _mw_err "Fix:   ssh-keyscan localhost >> ~/.ssh/known_hosts" ;;
        *"Connection refused"*|*"Operation timed out"*|*"Could not resolve"*)
            _mw_err "Cause: sshd is not reachable on localhost."
            _mw_err "Fix:   enable Remote Login in System Settings -> General -> Sharing" ;;
        *)
            _mw_err "Cause: ${detail}" ;;
    esac
    _mw_err ""
    _mw_err "Verify with: ssh -o BatchMode=yes localhost 'echo ok'"
}

# _mw_watch_mode — how should the loop wait for a change?
#
# Polling is the portable default and stays the fallback. Where `fswatch` exists it is strictly better:
# the loop wakes on the event instead of on a timer, so the debounce is the only latency. It is never
# REQUIRED — a missing `fswatch` must not change behaviour, only speed.
_mw_watch_mode() {
    case "${_MW_WATCH_MODE:-auto}" in
        poll)  printf 'poll\n'; return 0 ;;
        event) command -v fswatch >/dev/null 2>&1 && { printf 'event\n'; return 0; }
               _mw_err "--event-watch requested but fswatch is not installed; polling instead"
               printf 'poll\n'; return 0 ;;
    esac
    command -v fswatch >/dev/null 2>&1 && { printf 'event\n'; return 0; }
    printf 'poll\n'
}

# Wait for something to change, then return. <interval> bounds the poll; <repos...> are watched.
#
# With fswatch the wait ends on a real file event, so the caller's debounce controls latency. Without
# it, the wait is a plain sleep — identical behaviour to before this function existed.
_mw_wait_for_change() { # mode interval repos...
    local mode="$1" interval="$2"; shift 2
    case "$mode" in
        event)
            # -1: one event then exit (we re-arm each cycle); -r: recurse; -l 2: 2s latency ceiling so
            # a missed event still resolves. Bounded by the caller's signal handling.
            if [[ $# -gt 0 ]]; then
                fswatch -1 -r -l 2 "$@" >/dev/null 2>&1 || sleep "$interval"
            else
                sleep "$interval"
            fi ;;
        *)  sleep "$interval" ;;
    esac
}

# Run one pass over every linked repo. Echoes nothing; logs outcomes.
_mw_cycle() { # verbose
    local verbose="$1" cli repo fp
    cli="$(_mw_cli)" || { _mw_err "cannot locate ainish-coder"; return 1; }
    local seen=0 changed=0 failed=0
    while IFS= read -r repo; do
        [[ -n "$repo" ]] || continue
        seen=$((seen + 1))
        fp="$(_mw_fingerprint "$repo")"
        local last
        last="$(_mw_read_fp "$repo")"
        [[ "$fp" == "$last" ]] && { [[ "$verbose" == "true" ]] && _mw_say "no change: $repo"; continue; }

        # A repo in backoff is skipped until its next attempt. Its fingerprint is NOT recorded, so the
        # change stays pending and is retried when the window opens. Backoff exists so an unreachable
        # peer is retried a handful of times rather than 1,800 times an hour.
        if _mw_in_backoff "$repo"; then
            [[ "$verbose" == "true" ]] && _mw_say "backoff: $repo"
            continue
        fi

        # Debounce: wait for the tree to stop changing, so a burst of saves is one commit.
        local quiet_until now remaining stable
        stable=false
        local deadline=$(( $(date +%s) + ${AINISH_WATCH_DEBOUNCE:-2} * 10 ))
        while (( $(date +%s) < deadline )); do
            sleep "${AINISH_WATCH_DEBOUNCE:-2}"
            local again
            again="$(_mw_fingerprint "$repo")"
            if [[ "$again" == "$fp" ]]; then stable=true; break; fi
            fp="$again"
        done
        [[ "$stable" == "true" ]] || { _mw_log "still churning, skip: $repo"; continue; }

        changed=$((changed + 1))
        _mw_log "syncing: $repo"
        local out rc=0
        out="$(_mw_sync_repo "$repo" "$cli")" || rc=$?
        if (( rc == 0 )); then
            _mw_write_fp "$repo" "$(_mw_fingerprint "$repo")"
            _mw_clear_failures "$repo"
            [[ "$verbose" == "true" ]] && _mw_say "synced: $repo"
            _mw_log "ok: $repo"
        else
            failed=$((failed + 1))
            # Do NOT record the fingerprint on failure. Recording it would mark the change as handled
            # and silently lose it — which is exactly what happened on the first live install: a
            # transient "not a git repository" (a concurrent git operation held the repo) marked the
            # save synced and it never retried. The change stays pending instead, and backoff stops a
            # persistently unreachable peer from flooding the log every interval.
            local n; n="$(_mw_bump_failures "$repo")"
            _mw_log "failed: $repo (attempt $n)"
            printf 'machine-watch: sync failed for %s (attempt %s, retrying with backoff)\n%s\n' \
                "$repo" "$n" "$out" >&2
        fi
    done < <(_mw_linked_repos)

    _mw_write_state "$seen" "$changed" "$failed"
    (( failed == 0 ))
}

# Per-repo fingerprints, kept beside the state file rather than inside each repo: writing into a
# watched repo's .git would itself be a change worth reacting to.
_mw_fp_file() { printf '%s/fp-%s\n' "$_MW_STATE_DIR" "$(printf '%s' "$1" | cksum | awk '{print $1}')"; }
_mw_read_fp()  { local f; f="$(_mw_fp_file "$1")"; [[ -f "$f" ]] && cat "$f" 2>/dev/null || printf ''; }
_mw_write_fp() { mkdir -p "$_MW_STATE_DIR" 2>/dev/null; printf '%s' "$2" > "$(_mw_fp_file "$1")" 2>/dev/null || true; }

# Failure bookkeeping, so a pending change is retried but a permanently broken peer does not flood the
# log every interval. Each failure stores "<count> <epoch-of-next-attempt>".
_mw_fail_file() { printf '%s/fail-%s\n' "$_MW_STATE_DIR" "$(printf '%s' "$1" | cksum | awk '{print $1}')"; }
_mw_bump_failures() { # repo -> new count
    local f n=0 next now
    f="$(_mw_fail_file "$1")"
    now="$(date +%s)"
    if [[ -f "$f" ]]; then
        read -r n _ < "$f" 2>/dev/null || n=0
        [[ "$n" =~ ^[0-9]+$ ]] || n=0
    fi
    n=$((n + 1))
    # Exponential backoff capped at 5 minutes: 0,4,8,16,...  A peer that is off should be retried, but
    # not 1800 times an hour.
    local delay=$(( 2 ** (n > 7 ? 7 : n) ))
    (( delay > 300 )) && delay=300
    mkdir -p "$_MW_STATE_DIR" 2>/dev/null
    printf '%s %s\n' "$n" "$((now + delay))" > "$f" 2>/dev/null || true
    printf '%s\n' "$n"
}
_mw_clear_failures() { rm -f "$(_mw_fail_file "$1")" 2>/dev/null || true; }
# True when this repo is in backoff and its next attempt has not arrived.
_mw_in_backoff() {
    local f n next now
    f="$(_mw_fail_file "$1")"
    [[ -f "$f" ]] || return 1
    read -r n next < "$f" 2>/dev/null || return 1
    [[ "$next" =~ ^[0-9]+$ ]] || return 1
    now="$(date +%s)"
    (( now < next ))
}

_mw_write_state() { # seen changed failed
    mkdir -p "$_MW_STATE_DIR" 2>/dev/null
    local transport="direct"
    [[ -f "${_MW_STATE_DIR}/transport" ]] && transport="$(cat "${_MW_STATE_DIR}/transport" 2>/dev/null)"
    printf 'last_cycle=%s\nrepos=%s\nchanged=%s\nfailed=%s\npid=%s\ntransport=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$3" "$$" "${transport:-direct}" > "$_MW_STATE_FILE" 2>/dev/null || true
}

_mw_write_transport() { # direct|ssh|none
    mkdir -p "$_MW_STATE_DIR" 2>/dev/null
    printf '%s\n' "$1" > "${_MW_STATE_DIR}/transport" 2>/dev/null || true
}

_mw_write_ssh_health() { # ok|broken|unknown
    mkdir -p "$_MW_STATE_DIR" 2>/dev/null
    printf '%s\n' "$1" > "${_MW_STATE_DIR}/ssh-health" 2>/dev/null || true
}
_mw_read_ssh_health() {
    local f="${_MW_STATE_DIR}/ssh-health"
    [[ -f "$f" ]] && tr -d '\r\n' < "$f" 2>/dev/null || printf 'unknown'
}

# ── lock ────────────────────────────────────────────────────────────────────

# One cycle at a time. The pid is checked for liveness so a crashed cycle (or a machine that lost
# power) does not leave a lock that disables the watcher forever.
_mw_lock() {
    local lock="${_MW_STATE_DIR}/watch.lock"
    mkdir -p "$_MW_STATE_DIR" 2>/dev/null
    if [[ -f "$lock" ]]; then
        local other
        other="$(cat "$lock" 2>/dev/null | tr -dc '0-9')"
        if [[ -n "$other" ]] && kill -0 "$other" 2>/dev/null; then
            return 1
        fi
        rm -f "$lock" 2>/dev/null
    fi
    printf '%s\n' "$$" > "$lock" 2>/dev/null || return 1
    return 0
}
_mw_unlock() { rm -f "${_MW_STATE_DIR}/watch.lock" 2>/dev/null || true; }

# ── service installation ────────────────────────────────────────────────────

_mw_plist_path() { printf '%s/Library/LaunchAgents/%s.plist\n' "$HOME" "$_MW_LABEL"; }
_mw_unit_path()  { printf '%s/.config/systemd/user/ainish-machine-watch.service\n' "$HOME"; }

_mw_install_macos() {
    local cli plist dir interval debounce
    cli="$(_mw_cli)" || { _mw_err "cannot locate ainish-coder"; return 1; }
    plist="$(_mw_plist_path)"; dir="$(dirname "$plist")"
    interval="${AINISH_WATCH_INTERVAL:-2}"; debounce="${AINISH_WATCH_DEBOUNCE:-2}"
    mkdir -p "$dir" 2>/dev/null || { _mw_err "cannot create $dir"; return 1; }

    # Absolute paths only: launchd starts with a minimal environment and does not inherit a shell
    # profile, so a relative command or a PATH lookup would silently fail at login.
    cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>${_MW_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${cli}</string>
        <string>--machine-watch</string>
        <string>--foreground</string>
        <string>--interval</string><string>${interval}</string>
        <string>--debounce</string><string>${debounce}</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>ThrottleInterval</key><integer>30</integer>
    <key>StandardOutPath</key><string>${_MW_LOG}</string>
    <key>StandardErrorPath</key><string>${_MW_LOG}</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
PLIST
    # bootout first so a re-install picks up new arguments; a missing job is not an error.
    launchctl bootout "gui/$(id -u)/${_MW_LABEL}" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null || launchctl load -w "$plist" 2>/dev/null || {
        _mw_err "launchctl refused to load $plist"; return 1; }
    launchctl enable "gui/$(id -u)/${_MW_LABEL}" >/dev/null 2>&1 || true
    _mw_log "installed launchd agent ${_MW_LABEL} (interval=${interval}s debounce=${debounce}s)"

    # VERIFY BY READING BACK. `bootstrap` exiting 0 does not mean the job is running, and a job can be
    # running while being unable to reach the repositories it is supposed to watch.
    _mw_verify_macos || return 1
    return 0
}

# _mw_verify_macos — prove the agent is actually running, and can actually read what it must watch.
#
# Two failure modes were observed live and neither is visible from an exit code:
#   1. `launchctl bootstrap` returns 0 while the job never loads (a stale domain, a duplicate label).
#   2. macOS TCC denies a launchd-spawned process access to an external/removable volume: `.git`
#      stats fine but reading it fails with "Operation not permitted", so every cycle reports
#      "not a git repository" and the operator is told nothing.
# The second is the dangerous one — it looks like a working watcher that silently syncs nothing.
_mw_verify_macos() {
    local i state="" rc=0
    for i in 1 2 3 4 5 6 7 8 9 10; do
        state="$(launchctl print "gui/$(id -u)/${_MW_LABEL}" 2>/dev/null | sed -n 's/^[[:space:]]*state = //p' | head -1)"
        [[ "$state" == "running" ]] && break
        sleep 1
    done
    if [[ "$state" != "running" ]]; then
        _mw_err "the launchd agent did not reach 'running' (state: ${state:-absent})"
        _mw_info_uninstall_hint
        return 1
    fi

    # Give the first cycle time to probe the transport and write state.
    sleep 6
    local transport
    transport="$(cat "${_MW_STATE_DIR}/transport" 2>/dev/null || printf '')"
    case "$transport" in
        direct)
            _mw_say "verified: agent running, reading repositories directly" ;;
        ssh)
            _mw_say "verified: agent running, reaching repositories over loopback ssh"
            _mw_say "  (macOS TCC blocks direct reads from launchd on external volumes; sshd has access)" ;;
        *)
            # No transport recorded: the agent is up but has not managed to read any repo. Say why.
            if tail -30 "$_MW_LOG" 2>/dev/null | grep -q 'Operation not permitted'; then
                _mw_err "the watcher cannot read a linked repository from this background context."
                _mw_err "macOS TCC denies launchd read access to external volumes, and loopback ssh did not work either."
                _mw_err ""
                _mw_err "Fix one of these, then re-run --machine-watch --install:"
                _mw_err "  a) make sure 'ssh localhost' works without a password:"
                _mw_err "       ssh-copy-id localhost"
                _mw_err "  b) move the repository onto the internal disk, or"
                _mw_err "  c) run 'ainish-coder --machine-watch --foreground' from a terminal with access"
                _mw_info_uninstall_hint
                return 1
            fi
            _mw_say "verified: agent running (transport not yet recorded)"
            ;;
    esac
    return 0
}

_mw_info_uninstall_hint() {
    _mw_err "remove it with: ainish-coder --machine-watch --uninstall"
}

_mw_install_linux() {
    local cli unit
    cli="$(_mw_cli)" || { _mw_err "cannot locate ainish-coder"; return 1; }
    unit="$(_mw_unit_path)"
    mkdir -p "$(dirname "$unit")" 2>/dev/null || { _mw_err "cannot create $(dirname "$unit")"; return 1; }
    cat > "$unit" <<UNIT
[Unit]
Description=ainish-coder machine watcher — keeps linked repositories synced
After=network-online.target

[Service]
Type=simple
ExecStart=${cli} --machine-watch --foreground --interval ${AINISH_WATCH_INTERVAL:-2} --debounce ${AINISH_WATCH_DEBOUNCE:-2}
Restart=always
RestartSec=30

[Install]
WantedBy=default.target
UNIT
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user enable --now ainish-machine-watch.service >/dev/null 2>&1 || {
        _mw_err "systemctl --user could not enable the unit"; return 1; }
    _mw_log "installed systemd user unit"
    return 0
}

_mw_install_service() {
    case "$(uname -s 2>/dev/null)" in
        Darwin) _mw_install_macos ;;
        Linux)  if grep -qi microsoft /proc/version 2>/dev/null; then
                    _mw_err "WSL: run --machine-watch --foreground under your own supervisor (systemd may be absent)"
                    return 1
                fi
                _mw_install_linux ;;
        *)      _mw_err "no service manager known for this platform; use --machine-watch --foreground"
                return 1 ;;
    esac
}

_mw_uninstall_service() {
    case "$(uname -s 2>/dev/null)" in
        Darwin)
            local plist; plist="$(_mw_plist_path)"
            launchctl bootout "gui/$(id -u)/${_MW_LABEL}" >/dev/null 2>&1 || true
            rm -f "$plist" 2>/dev/null || true
            _mw_log "removed launchd agent"
            ;;
        Linux)
            systemctl --user disable --now ainish-machine-watch.service >/dev/null 2>&1 || true
            rm -f "$(_mw_unit_path)" 2>/dev/null || true
            systemctl --user daemon-reload >/dev/null 2>&1 || true
            _mw_log "removed systemd unit"
            ;;
        *) : ;;
    esac
    return 0
}

# ── status ──────────────────────────────────────────────────────────────────

_mw_status() { # json
    local json="$1"
    local installed=false running=false
    case "$(uname -s 2>/dev/null)" in
        Darwin)
            [[ -f "$(_mw_plist_path)" ]] && installed=true
            if launchctl print "gui/$(id -u)/${_MW_LABEL}" 2>/dev/null | grep -q "state = running"; then
                running=true
            fi
            ;;
        Linux)
            [[ -f "$(_mw_unit_path)" ]] && installed=true
            systemctl --user is-active --quiet ainish-machine-watch.service 2>/dev/null && running=true
            ;;
    esac
    local last="never" repos=0 changed=0 failed=0 transport="unknown"
    # The transport file is the authority: it is written when the loop decides how to reach the repos,
    # and it survives a cycle that could not read them (which is exactly when the operator needs to
    # see why). watch.state mirrors it for convenience but is only rewritten by a completed cycle.
    [[ -f "${_MW_STATE_DIR}/transport" ]] && \
        transport="$(tr -d '\r\n' < "${_MW_STATE_DIR}/transport" 2>/dev/null)"
    if [[ -f "$_MW_STATE_FILE" ]]; then
        last="$(sed -n 's/^last_cycle=//p' "$_MW_STATE_FILE" 2>/dev/null)"
        repos="$(sed -n 's/^repos=//p' "$_MW_STATE_FILE" 2>/dev/null)"
        changed="$(sed -n 's/^changed=//p' "$_MW_STATE_FILE" 2>/dev/null)"
        failed="$(sed -n 's/^failed=//p' "$_MW_STATE_FILE" 2>/dev/null)"
        if [[ "$transport" == "unknown" ]]; then
            transport="$(sed -n 's/^transport=//p' "$_MW_STATE_FILE" 2>/dev/null)"
            transport="${transport:-unknown}"
        fi
    fi
    local linked
    linked="$(_mw_linked_repos | wc -l | tr -d ' ')"

    if [[ "$json" == "true" ]]; then
        printf '{"format":"ainish-coder/machine-watch/v1","installed":%s,"running":%s,"transport":"%s","linked_repos":%s,"last_cycle":"%s","last_repos":%s,"last_changed":%s,"last_failed":%s}\n' \
            "$installed" "$running" "${transport}" "${linked:-0}" "${last:-never}" "${repos:-0}" "${changed:-0}" "${failed:-0}"
        return 0
    fi

    printf 'machine-watch\n'
    printf '  service:   %s\n' "$( [[ "$installed" == "true" ]] && echo installed || echo "NOT installed" )"
    printf '  running:   %s\n' "$( [[ "$running" == "true" ]] && echo yes || echo no )"
    printf '  linked:    %s repo(s)\n' "${linked:-0}"
    local transport_desc
    case "$transport" in
        ssh)    transport_desc="loopback ssh (this context cannot read the repos directly)" ;;
        direct) transport_desc="direct" ;;
        *)      transport_desc="unknown — run --machine-watch --foreground once" ;;
    esac
    printf '  transport: %s\n' "$transport_desc"
    if [[ "$transport" == "ssh" ]]; then
        local sshh; sshh="$(_mw_read_ssh_health)"
        case "$sshh" in
            ok)     printf '  ssh:       ok (loopback reachable)\n' ;;
            broken) printf '  ssh:       BROKEN — run: ssh-copy-id localhost\n' ;;
            *)      printf '  ssh:       not yet probed\n' ;;
        esac
    fi
    printf '  cli:       %s\n' "$(_mw_resolve_stable_cli 2>/dev/null || echo unknown)"
    printf '  mode:      %s\n' "$(_mw_watch_mode 2>/dev/null || echo poll)"
    printf '  last sync: %s  (%s repo(s), %s changed, %s failed)\n' "${last:-never}" "${repos:-0}" "${changed:-0}" "${failed:-0}"
    [[ -s "$_MW_LOG" ]] && { printf '  recent log:\n'; tail -5 "$_MW_LOG" 2>/dev/null | sed 's/^/    /'; }
    return 0
}

# ── entry point ─────────────────────────────────────────────────────────────

machine_watch() {
    local interval="$AINISH_WATCH_INTERVAL" debounce="$AINISH_WATCH_DEBOUNCE"
    local once=false foreground=false verbose=false json=false status=false uninstall=false install=false
    local a

    while (( $# )); do
        case "$1" in
            --interval)   interval="${2:-2}";            shift 2 ;;
            --debounce)   debounce="${2:-2}";            shift 2 ;;
            --once)       once=true;                     shift ;;
            --foreground) foreground=true;               shift ;;
            --verbose)    verbose=true;                  shift ;;
            --json)       json=true;                     shift ;;
            --status)     status=true;                   shift ;;
            --uninstall)  uninstall=true;                shift ;;
            --install)    install=true;                  shift ;;
            --transport)  _MW_TRANSPORT="${2:-auto}";    shift 2 ;;
            --event-watch) _MW_WATCH_MODE="event";       shift ;;
            --poll)        _MW_WATCH_MODE="poll";        shift ;;
            --machines-file) AINISH_MACHINES_FILE="${2:-}"; shift 2 ;;
            --links-file)    AINISH_LINKS_FILE="${2:-}";    shift 2 ;;
            -h|--help)    _mw_usage; return 0 ;;
            -*)           _mw_err "unknown option: $1 (try --machine-watch --help)"; return 1 ;;
            *)            shift ;;
        esac
    done

    [[ "$interval" =~ ^[0-9]+$ ]] || { _mw_err "--interval must be a whole number of seconds"; return 1; }
    [[ "$debounce" =~ ^[0-9]+$ ]] || { _mw_err "--debounce must be a whole number of seconds"; return 1; }
    AINISH_WATCH_INTERVAL="$interval"
    AINISH_WATCH_DEBOUNCE="$debounce"

    if [[ "$status" == "true" ]]; then _mw_status "$json"; return 0; fi
    if [[ "$uninstall" == "true" ]]; then
        _mw_uninstall_service || return 1
        _mw_say "watcher removed; links are untouched (see --machine-link --list)"
        return 0
    fi
    if [[ "$install" == "true" ]]; then
        _mw_install_service || return 1
        _mw_say "watcher installed — linked repositories now sync in the background"
        return 0
    fi

    # Refuse to run a loop that has nothing to watch: a silent no-op watcher is worse than a loud
    # refusal, because the operator believes their work is syncing when it is not.
    if [[ -z "$(_mw_linked_repos)" ]]; then
        _mw_err "no linked repositories — run: ainish-coder --machine-link DIR --peer NAME --watch"
        return 1
    fi

    if [[ "$once" == "true" ]]; then
        _mw_lock || { _mw_err "another cycle is running"; return 1; }
        _mw_cycle "$verbose"
        local rc=$?
        _mw_unlock
        return $rc
    fi

    # Foreground loop. Under a service manager this IS the background process; run interactively it
    # prints each cycle so the operator can see it working.
    local first_repo transport
    first_repo="$(_mw_linked_repos | head -1)"
    transport="$(_mw_detect_transport "$first_repo")"
    _mw_write_transport "$transport"

    if [[ "$transport" == "none" ]]; then
        _mw_err "cannot read any linked repository from this context, directly or over loopback ssh."
        _mw_err "  direct:  denied (macOS TCC blocks launchd from external volumes)"
        _mw_err "  ssh:     $(ssh -o BatchMode=yes -o ConnectTimeout=5 localhost 'echo ok' 2>&1 | tail -1)"
        _mw_err "Check that 'ssh localhost' works without a password (ssh-copy-id to yourself)."
        return 1
    fi

    if [[ "$transport" == "ssh" ]]; then
        _mw_say "transport: loopback ssh (this context cannot read the repo directly)"
        _mw_log "transport: ssh"
    else
        _mw_log "transport: direct"
    fi

    _mw_say "watching $(_mw_linked_repos | wc -l | tr -d ' ') linked repo(s) — every ${interval}s, debounce ${debounce}s"
    local watch_mode
    watch_mode="$(_mw_watch_mode)"
    if [[ "$watch_mode" == "event" ]]; then
        _mw_say "mode: file events (fswatch)"
    else
        _mw_say "mode: polling every ${interval}s (install fswatch for event-driven latency)"
    fi
    _mw_write_state "$(_mw_linked_repos | wc -l | tr -d ' ')" 0 0
    _mw_say "Ctrl+C to stop. State: $_MW_STATE_FILE"
    local stopping=false ssh_reported=false
    trap 'stopping=true' INT TERM
    while [[ "$stopping" != "true" ]]; do
        if [[ "$transport" == "ssh" ]]; then
            # The whole cycle runs under sshd's authority, because this process cannot read the repos
            # at all. Delegate rather than duplicate: one implementation of the cycle, in one place.
            local out rc=0
            out="$(_mw_cycle_via_ssh "$(_mw_cli)" "$interval" "$debounce" "$verbose")" || rc=$?
            if (( rc != 0 )); then
                _mw_log "ssh cycle failed"
                printf '%s\n' "$out" >&2
                # Diagnose the transport once, then stop spamming: a broken key would otherwise print
                # the same paragraph every interval forever.
                if [[ "$ssh_reported" != "true" ]]; then
                    if [[ "$(_mw_ssh_health)" == "broken" ]]; then
                        _mw_write_ssh_health "broken"
                        _mw_explain_ssh_failure
                        _mw_err "(this message is shown once; the watcher keeps retrying)"
                        ssh_reported=true
                    fi
                fi
            else
                ssh_reported=false
                _mw_write_ssh_health "ok"
            fi
        else
            if _mw_lock; then
                _mw_cycle "$verbose" || true
                _mw_unlock
            fi
        fi
        # Sleep in one-second slices so a signal is handled promptly rather than after a full interval.
        # Wait for the next change. In event mode a real file event ends the wait immediately, so the
        # debounce is the only latency; in poll mode this is the same one-second-sliced sleep as before,
        # which keeps a signal handled promptly.
        if [[ "$watch_mode" == "event" ]]; then
            local -a _wrepos=()
            local _r
            while IFS= read -r _r; do [[ -n "$_r" ]] && _wrepos+=("$_r"); done < <(_mw_linked_repos)
            _mw_wait_for_change event "$interval" ${_wrepos[@]+"${_wrepos[@]}"}
        else
            local i=0
            while (( i < interval )) && [[ "$stopping" != "true" ]]; do
                sleep 1
                i=$((i + 1))
            done
        fi
    done
    _mw_unlock
    _mw_say "stopped"
    return 0
}
