#!/usr/bin/env bash
# End-to-end proof that `ainish-coder --rules` distributes the CONTRACT and never this repo's
# CONTENT. A target is seeded with its own .agents/rag + .agents/wiki state, the rules bundle is
# deployed into it, and the test asserts:
#
#   1. contract surfaces arrive (AGENTS.md, .agents/llms.txt),
#   2. the target's own .agents/rag and .agents/wiki are untouched (byte-identical),
#   3. the deployed manifest never names repo-local state,
#   4. no source-repo memory/plan/task file reaches the target.
#
# Hermetic: HOME and AINISH_CONFIG_DIR are redirected into a temp dir, so the operator's real fleet
# registry, skill selection, and backups are never read or written.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t ainish-rules-isolation)"
cleanup() { rm -rf "$WORK" 2>/dev/null || true; }
trap cleanup EXIT

export HOME="${WORK}/home"
export AINISH_CONFIG_DIR="${WORK}/config"
export AINISH_SKILLS_PROMPT=off
export AINISH_AGENTS_BACKUP=false
mkdir -p "$HOME" "$AINISH_CONFIG_DIR"

TARGET="${WORK}/target-repo"
mkdir -p "$TARGET/.agents/rag/lancedb" "$TARGET/.agents/wiki" "$TARGET/.agents/memories" \
         "$TARGET/.agents/tasks" "$TARGET/.agents/plans"
git -C "$TARGET" init -q 2>/dev/null || true

# Target-local state that must survive the deploy untouched.
printf 'TARGET-OWNED-VECTORS\n'  > "$TARGET/.agents/rag/sentinel.txt"
printf '# Target wiki\n\nTARGET-WIKI-BODY\n' > "$TARGET/.agents/wiki/README.md"
printf -- '- target memory fact\n' > "$TARGET/.agents/memories/2026-11-01-memory.txt"
printf '# target task\n' > "$TARGET/.agents/tasks/2026-11-01-task.md"
printf '# target plan\n' > "$TARGET/.agents/plans/2026-11-01-x.plan.md"

before_rag="$(cat "$TARGET/.agents/rag/sentinel.txt")"
before_wiki="$(cat "$TARGET/.agents/wiki/README.md")"
before_mem="$(cat "$TARGET/.agents/memories/2026-11-01-memory.txt")"
before_task="$(cat "$TARGET/.agents/tasks/2026-11-01-task.md")"
before_plan="$(cat "$TARGET/.agents/plans/2026-11-01-x.plan.md")"

fail=0
report() {
    if [ "$1" -eq 0 ]; then echo "PASS $2"; else echo "FAIL $2"; fail=1; fi
}

if ! bash "${REPO_ROOT}/bin/ainish-coder" --rules "$TARGET" --headless -y >"${WORK}/deploy.log" 2>&1; then
    echo "FAIL --rules deploy exited non-zero; tail:"
    tail -n 25 "${WORK}/deploy.log"
    exit 1
fi
echo "PASS --rules deploy exited zero"

# 1. Contract surfaces arrive.
[ -f "$TARGET/AGENTS.md" ]; report $? "AGENTS.md deployed"
[ -f "$TARGET/.agents/llms.txt" ]; report $? ".agents/llms.txt deployed (the tree map)"

# 2. Target-local state untouched.
[ "$(cat "$TARGET/.agents/rag/sentinel.txt" 2>/dev/null)" = "$before_rag" ]; \
    report $? ".agents/rag left untouched"
[ "$(cat "$TARGET/.agents/wiki/README.md" 2>/dev/null)" = "$before_wiki" ]; \
    report $? ".agents/wiki left untouched"
[ "$(cat "$TARGET/.agents/memories/2026-11-01-memory.txt" 2>/dev/null)" = "$before_mem" ]; \
    report $? ".agents/memories left untouched"
[ "$(cat "$TARGET/.agents/tasks/2026-11-01-task.md" 2>/dev/null)" = "$before_task" ]; \
    report $? ".agents/tasks left untouched"
[ "$(cat "$TARGET/.agents/plans/2026-11-01-x.plan.md" 2>/dev/null)" = "$before_plan" ]; \
    report $? ".agents/plans left untouched"

# 3. The deployed manifest never names repo-local state in managed_paths.
MANIFEST="$TARGET/.agents/ainish-deploy.json"
if [ -f "$MANIFEST" ]; then
    managed_block="$(sed -n '/"managed_paths": \[/,/\]/p' "$MANIFEST")"
    case "$managed_block" in
        *.agents/rag*|*.agents/wiki*|*.agents/memories*|*.agents/tasks*|*.agents/plans*|*.agents/suggestions*)
            report 1 "manifest managed_paths names repo-local state" ;;
        *)
            report 0 "manifest managed_paths names only contract surfaces" ;;
    esac
else
    report 1 "manifest was written"
fi

# 4. No source-repo plan or memory ARTIFACT leaked in. The distributed `plans/llms.txt` index is
#    contract surface and is expected; a `.plan.md` from this repo is content and must not arrive.
leaked_plans="$(find "$TARGET/.agents/plans" -name '*.plan.md' 2>/dev/null | grep -v '2026-11-01' || true)"
[ -z "$leaked_plans" ]; report $? "no source-repo plan artifacts were copied in"

leaked_mem="$(find "$TARGET/.agents/memories" -name '*-memory.txt' 2>/dev/null | grep -v '2026-11-01' || true)"
[ -z "$leaked_mem" ]; report $? "no source-repo memory files were copied in"

leaked_tasks="$(find "$TARGET/.agents/tasks" -name '*.md' 2>/dev/null | grep -v '2026-11-01' || true)"
[ -z "$leaked_tasks" ]; report $? "no source-repo task records were copied in"

# The plans index itself IS contract surface and must have been deployed.
[ -f "$TARGET/.agents/plans/llms.txt" ]; report $? ".agents/plans/llms.txt deployed (contract surface)"

exit "$fail"
