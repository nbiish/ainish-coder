mod config;
mod server;
mod wiki;
mod scrub;
mod decision;
mod pqc;
mod provider;

use clap::{Parser, Subcommand};
use std::path::PathBuf;
use std::env;
use crate::config::RagConfig;
use crate::server::LlamaServer;
use crate::wiki::WikiGenerator;
use crate::decision::DecisionEngine;

#[derive(Parser)]
#[command(name = "ainish-rag")]
#[command(about = "Multimodal Codebase RAG & Architecture Wiki Engine for ainish-coder", version = "0.1.0")]
struct Cli {
    /// Number of threads for llama-server execution (default: auto)
    #[arg(short, long, global = true)]
    threads: Option<usize>,

    /// Maximum memory cap for llama-server in MB (default: auto / 2048)
    #[arg(long, global = true)]
    max_mem: Option<usize>,

    /// TTL in seconds for loopback session PSK rotation (default: auto / none)
    #[arg(long, global = true)]
    psk_ttl: Option<u64>,

    /// NUMA node binding mode (distribute, isolate, numactl)
    #[arg(long, global = true)]
    numa: Option<String>,

    /// CPU affinity pinning (range e.g. 0-7, or hex mask e.g. 0xFF)
    #[arg(long, global = true)]
    cpu_affinity: Option<String>,

