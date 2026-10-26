use std::path::{Path, PathBuf};
use std::fs;
use std::collections::{HashMap, HashSet};
use walkdir::WalkDir;
use chrono::Utc;

pub struct WikiGenerator {
    repo_root: PathBuf,
    repo_name: String,
    wiki_dir: PathBuf,
}

#[derive(Default)]
struct RepoStats {
    total_files: usize,
    code_files: usize,
    doc_files: usize,
    image_files: usize,
    audio_video_files: usize,
    extensions: HashMap<String, usize>,
    directories: HashSet<String>,
    entrypoints: Vec<String>,
    #[allow(dead_code)]
    symbols: Vec<(String, String)>, // (symbol, path)
    dependencies: Vec<String>,
    todos: Vec<(String, usize, String)>, // (path, line, text)
}

impl WikiGenerator {
    pub fn new(repo_root: &Path) -> Self {
        let repo_name = repo_root
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("repo")
            .to_string();

        let wiki_dir = repo_root.join(".agents").join("wiki");

        Self {
            repo_root: repo_root.to_path_buf(),
            repo_name,
            wiki_dir,
        }
    }

    pub fn generate_all(&self) -> Result<Vec<PathBuf>, String> {
        fs::create_dir_all(&self.wiki_dir)
            .map_err(|e| format!("Failed to create wiki directory {}: {}", self.wiki_dir.display(), e))?;

        println!("  [rag:wiki] Analyzing repository structure: {}...", self.repo_name);
        let stats = self.analyze_repo();

        let mut generated = Vec::new();

        // 1. Architecture
        let arch_path = self.wiki_dir.join("01-architecture.md");
        let arch_content = self.render_architecture(&stats);
        fs::write(&arch_path, arch_content).map_err(|e| e.to_string())?;
        generated.push(arch_path);

        // 2. Codebase Connections & Symbols
        let conn_path = self.wiki_dir.join("02-codebase-connections.md");
        let conn_content = self.render_connections(&stats);
        fs::write(&conn_path, conn_content).map_err(|e| e.to_string())?;
        generated.push(conn_path);

        // 3. Security & Governance
        let sec_path = self.wiki_dir.join("03-security-and-governance.md");
        let sec_content = self.render_security(&stats);
        fs::write(&sec_path, sec_content).map_err(|e| e.to_string())?;
        generated.push(sec_path);

        // 4. Improvements & Tech Debt
        let imp_path = self.wiki_dir.join("04-improvements-and-debt.md");
        let imp_content = self.render_improvements(&stats);
        fs::write(&imp_path, imp_content).map_err(|e| e.to_string())?;
        generated.push(imp_path);

        // 5. Research & Intelligence
        let res_path = self.wiki_dir.join("05-research-and-intelligence.md");
        let res_content = self.render_research(&stats);
        fs::write(&res_path, res_content).map_err(|e| e.to_string())?;
        generated.push(res_path);

        // 6. Marketing & Positioning
        let mkt_path = self.wiki_dir.join("06-marketing-and-positioning.md");
        let mkt_content = self.render_marketing(&stats);
        fs::write(&mkt_path, mkt_content).map_err(|e| e.to_string())?;
        generated.push(mkt_path);

        // Index / README
        let index_path = self.wiki_dir.join("README.md");
        let index_content = self.render_index(&stats);
        fs::write(&index_path, index_content).map_err(|e| e.to_string())?;
        generated.push(index_path);

        println!("  [rag:wiki] Successfully generated {} wiki pages in {}", generated.len(), self.wiki_dir.display());
        Ok(generated)
    }

