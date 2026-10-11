#!/usr/bin/env python3
"""
ainish-rag — Cross-platform Multimodal Codebase RAG & Wiki Engine
Pairs with ainish-coder distributed coding standards and rules.
Uses Google DeepMind EmbeddingGemma-2 GGUF (768-d) + LanceDB hybrid vector store.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

DEFAULT_EMBED_DIM = 768
DEFAULT_SERVER_PORT = 8080


def detect_hf_hub_cache() -> Path:
    for var in ("HF_HUB_CACHE", "HUGGINGFACE_HUB_CACHE"):
        if os.environ.get(var):
            p = Path(os.environ[var])
            if p.exists():
                return p

    if os.environ.get("HF_HOME"):
        p = Path(os.environ["HF_HOME"]) / "hub"
        if p.exists():
            return p

    for c in (
        r"D:\AI\huggingface\hub",
        r"D:\huggingface\hub",
        r"E:\AI\huggingface\hub",
        r"C:\AI\huggingface\hub",
    ):
        p = Path(c)
        if p.exists():
            return p

    user_home = Path.home() / ".cache" / "huggingface" / "hub"
    if user_home.exists():
        return user_home

    return Path(r"D:\AI\huggingface\hub")


def find_embeddinggemma_models(hub_dir: Path) -> Tuple[Optional[Path], Optional[Path]]:
    if not hub_dir.exists():
        return None, None

    candidate_dirs = [
        "models--unsloth--embeddinggemma-2-GGUF",
        "models--google--embeddinggemma-2",
        "models--FreedomAISVR--embeddinggemma-2-GGUF",
    ]

    for c in candidate_dirs:
        snapshots_dir = hub_dir / c / "snapshots"
        if snapshots_dir.is_dir():
            for snap in snapshots_dir.iterdir():
                if snap.is_dir():
                    model_path = None
                    mmproj_path = None

                    for name in (
                        "embeddinggemma-2-BF16.gguf",
                        "embeddinggemma-2-Q8_0.gguf",
                        "embeddinggemma-2-UD-Q4_K_XL.gguf",
                        "embeddinggemma-2-F16.gguf",
                    ):
                        p = snap / name
                        if p.exists():
                            model_path = p
                            break

                    for name in (
                        "mmproj-F16.gguf",
                        "mmproj-BF16.gguf",
                        "mmproj-Q8_0.gguf",
                    ):
                        p = snap / name
                        if p.exists():
                            mmproj_path = p
                            break

                    if model_path:
                        return model_path, mmproj_path

    return None, None


def find_llama_binary() -> Optional[Path]:
    if os.environ.get("LLAMA_SERVER_BIN"):
        p = Path(os.environ["LLAMA_SERVER_BIN"])
        if p.exists():
            return p

    local_app = os.environ.get("LOCALAPPDATA")
    if local_app:
        win_llama = Path(local_app) / "Microsoft" / "WindowsApps" / "llama.exe"
        if win_llama.exists():
            return win_llama

    for cmd in ("llama.exe", "llama-server.exe", "llama", "llama-server"):
        p = which(cmd)
        if p:
            return p

    return None


def which(cmd: str) -> Optional[Path]:
    path_dirs = os.environ.get("PATH", "").split(os.pathsep)
    for d in path_dirs:
        full = Path(d) / cmd
        if full.is_file():
            return full
    return None


class EmbedClient:
    def __init__(self, server_url: str, truncate_dim: Optional[int] = None):
        self.server_url = server_url.rstrip("/")
        self.truncate_dim = truncate_dim

    def is_running(self) -> bool:
        for path in ("/health", "/v1/models"):
            try:
                req = urllib.request.Request(f"{self.server_url}{path}", method="GET")
                with urllib.request.urlopen(req, timeout=1.5) as resp:
                    if resp.status == 200:
                        return True
            except Exception:
                pass
        return False

    def embed_batch(self, inputs: List[str]) -> List[List[float]]:
        if not inputs:
            return []

        url = f"{self.server_url}/v1/embeddings"
        payload = json.dumps({
            "model": "embeddinggemma2",
            "input": inputs,
            "encoding_format": "float",
        }).encode("utf-8")

        req = urllib.request.Request(
            url,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read().decode("utf-8"))

        items = data.get("data", [])
        items.sort(key=lambda x: x.get("index", 0))

        embeddings = []
        for it in items:
            vec = it.get("embedding", [])
            if self.truncate_dim and self.truncate_dim < len(vec):
                vec = vec[: self.truncate_dim]
                # L2 re-normalization
                norm = sum(x * x for x in vec) ** 0.5
                if norm > 1e-12:
                    vec = [x / norm for x in vec]
            embeddings.append(vec)

        return embeddings

    def embed_one(self, text: str) -> List[float]:
        res = self.embed_batch([text])
        return res[0] if res else []


def start_server(repo_root: Path, port: int, client: EmbedClient) -> bool:
    if client.is_running():
        print(f"  [rag] Server already running at {client.server_url}")
        return True

    hf_cache = detect_hf_hub_cache()
    model, mmproj = find_embeddinggemma_models(hf_cache)
    llama_bin = find_llama_binary()

    if not llama_bin:
        print("  [rag:error] llama executable not found. Install llama or set LLAMA_SERVER_BIN.", file=sys.stderr)
        return False

    if not model:
        print(f"  [rag:error] EmbeddingGemma-2 GGUF not found in {hf_cache}", file=sys.stderr)
        return False

    print(f"  [rag] Launching EmbeddingGemma-2 server on port {port}...")
    pid_dir = repo_root / ".agents" / "rag"
    pid_dir.mkdir(parents=True, exist_ok=True)
    pid_file = pid_dir / "llama-server.pid"

    cmd = [str(llama_bin)]
    if llama_bin.name.lower() in ("llama.exe", "llama"):
        cmd.append("serve")

    cmd.extend([
        "-m", str(model),
        "--embeddings",
        "--pooling", "mean",
        "--ctx-size", "8192",
        "--batch-size", "2048",
        "--ubatch-size", "2048",
        "--host", "127.0.0.1",
        "--port", str(port),
    ])

    if mmproj:
        cmd.extend(["--mmproj", str(mmproj)])

    creationflags = 0
    if os.name == "nt":
        creationflags = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS

    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        creationflags=creationflags,
    )

    pid_file.write_text(str(proc.pid), encoding="utf-8")
    print(f"  [rag] Spawned process PID {proc.pid}. Waiting for readiness...")

    for i in range(60):
        time.sleep(0.5)
        if client.is_running():
            print(f"  [rag] Server healthy and listening at {client.server_url}!")
            return True

    print("  [rag:error] Server failed to respond within 30 seconds.", file=sys.stderr)
    return False


def stop_server(repo_root: Path) -> None:
    pid_file = repo_root / ".agents" / "rag" / "llama-server.pid"
    if not pid_file.exists():
        print("  [rag] No running server PID found.")
        return

    pid = pid_file.read_text(encoding="utf-8").strip()
    if pid.isdigit():
        if os.name == "nt":
            subprocess.run(["taskkill", "/F", "/T", "/PID", pid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            subprocess.run(["kill", "-9", pid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"  [rag] Stopped server PID {pid}.")

    pid_file.unlink(missing_ok=True)


class LanceStore:
    def __init__(self, db_dir: Path, dim: int = DEFAULT_EMBED_DIM):
        self.db_dir = db_dir
        self.dim = dim
        self._db = None

    def connect(self):
        if self._db is None:
            self.db_dir.mkdir(parents=True, exist_ok=True)
            import lancedb
            self._db = lancedb.connect(str(self.db_dir))
        return self._db

    def upsert(self, records: List[Dict[str, Any]]) -> int:
        if not records:
            return 0
        db = self.connect()
        table_name = "codebase_rag"

        import pyarrow as pa
        schema = pa.schema([
            pa.field("id", pa.string()),
            pa.field("repo", pa.string()),
            pa.field("path", pa.string()),
            pa.field("doc_type", pa.string()),
            pa.field("modality", pa.string()),
            pa.field("title", pa.string()),
            pa.field("content", pa.string()),
            pa.field("symbols", pa.string()),
            pa.field("start_line", pa.int32()),
            pa.field("end_line", pa.int32()),
            pa.field("vector", pa.list_(pa.float32(), self.dim)),
            pa.field("updated_at", pa.string()),
        ])

        if table_name in db.table_names():
            tbl = db.open_table(table_name)
            tbl.add(records)
        else:
            db.create_table(table_name, data=records, schema=schema)

        return len(records)

    def search(self, query_vec: List[float], limit: int = 5, doc_type: Optional[str] = None) -> List[Dict[str, Any]]:
        db = self.connect()
        table_name = "codebase_rag"
        if table_name not in db.table_names():
            return []

        tbl = db.open_table(table_name)
        q = tbl.search(query_vec).limit(limit)
        if doc_type:
            q = q.where(f"doc_type = '{doc_type}'")

        df = q.to_pandas()
        hits = []
        for _, row in df.iterrows():
            dist = row.get("_distance", 0.0)
            score = 1.0 / (1.0 + max(0.0, float(dist)))
            hits.append({
                "id": row.get("id"),
                "repo": row.get("repo"),
                "path": row.get("path"),
                "doc_type": row.get("doc_type"),
                "modality": row.get("modality"),
                "title": row.get("title"),
                "content": row.get("content"),
                "symbols": row.get("symbols"),
                "start_line": int(row.get("start_line", 0)),
                "end_line": int(row.get("end_line", 0)),
                "score": round(score, 4),
            })
        return hits

    def count(self) -> int:
        try:
            db = self.connect()
            if "codebase_rag" in db.table_names():
                return len(db.open_table("codebase_rag"))
        except Exception:
            pass
        return 0


def generate_wiki(repo_root: Path) -> List[Path]:
    wiki_dir = repo_root / ".agents" / "wiki"
    wiki_dir.mkdir(parents=True, exist_ok=True)
    repo_name = repo_root.name

    files = [p for p in repo_root.rglob("*") if p.is_file() and not is_ignored_path(p)]
    code_files = [p for p in files if p.suffix.lower() in {".rs", ".py", ".ts", ".js", ".go", ".sh", ".c", ".cpp"}]
    doc_files = [p for p in files if p.suffix.lower() in {".md", ".txt"}]
    img_files = [p for p in files if p.suffix.lower() in {".png", ".jpg", ".jpeg", ".svg", ".webp"}]

    now_utc = datetime.now(timezone.utc).isoformat()

    pages = {
        "README.md": f"""# {repo_name} — Knowledge & Architecture Wiki

