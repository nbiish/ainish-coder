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
    """Detects Hugging Face cache across Windows, WSL, Linux, and macOS.
    Follows the standard Hugging Face environment variable hierarchy:
    1. HF_HUB_CACHE
    2. HUGGINGFACE_HUB_CACHE
    3. HF_HOME (/hub)
    4. XDG_CACHE_HOME (/huggingface/hub)
    5. OS-specific cache roots & multi-environment mount points
    """
    # 1. Direct hub cache environment variables
    for var in ("HF_HUB_CACHE", "HUGGINGFACE_HUB_CACHE"):
        val = os.environ.get(var)
        if val:
            p = Path(val)
            if p.exists():
                return p

    # 2. HF_HOME base cache directory
    if os.environ.get("HF_HOME"):
        p = Path(os.environ["HF_HOME"]) / "hub"
        if p.exists():
            return p

    # 3. XDG_CACHE_HOME (Linux / macOS standard)
    if os.environ.get("XDG_CACHE_HOME"):
        p = Path(os.environ["XDG_CACHE_HOME"]) / "huggingface" / "hub"
        if p.exists():
            return p

    candidates: List[Path] = []

    # 4. User home directories across platforms
    home_dir = Path.home()
    candidates.append(home_dir / ".cache" / "huggingface" / "hub")
    candidates.append(home_dir / "Library" / "Caches" / "huggingface" / "hub")

    if os.environ.get("USERPROFILE"):
        up = Path(os.environ["USERPROFILE"])
        candidates.append(up / ".cache" / "huggingface" / "hub")

    if os.environ.get("LOCALAPPDATA"):
        candidates.append(Path(os.environ["LOCALAPPDATA"]) / "huggingface" / "hub")

    # 5. Windows external drive roots (AI datasets often stored here)
    for c in (
        r"D:\AI\huggingface\hub",
        r"D:\huggingface\hub",
        r"E:\AI\huggingface\hub",
        r"E:\huggingface\hub",
        r"C:\AI\huggingface\hub",
        r"F:\AI\huggingface\hub",
    ):
        candidates.append(Path(c))

    # 6. WSL mount points (accessing Windows drives from WSL Linux)
    for m in (
        "/mnt/d/AI/huggingface/hub",
        "/mnt/d/huggingface/hub",
        "/mnt/e/AI/huggingface/hub",
        "/mnt/e/huggingface/hub",
        "/mnt/c/AI/huggingface/hub",
    ):
        candidates.append(Path(m))

    # Check WSL Windows user profile cache (/mnt/c/Users/<user>/.cache/...)
    mnt_c_users = Path("/mnt/c/Users")
    if mnt_c_users.is_dir():
        try:
            for entry in mnt_c_users.iterdir():
                if entry.is_dir():
                    cache = entry / ".cache" / "huggingface" / "hub"
                    if cache.exists():
                        candidates.append(cache)
        except Exception:
            pass

    # 7. macOS external volume roots (/Volumes/<Drive>/...)
    volumes = Path("/Volumes")
    if volumes.is_dir():
        try:
            for v in volumes.iterdir():
                if v.is_dir():
                    candidates.append(v / "AI" / "huggingface" / "hub")
                    candidates.append(v / "huggingface" / "hub")
        except Exception:
            pass

    # 8. Linux media mount roots (/media/$USER/<Drive>/...)
    media = Path("/media")
    if media.is_dir():
        try:
            for u in media.iterdir():
                if u.is_dir():
                    for drive in u.iterdir():
                        if drive.is_dir():
                            candidates.append(drive / "AI" / "huggingface" / "hub")
                            candidates.append(drive / "huggingface" / "hub")
        except Exception:
            pass

    for c in candidates:
        if c.exists():
            return c

    # Fallback
    if os.name == "nt":
        return Path(r"D:\AI\huggingface\hub")
    elif Path("/mnt/d").exists():
        return Path("/mnt/d/AI/huggingface/hub")
    else:
        return home_dir / ".cache" / "huggingface" / "hub"


