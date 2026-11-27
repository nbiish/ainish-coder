#!/usr/bin/env bash
# test-machine-watch.sh — hermetic proof for `ainish-coder --machine-watch`.
#
# Two local checkouts stand in for two machines: no SSH, no launchd, no network. It proves the four
# properties the watcher exists for, and one it must never break:
#   1. a SAVE (no commit) reaches the peer's working tree
#   2. a burst of saves coalesces into one commit, not one per save
#   3. a peer with unsaved work is never overwritten, and its work survives byte-identical
#   4. one cycle at a time (the lock), and --status reports without running anything
#   5. an unchanged tree causes no work at all
# Usage: bash scripts/test-machine-watch.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${REPO}/bin/ainish-coder"
PASS=0
FAIL=0

ok()    { PASS=$((PASS+1)); printf '  ok   %s\n' "$*"; }
bad()   { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$*"; }
check() { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (got '$3', want '$2')"; fi; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/machine-watch-test.XXXXXX")"
cleanup() {
    # Stop anything the lock file thinks is running before removing the tree.
    [[ -f "${WORK}/home/.config/ainish-coder/watch.lock" ]] && rm -f "${WORK}/home/.config/ainish-coder/watch.lock"
    rm -rf "$WORK"
}
trap cleanup EXIT

export GIT_AUTHOR_NAME="gate" GIT_AUTHOR_EMAIL="gate@ainish.local"
export GIT_COMMITTER_NAME="gate" GIT_COMMITTER_EMAIL="gate@ainish.local"
export GIT_CONFIG_GLOBAL="${WORK}/gitconfig"
# Hermetic HOME: the watcher writes state under ~/.config/ainish-coder and must not touch the real one.
export HOME="${WORK}/home"
mkdir -p "$HOME"
git config --global init.defaultBranch main
git config --global commit.gpgsign false

SRC="${WORK}/src/demo"
mkdir -p "$SRC"
git -C "$SRC" init -q
printf '*.log\n' > "$SRC/.gitignore"
printf 'line one\n' > "$SRC/tracked.txt"
git -C "$SRC" add -A && git -C "$SRC" commit -qm "initial"

A="${WORK}/machine-a/demo"
B="${WORK}/machine-b/demo"
mkdir -p "$(dirname "$A")" "$(dirname "$B")"
git clone -q "$SRC" "$A"
git clone -q "$SRC" "$B"
# Different directory names on purpose: only a recorded link resolves the peer path.
mkdir -p "${WORK}/machine-b/peer-demo"
rm -rf "${WORK}/machine-b/peer-demo"
git clone -q "$SRC" "${WORK}/machine-b/peer-demo"

export AINISH_LINKS_FILE="${WORK}/links.txt"
export AINISH_MACHINES_FILE="${WORK}/machines.txt"
printf 'box-18gb=self\npeer-b-64gb=%s\n' "${WORK}/machine-b" > "$AINISH_MACHINES_FILE"

echo "== fixture: link A to the peer and arm the watcher state =="
"$CLI" --machine-link --repo "$A" --peer peer-b-64gb --peer-path "${WORK}/machine-b/peer-demo" \
    --machines-file "$AINISH_MACHINES_FILE" --no-hooks >/dev/null 2>&1
check "link recorded" "0" "$?"

PEER="${WORK}/machine-b/peer-demo"

echo "== 1. a SAVE with no commit reaches the peer =="
# This is the whole point: an uncommitted file crossing. Before the watcher, nothing could do this.
printf 'saved but never committed\n' > "$A/saved.txt"
git -C "$A" status --porcelain saved.txt | grep -q '^??' && ok "the file really is uncommitted" \
    || bad "fixture wrong: saved.txt is not untracked"
OUT1="$("$CLI" --machine-watch --once --verbose 2>&1)"
check "one cycle exits 0" "0" "$?"
check "peer received the saved file" "saved but never committed" "$(cat "$PEER/saved.txt" 2>/dev/null)"
[[ -f "$PEER/saved.txt" ]] && ok "the file exists in the peer's WORKING TREE" \
    || bad "peer has no working-tree copy"

echo "== 2. a burst of saves becomes ONE commit =="
C_BEFORE="$(git -C "$A" rev-list --count HEAD)"
for i in 1 2 3 4 5; do
    printf 'burst %s\n' "$i" > "$A/burst.txt"
    sleep 0.2
done
"$CLI" --machine-watch --once >/dev/null 2>&1
C_AFTER="$(git -C "$A" rev-list --count HEAD)"
check "five rapid saves produced one commit" "1" "$((C_AFTER - C_BEFORE))"
check "peer holds the final content of the burst" "burst 5" "$(cat "$PEER/burst.txt" 2>/dev/null)"

echo "== 3. an unchanged tree does nothing =="
C_STEADY="$(git -C "$A" rev-list --count HEAD)"
OUT3="$("$CLI" --machine-watch --once --verbose 2>&1)"
check "second cycle exits 0" "0" "$?"
check "no new commit was created" "$C_STEADY" "$(git -C "$A" rev-list --count HEAD)"
if printf '%s' "$OUT3" | grep -q 'no change'; then ok "the cycle reports no change"; else
    bad "cycle did not report no-change"; printf '%s\n' "$OUT3" | sed 's/^/    | /'
fi

echo "== 4. a peer with unsaved work is NEVER overwritten =="
# The peer has an untracked file of its own. A blind push would destroy it; this must not.
printf 'PEER LOCAL WORK - MUST SURVIVE\n' > "$PEER/precious.txt"
PRECIOUS_BEFORE="$(cksum "$PEER/precious.txt" 2>/dev/null | awk '{print $1"-"$2}')"
printf 'new work from A\n' > "$A/from-a.txt"
OUT4="$("$CLI" --machine-watch --once 2>&1)"
check "peer's precious file survives byte-identical" "$PRECIOUS_BEFORE" \
    "$(cksum "$PEER/precious.txt" 2>/dev/null | awk '{print $1"-"$2}')"
check "peer's precious content is unchanged" "PEER LOCAL WORK - MUST SURVIVE" \
    "$(head -1 "$PEER/precious.txt" 2>/dev/null)"
if printf '%s' "$OUT4" | grep -qi 'failed'; then
    ok "the blocked peer is reported, not silently skipped"
else
    bad "a blocked peer was not reported"; printf '%s\n' "$OUT4" | sed 's/^/    | /'
fi

echo "== 5. the lock prevents overlapping cycles =="
# A live pid in the lock file must make the next cycle refuse rather than run concurrently.
sleep 30 & LIVE_PID=$!
mkdir -p "$HOME/.config/ainish-coder"
printf '%s\n' "$LIVE_PID" > "$HOME/.config/ainish-coder/watch.lock"
"$CLI" --machine-watch --once >/dev/null 2>&1
LOCK_RC=$?
check "a cycle refuses while another holds the lock" "1" "$LOCK_RC"
kill "$LIVE_PID" 2>/dev/null || true
wait "$LIVE_PID" 2>/dev/null || true
# A stale lock (dead pid) must be reclaimed, or one crash disables the watcher forever.
printf '999999\n' > "$HOME/.config/ainish-coder/watch.lock"
"$CLI" --machine-watch --once >/dev/null 2>&1
check "a stale lock is reclaimed" "0" "$?"

echo "== 6. --status reports without running a cycle =="
ST="$("$CLI" --machine-watch --status 2>&1)"
check "--status exits 0" "0" "$?"
if printf '%s' "$ST" | grep -q 'linked:'; then ok "--status reports linked repos"; else
    bad "--status did not report linked repos"; printf '%s\n' "$ST" | sed 's/^/    | /'; fi
JS="$("$CLI" --machine-watch --status --json 2>/dev/null)"
if printf '%s' "$JS" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["format"]=="ainish-coder/machine-watch/v1"; assert d["linked_repos"]>=1' 2>/dev/null; then
    ok "--status --json parses and counts the linked repo"
else
    bad "--status --json did not parse"; printf '%s\n' "$JS" | sed 's/^/    | /'
fi

echo "== 7. an unlinked machine refuses to start a watcher =="
: > "${WORK}/empty-links.txt"
AINISH_LINKS_FILE="${WORK}/empty-links.txt" "$CLI" --machine-watch --once >/dev/null 2>&1
check "no links means exit 1, not a silent no-op" "1" "$?"

echo "== 8. a FAILED cycle does not mark the change as synced (it must retry) =="
# The live regression this pins: on failure the fingerprint was recorded anyway, so a transient error
# marked the save "handled" and it never retried — a silent data-loss path. A change that did not
# arrive must stay pending.
#
# This section uses its OWN link file containing only repo E. A cycle covers every linked repo, and
# section 4 deliberately leaves machine-a with a blocked peer; running the fleet here would keep
# returning non-zero for that reason and hide whether E's pending change was retried.
E="${WORK}/machine-e/demo"
mkdir -p "$(dirname "$E")"
git clone -q "$SRC" "$E"
F="${WORK}/machine-f/demo"
mkdir -p "$(dirname "$F")"
git clone -q "$SRC" "$F"
E_RESOLVED="$(git -C "$E" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$E")"
F_RESOLVED="$(git -C "$F" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$F")"
printf 'box-18gb=self\npeer-f-16gb=%s\n' "${WORK}/machine-f" > "${WORK}/machines-f.txt"
SCOPED="${WORK}/links-only-e.txt"
printf '%s | peer-f-16gb | %s\n' "$E_RESOLVED" "$F_RESOLVED" > "$SCOPED"
printf 'work that must eventually arrive\n' > "$E/pending.txt"

