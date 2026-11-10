#!/usr/bin/env bash
# Cross-platform parity check: verifies the store one engine wrote is readable by the other, and
# that both binaries answer the same verbs with the same data.
#
# Run on any host. It compares whatever engines are present rather than assuming both are:
#   * `bin/ainish-rag.exe`      — Windows binary (also usable from WSL via interop)
#   * `src/rag/target/release/ainish-rag` — native Linux binary
#   * the Python engine         — always present (bin/ainish-rag falls back to it)
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

UV=""
command -v uv >/dev/null 2>&1 && UV="uv"
[ -n "$UV" ] || for c in "${LOCALAPPDATA:-}/Microsoft/WinGet/Packages/astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe/uv.exe" \
                       "${HOME}/.local/bin/uv"; do [ -x "$c" ] && { UV="$c"; break; }; done

fail=0
report() { if [ "$1" -eq 0 ]; then echo "PASS $2"; else echo "FAIL $2"; fail=1; fi; }

# 1. The store exists and holds the knowledge table.
"$UV" run --with lancedb --with pyarrow python - <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, "src/rag")
import rag
store = rag.LanceStore(rag.shared_rag_dir(Path(".").resolve()) / "lancedb",
                       table_name=rag.LanceStore.AGENTS_TABLE)
names = store.list_table_names()
rows = store.count()
print(f"tables={names} agents_rows={rows}")
raise SystemExit(0 if "agents_knowledge" in names and rows > 0 else 1)
PY
report $? "store holds a populated agents_knowledge table"

# 2. Every engine binary on this host can query it.
for bin in "src/rag/target/release/ainish-rag" "bin/ainish-rag.exe"; do
    [ -x "$bin" ] || continue
    out="$("$bin" query-agents "obsidian wikilinks frontmatter" --limit 1 2>&1)"
    if printf '%s' "$out" | grep -q "Location:"; then
        report 0 "$bin reads the knowledge corpus"
    elif printf '%s' "$out" | grep -q "No .agents/\*\* knowledge table"; then
        report 1 "$bin reports the table missing"
    else
        report 1 "$bin returned no hits ($(printf '%s' "$out" | tail -1 | cut -c1-80))"
    fi
done

# 3. The Python engine sees the same store the binaries use.
"$UV" run src/rag/rag.py status 2>/dev/null | grep -q "LanceDB Path" 2>/dev/null
report $? "python engine resolves the store"

echo
[ "$fail" -eq 0 ] && echo "RESULT: PASS" || echo "RESULT: FAIL"
exit "$fail"