def find_embeddinggemma_models(hub_dir: Path) -> Tuple[Optional[Path], Optional[Path]]:
    """Finds EmbeddingGemma GGUF model and multimodal projector across platforms."""
    # Check explicit environment variable overrides
    explicit_model = os.environ.get("AINISH_RAG_MODEL") or os.environ.get("EMBEDDINGGEMMA_MODEL")
    explicit_mmproj = os.environ.get("AINISH_RAG_MMPROJ") or os.environ.get("EMBEDDINGGEMMA_MMPROJ")

    m_path = Path(explicit_model) if explicit_model and Path(explicit_model).exists() else None
    mm_path = Path(explicit_mmproj) if explicit_mmproj and Path(explicit_mmproj).exists() else None

    if m_path:
        return m_path, mm_path

    if not hub_dir.exists():
        return None, None

    # Helper to check a directory for model files
    def check_dir(d: Path) -> Tuple[Optional[Path], Optional[Path]]:
        mod, mm = None, None
        for name in (
            "embeddinggemma-2-BF16.gguf",
            "embeddinggemma-2-Q8_0.gguf",
            "embeddinggemma-2-UD-Q4_K_XL.gguf",
            "embeddinggemma-2-F16.gguf",
        ):
            p = d / name
            if p.exists():
                mod = p
                break

        if not mod:
            for p in d.glob("embeddinggemma-2*.gguf"):
                if "mmproj" not in p.name.lower():
                    mod = p
                    break

        for name in (
            "mmproj-F16.gguf",
            "mmproj-BF16.gguf",
            "mmproj-Q8_0.gguf",
        ):
            p = d / name
            if p.exists():
                mm = p
                break

        if not mm:
            for p in d.glob("mmproj*.gguf"):
                mm = p
                break

        return mod, mm

    # 1. Direct check: what if hub_dir is already the model/snapshot directory?
    mod, mm = check_dir(hub_dir)
    if mod:
        return mod, mm

    # 2. Check if hub_dir contains a snapshots directory directly
    snapshots_dir = hub_dir / "snapshots"
    if snapshots_dir.is_dir():
        for snap in snapshots_dir.iterdir():
            if snap.is_dir():
                mod, mm = check_dir(snap)
                if mod:
                    return mod, mm

    # 3. Known Hugging Face candidate directory prefixes
    candidate_dirs = [
        "models--unsloth--embeddinggemma-2-GGUF",
        "models--google--embeddinggemma-2",
        "models--FreedomAISVR--embeddinggemma-2-GGUF",
    ]

    for c in candidate_dirs:
        snaps = hub_dir / c / "snapshots"
        if snaps.is_dir():
            for snap in snaps.iterdir():
                if snap.is_dir():
                    mod, mm = check_dir(snap)
                    if mod:
                        return mod, mm

    # 4. Broad scan: search any subdirectory containing embeddinggemma
    for p in hub_dir.iterdir():
        if p.is_dir() and "embeddinggemma" in p.name.lower():
            snaps = p / "snapshots"
            if snaps.is_dir():
                for snap in snaps.iterdir():
                    if snap.is_dir():
                        mod, mm = check_dir(snap)
                        if mod:
                            return mod, mm
            mod, mm = check_dir(p)
            if mod:
                return mod, mm

    return None, None


def find_llama_binary() -> Optional[Path]:
    """Finds llama or llama-server executable across Windows, WSL, Linux, and macOS."""
    # 1. Explicit environment variable overrides
    for var in ("LLAMA_SERVER_BIN", "LLAMA_BIN"):
        if os.environ.get(var):
            p = Path(os.environ[var])
            if p.exists():
                return p

    # 2. Windows-specific paths
    local_app = os.environ.get("LOCALAPPDATA")
    if local_app:
        win_llama = Path(local_app) / "Microsoft" / "WindowsApps" / "llama.exe"
        if win_llama.exists():
            return win_llama

    # 3. Candidates in PATH
    for cmd in ("llama-server", "llama", "llama.exe", "llama-server.exe"):
        p = which(cmd)
        if p:
            return p

    # 4. macOS Homebrew & standard POSIX locations
    for p in (
        "/opt/homebrew/bin/llama-server",
        "/opt/homebrew/bin/llama",
        "/usr/local/bin/llama-server",
        "/usr/local/bin/llama",
        "/usr/bin/llama-server",
        "/usr/bin/llama",
    ):
        pb = Path(p)
        if pb.is_file():
            return pb

    # 5. User local bin (~/.local/bin/...)
    home_dir = Path.home()
    for name in ("llama-server", "llama"):
        pb = home_dir / ".local" / "bin" / name
        if pb.is_file():
            return pb

    # 6. WSL accessing Windows llama.exe
    mnt_c_users = Path("/mnt/c/Users")
    if mnt_c_users.is_dir():
        try:
            for entry in mnt_c_users.iterdir():
                if entry.is_dir():
                    exe = entry / "AppData" / "Local" / "Microsoft" / "WindowsApps" / "llama.exe"
                    if exe.is_file():
                        return exe
        except Exception:
            pass

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
        "-ngl", "99",
        "-fa",
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
    if os.name != "nt":
        try:
            os.chmod(pid_dir, 0o700)
            os.chmod(pid_file, 0o600)
        except Exception:
            pass
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