# Break the peer, run one cycle, restore it.
mv "$F" "${F}.hidden"
RC8=1
AINISH_LINKS_FILE="$SCOPED" AINISH_MACHINES_FILE="${WORK}/machines-f.txt" "$CLI" --machine-watch --once >/dev/null 2>&1 || RC8=$?
mv "${F}.hidden" "$F"
check "the failing cycle exits non-zero" "1" "$RC8"
check "the peer did not receive it while it was broken" "MISSING" \
    "$( [[ -f "$F/pending.txt" ]] && cat "$F/pending.txt" || echo MISSING )"

# A failed cycle must leave the change PENDING. Two proofs: no fingerprint was stored, and a backoff
# entry exists. If the fingerprint had been written, the sync below would find "no change" and the
# save would be lost forever.
FPKEY="$(printf '%s' "$E_RESOLVED" | cksum | awk '{print $1}')"
FPF="${HOME}/.config/ainish-coder/fail-${FPKEY}"
FPFILE="${HOME}/.config/ainish-coder/fp-${FPKEY}"
[[ -f "$FPF" ]] && ok "a backoff entry exists after the failure" || bad "no backoff entry after a failed cycle"
[[ -f "$FPFILE" ]] && bad "the FAILED change was marked synced (fingerprint recorded)" \
    || ok "the failed change was NOT marked synced"

