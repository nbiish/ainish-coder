#!/bin/sh
# Validate an Elephant design artifact before implementation.
set -eu

design=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --design)
      [ "$#" -ge 2 ] || { echo "error: --design requires a path" >&2; exit 2; }
      design=$2
      shift 2
      ;;
    --help|-h)
      printf '%s\n' 'Usage: bin/egm-check.sh --design path/to/design.md'
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      exit 2
      ;;
  esac
done

[ -n "$design" ] || { echo 'error: --design is required' >&2; exit 2; }
[ -f "$design" ] || { echo "error: design not found: $design" >&2; exit 1; }

required='Problem
Goals
Non-goals
Constraints and invariants
Proposed architecture
Interfaces and data
Files and symbols
Alternatives considered
Risks and mitigations
Implementation plan
Verification and rollback'
missing=0
printf '%s\n' '=== EGM DESIGN CHECK ==='
printf 'design: %s\n' "$design"
while IFS= read -r heading; do
  [ -n "$heading" ] || continue
  if grep -Fq "## $heading" "$design"; then
    printf 'PASS: %s\n' "$heading"
  else
    printf 'FAIL: missing ## %s\n' "$heading"
    missing=1
  fi
done <<EOF
$required
EOF

if grep -nE '(^|[^[:alnum:]])TODO([^[:alnum:]]|$)|<short name>|<path>' "$design" >/dev/null 2>&1; then
  echo 'FAIL: unresolved placeholder or TODO'
  missing=1
fi

if [ "$missing" -ne 0 ]; then
  echo 'result: NOT_READY'
  exit 1
fi
echo 'result: READY_FOR_GOLDFISH'