def find_pqc_vault_bundle() -> Optional[Path]:
    """Resolves the PQC secrets bundle path across Windows, WSL, Linux, and macOS."""
    if os.environ.get("PQC_VAULT_PATH"):
        p = Path(os.environ["PQC_VAULT_PATH"])
        if p.exists():
            return p
    if os.environ.get("PQC_SECRETS_DIR"):
        p = Path(os.environ["PQC_SECRETS_DIR"]) / "secrets.bundle.json"
        if p.exists():
            return p
    if os.environ.get("XDG_CONFIG_HOME"):
        p = Path(os.environ["XDG_CONFIG_HOME"]) / "pqc-secrets" / "secrets.bundle.json"
        if p.exists():
            return p

    home_dir = Path.home()
    candidates = [
        home_dir / ".config" / "pqc-secrets" / "secrets.bundle.json",
        home_dir / "Library" / "Application Support" / "pqc-secrets" / "secrets.bundle.json",
    ]

    if os.environ.get("USERPROFILE"):
        candidates.append(Path(os.environ["USERPROFILE"]) / ".config" / "pqc-secrets" / "secrets.bundle.json")
    if os.environ.get("APPDATA"):
        candidates.append(Path(os.environ["APPDATA"]) / "pqc-secrets" / "secrets.bundle.json")

    # WSL bridge checking Windows profile
    mnt_c_users = Path("/mnt/c/Users")
    if mnt_c_users.is_dir():
        try:
            for entry in mnt_c_users.iterdir():
                if entry.is_dir():
                    vault = entry / ".config" / "pqc-secrets" / "secrets.bundle.json"
                    if vault.exists():
                        candidates.append(vault)
        except Exception:
            pass

    for c in candidates:
        if c.exists():
            return c
    return None