rm -f "$FPF" "$FPFILE"
AINISH_LINKS_FILE="$SCOPED" AINISH_MACHINES_FILE="${WORK}/machines-f.txt" "$CLI" --machine-watch --once >/dev/null 2>&1
check "the pending save is retried and arrives after recovery" "work that must eventually arrive" \
    "$(cat "$F/pending.txt" 2>/dev/null)"

echo "== 9. transport detection picks direct when readable, and reports 'none' when neither works =="
# This process can read the fixture repos, so detection must say 'direct'. The 'ssh' branch is proven
# live on the operator's external volume (a 1s loopback-ssh probe, verified by the installer); it is
# not asserted here because a hermetic fixture cannot reproduce macOS TCC, and faking it would be a
# test that passes for the wrong reason.
TD="$(bash -c 'source "'"$REPO"'/src/machine_watch.sh" >/dev/null 2>&1; _MW_TRANSPORT=auto; _mw_detect_transport "'"$A"'"' 2>/dev/null)"
check "a readable repo is synced directly" "direct" "$TD"
# A repo that does not exist must report 'none' rather than silently choosing something.
TN="$(bash -c 'source "'"$REPO"'/src/machine_watch.sh" >/dev/null 2>&1; _MW_TRANSPORT=auto; _mw_detect_transport "/nonexistent/repo"' 2>/dev/null)"
check "an unreadable repo reports no transport" "none" "$TN"
# --transport direct must not silently fall back to ssh when the repo is unreadable.
TDF="$(bash -c 'source "'"$REPO"'/src/machine_watch.sh" >/dev/null 2>&1; _MW_TRANSPORT=direct; _mw_detect_transport "/nonexistent/repo"' 2>/dev/null)"
check "--transport direct respects the pin" "none" "$TDF"

echo "== 10. --status names the transport in use =="
printf 'ssh\n' > "${HOME}/.config/ainish-coder/transport" 2>/dev/null || {
    mkdir -p "${HOME}/.config/ainish-coder"; printf 'ssh\n' > "${HOME}/.config/ainish-coder/transport"; }
STT="$("$CLI" --machine-watch --status 2>&1)"
if printf '%s' "$STT" | grep -q 'loopback ssh'; then
    ok "--status reports the loopback-ssh transport"
else
    bad "--status did not report the transport"; printf '%s\n' "$STT" | sed 's/^/    | /'
fi
JS2="$("$CLI" --machine-watch --status --json 2>/dev/null)"
if printf '%s' "$JS2" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["transport"]=="ssh"' 2>/dev/null; then
    ok "--status --json carries the transport"
