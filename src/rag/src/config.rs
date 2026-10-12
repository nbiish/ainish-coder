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
}

impl RagConfig {
    pub fn detect(repo_root: &Path) -> Self {
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

        let lancedb_dir = repo_root.join(".agents").join("rag").join("lancedb");
        let wiki_dir = repo_root.join(".agents").join("wiki");
        let embedding_dim = 768;
        let threads = env::var("AINISH_RAG_THREADS").ok().and_then(|t| t.parse().ok());
        let max_mem = env::var("AINISH_RAG_MAX_MEM").ok().and_then(|m| m.parse().ok());

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
        }
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
