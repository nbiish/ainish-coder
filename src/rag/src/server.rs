use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::fs;
use std::sync::Mutex;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;
use tokio::time::sleep;
use crate::config::RagConfig;

/// Repository whose embedding server this process spawned. Only the spawning process tears the
/// model down, so concurrent readers never kill a server another command is still using.
static EPHEMERAL_SERVER_ROOT: Mutex<Option<PathBuf>> = Mutex::new(None);

/// Set from `--keep-server` / `AINISH_RAG_KEEP_SERVER` (and implicitly by `serve` and by
/// `service status --warm`, whose whole purpose is a warm resident server).
static KEEP_SERVER: AtomicBool = AtomicBool::new(false);

pub struct LlamaServer;

impl LlamaServer {
    /// Records the operator's residency choice for this process.
    pub fn set_keep_server(keep: bool) {
        KEEP_SERVER.store(keep, Ordering::Relaxed);
    }

    pub fn keep_server_requested() -> bool {
        KEEP_SERVER.load(Ordering::Relaxed)
    }

    /// Guard that tears down any locally spawned embedding server when the process exits,
    /// including on error paths. Dropping it is always safe.
    pub fn ephemeral_guard(keep_server: bool) -> EphemeralServerGuard {
        EphemeralServerGuard { keep_server }
    }

    /// Records that this process spawned the local embedding server for `repo_root`.
    /// `cleanup_ephemeral` (called when the guard drops) tears it down again, releasing the
    /// model's multi-gigabyte resident footprint once the command has finished.
    pub fn mark_ephemeral(repo_root: &Path) {
        if let Ok(mut slot) = EPHEMERAL_SERVER_ROOT.lock() {
            *slot = Some(repo_root.to_path_buf());
        }
    }

    /// True when this process spawned the server and still owns its teardown.
    #[cfg(test)]
    pub fn owns_ephemeral() -> bool {
        EPHEMERAL_SERVER_ROOT
            .lock()
            .map(|slot| slot.is_some())
            .unwrap_or(false)
    }

    /// Stops the server only when this process spawned it. Safe to call unconditionally at exit.
    pub fn cleanup_ephemeral() {
        let root = EPHEMERAL_SERVER_ROOT
            .lock()
            .ok()
            .and_then(|mut slot| slot.take());
        if let Some(root) = root {
            let _ = Self::stop_quiet(&root);
        }
    }

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