else
    bad "--status --json lacks the transport"; printf '%s\n' "$JS2" | sed 's/^/    | /'
fi

echo "== 11. the installer records a path that survives a worktree being removed =="
# The live failure: installing from a worktree wrote the worktree's bin/ainish-coder into the plist, and
# removing the worktree left the daemon failing every cycle with "no such file or directory".
WT_RESOLVED="$(bash -c 'source "'"$REPO"'/src/machine_watch.sh" >/dev/null 2>&1; _mw_resolve_stable_cli' 2>/dev/null)"
if [[ "$WT_RESOLVED" == *"/bin/ainish-coder" ]]; then
    ok "resolved CLI ends in bin/ainish-coder"
else
    bad "resolved CLI looks wrong: $WT_RESOLVED"
fi
if [[ -x "$WT_RESOLVED" ]]; then
    ok "the recorded CLI actually exists and is executable"
else
    bad "the recorded CLI is not executable: $WT_RESOLVED"
fi
# It must NOT point into a disposable worktree when a main checkout is available.
MAIN_CHECKOUT="$(cd "$REPO" && git rev-parse --git-common-dir 2>/dev/null | xargs -I{} dirname {} 2>/dev/null || true)"
case "$WT_RESOLVED" in
    *"/watch-suggestions/"*|*"/watch-ssh-transport/"*|*"/machine-watch-daemon/"*)
        bad "the CLI path points into a disposable worktree: $WT_RESOLVED" ;;
    *)  ok "the CLI path is not a disposable worktree" ;;
esac

echo "== 12. ssh health is reported and a broken transport is explained =="
SHH="$(bash -c 'source "'"$REPO"'/src/machine_watch.sh" >/dev/null 2>&1; _mw_ssh_health' 2>/dev/null)"
case "$SHH" in
    ok|broken) ok "ssh health returns a known state ($SHH)" ;;
    *) bad "ssh health returned '$SHH'" ;;
esac
# The explanation must name the fix, or the operator is told a problem exists with no way out.
EXPL="$(bash -c 'source "'"$REPO"'/src/machine_watch.sh" >/dev/null 2>&1; _MW_SSH_ERROR="Permission denied (publickey)."; _mw_explain_ssh_failure' 2>&1)"
if printf '%s' "$EXPL" | grep -q 'ssh-copy-id localhost'; then
    ok "a publickey failure names ssh-copy-id as the fix"
else
    bad "the ssh failure explanation does not name the fix"; printf '%s\n' "$EXPL" | sed 's/^/    | /'
fi
if printf '%s' "$EXPL" | grep -qi 'not a problem with the repository'; then
    ok "the explanation rules out the repository as the cause"
else
    bad "the explanation does not distinguish transport from repository"
fi

echo "== 13. watch mode degrades to poll when fswatch is absent =="
WM="$(bash -c 'source "'"$REPO"'/src/machine_watch.sh" >/dev/null 2>&1; _MW_WATCH_MODE=auto; _mw_watch_mode' 2>/dev/null)"
if command -v fswatch >/dev/null 2>&1; then
    check "auto picks event mode when fswatch exists" "event" "$WM"
else
    check "auto picks poll when fswatch is absent" "poll" "$WM"
fi
WMP="$(bash -c 'source "'"$REPO"'/src/machine_watch.sh" >/dev/null 2>&1; _MW_WATCH_MODE=poll; _mw_watch_mode' 2>/dev/null)"
check "--poll always means poll" "poll" "$WMP"

echo "== 14. --auto-commit names the changed paths in the commit body =="
# A bare wip(<machine>) repeated is unreadable; the body must say what changed. Squashing is refused
# because SHAs are load-bearing (merge-base --is-ancestor, --latest attribution).
AP="${WORK}/peer-automsg/src-demo"
mkdir -p "$(dirname "$AP")"
git clone -q "$SRC" "$AP"
AP_MSG_DIR="${WORK}/peer-automsg/msg-demo"
git clone -q "$SRC" "$AP_MSG_DIR"
AP_RESOLVED="$(git -C "$AP" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$AP")"
AP_MSG_RESOLVED="$(git -C "$AP_MSG_DIR" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$AP_MSG_DIR")"
printf 'box-18gb=self\nauto-16gb=%s\n' "${WORK}/peer-automsg" > "${WORK}/machines-auto.txt"
# The links file must use the RESOLVED toplevel: --linked-only matches on it, and on macOS /var and
# /private/var are different strings for the same directory.
printf '%s | auto-16gb | %s\n' "$AP_RESOLVED" "$AP_MSG_RESOLVED" > "${WORK}/links-auto.txt"
printf 'one\n' > "$AP_RESOLVED/alpha.txt"
printf 'two\n' > "$AP_RESOLVED/beta.txt"
AINISH_MACHINES_FILE="${WORK}/machines-auto.txt" AINISH_LINKS_FILE="${WORK}/links-auto.txt" \
    "$CLI" --machine-sync "$AP_RESOLVED" --push --auto-commit --linked-only --quiet \
    --machines-file "${WORK}/machines-auto.txt" --links-file "${WORK}/links-auto.txt" >/dev/null 2>&1
