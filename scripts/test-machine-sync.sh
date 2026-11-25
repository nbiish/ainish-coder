#!/usr/bin/env bash
# test-machine-sync.sh — hermetic proof for `ainish-coder --machine-sync`.
#
# Two local checkouts stand in for two machines, so the gate needs no SSH and no network. It proves
# the four properties the verb exists for, and one it must never break:
#   1. branches cross in both directions, as refs/remotes/<machine>/*
#   2. uncommitted work crosses as a snapshot commit, so a dirty tree is readable on the peer
#   3. ignored files never cross (a bundle carries commits, not a directory tree)
#   4. the peer's HEAD, branch, index, and working tree are untouched
#   5. capacity filtering selects peers by the number in their name
# Usage: bash scripts/test-machine-sync.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${REPO}/bin/ainish-coder"
PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$*"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$*"; }
check() { # description expected actual
    if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (got '$3', want '$2')"; fi
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/machine-sync-test.XXXXXX")"
cleanup() {
    command -v chflags >/dev/null 2>&1 && chflags -R nouchg "$WORK" 2>/dev/null || true
    chmod -R u+w "$WORK" 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

export AINISH_FEDERATION_KEYS_DIR="${WORK}/fed-keys"

export GIT_AUTHOR_NAME="gate" GIT_AUTHOR_EMAIL="gate@ainish.local"
export GIT_COMMITTER_NAME="gate" GIT_COMMITTER_EMAIL="gate@ainish.local"
export GIT_CONFIG_GLOBAL="${WORK}/gitconfig"
git config --global init.defaultBranch main
git config --global commit.gpgsign false

# ── fixture ──────────────────────────────────────────────────────────────────
SRC="${WORK}/src/demo"
mkdir -p "$SRC"
git -C "$SRC" init -q
printf '*.log\n*.exe\n' > "$SRC/.gitignore"
printf 'line one\n' > "$SRC/tracked.txt"
printf 'release 1\n' > "$SRC/README.md"
git -C "$SRC" add -A
git -C "$SRC" commit -qm "initial"

A="${WORK}/machine-a/demo"
B="${WORK}/machine-b/demo"
mkdir -p "$(dirname "$A")" "$(dirname "$B")"
git clone -q "$SRC" "$A"
git clone -q "$SRC" "$B"

# machine A: a feature branch and a dirty tree
git -C "$A" checkout -q -b feature/a
printf 'line one\nline two from A\n' > "$A/tracked.txt"
printf 'work only A has\n' > "$A/uncommitted-from-a.txt"
printf 'ignored build output\n' > "$A/debug.log"
printf 'binary-ish payload\n' > "$A/tool.exe"

# machine B: its own branch and its own dirty tree
git -C "$B" checkout -q -b feature/b
printf 'line one\nline two from B\n' > "$B/tracked.txt"
printf 'work only B has\n' > "$B/uncommitted-from-b.txt"
printf 'ignored on B\n' > "$B/debug.log"

REG="${WORK}/machines.txt"
cat > "$REG" <<EOF
# hermetic fixture: two checkouts, capacity-named
box-18gb=self
peer-b-64gb=$(dirname "$B")
tinypeer-8gb=$(dirname "$B")
EOF

B_HEAD_BEFORE="$(git -C "$B" rev-parse HEAD)"
B_BRANCH_BEFORE="$(git -C "$B" rev-parse --abbrev-ref HEAD)"
B_STATUS_BEFORE="$(git -C "$B" status --porcelain | sort)"
A_HEAD_BEFORE="$(git -C "$A" rev-parse HEAD)"

echo "== --machine-sync: push + pull between two checkouts =="
OUT="$("$CLI" --machine-sync --repo "$A" --machines-file "$REG" --machine peer-b-64gb --both 2>&1)"
RC=$?
check "sync exits 0" "0" "$RC"
if [[ "$RC" != "0" ]]; then printf '%s\n' "$OUT" | sed 's/^/    | /'; fi

echo "== 1. branches crossed as refs/remotes =="
git -C "$B" rev-parse -q --verify refs/remotes/box-18gb/feature/a >/dev/null 2>&1 && ok "peer B received A's feature/a branch" || bad "peer B missing refs/remotes/box-18gb/feature/a"
git -C "$B" rev-parse -q --verify refs/remotes/box-18gb/main >/dev/null 2>&1 && ok "peer B received A's main" || bad "peer B missing refs/remotes/box-18gb/main"
git -C "$A" rev-parse -q --verify refs/remotes/peer-b-64gb/feature/b >/dev/null 2>&1 && ok "A received B's feature/b branch" || bad "A missing refs/remotes/peer-b-64gb/feature/b"

echo "== 2. uncommitted work crossed as a snapshot =="
A_WIP="$(git -C "$A" for-each-ref --format='%(refname)' 'refs/machine-sync/box-18gb/feature/a' 2>/dev/null | head -1)"
[[ -n "$A_WIP" ]] && ok "A snapshotted its dirty tree onto $A_WIP" || bad "A did not create a machine-sync snapshot ref"
check "snapshot carries the new untracked file" "work only A has" "$(git -C "$B" show "${A_WIP}:uncommitted-from-a.txt" 2>/dev/null)"
check "snapshot carries the tracked edit" "line one
line two from A" "$(git -C "$B" show "${A_WIP}:tracked.txt" 2>/dev/null)"
B_WIP="$(git -C "$B" for-each-ref --format='%(refname)' 'refs/machine-sync/peer-b-64gb/feature/b' 2>/dev/null | head -1)"
[[ -n "$B_WIP" ]] && ok "B's dirty tree arrived here as $B_WIP" || bad "B's uncommitted work did not arrive"
check "B's untracked file is readable here" "work only B has" "$(git -C "$A" show "${B_WIP}:uncommitted-from-b.txt" 2>/dev/null)"

echo "== 3. ignored files never cross =="
git -C "$B" cat-file -e "${A_WIP}:debug.log" 2>/dev/null && bad "ignored debug.log crossed the wire" || ok "ignored debug.log stayed on machine A"
git -C "$B" cat-file -e "${A_WIP}:tool.exe" 2>/dev/null && bad "ignored tool.exe crossed the wire" || ok "ignored tool.exe stayed on machine A"

echo "== 4. the peer was not disturbed =="
check "B's HEAD unchanged" "$B_HEAD_BEFORE" "$(git -C "$B" rev-parse HEAD)"
check "B's branch unchanged" "$B_BRANCH_BEFORE" "$(git -C "$B" rev-parse --abbrev-ref HEAD)"
check "B's working tree unchanged" "$B_STATUS_BEFORE" "$(git -C "$B" status --porcelain | sort)"
check "A's HEAD unchanged" "$A_HEAD_BEFORE" "$(git -C "$A" rev-parse HEAD)"

echo "== 4b. the push is verified against what the peer actually recorded =="
A_HEAD_NOW="$(git -C "$A" rev-parse HEAD)"
check "peer's remote-tracking ref matches this machine's HEAD" "$A_HEAD_NOW" "$(git -C "$B" rev-parse refs/remotes/box-18gb/feature/a 2>/dev/null)"

echo "== 4c. --ff-peers moves a clean peer checkout, and only that =="
git -C "$B" update-ref refs/remotes/machine-2-32gb/feature/b "$(git -C "$B" rev-parse HEAD)" 2>/dev/null || true
B_TIP_BEFORE="$(git -C "$B" rev-parse refs/remotes/box-18gb/feature/a)"
"$CLI" --machine-sync --repo "$A" --machines-file "$REG" --machine peer-b-64gb --push --ff-peers >/dev/null 2>&1
check "--ff-peers fast-forwards the peer's checked-out branch" "$B_TIP_BEFORE" "$(git -C "$B" rev-parse HEAD)"
printf 'dirty
' >> "$B/tracked.txt"
B_DIRTY_TIP="$(git -C "$B" rev-parse HEAD)"
printf 'next\n' >> "$A/tracked.txt"
git -C "$A" commit -qam "advance a"
"$CLI" --machine-sync --repo "$A" --machines-file "$REG" --machine peer-b-64gb --push --ff-peers >/dev/null 2>&1
check "--ff-peers refuses to move a dirty peer tree" "$B_DIRTY_TIP" "$(git -C "$B" rev-parse HEAD)"
git -C "$B" checkout -q -- tracked.txt

echo "== 5. repeat run is idempotent =="
B_HEAD_AFTER_FIRST="$(git -C "$B" rev-parse HEAD)"
"$CLI" --machine-sync --repo "$A" --machines-file "$REG" --machine peer-b-64gb --both >/dev/null 2>&1
RC2=$?
check "second sync exits 0" "0" "$RC2"
check "peer HEAD still unchanged" "$B_HEAD_AFTER_FIRST" "$(git -C "$B" rev-parse HEAD)"

echo "== 6. capacity filtering =="
DRY="$("$CLI" --machine-sync --repo "$A" --machines-file "$REG" --min-ram 32 --dry-run 2>&1)"
if printf '%s' "$DRY" | grep -q 'peer-b-64gb' && ! printf '%s' "$DRY" | grep -q 'tinypeer-8gb'; then
    ok "--min-ram 32 selects the 64 GB peer and skips the 8 GB one"
else
    bad "--min-ram 32 did not filter by capacity"; printf '%s\n' "$DRY" | sed 's/^/    | /'
fi

echo "== 7. --status reports without moving anything =="
ST="$("$CLI" --machine-sync --repo "$A" --machines-file "$REG" --machine peer-b-64gb --status 2>&1)"
if printf '%s' "$ST" | grep -q 'feature/b'; then ok "--status lists the peer's known branches"; else bad "--status did not report peer refs"; printf '%s\n' "$ST" | sed 's/^/    | /'; fi

echo "== 8. --json is valid JSON =="
JS="$("$CLI" --machine-sync --repo "$A" --machines-file "$REG" --machine peer-b-64gb --json 2>/dev/null)"
if printf '%s' "$JS" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["peers"][0]["name"]=="peer-b-64gb"; assert d["peers"][0]["ram_gb"]==64' 2>/dev/null; then
    ok "--json parses and carries the peer capacity"
else
    bad "--json did not parse"; printf '%s\n' "$JS" | sed 's/^/    | /'
fi

echo "== 8b. a one-direction run succeeds without the other direction =="
"$CLI" --machine-sync --repo "$A" --machines-file "$REG" --machine peer-b-64gb --pull >/dev/null 2>&1
check "pull-only exits 0" "0" "$?"
"$CLI" --machine-sync --repo "$A" --machines-file "$REG" --machine peer-b-64gb --push >/dev/null 2>&1
check "push-only exits 0" "0" "$?"

echo "== 9. a missing peer repository fails closed =="
printf 'peer-b-64gb=%s\n' "$(dirname "$B")" > "${WORK}/machines-bad.txt"
printf 'box-18gb=self\npeer-b-64gb=%s/nonexistent-root\n' "${WORK}" >> "${WORK}/machines-bad.txt"
"$CLI" --machine-sync --repo "$A" --machines-file "${WORK}/machines-bad.txt" --machine peer-b-64gb >/dev/null 2>&1
RC3=$?
check "unreachable peer exits 1" "1" "$RC3"

# ── links: a peer path recorded once, used without flags ─────────────────────
#
# The failure this covers is the one that made the verb unusable in practice: peer paths were guessed
# as `<peer-root>/<repo-name>`, so a repo kept under different trees on two machines was addressed at
# a path that did not exist. A link is the fix, and these assertions are what keep it working.
echo "== 10. --machine-link records a peer path that --machine-sync then uses =="
LINKS="${WORK}/links.txt"
export AINISH_LINKS_FILE="$LINKS"
# Deliberately give the peer a DIFFERENT directory name, so the name-based guess cannot succeed and
# only the recorded link can resolve the path.
C="${WORK}/peer-c/renamed-demo"
mkdir -p "$(dirname "$C")"
git clone -q "$SRC" "$C"
printf 'box-18gb=self\npeer-c-32gb=%s\n' "$(dirname "$C")" > "${WORK}/machines-c.txt"
LK="$("$CLI" --machine-link --repo "$A" --peer peer-c-32gb \
        --peer-path "$C" --machines-file "${WORK}/machines-c.txt" 2>&1)"
check "--machine-link exits 0" "0" "$?"
[[ -f "$LINKS" ]] && ok "links registry written" || bad "links registry missing"
grep -qF "peer-c-32gb | $C" "$LINKS" 2>/dev/null && ok "registry records the peer path" \
    || bad "registry does not record the peer path"
# The name-based guess would look for <peer root>/demo, which does not exist.
SY="$("$CLI" --machine-sync --repo "$A" --machines-file "${WORK}/machines-c.txt" \
        --machine peer-c-32gb --direction-push 2>/dev/null || true)"
SY="$("$CLI" --machine-sync --repo "$A" --machines-file "${WORK}/machines-c.txt" \
        --machine peer-c-32gb --push 2>&1)"
check "sync through the link exits 0" "0" "$?"
if printf '%s' "$SY" | grep -q 'path from link'; then
    ok "sync reports the path came from the link"
else
    bad "sync did not report a linked path"; printf '%s\n' "$SY" | sed 's/^/    | /'
fi

echo "== 11. --machine-link installed a working post-commit hook =="
[[ -f "$A/.git/hooks/post-commit" ]] && ok "post-commit hook installed" || bad "no post-commit hook"
grep -qF "AINISH-CODER MACHINE SYNC START" "$A/.git/hooks/post-commit" 2>/dev/null \
    && ok "hook carries the managed block" || bad "hook block missing"
# The hook must send, never receive: receiving moves this machine's branch unattended.
grep -qF -- "--push" "$A/.git/hooks/post-commit" 2>/dev/null && ok "hook is push-only" \
    || bad "hook is not push-only"
grep -qF -- "--linked-only" "$A/.git/hooks/post-commit" 2>/dev/null \
    && ok "hook is scoped to linked peers" || bad "hook would push to every peer"

echo "== 11b. a commit propagates to the linked peer with no command =="
# The peer must be on the SAME branch for a fast-forward to be legitimate — a peer on a different
# branch is deliberately left alone (asserted in 4c). A is on feature/a here, so put C there too.
git -C "$C" checkout -q -B feature/a 2>/dev/null || git -C "$C" checkout -q feature/a
C_BEFORE="$(git -C "$C" rev-parse HEAD)"
printf 'linked edit\n' > "$A/linked-edit.txt"
git -C "$A" add linked-edit.txt
git -C "$A" commit -qm "linked edit"
A_AFTER="$(git -C "$A" rev-parse HEAD)"
C_AFTER="$(git -C "$C" rev-parse HEAD)"
check "peer advanced to the new commit automatically" "$A_AFTER" "$C_AFTER"
[[ "$C_BEFORE" != "$C_AFTER" ]] && ok "peer HEAD moved off its old commit" || bad "peer HEAD never moved"

echo "== 11c. the hook is idempotent and removable =="
HOOK_SUM_BEFORE="$(cksum "$A/.git/hooks/post-commit" 2>/dev/null)"
"$CLI" --machine-link --repo "$A" --peer peer-c-32gb --peer-path "$C" \
    --machines-file "${WORK}/machines-c.txt" >/dev/null 2>&1
HOOK_SUM_AFTER="$(cksum "$A/.git/hooks/post-commit" 2>/dev/null)"
check "re-linking does not stack hook blocks" "$HOOK_SUM_BEFORE" "$HOOK_SUM_AFTER"
check "re-linking keeps one registry row" "1" "$(grep -cF "peer-c-32gb | $C" "$LINKS" 2>/dev/null)"
"$CLI" --machine-link --repo "$A" --peer peer-c-32gb --remove \
    --machines-file "${WORK}/machines-c.txt" >/dev/null 2>&1
check "--remove exits 0" "0" "$?"
grep -qF "peer-c-32gb" "$LINKS" 2>/dev/null && bad "link survived --remove" || ok "link removed"
[[ -f "$A/.git/hooks/post-commit" ]] && bad "hook survived --remove" || ok "hook removed with the link"

echo "== 12. --all runs every linked repo, and fails closed when nothing is linked =="
# Re-link both A and a second clone, then sync both in one command.
D="${WORK}/peer-c/renamed-two"
git clone -q "$SRC" "$D"
"$CLI" --machine-link --repo "$A" --peer peer-c-32gb --peer-path "$C" \
    --machines-file "${WORK}/machines-c.txt" --no-hooks >/dev/null 2>&1
ALL="$("$CLI" --machine-sync --all --machines-file "${WORK}/machines-c.txt" 2>&1)"
check "--all exits 0" "0" "$?"
if printf '%s' "$ALL" | grep -q 'renamed-demo'; then ok "--all visited the linked repo"; else
    bad "--all did not visit the linked repo"; printf '%s\n' "$ALL" | sed 's/^/    | /'
fi
EMPTY="${WORK}/links-empty.txt"
: > "$EMPTY"
AINISH_LINKS_FILE="$EMPTY" "$CLI" --machine-sync --all --machines-file "${WORK}/machines-c.txt" >/dev/null 2>&1
check "--all with no links exits 1 (nothing linked is not success)" "1" "$?"

echo "== 13. --quiet is silent, and errors still reach stderr =="
QUIET_OUT="$("$CLI" --machine-sync --repo "$A" --machines-file "${WORK}/machines-c.txt" \
    --machine peer-c-32gb --push --linked-only --quiet 2>/dev/null)"
check "--quiet prints nothing on stdout" "" "$QUIET_OUT"

echo "== 14. --dry-run survives a peer that has never synced from here =="
# The regression: an unguarded `rev-list` against a missing peer ref aborted the whole run under
# `set -e`, printing a truncated header and exiting 1. A fresh checkout has no such ref.
# The checkout must share the repo's directory name in its OWN root, or the peer resolves to a path
# that does not exist and the dry run reports "unreachable" instead of forecasting.
E_ROOT="${WORK}/peer-fresh"
E="${E_ROOT}/demo"
mkdir -p "$E_ROOT"
git clone -q "$SRC" "$E"
printf 'box-18gb=self\nfresh-8gb=%s\n' "$E_ROOT" > "${WORK}/machines-fresh.txt"
DRY="$("$CLI" --machine-sync --repo "$A" --machines-file "${WORK}/machines-fresh.txt" \
    --machine fresh-8gb --dry-run 2>&1)"
check "--dry-run on a never-synced peer exits 0" "0" "$?"
if printf '%s' "$DRY" | grep -qi 'never synced'; then
    ok "--dry-run explains that the peer has no ref yet"
else
    bad "--dry-run gave no forecast for an unsynced peer"; printf '%s\n' "$DRY" | sed 's/^/    | /'
fi

# ── branch materialisation and --latest ─────────────────────────────────────
#
# A delivered refs/remotes/<machine>/<branch> is not a branch you can work on. These assertions pin the
# two properties that make "sync all branches" true: absent branches are created, and an existing
# branch that disagrees is never moved.
echo "== 15. --branches materialises every branch on the peer =="
M="${WORK}/peer-m/src-demo"
N="${WORK}/peer-m/dst-demo"
mkdir -p "$(dirname "$M")" "$(dirname "$N")"
git clone -q "$SRC" "$M"
git clone -q "$SRC" "$N"
# Give M two branches that N does not have.
git -C "$M" checkout -q -b feat/alpha && git -C "$M" -c user.email=g@a -c user.name=g commit -q --allow-empty -m alpha
git -C "$M" checkout -q -b feat/beta  && git -C "$M" -c user.email=g@a -c user.name=g commit -q --allow-empty -m beta
git -C "$M" checkout -q main
printf 'box-18gb=self\npeer-m-16gb=%s\n' "$(dirname "$N")" > "${WORK}/machines-m.txt"
# The peer directory is deliberately named differently from this repo, so only a recorded link can
# resolve it — the same situation as D:/Code/x on Windows versus a remote code root on the Mac.
"$CLI" --machine-link --repo "$M" --peer peer-m-16gb --peer-path "$N" \
    --machines-file "${WORK}/machines-m.txt" --no-hooks >/dev/null 2>&1
check "peer starts with only main" "main" "$(git -C "$N" branch --format='%(refname:short)' | tr '\n' ' ' | sed 's/ $//')"
MB="$("$CLI" --machine-sync --repo "$M" --machines-file "${WORK}/machines-m.txt" \
    --machine peer-m-16gb --push --branches 2>&1)"
check "--branches exits 0" "0" "$?"
N_BRANCHES="$(git -C "$N" branch --format='%(refname:short)' | sort | tr '\n' ' ')"
if printf '%s' "$N_BRANCHES" | grep -q 'feat/alpha' && printf '%s' "$N_BRANCHES" | grep -q 'feat/beta'; then
    ok "peer gained feat/alpha and feat/beta as local branches"
else
    bad "peer did not gain the branches (has: $N_BRANCHES)"; printf '%s\n' "$MB" | sed 's/^/    | /'
fi
# A created branch must point at the sender's tip, not merely exist.
check "created branch points at the sender's tip" \
    "$(git -C "$M" rev-parse feat/alpha)" "$(git -C "$N" rev-parse feat/alpha)"

echo "== 16. a diverged branch is never moved =="
# Both sides get their own commit on the same branch name, with no common tip.
git -C "$N" checkout -q -b feat/diverged
git -C "$N" -c user.email=g@a -c user.name=g commit -q --allow-empty -m "N-only work"
N_DIV_TIP="$(git -C "$N" rev-parse feat/diverged)"
git -C "$M" checkout -q -b feat/diverged
git -C "$M" -c user.email=g@a -c user.name=g commit -q --allow-empty -m "M-only work"
git -C "$M" checkout -q main
DV="$("$CLI" --machine-sync --repo "$M" --machines-file "${WORK}/machines-m.txt" \
    --machine peer-m-16gb --push --branches 2>&1)"
check "--branches exits 0 when a branch diverges" "0" "$?"
check "the peer's diverged branch is byte-identical afterwards" "$N_DIV_TIP" "$(git -C "$N" rev-parse feat/diverged)"
if printf '%s' "$DV" | grep -qi 'DIVERGED'; then
    ok "the divergence is reported, not hidden"
else
    bad "divergence was not reported"; printf '%s\n' "$DV" | sed 's/^/    | /'
fi

echo "== 17. --latest names the newest machine per branch =="
LT="$("$CLI" --machine-sync --repo "$M" --machines-file "${WORK}/machines-m.txt" \
    --machine peer-m-16gb --latest 2>&1)"
check "--latest exits 0" "0" "$?"
if printf '%s' "$LT" | grep -q 'feat/alpha'; then
    ok "--latest reports every branch"
else
    bad "--latest did not list branches"; printf '%s\n' "$LT" | sed 's/^/    | /'
fi
if printf '%s' "$LT" | grep -q 'NEWEST ON'; then ok "--latest has a where column"; else bad "--latest lacks the machine column"; fi
LJ="$("$CLI" --machine-sync --repo "$M" --machines-file "${WORK}/machines-m.txt" \
    --machine peer-m-16gb --latest --json 2>/dev/null)"
if printf '%s' "$LJ" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["format"]=="ainish-coder/machine-latest/v1"; assert len(d["branches"])>=3' 2>/dev/null; then
    ok "--latest --json parses and carries branches"
else
    bad "--latest --json did not parse"; printf '%s\n' "$LJ" | sed 's/^/    | /'
fi
# The newest commit on feat/alpha is M's, so M must be named as the holder.
if printf '%s' "$LJ" | python3 -c '
import json,sys
d=json.load(sys.stdin)
row=[b for b in d["branches"] if b["branch"]=="feat/alpha"][0]
assert row["newest_machine"].split("+")[0].split("~")[0]=="box-18gb", row
' 2>/dev/null; then
    ok "--latest attributes feat/alpha to the machine that holds it"
else
    bad "--latest misattributed feat/alpha"
fi

echo "== 18. cross-platform UTC dates, missing-repo vs unreachable hint, and --doctor --json =="
if printf '%s' "$LT" | grep -qE '20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}'; then
    ok "--latest formats UTC ISO timestamps (not raw epoch) on this platform"
else
    bad "--latest did not format UTC ISO timestamp"; printf '%s\n' "$LT" | sed 's/^/    | /'
fi

MISSING_PEER="${WORK}/peer-missing-root"
mkdir -p "$MISSING_PEER"
printf 'box-18gb=self\ngone-16gb=%s\n' "$MISSING_PEER" > "${WORK}/machines-gone.txt"
MISS_OUT="$("$CLI" --machine-sync --repo "$M" --machines-file "${WORK}/machines-gone.txt" \
    --machine gone-16gb --latest 2>&1)"
if printf '%s' "$MISS_OUT" | grep -q -- '--machine-link'; then
    ok "missing local repo at peer path suggests --machine-link fix"
else
    bad "missing repo did not suggest --machine-link"; printf '%s\n' "$MISS_OUT" | sed 's/^/    | /'
fi

DOC_HERMES="${WORK}/doc-hermes"
DOC_PI="${WORK}/doc-pi"
for p in context-elephant context-goldfish consolidate-elephant consolidate-goldfish consolidate-archivist consolidate-structural; do
    mkdir -p "${DOC_HERMES}/profiles/${p}"
    printf 'model:\n  default: local-router/fallback-models\n' > "${DOC_HERMES}/profiles/${p}/config.yaml"
done
mkdir -p "$DOC_PI"
printf '{"providers":{"local-router":{"baseUrl":"http://127.0.0.1:11434/v1"}}}\n' > "${DOC_PI}/models.json"
DOC_JSON="$(HERMES_HOME="$DOC_HERMES" PI_CODING_AGENT_DIR="$DOC_PI" AINISH_LOCAL_ROUTER_URL="http://127.0.0.1:9" \
    "$CLI" --machine-sync --doctor --json --machines-file "${WORK}/machines-c.txt" --links-file "$LINKS" 2>/dev/null || true)"
if printf '%s' "$DOC_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["format"]=="ainish-coder/machine-doctor/v1"; assert d["context_agents"]["profiles_ready"]==6; assert d["context_agents"]["pi_wired"] is True' 2>/dev/null; then
    ok "--machine-sync --doctor --json reports 6/6 Hermes profiles and pi wiring"
else
    bad "--machine-sync --doctor --json payload invalid"; printf '%s\n' "$DOC_JSON" | sed 's/^/    | /'
fi

echo "== 19. PQC agent-read-only gitignored federation CoD exchange =="
FED_TODAY="$(date -u +%F)"
FED_A="${WORK}/fed-a/demo"
FED_B="${WORK}/fed-b/demo"
mkdir -p "$(dirname "$FED_A")" "$(dirname "$FED_B")"
git clone -q "$SRC" "$FED_A"
git clone -q "$SRC" "$FED_B"
printf '\n.agents/federation/*.md\n' >> "$FED_A/.gitignore"
printf '\n.agents/federation/*.md\n' >> "$FED_B/.gitignore"
git -C "$FED_A" add .gitignore && git -C "$FED_A" commit -qm "chore: ignore federation md"
git -C "$FED_B" add .gitignore && git -C "$FED_B" commit -qm "chore: ignore federation md"
git -C "$FED_A" checkout -qb feat/fed-alpha
echo "alpha" > "$FED_A/alpha.txt"
git -C "$FED_A" add alpha.txt && git -C "$FED_A" commit -qm "feat: alpha on A"
git -C "$FED_B" checkout -qb feat/fed-beta
echo "beta" > "$FED_B/beta.txt"
git -C "$FED_B" add beta.txt && git -C "$FED_B" commit -qm "feat: beta on B"

cat > "${WORK}/machines-fed.txt" <<EOF
box-18gb=self
peer-b-64gb=$(dirname "$FED_B")
EOF

FED_OUT="$("$CLI" --machine-sync --repo "$FED_A" --machines-file "${WORK}/machines-fed.txt" --machine peer-b-64gb --both 2>&1)"
[[ -f "${FED_A}/.agents/federation/${FED_TODAY}.md" && -f "${FED_B}/.agents/federation/${FED_TODAY}.md" ]] \
    && ok "PQC federation CoD file materialized on both peers" \
    || bad "PQC federation CoD file missing after sync: $FED_OUT"
grep -q 'box-18gb | branch:feat/fed-alpha' "${FED_B}/.agents/federation/${FED_TODAY}.md" \
    && grep -q 'peer-b-64gb | branch:feat/fed-beta' "${FED_A}/.agents/federation/${FED_TODAY}.md" \
    && ok "both peers hold union-merged CoD entries from each other" \
    || bad "federation CoD entries did not union-merge across peers"
[[ ! -w "${FED_A}/.agents/federation/${FED_TODAY}.md" && ! -w "${FED_B}/.agents/federation/${FED_TODAY}.md" ]] \
    && ok "federation CoD files are OS-locked read-only for agents on both peers" \
    || bad "federation CoD files are writable (agent read-only lock missing)"
[[ -z "$(git -C "$FED_A" status --porcelain)" && -z "$(git -C "$FED_B" status --porcelain)" ]] \
    && ok "gitignored federation CoD files leave both git trees completely clean" \
    || bad "federation CoD files dirtied git status"

echo
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 )) || exit 1