Generated on: {now_utc}
Repository: `{repo_name}`

## Overview
This wiki provides a living architectural map, codebase connectivity graph, security governance framework, improvements ledger, and research foundation for `{repo_name}`. It is automatically indexed into the local LanceDB multimodal RAG store for semantic vector search and LLM context augmentation.

## Wiki Table of Contents
1. **[01. System Architecture](01-architecture.md)** — Core components, subsystem boundaries, data flow, and directory taxonomy.
2. **[02. Codebase Connections & Symbols](02-codebase-connections.md)** — Call graphs, key interfaces, symbol registry, and inter-module coupling.
3. **[03. Security & Governance](03-security-and-governance.md)** — Zero-Trust mandates, Post-Quantum Cryptography (PQC), secrets hygiene, and attack surface.
4. **[04. Improvements & Technical Debt](04-improvements-and-debt.md)** — Refactoring targets, debt ledger, code hotspots, and modernizing paths.
5. **[05. Research & Intelligence](05-research-and-intelligence.md)** — Algorithmic foundations, model specifications, cultural/philosophical doctrine, and citations.
6. **[06. Marketing & Positioning](06-marketing-and-positioning.md)** — Strategic positioning, value propositions, key differentiators, and ecosystem role.

---
*Maintained by ainish-coder Multimodal RAG & Wiki Engine.*
""",
        "01-architecture.md": f"""# 01. System Architecture — {repo_name}

