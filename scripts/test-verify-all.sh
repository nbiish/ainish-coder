#!/usr/bin/env bash
# Runs every hermetic verification script and reports one line each. Exit 0 only if all pass.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

failed=0
# These scripts use bash-isms (`declare -F`, process substitution, arrays) deliberately: they test
# bash-implemented deployment code. Running them under `sh` (dash) would fail on the harness rather
# than the behaviour, so invoke bash explicitly.
for s in scripts/test-rules-isolation.sh scripts/test-rules-deploy-isolation.sh scripts/test-agents-corpus-coverage.sh scripts/test-knowledge-roundtrip.sh scripts/test-cross-platform.sh; do
    out="$(bash "$s" 2>&1)"
    rc=$?
    pass=$(printf '%s\n' "$out" | grep -c '^PASS')
    fail=$(printf '%s\n' "$out" | grep -c '^FAIL')
    if [ "$rc" -eq 0 ]; then
        echo "PASS $s (${pass} assertions)"
    else
        echo "FAIL $s (exit $rc, ${fail} failed)"
        printf '%s\n' "$out" | grep '^FAIL' | sed 's/^/     /'
        failed=1
    fi
done
exit $failed
