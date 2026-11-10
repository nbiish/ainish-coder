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
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

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

echo
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 )) || exit 1
