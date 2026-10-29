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

        let ledger = self.read_operator_ledger();
        let mut page = format!(r#"# 04. Improvements & Technical Debt — {repo}

## 1. In-Flight Debt & Code Hotspots
The following actionable items and markers were identified across the codebase:
{todo_list}

## 2. Recommended Architectural Refactors
1. **Multimodal Indexing Expansion:** Continuously refresh LanceDB vectors upon meaningful git commits.
2. **Deterministic Build Pipeline:** Ensure all binary targets compile with zero warnings across macOS, Linux, and Windows MSVC.
3. **Zero-Stale Memory Scrubbing:** Retire resolved constraints in `.agents/memories/` using `[RESOLVED]` entries.

## 3. Operator ledger
`ainish-rag wiki` rewrites pages 01–06 and README.md. It never writes `.agents/wiki/ledger.md`. Append one dated line there per cycle. This section is that file, spliced in on each generation.

"#,
            repo = self.repo_name,
            todo_list = todo_list,
        );
        page.push_str(&ledger);
        page
    }

    /// Reads `.agents/wiki/ledger.md`, scrubs credentials/PII (`scrub_sensitive_content`),
    /// redacts local absolute filesystem user paths to repository-relative paths, and
    /// cross-links with `.agents/memories/{date}-memory.txt` so resolved items automatically mark `[RESOLVED]`.
    pub fn read_operator_ledger(&self) -> String {
        let path = self.wiki_dir.join("ledger.md");
        match fs::read_to_string(&path) {
            Ok(text) if !text.trim().is_empty() => {
                let scrubbed = crate::ingest::scrub_sensitive_content(&text);
                let redacted = self.redact_local_user_paths(&scrubbed);
                let cross_linked = self.cross_link_resolved_memories(&redacted);
                cross_linked.trim_end().to_string() + "\n"
            }
            _ => "- No operator entries yet. Append dated lines to `.agents/wiki/ledger.md`.\n".to_string(),
        }
    }

    /// Redacts local absolute filesystem user paths (Windows `C:\Users\<user>\...`, `D:\Code\...`,
    /// WSL `/mnt/c/Users/<user>/...`, `/mnt/d/Code/...`, POSIX `/Users/<user>/...`, `/home/<user>/...`)
    /// and internal RFC-1918 / CGNAT (Tailscale/WireGuard) IPv4 and ULA/link-local IPv6 addresses
    /// in ledger entries prior to wiki generation.
    pub fn redact_local_user_paths(&self, text: &str) -> String {
        let mut out = text.to_string();
        let repo_abs_slash = self.repo_root.to_string_lossy().replace('\\', "/");
        let repo_abs_back = self.repo_root.to_string_lossy().replace('/', "\\");
        if !repo_abs_slash.is_empty() && repo_abs_slash != "." {
            out = out.replace(&(repo_abs_slash.clone() + "/"), "");
            out = out.replace(&repo_abs_slash, ".");
        }
        if !repo_abs_back.is_empty() && repo_abs_back != "." {
            out = out.replace(&(repo_abs_back.clone() + "\\"), "");
            out = out.replace(&repo_abs_back, ".");
        }

        static RE_USER_PATHS: std::sync::LazyLock<regex::Regex> = std::sync::LazyLock::new(|| {
            regex::Regex::new(r"(?i)(?:[A-Z]:[\\/]+Users[\\/]+[^\\/\s`'\x22]+[\\/]+|/mnt/[a-z]/Users/[^/\s`'\x22]+/|/Users/[^/\s`'\x22]+/|/home/[^/\s`'\x22]+/|[A-Z]:[\\/]+Code[\\/]+|/mnt/[a-z]/Code/)").expect("valid user path regex")
        });
        static RE_INTERNAL_IPS: std::sync::LazyLock<regex::Regex> = std::sync::LazyLock::new(|| {
            regex::Regex::new(r"(?i)\b(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3}|100\.(?:6[4-9]|[7-9]\d|1[0-1]\d|12[0-7])\.\d{1,3}\.\d{1,3}|(?:fd[0-9a-f]{2}|fe80):[0-9a-f:]+)\b").expect("valid internal ip regex")
        });
        static RE_MAC_ADDR: std::sync::LazyLock<regex::Regex> = std::sync::LazyLock::new(|| {
            regex::Regex::new(r"(?i)\b(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b").expect("valid mac address regex")
        });
        let no_paths = RE_USER_PATHS.replace_all(&out, "").into_owned();
        let no_ips = RE_INTERNAL_IPS.replace_all(&no_paths, "[REDACTED:INTERNAL_IP]").into_owned();
        RE_MAC_ADDR.replace_all(&no_ips, "[REDACTED:MAC]").into_owned()
    }

    /// Strips ANSI escape sequences, non-printable control characters, and Trojan Source
    /// bidirectional Unicode override characters (`U+202A`..`U+202E`, `U+2066`..`U+2069`)
    /// from operator note input.
    pub fn sanitize_note_input(note: &str) -> String {
        static RE_ANSI: std::sync::LazyLock<regex::Regex> = std::sync::LazyLock::new(|| {
            regex::Regex::new(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07]*\x07|\x1b[@-_]").expect("valid ansi regex")
        });
        let without_ansi = RE_ANSI.replace_all(note, "");
        without_ansi
            .chars()
            .filter(|&c| {
                (!c.is_control() || c == '\t')
                    && !matches!(c, '\u{202A}'..='\u{202E}' | '\u{2066}'..='\u{2069}')
            })
            .collect::<String>()
            .trim()
            .to_string()
    }

    /// Checks whether text contains Trojan Source bidirectional Unicode override characters.
    pub fn contains_bidi_override(text: &str) -> bool {
        text.chars().any(|c| matches!(c, '\u{202A}'..='\u{202E}' | '\u{2066}'..='\u{2069}'))
    }

    /// Resolves the active short git commit hash (`HEAD`) for provenance stamping in `ledger.md`.
    fn current_head_short_sha(&self) -> String {
        std::process::Command::new("git")
            .args(["rev-parse", "--short", "HEAD"])
            .current_dir(&self.repo_root)
            .output()
            .ok()
            .filter(|o| o.status.success())
            .and_then(|o| String::from_utf8(o.stdout).ok())
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| "HEAD".to_string())
    }

    /// Cross-links `.agents/wiki/ledger.md` entries with `.agents/memories/{date}-memory.txt`
    /// so ledger items matching `[RESOLVED]` memory entries automatically carry `[RESOLVED]`.
    pub fn cross_link_resolved_memories(&self, ledger_text: &str) -> String {
        let memories_dir = self.repo_root.join(".agents").join("memories");
        let mut resolved_tokens: Vec<String> = Vec::new();
        if let Ok(entries) = fs::read_dir(&memories_dir) {
            for e in entries.flatten() {
                let p = e.path();
                if p.file_name().map_or(false, |n| n.to_string_lossy().ends_with("-memory.txt")) {
                    if let Ok(m_text) = fs::read_to_string(&p) {
                        for line in m_text.lines() {
                            if line.contains("[RESOLVED]") {
                                for word in line.split(|c: char| !c.is_alphanumeric() && c != '_' && c != '-') {
                                    if word.len() >= 6 && !word.eq_ignore_ascii_case("RESOLVED") {
                                        resolved_tokens.push(word.to_lowercase());
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        let mut output_lines = Vec::new();
        for line in ledger_text.lines() {
            let trimmed = line.trim();
            if trimmed.starts_with("- ") && !trimmed.contains("[RESOLVED]") && !resolved_tokens.is_empty() {
                let lower = trimmed.to_lowercase();
                let match_count = resolved_tokens.iter().filter(|tok| lower.contains(tok.as_str())).count();
                if match_count >= 2 {
                    if let Some(rest) = line.strip_prefix("- ") {
                        output_lines.push(format!("- [RESOLVED] {}", rest));
                        continue;
                    }
                }
            }
            output_lines.push(line.to_string());
        }
        output_lines.join("\n")
    }

    /// Appends a UTC-dated operator note (with active `HEAD` commit SHA) to `.agents/wiki/ledger.md`,
    /// signs `.agents/wiki/ledger.md` with a detached FIPS 204 ML-DSA-65 `.sig` envelope,
    /// and re-renders `.agents/wiki/04-improvements-and-debt.md`.
    pub fn append_note_and_sign(&self, note: &str) -> Result<(PathBuf, PathBuf), String> {
        fs::create_dir_all(&self.wiki_dir).map_err(|e| e.to_string())?;
        let ledger_path = self.wiki_dir.join("ledger.md");
        let today = Utc::now().format("%Y-%m-%d").to_string();
        let head_sha = self.current_head_short_sha();
        let no_ctrl = Self::sanitize_note_input(note);
        let clean_note = crate::ingest::scrub_sensitive_content(&no_ctrl);
        let clean_note = self.redact_local_user_paths(&clean_note);
        let entry_line = format!("- {} ({}) {}\n", today, head_sha, clean_note);

        let mut content = if ledger_path.exists() {
            fs::read_to_string(&ledger_path).unwrap_or_default()
        } else {
            "# Operator ledger\n\n`ainish-rag wiki` regenerates `01`–`06` and `README.md`. It does not touch this file. Append one dated line per cycle. The generator splices this file into `04-improvements-and-debt.md`.\n\n".to_string()
        };
        if !content.ends_with('\n') && !content.is_empty() {
            content.push('\n');
        }
        content.push_str(&entry_line);
        fs::write(&ledger_path, &content).map_err(|e| format!("Failed writing ledger.md: {}", e))?;

        // Sign .agents/wiki/ledger.md with detached ML-DSA-65 .sig envelope
        let sig_path = crate::pqc::sign_file(&ledger_path)?;

        // Re-render page 04 (and full wiki) so 04-improvements-and-debt.md is immediately updated
        let stats = self.analyze_repo();
        let imp_path = self.wiki_dir.join("04-improvements-and-debt.md");
        let imp_content = self.render_improvements(&stats);
        fs::write(&imp_path, imp_content).map_err(|e| e.to_string())?;

        Ok((ledger_path, sig_path))
    }

    /// Marks matching entries `[RESOLVED]` in both `.agents/wiki/ledger.md` (and re-signs `ledger.sig`)
    /// and today's `.agents/memories/{date}-memory.txt`, then re-renders `04-improvements-and-debt.md`.
    pub fn resolve_note(&self, keyword: &str) -> Result<usize, String> {
        let kw_clean = Self::sanitize_note_input(keyword);
        if kw_clean.is_empty() {
            return Err("Empty resolve keyword provided".to_string());
        }
        let kw_lower = kw_clean.to_lowercase();
        let ledger_path = self.wiki_dir.join("ledger.md");
        let mut resolved_count = 0usize;
        let mut matched_lines = Vec::new();

        if ledger_path.exists() {
            let content = fs::read_to_string(&ledger_path).map_err(|e| e.to_string())?;
            let mut updated_lines = Vec::new();
            for line in content.lines() {
                let trimmed = line.trim();
                if trimmed.starts_with("- ") && !trimmed.contains("[RESOLVED]") && trimmed.to_lowercase().contains(&kw_lower) {
                    if let Some(rest) = line.strip_prefix("- ") {
                        let resolved_line = format!("- [RESOLVED] {}", rest);
                        matched_lines.push(rest.to_string());
                        updated_lines.push(resolved_line);
                        resolved_count += 1;
                        continue;
                    }
                }
                updated_lines.push(line.to_string());
            }
            if resolved_count > 0 {
                let new_text = updated_lines.join("\n") + "\n";
                fs::write(&ledger_path, &new_text).map_err(|e| e.to_string())?;
                let _ = crate::pqc::sign_file(&ledger_path);
            }
        }

        // Also append [RESOLVED] entry to today's .agents/memories/{date}-memory.txt
        let mem_dir = self.repo_root.join(".agents").join("memories");
        let _ = fs::create_dir_all(&mem_dir);
        let today = Utc::now().format("%Y-%m-%d").to_string();
        let hhmm = Utc::now().format("%H:%M").to_string();
        let mem_path = mem_dir.join(format!("{}-memory.txt", today));
        let mut mem_content = if mem_path.exists() {
            fs::read_to_string(&mem_path).unwrap_or_default()
        } else {
            format!("# memory — {} (UTC)\n# Pairs with ../comms/{}-team.txt. Format law: AGENTS.md <REPO_MEMORY>.\n\n", today, today)
        };
        if !mem_content.ends_with('\n') && !mem_content.is_empty() {
            mem_content.push('\n');
        }
        if matched_lines.is_empty() {
            mem_content.push_str(&format!("- {} [RESOLVED] {} — resolved via ainish-rag wiki --resolve\n", hhmm, kw_clean));
        } else {
            for m in &matched_lines {
                mem_content.push_str(&format!("- {} [RESOLVED] {} — resolved in wiki ledger\n", hhmm, m));
            }
        }
        fs::write(&mem_path, &mem_content).map_err(|e| e.to_string())?;

        // Re-render page 04
        let stats = self.analyze_repo();
        let imp_path = self.wiki_dir.join("04-improvements-and-debt.md");
        let imp_content = self.render_improvements(&stats);
        let _ = fs::write(&imp_path, imp_content);

        Ok(resolved_count)
    }

    /// Lists all operator notes from `.agents/wiki/ledger.md` with their `[RESOLVED]` / `[OPEN]` status.
    pub fn list_notes(&self) -> Vec<String> {
        let rendered = self.read_operator_ledger();
        rendered
            .lines()
            .filter(|l| l.trim().starts_with("- "))
            .map(|l| l.trim().to_string())
            .collect()
    }

    /// Extracts key symbol graph anchors (`fn`, `struct`, `enum`, `trait`, `def`, `class`) across
    /// files matching `scope_hints` (or top codebase modules) for `ainish-rag orient --inject`.
    pub fn extract_key_symbols_for_orient(&self, scope_hints: &[String], max_anchors: usize) -> Vec<String> {
        let mut anchors = Vec::new();
        let re_sym = regex::Regex::new(r"(?:pub\s+)?(?:async\s+)?(?:fn|struct|enum|trait|def|class)\s+([A-Za-z0-9_]+)").expect("valid sym regex");

        let mut candidate_files = Vec::new();
        for entry in WalkDir::new(&self.repo_root).follow_links(false).into_iter().flatten() {
            if !entry.file_type().is_file() {
                continue;
            }
            let p = entry.path();
            if crate::ingest::is_ignored_path(p) {
                continue;
            }
            let ext = p.extension().and_then(|e| e.to_str()).unwrap_or("").to_lowercase();
            if !matches!(ext.as_str(), "rs" | "py" | "ts" | "js" | "go") {
                continue;
            }
            let rel = p.strip_prefix(&self.repo_root).unwrap_or(p).to_string_lossy().replace('\\', "/");
            let priority = if scope_hints.iter().any(|h| !h.is_empty() && rel.to_lowercase().contains(&h.to_lowercase())) {
                0
            } else {
                1
            };
            candidate_files.push((priority, rel, p.to_path_buf()));
        }
        candidate_files.sort_by(|a, b| a.0.cmp(&b.0).then_with(|| a.1.cmp(&b.1)));

        for (_prio, rel, path) in candidate_files.into_iter().take(12) {
            if let Ok(content) = fs::read_to_string(&path) {
                let mut file_syms = Vec::new();
                for line in content.lines() {
                    if let Some(cap) = re_sym.captures(line) {
                        if let Some(m) = cap.get(1) {
                            let s = m.as_str().to_string();
                            if s.len() >= 4 && !file_syms.contains(&s) {
                                file_syms.push(s);
                                if file_syms.len() >= 6 {
                                    break;
                                }
                            }
                        }
                    }
                }
                if !file_syms.is_empty() {
                    anchors.push(format!("- `{}`: {}", rel, file_syms.iter().map(|s| format!("`{}`", s)).collect::<Vec<_>>().join(", ")));
                    if anchors.len() >= max_anchors {
                        break;
                    }
                }
            }
        }
        anchors
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn operator_ledger_survives_repeated_generate_all_and_scrubs_secrets_and_paths() {
        let tmp_dir = std::env::temp_dir().join(format!("ainish-wiki-test-{}", std::process::id()));
        let _ = fs::remove_dir_all(&tmp_dir);
        let wiki_dir = tmp_dir.join(".agents").join("wiki");
        let mem_dir = tmp_dir.join(".agents").join("memories");
        fs::create_dir_all(&wiki_dir).unwrap();
        fs::create_dir_all(&mem_dir).unwrap();

        let custom_ledger = "# Operator ledger\n\n\
            - 2026-10-28 Custom operator note alpha-bravo-charlie in C:\\Users\\alice\\project\\src\\lib.rs at 192.168.1.42 and 100.88.12.5 mac AA:BB:CC:DD:EE:FF\n\
            - 2026-10-28 Legacy constraint delta_echo_foxtrot_99\n";
        fs::write(wiki_dir.join("ledger.md"), custom_ledger).unwrap();
        fs::write(
            mem_dir.join("2026-10-28-memory.txt"),
            "- 12:00 [RESOLVED] Legacy constraint delta_echo_foxtrot_99 — fixed in main\n",
        ).unwrap();

        let wiki_gen = WikiGenerator::new(&tmp_dir);
        assert_eq!(
            WikiGenerator::sanitize_note_input("hello \x1b[31mred\x1b[0m\x07\u{202E} world"),
            "hello red world"
        );
        assert!(WikiGenerator::contains_bidi_override("evil \u{202E} code"));
        assert!(!WikiGenerator::contains_bidi_override("clean code"));
        // First generation run
        wiki_gen.generate_all().unwrap();
        // Second generation run — must preserve ledger.md and splice into 04-improvements-and-debt.md
        wiki_gen.generate_all().unwrap();

        let ledger_disk = fs::read_to_string(wiki_dir.join("ledger.md")).unwrap();
        assert_eq!(ledger_disk, custom_ledger);

        let page04 = fs::read_to_string(wiki_dir.join("04-improvements-and-debt.md")).unwrap();
        assert!(page04.contains("Custom operator note alpha-bravo-charlie"));
        // User path C:\Users\alice\, internal IPs, and MAC addresses must be redacted
        assert!(!page04.contains("C:\\Users\\alice\\"));
        assert!(!page04.contains("192.168.1.42"));
        assert!(!page04.contains("100.88.12.5"));
        assert!(!page04.contains("AA:BB:CC:DD:EE:FF"));
        assert!(page04.contains("[REDACTED:INTERNAL_IP]"));
        assert!(page04.contains("[REDACTED:MAC]"));
        // Memory cross-link must mark [RESOLVED] on the matching entry
        assert!(page04.contains("- [RESOLVED] 2026-10-28 Legacy constraint delta_echo_foxtrot_99"));

        // Resolve via resolve_note
        let resolved_cnt = wiki_gen.resolve_note("alpha-bravo-charlie").unwrap();
        assert_eq!(resolved_cnt, 1);
        let notes = wiki_gen.list_notes();
        assert!(notes.iter().all(|n| n.contains("[RESOLVED]")));

        let _ = fs::remove_dir_all(&tmp_dir);
    }
}