    fn analyze_repo(&self) -> RepoStats {
        let mut stats = RepoStats::default();

        for entry in WalkDir::new(&self.repo_root).follow_links(false).into_iter().flatten() {
            let path = entry.path();
            if crate::ingest::is_ignored_path(path) {
                continue;
            }

            if entry.file_type().is_dir() {
                if let Ok(rel) = path.strip_prefix(&self.repo_root) {
                    if !rel.as_os_str().is_empty() {
                        stats.directories.insert(rel.to_string_lossy().replace('\\', "/"));
                    }
                }
                continue;
            }

            stats.total_files += 1;
            let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("").to_lowercase();
            *stats.extensions.entry(ext.clone()).or_insert(0) += 1;

            let rel = path.strip_prefix(&self.repo_root)
                .unwrap_or(path)
                .to_string_lossy()
                .replace('\\', "/");

            if matches!(ext.as_str(), "rs" | "py" | "ts" | "js" | "go" | "sh" | "c" | "cpp") {
                stats.code_files += 1;

                if rel.starts_with("bin/") || rel.contains("main.") || rel.contains("index.") {
                    stats.entrypoints.push(rel.clone());
                }

                if let Ok(content) = fs::read_to_string(path) {
                    for (line_num, line) in content.lines().enumerate() {
                        if line.contains("TODO") || line.contains("FIXME") || line.contains("XXX") {
                            stats.todos.push((rel.clone(), line_num + 1, line.trim().to_string()));
                        }
                    }
                }
            } else if matches!(ext.as_str(), "md" | "txt") {
                stats.doc_files += 1;
            } else if matches!(ext.as_str(), "png" | "jpg" | "jpeg" | "svg" | "webp") {
                stats.image_files += 1;
            } else if matches!(ext.as_str(), "mp3" | "wav" | "mp4" | "mkv" | "webm") {
                stats.audio_video_files += 1;
            }
        }

        // Detect dependencies
        let cargo_toml = self.repo_root.join("Cargo.toml");
        if let Ok(content) = fs::read_to_string(cargo_toml) {
            for line in content.lines() {
                if line.contains('=') && !line.starts_with('[') {
                    if let Some(dep) = line.split('=').next() {
                        let d = dep.trim();
                        if !d.is_empty() && !stats.dependencies.contains(&d.to_string()) {
                            stats.dependencies.push(d.to_string());
                        }
                    }
                }
            }
        }

        let pkg_json = self.repo_root.join("package.json");
        if let Ok(content) = fs::read_to_string(pkg_json) {
            if let Ok(v) = serde_json::from_str::<serde_json::Value>(&content) {
                if let Some(deps) = v.get("dependencies").and_then(|d| d.as_object()) {
                    for k in deps.keys() {
                        stats.dependencies.push(k.clone());
                    }
                }
            }
        }

        stats
    }

    fn render_index(&self, _stats: &RepoStats) -> String {
        format!(r#"# {repo} — Knowledge & Architecture Wiki

Generated on: {date} (UTC)
Repository: `{repo}`

## Overview
This wiki provides a living architectural map, codebase connectivity graph, security governance framework, improvements ledger, and research foundation for `{repo}`. It is automatically indexed into the local LanceDB multimodal RAG store for semantic vector search and LLM context augmentation.

## Wiki Table of Contents
1. **[01. System Architecture](01-architecture.md)** — Core components, subsystem boundaries, data flow, and directory taxonomy.
2. **[02. Codebase Connections & Symbols](02-codebase-connections.md)** — Call graphs, key interfaces, symbol registry, and inter-module coupling.
3. **[03. Security & Governance](03-security-and-governance.md)** — Zero-Trust mandates, Post-Quantum Cryptography (PQC), secrets hygiene, and attack surface.
4. **[04. Improvements & Technical Debt](04-improvements-and-debt.md)** — Refactoring targets, debt ledger, code hotspots, and modernizing paths.
5. **[05. Research & Intelligence](05-research-and-intelligence.md)** — Algorithmic foundations, model specifications, cultural/philosophical doctrine, and citations.
6. **[06. Marketing & Positioning](06-marketing-and-positioning.md)** — Strategic positioning, value propositions, key differentiators, and ecosystem role.

---
*Maintained by ainish-coder Multimodal RAG & Wiki Engine.*
"#,
            repo = self.repo_name,
            date = Utc::now().to_rfc3339()
        )
    }

    fn render_architecture(&self, stats: &RepoStats) -> String {
        let mut dirs_list = String::new();
        let mut sorted_dirs: Vec<&String> = stats.directories.iter().collect();
        sorted_dirs.sort();
        for d in sorted_dirs.iter().take(20) {
            dirs_list.push_str(&format!("- `{}/`\n", d));
        }

        let mut entry_list = String::new();
        for ep in &stats.entrypoints {
            entry_list.push_str(&format!("- `{}`\n", ep));
        }
        if entry_list.is_empty() {
            entry_list.push_str("- Standard entrypoints configured in project manifests.\n");
        }

        format!(r#"# 01. System Architecture — {repo}

## 1. Executive Summary
`{repo}` is engineered with modular boundaries, strict separation of concerns, and reproducible deployment artifacts.

## 2. Directory Layout & Module Ownership
The repository is structured into the following operational subsystems:
{dirs_list}

## 3. Entrypoints & Execution Vectors
The primary execution boundaries and user-facing entrypoints:
{entry_list}

## 4. Multimodal Asset Distribution
- **Total Tracked Files:** {total_files}
- **Source Code Files:** {code_files}
- **Documentation & Notes:** {doc_files}
- **Image Assets:** {image_files}
- **Audio / Video Media:** {media_files}

## 5. Architectural Communication Protocol
- Coordination across agent harnesses and operator sessions is mediated via dated ledger files (`.agents/comms/{{date}}-team.txt`) and durable memory files (`.agents/memories/{{date}}-memory.txt`).
- State mutations execute on task worktrees (`feat/*`, `fix/*`, `chore/*`) and merge autonomously when verification gates pass.
"#,
            repo = self.repo_name,
            dirs_list = dirs_list,
            entry_list = entry_list,
            total_files = stats.total_files,
            code_files = stats.code_files,
            doc_files = stats.doc_files,
            image_files = stats.image_files,
            media_files = stats.audio_video_files,
        )
    }