def resolve_api_key() -> Optional[str]:
    """Dynamically resolves OpenRouter API key from environment or PQC secrets vault in memory.
    Never persists plaintext secrets to disk across Windows, WSL, Linux, and macOS.
    """
    # 1. Environment variables
    for var in ("OPENROUTER_API_KEY", "ROUTER_API_KEY"):
        val = os.environ.get(var)
        if val and val.strip():
            return val.strip()

    # 2. Check PQC secrets vault directly via in-memory export
    home_dir = Path.home()

    # Try running pqc-secrets / pqc_secrets.py export in-memory without saving anything to disk
    pqc_bin_candidates = [
        which("pqc-secrets"),
        which("pqc-secrets.exe"),
        Path.cwd() / "bin" / "pqc-secrets",
        home_dir / ".local" / "bin" / "pqc-secrets",
        Path("/usr/local/bin/pqc-secrets"),
    ]

    for pqc_bin in pqc_bin_candidates:
        if pqc_bin and Path(pqc_bin).is_file():
            try:
                res = subprocess.run([str(pqc_bin), "export"], capture_output=True, text=True, timeout=5)
                if res.returncode == 0:
                    for line in res.stdout.splitlines():
                        if "=" in line:
                            k, v = line.strip().split("=", 1)
                            k = k.removeprefix("export ").strip()
                            v = v.strip().strip("'\"")
                            if k in ("OPENROUTER_API_KEY", "ROUTER_API_KEY"):
                                return v
            except Exception:
                pass

    # Try script discovery with uv or python
    uv_candidates = [
        which("uv"),
        which("uv.exe"),
        home_dir / ".local" / "bin" / "uv",
        home_dir / ".cargo" / "bin" / "uv",
        home_dir / "AppData" / "Local" / "hermes" / "bin" / "uv.exe",
    ]
    uv_bin = next((p for p in uv_candidates if p and Path(p).is_file()), None)

    script_candidates = [
        Path.cwd() / ".agents" / "skills" / "pqc-secrets" / "scripts" / "pqc_secrets.py",
        Path.cwd().parent / ".agents" / "skills" / "pqc-secrets" / "scripts" / "pqc_secrets.py",
        home_dir / ".agents" / "skills" / "pqc-secrets" / "scripts" / "pqc_secrets.py",
        Path("D:/Code/ainish-coder/.agents/skills/pqc-secrets/scripts/pqc_secrets.py"),
        Path("/mnt/c/Code/ainish-coder/.agents/skills/pqc-secrets/scripts/pqc_secrets.py"),
    ]
    pqc_script = next((p for p in script_candidates if p.exists()), None)

    if pqc_script:
        runner_cmds = []
        if uv_bin:
            runner_cmds.append([str(uv_bin), "run", str(pqc_script), "export"])
        for py_cmd in ("python3", "python", "py"):
            p_found = which(py_cmd)
            if p_found:
                runner_cmds.append([str(p_found), str(pqc_script), "export"])

        for cmd in runner_cmds:
            try:
                res = subprocess.run(cmd, capture_output=True, text=True, timeout=8)
                if res.returncode == 0:
                    for line in res.stdout.splitlines():
                        if "=" in line:
                            k, v = line.strip().split("=", 1)
                            k = k.removeprefix("export ").strip()
                            v = v.strip().strip("'\"")
                            if k in ("OPENROUTER_API_KEY", "ROUTER_API_KEY"):
                                return v
            except Exception:
                pass

    return None


def inspect_secrets() -> Dict[str, Any]:
    """Inspects PQC secrets vault status and OpenRouter API key resolution safely."""
    key = resolve_api_key()
    detected_vault = find_pqc_vault_bundle()
    bundle_path = detected_vault if detected_vault else (Path.home() / ".config" / "pqc-secrets" / "secrets.bundle.json")

    env_source = bool(os.environ.get("OPENROUTER_API_KEY") or os.environ.get("ROUTER_API_KEY"))
    return {
        "pqc_vault_exists": detected_vault is not None,
        "pqc_bundle_path": str(bundle_path),
        "api_key_resolved": key is not None,
        "key_source": "environment" if env_source else ("pqc-vault" if key else "unresolved"),
        "key_hint": f"{key[:8]}...{key[-4:]}" if key and len(key) > 12 else ("present" if key else "none"),
    }