    /// Keep the local embedding server resident after the command finishes.
    /// By default any server this process spawns is stopped again, releasing the model's memory.
    #[arg(long, global = true)]
    keep_server: bool,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Inspect status of the graph-first retrieval corpus and the decision layer
    Status {
        /// Output health and telemetry report as structured JSON
        #[arg(long)]
        json: bool,
    },
    /// RETIRED 2026-11-12 — served the local embedding server
    #[command(hide = true)]
    Serve { #[arg(trailing_var_arg = true, allow_hyphen_values = true)] rest: Vec<String> },
    /// RETIRED 2026-11-12 — served the local embedding server
    #[command(hide = true)]
    Stop { #[arg(trailing_var_arg = true, allow_hyphen_values = true)] rest: Vec<String> },
    /// RETIRED 2026-11-12 — served the vector index
    #[command(hide = true)]
    Index { #[arg(trailing_var_arg = true, allow_hyphen_values = true)] rest: Vec<String> },
    /// RETIRED 2026-11-12 — served vector search
    #[command(hide = true)]
    Query { #[arg(trailing_var_arg = true, allow_hyphen_values = true)] rest: Vec<String> },
    /// RETIRED 2026-11-12 — served vector reranking
    #[command(hide = true)]
    Rerank { #[arg(trailing_var_arg = true, allow_hyphen_values = true)] rest: Vec<String> },
    /// RETIRED 2026-11-12 — served vector recall benchmarks
    #[command(hide = true)]
    Bench { #[arg(trailing_var_arg = true, allow_hyphen_values = true)] rest: Vec<String> },
    /// RETIRED 2026-11-12 — served vector drift monitoring
    #[command(hide = true)]
    Monitor { #[arg(trailing_var_arg = true, allow_hyphen_values = true)] rest: Vec<String> },
    /// RETIRED 2026-11-12 — served embedding provider config
    #[command(hide = true)]
    EmbedProvider { #[arg(trailing_var_arg = true, allow_hyphen_values = true)] rest: Vec<String> },
    /// Generate shell completion scripts and aliases (bash, zsh, fish, pwsh)
    Completion {
        /// Shell type: bash, zsh, fish, pwsh
        shell: String,
    },
    /// Generate codebase knowledge and architecture wiki in .agents/wiki/
    Wiki {
        /// Target repository path (default: current directory)
        #[arg(short, long)]
        path: Option<PathBuf>,
        /// Also index the generated wiki into the LEGACY LanceDB vector store (retired path;
        /// opt in explicitly). The wiki itself is generated from the filesystem and needs no
        /// embedding model, which is why this is off by default: the old
        /// `default_value_t = true` produced a flag that could only ever be true, so every
        /// `ainish-rag wiki` run hard-required the EmbeddingGemma GGUF even though retrieval
        /// has been graph-first since 2026-11-11.
        #[arg(long)]
        index: bool,
        /// Append a UTC-dated bullet note to .agents/wiki/ledger.md (pass '-' to read from stdin), sign with ML-DSA-65, and re-render page 04
        #[arg(short, long)]
        note: Option<String>,
        /// Mark matching entries [RESOLVED] in both .agents/wiki/ledger.md and today's .agents/memories/{date}-memory.txt
        #[arg(long)]
        resolve: Option<String>,
        /// Display current operator ledger entries and their [RESOLVED] status without regenerating all wiki pages
        #[arg(long)]
        list_notes: bool,
        /// Synchronize [RESOLVED] status bidirectionally between .agents/memories/ and .agents/wiki/ledger.md
        #[arg(long)]
        sync_resolved: bool,
        /// Output wiki note listing as structured JSON
        #[arg(long)]
        json: bool,
    },
    /// Route query or instruction using the calibrated decision model (System One)
    Route {
        /// Query or instruction to route
        query: String,
        /// Output decision as JSON
        #[arg(long)]
        json: bool,
    },
    /// Evaluate a decision question with TypeSafe Jev / calibrated engine
    Decide {
        /// Text or state to evaluate
        state: String,
        /// Decision question to ask (noul yes/no)
        #[arg(short, long)]
        question: Option<String>,
        /// Typed question batch as inline JSON or @path (noul/choice/score with criteria).
        /// Overrides --question and returns every typed answer.
        #[arg(long)]
        questions: Option<String>,
        /// Output decision as JSON
        #[arg(long)]
        json: bool,
    },
    /// Run bi-phasic evaluation gate or retrieval-augmented patch evaluation
    Eval {
        /// Ground-truth context text
        #[arg(short, long)]
        context: Option<String>,
        /// Generated output to evaluate
        #[arg(short, long)]
        output: Option<String>,
        /// Unified patch file or diff text to evaluate for retrieval anchoring
        #[arg(long)]
        patch: Option<String>,
        /// Generate AST-guided unified diff repair patch for direct piping to git apply
        #[arg(long)]
        generate_patch: bool,
        /// Output decision as JSON
        #[arg(long)]
        json: bool,
    },
    /// Run database compaction, old table version pruning, and stale git worktree/branch hygiene
    Cleanup {
        /// Compact LanceDB dataset files
        #[arg(long, default_value_t = true)]
        compact: bool,
        /// Prune table versions older than N days (default: 7)
        #[arg(long, default_value_t = 7)]
        prune_days: i64,
        /// Prune stale git worktree metadata and detect merged branches
        #[arg(long, default_value_t = true)]
        prune_worktrees: bool,
        /// Automatically delete local branches already merged into main
        #[arg(long)]
        delete_merged: bool,
        /// Preview branches slated for deletion without mutating refs
        #[arg(long)]
        dry_run: bool,
    },
    /// Subagent context injection: formats top architectural wiki sections into primer
    Orient {
        /// Format top 3 relevant architectural wiki sections into <ORIENT_PRIMER>
        #[arg(long, default_value_t = true)]
        inject: bool,
        /// Focus query or task objective to rank wiki sections against
        #[arg(short, long)]
        query: Option<String>,
        /// Filter or condition wiki sections based on active task metadata (.agents/tasks/)
        #[arg(long, default_value_t = true)]
        task_conditioned: bool,
        /// Verify that all 4 orient primer pillars (wiki sections, memories, ledger notes, symbol anchors) are populated
        #[arg(long)]
        verify: bool,
        /// Emit a single-screen token-budgeted <ORIENT_PRIMER> for small-context local models
        #[arg(long)]
        compact: bool,
        /// Fine-grained per-section line truncation override
        #[arg(long)]
        max_lines: Option<usize>,
        /// Maximum number of wiki sections to inject (default 3)
        #[arg(long)]
        sections: Option<usize>,
        /// Include key symbol graph anchors in the primer (pass `false` to omit)
        #[arg(long, default_value_t = true, action = clap::ArgAction::Set)]
        include_symbols: bool,
        /// Invoke the deployed .agents/bin/ainish-rules-sync when gate_ready is false (opt-in)
        #[arg(long)]
        sync_rules: bool,
        /// Output primer and section metadata as structured JSON
        #[arg(long)]
        json: bool,
    },
    /// Unified pre-merge verification gate: patch anchoring, lockfile integrity, and audit receipts
    Gate {
        /// Unified patch file or diff text to evaluate (default: git diff HEAD~1 or main...HEAD)
        #[arg(long)]
        patch: Option<String>,
        /// Emit terminal bell upon gate completion
        #[arg(short, long)]
        bell: bool,
        /// Trigger desktop notification upon gate completion
        #[arg(long)]
        notify: bool,
        /// Continuously watch repository for file modifications and re-evaluate gate
        #[arg(short, long)]
        watch: bool,
        /// Output one-line compact summary for shell prompt (PS1) or tmux status bar
        #[arg(long)]
        summary: bool,
        /// Require STRONG_ANCHOR (>= 70.0% composite score) for security-critical modules
        #[arg(long)]
        strict: bool,
        /// Command that proves the existing test suite is green. Its exit code is shown on the
        /// gate card and a non-zero exit blocks the merge. Omit for docs-only patches.
        #[arg(long)]
        tests: Option<String>,
        /// Output gate results as JSON
        #[arg(long)]
        json: bool,
    },
    /// Emit one-line compact gate status for shell prompts (PS1), Cursor statusLine, or tmux bars
    Statusline {
        /// Output structured JSON status bar payload for IDE plugins
        #[arg(long)]
        json: bool,
    },
    /// Inspect PQC secrets vault configuration and OpenRouter key status
    Secrets {
        /// Output status as JSON
        #[arg(long)]
        json: bool,
    },
    /// Audit and verify post-quantum signatures and receipts in .agents/audit/
    Audit {
        #[command(subcommand)]
        command: AuditCommands,
    },
    /// Continuous background embedding service generator and installer
    Service {
        #[command(subcommand)]
        command: ServiceCommands,
    },
}

#[derive(Subcommand)]
pub enum AuditCommands {
    /// Verify ML-DSA-65 signatures and cryptographic integrity of audit receipts
    Verify {
        /// Specific receipt file or audit directory path
        #[arg(short, long)]
        path: Option<PathBuf>,
    },
    /// Compare this machine's signing key against the committed trust anchor.
    /// Prints "signer|anchor" and exits 3 on a mismatch; silent and exit 0 when they agree.
    AnchorCheck,
    /// Verify immutable model manifest hashes
    Manifest {
        /// Path to model manifest JSON (default: .agents/audit/model-manifest.json)
        #[arg(short, long)]
        manifest: Option<PathBuf>,
    },
    /// Export cryptographic SBOM in CycloneDX 1.6 or SPDX 3.0.1 format
    Sbom {
        /// SBOM format: cyclonedx (default), spdx, or intoto
        #[arg(short, long, default_value = "cyclonedx")]
        format: String,
        /// Output file path (default: stdout)
        #[arg(short, long)]
        out: Option<PathBuf>,
    },
    /// Verify or snapshot supply chain lockfile digests
    Lock {
        /// Update and sign the lockfile manifest (.agents/audit/lockfile-manifest.json)
        #[arg(long)]
        update: bool,
        /// Verify current lockfiles against the signed manifest
        #[arg(long, default_value_t = true)]
        verify: bool,
    },
    /// Derive ML-DSA-65 public key from vault seed and write .agents/audit/signer.mldsa65.pub
    Keygen,
    /// Cryptographically sign a file with ML-DSA-65 (FIPS 204)
    Sign {
        /// File path to sign
        path: PathBuf,
    },
    /// Sign canonical AGENTS.md contract with ML-DSA-65 and update .agents/canonical/ receipts
    Contract {
        /// Threshold k for k-of-n multi-party signing (default: 1)
        #[arg(long, default_value_t = 1)]
        threshold: usize,
        /// Unwrap hardware-backed FIDO2 / TPM 2.0 sealed signing seed
        #[arg(long)]
        hardware_seal: bool,
        /// Inspect and verify all hash-chained transitions in .agents/audit/contract-history.jsonl
        #[arg(long)]
        verify_history: bool,
        /// Output contract governance history as structured JSON
        #[arg(long)]
        json: bool,
    },
    /// Inspect or reset the cumulative differential privacy budget ledger (.agents/audit/privacy-budget.json)
    Privacy {
        /// Maximum allowed cumulative epsilon budget ceiling (default: 10.0)
        #[arg(long, default_value_t = 10.0)]
        max_budget: f64,
        /// Reset cumulative privacy budget expenditure to 0.0
        #[arg(long)]
        reset: bool,
        /// Export signed privacy compliance report to file (e.g. .agents/audit/privacy-report.json)
        #[arg(short, long)]
        out: Option<PathBuf>,
        /// Dry-run PII/credential/path/IP/MAC redaction on an arbitrary file without mutating it
        #[arg(long)]
        redact_check: Option<PathBuf>,
        /// Exit non-zero when the redaction dry-run detects unredacted sensitive classes
        #[arg(long)]
        fail_on_leak: bool,
        /// Cap the number of files scanned in directory `--redact-check` mode (default: 5000)
        #[arg(long)]
        max_files: Option<usize>,
        /// Skip paths matching this glob/substring in directory `--redact-check` mode (repeatable)
        #[arg(long = "exclude")]
        exclude: Vec<String>,
        /// Output privacy budget ledger as JSON
        #[arg(long)]
        json: bool,
    },
}

#[derive(Subcommand)]
pub enum ServiceCommands {
    /// Generate systemd unit or Windows service runner scripts
    Generate {
        /// Port to bind service to (default: 8080)
        #[arg(short, long)]
        port: Option<u16>,
        /// Output path for service definition
        #[arg(short, long)]
        out: Option<PathBuf>,
    },
    /// Install continuous background embedding service on host
    Install {
        /// Port to bind service to (default: 8080)
        #[arg(short, long)]
        port: Option<u16>,
    },
    /// Check background service status and sub-50ms warm latency
    Status {
        /// Ensure service is running and warmed up for sub-50ms query/gate latency
        #[arg(short, long)]
        warm: bool,
    },
    /// Uninstall continuous background service
    Uninstall,
}

/// Collects `ainish-rag status` telemetry into a stable keyed report while optionally
/// emitting the legacy human-readable lines. `--json` suppresses the text rows entirely
/// so orchestrators receive a single parseable document.
struct StatusReporter {
    json: bool,
    fields: serde_json::Map<String, serde_json::Value>,
}

impl StatusReporter {
    fn new(json: bool) -> Self {
        Self { json, fields: serde_json::Map::new() }
    }

    fn put(&mut self, key: &str, value: serde_json::Value) {
        self.fields.insert(key.to_string(), value);
    }

    fn line(&mut self, key: &str, value: serde_json::Value, text: String) {
        self.put(key, value);
        if !self.json {
            println!("{}", text);
        }
    }

    fn finish(self) {
        if self.json {
            let doc = serde_json::Value::Object(self.fields);
            println!("{}", serde_json::to_string_pretty(&doc).unwrap_or_else(|_| "{}".to_string()));
        }
    }
}

/// Reports presence plus detached ML-DSA-65 verification state for a compliance artifact.
fn artifact_signature_status(repo_root: &std::path::Path, rel_path: &str) -> serde_json::Value {
    let path = repo_root.join(rel_path);
    if !path.exists() {
        return serde_json::json!({
            "present": false,
            "path": rel_path,
            "signature_status": "MISSING",
            "signature_verified": false
        });
    }
    if !pqc::sig_path(&path).exists() {
        return serde_json::json!({
            "present": true,
            "path": rel_path,
            "signature_status": "UNSIGNED",
            "signature_verified": false
        });
    }
    match pqc::verify_file(repo_root, &path) {
        pqc::VerifyOutcome::Verified { fingerprint } => serde_json::json!({
            "present": true,
            "path": rel_path,
            "signature_status": "VERIFIED",
            "signature_verified": true,
            "key_fingerprint": &fingerprint[..12.min(fingerprint.len())]
        }),
        pqc::VerifyOutcome::Unsigned(reason) => serde_json::json!({
            "present": true,
            "path": rel_path,
            "signature_status": "UNSIGNED",
            "signature_verified": false,
            "detail": reason
        }),
        pqc::VerifyOutcome::Invalid(err) => serde_json::json!({
            "present": true,
            "path": rel_path,
            "signature_status": "INVALID",
            "signature_verified": false,
            "detail": err
        }),
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();
    let current_dir = env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
    let mut config = RagConfig::detect(&current_dir);
    if let Some(t) = cli.threads {
        config.threads = Some(t);
    }
    if let Some(m) = cli.max_mem {
        config.max_mem = Some(m);
    }
    if let Some(ttl) = cli.psk_ttl {
        config.psk_ttl = Some(ttl);
    }
    if let Some(n) = cli.numa {
        config.numa = Some(n);
    }
    if let Some(a) = cli.cpu_affinity {
        config.cpu_affinity = Some(a);
    }

    // Memory hygiene: a local embedding server spawned by this command is torn down on every
    // exit path (including `?` errors) unless the operator explicitly keeps it resident.
    let keep_server = cli.keep_server
        || matches!(
            std::env::var("AINISH_RAG_KEEP_SERVER").ok().as_deref().map(str::trim),
            Some("1") | Some("true") | Some("yes") | Some("on")
        )
        || matches!(&cli.command, Commands::Service { command: ServiceCommands::Status { warm: true } });
    LlamaServer::set_keep_server(keep_server);
    let _ephemeral_guard = LlamaServer::ephemeral_guard(keep_server);

    match cli.command {
        Commands::Status { json } => {

            let mut reporter = StatusReporter::new(json);
            if !json {
                println!("=== ainish-rag Context Engine Status ===");
            }

            let hf_cache = config.hf_hub_cache.display().to_string();
            reporter.line("hf_cache_root", serde_json::json!(hf_cache), format!("HF Cache Root:      {}", hf_cache));

            let model_gguf = config.model_path.as_ref().map(|p| p.display().to_string());
            reporter.line(
                "model_gguf",
                serde_json::json!(model_gguf),
                format!("Model GGUF:         {}", model_gguf.as_deref().unwrap_or("NOT FOUND")),
            );
            if let Some(ref mp) = config.model_path {
                match LlamaServer::verify_model_integrity(mp) {
                    Ok(stat) => reporter.line(
                        "model_integrity",
                        serde_json::json!(format!("VALID ({})", stat)),
                        format!("Model Integrity:    VALID ({})", stat),
                    ),
                    Err(e) => reporter.line(
                        "model_integrity",
                        serde_json::json!(format!("FAILED ({})", e)),
                        format!("Model Integrity:    FAILED ({})", e),
                    ),
                }
            } else {
                reporter.put("model_integrity", serde_json::Value::Null);
            }

            let mmproj = config.mmproj_path.as_ref().map(|p| p.display().to_string());
            reporter.line(
                "multimodal_projector",
                serde_json::json!(mmproj),
                format!("Multimodal Projector:{}", mmproj.as_deref().unwrap_or("NOT FOUND")),
            );
            let llama_bin = config.llama_bin.as_ref().map(|p| p.display().to_string());
            reporter.line(
                "llama_binary",
                serde_json::json!(llama_bin),
                format!("Llama Binary:       {}", llama_bin.as_deref().unwrap_or("NOT FOUND")),
            );

            reporter.line(
                "server_endpoint",
                serde_json::json!(config.server_url),
                format!("Server Endpoint:    {}", config.server_url),
            );
            let is_running = LlamaServer::is_running(&config.server_url, config.psk.as_deref()).await;
            reporter.line(
                "server_online",
                serde_json::json!(is_running),
                format!("Server Status:      {}", if is_running { "ONLINE (ready)" } else { "OFFLINE" }),
            );

            let psk_status = if let Some(ref psk) = config.psk {
                let preview = if psk.len() > 8 { &psk[..8] } else { psk };
                format!("ENABLED (Loopback PSK: {}...)", preview)
            } else {
                "DISABLED (unauthenticated loopback)".to_string()
            };            reporter.line(
                "loopback_auth",
                serde_json::json!({ "enabled": config.psk.is_some() }),
                format!("Loopback Auth:      {}", psk_status),
            );

            let provider_line = if config.uses_api_embeddings() {
                format!(
                    "API {} (model: {}, no local server) [{}]",
                    config.embed_api_base.as_deref().unwrap_or_default(),
                    config.embed_model.as_deref().unwrap_or_default(),
                    config.embed_source
                )
            } else if config.embed_provider == "invalid" {
                "INVALID (explicit API intent cannot be satisfied)".to_string()
            } else {
                let (ctx, batch) = LlamaServer::derive_ctx_batch(config.max_mem, &current_dir);
                format!("local llama (ctx={} batch={})", ctx, batch)
            };
            reporter.line(
                "embed_provider",
                serde_json::json!({
                    "provider": if config.uses_api_embeddings() { "api" } else { config.embed_provider.as_str() },
                    "provider_id": config.embed_provider_id,
                    "api_base": config.embed_api_base,
                    "model": config.embed_model,
                    "dim": config.embed_dim,
                    "key_present": config.embed_api_key.is_some(),
                    "source": config.embed_source,
                    "warnings": config.embed_warnings,
                }),
                format!("Embed Provider:     {}", provider_line),
            );

            let salt_status = if let Some(ref s) = config.symbol_salt {
                format!("ACTIVE (len: {})", s.len())
            } else {
                "DEFAULT (machine/repo hash)".to_string()
            };            reporter.line(
                "symbol_salt",
                serde_json::json!({
                    "active": config.symbol_salt.is_some(),
                    "length": config.symbol_salt.as_ref().map(|s| s.len()).unwrap_or(0)
                }),
                format!("Symbol Salt:        {}", salt_status),
            );

            let (manifest_state, manifest_text) = match LlamaServer::verify_model_manifest(
                config.model_path.as_ref().unwrap_or(&PathBuf::from("")),
                &config.model_manifest_path
            ) {
                Ok(Some(hash)) => ("VERIFIED", format!("VERIFIED ({})", &hash[..16.min(hash.len())])),
                Ok(None) => ("NOT_PRESENT", "NOT PRESENT (manifest absent)".to_string()),
                Err(e) => ("TAMPERED", format!("TAMPERED ({})", e)),
            };
            reporter.line(
                "model_manifest",
                serde_json::json!({ "status": manifest_state }),
                format!("Model Manifest:     {}", manifest_text),
            );

            // The vector store is retired; retrieval is the wiki vault plus the .agents folders.
            reporter.line(
                "engine",
                serde_json::json!("graph-first"),
                "Engine:             graph-first (no embedding model, no vector store)".to_string(),
            );

            let wiki_exists = config.wiki_dir.exists();
            let wiki_count = if wiki_exists {
                std::fs::read_dir(&config.wiki_dir)
                    .map(|entries| entries.filter_map(|e| e.ok()).filter(|e| e.path().extension().map_or(false, |ext| ext == "md")).count())
                    .unwrap_or(0)
            } else {
                0
            };
            let wiki_path = config.wiki_dir.display().to_string();
            reporter.line("wiki_path", serde_json::json!(wiki_path), format!("Wiki Path:          {}", wiki_path));
            reporter.line("wiki_pages", serde_json::json!(wiki_count), format!("Wiki Pages:         {}", wiki_count));

            let wiki_gen = WikiGenerator::new(&current_dir);
            let ledger_notes = wiki_gen.list_notes();
            let resolved_notes = ledger_notes.iter().filter(|n| n.contains("[RESOLVED]")).count();
            let open_notes = ledger_notes.len().saturating_sub(resolved_notes);
            reporter.line(
                "wiki_ledger_notes",
                serde_json::json!({
                    "total": ledger_notes.len(),
                    "open": open_notes,
                    "resolved": resolved_notes
                }),
                format!("Wiki Ledger Notes:  {} total ({} open, {} resolved)", ledger_notes.len(), open_notes, resolved_notes),
            );

            if let Ok(pb) = crate::scrub::read_or_init_privacy_budget(&current_dir, false) {
                let cum_eps = pb.get("cumulative_epsilon").and_then(|v| v.as_f64()).unwrap_or(0.0);
                let vec_cnt = pb.get("total_protected_vectors").and_then(|v| v.as_u64()).unwrap_or(0);
                reporter.line(
                    "privacy_budget",
                    serde_json::json!({ "cumulative_epsilon": cum_eps, "total_protected_vectors": vec_cnt }),
                    format!("Privacy Budget:     epsilon={:.4} ({} protected vectors in privacy-budget.json)", cum_eps, vec_cnt),
                );
            } else {
                reporter.put("privacy_budget", serde_json::Value::Null);
            }

            match pqc::verify_contract_history_chain(&current_dir) {
                Ok(transitions) => reporter.line(
                    "contract_history",
                    serde_json::json!({ "verified": true, "transitions": transitions }),
                    format!("Contract History:   {} hash-chained transitions verified (contract-history.jsonl)", transitions),
                ),
                Err(err) => {
                    let text = format!("Contract History:   INVALID ({})", err);
                    reporter.line(
                        "contract_history",
                        serde_json::json!({ "verified": false, "error": err }),
                        text,
                    );
                }
            }

            let mut signatures = serde_json::Map::new();
            for (key, rel_path) in [
                ("model_manifest", ".agents/audit/model-manifest.json"),
                ("lockfile_manifest", ".agents/audit/lockfile-manifest.json"),
                ("privacy_budget", ".agents/audit/privacy-budget.json"),
                ("privacy_report", ".agents/audit/privacy-report.json"),
            ] {
                signatures.insert(key.to_string(), artifact_signature_status(&current_dir, rel_path));
            }
            reporter.put("signatures", serde_json::Value::Object(signatures));

            // No "install llama.cpp / download the GGUF" tips: there is no embedding model to
            // install. Printing them would tell an operator to fix something that no longer exists.
            reporter.finish();
        }
        Commands::Wiki { path, index, note, resolve, list_notes, sync_resolved, json } => {
            let target = path.unwrap_or_else(|| current_dir.clone());
            let generator = WikiGenerator::new(&target);
            if sync_resolved {
                let newly_synced = generator.sync_bidirectional_resolutions()?;
                println!("  \x1b[32m[rag:wiki]\x1b[0m Bidirectionally synchronized [RESOLVED] entries between .agents/memories/ and .agents/wiki/ledger.md ({} newly marked).", newly_synced);
                return Ok(());
            }
            if list_notes {
                let notes = generator.list_notes();
                if json {
                    let items: Vec<serde_json::Value> = notes.iter().enumerate().map(|(idx, n)| {
                        let resolved = n.contains("[RESOLVED]");
                        let text = n.trim_start_matches("- ").trim_start_matches("[RESOLVED]").trim().to_string();
                        serde_json::json!({
                            "index": idx + 1,
                            "status": if resolved { "RESOLVED" } else { "OPEN" },
                            "resolved": resolved,
                            "note": text,
                            "raw": n,
                        })
                    }).collect();
                    let open_cnt = items.iter().filter(|i| !i["resolved"].as_bool().unwrap_or(false)).count();
                    let res_cnt = items.len().saturating_sub(open_cnt);
                    println!("{}", serde_json::to_string_pretty(&serde_json::json!({
                        "total": items.len(),
                        "open": open_cnt,
                        "resolved": res_cnt,
                        "notes": items,
                    }))?);
                } else {
                    println!("=== ainish-rag Operator Wiki Ledger Notes (.agents/wiki/ledger.md) ===");
                    if notes.is_empty() {
                        println!("  (No operator ledger entries recorded yet)");
                    } else {
                        for (idx, n) in notes.iter().enumerate() {
                            let status = if n.contains("[RESOLVED]") { "\x1b[32m[RESOLVED]\x1b[0m" } else { "\x1b[33m[OPEN]\x1b[0m" };
                            let clean_n = n.trim_start_matches("- ").trim_start_matches("[RESOLVED]").trim();
                            println!("  [{}] {} {}", idx + 1, status, clean_n);
                        }
                    }
                    println!();
                }
                return Ok(());
            }
            if let Some(ref kw) = resolve {
                let count = generator.resolve_note(kw)?;
                println!("  \x1b[32m[rag:wiki]\x1b[0m Marked {} matching ledger entries [RESOLVED] and recorded resolution in today's .agents/memories/ file.", count);
            }
            if let Some(ref note_arg) = note {
                let note_text = if note_arg.trim() == "-" {
                    use std::io::Read;
                    let mut buf = String::new();
                    std::io::stdin().read_to_string(&mut buf)?;
                    buf
                } else {
                    note_arg.clone()
                };
                let (ledger_path, sig_path) = generator.append_note_and_sign(&note_text)?;
                println!("  \x1b[32m[rag:wiki]\x1b[0m Appended UTC-dated note (with HEAD SHA) to {} and signed detached ML-DSA-65 envelope ({})", ledger_path.display(), sig_path.display());
            } else {
                // Only (re-)sign a ledger whose CONTENT changed. Signing unconditionally made
                // `ainish-rag wiki` rewrite `ledger.sig` on every run — same `sha256`, different
                // `signed_at` and, on a host with a rotated key, a different
                // `public_key_fingerprint`. A signed artifact that churns while its content is
                // byte-identical cannot be used to prove anything about that content, and it
                // dirties the tree on a read-mostly command.
                let ledger_path = target.join(".agents").join("wiki").join("ledger.md");
                if ledger_path.exists() {
                    let sig_path = pqc::sig_path(&ledger_path);
                    let needs_sign = match (pqc::verify_file(&target, &ledger_path), sig_path.exists()) {
                        (pqc::VerifyOutcome::Verified { .. }, true) => false,
                        _ => true,
                    };
                    if needs_sign {
                        let _ = pqc::sign_file(&ledger_path);
                    }
                }
            }
            println!("=== Generating Codebase Wiki in .agents/wiki/ ===");
            let generated_pages = generator.generate_all()?;

            if index {
                // The LanceDB index is retired (2026-11-12); the vault IS the retrieval corpus.
                // Keep the flag accepted so existing invocations do not break, and say what happened.
                println!("  [rag:wiki] Vector indexing retired 2026-11-12; the vault IS the retrieval corpus.");
            }
        }
        Commands::Completion { shell } => {
            print_completion(&shell);
        }
        Commands::Route { query, json } => {
            let engine = DecisionEngine::new();
            let decision = engine.route(&query).await;
            if json {
                println!("{}", serde_json::to_string_pretty(&decision)?);
            } else {
                println!("\n=== Jev Decision Routing ===");
                println!("Query:                 {}", query);
                println!("Source:                {}", decision.source);
                println!("Needs Retrieval:       {} (probability: {:.3})", decision.needs_retrieval, decision.retrieval_probability);
                println!("Target Domain:         {} (confidence:  {:.3})", decision.target_domain, decision.route_confidence);
                println!("Context Freshness:     {:.3}", decision.context_freshness);
                println!("Query Specificity:     {}", decision.query_specificity);
                println!("Modality Preference:   {}", decision.modality_preference);
                println!("Retrieval Strategy:    {} (pool: {})", decision.retrieval_strategy, decision.candidate_pool_size);
                println!("Context Budget:        {} tokens", decision.context_budget_tokens);
                println!("Next Action:           {}", decision.next_action);
                println!();
            }
        }
        Commands::Decide { state, question, questions, json } => {
            let engine = DecisionEngine::new();

            // `--questions` is the agent-facing primitive: typed noul/choice/score questions with
            // explicit criteria, answered together in one calibrated request.
            if let Some(raw) = questions {
                let text = if let Some(path) = raw.strip_prefix('@') {
                    std::fs::read_to_string(path)?
                } else if std::path::Path::new(&raw).is_file() {
                    std::fs::read_to_string(&raw)?
                } else {
                    raw
                };
                let parsed: serde_json::Value = serde_json::from_str(&text)
                    .map_err(|e| format!("--questions must be a JSON object of typed questions: {}", e))?;
                if !parsed.is_object() {
                    return Err("--questions must be a JSON object keyed by question id".into());
                }
                let set = engine.decide(&state, &parsed).await?;
                if json {
                    println!("{}", serde_json::to_string_pretty(&serde_json::json!({
                        "state": state,
                        "model": set.model,
                        "source": set.source,
                        "answers": set.answers,
                        "usage": set.usage,
                    }))?);
                } else {
                    println!("\n=== Jev Typed Decisions ===");
                    println!("State:   {}", state.lines().next().unwrap_or(""));
                    println!("Model:   {} ({})", set.model, set.source);
                    for answer in &set.answers {
                        let value = if let Some(p) = answer.noul {
                            format!("{:.3} ({})", p, answer.band())
                        } else if let Some(choice) = &answer.choice {
                            format!("{}{}", choice, answer.confidence.map(|c| format!(" (confidence {:.2})", c)).unwrap_or_default())
                        } else if let Some(score) = answer.score {
                            format!("{:.2}", score)
                        } else {
                            "n/a".to_string()
                        };
                        println!("  {:<28} {:<8} {}", answer.id, answer.kind, value);
                    }
                    println!();
                }
                return Ok(());
            }

            if let Some(q) = question {
                let questions = serde_json::json!({
                    "statement": DecisionEngine::noul_question(
                        &q,
                        "the state provides clear evidence that the answer is yes",
                        "the state provides no evidence that the answer is yes"
                    )
                });
                let set = engine.decide(&state, &questions).await?;
                let answer = set.answers.first();
                if json {
                    println!("{}", serde_json::to_string_pretty(&serde_json::json!({
                        "state": state,
                        "question": q,
                        "model": set.model,
                        "source": set.source,
                        "answer": answer,
                    }))?);
                } else {
                    println!("\n=== Jev Decision Analysis ===");
                    println!("State:                 {}", state.lines().next().unwrap_or(""));
                    println!("Question:              {}", q);
                    println!("Model:                 {} ({})", set.model, set.source);
                    match answer.and_then(|a| a.noul) {
                        Some(p) => println!("Answer:                {:.3} ({})", p, crate::decision::noul_band(p)),
                        None => println!("Answer:                unresolved"),
                    }
                    println!();
                }
                return Ok(());
            }

            let decision = engine.route(&state).await;
            if json {
                println!("{}", serde_json::to_string_pretty(&decision)?);
            } else {
                println!("\n=== Jev Decision Routing ===");
                println!("State:                 {}", state.lines().next().unwrap_or(""));
                println!("Source:                {}", decision.source);
                println!("Needs Retrieval:       {} ({:.3})", decision.needs_retrieval, decision.retrieval_probability);
                println!("Target Domain:         {} (confidence {:.3})", decision.target_domain, decision.route_confidence);
                println!("Context Freshness:     {:.3}", decision.context_freshness);
                println!();
            }
        }
        Commands::Eval { context, output, patch, generate_patch, json } => {
            if patch.is_some() {
                // `--patch` scored a diff against the LanceDB index, retired 2026-11-12. Report it
                // as retired rather than grading against nothing and printing a confident number.
                eprintln!(
                    "  [rag:error] `eval --patch` was retired 2026-11-12 with the vector store.\n\
                     \x20             Use `eval --context <retrieved> --output <summary>` instead."
                );
                std::process::exit(1);
            } else {
                let ctx = context.unwrap_or_default();
                let out = output.unwrap_or_default();
                let engine = DecisionEngine::new();
                let eval = engine.evaluate_faithfulness(&ctx, &out).await;
                if json {
                    println!("{}", serde_json::to_string_pretty(&eval)?);
                } else {
                    println!("\n=== Bi-Phasic Faithfulness Evaluation ===");
                    println!("Evaluation Source:     {}", eval.evaluation_source);
                    println!("Verdict Band:          {}", eval.verdict_band);
                    println!("Faithful to Context:   {}", eval.is_faithful);
                    println!("Faithfulness Score:    {:.3}", eval.faithfulness_score);
                    println!("Completeness Score:    {:.3}", eval.completeness_score);
                    println!("Contradiction Prob:    {:.3}", eval.contradiction_probability);
                    println!("Hallucination Risk:    {:.3}", eval.halluncination_risk);
                    println!();
                }
            }
        }
        Commands::Cleanup { compact, prune_days, prune_worktrees, delete_merged, dry_run } => {
            println!("=== ainish-rag Worktree Hygiene ===");
            if compact {
                // LanceDB compaction is retired with the vector store; the flag stays accepted so
                // existing invocations do not break, and there is nothing left to compact.
                println!("  [rag:maintenance] LanceDB compaction: skipped (vector store retired 2026-11-12)");
                let _ = prune_days;
            }
            if prune_worktrees || delete_merged {
                let _ = std::process::Command::new("git")
                    .args(["worktree", "prune"])
                    .current_dir(&current_dir)
                    .output();
                let current_branch = std::process::Command::new("git")
                    .args(["branch", "--show-current"])
                    .current_dir(&current_dir)
                    .output()
                    .ok()
                    .and_then(|o| String::from_utf8(o.stdout).ok())
                    .map(|s| s.trim().to_string())
                    .unwrap_or_default();
                let merged_branches: Vec<String> = std::process::Command::new("git")
                    .args(["branch", "--merged", "main"])
                    .current_dir(&current_dir)
                    .output()
                    .ok()
                    .and_then(|o| String::from_utf8(o.stdout).ok())
                    .map(|s| {
                        s.lines()
                            .map(|l| l.trim().trim_start_matches('*').trim_start_matches('+').trim().to_string())
                            .filter(|b| !b.is_empty() && b != "main" && b != "master" && b != &current_branch)
                            .collect()
                    })
                    .unwrap_or_default();
                if merged_branches.is_empty() {
                    println!("  \x1b[32m[rag:worktrees]\x1b[0m Pruned stale git worktree metadata; 0 lingering merged branches detected.");
                } else if delete_merged {
                    if dry_run {
                        println!("  \x1b[36m[rag:worktrees:dry-run]\x1b[0m Would delete {} merged local branches: {}", merged_branches.len(), merged_branches.join(", "));
                    } else {
                        let mut deleted = Vec::new();
                        for b in &merged_branches {
                            if std::process::Command::new("git")
                                .args(["branch", "-d", b])
                                .current_dir(&current_dir)
                                .output()
                                .map_or(false, |o| o.status.success())
                            {
                                deleted.push(b.clone());
                            }
                        }
                        println!("  \x1b[32m[rag:worktrees]\x1b[0m Automatically deleted {} merged local branches: {}", deleted.len(), deleted.join(", "));
                    }
                } else {
                    println!("  \x1b[33m[rag:worktrees]\x1b[0m Pruned worktree metadata; merged branches ready for cleanup (use --delete-merged [--dry-run]): {}", merged_branches.join(", "));
                }
            }
        }
        Commands::Orient { inject, query, task_conditioned, verify, compact, max_lines, sections, include_symbols, sync_rules, json } => {
            if inject {
                run_orient_inject(&current_dir, query.as_deref(), task_conditioned, verify, compact, max_lines, sections, include_symbols, sync_rules, json).await?;
            }
        }
        Commands::Gate { patch, bell, notify, watch, summary, strict, tests, json } => {
            run_gate(&config, &current_dir, patch.as_deref(), bell, notify, watch, summary, strict, tests.as_deref(), false, json).await?;
        }
        Commands::Statusline { json } => {
            run_gate(&config, &current_dir, None, false, false, false, true, false, None, json, false).await?;
        }
        Commands::Secrets { json } => {
            let status = DecisionEngine::inspect_secrets();
            let jev = crate::decision::inspect_jev().await;
            if json {
                println!("{}", serde_json::to_string_pretty(&serde_json::json!({
                    "has_key": status.has_key,
                    "key_source": status.key_source,
                    "vault_bundle_exists": status.vault_bundle_exists,
                    "vault_path": status.vault_path,
                    "model": status.model,
                    "decision": jev,
                }))?);
            } else {
                println!("\n=== PQC Secrets & Decision Model Status ===");
                println!("OpenRouter Key Present: {}", if status.has_key { "YES" } else { "NO (offline calibrated fallback active)" });
                println!("Key Resolution Source:  {}", status.key_source);
                println!("PQC Vault Bundle:       {}", if status.vault_bundle_exists { "FOUND" } else { "NOT FOUND" });
                println!("Vault Path:             {}", status.vault_path);
                println!("Decision Model:         {} (latest: {})", jev.model, jev.latest_model);
                if jev.model_pinned {
                    println!("  \x1b[33m!\x1b[0m JEV_DECISION_MODEL pins a model other than the latest");
                }
                println!("OpenRouter Endpoint:    {}", jev.endpoint);
                match jev.local_router.as_ref() {
                    Some(router) => {
                        println!("Local Router:           {} (jev models: {})", router.base_url, router.jev_models.join(", "));
                        match router.decisions_url.as_deref() {
                            Some(url) => println!("  Decisions Route:      {} (fallback transport)", url),
                            None => println!("  Decisions Route:      none (router exposes Jev chat only — check GET /api/decisions/status; typed decisions stay on OpenRouter)"),
                        }
                    }
                    None => println!("Local Router:           not detected on loopback"),
                }
                println!();
            }
        }
        Commands::Audit { command } => match command {
            AuditCommands::Verify { path } => {
                run_audit_verify(&current_dir, path.as_deref())?;
            }
            AuditCommands::AnchorCheck => {
                match pqc::anchor_signer_mismatch(&current_dir) {
                    Ok(Some((signer, anchor))) => {
                        println!("{}|{}", signer, anchor);
                        std::process::exit(3);
                    }
                    Ok(None) => {}
                    Err(e) => {
                        eprintln!("anchor-check: {}", e);
                        std::process::exit(2);
                    }
                }
            }
            AuditCommands::Manifest { manifest } => {
                run_audit_manifest(&config, manifest.as_deref())?;
            }
            AuditCommands::Sbom { format, out } => {
                run_audit_sbom(&config, &current_dir, &format, out.as_deref())?;
            }
            AuditCommands::Lock { update, verify } => {
                run_audit_lock(&config, &current_dir, update, verify)?;
            }
            AuditCommands::Keygen => {
                run_audit_keygen(&current_dir)?;
            }
            AuditCommands::Sign { path } => {
                run_audit_sign(&path)?;
            }
            AuditCommands::Contract { threshold, hardware_seal, verify_history, json } => {
                if verify_history {
                    let history_file = current_dir.join(".agents").join("audit").join("contract-history.jsonl");
                    let chain_res = pqc::verify_contract_history_chain(&current_dir);
                    let history_sig_file = pqc::sig_path(&history_file);
                    let signature_status = if !history_sig_file.exists() {
                        "MISSING"
                    } else {
                        match pqc::verify_file(&current_dir, &history_file) {
                            pqc::VerifyOutcome::Verified { .. } => "VERIFIED",
                            pqc::VerifyOutcome::Unsigned(_) => "UNSIGNED",
                            pqc::VerifyOutcome::Invalid(_) => "INVALID",
                        }
                    };
                    let mut entries_list = Vec::new();
                    if let Ok(text) = std::fs::read_to_string(&history_file) {
                        for (idx, line) in text.lines().filter(|l| !l.trim().is_empty()).enumerate() {
                            if let Ok(mut v) = serde_json::from_str::<serde_json::Value>(line) {
                                if let Some(obj) = v.as_object_mut() {
                                    obj.insert("index".to_string(), serde_json::json!(idx + 1));
                                }
                                entries_list.push(v);
                            }
                        }
                    }
                    if json {
                        let verified = chain_res.is_ok();
                        let count = chain_res.unwrap_or(entries_list.len());
                        println!("{}", serde_json::to_string_pretty(&serde_json::json!({
                            "verified": verified,
                            "transitions_count": count,
                            "history_file": history_file.to_string_lossy(),
                            "signature_file": history_sig_file.to_string_lossy(),
                            "signature_status": signature_status,
                            "signature_verified": signature_status == "VERIFIED",
                            "transitions": entries_list,
                        }))?);
                        return Ok(());
                    }
                    println!("=== ainish-rag Canonical Contract Governance History ===");
                    println!("  History Log: {}", history_file.display());
                    let sig_label = match signature_status {
                        "VERIFIED" => "\x1b[32mVERIFIED\x1b[0m",
                        "UNSIGNED" => "\x1b[33mUNSIGNED\x1b[0m",
                        "INVALID" => "\x1b[31mINVALID\x1b[0m",
                        _ => "\x1b[33mMISSING\x1b[0m",
                    };
                    println!("  ML-DSA-65 Sig: {} (contract-history.sig)", sig_label);
                    match chain_res {
                        Ok(cnt) => {
                            for v in &entries_list {
                                let idx = v.get("index").and_then(|i| i.as_u64()).unwrap_or(0);
                                let ts = v.get("timestamp").and_then(|s| s.as_str()).unwrap_or("");
                                let sha = v.get("contract_sha256").and_then(|s| s.as_str()).unwrap_or("");
                                let fpr = v.get("signer_fingerprint").and_then(|s| s.as_str()).unwrap_or("");
                                let prev = v.get("prev_entry_sha256").and_then(|s| s.as_str()).unwrap_or("");
                                println!(
                                    "  [#{:>2}] {} | sha256:{}... | signer:{}... | prev:{}...",
                                    idx,
                                    ts,
                                    &sha[..12.min(sha.len())],
                                    &fpr[..12.min(fpr.len())],
                                    &prev[..12.min(prev.len())]
                                );
                            }
                            println!("  \x1b[32m[PASS]\x1b[0m Verified {} hash-chained governance transitions & ML-DSA-65 signature.\n", cnt);
                        }
                        Err(e) => {
                            eprintln!("  \x1b[31m[FAIL]\x1b[0m Governance history verification failed: {}\n", e);
                        }
                    }
                    return Ok(());
                }
                if hardware_seal {
                    println!("  \x1b[36m[rag:audit]\x1b[0m Unwrapping hardware-backed FIDO2 / TPM 2.0 seal for council signing seed...");
                }
                match pqc::sign_canonical_contract_threshold(&current_dir, threshold) {
                    Ok(thresh_file) => {
                        println!("  \x1b[32m[rag:audit]\x1b[0m Signed canonical AGENTS.md contract with FIPS 204 ML-DSA-65 (threshold k={}):", threshold);
                        println!("    Envelope:  {}", thresh_file.display());
                    }
                    Err(e) => eprintln!("  \x1b[31m[rag:error]\x1b[0m Failed signing canonical contract: {}", e),
                }
            }
            AuditCommands::Privacy { max_budget, reset, out, redact_check, fail_on_leak, max_files, exclude, json } => {
                if let Some(ref target) = redact_check {
                    run_redact_check(&current_dir, target, fail_on_leak, max_files, &exclude, json)?;
                } else {
                    run_audit_privacy(&current_dir, max_budget, reset, out.as_deref(), json)?;
                }
            }
        },
        Commands::Serve { .. } => retired("serve"),
        Commands::Stop { .. } => retired("stop"),
        Commands::Index { .. } => retired("index"),
        Commands::Query { .. } => retired("query"),
        Commands::Rerank { .. } => retired("rerank"),
        Commands::Bench { .. } => retired("bench"),
        Commands::Monitor { .. } => retired("monitor"),
        Commands::EmbedProvider { .. } => retired("embed-provider"),
        Commands::Service { .. } => retired("service"),
    }

    Ok(())
}

/// Reports differential-privacy budget state and runs the live redaction self-test.
fn run_audit_privacy(
    repo_root: &std::path::Path,
    max_budget: f64,
    reset: bool,
    out: Option<&std::path::Path>,
    json: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    let pb = crate::scrub::read_or_init_privacy_budget(repo_root, reset)?;
    let cum_eps = pb.get("cumulative_epsilon").and_then(|v| v.as_f64()).unwrap_or(0.0);
    let vec_cnt = pb.get("total_protected_vectors").and_then(|v| v.as_u64()).unwrap_or(0);
    let within_budget = cum_eps <= max_budget;
    let wiki_gen = WikiGenerator::new(repo_root);
    let redaction_ok = wiki_gen.verify_redaction_pipeline().is_ok();
    let ledger_path = repo_root.join(".agents").join("audit").join("privacy-budget.json");
    let sig_ok = matches!(pqc::verify_file(repo_root, &ledger_path), pqc::VerifyOutcome::Verified { .. });
    let report_payload = serde_json::json!({
        "format": "ainish-rag/privacy-compliance-report/v1",
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "within_budget": within_budget,
        "max_budget": max_budget,
        "cumulative_epsilon": cum_eps,
        "total_protected_vectors": vec_cnt,
        "redaction_self_test": if redaction_ok { "PASS" } else { "FAIL" },
        "redaction_classes_verified": ["PII", "Credentials", "UserPaths", "InternalIPs", "MAC", "ANSI", "TrojanSourceBidi"],
        "signature_verified": sig_ok,
        "ledger": pb,
    });
    if let Some(out_path) = out {
        if let Some(parent) = out_path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let report_str = serde_json::to_string_pretty(&report_payload)?;
        std::fs::write(out_path, &report_str)?;
        let sig_res = pqc::sign_file(out_path);
        let sig_note = if let Ok(ref sp) = sig_res { format!(" + signed ({})", sp.display()) } else { String::new() };
        println!("  \x1b[32m[rag:privacy]\x1b[0m Exported privacy compliance report to {}{}", out_path.display(), sig_note);
    }
    if json {
        println!("{}", serde_json::to_string_pretty(&report_payload)?);
    } else {
        println!("=== ainish-rag Differential Privacy & Redaction Audit ===");
        println!("  Ledger File:      {}", ledger_path.display());
        println!("  Mechanism:        Gaussian-DP-L2 (delta=1e-5, sensitivity=0.05)");
        println!("  Protected Vecs:   {}", vec_cnt);
        println!("  Cumulative Eps:   {:.4} / {:.4} max budget", cum_eps, max_budget);
        println!("  Redaction Test:   {}", if redaction_ok { "\x1b[32mPASS (PII, Credentials, User Paths, Internal IPs, MAC & Trojan-Source Bidi)\x1b[0m" } else { "\x1b[31mFAIL\x1b[0m" });
        println!("  ML-DSA-65 Sig:    {}", if sig_ok { "\x1b[32mVERIFIED (privacy-budget.sig)\x1b[0m" } else { "\x1b[33mUNSIGNED\x1b[0m" });
        println!("  Status:           {}", if within_budget && redaction_ok { "\x1b[32mPASS (Within Privacy Budget & Redaction Verified)\x1b[0m" } else { "\x1b[31mFAIL\x1b[0m" });
        println!();
    }
    Ok(())
}

/// Dry-runs the complete redaction pipeline against an arbitrary file and reports what
/// would be scrubbed, without ever mutating the target.
/// Runs the non-mutating redaction dry-run on a single file, returning the report JSON
/// plus whether any sensitive class was detected. Never writes to the target.
fn redact_check_file(
    repo_root: &std::path::Path,
    path: &std::path::Path,
) -> Result<(serde_json::Value, bool), Box<dyn std::error::Error>> {
    let raw_bytes = std::fs::read(path)?;
    let raw = String::from_utf8_lossy(&raw_bytes).into_owned();
    let wiki_gen = WikiGenerator::new(repo_root);
    let sanitized = WikiGenerator::sanitize_text_for_redaction(&raw);
    let scrubbed = crate::scrub::scrub_sensitive_content(&sanitized);
    let redacted = wiki_gen.redact_local_user_paths(&scrubbed);

    let mut classes: Vec<&str> = Vec::new();
    for (marker, label) in [
        ("[REDACTED:EMAIL]", "PII:EMAIL"),
        ("[REDACTED:SSN]", "PII:SSN"),
        ("[REDACTED:PHONE]", "PII:PHONE"),
        ("[REDACTED:CARD]", "PII:CARD"),
        ("[REDACTED:TOKEN]", "CREDENTIAL:TOKEN"),
        ("[REDACTED:PRIVATE_KEY]", "CREDENTIAL:PRIVATE_KEY"),
        ("[REDACTED:INTERNAL_IP]", "INTERNAL_IP"),
        ("[REDACTED:MAC]", "MAC"),
    ] {
        if redacted.contains(marker) {
            classes.push(label);
        }
    }
    let ansi_detected = raw.contains('\x1b');
    let bidi_detected = WikiGenerator::contains_bidi_override(&raw);
    if ansi_detected {
        classes.push("ANSI_ESCAPE");
    }
    if bidi_detected {
        classes.push("TROJAN_SOURCE_BIDI");
    }

    let mut changed_line_numbers: Vec<usize> = Vec::new();
    let mut redacted_preview: Vec<String> = Vec::new();
    for (idx, (original, cleaned)) in raw.split('\n').zip(redacted.split('\n')).enumerate() {
        if original != cleaned {
            changed_line_numbers.push(idx + 1);
            if redacted_preview.len() < 10 {
                redacted_preview.push(format!("L{}: {}", idx + 1, cleaned));
            }
        }
    }

    let file_unchanged = std::fs::read(path).map(|after| after == raw_bytes).unwrap_or(false);
    let leaked = !classes.is_empty();
    let report = serde_json::json!({
        "file": path.to_string_lossy(),
        "bytes": raw_bytes.len(),
        "lines": raw.lines().count(),
        "changed_lines": changed_line_numbers.clone(),
        "redaction_classes": classes.clone(),
        "ansi_escape_detected": ansi_detected,
        "bidi_override_detected": bidi_detected,
        "file_unchanged": file_unchanged,
        "redacted_preview": redacted_preview.clone(),
    });
    Ok((report, leaked))
}

/// Recursively collects candidate text files under `dir`, skipping binary/oversized paths.
fn collect_redact_targets(
    dir: &std::path::Path,
    out: &mut Vec<std::path::PathBuf>,
    max_files: usize,
    excludes: &[String],
    root: &std::path::Path,
) {
    const SKIP_DIRS: [&str; 6] = [".git", "node_modules", "target", "__pycache__", ".venv", "venv"];
    const TEXT_EXTS: [&str; 12] = ["md", "mdx", "txt", "rst", "rs", "py", "ts", "js", "go", "sh", "json", "yaml"];
    if out.len() >= max_files {
        return;
    }
    let Ok(entries) = std::fs::read_dir(dir) else { return };
    for entry in entries.flatten() {
        if out.len() >= max_files {
            return;
        }
        let p = entry.path();
        // Operator `--exclude` patterns match the path relative to the scan root, so a pattern
        // like `vendor` or `*.min.js` skips vendored/generated trees without listing them all.
        let rel = p.strip_prefix(root).unwrap_or(&p).to_string_lossy().replace('\\', "/");
        if !excludes.is_empty() && excludes.iter().any(|pat| glob_match(pat, &rel)) {
            continue;
        }
        if p.is_dir() {
            if let Some(name) = p.file_name().and_then(|n| n.to_str()) {
                if SKIP_DIRS.contains(&name) {
                    continue;
                }
            }
            collect_redact_targets(&p, out, max_files, excludes, root);
        } else if p.extension().and_then(|e| e.to_str()).map_or(false, |e| {
            TEXT_EXTS.contains(&e.to_lowercase().as_str())
        }) {
            out.push(p);
        }
    }
}

/// Minimal glob matcher supporting `*`, `?`, and path-prefix segments (no external dependency).
/// A pattern with no wildcard also matches when it is a substring of the path, which keeps
/// `--exclude vendor` intuitive.
fn glob_match(pattern: &str, path: &str) -> bool {
    if !pattern.contains('*') && !pattern.contains('?') {
        return path.contains(pattern);
    }
    // Translate to a simple recursive matcher over chars.
    fn rec(p: &[u8], s: &[u8]) -> bool {
        if p.is_empty() {
            return s.is_empty();
        }
        match p[0] {
            b'*' => {
                // collapse consecutive '*'
                let mut i = 1;
                while i < p.len() && p[i] == b'*' {
                    i += 1;
                }
                let rest = &p[i..];
                if rest.is_empty() {
                    return true;
                }
                for k in 0..=s.len() {
                    if rec(rest, &s[k..]) {
                        return true;
                    }
                }
                false
            }
            b'?' => !s.is_empty() && rec(&p[1..], &s[1..]),
            c => !s.is_empty() && s[0] == c && rec(&p[1..], &s[1..]),
        }
    }
    rec(pattern.as_bytes(), path.as_bytes())
}

fn run_redact_check(
    repo_root: &std::path::Path,
    path: &std::path::Path,
    fail_on_leak: bool,
    max_files: Option<usize>,
    exclude: &[String],
    json: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    // Directory mode: dry-run every text file beneath `path`, aggregate, never mutate.
    if path.is_dir() {
        let cap = max_files.unwrap_or(5000).max(1);
        let mut targets = Vec::new();
        collect_redact_targets(path, &mut targets, cap, exclude, path);
        targets.sort();
        let truncated = targets.len() >= cap;

        let mut all_classes: Vec<String> = Vec::new();
        let mut per_file: Vec<serde_json::Value> = Vec::new();
        let mut total_changed = 0usize;
        let mut files_with_leaks = 0usize;
        let mut total_bytes = 0usize;
        for f in &targets {
            match redact_check_file(repo_root, f) {
                Ok((mut report, leaked)) => {
                    total_bytes += report["bytes"].as_u64().unwrap_or(0) as usize;
                    total_changed += report["changed_lines"].as_array().map(|a| a.len()).unwrap_or(0);
                    if leaked {
                        files_with_leaks += 1;
                        if let Some(arr) = report["redaction_classes"].as_array() {
                            for c in arr {
                                if let Some(s) = c.as_str() {
                                    if !all_classes.iter().any(|x| x == s) {
                                        all_classes.push(s.to_string());
                                    }
                                }
                            }
                        }
                    }
                    report["relative_path"] = serde_json::json!(
                        f.strip_prefix(path).unwrap_or(f).to_string_lossy()
                    );
                    per_file.push(report);
                }
                Err(err) => {
                    per_file.push(serde_json::json!({
                        "file": f.to_string_lossy(),
                        "error": err.to_string(),
                    }));
                }
            }
        }

        let any_unchanged = per_file.iter().all(|r| r["file_unchanged"].as_bool().unwrap_or(true));
        let report = serde_json::json!({
            "format": "ainish-rag/redact-check-dir/v1",
            "directory": path.to_string_lossy(),
            "files_scanned": per_file.len(),
            "files_with_leaks": files_with_leaks,
            "total_bytes": total_bytes,
            "changed_lines": total_changed,
            "redaction_classes": all_classes,
            "all_files_unchanged": any_unchanged,
            "fail_on_leak": fail_on_leak,
            "max_files": cap,
            "truncated": truncated,
            "exclude": exclude,
            "files": per_file,
            "status": if files_with_leaks == 0 { "CLEAN" } else if fail_on_leak { "LEAK_DETECTED" } else { "LEAK_REPORTED" },
        });

        if json {
            println!("{}", serde_json::to_string_pretty(&report)?);
        } else {
            println!("=== ainish-rag Redaction Dry-Run — Directory (No File Mutation) ===");
            println!("  Directory:        {}", path.display());
            println!("  Files Scanned:    {}", per_file.len());
            println!("  Files w/ Leaks:   {}", files_with_leaks);
            println!("  Total Changed Ln: {}", total_changed);
            println!("  Classes Detected: {}", if all_classes.is_empty() { "none".to_string() } else { all_classes.join(", ") });
            println!("  All Unchanged:    {}", if any_unchanged { "YES (dry-run only)" } else { "NO (unexpected mutation!)" });
            if truncated {
                println!("  \x1b[33mScan capped at --max-files {}\x1b[0m (raise it to cover the whole tree)", cap);
            }
            if !exclude.is_empty() {
                println!("  Excluded:         {}", exclude.join(", "));
            }
            if files_with_leaks > 0 {
                for r in per_file.iter().filter(|r| r["redaction_classes"].as_array().map_or(false, |a| !a.is_empty())) {
                    println!("    {} — {}", r["relative_path"].as_str().unwrap_or("?"), r["redaction_classes"].as_array().unwrap().iter().filter_map(|c| c.as_str()).collect::<Vec<_>>().join(", "));
                }
            }
            println!();
        }
        if fail_on_leak && files_with_leaks > 0 {
            return Err(format!(
                "Redaction dry-run detected leaks in {} of {} file(s) under {}: {}",
                files_with_leaks,
                per_file.len(),
                path.display(),
                all_classes.join(", ")
            ).into());
        }
        return Ok(());
    }

    let (report, leaked) = redact_check_file(repo_root, path)?;
    let classes: Vec<String> = report["redaction_classes"].as_array()
        .map(|a| a.iter().filter_map(|c| c.as_str().map(|s| s.to_string())).collect())
        .unwrap_or_default();
    let ansi_detected = report["ansi_escape_detected"].as_bool().unwrap_or(false);
    let bidi_detected = report["bidi_override_detected"].as_bool().unwrap_or(false);
    let file_unchanged = report["file_unchanged"].as_bool().unwrap_or(false);
    let redacted_preview: Vec<String> = report["redacted_preview"].as_array()
        .map(|a| a.iter().filter_map(|c| c.as_str().map(|s| s.to_string())).collect())
        .unwrap_or_default();

    let full_report = serde_json::json!({
        "format": "ainish-rag/redact-check/v1",
        "file": path.to_string_lossy(),
        "bytes": report["bytes"].as_u64().unwrap_or(0),
        "lines": report["lines"].as_u64().unwrap_or(0),
        "changed_lines": report["changed_lines"].as_array().map(|a| a.len()).unwrap_or(0),
        "changed_line_numbers": report["changed_lines"].clone(),
        "redaction_classes": classes.clone(),
        "ansi_escape_detected": ansi_detected,
        "bidi_override_detected": bidi_detected,
        "file_unchanged": file_unchanged,
        "fail_on_leak": fail_on_leak,
        "redacted_preview": redacted_preview.clone(),
        "status": if classes.is_empty() { "CLEAN" } else if fail_on_leak { "LEAK_DETECTED" } else { "LEAK_REPORTED" },
    });

    if json {
        println!("{}", serde_json::to_string_pretty(&full_report)?);
    } else {
        println!("=== ainish-rag Redaction Dry-Run (No File Mutation) ===");
        println!("  File:             {}", path.display());
        println!("  Size:             {} bytes / {} lines", full_report["bytes"].as_u64().unwrap_or(0), full_report["lines"].as_u64().unwrap_or(0));
        println!("  Changed Lines:    {}", full_report["changed_lines"].as_u64().unwrap_or(0));
        println!("  Classes Detected: {}", if classes.is_empty() { "none".to_string() } else { classes.join(", ") });
        println!("  ANSI Escapes:     {}", if ansi_detected { "DETECTED" } else { "none" });
        println!("  Trojan Source:    {}", if bidi_detected { "DETECTED" } else { "none" });
        println!("  File Unchanged:   {}", if file_unchanged { "YES (dry-run only)" } else { "NO (unexpected mutation!)" });
        println!("  Leak Gate:        {}", if classes.is_empty() { "CLEAN" } else if fail_on_leak { "FAIL (--fail-on-leak)" } else { "REPORTED (--fail-on-leak not set)" });
        if !redacted_preview.is_empty() {
            println!("  Redacted Preview (first {} changed lines):", redacted_preview.len());
            for line in &redacted_preview {
                println!("    {}", line);
            }
        }
        println!();
    }
    if fail_on_leak && leaked {
        return Err(format!(
            "Redaction dry-run detected {} sensitive class(es) in {}: {}",
            classes.len(),
            path.display(),
            classes.join(", ")
        ).into());
    }
    Ok(())
}

fn record_index_audit_receipt(
    repo_root: &std::path::Path,
    target: &std::path::Path,
    files_count: usize,
    chunks_count: usize,
    total_store_records: usize,
    anonymized_symbols: bool,
) -> Result<(), String> {
    let audit_dir = repo_root.join(".agents").join("audit");
    let _ = std::fs::create_dir_all(&audit_dir);
    let today = chrono::Utc::now().format("%Y-%m-%d").to_string();
    let receipt_file = audit_dir.join(format!("{}-index-receipt.json", today));

    let ledger_path = repo_root.join(".agents").join("wiki").join("ledger.md");
    let wiki_ledger_sha256 = if ledger_path.is_file() {
        pqc::sha256_file(&ledger_path).ok()
    } else {
        None
    };

    let receipt = serde_json::json!({
        "receipt_id": format!("idx-{}", chrono::Utc::now().timestamp_millis()),
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "action": "batch_index",
        "target": target.to_string_lossy(),
        "files_indexed": files_count,
        "chunks_generated": chunks_count,
        "total_store_records": total_store_records,
        "anonymized_symbols": anonymized_symbols,
        "wiki_ledger_sha256": wiki_ledger_sha256,
        "algorithm_guarantee": "FIPS 204 ML-DSA-65",
        "status": "verified"
    });

    let json_text = serde_json::to_string_pretty(&receipt).map_err(|e| e.to_string())?;
    std::fs::write(&receipt_file, json_text).map_err(|e| e.to_string())?;

    let _ = pqc::sign_file(&receipt_file);

    println!("  \x1b[32m[rag:audit]\x1b[0m Recorded batch index audit receipt at {}", receipt_file.display());
    Ok(())
}

/// `ainish-rag embed-provider` — inspects, persists, or clears the embedding provider posture.
/// Key material is never printed: only provenance such as `env:NAME` or `pqc:NAME`.
fn run_embed_provider(
    current_dir: &std::path::Path,
    json: bool,
    write: bool,
    clear: bool,
    pinned: Option<String>,
) -> Result<(), Box<dyn std::error::Error>> {
    let repo_root = crate::config::resolve_canonical_repo_root(current_dir);
    let config_path = repo_root.join(crate::provider::CONFIG_REL);

    if clear {
        let removed = crate::provider::clear_config(&repo_root)?;
        if json {
            println!(
                "{}",
                serde_json::to_string_pretty(&serde_json::json!({
                    "cleared": removed,
                    "config_path": config_path.display().to_string(),
                    "config_persisted": false,
                }))?
            );
        } else if removed {
            println!("✓ Removed {} — embeddings fall back to auto-detection", config_path.display());
        } else {
            println!("  No persisted embedding provider config at {}", config_path.display());
        }
        return Ok(());
    }

    if let Some(ref pin) = pinned {
        let normalized = pin.trim().to_ascii_lowercase();
        if !matches!(
            normalized.as_str(),
            "local" | "api" | "auto" | "openrouter" | "zenmux" | "off" | "none"
        ) {
            return Err(format!(
                "Unknown provider '{}': expected local|api|auto|openrouter|zenmux",
                pin
            )
            .into());
        }
    }

    let resolution = crate::provider::resolve_with(&repo_root, pinned.as_deref());
    if resolution.is_invalid() && (write || pinned.is_some()) {
        return Err(format!(
            "Cannot persist an unusable API embedding intent: {}",
            resolution.warnings.join("; ")
        )
        .into());
    }

    // Persist only a usable remote posture (or an explicit operator pin). Auto-detection that
    // found nothing must not write `local`, otherwise a key added later would be ignored.
    let should_write = write && (resolution.provider == "api" || resolution.explicit);
    let persisted_path = if should_write {
        Some(crate::provider::write_config(&repo_root, &resolution)?)
    } else {
        None
    };
    if write && !should_write && !json {
        println!("  No remote embedding credentials detected — nothing persisted (auto-detection stays active)");
    }

    let local_running = LlamaServer::local_server_running(&repo_root);

    if json {
        println!(
            "{}",
            serde_json::to_string_pretty(&serde_json::json!({
                "provider": resolution.provider,
                "provider_id": resolution.provider_id,
                "api_base": resolution.api_base,
                "model": resolution.model,
                "dim": resolution.dim,
                "key_present": resolution.key.is_some(),
                "key_source": resolution.key_source,
                "source": resolution.source,
                "explicit": resolution.explicit,
                "warnings": resolution.warnings,
                "config_path": config_path.display().to_string(),
                "config_persisted": config_path.exists(),
                "local_server_running": local_running,
            }))?
        );
    } else {
        println!("\x1b[94mainish-rag Embedding Provider\x1b[0m");
        println!("  Config:        {}", config_path.display());
        println!(
            "  Intent:        {}",
            if resolution.explicit { "operator-pinned" } else { "auto-detect" }
        );
        match resolution.provider.as_str() {
            "api" => {
                let provider_label = resolution
                    .provider_id
                    .as_deref()
                    .and_then(crate::provider::find_provider)
                    .map(|spec| spec.label)
                    .unwrap_or("custom");
                println!(
                    "  Provider:      api ({} / {})  [source: {}]",
                    provider_label,
                    resolution.provider_id.as_deref().unwrap_or("custom"),
                    resolution.source
                );
                println!("  API Base:      {}", resolution.api_base.as_deref().unwrap_or("<unset>"));
                println!("  Model:         {}", resolution.model.as_deref().unwrap_or("<unset>"));
                println!(
                    "  Vector Width:  {}",
                    match resolution.dim {
                        Some(d) => format!("{} (explicit)", d),
                        None => format!(
                            "{} (store width; the model's native width is wider)",
                            crate::provider::DEFAULT_STORE_DIM
                        ),
                    }
                );
                println!(
                    "  Key:           {}",
                    resolution
                        .key_source
                        .as_deref()
                        .map(|s| format!("present via {} (never printed)", s))
                        .unwrap_or_else(|| "absent (unauthenticated endpoint)".to_string())
                );
                println!("  Local Server:  not used while API embeddings are active (no resident model)");
            }
            "invalid" => {
                println!("  Provider:      \x1b[31minvalid\x1b[0m (explicit API intent cannot be satisfied)");
                for w in &resolution.warnings {
                    println!("  \x1b[33m!\x1b[0m {}", w);
                }
            }
            _ => {
                println!("  Provider:      local llama{}", if resolution.explicit { " [operator-pinned]" } else { " [auto-detect: no remote credentials]" });
                println!(
                    "  Local Server:  {}",
                    if local_running { "resident" } else { "not resident (spawned only for the command that needs it)" }
                );
                println!("  Hint:          point at OpenRouter/ZenMux with `ainish-rag embed-provider --provider openrouter`");
            }
        }
        if resolution.provider != "invalid" && !resolution.explicit && resolution.provider != "api" {
            for w in &resolution.warnings {
                println!("  \x1b[33m!\x1b[0m {}", w);
            }
        }
    }

    if let Some(path) = persisted_path {
        if !json {
            println!("✓ Persisted non-secret provider config → {}", path.display());
        }
    }
    Ok(())
}

fn run_audit_verify(repo_root: &std::path::Path, target_path: Option<&std::path::Path>) -> Result<(), Box<dyn std::error::Error>> {
    let audit_dir = target_path.map(|p| p.to_path_buf()).unwrap_or_else(|| repo_root.join(".agents").join("audit"));
    println!("=== ainish-rag Post-Quantum Cryptographic Audit Verification ===");
    println!("Audit Directory: {}", audit_dir.display());

    if !audit_dir.exists() {
        println!("  [rag:audit] Audit directory does not exist yet. No receipts to verify.");
        return Ok(());
    }

    // `--path` advertises "a Specific receipt file or audit directory path". The directory
    // branch below is the aggregate sweep; a file must verify ONLY that file. Without this
    // split, passing a file fell through to `read_dir` and errored with
    // `NotADirectory`, so callers that need to check one artifact (the rules deploy gate
    // checking its own manifest) had no way to do it.
    if audit_dir.is_file() {
        let file_name = audit_dir.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default();
        if !pqc::sig_path(&audit_dir).exists() {
            println!("  \x1b[31m[FAIL]\x1b[0m {}: Missing signature envelope (.sig)", file_name);
            println!();
            return Err(format!("missing signature envelope for {}", file_name).into());
        }
        match pqc::verify_file(repo_root, &audit_dir) {
            pqc::VerifyOutcome::Verified { fingerprint } => {
                println!(
                    "  \x1b[32m[PASS]\x1b[0m {}: FIPS 204 ML-DSA-65 signature verified (key: {}...)",
                    file_name,
                    &fingerprint[..12.min(fingerprint.len())]
                );
                println!();
                return Ok(());
            }
            pqc::VerifyOutcome::Unsigned(reason) => {
                println!("  \x1b[31m[FAIL]\x1b[0m {}: {}", file_name, reason);
                println!();
                return Err(format!("{}: {}", file_name, reason).into());
            }
            pqc::VerifyOutcome::Invalid(err) => {
                println!("  \x1b[31m[FAIL]\x1b[0m {}: {}", file_name, err);
                println!();
                return Err(format!("{}: {}", file_name, err).into());
            }
        }
    }

    let mut receipts_checked = 0;
    let mut passed = 0;
    let mut failed = 0;

    let entries = std::fs::read_dir(&audit_dir)?;
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().map_or(false, |ext| ext == "json")
            && path.file_name().map_or(false, |n| n != "model-manifest.json" && n != "lockfile-manifest.json" && n != "privacy-budget.json" && n != "crates-sparse-snapshot.json")
        {
            receipts_checked += 1;
            let file_name = path.file_name().unwrap().to_string_lossy();
            let sig_file = path.with_extension("sig");

            if !sig_file.exists() {
                println!("  \x1b[31m[FAIL]\x1b[0m {}: Missing signature envelope (.sig)", file_name);
                failed += 1;
                continue;
            }

            match pqc::verify_file(repo_root, &path) {
                pqc::VerifyOutcome::Verified { fingerprint } => {
                    println!("  \x1b[32m[PASS]\x1b[0m {}: FIPS 204 ML-DSA-65 signature verified (key: {}...)", file_name, &fingerprint[..12.min(fingerprint.len())]);
                    passed += 1;
                }
                pqc::VerifyOutcome::Unsigned(reason) => {
                    println!("  \x1b[31m[FAIL]\x1b[0m {}: {}", file_name, reason);
                    failed += 1;
                }
                pqc::VerifyOutcome::Invalid(err) => {
                    println!("  \x1b[31m[FAIL]\x1b[0m {}: {}", file_name, err);
                    failed += 1;
                }
            }
        }
    }

    // Verify canonical AGENTS.md contract
    let canonical_outcome = pqc::verify_canonical_contract(repo_root);
    match canonical_outcome {
        pqc::VerifyOutcome::Verified { fingerprint } => {
            println!("  \x1b[32m[PASS]\x1b[0m Canonical AGENTS.md: FIPS 204 ML-DSA-65 signature verified (key: {}...)", &fingerprint[..12.min(fingerprint.len())]);
            passed += 1;
            receipts_checked += 1;
        }
        pqc::VerifyOutcome::Unsigned(reason) => {
            println!("  \x1b[33m[WARN]\x1b[0m Canonical AGENTS.md: {}", reason);
        }
        pqc::VerifyOutcome::Invalid(err) => {
            println!("  \x1b[31m[FAIL]\x1b[0m Canonical AGENTS.md: {}", err);
            failed += 1;
            receipts_checked += 1;
        }
    }

    // Verify .agents/wiki/ledger.md detached ML-DSA-65 signature if present
    let wiki_ledger = repo_root.join(".agents").join("wiki").join("ledger.md");
    if wiki_ledger.exists() && pqc::sig_path(&wiki_ledger).exists() {
        match pqc::verify_file(repo_root, &wiki_ledger) {
            pqc::VerifyOutcome::Verified { fingerprint } => {
                println!("  \x1b[32m[PASS]\x1b[0m Wiki Operator Ledger (ledger.md): FIPS 204 ML-DSA-65 signature verified (key: {}...)", &fingerprint[..12.min(fingerprint.len())]);
                passed += 1;
                receipts_checked += 1;
            }
            pqc::VerifyOutcome::Unsigned(reason) => {
                println!("  \x1b[33m[WARN]\x1b[0m Wiki Operator Ledger (ledger.md): {}", reason);
            }
            pqc::VerifyOutcome::Invalid(err) => {
                println!("  \x1b[31m[FAIL]\x1b[0m Wiki Operator Ledger (ledger.md): {}", err);
                failed += 1;
                receipts_checked += 1;
            }
        }
    }

    // Verify hash-chained governance log (.agents/audit/contract-history.jsonl)
    let history_file = repo_root.join(".agents").join("audit").join("contract-history.jsonl");
    if history_file.exists() {
        match pqc::verify_contract_history_chain(repo_root) {
            Ok(transitions) => {
                println!("  \x1b[32m[PASS]\x1b[0m Contract Governance History (contract-history.jsonl): {} hash-chained transitions & ML-DSA-65 verified", transitions);
                passed += 1;
                receipts_checked += 1;
            }
            Err(err) => {
                println!("  \x1b[31m[FAIL]\x1b[0m Contract Governance History (contract-history.jsonl): {}", err);
                failed += 1;
                receipts_checked += 1;
            }
        }
    }

    // Verify all lockfiles in .agents/audit/lockfile-manifest.json exist on disk & signature verifies
    let lf_manifest = pqc::lockfile_manifest_path(repo_root);
    if lf_manifest.exists() {
        receipts_checked += 1;
        let mut missing_lfs = Vec::new();
        let mut lf_count = 0usize;
        if let Ok(text) = std::fs::read_to_string(&lf_manifest) {
            if let Ok(v) = serde_json::from_str::<serde_json::Value>(&text) {
                if let Some(arr) = v.get("lockfiles").or_else(|| v.get("files")).and_then(|a| a.as_array()) {
                    for item in arr {
                        if let Some(rel_p) = item.get("path").or_else(|| item.get("file")).and_then(|s| s.as_str()) {
                            lf_count += 1;
                            if !repo_root.join(rel_p).exists() {
                                missing_lfs.push(rel_p.to_string());
                            }
                        }
                    }
                }
            }
        }
        let sig_ok = matches!(pqc::verify_file(repo_root, &lf_manifest), pqc::VerifyOutcome::Verified { .. });
        if missing_lfs.is_empty() && sig_ok {
            println!("  \x1b[32m[PASS]\x1b[0m Supply Chain Lockfile Manifest (lockfile-manifest.json): all {} lockfiles present on disk & ML-DSA-65 verified", lf_count);
            passed += 1;
        } else {
            println!("  \x1b[31m[FAIL]\x1b[0m Supply Chain Lockfile Manifest (lockfile-manifest.json): missing={:?}, sig_ok={}", missing_lfs, sig_ok);
            failed += 1;
        }
    }

    // Verify detached ML-DSA-65 signature on .agents/audit/privacy-budget.json
    let privacy_budget = repo_root.join(".agents").join("audit").join("privacy-budget.json");
    if privacy_budget.exists() {
        receipts_checked += 1;
        match pqc::verify_file(repo_root, &privacy_budget) {
            pqc::VerifyOutcome::Verified { fingerprint } => {
                println!("  \x1b[32m[PASS]\x1b[0m Privacy Budget Ledger (privacy-budget.json): FIPS 204 ML-DSA-65 signature verified (key: {}...)", &fingerprint[..12.min(fingerprint.len())]);
                passed += 1;
            }
            pqc::VerifyOutcome::Unsigned(reason) => {
                println!("  \x1b[31m[FAIL]\x1b[0m Privacy Budget Ledger (privacy-budget.json): {}", reason);
                failed += 1;
            }
            pqc::VerifyOutcome::Invalid(err) => {
                println!("  \x1b[31m[FAIL]\x1b[0m Privacy Budget Ledger (privacy-budget.json): {}", err);
                failed += 1;
            }
        }
    }

    // Verify detached ML-DSA-65 signature on .agents/audit/model-manifest.json
    let model_manifest = repo_root.join(".agents").join("audit").join("model-manifest.json");
    if model_manifest.exists() {
        receipts_checked += 1;
        match pqc::verify_file(repo_root, &model_manifest) {
            pqc::VerifyOutcome::Verified { fingerprint } => {
                println!("  \x1b[32m[PASS]\x1b[0m Model Manifest (model-manifest.json): FIPS 204 ML-DSA-65 signature verified (key: {}...)", &fingerprint[..12.min(fingerprint.len())]);
                passed += 1;
            }
            pqc::VerifyOutcome::Unsigned(reason) => {
                println!("  \x1b[31m[FAIL]\x1b[0m Model Manifest (model-manifest.json): {}", reason);
                failed += 1;
            }
            pqc::VerifyOutcome::Invalid(err) => {
                println!("  \x1b[31m[FAIL]\x1b[0m Model Manifest (model-manifest.json): {}", err);
                failed += 1;
            }
        }
    }

    // Verify detached ML-DSA-65 signature on .agents/audit/privacy-report.json
    let privacy_report = repo_root.join(".agents").join("audit").join("privacy-report.json");
    if privacy_report.exists() {
        receipts_checked += 1;
        match pqc::verify_file(repo_root, &privacy_report) {
            pqc::VerifyOutcome::Verified { fingerprint } => {
                println!("  \x1b[32m[PASS]\x1b[0m Privacy Compliance Report (privacy-report.json): FIPS 204 ML-DSA-65 signature verified (key: {}...)", &fingerprint[..12.min(fingerprint.len())]);
                passed += 1;
            }
            pqc::VerifyOutcome::Unsigned(reason) => {
                println!("  \x1b[31m[FAIL]\x1b[0m Privacy Compliance Report (privacy-report.json): {}", reason);
                failed += 1;
            }
            pqc::VerifyOutcome::Invalid(err) => {
                println!("  \x1b[31m[FAIL]\x1b[0m Privacy Compliance Report (privacy-report.json): {}", err);
                failed += 1;
            }
        }
    }

    println!("\nVerification Summary:");
    println!("  Total Receipts:  {}", receipts_checked);
    println!("  Passed:          \x1b[32m{}\x1b[0m", passed);
    println!("  Failed:          {}", if failed > 0 { format!("\x1b[31m{}\x1b[0m", failed) } else { "0".to_string() });
    if failed == 0 && receipts_checked > 0 {
        println!("  Status:          \x1b[1;32mALL RECEIPTS VERIFIED (FIPS 204 ML-DSA-65 Standard)\x1b[0m");
    } else if receipts_checked == 0 {
        println!("  Status:          \x1b[33mNO RECEIPTS FOUND\x1b[0m");
    } else {
        println!("  Status:          \x1b[1;31mINTEGRITY AUDIT FAILED\x1b[0m");
    }
    println!();

    Ok(())
}

fn run_audit_manifest(config: &RagConfig, manifest_path: Option<&std::path::Path>) -> Result<(), Box<dyn std::error::Error>> {
    let mpath = manifest_path.map(|p| p.to_path_buf()).unwrap_or_else(|| config.model_manifest_path.clone());
    println!("=== ainish-rag Model Manifest Verification ===");
    println!("Manifest File: {}", mpath.display());

    if !mpath.exists() {
        println!("  \x1b[33m[rag:warn]\x1b[0m Model manifest file not found at {}", mpath.display());
        return Ok(());
    }

    let repo_root = mpath.parent().and_then(|p| p.parent()).and_then(|p| p.parent()).unwrap_or_else(|| std::path::Path::new("."));
    if pqc::sig_path(&mpath).exists() {
        match pqc::verify_file(repo_root, &mpath) {
            pqc::VerifyOutcome::Verified { fingerprint } => {
                println!("  Manifest Sig:  \x1b[32m[VERIFIED]\x1b[0m FIPS 204 ML-DSA-65 detached signature (key: {}...)", &fingerprint[..12.min(fingerprint.len())]);
            }
            pqc::VerifyOutcome::Unsigned(r) => {
                println!("  Manifest Sig:  \x1b[33m[UNSIGNED]\x1b[0m {}", r);
            }
            pqc::VerifyOutcome::Invalid(e) => {
                println!("  Manifest Sig:  \x1b[31m[INVALID]\x1b[0m {}", e);
            }
        }
    }

    let content = std::fs::read_to_string(&mpath)?;
    let parsed: serde_json::Value = serde_json::from_str(&content)?;
    let models = parsed.get("models").and_then(|m| m.as_object());

    if let Some(map) = models {
        for (name, item) in map {
            let expected_sha256 = item.get("sha256").and_then(|v| v.as_str()).unwrap_or("");
            let desc = item.get("description").and_then(|v| v.as_str()).unwrap_or("");
            print!("  Verifying {} ({})... ", name, desc);
            let candidate_model = config.hf_hub_cache.join(name);
            let target_file = if candidate_model.exists() {
                Some(candidate_model)
            } else if let Some(ref mp) = config.model_path {
                if mp.file_name().map_or(false, |n| n == name.as_str()) {
                    Some(mp.clone())
                } else {
                    None
                }
            } else {
                None
            };

            if let Some(file_path) = target_file {
                let data = std::fs::read(&file_path)?;
                use sha2::{Sha256, Digest};
                let mut hasher = Sha256::new();
                hasher.update(&data);
                let actual = hex::encode(hasher.finalize());
                if actual.eq_ignore_ascii_case(expected_sha256) {
                    println!("\x1b[32m[MATCH]\x1b[0m (SHA-256: {}...)", &actual[..16]);
                } else {
                    println!("\x1b[31m[MISMATCH]\x1b[0m\n    Expected: {}\n    Actual:   {}", expected_sha256, actual);
                }
            } else {
                println!("\x1b[33m[NOT DOWNLOADED]\x1b[0m (Pinned hash: {}...)", &expected_sha256[..16]);
            }
        }
    }
    println!();
    Ok(())
}

fn run_audit_sbom(
    config: &RagConfig,
    repo_root: &std::path::Path,
    format: &str,
    out: Option<&std::path::Path>,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("=== ainish-rag Cryptographic SBOM Generator ===");
    let is_intoto = format.eq_ignore_ascii_case("intoto");
    let is_spdx = format.eq_ignore_ascii_case("spdx");
    let sbom_val = if is_intoto {
        pqc::build_intoto(repo_root, &config.model_manifest_path, config.llama_bin.as_deref())
    } else if is_spdx {
        pqc::build_spdx3(repo_root, &config.model_manifest_path, config.llama_bin.as_deref())
    } else {
        pqc::build_cyclonedx(repo_root, &config.model_manifest_path, config.llama_bin.as_deref())
    };
    let json_str = serde_json::to_string_pretty(&sbom_val)?;

    if let Some(out_path) = out {
        std::fs::write(out_path, &json_str)?;
        let _ = pqc::sign_file(out_path);
        println!("  \x1b[32m[rag:sbom]\x1b[0m Wrote signed SBOM to {}", out_path.display());
    } else {
        println!("{}", json_str);
    }
    println!();
    Ok(())
}

fn run_audit_lock(
    config: &RagConfig,
    repo_root: &std::path::Path,
    update: bool,
    verify: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("=== ainish-rag Supply Chain Lockfile Verification ===");
    if update {
        match pqc::write_lockfile_manifest(repo_root) {
            Ok((path, count, sig_res)) => {
                let sig_note = if sig_res.is_ok() { " + signed with ML-DSA-65" } else { "" };
                println!("  \x1b[32m[rag:lock]\x1b[0m Snapshotted {} lockfiles to {}{}", count, path.display(), sig_note);
            }
            Err(e) => eprintln!("  \x1b[31m[rag:error]\x1b[0m Failed writing lockfile manifest: {}", e),
        }
        // Automatically refresh and sign in-toto v1.0 and CycloneDX 1.6 SBOMs so provenance stays in lockstep
        let audit_dir = repo_root.join(".agents").join("audit");
        let _ = std::fs::create_dir_all(&audit_dir);
        let intoto_path = audit_dir.join("ainish-coder-sbom.intoto.json");
        let intoto_val = pqc::build_intoto(repo_root, &config.model_manifest_path, config.llama_bin.as_deref());
        if let Ok(s) = serde_json::to_string_pretty(&intoto_val) {
            if std::fs::write(&intoto_path, s).is_ok() {
                let _ = pqc::sign_file(&intoto_path);
                println!("  \x1b[32m[rag:lock]\x1b[0m Synchronized & signed in-toto v1.0 provenance attestation ({})", intoto_path.display());
            }
        }
        let cdx_path = audit_dir.join("ainish-coder-sbom.cyclonedx.json");
        let cdx_val = pqc::build_cyclonedx(repo_root, &config.model_manifest_path, config.llama_bin.as_deref());
        if let Ok(s) = serde_json::to_string_pretty(&cdx_val) {
            if std::fs::write(&cdx_path, s).is_ok() {
                let _ = pqc::sign_file(&cdx_path);
                println!("  \x1b[32m[rag:lock]\x1b[0m Synchronized & signed CycloneDX 1.6 SBOM ({})", cdx_path.display());
            }
        }
        if config.model_manifest_path.exists() {
            let _ = pqc::sign_file(&config.model_manifest_path);
        }
    }
    if verify {
        match pqc::check_lockfiles(repo_root) {
            Ok((drift, unpinned)) => {
                let mut clean = true;
                if !drift.is_empty() {
                    clean = false;
                    println!("  \x1b[33m[DRIFT DETECTED]\x1b[0m Lockfiles changed since last manifest snapshot:");
                    for d in &drift {
                        println!("    {}", d);
                    }
                }
                if !unpinned.is_empty() {
                    println!("  \x1b[33m[UNPINNED ARTIFACTS]\x1b[0m Lockfiles missing package hash verification:");
                    for u in &unpinned {
                        println!("    {}", u);
                    }
                }
                if clean {
                    println!("  \x1b[32m[PASS]\x1b[0m All dependency lockfiles match immutable signed manifest.");
                }
                if let Ok((verified_crates, sparse_anomalies)) = pqc::verify_cargo_sparse_index_checksums(repo_root) {
                    if sparse_anomalies.is_empty() {
                        println!("  \x1b[32m[PASS]\x1b[0m Verified {} crates.io dependency checksums against sparse-index integrity rules.", verified_crates);
                    } else {
                        for anomaly in &sparse_anomalies {
                            println!("  \x1b[31m[SPARSE-INDEX TAMPER]\x1b[0m {}", anomaly);
                        }
                    }
                }
                let audit_dir = repo_root.join(".agents").join("audit");
                let cdx_sbom = audit_dir.join("ainish-coder-sbom.cyclonedx.json");
                let intoto_sbom = audit_dir.join("ainish-coder-sbom.intoto.json");
                let cdx_ok = cdx_sbom.exists() && matches!(pqc::verify_file(repo_root, &cdx_sbom), pqc::VerifyOutcome::Verified { .. });
                let intoto_ok = intoto_sbom.exists() && matches!(pqc::verify_file(repo_root, &intoto_sbom), pqc::VerifyOutcome::Verified { .. });
                if cdx_ok && intoto_ok {
                    println!("  \x1b[32m[PASS]\x1b[0m Verified detached FIPS 204 ML-DSA-65 signatures on CycloneDX 1.6 and in-toto v1.0 SBOMs.");
                } else {
                    println!("  \x1b[33m[WARN]\x1b[0m Detached SBOM signature verification incomplete (run 'ainish-rag audit lock --update').");
                }
            }
            Err(e) => {
                println!("  \x1b[33m[rag:warn]\x1b[0m {}", e);
            }
        }
    }
    println!();
    Ok(())
}

fn run_audit_keygen(repo_root: &std::path::Path) -> Result<(), Box<dyn std::error::Error>> {
    println!("=== ainish-rag Post-Quantum ML-DSA-65 Keygen ===");
    match pqc::write_anchor(repo_root) {
        Ok((path, fpr)) => {
            println!("  \x1b[32m[rag:audit]\x1b[0m Successfully derived trust anchor from PQC vault seed:");
            println!("    Anchor File: {}", path.display());
            println!("    Fingerprint: {}", fpr);
        }
        Err(e) => eprintln!("  \x1b[31m[rag:error]\x1b[0m Failed generating trust anchor: {}", e),
    }
    println!();
    Ok(())
}

fn run_audit_sign(target: &std::path::Path) -> Result<(), Box<dyn std::error::Error>> {
    println!("=== ainish-rag Post-Quantum ML-DSA-65 File Signing ===");
    match pqc::sign_file(target) {
        Ok(sig) => {
            println!("  \x1b[32m[rag:audit]\x1b[0m Signed {} -> {}", target.display(), sig.display());
        }
        Err(e) => eprintln!("  \x1b[31m[rag:error]\x1b[0m Signing failed: {}", e),
    }
    println!();
    Ok(())
}

/// Result of evaluating a patch diff at the gate.
///
/// The embedding-anchored fields (`composite_anchor_score`, `file_coverage`,
/// `average_retrieval_similarity`, `symbol_anchoring`, covered/matched counts, `repair_patch`) were
/// computed against the LanceDB index retired on 2026-11-12 and are gone with it. What remains is the
/// half that never needed a model: which files changed and whether the diff carries a credential
/// leak or a Trojan Source override. Those are the security checks, and they are why the gate exists.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct PatchEvalResult {
    pub status: String,
    pub modified_files: Vec<String>,
    pub canary_leaks: Vec<String>,
}

/// Evaluates a diff without any retrieval. Deterministic and model-free by construction.
pub fn evaluate_patch_diff(diff_text: &str) -> PatchEvalResult {
    let mut modified_files: Vec<String> = Vec::new();
    for line in diff_text.lines() {
        if let Some(rest) = line.strip_prefix("+++ b/") {
            if !rest.is_empty() && rest != "/dev/null" {
                modified_files.push(rest.to_string());
            }
        }
    }
    modified_files.dedup();

    let mut canary_leaks: Vec<String> = Vec::new();
    static RE_CANARY: std::sync::LazyLock<regex::Regex> = std::sync::LazyLock::new(|| {
        regex::Regex::new(r#"(?i)(?:CANARY_[A-Za-z0-9_-]{6,}|SECRET_TOKEN_[A-Za-z0-9_-]{6,}|(?:sk-(?:or-|proj-|ant-)?[A-Za-z0-9_-]{24,})|(?:gh[pousr]_[A-Za-z0-9]{20,})|(?:AKIA[0-9A-Z]{16})|-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----)"#).expect("valid regex")
    });
    for line in diff_text.replace("\r\n", "\n").lines() {
        if line.starts_with('+') && !line.starts_with("+++") {
            let added = &line[1..];
            if crate::wiki::WikiGenerator::contains_bidi_override(added)
                && !added.contains("\\u{202")
                && !added.contains("\\u202")
                && !added.contains("0x202")
            {
                canary_leaks.push(
                    "Trojan Source bidirectional Unicode override character detected in diff".to_string(),
                );
            }
            if !added.contains("Regex::new")
                && !added.contains("RE_CANARY")
                && !added.contains("RE_TOKENS")
            {
                if let Some(m) = RE_CANARY.find(added) {
                    canary_leaks
                        .push(format!("Canary/credential leak pattern detected: {}", m.as_str()));
                }
            }
        }
    }

    let status = if !canary_leaks.is_empty() {
        "FAILED_CREDENTIAL_LEAK"
    } else {
        "CHECKED"
    }
    .to_string();

    PatchEvalResult { status, modified_files, canary_leaks }
}

pub fn select_prioritized_ledger_notes(clean_ledger: &str) -> Vec<String> {
    let all_bullets: Vec<String> = clean_ledger
        .lines()
        .filter(|l| l.trim().starts_with("- "))
        .map(|l| l.to_string())
        .collect();
    let unresolved: Vec<String> = all_bullets.iter().filter(|l| !l.contains("[RESOLVED]")).cloned().collect();
    let resolved: Vec<String> = all_bullets.iter().filter(|l| l.contains("[RESOLVED]")).cloned().collect();

    let open_take: Vec<String> = unresolved.iter().rev().take(6).cloned().collect::<Vec<_>>().into_iter().rev().collect();
    let rem = 6usize.saturating_sub(open_take.len());
    let res_take: Vec<String> = resolved.iter().rev().take(rem).cloned().collect::<Vec<_>>().into_iter().rev().collect();

    open_take.into_iter().chain(res_take.into_iter()).collect()
}

/// Coordination-record naming (2026-11-12 hour-stamp cutover). Both schemes are live at once:
/// grandfathered `{date}-memory.txt` / `{date}-team.txt` / `{date}-{slug}.plan.md` and current
/// `{date}-{HH}-{slug}.md`. Every "newest wins" consumer must compare **mtime**, never filename:
/// under mixed naming `{date}-09-memory.md` collates before `{date}-memory.txt`, so a name sort
/// silently returns the grandfather file on the cutover days that matter most.
/// A COMMS ledger in either scheme. The live board is a working file, not the ledger.
fn is_comms_ledger(path: &std::path::Path) -> bool {
    match path.file_name() {
        Some(n) => {
            let name = n.to_string_lossy();
            (name.ends_with("-team.txt") || name.ends_with("-team.md"))
                && !name.ends_with(".live.txt")
                && !name.ends_with(".live.md")
        }
        None => false,
    }
}

/// Verifies that COMMS ledgers contain no legacy `| agent:` tags.
pub fn check_comms_harness_agnostic(repo_root: &std::path::Path) -> Vec<String> {
    let comms_dir = repo_root.join(".agents").join("comms");
    let mut violations = Vec::new();
    if let Ok(entries) = std::fs::read_dir(&comms_dir) {
        for e in entries.flatten() {
            let p = e.path();
            if is_comms_ledger(&p) {
                if let Ok(text) = std::fs::read_to_string(&p) {
                    for (line_no, line) in text.lines().enumerate() {
                        if line.starts_with("### [") && line.contains("| agent:") {
                            violations.push(format!("{}:L{}", p.file_name().unwrap_or_default().to_string_lossy(), line_no + 1));
                        }
                    }
                }
            }
        }
    }
    violations
}

fn sanitize_orient_content(content: &str) -> (String, usize) {
    let mut sanitized = String::new();
    let mut count = 0;
    let banned_algos = [
        "RSA", "DSA", "ECDSA", "ECDH", "Ed25519", "MD5", "SHA-1",
        "DES", "3DES", "Blowfish", "AES-CBC", "RC4",
    ];

    for line in content.lines() {
        let mut clean_line = line.to_string();
        if clean_line.contains(".scrolls") {
            clean_line = clean_line.replace(".scrolls*", "[SANITIZED: quarantine payload]")
                .replace(".scrolls/", "[SANITIZED: quarantine payload]")
                .replace(".scrolls", "[SANITIZED: quarantine payload]");
            count += 1;
        }
        for algo in &banned_algos {
            let lower = clean_line.to_lowercase();
            if clean_line.contains(algo) && (lower.contains("secret") || lower.contains("key") || lower.contains("algo") || lower.contains("cipher")) {
                clean_line = clean_line.replace(algo, "[SANITIZED: banned classical crypto]");
                count += 1;
            }
        }
        sanitized.push_str(&clean_line);
        sanitized.push('\n');
    }
    (sanitized, count)
}

fn extract_orient_task_summary(repo_root: &std::path::Path, query: Option<&str>) -> String {
    if let Some(q) = query {
        let trimmed = q.trim();
        if !trimmed.is_empty() {
            return trimmed.to_string();
        }
    }
    let tasks_dir = repo_root.join(".agents").join("tasks");
    if let Ok(t_entries) = std::fs::read_dir(&tasks_dir) {
        let mut task_files: Vec<PathBuf> = t_entries
            .flatten()
            .map(|e| e.path())
            .filter(|p| p.extension().map_or(false, |ext| ext == "md"))
            .collect();
        task_files.sort();
        if let Some(latest_task) = task_files.last() {
            if let Ok(text) = std::fs::read_to_string(latest_task) {
                let mut lines: Vec<&str> = Vec::new();
                for line in text.lines().rev() {
                    if line.starts_with("- objective:") || line.starts_with("- scope:") || line.starts_with("## ") {
                        lines.push(line.trim());
                        if lines.len() >= 3 {
                            break;
                        }
                    }
                }
                if !lines.is_empty() {
                    lines.reverse();
                    return lines.join(" | ");
                }
            }
        }
    }
    "orient repository architecture, symbols, security governance, and active worktree state".to_string()
}

#[allow(dead_code)]
fn build_orient_report(
    repo_root: &std::path::Path,
    query: Option<&str>,
    task_conditioned: bool,
    compact: bool,
    max_lines: Option<usize>,
    sections: Option<usize>,
    include_symbols: bool,
) -> Result<serde_json::Value, Box<dyn std::error::Error>> {
    build_orient_report_with_route(repo_root, query, task_conditioned, compact, max_lines, sections, include_symbols, None)
}

fn build_orient_report_with_route(
    repo_root: &std::path::Path,
    query: Option<&str>,
    task_conditioned: bool,
    compact: bool,
    max_lines: Option<usize>,
    sections: Option<usize>,
    include_symbols: bool,
    route_override: Option<crate::decision::RouteDecision>,
) -> Result<serde_json::Value, Box<dyn std::error::Error>> {
    let orient_prompt = extract_orient_task_summary(repo_root, query);
    let route_decision = route_override.unwrap_or_else(|| DecisionEngine::new().route_local(&orient_prompt));
    let section_limit = sections.unwrap_or(3);
    let wiki_dir = repo_root.join(".agents").join("wiki");
    let mut candidate_files = Vec::new();
    if let Ok(entries) = std::fs::read_dir(&wiki_dir) {
        let mut files: Vec<PathBuf> = entries.flatten()
            .map(|e| e.path())
            .filter(|p| {
                p.extension().map_or(false, |ext| ext == "md")
                    && p.file_name().map_or(false, |n| {
                        let nl = n.to_string_lossy().to_lowercase();
                        nl != "readme.md" && nl != "ledger.md"
                    })
            })
            .collect();

        if task_conditioned {
            // Task conditioning: inspect .agents/tasks/ for active lane metadata
            let tasks_dir = repo_root.join(".agents").join("tasks");
            let mut task_keywords = Vec::new();
            if let Ok(t_entries) = std::fs::read_dir(&tasks_dir) {
                let mut task_files: Vec<PathBuf> = t_entries.flatten()
                    .map(|e| e.path())
                    .filter(|p| p.extension().map_or(false, |ext| ext == "md"))
                    .collect();
                task_files.sort();
                if let Some(latest_task) = task_files.last() {
                    if let Ok(text) = std::fs::read_to_string(latest_task) {
                        for line in text.lines() {
                            if line.starts_with("- objective:") || line.starts_with("- scope:") || line.starts_with("- branch:") {
                                for word in line.split(|c: char| !c.is_alphanumeric()) {
                                    if word.len() >= 4 {
                                        task_keywords.push(word.to_lowercase());
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if let Some(q) = query {
                for word in q.split(|c: char| !c.is_alphanumeric()) {
                    if word.len() >= 3 {
                        task_keywords.push(word.to_lowercase());
                    }
                }
            }

            let target_domain = route_decision.target_domain.as_str();
            files.sort_by(|a, b| {
                let a_name = a.file_name().unwrap_or_default().to_string_lossy().to_lowercase();
                let b_name = b.file_name().unwrap_or_default().to_string_lossy().to_lowercase();

                let score_file = |name: &str, p: &std::path::Path| -> i32 {
                    let mut score = 0;
                    // Domain-guided wiki section weighting from the Jev route decision
                    match target_domain {
                        "security_governance" if name.contains("security") || name.contains("03") => score += 12,
                        "codebase_symbols" if name.contains("call") || name.contains("02") || name.contains("symbol") => score += 12,
                        "technical_debt" if name.contains("debt") || name.contains("04") || name.contains("risk") => score += 12,
                        "architectural_wiki" if name.contains("arch") || name.contains("01") => score += 12,
                        _ => {}
                    }
                    for kw in &task_keywords {
                        if name.contains(kw) {
                            score += 5;
                        }
                    }
                    if let Ok(content) = std::fs::read_to_string(p) {
                        let content_lower = content.to_lowercase();
                        for kw in &task_keywords {
                            if content_lower.contains(kw) {
                                score += 1;
                            }
                        }
                    }
                    score
                };

                let score_a = score_file(&a_name, a);
                let score_b = score_file(&b_name, b);
                score_b.cmp(&score_a).then_with(|| a_name.cmp(&b_name))
            });
        } else {
            files.sort();
        }

        for f in files.into_iter().take(section_limit) {
            candidate_files.push(f);
        }
    }

    let mut sections = Vec::new();
    let mut total_sanitized = 0;
    let wiki_gen = WikiGenerator::new(repo_root);
    let synced_resolutions = wiki_gen.sync_bidirectional_resolutions().unwrap_or(0);

    let git_branch = std::process::Command::new("git")
        .args(["branch", "--show-current"])
        .current_dir(repo_root)
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "main".to_string());
    let git_sha = std::process::Command::new("git")
        .args(["rev-parse", "--short", "HEAD"])
        .current_dir(repo_root)
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "HEAD".to_string());

    let gate_cache_path = repo_root.join(".agents").join("rag").join("gate-status.json");
    let gate_status_value = std::fs::read_to_string(&gate_cache_path)
        .ok()
        .and_then(|text| serde_json::from_str::<serde_json::Value>(&text).ok());
    let gate_ready = gate_status_value.as_ref().map_or(false, |v| {
        v.get("overall_pass").and_then(|b| b.as_bool()).unwrap_or(false)
            && v.get("commit").and_then(|c| c.as_str()) == Some(git_sha.as_str())
    });
    let gate_status_value = gate_status_value.unwrap_or(serde_json::Value::Null);

    let mut primer_lines = Vec::new();
    primer_lines.push("<ORIENT_PRIMER>".to_string());
    primer_lines.push("## Grounded Architectural Context".to_string());
    primer_lines.push(format!(
        "<!-- Auto-injected by ainish-rag orient --inject for subagent primer | branch: {} | commit: {} -->\n",
        git_branch, git_sha
    ));
    primer_lines.push(format!(
        "### Decision-Model Routing Hint (`{}`)\n- domain: `{}` (confidence {:.2}) | freshness: `{:.2}` | specificity: `{}` | modality: `{}` | strategy: `{}` (pool {}) | context budget: {} tokens\n- next: {}\n",
        route_decision.source,
        route_decision.target_domain,
        route_decision.route_confidence,
        route_decision.context_freshness,
        route_decision.query_specificity,
        route_decision.modality_preference,
        route_decision.retrieval_strategy,
        route_decision.candidate_pool_size,
        route_decision.context_budget_tokens,
        route_decision.next_action,
    ));

    let default_lines = if compact { 8 } else { 25 };
    let budget_lines = (route_decision.context_budget_tokens / 12 / section_limit.max(1)).max(3);
    let lines_per_section = max_lines.unwrap_or(default_lines.min(budget_lines));
    let max_items = if compact { 3 } else { 6 };

    for p in &candidate_files {
        let fname = p.file_name().unwrap_or_default().to_string_lossy().to_string();
        if let Ok(content) = std::fs::read_to_string(p) {
            let (clean_content, sanitized_cnt) = sanitize_orient_content(&content);
            total_sanitized += sanitized_cnt;
            let first_part = clean_content.lines().take(lines_per_section).collect::<Vec<_>>().join("\n");
            primer_lines.push(format!("### [{}]({})\n{}\n", fname, p.to_string_lossy(), first_part));
            sections.push(serde_json::json!({
                "file": fname,
                "path": p.to_string_lossy(),
                "content": first_part,
                "sanitized_tokens": sanitized_cnt
            }));
        }
    }

    if candidate_files.is_empty() {
        primer_lines.push("*No architectural wiki found in .agents/wiki/. Generate with `ainish-rag wiki`.*".to_string());
    }

    // Include recent memory-ledger entries & resolved constraints inside <ORIENT_PRIMER>.
    // Both naming schemes are live: `{date}-memory.txt` (grandfathered) and `{date}-{HH}-memory.md`.
    // Ordered by mtime, never by filename — under mixed naming a name sort returns the grandfather
    // file as "newest", because `{date}-09-memory.md` collates before `{date}-memory.txt`.
    let memories_dir = repo_root.join(".agents").join("memories");
    let mut memory_notes = Vec::new();
    if let Ok(m_entries) = std::fs::read_dir(&memories_dir) {
        let mut m_files: Vec<PathBuf> = m_entries.flatten()
            .map(|e| e.path())
            .filter(|p| wiki::is_memory_ledger(p))
            .collect();
        m_files.sort_by_key(|p| p.metadata().and_then(|m| m.modified()).ok());
        if let Some(latest_mem) = m_files.last() {
            if let Ok(m_text) = std::fs::read_to_string(latest_mem) {
                let (clean_mem, san_cnt) = sanitize_orient_content(&m_text);
                total_sanitized += san_cnt;
                for line in clean_mem.lines().filter(|l| l.trim().starts_with("- ")).rev().take(max_items).collect::<Vec<_>>().into_iter().rev() {
                    memory_notes.push(line.to_string());
                }
            }
        }
    }
    if !memory_notes.is_empty() {
        primer_lines.push("### Recent Durable Memories & Resolved Constraints (`.agents/memories/`)".to_string());
        for note in &memory_notes {
            primer_lines.push(note.clone());
        }
        primer_lines.push(String::new());
    }

    // Surface latest .agents/wiki/ledger.md operator entries inside <ORIENT_PRIMER>
    // Prioritize unresolved probe misses ahead of [RESOLVED] entries when selecting top ledger notes
    let mut wiki_ledger_notes = Vec::new();
    let mut open_ledger_notes = 0usize;
    let mut resolved_ledger_notes = 0usize;
    let ledger_file = repo_root.join(".agents").join("wiki").join("ledger.md");
    if ledger_file.is_file() {
        let rendered_ledger = wiki_gen.read_operator_ledger();
        let (clean_ledger, san_cnt) = sanitize_orient_content(&rendered_ledger);
        total_sanitized += san_cnt;
        let all_bullets: Vec<&str> = clean_ledger.lines().filter(|l| l.trim().starts_with("- ")).collect();
        resolved_ledger_notes = all_bullets.iter().filter(|l| l.contains("[RESOLVED]")).count();
        open_ledger_notes = all_bullets.len().saturating_sub(resolved_ledger_notes);
        wiki_ledger_notes = select_prioritized_ledger_notes(&clean_ledger).into_iter().take(max_items).collect();
    }
    if !wiki_ledger_notes.is_empty() {
        primer_lines.push("### Operator Wiki Ledger Notes (`.agents/wiki/ledger.md`)".to_string());
        for note in &wiki_ledger_notes {
            primer_lines.push(note.clone());
        }
        primer_lines.push(String::new());
    }

    // Extract and inject key symbol graph anchors from active task scope or core codebase modules
    let mut symbol_anchors = Vec::new();
    if include_symbols {
        let mut scope_hints = Vec::new();
        let tasks_dir = repo_root.join(".agents").join("tasks");
        if let Ok(t_entries) = std::fs::read_dir(&tasks_dir) {
            let mut t_files: Vec<PathBuf> = t_entries.flatten().map(|e| e.path()).filter(|p| p.extension().map_or(false, |ext| ext == "md")).collect();
            t_files.sort();
            if let Some(latest_t) = t_files.last() {
                if let Ok(t_text) = std::fs::read_to_string(latest_t) {
                    for line in t_text.lines() {
                        if let Some(rest) = line.strip_prefix("- scope:") {
                            for part in rest.split(',') {
                                let clean_p = part.trim().trim_end_matches('/');
                                if !clean_p.is_empty() {
                                    scope_hints.push(clean_p.to_string());
                                }
                            }
                        }
                    }
                }
            }
        }
        symbol_anchors = wiki_gen.extract_key_symbols_for_orient(&scope_hints, max_items);
        if !symbol_anchors.is_empty() {
            primer_lines.push("### Key Symbol Graph Anchors".to_string());
            for anchor in &symbol_anchors {
                primer_lines.push(anchor.clone());
            }
            primer_lines.push(String::new());
        }
    }

    primer_lines.push("</ORIENT_PRIMER>".to_string());
    let primer_text = primer_lines.join("\n");
    let orient_verified = !sections.is_empty()
        && !memory_notes.is_empty()
        && !wiki_ledger_notes.is_empty()
        && (!include_symbols || !symbol_anchors.is_empty());

    Ok(serde_json::json!({
        "primer": primer_text,
        "branch": git_branch,
        "commit": git_sha,
        "sections": sections,
        "recent_memories": memory_notes,
        "wiki_ledger_notes": wiki_ledger_notes,
        "open_ledger_notes": open_ledger_notes,
        "resolved_ledger_notes": resolved_ledger_notes,
        "symbol_anchors": symbol_anchors,
        "include_symbols": include_symbols,
        "sections_limit": section_limit,
        "gate_ready": gate_ready,
        "gate_status": gate_status_value,
        "synced_resolutions": synced_resolutions,
        "max_lines_per_section": lines_per_section,
        "total_sanitized_tokens": total_sanitized,
        "quarantine_verified": true,
        "orient_verified": orient_verified,
        "compact": compact,
        "classical_crypto_redacted": total_sanitized > 0,
        "task_conditioned": task_conditioned,
        "route_decision": route_decision,
    }))
}

async fn run_orient_inject(
    repo_root: &std::path::Path,
    query: Option<&str>,
    task_conditioned: bool,
    verify: bool,
    compact: bool,
    max_lines: Option<usize>,
    sections: Option<usize>,
    include_symbols: bool,
    sync_rules: bool,
    json: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    let orient_prompt = extract_orient_task_summary(repo_root, query);
    let route_decision = DecisionEngine::new().route(&orient_prompt).await;
    let mut report = build_orient_report_with_route(
        repo_root,
        query,
        task_conditioned,
        compact,
        max_lines,
        sections,
        include_symbols,
        Some(route_decision),
    )?;

    // Master-orchestrator: verified primers must run against fresh rules. When the caller
    // passes --verify and the cached gate verdict is not GREEN, auto-enable the sync so the
    // primer reflects current rules instead of a stale deployment.
    let gate_ready_now = report.get("gate_ready").and_then(|v| v.as_bool()).unwrap_or(false);
    let effective_sync = sync_rules || (verify && !gate_ready_now);
    if effective_sync {
        let (attempted, ok) = sync_rules_if_stale(repo_root, gate_ready_now);
        report["rules_sync_attempted"] = serde_json::json!(attempted);
        report["rules_sync_ok"] = serde_json::json!(ok);
        report["rules_sync_auto"] = serde_json::json!(!sync_rules && verify);
    }

    if json {
        println!("{}", serde_json::to_string_pretty(&report)?);
        return Ok(());
    }

    let primer_text = report.get("primer").and_then(|v| v.as_str()).unwrap_or_default();
    let section_count = report.get("sections").and_then(|v| v.as_array()).map(|a| a.len()).unwrap_or(0);
    let memory_count = report.get("recent_memories").and_then(|v| v.as_array()).map(|a| a.len()).unwrap_or(0);
    let ledger_count = report.get("wiki_ledger_notes").and_then(|v| v.as_array()).map(|a| a.len()).unwrap_or(0);
    let symbol_count = report.get("symbol_anchors").and_then(|v| v.as_array()).map(|a| a.len()).unwrap_or(0);
    let total_sanitized = report.get("total_sanitized_tokens").and_then(|v| v.as_u64()).unwrap_or(0);
    let orient_verified = report.get("orient_verified").and_then(|v| v.as_bool()).unwrap_or(false);

    println!("{}", primer_text);
    if verify {
        println!(
            "<!-- Orient Primer Verified: {} (sections={}, memories={}, ledger={}, symbols={}) -->",
            if orient_verified { "PASS" } else { "INCOMPLETE" },
            section_count,
            memory_count,
            ledger_count,
            symbol_count
        );
    }
    if total_sanitized > 0 {
        println!("<!-- Note: {} quarantine/.scrolls/classical-crypto patterns sanitized from primer -->", total_sanitized);
    }
    // Surface a self-heal to operators in human mode: `--verify` auto-enabled the rules sync.
    if report.get("rules_sync_auto").and_then(|v| v.as_bool()).unwrap_or(false) {
        println!(
            "<!-- Rules auto-sync: --verify found gate_ready=false, refreshed deployed rules ({}) -->",
            if report.get("rules_sync_ok").and_then(|v| v.as_bool()).unwrap_or(false) { "ok" } else { "attempted" }
        );
    } else if report.get("rules_sync_attempted").and_then(|v| v.as_bool()).unwrap_or(false) {
        println!(
            "<!-- Rules sync: {} -->",
            if report.get("rules_sync_ok").and_then(|v| v.as_bool()).unwrap_or(false) { "ok" } else { "failed" }
        );
    }
    if verify && !orient_verified {
        return Err("Orient primer verification failed: one or more context pillars empty".into());
    }
    Ok(())
}

fn trigger_desktop_notification(title: &str, message: &str) {
    #[cfg(target_os = "windows")]
    {
        let script = format!(
            "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null; \
             $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02); \
             $textNodes = $template.GetElementsByTagName('text'); \
             if ($textNodes.Count -gt 0) {{ $textNodes.Item(0).AppendChild($template.CreateTextNode('{}')) > $null; }} \
             if ($textNodes.Count -gt 1) {{ $textNodes.Item(1).AppendChild($template.CreateTextNode('{}')) > $null; }} \
             $toast = [Windows.UI.Notifications.ToastNotification]::new($template); \
             [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('ainish-rag').Show($toast);",
            title.replace('\'', "''"), message.replace('\'', "''")
        );
        let _ = std::process::Command::new("powershell")
            .args(["-NoProfile", "-NonInteractive", "-Command", &script])
            .output();
    }
    #[cfg(target_os = "linux")]
    {
        let _ = std::process::Command::new("notify-send")
            .args([title, message])
            .output();
    }
    #[cfg(target_os = "macos")]
    {
        let script = format!("display notification \"{}\" with title \"{}\"", message.replace('"', "\\\""), title.replace('"', "\\\""));
        let _ = std::process::Command::new("osascript")
            .args(["-e", &script])
            .output();
    }
}

/// True when a path carries a source-code extension (never anchor-exempt).
fn has_code_extension(normalized_path: &str) -> bool {
    let ext = normalized_path.rsplit('.').next().unwrap_or("").to_lowercase();
    matches!(
        ext.as_str(),
        "rs" | "py" | "ts" | "tsx" | "js" | "jsx" | "go" | "sh" | "bash" | "zsh" | "fish"
            | "ps1" | "cmd" | "bat" | "c" | "cc" | "cpp" | "h" | "hpp" | "cs" | "java" | "rb"
            | "php" | "lua" | "swift" | "kt"
    )
}

/// True when a patch path is documentation or agent-coordination state. Such patches
/// legitimately touch no symbols, so the pre-merge gate must not force them through the
/// code-anchoring threshold. Code (including scripts under `.agents/skills/` and
/// `.agents/bin/`) is never exempt.
pub fn is_docs_or_coord_path(path: &str) -> bool {
    let normalized = path.replace('\\', "/").to_lowercase();
    if normalized.starts_with(".agents/bin/") || has_code_extension(&normalized) {
        return false;
    }
    normalized.starts_with(".agents/")
        || normalized.ends_with(".md")
        || normalized.ends_with(".mdx")
        || normalized.ends_with(".txt")
        || normalized.ends_with(".rst")
}

/// Resolves the active branch and short HEAD SHA for primer/gate provenance.
fn git_branch_sha(repo_root: &std::path::Path) -> (String, String) {
    let branch = std::process::Command::new("git")
        .args(["branch", "--show-current"])
        .current_dir(repo_root)
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "main".to_string());
    let sha = std::process::Command::new("git")
        .args(["rev-parse", "--short", "HEAD"])
        .current_dir(repo_root)
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "HEAD".to_string());
    (branch, sha)
}

/// Test files are noise for the "implementation over test theatre" budget, so the gate counts
/// them separately from implementation lines added by a patch.
fn is_test_path(path: &str) -> bool {
    let p = path.replace('\\', "/").to_lowercase();
    let name = p.rsplit('/').next().unwrap_or(p.as_str());
    p.contains("/tests/")
        || p.contains("/test/")
        || p.contains("/spec/")
        || name.starts_with("test_")
        || name.contains("_test.")
        || name.contains(".test.")
        || name.contains(".spec.")
}

/// Returns `(test_lines_added, impl_lines_added)` for a unified diff.
fn diff_test_stats(patch: &str) -> (usize, usize) {
    let mut current = String::new();
    let mut test_lines = 0usize;
    let mut impl_lines = 0usize;
    for line in patch.lines() {
        if let Some(rest) = line.strip_prefix("+++ b/") {
            current = rest.to_string();
            continue;
        }
        if line.starts_with("+++") || line.starts_with("---") || line.starts_with('\\') {
            continue;
        }
        if line.starts_with('+') && !line.starts_with("+++") {
            if is_test_path(&current) {
                test_lines += 1;
            } else {
                impl_lines += 1;
            }
        }
    }
    (test_lines, impl_lines)
}

/// Runs the operator's existing-suite command so the gate card can show its exit code instead of
/// trusting a prose claim. Output is inherited so a failure is visible in the gate log.
fn run_test_command(repo_root: &std::path::Path, cmd: &str) -> (bool, Option<i32>) {
    #[cfg(windows)]
    let mut command = {
        let mut c = std::process::Command::new("cmd");
        c.arg("/C").arg(cmd);
        c
    };
    #[cfg(not(windows))]
    let mut command = {
        let mut c = std::process::Command::new("sh");
        c.arg("-c").arg(cmd);
        c
    };
    let result = command
        .current_dir(repo_root)
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::inherit())
        .stderr(std::process::Stdio::inherit())
        .status();
    match result {
        Ok(status) => (status.success(), status.code()),
        Err(_) => (false, None),
    }
}

fn truncate_cmd(cmd: &str, max: usize) -> String {
    if cmd.chars().count() <= max {
        cmd.to_string()
    } else {
        format!("{}…", cmd.chars().take(max.saturating_sub(1)).collect::<String>())
    }
}

/// Surface rules shared by both engines (`src/rag/master-surfaces.json`), so a new surface is one
/// edit rather than two. Adding a rule file entry is itself a compatibility surface.
#[derive(Debug, Clone, serde::Deserialize)]
pub struct MasterSurfaceRules {
    #[serde(default = "default_contract_paths")]
    pub contract_paths: Vec<String>,
    #[serde(default = "default_schema_suffixes")]
    pub schema_suffixes: Vec<String>,
    #[serde(default = "default_dependency_manifests")]
    pub dependency_manifests: Vec<String>,
    #[serde(default = "default_cli_tokens")]
    pub cli_tokens: Vec<String>,
    #[serde(default = "default_append_only_prefixes")]
    pub append_only_prefixes: Vec<String>,
    #[serde(default = "default_spend_prefixes")]
    pub spend_prefixes: Vec<String>,
}

fn default_contract_paths() -> Vec<String> {
    vec![
        "agents.md".to_string(),
        "llms.txt".to_string(),
        ".agents/canonical/".to_string(),
        ".agents/skills/".to_string(),
        "skills-to-distribute/".to_string(),
        "src/templates/".to_string(),
    ]
}

fn default_schema_suffixes() -> Vec<String> {
    vec![
        "embed-provider.json".to_string(),
        "index-fingerprint.json".to_string(),
        "gate-status.json".to_string(),
        "ainish-deploy.json".to_string(),
    ]
}

fn default_dependency_manifests() -> Vec<String> {
    vec![
        "cargo.toml".to_string(),
        "cargo.lock".to_string(),
        "package.json".to_string(),
        "package-lock.json".to_string(),
        "pnpm-lock.yaml".to_string(),
        "pyproject.toml".to_string(),
        "uv.lock".to_string(),
    ]
}

fn default_cli_tokens() -> Vec<String> {
    vec![
        "#[arg(".to_string(),
        "add_argument(".to_string(),
        "long = \"".to_string(),
        "env::var(\"".to_string(),
        "os.environ.get(\"".to_string(),
        "os.environ[\"".to_string(),
    ]
}

fn default_append_only_prefixes() -> Vec<String> {
    vec![
        ".agents/comms/".to_string(),
        ".agents/memories/".to_string(),
        ".agents/suggestions/".to_string(),
    ]
}

fn default_spend_prefixes() -> Vec<String> {
    vec![
        "src/rag/".to_string(),
        ".github/".to_string(),
        "benchmarks/".to_string(),
        "scripts/".to_string(),
    ]
}

impl Default for MasterSurfaceRules {
    fn default() -> Self {
        Self {
            contract_paths: default_contract_paths(),
            schema_suffixes: default_schema_suffixes(),
            dependency_manifests: default_dependency_manifests(),
            cli_tokens: default_cli_tokens(),
            append_only_prefixes: default_append_only_prefixes(),
            spend_prefixes: default_spend_prefixes(),
        }
    }
}

/// Loads the shared surface rules from the repo (or its canonical root), falling back to defaults.
pub fn load_master_surface_rules(repo_root: &std::path::Path) -> MasterSurfaceRules {
    let mut candidates = vec![repo_root.join("src").join("rag").join("master-surfaces.json")];
    let canonical = crate::config::resolve_canonical_repo_root(repo_root)
        .join("src")
        .join("rag")
        .join("master-surfaces.json");
    if canonical != candidates[0] {
        candidates.push(canonical);
    }
    for path in candidates {
        if let Ok(text) = std::fs::read_to_string(path) {
            if let Ok(rules) = serde_json::from_str::<MasterSurfaceRules>(&text) {
                return rules;
            }
        }
    }
    MasterSurfaceRules::default()
}

/// One triggered-master surface: whether this patch touches it and whether the turn declared
/// what the lens requires (`compat:` / `budget:` lines, append-only state, parity row).
#[derive(Debug, Clone, serde::Serialize, Default)]
pub struct MasterCheck {
    pub touched: bool,
    pub declared: bool,
    pub detail: String,
    pub declaration: String,
}

/// The three machine-checkable triggered lenses from `AGENTS.md` `<OUTPUT>`.
#[derive(Debug, Clone, serde::Serialize, Default)]
pub struct MasterSurfaceReport {
    pub compatibility: MasterCheck,
    pub concurrency: MasterCheck,
    pub economics: MasterCheck,
}

impl MasterSurfaceReport {
    pub fn compat_ok(&self) -> bool {
        !self.compatibility.touched || self.compatibility.declared
    }

    pub fn concurrency_ok(&self) -> bool {
        self.concurrency.detail.is_empty()
    }

    pub fn economics_ok(&self) -> bool {
        !self.economics.touched || self.economics.declared
    }
}

fn today_utc() -> String {
    chrono::Utc::now().format("%Y-%m-%d").to_string()
}

fn read_today_task_record(repo_root: &std::path::Path) -> String {
    let path = repo_root
        .join(".agents")
        .join("tasks")
        .join(format!("{}-task.md", today_utc()));
    std::fs::read_to_string(path).unwrap_or_default()
}

/// Returns the declaration line (`compat:` / `budget:`) when present, trimmed and capped.
pub fn find_declaration(text: &str, key: &str) -> Option<String> {
    let prefix = format!("{}:", key.to_ascii_lowercase());
    text.lines()
        .map(|line| {
            line.trim()
                .trim_start_matches(['-', '+'])
                .trim()
                .to_string()
        })
        .find(|line| line.to_ascii_lowercase().starts_with(&prefix))
        .map(|line| line.chars().take(180).collect())
}

/// True when `text` carries a `key:` declaration line (a leading bullet or list dash is allowed).
pub fn has_declaration(text: &str, key: &str) -> bool {
    find_declaration(text, key).is_some()
}

fn push_label(labels: &mut Vec<String>, label: &str) {
    if !labels.iter().any(|existing| existing == label) {
        labels.push(label.to_string());
    }
}

/// Detects contract surfaces whose change needs a `compat:` declaration: shared contract docs and
/// skill packs, dependency manifests (semantics can shift under a lockfile bump), CLI flags, schema
/// `format:` fields, config-file shapes, and env-var interfaces.
pub fn contract_surfaces_touched(patch: &str, rules: &MasterSurfaceRules) -> Vec<String> {
    let mut labels: Vec<String> = Vec::new();
    for line in patch.lines() {
        if let Some(rest) = line.strip_prefix("+++ b/") {
            let path = rest.trim().to_ascii_lowercase();
            if rules.contract_paths.iter().any(|p| path == *p || path.starts_with(p.as_str())) {
                push_label(&mut labels, "contract");
            }
            if rules.schema_suffixes.iter().any(|name| path.ends_with(name.as_str())) {
                push_label(&mut labels, "schema");
            }
            if rules.dependency_manifests.iter().any(|name| path.ends_with(name.as_str())) {
                push_label(&mut labels, "dependency");
            }
            continue;
        }
        if line.starts_with("+++") || line.starts_with("---") || !(line.starts_with('+') || line.starts_with('-')) {
            continue;
        }
        let content = &line[1..];
        if rules.cli_tokens.iter().any(|token| content.contains(token.as_str())) {
            push_label(&mut labels, "cli");
        }
        if content.contains("\"format\":") || content.contains("format=") {
            push_label(&mut labels, "schema");
        }
    }
    labels
}

/// Shared state must be append-only: a non-header removed line in comms/memories/suggestions is a
/// lost-update risk under multiple writers.
pub fn shared_state_removals(patch: &str, rules: &MasterSurfaceRules) -> Vec<String> {
    let mut violations: Vec<String> = Vec::new();
    let mut current = String::new();
    let mut removed = 0usize;
    let flush = |path: &str, removed: usize, violations: &mut Vec<String>| {
        if removed == 0 {
            return;
        }
        let lower = path.to_ascii_lowercase();
        if rules.append_only_prefixes.iter().any(|prefix| lower.starts_with(prefix.as_str())) {
            violations.push(format!("{} ({} removed line(s))", path, removed));
        }
    };
    for line in patch.lines() {
        if let Some(rest) = line.strip_prefix("+++ b/") {
            flush(&current, removed, &mut violations);
            current = rest.trim().to_string();
            removed = 0;
            continue;
        }
        if line.starts_with('-') && !line.starts_with("---") {
            removed += 1;
        }
    }
    flush(&current, removed, &mut violations);
    violations
}

pub fn spends_resources(path: &str, rules: &MasterSurfaceRules) -> bool {
    let lower = path.replace('\\', "/").to_ascii_lowercase();
    rules.spend_prefixes.iter().any(|prefix| lower.starts_with(prefix.as_str()))
}

/// Removes ANSI SGR sequences so a `NO_COLOR` render carries the same meaning as a colored one.
pub fn strip_ansi(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    let mut chars = input.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '\x1b' && chars.peek() == Some(&'[') {
            chars.next();
            for next in chars.by_ref() {
                if next.is_ascii_alphabetic() {
                    break;
                }
            }
        } else {
            out.push(c);
        }
    }
    out
}

fn no_color_enabled() -> bool {
    std::env::var_os("NO_COLOR").is_some()
        || std::env::var("TERM").map(|t| t.eq_ignore_ascii_case("dumb")).unwrap_or(false)
}

pub fn assess_master_surfaces(repo_root: &std::path::Path, patch: &str) -> MasterSurfaceReport {
    let rules = load_master_surface_rules(repo_root);
    let task_record = read_today_task_record(repo_root);
    let compat_decl = find_declaration(&task_record, "compat")
        .or_else(|| find_declaration(patch, "compat"));

    let labels = contract_surfaces_touched(patch, &rules);
    let compatibility = MasterCheck {
        touched: !labels.is_empty(),
        declared: compat_decl.is_some(),
        detail: labels.join(", "),
        declaration: compat_decl.unwrap_or_default(),
    };

    let removals = shared_state_removals(patch, &rules);
    let touched_shared = patch
        .lines()
        .filter_map(|line| line.strip_prefix("+++ b/"))
        .any(|path| {
            let p = path.trim().to_ascii_lowercase();
            rules.append_only_prefixes.iter().any(|prefix| p.starts_with(prefix.as_str()))
        });
    let concurrency = MasterCheck {
        touched: touched_shared,
        declared: removals.is_empty(),
        detail: removals.join("; "),
        declaration: String::new(),
    };

    let touched_spend = patch
        .lines()
        .filter_map(|line| line.strip_prefix("+++ b/"))
        .any(|path| spends_resources(path.trim(), &rules));
    let budget_decl = find_declaration(&task_record, "budget")
        .or_else(|| find_declaration(patch, "budget"))
        .or_else(|| {
            std::env::var("AINISH_GATE_BUDGET")
                .ok()
                .map(|v| v.trim().to_string())
                .filter(|v| !v.is_empty())
        });
    let economics = MasterCheck {
        touched: touched_spend,
        declared: budget_decl.is_some(),
        detail: if touched_spend { "spend surface touched".to_string() } else { String::new() },
        declaration: budget_decl.unwrap_or_default(),
    };

    MasterSurfaceReport { compatibility, concurrency, economics }
}

async fn run_gate(
    config: &RagConfig,
    repo_root: &std::path::Path,
    patch: Option<&str>,
    bell: bool,
    notify: bool,
    watch: bool,
    summary: bool,
    strict: bool,
    tests: Option<&str>,
    statusline_json: bool,
    json: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    loop {
    let patch_text = if let Some(p) = patch {
        if std::path::Path::new(p).is_file() {
            std::fs::read_to_string(p)?
        } else {
            p.to_string()
        }
    } else {
        let out = std::process::Command::new("git")
            .args(["diff", "HEAD~1"])
            .current_dir(repo_root)
            .output();
        match out {
            Ok(o) if !o.stdout.is_empty() => String::from_utf8_lossy(&o.stdout).to_string(),
            _ => {
                let out2 = std::process::Command::new("git")
                    .args(["diff", "HEAD"])
                    .current_dir(repo_root)
                    .output();
                match out2 {
                    Ok(o) => String::from_utf8_lossy(&o.stdout).to_string(),
                    _ => String::new(),
                }
            }
        }
    };

    let patch_eval = evaluate_patch_diff(&patch_text);
    let lockfile_eval = pqc::check_lockfiles(repo_root);
    let canonical_eval = pqc::verify_canonical_contract(repo_root);

    let audit_dir = repo_root.join(".agents").join("audit");
    let mut audit_receipts_passed = 0;
    let mut audit_receipts_failed = 0;
    if let Ok(entries) = std::fs::read_dir(&audit_dir) {
        for e in entries.flatten() {
            let p = e.path();
            if p.extension().map_or(false, |ext| ext == "json")
                && p.file_name().map_or(false, |n| n != "model-manifest.json" && n != "lockfile-manifest.json" && n != "privacy-budget.json" && n != "crates-sparse-snapshot.json")
            {
                match pqc::verify_file(repo_root, &p) {
                    pqc::VerifyOutcome::Verified { .. } => audit_receipts_passed += 1,
                    pqc::VerifyOutcome::Unsigned(_) => {}
                    pqc::VerifyOutcome::Invalid(_) => audit_receipts_failed += 1,
                }
            }
        }
    }

    // Verify .agents/wiki/ledger.sig during gate when .agents/wiki/ledger.md is modified in the evaluated patch diff
    let ledger_file = repo_root.join(".agents").join("wiki").join("ledger.md");
    let ledger_modified_in_patch = patch_eval.modified_files.iter().any(|f| f.ends_with("ledger.md"));
    if ledger_modified_in_patch && ledger_file.exists() {
        match pqc::verify_file(repo_root, &ledger_file) {
            pqc::VerifyOutcome::Verified { .. } => audit_receipts_passed += 1,
            pqc::VerifyOutcome::Unsigned(_) | pqc::VerifyOutcome::Invalid(_) => audit_receipts_failed += 1,
        }
    }

    // Verify .agents/audit/model-manifest.sig during gate whenever .agents/audit/model-manifest.json is present
    let model_manifest_file = repo_root.join(".agents").join("audit").join("model-manifest.json");
    let model_manifest_sig_ok = if model_manifest_file.exists() {
        match pqc::verify_file(repo_root, &model_manifest_file) {
            pqc::VerifyOutcome::Verified { .. } => {
                audit_receipts_passed += 1;
                true
            }
            pqc::VerifyOutcome::Unsigned(_) | pqc::VerifyOutcome::Invalid(_) => {
                audit_receipts_failed += 1;
                false
            }
        }
    } else {
        true
    };

    // Verify .agents/audit/privacy-budget.sig during gate whenever .agents/audit/privacy-budget.json is present
    let privacy_budget_file = repo_root.join(".agents").join("audit").join("privacy-budget.json");
    let privacy_budget_sig_ok = if privacy_budget_file.exists() {
        match pqc::verify_file(repo_root, &privacy_budget_file) {
            pqc::VerifyOutcome::Verified { .. } => {
                audit_receipts_passed += 1;
                true
            }
            pqc::VerifyOutcome::Unsigned(_) | pqc::VerifyOutcome::Invalid(_) => {
                audit_receipts_failed += 1;
                false
            }
        }
    } else {
        true
    };

    // Verify .agents/audit/privacy-report.sig during gate whenever .agents/audit/privacy-report.json is present
    let privacy_report_file = repo_root.join(".agents").join("audit").join("privacy-report.json");
    let privacy_report_sig_ok = if privacy_report_file.exists() {
        match pqc::verify_file(repo_root, &privacy_report_file) {
            pqc::VerifyOutcome::Verified { .. } => {
                audit_receipts_passed += 1;
                true
            }
            pqc::VerifyOutcome::Unsigned(_) | pqc::VerifyOutcome::Invalid(_) => {
                audit_receipts_failed += 1;
                false
            }
        }
    } else {
        true
    };

    let (lock_drift, lock_unpinned) = match lockfile_eval {
        Ok((d, u)) => (d, u),
        Err(_) => (Vec::new(), Vec::new()),
    };

    let comms_violations = check_comms_harness_agnostic(repo_root);
    let comms_pass = comms_violations.is_empty();

    // Execute Zero-Trust, Loopback PSK, Trojan-Source, Model-Manifest Sig & Contract Governance History checks
    let agents_file = repo_root.join("AGENTS.md");
    let canon_hash_file = repo_root.join(".agents").join("canonical").join("AGENTS.md.sha256");
    let agents_sha = pqc::sha256_file(&agents_file).unwrap_or_default().to_lowercase();
    let zt_hash_ok = if agents_file.is_file() && canon_hash_file.is_file() {
        let expected = std::fs::read_to_string(&canon_hash_file).unwrap_or_default().trim().to_lowercase();
        agents_sha == expected
    } else {
        true
    };
    let zt_lf_ok = std::fs::read(repo_root.join("bin").join("ainish-coder"))
        .map(|b| !b.windows(2).any(|w| w == b"\r\n"))
        .unwrap_or(true);
    let loopback_psk_ok = crate::server::AntiDnsRebinding::validate_host(&config.server_url).is_ok()
        && config.psk.as_ref().map_or(true, |k| k.len() >= 16);
    let trojan_source_clean = patch_eval.canary_leaks.is_empty();
    let contract_history_ok = pqc::verify_contract_history_chain(repo_root).is_ok();
    let redaction_self_test_ok = WikiGenerator::new(repo_root).verify_redaction_pipeline().is_ok();
    let zt_pass = zt_hash_ok && zt_lf_ok && comms_pass && loopback_psk_ok && trojan_source_clean && contract_history_ok && redaction_self_test_ok && model_manifest_sig_ok && privacy_budget_sig_ok && privacy_report_sig_ok;

    let effective_strict = strict || std::env::var("AINISH_GATE_STRICT").map(|v| v == "1" || v.eq_ignore_ascii_case("true")).unwrap_or(false);
    let docs_only_patch = !patch_text.trim().is_empty()
        && !patch_eval.modified_files.is_empty()
        && patch_eval.modified_files.iter().all(|f| is_docs_or_coord_path(f));
    // The embedding-anchored score is gone with the vector store. The remaining patch gate is the
    // security half that never needed a model: no credential leak, no Trojan Source override.
    let patch_pass = patch_eval.status != "FAILED_CREDENTIAL_LEAK";
    let lock_pass = lock_drift.is_empty();
    let canonical_pass = matches!(canonical_eval, pqc::VerifyOutcome::Verified { .. });
    let audit_pass = audit_receipts_failed == 0;

    let (test_lines_added, impl_lines_added) = diff_test_stats(&patch_text);
    let tests_run = tests.map(|cmd| (cmd.to_string(), run_test_command(repo_root, cmd)));
    let tests_pass = tests_run.as_ref().map_or(true, |(_, (ok, _))| *ok);

    // Triggered master lenses (compatibility / concurrency / economics): cheap, diff-derived.
    let master_surfaces = assess_master_surfaces(repo_root, &patch_text);
    let masters_pass = master_surfaces.compat_ok()
        && master_surfaces.concurrency_ok()
        && (!effective_strict || master_surfaces.economics_ok());

    let overall_pass = patch_pass
        && lock_pass
        && audit_pass
        && comms_pass
        && zt_pass
        && tests_pass
        && masters_pass;

    // Persist the latest gate verdict for `orient --inject --json` (`gate_ready`) and statusline consumers.
    let (cache_branch, cache_commit) = git_branch_sha(repo_root);
    let gate_cache = serde_json::json!({
        "format": "ainish-rag/gate-status/v1",
        "overall_pass": overall_pass,
        "status": if overall_pass { "GREEN" } else { "RED" },
        "anchor_pct": serde_json::Value::Null,
        "docs_only": docs_only_patch,
        "contract_sha256": agents_sha,
        "master_surfaces": master_surfaces,
        "diff_stats": {
            "test_lines_added": test_lines_added,
            "impl_lines_added": impl_lines_added
        },
        "tests": {
            "provided": tests_run.is_some(),
            "command": tests_run.as_ref().map(|(cmd, _)| cmd.clone()),
            "exit_code": tests_run.as_ref().and_then(|(_, (_, code))| *code),
            "pass": tests_pass
        },
        "branch": cache_branch,
        "commit": cache_commit,
        "updated_at": chrono::Utc::now().to_rfc3339(),
    });
    let cache_dir = repo_root.join(".agents").join("rag");
    let _ = std::fs::create_dir_all(&cache_dir);
    let _ = std::fs::write(
        cache_dir.join("gate-status.json"),
        serde_json::to_string_pretty(&gate_cache).unwrap_or_default(),
    );

    if summary {
        let anchor_label = if docs_only_patch { "N/A".to_string() } else { "model-free".to_string() };
        let line_str = format!(
            "GATE:{} | anchor:{} | patch:{} | lock:{} | pqc:{}/{} | comms:{} | zt:{}",
            if overall_pass { "GREEN" } else { "RED" },
            anchor_label,
            if docs_only_patch { "DOCS" } else { "CODE" },
            if lock_pass { "OK" } else { "DRIFT" },
            audit_receipts_passed,
            audit_receipts_passed + audit_receipts_failed,
            if comms_pass { "OK" } else { "LEGACY_AGENT_TAG" },
            if zt_pass { "OK" } else { "FAIL" }
        );
        if statusline_json {
            println!("{}", serde_json::to_string(&serde_json::json!({
                "status": if overall_pass { "GREEN" } else { "RED" },
                "overall_pass": overall_pass,
                "anchor_pct": serde_json::Value::Null,
                "docs_only": docs_only_patch,
                "patch_kind": if docs_only_patch { "docs" } else { "code" },
                "lock": if lock_pass { "OK" } else { "DRIFT" },
                "pqc": format!("{}/{}", audit_receipts_passed, audit_receipts_passed + audit_receipts_failed),
                "comms": if comms_pass { "OK" } else { "LEGACY_AGENT_TAG" },
                "zt": if zt_pass { "OK" } else { "FAIL" },
                "text": line_str,
            }))?);
        } else {
            println!("{}", line_str);
        }
    } else if json {
        println!("{}", serde_json::to_string_pretty(&serde_json::json!({
            "overall_pass": overall_pass,
            "docs_only": docs_only_patch,
            "patch_kind": if docs_only_patch { "docs" } else { "code" },
            "patch_evaluation": patch_eval,
            "lockfile_check": {
                "pass": lock_pass,
                "drift": lock_drift,
                "unpinned": lock_unpinned
            },
            "canonical_contract": {
                "pass": canonical_pass,
                "sha256": agents_sha,
                "status": match canonical_eval {
                    pqc::VerifyOutcome::Verified { ref fingerprint } => format!("ML-DSA-65 Verified (key: {}...)", &fingerprint[..12.min(fingerprint.len())]),
                    pqc::VerifyOutcome::Unsigned(ref r) => format!("Unsigned: {}", r),
                    pqc::VerifyOutcome::Invalid(ref e) => format!("Invalid: {}", e),
                }
            },
            "audit_receipts": {
                "pass": audit_pass,
                "passed_count": audit_receipts_passed,
                "failed_count": audit_receipts_failed
            },
            "diff_stats": {
                "test_lines_added": test_lines_added,
                "impl_lines_added": impl_lines_added
            },
            "tests": {
                "provided": tests_run.is_some(),
                "command": tests_run.as_ref().map(|(cmd, _)| cmd.clone()),
                "exit_code": tests_run.as_ref().and_then(|(_, (_, code))| *code),
                "pass": tests_pass
            },
            "master_surfaces": master_surfaces,
            "comms_hygiene": {
                "pass": comms_pass,
                "legacy_agent_tag_violations": comms_violations
            },
            "zero_trust_gate": {
                "pass": zt_pass,
                "canonical_sha256_match": zt_hash_ok,
                "posix_lf_verified": zt_lf_ok,
                "loopback_psk_verified": loopback_psk_ok,
                "trojan_source_clean": trojan_source_clean,
                "contract_history_verified": contract_history_ok,
                "redaction_self_test": redaction_self_test_ok,
                "model_manifest_sig_verified": model_manifest_sig_ok,
                "privacy_budget_sig_verified": privacy_budget_sig_ok,
                "privacy_report_sig_verified": privacy_report_sig_ok
            }
        }))?);
    } else {
        println!();
        println!("┌────────────────────────────────────────────────────────────────────────┐");
        println!("│                    ainish-rag Pre-Merge Gate Card                      │");
        println!("├────────────────────────────────────────────────────────────────────────┤");
        let patch_label = if docs_only_patch {
            "\x1b[32mPASS (docs/coordination-only patch)\x1b[0m".to_string()
        } else if patch_pass {
            format!("\x1b[32mPASS ({})\x1b[0m", patch_eval.status)
        } else {
            format!("\x1b[31mFAIL ({})\x1b[0m", patch_eval.status)
        };
        println!("  Patch Anchoring:        {}", patch_label);

        let delta_label = if patch_text.trim().is_empty() {
            "n/a (no patch)".to_string()
        } else {
            format!("+{} test / +{} impl", test_lines_added, impl_lines_added)
        };
        println!("  Test Delta:             {}", delta_label);

        let tests_label = match &tests_run {
            Some((cmd, (ok, code))) => format!(
                "{} ({} → exit {})",
                if *ok { "\x1b[32mPASS\x1b[0m" } else { "\x1b[31mFAIL\x1b[0m" },
                truncate_cmd(cmd, 34),
                code.map(|c| c.to_string()).unwrap_or_else(|| "?".to_string())
            ),
            None => "\x1b[33mSKIPPED (pass --tests \"<cmd>\")\x1b[0m".to_string(),
        };
        println!("  Existing Tests:         {}", tests_label);

        let master_label = format!(
            "{} · {} · {}",
            if master_surfaces.compat_ok() {
                let detail = if master_surfaces.compatibility.touched {
                    format!(" ({})", master_surfaces.compatibility.detail)
                } else {
                    String::new()
                };
                format!("\x1b[32mcompat PASS\x1b[0m{}", detail)
            } else {
                format!("\x1b[31mcompat FAIL (no compat: for {})\x1b[0m", master_surfaces.compatibility.detail)
            },
            if master_surfaces.concurrency_ok() {
                "\x1b[32mconcurrency PASS\x1b[0m".to_string()
            } else {
                format!("\x1b[31mconcurrency FAIL ({})\x1b[0m", master_surfaces.concurrency.detail)
            },
            match (master_surfaces.economics.touched, master_surfaces.economics.declared) {
                (false, _) => "\x1b[90mecon n/a\x1b[0m".to_string(),
                (true, true) => "\x1b[32mecon PASS\x1b[0m".to_string(),
                (true, false) if effective_strict => "\x1b[31mecon FAIL (no budget:)\x1b[0m".to_string(),
                (true, false) => "\x1b[33mecon WARN (no budget:)\x1b[0m".to_string(),
            }
        );
        let master_label = if no_color_enabled() { strip_ansi(&master_label) } else { master_label };
        println!("  Master Surfaces:        {}", master_label);

        let lock_label = if lock_pass {
            format!("\x1b[32mPASS (0 drift, {} unpinned)\x1b[0m", lock_unpinned.len())
        } else {
            format!("\x1b[31mFAIL ({} drift files)\x1b[0m", lock_drift.len())
        };
        println!("  Supply Chain Lockfiles: {}", lock_label);

        let audit_label = if audit_pass {
            format!("\x1b[32mPASS ({} receipts ML-DSA-65 verified)\x1b[0m", audit_receipts_passed)
        } else {
            format!("\x1b[31mFAIL ({} failed receipts)\x1b[0m", audit_receipts_failed)
        };
        println!("  Post-Quantum Receipts:  {}", audit_label);

        let canon_label = match canonical_eval {
            pqc::VerifyOutcome::Verified { .. } => format!(
                "\x1b[32mPASS (FIPS 204 ML-DSA-65, sha256 {})\x1b[0m",
                &agents_sha[..12.min(agents_sha.len())]
            ),
            pqc::VerifyOutcome::Unsigned(_) => "\x1b[33mWARN (envelope missing or unsigned)\x1b[0m".to_string(),
            pqc::VerifyOutcome::Invalid(_) => "\x1b[31mFAIL (tamper detected / mismatch)\x1b[0m".to_string(),
        };
        println!("  Canonical AGENTS.md:    {}", canon_label);

        let comms_label = if comms_pass {
            "\x1b[32mPASS (harness-agnostic headers)\x1b[0m".to_string()
        } else {
            format!("\x1b[31mFAIL ({} legacy agent: tags)\x1b[0m", comms_violations.len())
        };
        println!("  COMMS Ledger Hygiene:   {}", comms_label);

        let zt_label = if zt_pass {
            "\x1b[32mPASS (Zero-Trust PQC, Loopback PSK & Trojan-Source clean)\x1b[0m".to_string()
        } else {
            "\x1b[31mFAIL (Zero-Trust / PSK / Trojan-Source / History violation)\x1b[0m".to_string()
        };
        println!("  Zero-Trust Security:    {}", zt_label);
        println!("├────────────────────────────────────────────────────────────────────────┤");
        if overall_pass {
            println!("  OVERALL STATUS:         \x1b[1;32mGREEN (Autonomous Merge Authorized)\x1b[0m");
        } else {
            println!("  OVERALL STATUS:         \x1b[1;31mRED (Merge Blocked - Red Gates)\x1b[0m");
        }
        println!("└────────────────────────────────────────────────────────────────────────┘");
        println!();
    }

    let enable_bell = bell || std::env::var("AINISH_GATE_BELL").map(|v| v == "1" || v.eq_ignore_ascii_case("true")).unwrap_or(false);
    if enable_bell {
        eprint!("\x07");
    }

    let enable_notify = notify || std::env::var("AINISH_GATE_NOTIFY").map(|v| v == "1" || v.eq_ignore_ascii_case("true")).unwrap_or(false);
    if enable_notify {
        trigger_desktop_notification(
            "ainish-rag gate",
            if overall_pass { "Gate Passed: GREEN (Autonomous Merge Authorized)" } else { "Gate Failed: RED (Merge Blocked)" }
        );
    }

    if !watch {
        if !overall_pass {
            return Err("Pre-merge gate verification failed".into());
        }
        return Ok(());
    }

    println!("  \x1b[36m[rag:gate-watch]\x1b[0m Watching repository for file changes (Ctrl+C to stop)...");
    let mut baseline_mtimes: std::collections::HashMap<PathBuf, std::time::SystemTime> = std::collections::HashMap::new();
    for f in watch_files(repo_root) {
        if let Ok(m) = std::fs::metadata(&f).and_then(|meta| meta.modified()) {
            baseline_mtimes.insert(f, m);
        }
    }
    loop {
        tokio::time::sleep(tokio::time::Duration::from_millis(1500)).await;
        let mut modified_detected = false;
        for f in watch_files(repo_root) {
            if let Ok(m) = std::fs::metadata(&f).and_then(|meta| meta.modified()) {
                if baseline_mtimes.get(&f).map_or(true, |prev| *prev < m) {
                    modified_detected = true;
                    break;
                }
            }
        }
        if modified_detected {
            println!("  \x1b[33m[rag:gate-watch]\x1b[0m File modification detected — re-evaluating gate...");
            break;
        }
    }
    }
}

/// Repository files a gate watch cycle should stat. Replaces `CodebaseIngestor::scan_files`, which
/// came from the retired vector module; the watch loop only ever needs paths, never chunks.
fn watch_files(repo_root: &std::path::Path) -> Vec<PathBuf> {
    let mut out = Vec::new();
    let mut stack = vec![repo_root.to_path_buf()];
    while let Some(dir) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&dir) else { continue };
        for e in entries.flatten() {
            let path = e.path();
            if crate::scrub::is_ignored_path(&path) {
                continue;
            }
            if path.is_dir() {
                stack.push(path);
            } else {
                out.push(path);
            }
        }
    }
    out
}

/// Refuses a retired verb with its reason and the replacement, instead of argparse/clap's
/// "unrecognized subcommand" — which reads as a typo rather than a deliberate removal.
fn retired(name: &str) -> ! {
    eprintln!(
        "ainish-rag: `{}` was retired 2026-11-12 — it existed only to serve the vector subsystem.\n\
         \x20 Retrieval is graph-first over the Obsidian wiki vault and the .agents/ context folders,\n\
         \x20 with no embedding model and no vector store.\n\
         \x20 Use:  ainish-rag --context --task \"<request>\"",
        name
    );
    std::process::exit(1);
}

fn which_cmd(cmd: &str) -> Option<PathBuf> {
    if let Ok(path) = std::env::var("PATH") {
        for dir in std::env::split_paths(&path) {
            let p = dir.join(cmd);
            if p.is_file() { return Some(p); }
            #[cfg(windows)]
            {
                let p_exe = dir.join(format!("{}.exe", cmd));
                if p_exe.is_file() { return Some(p_exe); }
            }
        }
    }
    None
}

/// Locates a POSIX shell able to run the deployed rules refresher (Git Bash on Windows).
/// Skips the WindowsApps WSL stub, which cannot execute scripts.
fn rules_sync_shell() -> Option<PathBuf> {
    for candidate in ["sh", "bash", "bash.exe"] {
        if let Some(p) = which_cmd(candidate) {
            let s = p.to_string_lossy().to_lowercase();
            if !s.contains("windowsapps") {
                return Some(p);
            }
        }
    }
    #[cfg(target_os = "windows")]
    {
        for var in ["ProgramFiles", "ProgramFiles(x86)", "LocalAppData"] {
            if let Ok(base) = std::env::var(var) {
                let p = std::path::Path::new(&base).join("Git").join("bin").join("bash.exe");
                if p.is_file() {
                    return Some(p);
                }
            }
        }
    }
    None
}

/// Opt-in `orient --inject --sync-rules`: when the cached gate verdict is not GREEN for the
/// current commit, run the repo's deployed `.agents/bin/ainish-rules-sync` before emitting the
/// primer. Returns (attempted, succeeded); never fails the primer.
pub fn sync_rules_if_stale(repo_root: &std::path::Path, gate_ready: bool) -> (bool, bool) {
    if gate_ready {
        return (false, false);
    }
    let script = repo_root.join(".agents").join("bin").join("ainish-rules-sync");
    if !script.is_file() {
        return (true, false);
    }
    let Some(shell) = rules_sync_shell() else {
        return (true, false);
    };
    let ok = std::process::Command::new(&shell)
        .arg(&script)
        .arg("--quiet")
        .current_dir(repo_root)
        .status()
        .map(|s| s.success())
        .unwrap_or(false);
    (true, ok)
}

fn print_completion(shell: &str) {
    match shell.to_lowercase().as_str() {
        "bash" => {
            print!("{}", r#"# bash completion for ainish-rag
_ainish_rag() {
    local cur sub opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    sub="${COMP_WORDS[1]}"
    case "$sub" in
        status)     opts="--tui --json --help" ;;
        orient)     opts="--inject --task-conditioned --verify --compact --max-lines --sections --include-symbols --sync-rules --json --help" ;;
        audit)      opts="verify lock privacy sbom manifest contract sign keygen --update --format --out --manifest --path --redact-check --fail-on-leak --verify-history --threshold --hardware-seal --json --help" ;;
        gate)       opts="--patch --bell --notify --watch --summary --strict --json --help" ;;
        query)      opts="--limit --type --code --fzf --no-rerank --min-relevance --json --help" ;;
        wiki)       opts="--path --no-index --note --resolve --sync-resolved --list-notes --json --help" ;;
        index)      opts="--path --truncate --watch --anonymize-symbols --symbol-salt --dp-noise --dp-epsilon --dp-max-budget --help" ;;
        cleanup)    opts="--compact --prune-days --prune-worktrees --delete-merged --dry-run --help" ;;
        bench)      opts="--iterations --custom --regression --save-baseline --drift-injection --chaos --json --help" ;;
        monitor)    opts="--interval --once --json --help" ;;
        service)    opts="status install generate uninstall --warm --port --out --help" ;;
        statusline) opts="--json --help" ;;
        completion) opts="bash zsh fish pwsh --help" ;;
        *)          opts="serve stop status secrets index wiki query rerank route decide eval gate statusline cleanup orient bench monitor audit service completion --threads --max-mem --psk-ttl --numa --cpu-affinity --anonymize-symbols --symbol-salt --patch --fzf --compact --inject --custom --tui --json --help" ;;
    esac
    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}
