use std::path::{Path, PathBuf};
use std::env;

#[derive(Debug, Clone)]
pub struct RagConfig {
    pub hf_hub_cache: PathBuf,
    pub model_path: Option<PathBuf>,
    pub mmproj_path: Option<PathBuf>,
    pub llama_bin: Option<PathBuf>,
    pub server_url: String,
    pub server_port: u16,
    pub lancedb_dir: PathBuf,
    pub wiki_dir: PathBuf,
    pub embedding_dim: usize,
    pub threads: Option<usize>,
    pub max_mem: Option<usize>,
    pub psk: Option<String>,
    pub symbol_salt: Option<String>,
    pub model_manifest_path: PathBuf,
    pub psk_ttl: Option<u64>,
    pub numa: Option<String>,
    pub cpu_affinity: Option<String>,
    pub dp_epsilon: Option<f32>,
    pub dp_max_budget: Option<f32>,
    /// "local" (llama server, default) or "api" (remote OpenAI-compatible embeddings endpoint).
    pub embed_provider: String,
    /// Base URL of the API embeddings endpoint, e.g. `https://api.openai.com/v1`.
    pub embed_api_base: Option<String>,
    /// API key resolved in-memory from env/PQC vault; NEVER persisted to disk.
    pub embed_api_key: Option<String>,
    /// Remote model name, e.g. `text-embedding-3-small`.
    pub embed_model: Option<String>,
    /// Vector dimension of the remote model (must match the LanceDB store).
    pub embed_dim: Option<usize>,
}