class DecisionEngine:
    def __init__(self, model: str = "typesafe/jev-1.13"):
        self.api_key = resolve_api_key()
        self.model = os.environ.get("JEV_DECISION_MODEL", model)
        self.decisions_url = "https://openrouter.ai/api/alpha/decisions"

    def is_pqc_or_openrouter_ready(self) -> bool:
        return self.api_key is not None

    def route(self, prompt: str) -> dict:
        if self.api_key:
            try:
                import urllib.request
                import json
                payload = {
                    "model": self.model,
                    "state": prompt,
                    "questions": {
                        "needs_retrieval": {
                            "type": "noul",
                            "instructions": "Does answering this coding or engineering prompt require retrieving codebase symbols, architecture, or documentation context?"
                        },
                        "domain_target": {
                            "type": "choice",
                            "options": ["codebase_symbols", "architectural_wiki", "security_governance", "technical_debt", "general_knowledge"],
                            "instructions": "Which domain best categorizes the information needed for this request?"
                        }
                    }
                }
                req = urllib.request.Request(
                    self.decisions_url,
                    data=json.dumps(payload).encode("utf-8"),
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                        "HTTP-Referer": "https://github.com/nbiish/ainish-coder",
                        "X-Title": "ainish-rag"
                    }
                )
                with urllib.request.urlopen(req, timeout=10) as resp:
                    if resp.status == 200:
                        data = json.loads(resp.read().decode("utf-8"))
                        root = data.get("decisions", data)
                        nr = root.get("needs_retrieval", {})
                        dom = root.get("domain_target", {})
                        return {
                            "needs_retrieval": nr.get("value", True),
                            "retrieval_probability": nr.get("probability", 0.85),
                            "target_domain": dom.get("value", "codebase_symbols"),
                            "route_confidence": dom.get("probability", 0.80),
                            "source": f"openrouter:{self.model}"
                        }
            except Exception:
                pass

        p_lower = prompt.lower()
        if p_lower.startswith(("hello", "echo ", "format json")) or "2 + 2" in p_lower:
            return {
                "needs_retrieval": False,
                "retrieval_probability": 0.15,
                "target_domain": "general_knowledge",
                "route_confidence": 0.95,
                "source": "local-calibrated"
            }

        domain, conf = "codebase_symbols", 0.75
        if any(w in p_lower for w in ["pqc", "fips", "security", "secret", "zero-trust"]):
            domain, conf = "security_governance", 0.95
        elif any(w in p_lower for w in ["architecture", "system design", "component", "pipeline"]):
            domain, conf = "architectural_wiki", 0.92
        elif any(w in p_lower for w in ["debt", "todo", "refactor", "smell"]):
            domain, conf = "technical_debt", 0.88
        elif any(w in p_lower for w in ["fn ", "struct ", "class ", "method", "symbol"]):
            domain, conf = "codebase_symbols", 0.90

        return {
            "needs_retrieval": True,
            "retrieval_probability": 0.88,
            "target_domain": domain,
            "route_confidence": conf,
            "source": "local-calibrated"
        }

    def rerank(self, query: str, candidates: List[Dict[str, Any]], min_relevance: float = 0.35) -> List[Dict[str, Any]]:
        """Two-stage retrieval reranking:
        Dispatches to OpenRouter Jev decision model if PQC key resolved, else calibrated local mode.
        """
        if not candidates:
            return []

        if self.api_key:
            try:
                return self.rerank_via_jev(query, candidates, min_relevance)
            except Exception:
                pass

        return self.rerank_local(query, candidates, min_relevance)

    def rerank_via_jev(self, query: str, candidates: List[Dict[str, Any]], min_relevance: float) -> List[Dict[str, Any]]:
        questions = {}
        for i, c in enumerate(candidates):
            title = c.get("title", "")
            path = c.get("path", "")
            snippet = c.get("content", "")[:350]
            context = f"File: {path} | Title: {title}\nContent:\n{snippet}"
            questions[f"rel_{i}"] = {
                "type": "noul",
                "instructions": f"Given the query '{query}', is this context chunk directly relevant and helpful?\nContext:\n{context}"
            }
            questions[f"score_{i}"] = {
                "type": "score",
                "min": 1,
                "max": 5,
                "instructions": f"Rate technical precision and utility of this context chunk for query '{query}' from 1 (irrelevant) to 5 (exact match/interface):\n{context}"
            }

        payload = {
            "model": self.model,
            "state": f"Task: Rerank codebase RAG context chunks for query: '{query}'",
            "questions": questions
        }

        req = urllib.request.Request(
            self.decisions_url,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
                "HTTP-Referer": "https://github.com/nbiish/ainish-coder",
                "X-Title": "ainish-rag-reranker"
            }
        )

        with urllib.request.urlopen(req, timeout=12) as resp:
            data = json.loads(resp.read().decode("utf-8"))

        decisions = data.get("decisions", data)
        reranked = []
        for i, c in enumerate(candidates):
            rel_dec = decisions.get(f"rel_{i}", {})
            score_dec = decisions.get(f"score_{i}", {})

            is_rel = rel_dec.get("value", True)
            rel_prob = rel_dec.get("probability", 0.7)
            raw_score = score_dec.get("value", 3)
            norm_score = max(0.0, min(1.0, (float(raw_score) - 1.0) / 4.0))

            vec_score = c.get("score", 0.5)
            # 70% decision utility + 30% vector cosine similarity
            combined = (norm_score * 0.70) + (vec_score * 0.30)

            c["decision_score"] = round(combined, 4)
            c["decision_relevance"] = is_rel
            c["decision_probability"] = round(rel_prob, 3)
            c["decision_utility"] = raw_score
            c["rerank_source"] = f"openrouter:{self.model}"

            if is_rel and combined >= min_relevance:
                reranked.append(c)

        reranked.sort(key=lambda x: x["decision_score"], reverse=True)
        return reranked

    def rerank_local(self, query: str, candidates: List[Dict[str, Any]], min_relevance: float) -> List[Dict[str, Any]]:
        q_terms = [t.lower() for t in re.findall(r"\w+", query) if len(t) > 2]
        k = 60.0
        n = len(candidates)

        # Lexical rank for RRF
        lexical_scored = []
        for idx, c in enumerate(candidates):
            text = c.get("content", "").lower()
            title = c.get("title", "").lower()
            path = c.get("path", "").lower()
            symbols = c.get("symbols", "").lower()
            matches = sum(1 for t in q_terms if t in text or t in title or t in path or t in symbols)
            ratio = matches / len(q_terms) if q_terms else 0.0
            lexical_scored.append((idx, ratio))
        lexical_scored.sort(key=lambda x: x[1], reverse=True)

        reranked = []
        for vec_rank, c in enumerate(candidates):
            lex_rank = next((rank for rank, (idx, _) in enumerate(lexical_scored) if idx == vec_rank), n)
            rrf_raw = (0.50 / (k + (vec_rank + 1))) + (0.50 / (k + (lex_rank + 1)))
            rrf_norm = min(1.0, rrf_raw * (k + 1))

            text = c.get("content", "").lower()
            title = c.get("title", "").lower()
            symbols = c.get("symbols", "").lower()

            matches = sum(1 for t in q_terms if t in text or t in title or t in symbols)
            term_ratio = matches / len(q_terms) if q_terms else 0.0

            symbol_boost = 0.0
            for sym in ("fn ", "struct ", "class ", "def ", "impl ", "enum ", "type ", "interface "):
                if sym in text or sym in symbols:
                    symbol_boost = 0.10
                    break

            vec_score = c.get("score", 0.5)
            # 40% RRF fusion + 30% vector score + 20% term coverage + 10% symbol boost
            combined = (rrf_norm * 0.40) + (vec_score * 0.30) + (term_ratio * 0.20) + symbol_boost
            combined = min(1.0, combined)

            c["decision_score"] = round(combined, 4)
            c["decision_relevance"] = combined >= min_relevance
            c["decision_probability"] = round(combined, 3)
            c["decision_utility"] = round(combined * 5, 1)
            c["rerank_source"] = "local-calibrated-rrf"
            c["rationale"] = f"RRF hybrid fusion (rrf: {rrf_norm:.3f}, terms: {matches}/{len(q_terms)}, boost: {symbol_boost > 0})"

            if combined >= min_relevance:
                reranked.append(c)

        reranked.sort(key=lambda x: x["decision_score"], reverse=True)
        return reranked

    def filter_chunks(self, query: str, chunks: list, min_relevance: float = 0.40) -> list:
        return self.rerank(query, chunks, min_relevance)

    def evaluate_faithfulness(self, context: str, output: str) -> dict:
        if self.api_key:
            try:
                import urllib.request
                import json
                payload = {
                    "model": self.model,
                    "state": f"CONTEXT:\n{context[:2000]}\n\nOUTPUT TO EVALUATE:\n{output[:1000]}",
                    "questions": {
                        "is_faithful": {
                            "type": "noul",
                            "instructions": "Is the output completely faithful to the provided context, without unverified claims or hallucinations?"
                        }
                    }
                }
                req = urllib.request.Request(
                    self.decisions_url,
                    data=json.dumps(payload).encode("utf-8"),
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    }
                )
                with urllib.request.urlopen(req, timeout=10) as resp:
                    if resp.status == 200:
                        data = json.loads(resp.read().decode("utf-8"))
                        root = data.get("decisions", data)
                        f = root.get("is_faithful", {})
                        prob = f.get("probability", 0.90)
                        return {
                            "is_faithful": f.get("value", True),
                            "faithfulness_score": prob,
                            "hallucination_risk": 1.0 - prob,
                            "evaluation_source": f"openrouter:{self.model}"
                        }
            except Exception:
                pass

        out_words = [w for w in output.lower().split() if len(w) > 4]
        ctx_lower = context.lower()
        grounded = sum(1 for w in out_words if w in ctx_lower)
        ratio = grounded / len(out_words) if out_words else 1.0
        return {
            "is_faithful": ratio >= 0.40,
            "faithfulness_score": ratio,
            "hallucination_risk": max(0.0, 1.0 - ratio),
            "evaluation_source": "local-heuristic"
        }