    /// Detects the number of active git worktrees across the repository
    pub fn detect_active_worktrees(repo_root: &Path) -> usize {
        if let Ok(output) = Command::new("git").args(["worktree", "list", "--porcelain"]).current_dir(repo_root).output() {
            if let Ok(text) = String::from_utf8(output.stdout) {
                let count = text.lines().filter(|l| l.starts_with("worktree ")).count();
                if count > 0 {
                    return count;
                }
            }
        }
        1
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

    /// Default memory budget in MB when `--max-mem` is not configured. Kept in sync with the
    /// `mem_cap` displayed by `ainish-rag status`.
    pub fn default_mem_budget_mb() -> usize {
        2048
    }

    /// Multimodal llama asserts `ggml_can_mul_mat` when `n_ubatch` sits below 512, which is
    /// exactly what the worktree-divided budget produces (512 / 3 worktrees = 170). Keep the
    /// batch at or above this floor whenever an mmproj is loaded.
    pub const MIN_MULTIMODAL_BATCH: usize = 512;

    /// Raises the derived batch to the multimodal floor. Non-multimodal models keep the
    /// memory-budgeted value untouched.
    pub fn effective_batch(batch: usize, has_mmproj: bool) -> usize {
        if has_mmproj {
            batch.max(Self::MIN_MULTIMODAL_BATCH)
        } else {
            batch
        }
    }

    /// Resolves the GPU flag plan. `-ngl 0` must always be passed explicitly (omitting it leaves
    /// llama's GPU default in force), and CPU-only launches must not request `-fa on`: flash
    /// attention crashes some builds without a GPU backend.
    pub fn gpu_flag_plan(ngl: &str, flash_setting: &str) -> (String, bool) {
        let layers = ngl.trim().to_string();
        let flash = layers != "0"
            && !flash_setting.eq_ignore_ascii_case("off")
            && flash_setting.trim() != "0";
        (layers, flash)
    }

    /// Derives a KV-cache-safe `(ctx_size, batch_size)` for llama's `serve` from the operator's
    /// memory budget. The previous behaviour hardcoded 8192/8192, which drove resident memory to
    /// ~9.6GB regardless of `--max-mem`; sizing now tracks the budget so the cap is real.
    ///
    /// Explicit overrides (highest precedence): `AINISH_RAG_CTX` / `AINISH_RAG_BATCH`.
    pub fn derive_ctx_batch(max_mem_mb: Option<usize>, repo_root: &Path) -> (usize, usize) {
        if let Ok(v) = std::env::var("AINISH_RAG_CTX") {
            if let Ok(ctx) = v.trim().parse::<usize>() {
                if ctx > 0 {
                    let batch = std::env::var("AINISH_RAG_BATCH")
                        .ok()
                        .and_then(|b| b.trim().parse::<usize>().ok())
                        .filter(|b| *b > 0)
                        .unwrap_or_else(|| ctx.min(2048));
                    return (ctx, batch);
                }
            }
        }

        let budget = max_mem_mb.unwrap_or_else(Self::default_mem_budget_mb);
        let mut pair = if budget >= 16_000 {
            (8192, 4096)
        } else if budget >= 8_000 {
            (8192, 2048)
        } else if budget >= 4_000 {
            (4096, 1024)
        } else if budget >= 2_000 {
            (2048, 512)
        } else {
            (1024, 256)
        };

        // Multiple worktrees contend for the same host, so halve the batch to keep the
        // aggregate footprint inside the budget.
        let worktrees = Self::detect_active_worktrees(repo_root);
        if worktrees > 1 {
            pair = (pair.0, (pair.1 / worktrees).max(128));
        }
        pair
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

    /// Resolves the loopback session PSK (.agents/rag/session.psk), generating it from the OS CSPRNG
    /// when absent and rotating it once older than `ttl_secs`. Returns (psk, rotated).
    /// `AINISH_RAG_PSK` pins an operator-managed key and disables rotation.
    pub fn resolve_psk(rag_dir: &Path, ttl_secs: Option<u64>) -> Result<(String, bool), String> {
        if let Ok(val) = std::env::var("AINISH_RAG_PSK") {
            let clean = val.trim();
            if !clean.is_empty() {
                return Ok((clean.to_string(), false));
            }
        }
        let _ = fs::create_dir_all(rag_dir);
        let psk_path = rag_dir.join("session.psk");
        let mut existed = false;
        if let Ok(content) = fs::read_to_string(&psk_path) {
            let clean = content.trim();
            if clean.len() >= 32 {
                existed = true;
                let expired = match (ttl_secs, fs::metadata(&psk_path).and_then(|m| m.modified())) {
                    (Some(ttl), Ok(mtime)) => mtime.elapsed().map(|age| age.as_secs() >= ttl).unwrap_or(false),
                    _ => false,
                };
                if !expired {
                    return Ok((clean.to_string(), false));
                }
            }
        }
        let mut bytes = [0u8; 32];
        getrandom::getrandom(&mut bytes).map_err(|e| format!("OS CSPRNG unavailable for PSK generation: {}", e))?;
        let psk = hex::encode(bytes);
        fs::write(&psk_path, &psk).map_err(|e| format!("Failed to persist session PSK: {}", e))?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(&psk_path, fs::Permissions::from_mode(0o600));
        }
        Ok((psk, existed))
    }

    /// Builds llama-server NUMA / CPU affinity arguments from validated settings.
    /// affinity accepts a range ("0-7") -> --cpu-range, or a hex mask ("0xFF") -> --cpu-mask.
    pub fn numa_affinity_args(numa: Option<&str>, affinity: Option<&str>) -> Result<Vec<String>, String> {
        let mut args = Vec::new();
        if let Some(mode) = numa {
            match mode {
                "distribute" | "isolate" | "numactl" => { args.push("--numa".into()); args.push(mode.into()); }
                other => return Err(format!("Invalid --numa mode '{}': expected distribute|isolate|numactl", other)),
            }
        }
        if let Some(aff) = affinity {
            let aff = aff.trim();
            if let Some(hex_mask) = aff.strip_prefix("0x").or_else(|| aff.strip_prefix("0X")) {
                if hex_mask.is_empty() || hex_mask.len() > 32 || !hex_mask.chars().all(|c| c.is_ascii_hexdigit()) {
                    return Err(format!("Invalid --cpu-affinity mask '{}'", aff));
                }
                args.push("--cpu-mask".into()); args.push(hex_mask.to_string());
            } else if let Some((lo, hi)) = aff.split_once('-') {
                let lo: u32 = lo.trim().parse().map_err(|_| format!("Invalid --cpu-affinity range '{}'", aff))?;
                let hi: u32 = hi.trim().parse().map_err(|_| format!("Invalid --cpu-affinity range '{}'", aff))?;
                if lo > hi || hi > 4095 {
                    return Err(format!("Invalid --cpu-affinity range '{}'", aff));
                }
                args.push("--cpu-range".into()); args.push(format!("{}-{}", lo, hi));
            } else {
                return Err(format!("Invalid --cpu-affinity '{}': use a range like 0-7 or a hex mask like 0xFF", aff));
            }
            args.push("--cpu-strict".into()); args.push("1".into());
        }
        Ok(args)
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

    /// Prepares the embedding backend for one command.
    ///
    /// * Remote API provider: no llama process is spawned (zero resident model footprint). Any
    ///   leftover local server from an earlier run is reclaimed, and the endpoint is probed once
    ///   so a bad key/model fails here instead of halfway through an index.
    /// * Local provider: reuses a healthy server, or spawns one. Unless the operator asked to
    ///   keep it (`--keep-server` / `serve`), the spawned process is registered for teardown at
    ///   exit so the model is never left resident after its usage.
    pub async fn ensure_running(config: &RagConfig, repo_root: &Path) -> Result<(), String> {
        // Worktrees share the canonical repository's RAG state (PID, PSK, LanceDB, config).
        let canonical = crate::config::resolve_canonical_repo_root(repo_root);
        let repo_root: &Path = canonical.as_path();
        let ephemeral = !Self::keep_server_requested();

        // Vectors from different embedding models are not comparable: warn when the store was
        // built with a different provider than the one now in use.
        let identity = crate::provider::identity_for(
            &config.embed_provider,
            config.embed_provider_id.as_deref(),
            config.embed_model.as_deref(),
        );
        if let Some(warning) = crate::provider::index_mismatch_warning(repo_root, &identity) {
            eprintln!("  \x1b[33m[rag:index]\x1b[0m WARNING: {}", warning);
        }
        if config.embed_provider == "invalid" {
            let detail = if config.embed_warnings.is_empty() {
                "set AINISH_EMBED_API_BASE and AINISH_EMBED_MODEL, or run `ainish-rag embed-provider --provider local`".to_string()
            } else {
                config.embed_warnings.join("; ")
            };
            return Err(format!("Explicit API embedding intent is unusable: {}", detail));
        }

        // Remote API embedding provider: no local llama process is spawned at all, so a
        // multi-GB resident server never materializes.
        if config.uses_api_embeddings() {
            let provider = config.embed_provider_id.as_deref().unwrap_or("custom");
            println!(
                "  \x1b[36m[rag:embed-provider]\x1b[0m Using remote API embeddings via {} at {} (model {}, source: {}) — local llama server skipped",
                provider,
                config.embed_api_base.as_deref().unwrap_or_default(),
                config.embed_model.as_deref().unwrap_or_default(),
                config.embed_source
            );
            for warning in &config.embed_warnings {
                eprintln!("  \x1b[33m[rag:embed-provider]\x1b[0m {}", warning);
            }

            // Reclaim memory held by a local model spawned before the provider switched.
            if Self::reclaim_local_server(repo_root) {
                println!("  \x1b[36m[rag:memory]\x1b[0m Released the previously resident local embedding model");
            }

            if probe_enabled() {
                let timeout = probe_timeout();
                match crate::provider::probe(
                    config.embed_api_base.as_deref().unwrap_or_default(),
                    config.embed_model.as_deref().unwrap_or_default(),
                    config.embed_api_key.as_deref(),
                    timeout,
                )
                .await
                {
                    Ok(dim) => println!(
                        "  \x1b[32m[rag:embed-provider]\x1b[0m Remote embeddings verified ({} dims{})",
                        dim,
                        config
                            .embed_dim
                            .map(|d| format!(", stored at {}", d))
                            .unwrap_or_default()
                    ),
                    Err(err) => {
                        return Err(format!(
                            "{} — revert with `ainish-rag embed-provider --provider local` or set AINISH_EMBED_PROBE=0 to skip the probe",
                            err
                        ));
                    }
                }
            }
            return Ok(());
        }
        let pid_dir = repo_root.join(".agents").join("rag");
        let _ = fs::create_dir_all(&pid_dir);
        let pid_file = pid_dir.join("llama-server.pid");
        let psk = match config.psk.clone() {
            Some(p) => p,
            None => Self::resolve_psk(&pid_dir, config.psk_ttl)?.0,
        };
        let affinity_args = Self::numa_affinity_args(config.numa.as_deref(), config.cpu_affinity.as_deref())?;

        if Self::is_running(&config.server_url, Some(&psk)).await {
            println!("  [rag] Embedding server already responding at {}", config.server_url);
            return Ok(());
        }

        // A server we spawned earlier may still hold the port with a rotated-out PSK: retire it first.
        if pid_file.exists() {
            println!("  \x1b[33m[rag:security]\x1b[0m Retiring previous embedding server (stale or rotated PSK)...");
            let _ = Self::stop(repo_root);
            sleep(Duration::from_millis(750)).await;
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

            let worktrees = Self::detect_active_worktrees(repo_root);
            let (tuned_ctx, tuned_batch, tuned_threads) = if worktrees > 1 {
                let cpus = std::thread::available_parallelism().map(|n| n.get()).unwrap_or(4);
                let threads = (cpus / worktrees).max(2);
                println!("  \x1b[36m[rag:concurrency]\x1b[0m Detected {} active worktrees: auto-tuning thread allocation ({} threads) and batch scaling", worktrees, threads);
                let (ctx, batch) = Self::derive_ctx_batch(config.max_mem, repo_root);
                (ctx, batch, config.threads.unwrap_or(threads))
            } else {
                let (ctx, batch) = Self::derive_ctx_batch(config.max_mem, repo_root);
                (ctx, batch, config.threads.unwrap_or_else(|| std::thread::available_parallelism().map(|n| n.get()).unwrap_or(4)))
            };
            let tuned_batch = Self::effective_batch(tuned_batch, config.mmproj_path.is_some());
            println!(
                "  \x1b[36m[rag:memory]\x1b[0m Context/batch sized for {} MB budget: ctx={} batch={} (override with AINISH_RAG_CTX / AINISH_RAG_BATCH)",
                config.max_mem.unwrap_or_else(Self::default_mem_budget_mb),
                tuned_ctx,
                tuned_batch
            );

            cmd.arg("--embeddings")
                .arg("--pooling").arg("mean")
                .arg("--ctx-size").arg(tuned_ctx.to_string())
                .arg("--batch-size").arg(tuned_batch.to_string())
                .arg("--ubatch-size").arg(tuned_batch.to_string())
                .arg("--host").arg("127.0.0.1")
                .arg("--port").arg(config.server_port.to_string())
                .arg("--api-key").arg(&psk)
                .arg("--no-webui");

            let ngl = std::env::var("AINISH_RAG_NGL")
                .or_else(|_| std::env::var("LLAMA_GPU_LAYERS"))
                .unwrap_or_else(|_| "99".to_string());
            let flash_attn = std::env::var("AINISH_RAG_FLASH_ATTN")
                .unwrap_or_else(|_| "on".to_string());
            // Always pass the layer count, including 0: omitting the flag leaves llama's GPU
            // default in force, so `AINISH_RAG_NGL=0` never actually forced CPU.
            let (ngl_value, use_flash) = Self::gpu_flag_plan(&ngl, &flash_attn);
            cmd.arg("-ngl").arg(&ngl_value);
            if use_flash {
                cmd.arg("-fa").arg("on");
            }

            cmd.arg("--threads").arg(tuned_threads.to_string());
            cmd.args(&affinity_args);

            // Keep the child's stderr on disk: a load-time GGML assert is otherwise invisible
            // behind the null stdio handles and looks like an unexplained healthcheck timeout.
            let stderr_log = pid_dir.join("llama-server.err.log");
            let stderr_target = fs::File::create(&stderr_log).ok();
            cmd.stdin(Stdio::null()).stdout(Stdio::null());
            match stderr_target {
                Some(f) => { cmd.stderr(Stdio::from(f)); }
                None => { cmd.stderr(Stdio::null()); }
            }

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
                        if ephemeral {
                            Self::mark_ephemeral(repo_root);
                        }
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

        let log_hint = pid_dir.join("llama-server.err.log");
        Err(format!(
            "Embedding server failed to become ready at {} after {} attempts — hints: GPU-less hosts need AINISH_RAG_NGL=0 (this also disables -fa); multimodal models need batch/ubatch >= {} (the budget is floored automatically when an mmproj is loaded); raise --max-mem or set AINISH_RAG_CTX / AINISH_RAG_BATCH; llama's own stderr is in {}",
            config.server_url,
            max_retries,
            Self::MIN_MULTIMODAL_BATCH,
            log_hint.display()
        ))
    }

    /// Terminates a process tree. Best-effort: a recycled PID is still only signalled when the
    /// recorded process is alive at the time of the call.
    fn terminate(pid: u32) {
        #[cfg(target_os = "windows")]
        {
            let _ = Command::new("taskkill")
                .args(["/F", "/T", "/PID", &pid.to_string()])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .output();
        }

        #[cfg(not(target_os = "windows"))]
        {
            let _ = Command::new("kill")
                .args(["-9", &pid.to_string()])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .output();
        }
    }

    fn pid_alive(pid: u32) -> bool {
        #[cfg(target_os = "windows")]
        {
            let filter = format!("PID eq {}", pid);
            if let Ok(out) = Command::new("tasklist")
                .args(["/FI", &filter, "/NH"])
                .stdout(Stdio::piped())
                .stderr(Stdio::null())
                .output()
            {
                let text = String::from_utf8_lossy(&out.stdout);
                return text.contains(&pid.to_string());
            }
            false
        }
        #[cfg(not(target_os = "windows"))]
        {
            Command::new("kill")
                .args(["-0", &pid.to_string()])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status()
                .map(|s| s.success())
                .unwrap_or(false)
        }
    }

    /// True when a local embedding server recorded in the PID file is still alive.
    pub fn local_server_running(repo_root: &Path) -> bool {
        let canonical = crate::config::resolve_canonical_repo_root(repo_root);
        let pid_file = canonical.join(".agents").join("rag").join("llama-server.pid");
        let Ok(pid_str) = fs::read_to_string(&pid_file) else {
            return false;
        };
        pid_str.trim().parse::<u32>().map(Self::pid_alive).unwrap_or(false)
    }

    /// Stops a recorded server without human output. Returns true when a live process was torn
    /// down. Used for ephemeral teardown and for reclaiming a model after switching providers.
    pub fn stop_quiet(repo_root: &Path) -> bool {
        let canonical = crate::config::resolve_canonical_repo_root(repo_root);
        let pid_file = canonical.join(".agents").join("rag").join("llama-server.pid");
        let Ok(pid_str) = fs::read_to_string(&pid_file) else {
            return false;
        };
        let Ok(pid) = pid_str.trim().parse::<u32>() else {
            let _ = fs::remove_file(&pid_file);
            return false;
        };
        let alive = Self::pid_alive(pid);
        if alive {
            Self::terminate(pid);
        }
        let _ = fs::remove_file(&pid_file);
        alive
    }

    /// Reclaims a local embedding model left resident by an earlier run (e.g. before the
    /// operator switched to a remote API provider). Returns true when memory was released.
    pub fn reclaim_local_server(repo_root: &Path) -> bool {
        Self::stop_quiet(repo_root)
    }

    pub fn stop(repo_root: &Path) -> Result<(), String> {
        Self::stop_with_purge(repo_root, false)
    }

    /// Stops the local embedding server. `purge` also removes the loopback PSK material so no
    /// credential-bearing files are left behind.
    pub fn stop_with_purge(repo_root: &Path, purge: bool) -> Result<(), String> {
        let canonical = crate::config::resolve_canonical_repo_root(repo_root);
        let repo_root: &Path = canonical.as_path();
        let rag_dir = repo_root.join(".agents").join("rag");
        let pid_file = rag_dir.join("llama-server.pid");

        if !pid_file.exists() {
            println!("  [rag] No running server PID file found.");
        } else {
            let pid_str = fs::read_to_string(&pid_file)
                .map_err(|e| format!("Failed to read PID file: {}", e))?;
            let pid: u32 = pid_str.trim().parse()
                .map_err(|e| format!("Invalid PID in {}: {}", pid_file.display(), e))?;
            Self::terminate(pid);
            let _ = fs::remove_file(&pid_file);
            println!("  [rag] Stopped embedding server process PID {}.", pid);
        }

        // This process no longer owns a teardown for the server it may have spawned.
        if let Ok(mut slot) = EPHEMERAL_SERVER_ROOT.lock() {
            if slot.as_deref() == Some(repo_root) {
                *slot = None;
            }
        }

        if purge {
            for name in ["session.psk", "session.psk.meta"] {
                let path = rag_dir.join(name);
                if path.exists() {
                    fs::remove_file(&path)
                        .map_err(|e| format!("Failed to remove {}: {}", path.display(), e))?;
                }
            }
            println!("  [rag] Purged loopback PSK material from {}.", rag_dir.display());
        }
        Ok(())
    }
}

/// Tears down a locally spawned embedding server when the process exits. Dropping it on an
/// error path is what guarantees the model never outlives the command that loaded it.
pub struct EphemeralServerGuard {
    keep_server: bool,
}

impl Drop for EphemeralServerGuard {
    fn drop(&mut self) {
        if !self.keep_server {
            LlamaServer::cleanup_ephemeral();
        }
    }
}

/// Anti-DNS rebinding and IP-binding verification
pub struct AntiDnsRebinding;

impl AntiDnsRebinding {
    /// Validates that a Host or Origin header matches loopback interface and rejects non-loopback hosts
    pub fn validate_host(host_header: &str) -> Result<(), String> {
        let clean = host_header.trim();
        if clean.is_empty() {
            return Err("Empty Host header rejected for loopback security".to_string());
        }

        // Strip optional scheme
        let host_part = if let Some(stripped) = clean.strip_prefix("http://").or_else(|| clean.strip_prefix("https://")) {
            stripped
        } else {
            clean
        };

        // Split off port if present
        let hostname = if host_part.starts_with('[') {
            // IPv6 bracketed address: [::1]:8080 or [::1]
            if let Some(close_bracket) = host_part.find(']') {
                &host_part[1..close_bracket]
            } else {
                return Err(format!("Malformed IPv6 Host header: '{}'", clean));
            }
        } else if let Some((h, _port)) = host_part.split_once(':') {
            h
        } else {
            host_part
        };

        let h_lower = hostname.to_lowercase();
        if h_lower == "127.0.0.1" || h_lower == "localhost" || h_lower == "::1" || h_lower == "0:0:0:0:0:0:0:1" {
            Ok(())
        } else {
            Err(format!(
                "Anti-DNS rebinding violation: Host '{}' ({}) is not a permitted loopback address",
                clean, hostname
            ))
        }
    }

    /// Validates that an origin URL is strictly a loopback HTTP/HTTPS origin
    #[allow(dead_code)]
    pub fn validate_origin(origin: &str) -> Result<(), String> {
        let clean = origin.trim();
        if clean.is_empty() {
            return Ok(());
        }
        Self::validate_host(clean)
    }

    /// Constant-time comparison of loopback PSK tokens to prevent local timing side-channel probes
    pub fn verify_psk_constant_time(expected: &str, candidate: &str) -> bool {
        let a = expected.as_bytes();
        let b = candidate.as_bytes();
        let max_len = a.len().max(b.len());
        let mut diff: u8 = (a.len() ^ b.len()) as u8;
        for i in 0..max_len {
            let byte_a = *a.get(i).unwrap_or(&0);
            let byte_b = *b.get(i).unwrap_or(&0);
            diff |= byte_a ^ byte_b;
        }
        diff == 0 && !a.is_empty()
    }
}

/// Rate-limits failed loopback PSK authentication attempts to block brute-force / timing probes
pub struct PskAuthGuard {
    failed_attempts: std::sync::atomic::AtomicU32,
    max_attempts: u32,
}

impl PskAuthGuard {
    pub const fn new(max_attempts: u32) -> Self {
        Self {
            failed_attempts: std::sync::atomic::AtomicU32::new(0),
            max_attempts,
        }
    }

    pub fn verify(&self, expected: &str, candidate: &str) -> Result<(), String> {
        use std::sync::atomic::Ordering;
        let current_failures = self.failed_attempts.load(Ordering::SeqCst);
        if current_failures >= self.max_attempts {
            return Err(format!(
                "PSK authentication locked out: exceeded maximum failed attempts ({})",
                self.max_attempts
            ));
        }
        if AntiDnsRebinding::verify_psk_constant_time(expected, candidate) {
            self.failed_attempts.store(0, Ordering::SeqCst);
            Ok(())
        } else {
            let failures = self.failed_attempts.fetch_add(1, Ordering::SeqCst) + 1;
            std::thread::sleep(Duration::from_millis((failures as u64) * 25));
            Err(format!("Invalid loopback PSK token (failed attempt {}/{})", failures, self.max_attempts))
        }
    }
}

/// Remote embedding probe is on by default so a bad key/model fails at startup, not mid-index.
fn probe_enabled() -> bool {
    match std::env::var("AINISH_EMBED_PROBE").ok().as_deref().map(str::trim) {
        Some("0") | Some("false") | Some("off") | Some("no") => false,
        _ => true,
    }
}

fn probe_timeout() -> Duration {
    let ms = std::env::var("AINISH_EMBED_PROBE_TIMEOUT_MS")
        .ok()
        .and_then(|v| v.trim().parse::<u64>().ok())
        .unwrap_or(8_000)
        .clamp(500, 60_000);
    Duration::from_millis(ms)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_anti_dns_rebinding_allows_loopback() {
        assert!(AntiDnsRebinding::validate_host("127.0.0.1").is_ok());
        assert!(AntiDnsRebinding::validate_host("127.0.0.1:8080").is_ok());
        assert!(AntiDnsRebinding::validate_host("localhost").is_ok());
        assert!(AntiDnsRebinding::validate_host("localhost:8080").is_ok());
        assert!(AntiDnsRebinding::validate_host("[::1]").is_ok());
        assert!(AntiDnsRebinding::validate_host("[::1]:8080").is_ok());
        assert!(AntiDnsRebinding::validate_host("http://127.0.0.1:8080").is_ok());
    }

    #[test]
    fn test_anti_dns_rebinding_rejects_external_hosts() {
        assert!(AntiDnsRebinding::validate_host("attacker.com").is_err());
        assert!(AntiDnsRebinding::validate_host("evil.com:8080").is_err());
        assert!(AntiDnsRebinding::validate_host("192.168.1.1").is_err());
        assert!(AntiDnsRebinding::validate_host("10.0.0.1").is_err());
        assert!(AntiDnsRebinding::validate_host("0.0.0.0").is_err());
        assert!(AntiDnsRebinding::validate_host("http://attacker.com").is_err());
    }

    #[test]
    fn test_constant_time_psk_and_rate_limiting() {
        let secret = "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90";
        assert!(AntiDnsRebinding::verify_psk_constant_time(secret, secret));
        assert!(!AntiDnsRebinding::verify_psk_constant_time(secret, "wrong_token"));
        assert!(!AntiDnsRebinding::verify_psk_constant_time("", ""));

        let guard = PskAuthGuard::new(2);
        assert!(guard.verify(secret, "bad1").is_err());
        assert!(guard.verify(secret, "bad2").is_err());
        // 3rd attempt should be locked out even with valid secret
        assert!(guard.verify(secret, secret).is_err());
    }

    #[test]
    fn test_derive_ctx_batch_respects_memory_budget() {
        // The old behaviour hardcoded ctx=8192/batch=8192 regardless of --max-mem, which drove
        // resident memory to ~9.6GB. The default 2048 MB budget must now yield a small pair.
        let (ctx, batch) = LlamaServer::derive_ctx_batch(None, std::path::Path::new("."));
        assert_eq!(ctx, 2048, "default 2048MB budget must use 2048 ctx");
        assert!(batch <= 512, "default budget must keep batch small, got {}", batch);

        // A generous budget scales up, but batch never exceeds ctx.
        let (big_ctx, big_batch) = LlamaServer::derive_ctx_batch(Some(32_000), std::path::Path::new("."));
        assert_eq!(big_ctx, 8192);
        assert!(big_batch <= big_ctx);

        // A tight budget scales down.
        let (small_ctx, small_batch) = LlamaServer::derive_ctx_batch(Some(1024), std::path::Path::new("."));
        assert!(small_ctx <= 1024);
        assert!(small_batch <= 256);

        // Explicit operator override wins over any budget. (env mutation is process-global,
        // hence the unsafe block required by this Rust edition.)
        unsafe { std::env::set_var("AINISH_RAG_CTX", "4096") };
        let (ov_ctx, ov_batch) = LlamaServer::derive_ctx_batch(Some(512), std::path::Path::new("."));
        assert_eq!(ov_ctx, 4096);
        assert!(ov_batch <= 4096);
        unsafe { std::env::remove_var("AINISH_RAG_CTX") };
    }

    #[test]
    fn test_ephemeral_ownership_is_process_scoped() {
        let dir = std::env::temp_dir().join(format!("ainish-ephemeral-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(dir.join(".agents").join("rag")).unwrap();

        // Nothing spawned yet: no teardown ownership and cleanup is a no-op.
        assert!(!LlamaServer::owns_ephemeral());
        LlamaServer::cleanup_ephemeral();

        LlamaServer::mark_ephemeral(&dir);
        assert!(LlamaServer::owns_ephemeral());

        // Cleanup clears ownership even when no PID file exists (server already exited).
        LlamaServer::cleanup_ephemeral();
        assert!(!LlamaServer::owns_ephemeral());

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_stop_with_purge_removes_psk_material() {
        let dir = std::env::temp_dir().join(format!("ainish-purge-{}", std::process::id()));
        let rag_dir = dir.join(".agents").join("rag");
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&rag_dir).unwrap();
        std::fs::write(rag_dir.join("session.psk"), "deadbeef").unwrap();
        std::fs::write(rag_dir.join("session.psk.meta"), "{}").unwrap();

        LlamaServer::stop_with_purge(&dir, true).unwrap();

        assert!(!rag_dir.join("session.psk").exists());
        assert!(!rag_dir.join("session.psk.meta").exists());
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_multimodal_batch_floor() {
        // 512 / 3 worktrees = 170 was the exact value that crashed the mmproj load.
        assert_eq!(LlamaServer::effective_batch(170, true), 512);
        assert_eq!(LlamaServer::effective_batch(170, false), 170);
        assert_eq!(LlamaServer::effective_batch(1024, true), 1024);
    }

    #[test]
    fn test_gpu_flag_plan_pins_cpu_and_drops_flash_attention() {
        assert_eq!(LlamaServer::gpu_flag_plan("0", "on"), ("0".to_string(), false));
        assert_eq!(LlamaServer::gpu_flag_plan(" 0 ", "on"), ("0".to_string(), false));
        assert_eq!(LlamaServer::gpu_flag_plan("99", "on"), ("99".to_string(), true));
        assert_eq!(LlamaServer::gpu_flag_plan("99", "off"), ("99".to_string(), false));
    }
}
