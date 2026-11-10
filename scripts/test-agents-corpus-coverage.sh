#!/usr/bin/env bash
# Proves the .agents/** knowledge corpus indexes text the old `content[:3000]` truncation lost.
# Offline by construction: builds records directly from disk, no embedding call.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

# Resolve uv the way bin/ainish-rag does: PATH first, then the hermes install location.
UV=""
if command -v uv >/dev/null 2>&1; then
    UV="uv"
elif [ -x "${LOCALAPPDATA:-}/hermes/bin/uv.exe" ]; then
    UV="${LOCALAPPDATA}/hermes/bin/uv.exe"
elif [ -x "${HOME}/.local/bin/uv" ]; then
    UV="${HOME}/.local/bin/uv"
elif [ -x "${HOME}/.cargo/bin/uv" ]; then
    UV="${HOME}/.cargo/bin/uv"
else
    echo "SKIP uv not found; cannot run the chunker"
    exit 0
fi

"$UV" run python - "$@" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, "src/rag")
import rag

root = Path(".").resolve()
memory = root / ".agents" / "memories" / "2026-11-07-memory.txt"
if not memory.is_file():
    print("SKIP no daily memory file present")
    raise SystemExit(0)

raw = memory.read_text(encoding="utf-8", errors="replace")
old_cap = raw[:3000]
records = rag.chunk_agents_doc(memory, root)
if not records:
    print("FAIL chunker produced no records")
    raise SystemExit(1)

covered = sum(len(r["content"]) for r in records)

# A distinctive token that lives past the old ceiling must now be retrievable.
tail = raw[3000:]
markers = [w for w in tail.split() if len(w) >= 12][:20]
found = any(any(m in r["content"] for r in records) for m in markers)
missing_from_old = any(m not in old_cap for m in markers)

print(f"file chars           : {len(raw)}")
print(f"old ceiling kept     : {min(3000, len(raw))}")
print(f"chunks produced      : {len(records)}")
print(f"chars across chunks  : {covered}")
print(f"content past 3000    : {'present' if found else 'MISSING'}")
print(f"marker absent from old cap: {missing_from_old}")

ok = found and covered > len(old_cap) and missing_from_old
print("PASS" if ok else "FAIL")
raise SystemExit(0 if ok else 1)
PY