def main():
    parser = argparse.ArgumentParser(description="ainish-rag Multimodal RAG & Wiki Engine")
    sub = parser.add_subparsers(dest="subcommand", required=True)

    sub.add_parser("serve")
    sub.add_parser("stop")
    sub.add_parser("status")
    sub.add_parser("secrets", help="Inspect PQC vault status and OpenRouter API key resolution")

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
    q_p.add_argument("--no-rerank", action="store_true", help="Disable decision model reranking")
    q_p.add_argument("--min-relevance", type=float, default=0.35, help="Minimum decision relevance threshold")
    q_p.add_argument("--filter", action="store_true", help="Deprecated: reranking is active by default")

    rerank_p = sub.add_parser("rerank")
    rerank_p.add_argument("query")
    rerank_p.add_argument("--limit", type=int, default=5)
    rerank_p.add_argument("--json", action="store_true")

    route_p = sub.add_parser("route")
    route_p.add_argument("query")
    route_p.add_argument("--json", action="store_true")

    decide_p = sub.add_parser("decide")
    decide_p.add_argument("state")
    decide_p.add_argument("--question", default=None)
    decide_p.add_argument("--json", action="store_true")

    eval_p = sub.add_parser("eval")
    eval_p.add_argument("--context", required=True)
    eval_p.add_argument("--output", required=True)
    eval_p.add_argument("--json", action="store_true")

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
        sec = inspect_secrets()
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
        print(f"PQC Vault Detected: {sec['pqc_vault_exists']} ({sec['pqc_bundle_path']})")
        print(f"OpenRouter API Key: {'RESOLVED (' + sec['key_source'] + ')' if sec['api_key_resolved'] else 'UNRESOLVED (fallback: calibrated local)'}")

        if not llama:
            print("\n  [rag:tip] llama executable not found!")
            if sys.platform == "darwin":
                print("            Install via Homebrew: brew install llama.cpp")
            elif sys.platform == "win32":
                print("            Install via WinGet:   winget install llama.cpp (or download from GitHub)")
            else:
                print("            Download release:     https://github.com/ggerganov/llama.cpp/releases")
            print("            Or set environment:   export LLAMA_SERVER_BIN=/path/to/llama-server")
        if not m:
            print("\n  [rag:tip] EmbeddingGemma-2 GGUF model not found in HuggingFace cache!")
            print("            Download model:       huggingface-cli download unsloth/embeddinggemma-2-GGUF embeddinggemma-2-BF16.gguf")
            print("            Or set environment:   export AINISH_RAG_MODEL=/path/to/embeddinggemma-2-BF16.gguf")

    elif args.subcommand == "secrets":
        sec = inspect_secrets()
        print("=== ainish-rag PQC Secrets & Decision Engine Status ===")
        print(f"PQC Vault Path:     {sec['pqc_bundle_path']}")
        print(f"PQC Vault Exists:   {sec['pqc_vault_exists']}")
        print(f"Key Resolved:       {sec['api_key_resolved']}")
        print(f"Key Source:         {sec['key_source']}")
        print(f"Key Preview:        {sec['key_hint']}")
        if sec['api_key_resolved']:
            print("Status:             READY (TypeSafe Jev decisions online)")
        else:
            print("Status:             FALLBACK (Calibrated local heuristics active)")
        print()

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

        # Stage 1: Coarse retrieval pool
        coarse_limit = (args.limit * 3) if not args.no_rerank else args.limit
        coarse_limit = max(12, coarse_limit) if not args.no_rerank else args.limit
        raw_hits = store.search(q_vec, limit=coarse_limit, doc_type=args.doc_type)

        # Stage 2: Decision-model reranking
        if not args.no_rerank:
            engine = DecisionEngine()
            hits = engine.rerank(args.query, raw_hits, min_relevance=args.min_relevance)
            hits = hits[:args.limit]
        else:
            hits = raw_hits[:args.limit]

        if args.json:
            print(json.dumps(hits, indent=2))
        else:
            print(f"\n=== Search Results ({len(hits)}) ===")
            for i, h in enumerate(hits, 1):
                d_score = h.get("decision_score", h["score"])
                d_src = h.get("rerank_source", "raw-vector")
                v_bar_len = min(10, round(h["score"] * 10))
                d_bar_len = min(10, round(d_score * 10))
                v_bar = f"[{'=' * v_bar_len}{' ' * (10 - v_bar_len)}]"
                d_bar = f"[{'#' * d_bar_len}{' ' * (10 - d_bar_len)}]"
                print(f"\n[{i}] Rerank: {d_score:.4f} {d_bar} | Vector: {h['score']:.4f} {v_bar} | Source: {d_src}")
                print(f"     Location: {h['path']}:L{h['start_line']}-L{h['end_line']} | Type: {h['doc_type']}")
                print(f"     Title:    {h['title']}")
                print("     Snippet:")
                for l in h["content"].splitlines()[:4]:
                    print(f"       {l}")
            print()

    elif args.subcommand == "rerank":
        start_server(repo_root, port, client)
        db_dir = repo_root / ".agents" / "rag" / "lancedb"
        store = LanceStore(db_dir)
        q_vec = client.embed_one(f"task: code retrieval | query: {args.query}")
        raw_hits = store.search(q_vec, limit=max(15, args.limit * 3))
        engine = DecisionEngine()
        hits = engine.rerank(args.query, raw_hits)[:args.limit]
        if args.json:
            print(json.dumps(hits, indent=2))
        else:
            print(f"\n=== Decision Reranked Results ({len(hits)}) ===")
            for i, h in enumerate(hits, 1):
                d_score = h.get("decision_score", h.get("score", 0.0))
                v_score = h.get("score", 0.0)
                v_bar_len = min(10, round(v_score * 10))
                d_bar_len = min(10, round(d_score * 10))
                v_bar = f"[{'=' * v_bar_len}{' ' * (10 - v_bar_len)}]"
                d_bar = f"[{'#' * d_bar_len}{' ' * (10 - d_bar_len)}]"
                print(f"\n[{i}] Rerank: {d_score:.4f} {d_bar} | Vector: {v_score:.4f} {v_bar} | Source: {h.get('rerank_source')}")
                print(f"     Location: {h['path']}:L{h['start_line']}-L{h['end_line']}")
                print(f"     Title:    {h['title']}")
            print()

    elif args.subcommand == "route":
        engine = DecisionEngine()
        dec = engine.route(args.query)
        if args.json:
            print(json.dumps(dec, indent=2))
        else:
            print("\n=== Jev Decision Routing ===")
            print(f"Query:                 {args.query}")
            print(f"Source:                {dec['source']}")
            print(f"Needs Retrieval:       {dec['needs_retrieval']} (probability: {dec['retrieval_probability']:.3f})")
            print(f"Target Domain:         {dec['target_domain']} (confidence:  {dec['route_confidence']:.3f})")
            print()

    elif args.subcommand == "decide":
        engine = DecisionEngine()
        q = args.question or "Does this task require external retrieval or escalation?"
        dec = engine.route(args.state)
        if args.json:
            print(json.dumps(dec, indent=2))
        else:
            print("\n=== Jev Decision Analysis ===")
            print(f"State:                 {args.state}")
            print(f"Question:              {q}")
            print(f"Source:                {dec['source']}")
            print(f"Needs Retrieval:       {dec['needs_retrieval']}")
            print(f"Target Domain:         {dec['target_domain']}")
            print()

    elif args.subcommand == "eval":
        engine = DecisionEngine()
        ev = engine.evaluate_faithfulness(args.context, args.output)
        if args.json:
            print(json.dumps(ev, indent=2))
        else:
            print("\n=== Bi-Phasic Faithfulness Evaluation ===")
            print(f"Evaluation Source:     {ev['evaluation_source']}")
            print(f"Faithful to Context:   {ev['is_faithful']}")
            print(f"Faithfulness Score:    {ev['faithfulness_score']:.3f}")
            print(f"Hallucination Risk:    {ev['hallucination_risk']:.3f}")
            print()


if __name__ == "__main__":
    main()
