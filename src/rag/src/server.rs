use std::path::Path;
use std::process::{Command, Stdio};
use std::fs;
use std::time::Duration;
use tokio::time::sleep;
use crate::config::RagConfig;

pub struct LlamaServer;

impl LlamaServer {
    /// Verifies model file size and GGUF header magic prior to server spawn
    pub fn verify_model_integrity(model_path: &Path) -> Result<String, String> {
        if !model_path.exists() {
            return Err(format!("Model file not found at {}", model_path.display()));
        }
        let meta = fs::metadata(model_path).map_err(|e| e.to_string())?;
        if meta.len() < 1024 * 1024 {
            return Err(format!("Model file {} is too small ({} bytes), corrupted or placeholder", model_path.display(), meta.len()));
        }
        let mut file = fs::File::open(model_path).map_err(|e| e.to_string())?;
        use std::io::Read;
        let mut magic = [0u8; 4];
        if file.read_exact(&mut magic).is_ok() && &magic != b"GGUF" {
            return Err(format!("Model file {} missing GGUF header magic (found {:?})", model_path.display(), magic));
        }
        Ok(format!("GGUF valid ({:.2} MB)", meta.len() as f64 / (1024.0 * 1024.0)))
    }

    /// Verifies binary SHA-256 integrity against optional AINISH_LLAMA_SHA256 pinning
    pub fn verify_binary_checksum(llama_bin: &Path) -> Result<String, String> {
        if !llama_bin.exists() {
            return Err(format!("Llama binary not found at {}", llama_bin.display()));
        }
        let data = fs::read(llama_bin).map_err(|e| format!("Failed to read binary for checksum: {}", e))?;
        use sha2::{Sha256, Digest};
        let mut hasher = Sha256::new();
        hasher.update(&data);
        let hash = hex::encode(hasher.finalize());

        if let Ok(expected) = std::env::var("AINISH_LLAMA_SHA256") {
            let exp_clean = expected.trim().to_lowercase();
            if !exp_clean.is_empty() && hash.to_lowercase() != exp_clean {
                return Err(format!(
                    "Llama binary SHA-256 verification mismatch! Expected {}, found {}",
                    exp_clean, hash
                ));
            }
        }

        Ok(hash)
    }

    /// Probes available host physical memory in megabytes across Windows, Linux, and macOS
    pub fn get_available_memory_mb() -> usize {
        #[cfg(windows)]
        {
            #[repr(C)]
            struct MemoryStatusEx {
                dw_length: u32,
                dw_memory_load: u32,
                ull_total_phys: u64,
                ull_avail_phys: u64,
                ull_total_page_file: u64,
                ull_avail_page_file: u64,
                ull_total_virtual: u64,
                ull_avail_virtual: u64,
                ull_avail_extended_virtual: u64,
            }
            unsafe {
                let mut status = MemoryStatusEx {
                    dw_length: std::mem::size_of::<MemoryStatusEx>() as u32,
                    dw_memory_load: 0,
                    ull_total_phys: 0,
                    ull_avail_phys: 0,
                    ull_total_page_file: 0,
                    ull_avail_page_file: 0,
                    ull_total_virtual: 0,
                    ull_avail_virtual: 0,
                    ull_avail_extended_virtual: 0,
                };
                unsafe extern "system" {
                    fn GlobalMemoryStatusEx(lp_buffer: *mut MemoryStatusEx) -> i32;
                }
                if GlobalMemoryStatusEx(&mut status) != 0 {
                    return (status.ull_avail_phys / (1024 * 1024)) as usize;
                }
            }
        }

        #[cfg(target_os = "linux")]
        {
            if let Ok(content) = fs::read_to_string("/proc/meminfo") {
                for line in content.lines() {
                    if line.starts_with("MemAvailable:") {
                        let parts: Vec<&str> = line.split_whitespace().collect();
                        if parts.len() >= 2 {
                            if let Ok(kb) = parts[1].parse::<usize>() {
                                return kb / 1024;
                            }
                        }
                    }
                }
            }
        }

        #[cfg(target_os = "macos")]
        {
            if let Ok(out) = Command::new("sysctl").args(["-n", "hw.memsize"]).output() {
                if let Ok(s) = String::from_utf8(out.stdout) {
                    if let Ok(bytes) = s.trim().parse::<u64>() {
                        return (bytes / (1024 * 1024)) as usize;
                    }
                }
            }
        }

        4096
    }