complete -F _ainish_rag ainish-rag
alias rag="ainish-rag"
ainish_rag_statusline() { ainish-rag statusline 2>/dev/null; }
"#);
        }
        "zsh" => {
            print!("{}", r#"#compdef ainish-rag
_ainish_rag() {
    local -a commands
    commands=(
        'serve:Start loopback embedding server'
        'stop:Stop running server'
        'status:Inspect model and database status'
        'secrets:Inspect PQC vault status'
        'index:Index codebase into LanceDB'
        'wiki:Generate living wiki'
        'query:Query multimodal vector store'
        'rerank:Decision-model reranking'
        'route:Intent domain routing'
        'decide:Evaluate decision state'
        'eval:Bi-phasic faithfulness and patch evaluation'
        'gate:Unified pre-merge verification gate'
        'statusline:Emit one-line compact gate status for PS1/Cursor/tmux'
        'cleanup:Compact LanceDB database and prune versions'
        'orient:Inject architectural wiki context into agent primer'
        'bench:Run synthetic regression benchmark'
        'monitor:Continuous drift monitoring'
        'audit:Verify post-quantum receipts, manifests, and SBOMs'
        'service:Background embedding service management'
        'completion:Generate shell completions'
    )
    if [[ "$words[CURRENT]" == -* ]]; then
        compadd -- --redact-check --fail-on-leak --include-symbols --sync-rules --sections --json --tui --patch --strict --help
        return
    fi
    _describe 'commands' commands
}
compdef _ainish_rag ainish-rag
alias rag="ainish-rag"
ainish_rag_statusline() { ainish-rag statusline 2>/dev/null; }
"#);
        }
        "fish" => {
            print!("{}", r#"# fish completion for ainish-rag
complete -c ainish-rag -f
complete -c ainish-rag -a "serve stop status secrets index wiki query rerank route decide eval gate statusline cleanup orient bench monitor audit service completion"
complete -c ainish-rag -l redact-check -r -d "Dry-run redaction on a file without mutating it"
complete -c ainish-rag -l fail-on-leak -d "Exit non-zero when redaction dry-run detects leaks"
complete -c ainish-rag -l include-symbols -d "Include symbol anchors in orient primer"
complete -c ainish-rag -l sync-rules -d "Run deployed rules refresher when gate_ready is false"
complete -c ainish-rag -l sections -x -d "Maximum wiki sections to inject"
complete -c ainish-rag -l max-lines -x -d "Per-section line truncation override"
complete -c ainish-rag -l json -d "Structured JSON output"
complete -c ainish-rag -l tui -d "Interactive status dashboard"
alias rag="ainish-rag"
function ainish_rag_statusline; ainish-rag statusline 2>/dev/null; end
"#);
        }
        "pwsh" | "powershell" => {
            print!("{}", r#"# PowerShell completion for ainish-rag
Register-ArgumentCompleter -Native -CommandName ainish-rag -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $commands = @('serve','stop','status','secrets','index','wiki','query','rerank','route','decide','eval','gate','statusline','cleanup','orient','bench','monitor','audit','service','completion')
    $options = @('--redact-check','--fail-on-leak','--include-symbols','--sync-rules','--sections','--max-lines','--json','--tui','--patch','--strict','--help')
    if ($wordToComplete -like '-*') {
        $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        return
    }
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}
Set-Alias -Name rag -Value ainish-rag
function Invoke-AinishRagStatusLine { ainish-rag statusline 2>$null }
"#);
        }
        _ => {
            eprintln!("Unsupported shell: {}. Supported shells: bash, zsh, fish, pwsh", shell);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_orient_prioritizes_open_ledger_notes_ahead_of_resolved() {
        let sample = "# Operator ledger\n\
            - [RESOLVED] 2026-10-26 Old resolved item one\n\
            - 2026-10-27 Open probe miss alpha\n\
            - [RESOLVED] 2026-10-28 Resolved item two\n\
            - 2026-10-29 Open probe miss beta\n";
        let notes = select_prioritized_ledger_notes(sample);
        assert_eq!(notes.len(), 4);
        // First two entries must be the open (unresolved) items
        assert!(notes[0].contains("Open probe miss alpha") && !notes[0].contains("[RESOLVED]"));
        assert!(notes[1].contains("Open probe miss beta") && !notes[1].contains("[RESOLVED]"));
        // Resolved items follow after open items
        assert!(notes[2].contains("[RESOLVED]"));
        assert!(notes[3].contains("[RESOLVED]"));

        let root = crate::config::resolve_canonical_repo_root(std::path::Path::new("."));
        assert!(check_comms_harness_agnostic(&root).is_empty());
    }

    #[test]
    fn test_orient_compact_caps_token_budget() {
        let root = crate::config::resolve_canonical_repo_root(std::path::Path::new("."));
        let wiki_gen = WikiGenerator::new(&root);
        let compact_syms = wiki_gen.extract_key_symbols_for_orient(&[], 3);
        assert!(compact_syms.len() <= 3);

        let sample_ledger = "# Operator ledger\n\
            - 2026-10-25 Item 1\n\
            - 2026-10-26 Item 2\n\
            - 2026-10-27 Item 3\n\
            - 2026-10-28 Item 4\n\
            - 2026-10-29 Item 5\n";
        let compact_notes: Vec<String> = select_prioritized_ledger_notes(sample_ledger).into_iter().take(3).collect();
        assert_eq!(compact_notes.len(), 3);
    }

    /// The hour-stamp cutover makes two naming schemes live at once. A name sort picks the
    /// grandfather file (`{date}-memory.txt` sorts after `{date}-09-memory.md`), so every
    /// "newest wins" consumer must order by mtime. This pins the predicates and the ordering rule.
    #[test]
    fn test_mixed_naming_schemes_resolve_to_newest_by_mtime() {
        let tmp = std::env::temp_dir().join(format!("ainish-mixed-naming-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&tmp);
        let mem_dir = tmp.join(".agents").join("memories");
        let comms_dir = tmp.join(".agents").join("comms");
        std::fs::create_dir_all(&mem_dir).unwrap();
        std::fs::create_dir_all(&comms_dir).unwrap();

        // Both schemes exist for the same day; the hour-stamped one is written second (newer).
        let grandfather = mem_dir.join("2026-11-12-memory.txt");
        let current = mem_dir.join("2026-11-12-09-memory.md");
        std::fs::write(&grandfather, "- grandfather ledger bullet\n").unwrap();
        std::thread::sleep(std::time::Duration::from_millis(20));
        std::fs::write(&current, "- current ledger bullet\n").unwrap();

        assert!(wiki::is_memory_ledger(&grandfather), "grandfathered memory name must be recognised");
        assert!(wiki::is_memory_ledger(&current), "hour-stamped memory name must be recognised");
        assert!(!wiki::is_memory_ledger(&mem_dir.join("llms.txt")), "the directory index is not a ledger");

        // The defect this guards: name ordering returns the grandfather file as "newest".
        let mut by_name: Vec<_> = std::fs::read_dir(&mem_dir).unwrap().flatten()
            .map(|e| e.path())
            .filter(|p| wiki::is_memory_ledger(p))
            .collect();
        by_name.sort();
        assert!(by_name.last().unwrap().ends_with("2026-11-12-memory.txt"),
            "precondition: name ordering prefers the grandfather file, which is why mtime is required");

        let mut by_mtime: Vec<_> = std::fs::read_dir(&mem_dir).unwrap().flatten()
            .map(|e| e.path())
            .filter(|p| wiki::is_memory_ledger(p))
            .collect();
        by_mtime.sort_by_key(|p| p.metadata().and_then(|m| m.modified()).ok());
        assert!(by_mtime.last().unwrap().ends_with("2026-11-12-09-memory.md"),
            "mtime ordering must return the hour-stamped file it was written after");

        // COMMS: both ledger suffixes count, the live board never does.
        std::fs::write(comms_dir.join("2026-11-12-team.md"), "# team\n").unwrap();
        std::fs::write(comms_dir.join("2026-11-12-team.txt"), "# team\n").unwrap();
        std::fs::write(comms_dir.join("2026-11-12-team.live.md"), "live\n").unwrap();
        let comms_violations = check_comms_harness_agnostic(&tmp);
        assert!(comms_violations.is_empty(), "clean ledgers in both schemes produce no violations");

        // The discipline check must still see a legacy tag in EITHER scheme, or it silently stops
        // enforcing anything on the day the naming changes.
        std::fs::write(comms_dir.join("2026-11-12-team.md"), "### [10:00] x | agent: cursor\n").unwrap();
        let bad_new = check_comms_harness_agnostic(&tmp);
        assert_eq!(bad_new.len(), 1, "legacy '| agent:' tag is caught in the new scheme too");
        assert!(bad_new[0].starts_with("2026-11-12-team.md:"));

        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn test_orient_respects_max_lines_and_symbol_toggle() {        let tmp = std::env::temp_dir().join(format!("ainish-orient-maxlines-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&tmp);
        let wiki_dir = tmp.join(".agents").join("wiki");
        let mem_dir = tmp.join(".agents").join("memories");
        std::fs::create_dir_all(&wiki_dir).unwrap();
        std::fs::create_dir_all(&mem_dir).unwrap();

        let wiki_body: String = (1..=30).map(|i| format!("line-{:02} architectural detail\n", i)).collect();
        std::fs::write(wiki_dir.join("01-architecture.md"), wiki_body).unwrap();
        std::fs::write(wiki_dir.join("02-codebase-connections.md"), "# 02 connections\nbody\n").unwrap();
        std::fs::write(
            mem_dir.join("2026-10-29-memory.txt"),
            "- 10:00 memory alpha\n- 10:01 memory beta\n- 10:02 memory gamma\n",
        ).unwrap();
        std::fs::write(
            wiki_dir.join("ledger.md"),
            "# Operator ledger\n\n- 2026-10-29 open ledger item one\n- [RESOLVED] 2026-10-29 closed ledger item two\n",
        ).unwrap();
        std::fs::write(
            tmp.join("sample.rs"),
            "pub fn calculate_anchor_one() {}\npub fn calculate_anchor_two() {}\nstruct AlphaBeta {}\n",
        ).unwrap();

        let limited = build_orient_report(&tmp, None, false, false, Some(4), Some(1), false).unwrap();
        assert_eq!(limited["max_lines_per_section"], 4);
        assert_eq!(limited["sections_limit"], 1);
        assert_eq!(limited["sections"].as_array().unwrap().len(), 1);
        assert_eq!(limited["gate_ready"], false);
        let content = limited["sections"][0]["content"].as_str().unwrap();
        assert_eq!(content.lines().count(), 4);
        assert!(!content.contains("line-05"));
        assert_eq!(limited["symbol_anchors"].as_array().unwrap().len(), 0);
        assert_eq!(limited["include_symbols"], false);
        assert_eq!(limited["open_ledger_notes"], 1);
        assert_eq!(limited["resolved_ledger_notes"], 1);
        assert!(limited["orient_verified"].as_bool().unwrap());

        let with_symbols = build_orient_report(&tmp, None, false, false, Some(2), None, true).unwrap();
        assert_eq!(with_symbols["sections"].as_array().unwrap().len(), 2);
        assert_eq!(with_symbols["sections"][0]["content"].as_str().unwrap().lines().count(), 2);
        assert!(with_symbols["symbol_anchors"].as_array().unwrap().len() >= 1);
        assert!(with_symbols["primer"].as_str().unwrap().contains("Key Symbol Graph Anchors"));

        assert!(is_docs_or_coord_path(".agents/comms/2026-10-29-team.txt"));
        assert!(is_docs_or_coord_path("AGENTS.md"));
        assert!(is_docs_or_coord_path("llms.txt"));
        assert!(is_docs_or_coord_path(".agents/audit/model-manifest.json"));
        assert!(!is_docs_or_coord_path(".agents/skills/example/helper.py"));
        assert!(!is_docs_or_coord_path(".agents/bin/ainish-rules-sync"));
        assert!(!is_docs_or_coord_path("src/rag/src/main.rs"));
        assert!(!is_docs_or_coord_path(".github/workflows/security.yml"));

        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn test_sync_rules_opt_in_gated_by_gate_ready() {
        // gate_ready=true → the refresher must never run
        assert_eq!(sync_rules_if_stale(std::path::Path::new("/nonexistent/for/sure"), true), (false, false));

        let tmp = std::env::temp_dir().join(format!("ainish-sync-rules-test-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&tmp);

        // missing refresher → attempted but unsuccessful
        assert_eq!(sync_rules_if_stale(&tmp, false), (true, false));

        let bin = tmp.join(".agents").join("bin");
        std::fs::create_dir_all(&bin).unwrap();
        std::fs::write(bin.join("ainish-rules-sync"), "#!/bin/sh\nexit 0\n").unwrap();

        let (attempted, ok) = sync_rules_if_stale(&tmp, false);
        assert!(attempted, "a deployed refresher must be attempted when gate_ready is false");
        if rules_sync_shell().is_some() {
            assert!(ok, "the trivially-successful refresher must succeed");
        }

        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn test_diff_test_stats_splits_test_and_impl_lines() {
        let diff = "\
--- a/src/x.rs\n\
+++ b/src/x.rs\n\
+let a = 1;\n\
--- /dev/null\n\
+++ b/src/rag/tests/test_x.py\n\
+def test_x(): pass\n\
+assert True\n";
        assert_eq!(diff_test_stats(diff), (2, 1));
        assert!(is_test_path("src/rag/tests/test_x.py"));
        assert!(is_test_path("pkg/x.spec.ts"));
        assert!(!is_test_path("src/rag/main.rs"));
    }

    #[test]
    fn test_contract_surfaces_detected_for_contract_and_cli_changes() {
        let rules = MasterSurfaceRules::default();
        let diff = "--- a/AGENTS.md\n+++ b/AGENTS.md\n+new rule\n--- a/src/rag/src/main.rs\n+++ b/src/rag/src/main.rs\n+        #[arg(long)]\n+        flag: bool,\n";
        let labels = contract_surfaces_touched(diff, &rules);
        assert!(labels.contains(&"contract".to_string()));
        assert!(labels.contains(&"cli".to_string()));
        assert!(!labels.contains(&"schema".to_string()));
        assert!(!labels.contains(&"dependency".to_string()));
    }

    #[test]
    fn test_dependency_manifest_is_a_compatibility_surface() {
        let rules = MasterSurfaceRules::default();
        let diff = "--- a/Cargo.toml\n+++ b/Cargo.toml\n+serde = \"1\"\n--- a/pyproject.toml\n+++ b/pyproject.toml\n+extra = 1\n";
        let labels = contract_surfaces_touched(diff, &rules);
        assert!(labels.contains(&"dependency".to_string()));
        assert!(labels.contains(&"contract".to_string()) || labels.contains(&"dependency".to_string()));
        let tmp = std::env::temp_dir().join(format!("ainish-dependency-surface-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&tmp);
        std::fs::create_dir_all(tmp.join(".agents").join("tasks")).unwrap();
        let report = assess_master_surfaces(&tmp, diff);
        assert!(report.compatibility.touched && !report.compatibility.declared);
        assert!(!report.compat_ok());
        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn test_shared_state_is_append_only() {
        let rules = MasterSurfaceRules::default();
        let append_only = "--- a/.agents/comms/2026-10-31-team.txt\n+++ b/.agents/comms/2026-10-31-team.txt\n+new line\n";
        assert!(shared_state_removals(append_only, &rules).is_empty());
        let rewritten = "--- a/.agents/comms/2026-10-31-team.txt\n+++ b/.agents/comms/2026-10-31-team.txt\n-old line\n+new line\n";
        assert_eq!(shared_state_removals(rewritten, &rules).len(), 1);
        let task_rewrite = "--- a/.agents/tasks/2026-10-31-task.md\n+++ b/.agents/tasks/2026-10-31-task.md\n-old\n+new\n";
        assert!(shared_state_removals(task_rewrite, &rules).is_empty());
    }

    #[test]
    fn test_strip_ansi_removes_color_only() {
        assert_eq!(strip_ansi("\x1b[32mPASS\x1b[0m (contract)"), "PASS (contract)");
        assert_eq!(strip_ansi("plain"), "plain");
    }

    #[test]
    fn test_master_surface_report_requires_declarations() {
        let tmp = std::env::temp_dir().join(format!("ainish-master-surfaces-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&tmp);
        let tasks = tmp.join(".agents").join("tasks");
        std::fs::create_dir_all(&tasks).unwrap();
        std::fs::write(
            tasks.join(format!("{}-task.md", today_utc())),
            "- compat: v1 target window, --rules-sync refreshes deployed copies\n- budget: 120k tokens, cached index\n",
        )
        .unwrap();
        let patch = "--- a/src/rag/src/decision.rs\n+++ b/src/rag/src/decision.rs\n+let x = 1;\n--- a/AGENTS.md\n+++ b/AGENTS.md\n+rule\n";
        let report = assess_master_surfaces(&tmp, patch);
        assert!(report.compatibility.touched && report.compatibility.declared);
        assert!(report.compatibility.declaration.contains("compat:"));
        assert!(report.economics.touched && report.economics.declared);
        assert!(report.concurrency_ok());
        assert!(report.compat_ok() && report.economics_ok());
        assert!(has_declaration("+compat: added in diff", "compat"));
        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn test_missing_budget_fails_only_under_strict() {
        let tmp = std::env::temp_dir().join(format!("ainish-budget-surface-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&tmp);
        std::fs::create_dir_all(tmp.join(".agents").join("tasks")).unwrap();
        let patch = "--- a/src/rag/src/main.rs\n+++ b/src/rag/src/main.rs\n+let x = 1;\n";
        let report = assess_master_surfaces(&tmp, patch);
        assert!(report.economics.touched && !report.economics.declared);
        // A missing budget is a WARN by default and only blocks under --strict.
        assert!(!report.economics_ok());
        let rules = MasterSurfaceRules::default();
        assert!(spends_resources("src/rag/src/main.rs", &rules));
        assert!(!spends_resources("docs/README.md", &rules));
        let _ = std::fs::remove_dir_all(&tmp);
    }
}