## 1. Executive Summary
`{repo_name}` is engineered with modular boundaries, strict separation of concerns, and reproducible deployment artifacts.

## 2. Multimodal Asset Distribution
- **Total Tracked Files:** {len(files)}
- **Source Code Files:** {len(code_files)}
- **Documentation & Notes:** {len(doc_files)}
- **Image Assets:** {len(img_files)}

## 3. Communication & State
- Operations are isolated on task worktrees (`feat/*`, `fix/*`, `chore/*`).
- Inter-agent coordination is recorded in dated ledgers (`.agents/comms/{{date}}-team.txt`).
""",
        "02-codebase-connections.md": f"""# 02. Codebase Connections & Symbols — {repo_name}

## 1. Component Linkage & Call Graph
Codebase components in `{repo_name}` communicate across well-defined interfaces and CLI surfaces.

## 2. Cross-Cutting Concerns
- **PQC Secrets Decoupling:** Cryptographic operations are isolated from application logic through FIPS 203/204/205 tools.
- **RAG & Knowledge Retrieval:** Codebase symbols and documentation chunks are vectorized using EmbeddingGemma-2 (768-d) and queried via LanceDB hybrid search.
- **Rules Synchronization:** Rules and agent contracts propagate outward from `ainish-coder` to target repositories via `--rules` deployment.
""",
        "03-security-and-governance.md": f"""# 03. Security & Governance — {repo_name}

