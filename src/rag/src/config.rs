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
}

impl RagConfig {
    pub fn detect(repo_root: &Path) -> Self {
        let hf_cache = detect_hf_hub_cache();
        let (model_path, mmproj_path) = find_embeddinggemma_models(&hf_cache);
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
        }
    }
}

fn detect_hf_hub_cache() -> PathBuf {
    if let Ok(val) = env::var("HF_HUB_CACHE") {
        let p = PathBuf::from(val);
        if p.exists() {
            return p;
        }
    }
    if let Ok(val) = env::var("HUGGINGFACE_HUB_CACHE") {
        let p = PathBuf::from(val);
        if p.exists() {
            return p;
        }
    }
    if let Ok(val) = env::var("HF_HOME") {
        let p = PathBuf::from(val).join("hub");
        if p.exists() {
            return p;
        }
    }

    // Common drive locations (Windows external drives / AI root)
    let candidates = [
        r"D:\AI\huggingface\hub",
        r"D:\huggingface\hub",
        r"E:\AI\huggingface\hub",
        r"C:\AI\huggingface\hub",
    ];

    for c in candidates {
        let p = PathBuf::from(c);
        if p.exists() {
            return p;
        }
    }

    if let Ok(userprofile) = env::var("USERPROFILE") {
        let p = PathBuf::from(userprofile).join(".cache").join("huggingface").join("hub");
        if p.exists() {
            return p;
        }
    }

    PathBuf::from(r"D:\AI\huggingface\hub")
}

fn find_embeddinggemma_models(hub_dir: &Path) -> (Option<PathBuf>, Option<PathBuf>) {
    if !hub_dir.exists() {
        return (None, None);
    }

    let candidate_dirs = [
        "models--unsloth--embeddinggemma-2-GGUF",
        "models--google--embeddinggemma-2",
        "models--FreedomAISVR--embeddinggemma-2-GGUF",
    ];

    for c in candidate_dirs {
        let model_dir = hub_dir.join(c).join("snapshots");
        if let Ok(entries) = std::fs::read_dir(&model_dir) {
            for entry in entries.flatten() {
                let snapshot = entry.path();
                if snapshot.is_dir() {
                    let mut found_model = None;
                    let mut found_mmproj = None;

                    // Preferred model names
                    let model_prefs = [
                        "embeddinggemma-2-BF16.gguf",
                        "embeddinggemma-2-Q8_0.gguf",
                        "embeddinggemma-2-UD-Q4_K_XL.gguf",
                        "embeddinggemma-2-F16.gguf",
                    ];
                    for name in model_prefs {
                        let mp = snapshot.join(name);
                        if mp.exists() {
                            found_model = Some(mp);
                            break;
                        }
                    }

                    let mmproj_prefs = [
                        "mmproj-F16.gguf",
                        "mmproj-BF16.gguf",
                        "mmproj-Q8_0.gguf",
                    ];
                    for name in mmproj_prefs {
                        let mp = snapshot.join(name);
                        if mp.exists() {
                            found_mmproj = Some(mp);
                            break;
                        }
                    }

                    if found_model.is_some() {
                        return (found_model, found_mmproj);
                    }
                }
            }
        }
    }

    (None, None)
}

fn find_llama_binary() -> Option<PathBuf> {
    if let Ok(val) = env::var("LLAMA_SERVER_BIN") {
        let p = PathBuf::from(val);
        if p.exists() {
            return Some(p);
        }
    }

    if let Ok(local_app) = env::var("LOCALAPPDATA") {
        let win_app_llama = PathBuf::from(local_app)
            .join("Microsoft")
            .join("WindowsApps")
            .join("llama.exe");
        if win_app_llama.exists() {
            return Some(win_app_llama);
        }
    }

    let candidates = [
        "llama.exe",
        "llama-server.exe",
        "llama",
        "llama-server",
    ];

    for c in candidates {
        if let Ok(path) = which(c) {
            return Some(path);
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