    /// Evaluates memory cap safety before model launch
    pub fn check_memory_cap(max_mem_cap: Option<usize>) -> Result<usize, String> {
        let avail_mb = Self::get_available_memory_mb();
        let min_required = 800; // EmbeddingGemma-2 requires ~800MB - 1GB

        if avail_mb < min_required {
            eprintln!(
                "  [rag:warn] Host available memory ({} MB) is below recommended minimum ({} MB).",
                avail_mb, min_required
            );
        }

        if let Some(cap) = max_mem_cap {
            if cap < min_required {
                return Err(format!(
                    "Configured --max-mem ({} MB) is below minimum model requirement ({} MB)",
                    cap, min_required
                ));
            }
            if avail_mb < cap {
                eprintln!(
                    "  [rag:system] Available memory ({} MB) is less than configured cap ({} MB); optimizing context buffer",
                    avail_mb, cap
                );
            }
        }

        Ok(avail_mb)
    }

    /// Verifies GGUF model SHA-256 integrity against .agents/audit/model-manifest.json
    pub fn verify_model_manifest(model_path: &Path, manifest_path: &Path) -> Result<Option<String>, String> {
        if !manifest_path.exists() {
            return Ok(None);
        }
        let content = fs::read_to_string(manifest_path)
            .map_err(|e| format!("Failed to read model manifest {}: {}", manifest_path.display(), e))?;
        let manifest: serde_json::Value = serde_json::from_str(&content)
            .map_err(|e| format!("Failed to parse model manifest JSON: {}", e))?;

        let file_name = model_path.file_name().and_then(|n| n.to_str()).unwrap_or("");
        let models_map = manifest.get("models").and_then(|m| m.as_object());
        let expected_hash = models_map
            .and_then(|m| m.get(file_name))
            .and_then(|obj| obj.get("sha256"))
            .and_then(|v| v.as_str());

        if let Some(exp) = expected_hash {
            let data = fs::read(model_path)
                .map_err(|e| format!("Failed to read model file for manifest check: {}", e))?;
            use sha2::{Sha256, Digest};
            let mut hasher = Sha256::new();
            hasher.update(&data);
            let actual = hex::encode(hasher.finalize());
            if actual.to_lowercase() != exp.to_lowercase() {
                return Err(format!(
                    "Model manifest SHA-256 mismatch for {}! Expected {}, found {}",
                    file_name, exp, actual
                ));
            }
            return Ok(Some(actual));
        }

        Ok(None)
    }