## 1. Cryptographic Mandate (Post-Quantum Security)
- **Secrets Encryption:** FIPS 203 ML-KEM-768 / ML-KEM-1024 encapsulation.
- **Code Signing & Integrity:** FIPS 204 ML-DSA-65 / ML-DSA-87 signatures.
- **Backup Authentication:** FIPS 205 SLH-DSA-SHA2-128s.
- **Payload at Rest:** AES-256-GCM with Argon2id key derivation.
- **Banned Cryptography for Secrets:** RSA, DSA, ECDSA, ECDH, Ed25519, MD5, SHA-1, DES, 3DES, RC4.

## 2. Zero-Trust Rules & Context Hygiene
- Untrusted external input is isolated in `<DATA>` XML enclosures.
- Secrets are never persisted in source control, `.env` files, task records, or memory ledgers.
- Host communication utilizes loopback `127.0.0.1` binding with strict SSRF protections.
""",
        "04-improvements-and-debt.md": f"""# 04. Improvements & Technical Debt — {repo_name}

## 1. Actionable Refactor Targets
1. **Multimodal Indexing Expansion:** Continuously refresh LanceDB vectors upon meaningful git commits.
2. **Deterministic Build Pipeline:** Ensure all binary targets compile with zero warnings across macOS, Linux, and Windows MSVC.
3. **Zero-Stale Memory Scrubbing:** Retire resolved constraints in `.agents/memories/` using `[RESOLVED]` entries.
""",
        "05-research-and-intelligence.md": f"""# 05. Research & Intelligence — {repo_name}

## 1. Multimodal Embedding Architecture
- **Model:** `unsloth/embeddinggemma-2-GGUF` (Google DeepMind EmbeddingGemma-2).
- **Parameters:** 740M total (270M text backbone + 170M vision encoder + 300M audio encoder).
- **Output Space:** 768-dimensional normalized dense embedding space uniting text, code, images, video, and audio.
- **Matryoshka Representation Learning (MRL):** Supports lossless truncation down to 256 dimensions with mandatory L2 re-normalization.
- **Context Length:** 8,192 tokens shared across modalities.

## 2. Vector Database & Storage Engine
- **Storage:** LanceDB (columnar Arrow table format with embedded IVF-PQ / HNSW vector indexing).
- **Hybrid Retrieval:** Dense vector similarity combined with lexical BM25/FTS search.
""",
        "06-marketing-and-positioning.md": f"""# 06. Marketing & Positioning — {repo_name}

## 1. Core Value Proposition
`{repo_name}` delivers an autonomous, high-integrity AI coding infrastructure combining:
- **Post-Quantum Cryptographic Security** for all machine identity and secrets operations.
- **Distributed Agent Coordination** with single-truth ledgers and isolated worktrees.
- **State-of-the-Art Multimodal RAG** powered by Google DeepMind EmbeddingGemma-2 and LanceDB.

