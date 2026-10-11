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

    pub async fn is_running(server_url: &str) -> bool {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_millis(1500))
            .build()
            .unwrap_or_default();

        let health_url = format!("{}/health", server_url.trim_end_matches('/'));
        if let Ok(resp) = client.get(&health_url).send().await {
            if resp.status().is_success() {
                return true;
            }
        }

        let models_url = format!("{}/v1/models", server_url.trim_end_matches('/'));
        if let Ok(resp) = client.get(&models_url).send().await {
            if resp.status().is_success() {
                return true;
            }
        }

        false
    }

    pub async fn ensure_running(config: &RagConfig, repo_root: &Path) -> Result<(), String> {
        if Self::is_running(&config.server_url).await {
            println!("  [rag] Embedding server already responding at {}", config.server_url);
            return Ok(());
        }

        println!("  [rag] Starting EmbeddingGemma server on port {}...", config.server_port);

        let llama_bin = config.llama_bin.as_ref()
            .ok_or_else(|| "llama executable not found. Please install llama.exe or set LLAMA_SERVER_BIN.".to_string())?;

        let model_path = config.model_path.as_ref()
            .ok_or_else(|| format!("EmbeddingGemma GGUF model not found in {}", config.hf_hub_cache.display()))?;
        if let Err(err) = Self::verify_model_integrity(model_path) {
            eprintln!("  [rag:security] Model integrity verification failed: {}", err);
            return Err(err);
        }

        let pid_dir = repo_root.join(".agents").join("rag");
        let _ = fs::create_dir_all(&pid_dir);
        let pid_file = pid_dir.join("llama-server.pid");

        let mut cmd = Command::new(llama_bin);

        // Check if binary is unified llama.exe (uses `serve`) or llama-server
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
            .arg("--port").arg(config.server_port.to_string());

        // GPU / Metal layer offloading (defaults to 99 layers for full offload, 0 disables)
        let ngl = std::env::var("AINISH_RAG_NGL")
            .or_else(|_| std::env::var("LLAMA_GPU_LAYERS"))
            .unwrap_or_else(|_| "99".to_string());
        if ngl != "0" {
            cmd.arg("-ngl").arg(&ngl);
        }

        // FlashAttention flag (reduces memory and accelerates long context windows)
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

        let child = cmd.spawn()
            .map_err(|e| format!("Failed to spawn llama server: {}", e))?;

        let pid = child.id();
        let _ = fs::write(&pid_file, pid.to_string());

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(&pid_dir, fs::Permissions::from_mode(0o700));
            let _ = fs::set_permissions(&pid_file, fs::Permissions::from_mode(0o600));
        }
        println!("  [rag] Spawned llama server process PID {}...", pid);

        // Poll for readiness up to 30 seconds
        for i in 0..60 {
            sleep(Duration::from_millis(500)).await;
            if Self::is_running(&config.server_url).await {
                println!("  [rag] Embedding server healthy and ready at {}", config.server_url);
                return Ok(());
            }
            if i % 6 == 0 && i > 0 {
                println!("  [rag] Waiting for model to load into memory ({}s)...", i / 2);
            }
        }

        Err(format!("Embedding server failed to become ready at {} within 30s", config.server_url))
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