pub fn resolve_canonical_repo_root(start: &Path) -> PathBuf {
    if start.join(".agents").exists() {
        return start.to_path_buf();
    }
    let git_file = start.join(".git");
    if git_file.is_file() {
        if let Ok(content) = std::fs::read_to_string(&git_file) {
            for line in content.lines() {
                if let Some(gitdir) = line.trim().strip_prefix("gitdir:") {
                    let gitdir_path = PathBuf::from(gitdir.trim());
                    if let Some(parent) = gitdir_path.parent() {
                        if parent.ends_with("worktrees") {
                            if let Some(dot_git) = parent.parent() {
                                if let Some(main_repo) = dot_git.parent() {
                                    if main_repo.join(".agents").exists() {
                                        return main_repo.to_path_buf();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    let mut curr = start.parent();
    while let Some(p) = curr {
        if p.join(".agents").exists() {
            return p.to_path_buf();
        }
        curr = p.parent();
    }
    start.to_path_buf()
}

impl RagConfig {
    pub fn detect(repo_root: &Path) -> Self {
        let canonical_root = resolve_canonical_repo_root(repo_root);

        // 1. Direct explicit model overrides take precedence
        let explicit_model = env::var("AINISH_RAG_MODEL")
            .or_else(|_| env::var("EMBEDDINGGEMMA_MODEL"))
            .ok()
            .map(PathBuf::from)
            .filter(|p| p.exists());

        let explicit_mmproj = env::var("AINISH_RAG_MMPROJ")
            .or_else(|_| env::var("EMBEDDINGGEMMA_MMPROJ"))
            .ok()
            .map(PathBuf::from)
            .filter(|p| p.exists());

        let hf_cache = detect_hf_hub_cache();
        let (found_model, found_mmproj) = find_embeddinggemma_models(&hf_cache);

        let model_path = explicit_model.or(found_model);
        let mmproj_path = explicit_mmproj.or(found_mmproj);
        let llama_bin = find_llama_binary();
        
        let server_port = env::var("AINISH_RAG_PORT")
            .ok()
            .and_then(|p| p.parse().ok())
            .unwrap_or(8080);
            
        let server_url = env::var("AINISH_RAG_URL")
            .unwrap_or_else(|_| format!("http://127.0.0.1:{}", server_port));

        let lancedb_dir = canonical_root.join(".agents").join("rag").join("lancedb");
        let wiki_dir = canonical_root.join(".agents").join("wiki");
        let embedding_dim = 768;
        let threads = env::var("AINISH_RAG_THREADS").ok().and_then(|t| t.parse().ok());
        let max_mem = env::var("AINISH_RAG_MAX_MEM").ok().and_then(|m| m.parse().ok());

        let psk = env::var("AINISH_RAG_PSK")
            .ok()
            .filter(|s| !s.trim().is_empty())
            .or_else(|| {
                let p = canonical_root.join(".agents").join("rag").join("session.psk");
                std::fs::read_to_string(p).ok().map(|s| s.trim().to_string()).filter(|s| !s.is_empty())
            });

        let symbol_salt = env::var("AINISH_SYMBOL_SALT")
            .ok()
            .filter(|s| !s.trim().is_empty());

        let model_manifest_path = canonical_root.join(".agents").join("audit").join("model-manifest.json");

        // API-based embedding provider (operator opt-in). Non-secret fields may come from
        // ainish-coder's persisted provider config; the API key is resolved in-memory only.
        let embed_provider = env::var("AINISH_EMBED_PROVIDER")
            .ok()
            .map(|s| s.trim().to_lowercase())
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| "local".to_string());
        let embed_api_base = env::var("AINISH_EMBED_API_BASE")
            .ok()
            .filter(|s| !s.trim().is_empty())
            .or_else(|| Self::read_provider_cfg(&canonical_root, "api_base"));
        let embed_model = env::var("AINISH_EMBED_MODEL")
            .ok()
            .filter(|s| !s.trim().is_empty())
            .or_else(|| Self::read_provider_cfg(&canonical_root, "model"));
        let embed_dim = env::var("AINISH_EMBED_DIM")
            .ok()
            .and_then(|v| v.trim().parse::<usize>().ok())
            .or_else(|| Self::read_provider_cfg(&canonical_root, "dim").and_then(|v| v.parse::<usize>().ok()));
        // Key: env first, then the PQC vault via the standard AINISH key name. Never on disk.
        let embed_api_key = env::var("AINISH_EMBED_API_KEY")
            .ok()
            .filter(|s| !s.trim().is_empty());

        Self {
            hf_hub_cache: hf_cache,
            model_path,
            mmproj_path,
            llama_bin,
            server_url,
            server_port,
            lancedb_dir,
            wiki_dir,
            embedding_dim,
            threads,
            max_mem,
            psk,
            symbol_salt,
            model_manifest_path,
            psk_ttl: env::var("AINISH_RAG_PSK_TTL").ok().and_then(|v| v.trim().parse().ok()).filter(|v| *v > 0),
            numa: env::var("AINISH_RAG_NUMA").ok().filter(|s| !s.trim().is_empty()),
            cpu_affinity: env::var("AINISH_RAG_CPU_AFFINITY").ok().filter(|s| !s.trim().is_empty()),
            dp_epsilon: env::var("AINISH_RAG_DP_EPSILON").ok().and_then(|v| v.trim().parse().ok()),
            dp_max_budget: env::var("AINISH_RAG_DP_MAX_BUDGET").ok().and_then(|v| v.trim().parse().ok()),
            embed_provider,
            embed_api_base,
            embed_api_key,
            embed_model,
            embed_dim,
        }
    }

    /// Reads a non-secret field from `.agents/rag/embed-provider.json` (written by
    /// `ainish-coder --embed-config`). Secrets are never stored there.
    fn read_provider_cfg(canonical_root: &Path, key: &str) -> Option<String> {
        let p = canonical_root.join(".agents").join("rag").join("embed-provider.json");
        let text = std::fs::read_to_string(p).ok()?;
        let v: serde_json::Value = serde_json::from_str(&text).ok()?;
        let raw = v.get(key)?;
        // Fields may be strings (`api_base`, `model`) or numbers (`dim`).
        let s = match raw {
            serde_json::Value::String(s) => s.trim().to_string(),
            serde_json::Value::Number(n) => n.to_string(),
            _ => return None,
        };
        if s.is_empty() { None } else { Some(s) }
    }

    /// True when a remote API embedding provider is fully configured.
    pub fn uses_api_embeddings(&self) -> bool {
        self.embed_provider == "api"
            && self.embed_api_base.is_some()
            && self.embed_model.is_some()
    }
}

/// Detects Hugging Face cache across Windows, WSL, Linux, and macOS
/// Following the standard HF environment variable hierarchy:
/// 1. HF_HUB_CACHE
/// 2. HUGGINGFACE_HUB_CACHE
/// 3. HF_HOME (/hub)
/// 4. XDG_CACHE_HOME (/huggingface/hub)
/// 5. OS-specific cache roots & multi-environment mount points
pub fn detect_hf_hub_cache() -> PathBuf {
    // 1. Direct hub cache environment variables
    for var in &["HF_HUB_CACHE", "HUGGINGFACE_HUB_CACHE"] {
        if let Ok(val) = env::var(var) {
            let p = PathBuf::from(val);
            if p.exists() {
                return p;
            }
        }
    }

    // 2. HF_HOME base cache directory
    if let Ok(val) = env::var("HF_HOME") {
        let p = PathBuf::from(val).join("hub");
        if p.exists() {
            return p;
        }
    }

    // 3. XDG_CACHE_HOME (Linux / macOS standard)
    if let Ok(val) = env::var("XDG_CACHE_HOME") {
        let p = PathBuf::from(val).join("huggingface").join("hub");
        if p.exists() {
            return p;
        }
    }

    let mut candidates: Vec<PathBuf> = Vec::new();

    // 4. User home directories across platforms
    let home = env::var("HOME").ok().map(PathBuf::from);
    let userprofile = env::var("USERPROFILE").ok().map(PathBuf::from);

    if let Some(ref h) = home {
        // Linux / WSL standard
        candidates.push(h.join(".cache").join("huggingface").join("hub"));
        // macOS standard
        candidates.push(h.join("Library").join("Caches").join("huggingface").join("hub"));
    }

    if let Some(ref up) = userprofile {
        // Windows standard
        candidates.push(up.join(".cache").join("huggingface").join("hub"));
    }

    if let Ok(local_app) = env::var("LOCALAPPDATA") {
        candidates.push(PathBuf::from(local_app).join("huggingface").join("hub"));
    }

    // 5. Windows external drive roots (AI datasets often stored here)
    let win_drives = [
        r"D:\AI\huggingface\hub",
        r"D:\huggingface\hub",
        r"E:\AI\huggingface\hub",
        r"E:\huggingface\hub",
        r"C:\AI\huggingface\hub",
        r"F:\AI\huggingface\hub",
    ];
    for d in win_drives {
        candidates.push(PathBuf::from(d));
    }

    // 6. WSL mount points (accessing Windows drives from WSL Linux)
    let wsl_mounts = [
        "/mnt/d/AI/huggingface/hub",
        "/mnt/d/huggingface/hub",
        "/mnt/e/AI/huggingface/hub",
        "/mnt/e/huggingface/hub",
        "/mnt/c/AI/huggingface/hub",
    ];
    for m in wsl_mounts {
        candidates.push(PathBuf::from(m));
    }

    // Check WSL Windows user profile cache (/mnt/c/Users/<user>/.cache/...)
    let mnt_c_users = Path::new("/mnt/c/Users");
    if mnt_c_users.is_dir() {
        if let Ok(entries) = std::fs::read_dir(mnt_c_users) {
            for entry in entries.flatten() {
                let user_dir = entry.path();
                if user_dir.is_dir() {
                    let cache = user_dir.join(".cache").join("huggingface").join("hub");
                    if cache.exists() {
                        candidates.push(cache);
                    }
                }
            }
        }
    }

    // 7. macOS external volume roots (/Volumes/<Drive>/...)
    let volumes = Path::new("/Volumes");
    if volumes.is_dir() {
        if let Ok(entries) = std::fs::read_dir(volumes) {
            for entry in entries.flatten() {
                let v = entry.path();
                candidates.push(v.join("AI").join("huggingface").join("hub"));
                candidates.push(v.join("huggingface").join("hub"));
            }
        }
    }

    // 8. Linux media mount roots (/media/$USER/<Drive>/...)
    let media = Path::new("/media");
    if media.is_dir() {
        if let Ok(entries) = std::fs::read_dir(media) {
            for entry in entries.flatten() {
                let u = entry.path();
                if u.is_dir() {
                    if let Ok(drives) = std::fs::read_dir(&u) {
                        for drive in drives.flatten() {
                            let dp = drive.path();
                            candidates.push(dp.join("AI").join("huggingface").join("hub"));
                            candidates.push(dp.join("huggingface").join("hub"));
                        }
                    }
                }
            }
        }
    }

    for c in candidates {
        if c.exists() {
            return c;
        }
    }

    // Fallback default
    if cfg!(target_os = "windows") {
        PathBuf::from(r"D:\AI\huggingface\hub")
    } else if Path::new("/mnt/d").exists() {
        PathBuf::from("/mnt/d/AI/huggingface/hub")
    } else if let Some(ref h) = home {
        h.join(".cache").join("huggingface").join("hub")
    } else {
        PathBuf::from(r"D:\AI\huggingface\hub")
    }
}

/// Finds EmbeddingGemma GGUF and multimodal projector models
pub fn find_embeddinggemma_models(hub_dir: &Path) -> (Option<PathBuf>, Option<PathBuf>) {
    if !hub_dir.exists() {
        return (None, None);
    }

    // 1. Direct check: what if hub_dir is already the model directory or snapshot directory?
    if let (Some(m), mm) = check_dir_for_models(hub_dir) {
        return (Some(m), mm);
    }

    // 2. Check if hub_dir contains a "snapshots" subdirectory directly
    let snapshots_direct = hub_dir.join("snapshots");
    if snapshots_direct.is_dir() {
        if let (Some(m), mm) = check_snapshots_dir(&snapshots_direct) {
            return (Some(m), mm);
        }
    }

    // 3. Known Hugging Face repository candidate directory prefixes
    let candidate_dirs = [
        "models--unsloth--embeddinggemma-2-GGUF",
        "models--google--embeddinggemma-2",
        "models--FreedomAISVR--embeddinggemma-2-GGUF",
    ];

    for c in candidate_dirs {
        let snapshots = hub_dir.join(c).join("snapshots");
        if snapshots.is_dir() {
            if let (Some(m), mm) = check_snapshots_dir(&snapshots) {
                return (Some(m), mm);
            }
        }
    }

    // 4. Broad scan: search any subdirectory matching `*embeddinggemma*` in hub_dir
    if let Ok(entries) = std::fs::read_dir(hub_dir) {
        for entry in entries.flatten() {
            let p = entry.path();
            if p.is_dir() {
                let name = p.file_name().and_then(|n| n.to_str()).unwrap_or("").to_lowercase();
                if name.contains("embeddinggemma") {
                    let snapshots = p.join("snapshots");
                    if snapshots.is_dir() {
                        if let (Some(m), mm) = check_snapshots_dir(&snapshots) {
                            return (Some(m), mm);
                        }
                    }
                    if let (Some(m), mm) = check_dir_for_models(&p) {
                        return (Some(m), mm);
                    }
                }
            }
        }
    }

    (None, None)
}

fn check_snapshots_dir(snapshots_dir: &Path) -> (Option<PathBuf>, Option<PathBuf>) {
    if let Ok(entries) = std::fs::read_dir(snapshots_dir) {
        for entry in entries.flatten() {
            let snap = entry.path();
            if snap.is_dir() {
                if let (Some(m), mm) = check_dir_for_models(&snap) {
                    return (Some(m), mm);
                }
            }
        }
    }
    (None, None)
}

fn check_dir_for_models(dir: &Path) -> (Option<PathBuf>, Option<PathBuf>) {
    let mut found_model = None;
    let mut found_mmproj = None;

    let model_prefs = [
        "embeddinggemma-2-BF16.gguf",
        "embeddinggemma-2-Q8_0.gguf",
        "embeddinggemma-2-UD-Q4_K_XL.gguf",
        "embeddinggemma-2-F16.gguf",
    ];
    for name in model_prefs {
        let mp = dir.join(name);
        if mp.exists() {
            found_model = Some(mp);
            break;
        }
    }

    // Also check wildcard embeddinggemma-2*.gguf if exact match not found
    if found_model.is_none() {
        if let Ok(entries) = std::fs::read_dir(dir) {
            for entry in entries.flatten() {
                let p = entry.path();
                let fname = p.file_name().and_then(|n| n.to_str()).unwrap_or("").to_lowercase();
                if fname.starts_with("embeddinggemma-2") && fname.ends_with(".gguf") && !fname.contains("mmproj") {
                    found_model = Some(p);
                    break;
                }
            }
        }
    }

    let mmproj_prefs = [
        "mmproj-F16.gguf",
        "mmproj-BF16.gguf",
        "mmproj-Q8_0.gguf",
    ];
    for name in mmproj_prefs {
        let mp = dir.join(name);
        if mp.exists() {
            found_mmproj = Some(mp);
            break;
        }
    }

    if found_mmproj.is_none() {
        if let Ok(entries) = std::fs::read_dir(dir) {
            for entry in entries.flatten() {
                let p = entry.path();
                let fname = p.file_name().and_then(|n| n.to_str()).unwrap_or("").to_lowercase();
                if fname.starts_with("mmproj") && fname.ends_with(".gguf") {
                    found_mmproj = Some(p);
                    break;
                }
            }
        }
    }

    (found_model, found_mmproj)
}

/// Finds llama or llama-server executable across Windows, WSL, Linux, and macOS
pub fn find_llama_binary() -> Option<PathBuf> {
    // 1. Explicit environment variable overrides
    for var in &["LLAMA_SERVER_BIN", "LLAMA_BIN"] {
        if let Ok(val) = env::var(var) {
            let p = PathBuf::from(val);
            if p.exists() {
                return Some(p);
            }
        }
    }

    // 2. Windows-specific paths
    if let Ok(local_app) = env::var("LOCALAPPDATA") {
        let win_app_llama = PathBuf::from(local_app)
            .join("Microsoft")
            .join("WindowsApps")
            .join("llama.exe");
        if win_app_llama.exists() {
            return Some(win_app_llama);
        }
    }

    // 3. Candidates in PATH
    let path_candidates = [
        "llama-server",
        "llama",
        "llama.exe",
        "llama-server.exe",
    ];
    for c in path_candidates {
        if let Ok(path) = which(c) {
            return Some(path);
        }
    }

    // 4. macOS Homebrew & standard POSIX locations
    let posix_candidates = [
        "/opt/homebrew/bin/llama-server",
        "/opt/homebrew/bin/llama",
        "/usr/local/bin/llama-server",
        "/usr/local/bin/llama",
        "/usr/bin/llama-server",
        "/usr/bin/llama",
    ];
    for p in posix_candidates {
        let pb = PathBuf::from(p);
        if pb.is_file() {
            return Some(pb);
        }
    }

    // 5. User local bin (~/.local/bin/...)
    if let Ok(home) = env::var("HOME") {
        let user_bin = PathBuf::from(home).join(".local").join("bin");
        for name in &["llama-server", "llama"] {
            let pb = user_bin.join(name);
            if pb.is_file() {
                return Some(pb);
            }
        }
    }

    // 6. WSL accessing Windows llama.exe
    let wsl_winapps = Path::new("/mnt/c/Users");
    if wsl_winapps.is_dir() {
        if let Ok(entries) = std::fs::read_dir(wsl_winapps) {
            for entry in entries.flatten() {
                let p = entry.path();
                if p.is_dir() {
                    let exe = p.join("AppData")
                        .join("Local")
                        .join("Microsoft")
                        .join("WindowsApps")
                        .join("llama.exe");
                    if exe.is_file() {
                        return Some(exe);
                    }
                }
            }
        }
    }

    None
}

fn which(cmd: &str) -> Result<PathBuf, ()> {
    if let Ok(path_var) = env::var("PATH") {
        for p in env::split_paths(&path_var) {
            let full = p.join(cmd);
            if full.is_file() {
                return Ok(full);
            }
        }
    }
    Err(())
}

#[cfg(test)]
mod tests {
    use super::*;

    /// `ainish-coder --embed-config` writes non-secret provider settings here; the RAG engine
    /// must pick them up so a remote API model can replace the local llama server.
    #[test]
    fn test_read_provider_cfg_from_disk() {
        let dir = std::env::temp_dir().join(format!("ainish-cfg-test-{}", std::process::id()));
        let rag_dir = dir.join(".agents").join("rag");
        std::fs::create_dir_all(&rag_dir).unwrap();
        let f = rag_dir.join("embed-provider.json");
        std::fs::write(
            &f,
            r#"{"format":"ainish-rag/embed-provider/v1","provider":"api","api_base":"https://api.example.com/v1","model":"text-embedding-3-small","dim":1536}"#,
        )
        .unwrap();

        assert_eq!(
            RagConfig::read_provider_cfg(&dir, "api_base").as_deref(),
            Some("https://api.example.com/v1")
        );
        assert_eq!(
            RagConfig::read_provider_cfg(&dir, "model").as_deref(),
            Some("text-embedding-3-small")
        );
        assert_eq!(RagConfig::read_provider_cfg(&dir, "dim").as_deref(), Some("1536"));
        // Unknown keys resolve to None rather than panicking.
        assert!(RagConfig::read_provider_cfg(&dir, "nope").is_none());

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_read_provider_cfg_missing_file_is_none() {
        let dir = std::env::temp_dir().join(format!("ainish-cfg-missing-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        assert!(RagConfig::read_provider_cfg(&dir, "api_base").is_none());
        let _ = std::fs::remove_dir_all(&dir);
    }
}