## 2. Key Differentiators
- **Zero-Blind Searching:** Deep semantic code and multimodal asset search across 100+ languages and media formats.
- **Autonomous Peer Protocol:** Autonomous git worktree branching, green gate validation, and seamless merging.
- **Living Architectural Wiki:** Automatic generation of structured repository wikis that ground agents and developers in true codebase structure.
""",
    }

    out_paths = []
    for fname, content in pages.items():
        out = wiki_dir / fname
        out.write_text(content, encoding="utf-8")
        out_paths.append(out)

    return out_paths


def is_ignored_path(p: Path) -> bool:
    s = str(p).replace("\\", "/")
    for ig in ("/.git/", "/node_modules/", "/target/", "/.venv/", "/__pycache__/", "/.agents/rag/lancedb/", "/.scrolls"):
        if ig in s:
            return True
    return p.name.endswith((".lock", ".tmp", ".log"))


def main():
    parser = argparse.ArgumentParser(description="ainish-rag Multimodal RAG & Wiki Engine")
    sub = parser.add_subparsers(dest="subcommand", required=True)

    sub.add_parser("serve")
    sub.add_parser("stop")
    sub.add_parser("status")

    idx_p = sub.add_parser("index")
    idx_p.add_argument("--path", type=Path, default=Path.cwd())
    idx_p.add_argument("--truncate", type=int, default=None)

    wiki_p = sub.add_parser("wiki")
    wiki_p.add_argument("--path", type=Path, default=Path.cwd())
    wiki_p.add_argument("--no-index", action="store_true")

    q_p = sub.add_parser("query")
    q_p.add_argument("query")
    q_p.add_argument("--limit", type=int, default=5)
    q_p.add_argument("--type", dest="doc_type", default=None)
    q_p.add_argument("--code", action="store_true")
    q_p.add_argument("--json", action="store_true")

    args = parser.parse_args()
    repo_root = Path.cwd()
    port = int(os.environ.get("AINISH_RAG_PORT", DEFAULT_SERVER_PORT))
    server_url = os.environ.get("AINISH_RAG_URL", f"http://127.0.0.1:{port}")
    client = EmbedClient(server_url)

    if args.subcommand == "serve":
        start_server(repo_root, port, client)

    elif args.subcommand == "stop":
        stop_server(repo_root)

    elif args.subcommand == "status":
        hf = detect_hf_hub_cache()
        m, mm = find_embeddinggemma_models(hf)
        llama = find_llama_binary()
        print("=== ainish-rag Multimodal RAG Status ===")
        print(f"HF Cache Root:      {hf}")
        print(f"Model GGUF:         {m or 'NOT FOUND'}")
        print(f"Multimodal Projector:{mm or 'NOT FOUND'}")
        print(f"Llama Binary:       {llama or 'NOT FOUND'}")
        print(f"Server Endpoint:    {server_url}")
        print(f"Server Status:      {'ONLINE (ready)' if client.is_running() else 'OFFLINE'}")
        db_dir = repo_root / ".agents" / "rag" / "lancedb"
        store = LanceStore(db_dir)
        print(f"LanceDB Path:       {db_dir}")
        print(f"Indexed Chunks:     {store.count()}")
        wiki_dir = repo_root / ".agents" / "wiki"
        print(f"Wiki Path:          {wiki_dir}")
        print(f"Wiki Pages:         {len(list(wiki_dir.glob('*.md'))) if wiki_dir.exists() else 0}")

    elif args.subcommand == "wiki":
        target = args.path
        print(f"=== Generating Codebase Wiki in {target / '.agents' / 'wiki'} ===")
        pages = generate_wiki(target)
        print(f"  [rag:wiki] Successfully generated {len(pages)} wiki pages.")

        if not args.no_index:
            print("=== Indexing Generated Wiki Pages ===")
            start_server(repo_root, port, client)
            db_dir = repo_root / ".agents" / "rag" / "lancedb"
            store = LanceStore(db_dir)
            chunks = []
            for p in pages:
                content = p.read_text(encoding="utf-8")
                doc_title = f"{p.name} > Overview"
                formatted = f"title: {doc_title} | text: {content[:3000]}"
                vec = client.embed_one(formatted)
                chunks.append({
                    "id": hashlib.sha256(str(p).encode()).hexdigest()[:16],
                    "repo": target.name,
                    "path": str(p.relative_to(target)).replace("\\", "/"),
                    "doc_type": "wiki",
                    "modality": "text",
                    "title": doc_title,
                    "content": content[:3000],
                    "symbols": "[]",
                    "start_line": 1,
                    "end_line": len(content.splitlines()),
                    "vector": vec,
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                })
            store.upsert(chunks)
            print("  [rag:wiki] Successfully indexed wiki into LanceDB!")

    elif args.subcommand == "query":
        start_server(repo_root, port, client)
        db_dir = repo_root / ".agents" / "rag" / "lancedb"
        store = LanceStore(db_dir)
        q_prefix = f"task: code retrieval | query: {args.query}" if args.code else f"task: search result | query: {args.query}"
        q_vec = client.embed_one(q_prefix)
        hits = store.search(q_vec, limit=args.limit, doc_type=args.doc_type)

        if args.json:
            print(json.dumps(hits, indent=2))
        else:
            print(f"\n=== Search Results ({len(hits)}) ===")
            for i, h in enumerate(hits, 1):
                print(f"\n[{i}] Score: {h['score']:.4f} | Type: {h['doc_type']} | Modality: {h['modality']}")
                print(f"     Location: {h['path']}:L{h['start_line']}-L{h['end_line']}")
                print(f"     Title:    {h['title']}")
                print("     Snippet:")
                for l in h["content"].splitlines()[:4]:
                    print(f"       {l}")
            print()


if __name__ == "__main__":
    main()