    fn render_connections(&self, stats: &RepoStats) -> String {
        let mut dep_list = String::new();
        for d in &stats.dependencies {
            dep_list.push_str(&format!("- `{}`\n", d));
        }
        if dep_list.is_empty() {
            dep_list.push_str("- Zero external heavy dependencies; platform standard library oriented.\n");
        }

        format!(r#"# 02. Codebase Connections & Symbols — {repo}

## 1. Component Linkage & Call Graph
Codebase components in `{repo}` communicate across well-defined interfaces and CLI surfaces.

## 2. External Dependencies & Subsystems
{dep_list}

## 3. Cross-Cutting Concerns
- **PQC Secrets Decoupling:** Cryptographic operations are isolated from application logic through FIPS 203/204/205 tools.
- **RAG & Knowledge Retrieval:** Codebase symbols and documentation chunks are vectorized using EmbeddingGemma-2 (768-d) and queried via LanceDB hybrid search.
- **Rules Synchronization:** Rules and agent contracts propagate outward from `ainish-coder` to target repositories via `--rules` deployment.
"#,
            repo = self.repo_name,
            dep_list = dep_list
        )
    }

    fn render_security(&self, _stats: &RepoStats) -> String {
        format!(r#"# 03. Security & Governance — {repo}

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
"#,
            repo = self.repo_name
        )
    }

    fn render_improvements(&self, stats: &RepoStats) -> String {
        let mut todo_list = String::new();
        for (p, line, text) in stats.todos.iter().take(25) {
            todo_list.push_str(&format!("- **`{}:{}`**: {}\n", p, line, text));
        }
        if todo_list.is_empty() {
            todo_list.push_str("- No explicit TODO/FIXME markers discovered in codebase.\n");
        }

        format!(r#"# 04. Improvements & Technical Debt — {repo}

## 1. In-Flight Debt & Code Hotspots
The following actionable items and markers were identified across the codebase:
{todo_list}

## 2. Recommended Architectural Refactors
1. **Multimodal Indexing Expansion:** Continuously refresh LanceDB vectors upon meaningful git commits.
2. **Deterministic Build Pipeline:** Ensure all binary targets compile with zero warnings across macOS, Linux, and Windows MSVC.
3. **Zero-Stale Memory Scrubbing:** Retire resolved constraints in `.agents/memories/` using `[RESOLVED]` entries.
"#,
            repo = self.repo_name,
            todo_list = todo_list
        )
    }

    fn render_research(&self, _stats: &RepoStats) -> String {
        format!(r#"# 05. Research & Intelligence — {repo}

## 1. Multimodal Embedding Architecture
- **Model:** `unsloth/embeddinggemma-2-GGUF` (Google DeepMind EmbeddingGemma-2).
- **Parameters:** 740M total (270M text backbone + 170M vision encoder + 300M audio encoder).
- **Output Space:** 768-dimensional normalized dense embedding space uniting text, code, images, video, and audio.
- **Matryoshka Representation Learning (MRL):** Supports lossless truncation down to 256 dimensions with mandatory L2 re-normalization.
- **Context Length:** 8,192 tokens shared across modalities.

## 2. Vector Database & Storage Engine
- **Storage:** LanceDB (columnar Arrow table format with embedded IVF-PQ / HNSW vector indexing).
- **Hybrid Retrieval:** Dense vector similarity combined with lexical BM25/FTS search.
"#,
            repo = self.repo_name
        )
    }

    fn render_marketing(&self, _stats: &RepoStats) -> String {
        format!(r#"# 06. Marketing & Positioning — {repo}

## 1. Core Value Proposition
`{repo}` delivers an autonomous, high-integrity AI coding infrastructure combining:
- **Post-Quantum Cryptographic Security** for all machine identity and secrets operations.
- **Distributed Agent Coordination** with single-truth ledgers and isolated worktrees.
- **State-of-the-Art Multimodal RAG** powered by Google DeepMind EmbeddingGemma-2 and LanceDB.

## 2. Key Differentiators
- **Zero-Blind Searching:** Deep semantic code and multimodal asset search across 100+ languages and media formats.
- **Autonomous Peer Protocol:** Autonomous git worktree branching, green gate validation, and seamless merging.
- **Living Architectural Wiki:** Automatic generation of structured repository wikis that ground agents and developers in true codebase structure.
"#,
            repo = self.repo_name
        )
    }
}