BODY="$(git -C "$AP_RESOLVED" log -1 --format='%s%n%b' 2>/dev/null)"
if printf '%s' "$BODY" | grep -q 'alpha.txt' && printf '%s' "$BODY" | grep -q 'beta.txt'; then
    ok "the wip commit body lists the changed paths"
else
    bad "the wip commit body does not list changed paths"; printf '%s\n' "$BODY" | sed 's/^/    | /'
fi
if printf '%s' "$BODY" | grep -q 'changed 2 path(s)'; then
    ok "the body states how many paths changed"
else
    bad "the body does not state the change count"
fi
check "the commit subject stays a scannable one-liner" "1" "$(printf '%s' "$BODY" | head -1 | grep -c '^wip(')"

echo "== 15. sibling worktree edit triggers watcher snapshot without auto-committing worktree =="
WWT_A="${WORK}/wwt-a/demo"
WWT_B="${WORK}/wwt-b/demo"
WWT_SIB="${WORK}/wwt-a-sib"
mkdir -p "$(dirname "$WWT_A")" "$(dirname "$WWT_B")"
git clone -q "$SRC" "$WWT_A"
git clone -q "$SRC" "$WWT_B"
WWT_A_R="$(git -C "$WWT_A" rev-parse --show-toplevel)"
WWT_B_R="$(git -C "$WWT_B" rev-parse --show-toplevel)"
printf 'box-18gb=self\npeer-wwt-64gb=%s\n' "$(dirname "$WWT_B_R")" > "${WORK}/machines-wwt.txt"
printf '%s | peer-wwt-64gb | %s\n' "$WWT_A_R" "$WWT_B_R" > "${WORK}/links-wwt.txt"
# Baseline cycle so main checkout fingerprint is recorded.
AINISH_MACHINES_FILE="${WORK}/machines-wwt.txt" AINISH_LINKS_FILE="${WORK}/links-wwt.txt" \
    "$CLI" --machine-watch --once >/dev/null 2>&1
git -C "$WWT_A_R" worktree add -q -b feat/watched-wt "$WWT_SIB"
printf 'unsaved worktree edit\n' > "$WWT_SIB/wt-draft.txt"
AINISH_MACHINES_FILE="${WORK}/machines-wwt.txt" AINISH_LINKS_FILE="${WORK}/links-wwt.txt" \
    "$CLI" --machine-watch --once >/dev/null 2>&1
check "watcher cycle with dirty worktree exits 0" "0" "$?"
check "peer received sibling worktree draft snapshot" "unsaved worktree edit" \
    "$(git -C "$WWT_B_R" show 'refs/machine-sync/box-18gb/feat/watched-wt:wt-draft.txt' 2>/dev/null || echo MISSING)"
git -C "$WWT_SIB" status --porcelain wt-draft.txt | grep -q '^??' \
    && ok "watcher did not auto-commit inside sibling agent worktree" \
    || bad "watcher unexpectedly committed inside sibling worktree"

echo "== 16. --pull-now delivers peer commits to an idle local checkout =="
printf 'from peer while local idle\n' > "$WWT_B_R/from-peer-idle.txt"
git -C "$WWT_B_R" add from-peer-idle.txt && git -C "$WWT_B_R" commit -qm "peer idle commit"
AINISH_MACHINES_FILE="${WORK}/machines-wwt.txt" AINISH_LINKS_FILE="${WORK}/links-wwt.txt" \
    "$CLI" --machine-watch --once --pull-now >/dev/null 2>&1
check "--pull-now exits 0" "0" "$?"
check "idle local checkout received and fast-forwarded peer commit" "from peer while local idle" \
    "$(cat "$WWT_A_R/from-peer-idle.txt" 2>/dev/null || echo MISSING)"

echo
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 )) || exit 1
