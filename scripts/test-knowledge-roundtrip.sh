#!/usr/bin/env bash
# Proves the .agents/** knowledge corpus is both WRITTEN and READ by the prime.
#
# Three separate failures are possible here and each looks like "the agent just didn't know":
#   1. the table is never created (no driver, or index never run),
#   2. the table exists but the prime never queries it,
#   3. the prime queries it but the section is dropped by budget assembly.
# This exercises all three against a temporary repo with a stub embedder, so it needs no model and
# no network.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

# Resolve uv the way bin/ainish-rag does: PATH first, then known install locations. Git Bash on
# Windows does not inherit the Windows USER PATH, so `uv` on the PowerShell PATH is not "on PATH".
UV=""
if command -v uv >/dev/null 2>&1; then
    UV="uv"
else
    for candidate in \
        "${LOCALAPPDATA:-}/Microsoft/WinGet/Packages/astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe/uv.exe" \
        "${LOCALAPPDATA:-}/hermes/bin/uv.exe" \
        "${HOME}/.local/bin/uv" \
        "${HOME}/.cargo/bin/uv"
    do
        if [ -x "$candidate" ]; then UV="$candidate"; break; fi
    done
fi
if [ -z "$UV" ]; then
    echo "SKIP uv not found; cannot run the round-trip"
    exit 0
fi

exec "$UV" run --with lancedb --with pyarrow python - <<'PY'
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, "src/rag")
import rag

class StubClient:
    """Deterministic 768-d embedder: no model, no network. One-hot on the first letter so a query
    about a word that appears in a record lands near it."""
    truncate_dim = None
    dp_epsilon = None
    def recommended_batch_size(self):
        return 8
    def _vec(self, text):
        base = [0.0] * 768
        for i, ch in enumerate(text.lower()[:64]):
            base[(ord(ch) * 7 + i) % 768] += 1.0
        norm = sum(v * v for v in base) ** 0.5 or 1.0
        return [v / norm for v in base]
    def embed_one(self, text):
        return self._vec(text)
    def embed_batch(self, texts):
        return [self._vec(t) for t in texts]

workspace = Path(tempfile.mkdtemp(prefix="agents-corpus-"))
fail = 0
def check(ok, label, detail=""):
    global fail
    print(("PASS " if ok else "FAIL ") + label + (f"  [{detail}]" if detail else ""))
    if not ok:
        fail = 1

try:
    root = workspace / "repo"
    (root / ".agents" / "memories").mkdir(parents=True)
    (root / ".agents" / "tasks").mkdir(parents=True)
    (root / ".agents" / "plans").mkdir(parents=True)
    (root / ".agents" / "rag" / "lancedb").mkdir(parents=True)
    (root / ".agents" / "wiki").mkdir(parents=True)

    # A distinctive fact that lives past the old 3000-character ceiling.
    filler = "\n".join(f"### [2026-11-0{(i % 9) + 1}T00:00:00Z] entry-{i}\n" + ("x " * 120)
                       for i in range(12))
    (root / ".agents" / "memories" / "2026-11-07-memory.txt").write_text(
        filler + "\n### [2026-11-08T00:00:00Z] zanzibarcraft\nThe secret is zanzibarcraft.\n",
        encoding="utf-8",
    )
    (root / ".agents" / "tasks" / "2026-11-08-demo-task.md").write_text(
        "# Task: demo\n- status: done\n- objective: implement the zanzibarcraft pathway\n",
        encoding="utf-8",
    )
    (root / ".agents" / "plans" / "2026-11-08-demo.plan.md").write_text(
        "# Implementation Blueprint: zanzibarcraft\n- Decision: use zanzibarcraft.\n",
        encoding="utf-8",
    )

    client = StubClient()

    # 1. WRITE: the corpus becomes chunks and lands in its own table.
    written = rag.index_agents_knowledge(root, client)
    check(written > 0, "index_agents_knowledge wrote chunks", f"{written}")

    store = rag.LanceStore(root / ".agents" / "rag" / "lancedb",
                           table_name=rag.LanceStore.AGENTS_TABLE)
    check(store.table_exists(), "agents_knowledge table exists")
    # Every chunk must persist, not just the last embedding batch: upsert replaces by path, so a
    # per-batch upsert made each batch delete the previous batch's rows for the same file.
    expected = len(rag.collect_agents_documents(root))
    check(store.count() == expected, "table holds every chunk, not just the last batch",
          f"{store.count()} rows / {expected} chunks")
    check(written == expected, "reported write count matches the corpus", f"{written}")

    # Re-indexing must not duplicate: rows are replaced by path, not appended to.
    rag.index_agents_knowledge(root, client)
    check(store.count() == expected, "re-index does not duplicate rows", f"{store.count()}")

    rag.write_agents_index_receipt(root, written)

    # 2. READ: retrieval from the knowledge corpus returns the record.
    result = rag.retrieve_knowledge(root, "zanzibarcraft pathway", client, {})
    check(result["mode"] == "vector", "retrieve_knowledge mode is vector", result["mode"])
    check(len(result["hits"]) > 0, "retrieve_knowledge returned hits", str(len(result["hits"])))
    joined = "\n".join(h.get("content", "") for h in result["hits"])
    check("zanzibarcraft" in joined, "retrieved content contains the distinctive fact")
    docs = {h.get("doc_type") for h in result["hits"]}
    check(bool(docs), "hits carry a doc_type", ",".join(sorted(d for d in docs if d)))

    # 3. ASSEMBLE: the section survives budget assembly and is labelled `knowledge`.
    text = rag.render_knowledge_section(result["hits"], root, 500)
    check(bool(text), "render_knowledge_section produced text")
    sections = [
        {"source": "orientation", "text": "- branch: x", "reason": "t", "driver": None},
        {"source": "knowledge", "text": text, "reason": "t", "driver": None},
    ]
    inv = rag.assemble_injection("zanzibarcraft", sections, 4000, {}, False, [])
    kept = {s["source"] for s in inv["sections"]}
    check("knowledge" in kept, "assembled injection keeps the knowledge section", ",".join(sorted(kept)))
    rendered = rag.render_injection_text(inv)
    check("## knowledge" in rendered, "rendered envelope labels the section")
    check("zanzibarcraft" in rendered, "rendered envelope carries the fact")

    # 4. STALENESS: touching a knowledge file makes the receipt stale.
    check(not rag.agents_index_is_stale(root), "freshly written receipt is not stale")
    import time
    time.sleep(0.05)
    (root / ".agents" / "tasks" / "2026-11-09-newer-task.md").write_text("# newer\n", encoding="utf-8")
    check(rag.agents_index_is_stale(root), "a newer knowledge file makes the receipt stale")

    # 5. SCOPE: the index's own state is never indexed.
    check(rag.agents_doc_type(".agents/rag/lancedb/x.md") is None, "rag/ excluded from the corpus")
    check(rag.agents_doc_type(".agents/audit/r.sig") is None, "audit/ excluded from the corpus")
    check(rag.agents_doc_type(".agents/plans/p.plan.md") == "agents_plan", "plans/ typed as agents_plan")
finally:
    shutil.rmtree(workspace, ignore_errors=True)

print("\nRESULT:", "PASS" if fail == 0 else "FAIL")
sys.exit(fail)
PY