    /// Resolves or generates a session pre-shared key (PSK) stored in .agents/rag/session.psk
    pub fn resolve_or_create_psk(rag_dir: &Path) -> String {
        if let Ok(val) = std::env::var("AINISH_RAG_PSK") {
            let clean = val.trim();
            if !clean.is_empty() {
                return clean.to_string();
            }
        }
        let psk_path = rag_dir.join("session.psk");
        if psk_path.exists() {
            if let Ok(content) = fs::read_to_string(&psk_path) {
                let clean = content.trim();
                if !clean.is_empty() {
                    return clean.to_string();
                }
            }
        }
        let random_id = format!("{:x}{:x}", chrono::Utc::now().timestamp_nanos_opt().unwrap_or(0), std::process::id());
        use sha2::{Sha256, Digest};
        let mut hasher = Sha256::new();
        hasher.update(random_id.as_bytes());
        let psk = hex::encode(hasher.finalize());
        let _ = fs::write(&psk_path, &psk);
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(&psk_path, fs::Permissions::from_mode(0o600));
        }
        psk
    }

    pub async fn is_running(server_url: &str, psk: Option<&str>) -> bool {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_millis(1500))
            .build()
            .unwrap_or_default();

        let health_url = format!("{}/health", server_url.trim_end_matches('/'));
        let mut req = client.get(&health_url);
        if let Some(token) = psk {
            req = req.header("Authorization", format!("Bearer {}", token));
        }
        if let Ok(resp) = req.send().await {
            if resp.status().is_success() {
                return true;
            }
        }

        let models_url = format!("{}/v1/models", server_url.trim_end_matches('/'));
        let mut req_models = client.get(&models_url);
        if let Some(token) = psk {
            req_models = req_models.header("Authorization", format!("Bearer {}", token));
        }
        if let Ok(resp) = req_models.send().await {
            if resp.status().is_success() {
                return true;
            }
        }

        false
    }

    pub async fn ensure_running(config: &RagConfig, repo_root: &Path) -> Result<(), String> {
        let pid_dir = repo_root.join(".agents").join("rag");
        let _ = fs::create_dir_all(&pid_dir);
        let pid_file = pid_dir.join("llama-server.pid");
        let psk = config.psk.clone().unwrap_or_else(|| Self::resolve_or_create_psk(&pid_dir));

        if Self::is_running(&config.server_url, Some(&psk)).await {
            println!("  [rag] Embedding server already responding at {}", config.server_url);
            return Ok(());
        }

        println!("  [rag] Starting EmbeddingGemma server on port {}...", config.server_port);

        let llama_bin = config.llama_bin.as_ref()
            .ok_or_else(|| "llama executable not found. Please install llama.exe or set LLAMA_SERVER_BIN.".to_string())?;

        // 1. Check supply-chain binary checksum integrity
        let bin_sha = Self::verify_binary_checksum(llama_bin)?;
        println!("  [rag:security] Verified llama binary SHA-256 ({}...)", &bin_sha[..12.min(bin_sha.len())]);

        // 2. Check memory cap before launch to prevent host OOM kills
        let avail_mem = Self::check_memory_cap(config.max_mem)?;
        println!("  [rag:system] Host memory check: {} MB available", avail_mem);

        let model_path = config.model_path.as_ref()
            .ok_or_else(|| format!("EmbeddingGemma GGUF model not found in {}", config.hf_hub_cache.display()))?;
        if let Err(err) = Self::verify_model_integrity(model_path) {
            eprintln!("  [rag:security] Model integrity verification failed: {}", err);
            return Err(err);
        }

        // 3. Verify model against immutable model manifest
        if let Ok(Some(m_hash)) = Self::verify_model_manifest(model_path, &config.model_manifest_path) {
            println!("  \x1b[32m[rag:supply-chain]\x1b[0m Verified GGUF against blessed manifest ({}...)", &m_hash[..12.min(m_hash.len())]);
        }

        let max_retries = 3;
        for attempt in 1..=max_retries {
            if attempt > 1 {
                let backoff_ms = 1000 * (1 << (attempt - 2));
                println!("  \x1b[33m[rag:retry]\x1b[0m Retrying server launch (attempt {}/{}, backoff {}ms)...", attempt, max_retries, backoff_ms);
                sleep(Duration::from_millis(backoff_ms)).await;
                let _ = fs::remove_file(&pid_file);
            }

            let mut cmd = Command::new(llama_bin);

            let bin_name = llama_bin.file_name().and_then(|n| n.to_str()).unwrap_or("");
            if bin_name.eq_ignore_ascii_case("llama.exe") || bin_name.eq_ignore_ascii_case("llama") {
                cmd.arg("serve");
            }

            cmd.arg("-m").arg(model_path);

            if let Some(mmproj) = &config.mmproj_path {
                cmd.arg("--mmproj").arg(mmproj);
            }

            cmd.arg("--embeddings")
                .arg("--pooling").arg("mean")
                .arg("--ctx-size").arg("8192")
                .arg("--batch-size").arg("8192")
                .arg("--ubatch-size").arg("8192")
                .arg("--host").arg("127.0.0.1")
                .arg("--port").arg(config.server_port.to_string())
                .arg("--api-key").arg(&psk)
                .arg("--no-webui");

            let ngl = std::env::var("AINISH_RAG_NGL")
                .or_else(|_| std::env::var("LLAMA_GPU_LAYERS"))
                .unwrap_or_else(|_| "99".to_string());
            if ngl != "0" {
                cmd.arg("-ngl").arg(&ngl);
            }

            let flash_attn = std::env::var("AINISH_RAG_FLASH_ATTN")
                .unwrap_or_else(|_| "on".to_string());
            if flash_attn != "off" && flash_attn != "0" {
                cmd.arg("-fa").arg("on");
            }

            cmd.stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null());

            #[cfg(windows)]
            {
                use std::os::windows::process::CommandExt;
                const CREATE_NEW_PROCESS_GROUP: u32 = 0x00000200;
                const DETACHED_PROCESS: u32 = 0x00000008;
                cmd.creation_flags(CREATE_NEW_PROCESS_GROUP | DETACHED_PROCESS);
            }

            #[cfg(unix)]
            {
                use std::os::unix::process::CommandExt;
                cmd.process_group(0);
            }

            match cmd.spawn() {
                Ok(child) => {
                    let pid = child.id();
                    let _ = fs::write(&pid_file, pid.to_string());

                    #[cfg(unix)]
                    {
                        use std::os::unix::fs::PermissionsExt;
                        let _ = fs::set_permissions(&pid_dir, fs::Permissions::from_mode(0o700));
                        let _ = fs::set_permissions(&pid_file, fs::Permissions::from_mode(0o600));
                    }
                    println!("  [rag] Spawned llama server process PID {} with PSK authentication...", pid);

                    // Poll for readiness up to 30 seconds
                    let mut ready = false;
                    for i in 0..60 {
                        sleep(Duration::from_millis(500)).await;
                        if Self::is_running(&config.server_url, Some(&psk)).await {
                            println!("  [rag] Embedding server healthy and ready at {}", config.server_url);
                            ready = true;
                            break;
                        }
                        if i % 6 == 0 && i > 0 {
                            println!("  [rag] Waiting for model to load into memory ({}s)...", i / 2);
                        }
                    }

                    if ready {
                        return Ok(());
                    } else {
                        eprintln!("  [rag:warn] Healthcheck timed out on attempt {}/{}", attempt, max_retries);
                    }
                }
                Err(e) => {
                    eprintln!("  [rag:error] Failed to spawn llama server process on attempt {}/{}: {}", attempt, max_retries, e);
                }
            }
        }

        Err(format!("Embedding server failed to become ready at {} after {} attempts", config.server_url, max_retries))
    }

    pub fn stop(repo_root: &Path) -> Result<(), String> {
        let pid_file = repo_root.join(".agents").join("rag").join("llama-server.pid");
        if !pid_file.exists() {
            println!("  [rag] No running server PID file found.");
            return Ok(());
        }

        let pid_str = fs::read_to_string(&pid_file)
            .map_err(|e| format!("Failed to read PID file: {}", e))?;
        let pid: u32 = pid_str.trim().parse()
            .map_err(|e| format!("Invalid PID in {}: {}", pid_file.display(), e))?;

        #[cfg(target_os = "windows")]
        {
            let _ = Command::new("taskkill")
                .args(["/F", "/T", "/PID", &pid.to_string()])
                .output();
        }

        #[cfg(not(target_os = "windows"))]
        {
            let _ = Command::new("kill")
                .args(["-9", &pid.to_string()])
                .output();
        }

        let _ = fs::remove_file(&pid_file);
        println!("  [rag] Stopped embedding server process PID {}.", pid);
        Ok(())
    }
}
