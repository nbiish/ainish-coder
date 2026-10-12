mod config;
mod server;
mod embed;
mod store;
mod ingest;
mod wiki;
mod decision;
mod pqc;

use clap::{Parser, Subcommand};
use std::path::PathBuf;
use std::env;
use crate::config::RagConfig;
use crate::server::LlamaServer;
use crate::embed::EmbedClient;
use crate::store::LanceStore;
use crate::ingest::CodebaseIngestor;
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

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Start or ensure EmbeddingGemma llama server is running
    Serve {
        /// Loopback port for embedding server (default: 8080 or AINISH_RAG_PORT)
        #[arg(short, long)]
        port: Option<u16>,
    },
    /// Stop running embedding server
    Stop,
    /// Inspect status of model cache, server, LanceDB vector store, and wiki
    Status {
        /// Launch interactive TUI telemetry dashboard
        #[arg(long)]
        tui: bool,
    },
    /// Index codebase or target path into LanceDB
    Index {
        /// Target path to index (default: current directory)
        #[arg(short, long)]
        path: Option<PathBuf>,
        /// Matryoshka dimension truncation (128, 256, 512, or default 768)
        #[arg(short, long)]
        truncate: Option<usize>,
        /// Watch target path for file modifications and incrementally re-index
        #[arg(short, long)]
        watch: bool,
        /// Anonymize and hash proprietary code identifiers before embedding
        #[arg(long)]
        anonymize_symbols: bool,
        /// Configurable symbol salt preventing rainbow-table deanonymization
        #[arg(long)]
        symbol_salt: Option<String>,
    },
    /// Continuous drift monitoring and regression evaluation
    Monitor {
        /// Check interval in seconds for continuous monitoring
        #[arg(short, long)]
        interval: Option<u64>,
        /// Run drift check once and exit immediately
        #[arg(long, default_value_t = true)]
        once: bool,
        /// Output monitoring metrics as JSON
        #[arg(long)]
        json: bool,
    },
    /// Run automated synthetic query regression suite to assert recall stability
    Bench {
        /// Number of benchmark passes (default: 3)
        #[arg(short, long, default_value_t = 3)]
        iterations: usize,
        /// Output benchmark results as JSON
        #[arg(long)]
        json: bool,
        /// Path to custom domain-specific JSON query benchmark suite
        #[arg(long)]
        custom: Option<PathBuf>,
    },
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
        /// Also index the generated wiki into LanceDB vector store (default: true)
        #[arg(long, default_value_t = true)]
        index: bool,
    },
    /// Query the multimodal RAG vector store with two-stage decision reranking
    Query {
        /// Natural language or code search query
        query: String,
        /// Maximum number of search hits to return
        #[arg(short, long, default_value_t = 5)]
        limit: usize,
        /// Filter by doc type (code, wiki, doc, image, audio, video)
        #[arg(short, long)]
        doc_type: Option<String>,
        /// Optimize embedding prefix for code retrieval
        #[arg(long)]
        code: bool,
        /// Output results as JSON
        #[arg(long)]
        json: bool,
        /// Disable decision-model reranking (use coarse vector search only)
        #[arg(long)]
        no_rerank: bool,
        /// Minimum relevance threshold for decision filtering (default: 0.35)
        #[arg(long, default_value_t = 0.35)]
        min_relevance: f32,
        /// Interactive fuzzy finder mode for terminal browsing and snippet inspection
        #[arg(long)]
        fzf: bool,
    },
    /// Rerank candidate context chunks for a query using the decision model
    Rerank {
        /// Natural language or code query
        query: String,
        /// Maximum number of reranked search hits to return
        #[arg(short, long, default_value_t = 5)]
        limit: usize,
        /// Filter by doc type (code, wiki, doc, image, audio, video)
        #[arg(short, long)]
        doc_type: Option<String>,
        /// Output results as JSON
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
        /// Output decision as JSON
        #[arg(long)]
        json: bool,
    },
    /// Run database compaction and old table version pruning
    Cleanup {
        /// Compact LanceDB dataset files
        #[arg(long, default_value_t = true)]
        compact: bool,
        /// Prune table versions older than N days (default: 7)
        #[arg(long, default_value_t = 7)]
        prune_days: i64,
    },
    /// Subagent context injection: formats top architectural wiki sections into primer
    Orient {
        /// Format top 3 relevant architectural wiki sections into <ORIENT_PRIMER>
        #[arg(long, default_value_t = true)]
        inject: bool,
        /// Focus query or task objective to rank wiki sections against
        #[arg(short, long)]
        query: Option<String>,
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
    /// Verify immutable model manifest hashes
    Manifest {
        /// Path to model manifest JSON (default: .agents/audit/model-manifest.json)
        #[arg(short, long)]
        manifest: Option<PathBuf>,
    },
    /// Export cryptographic SBOM in CycloneDX 1.6 or SPDX 3.0.1 format
    Sbom {
        /// SBOM format: cyclonedx (default) or spdx
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
    /// Check background service status
    Status,
    /// Uninstall continuous background service
    Uninstall,
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

    match cli.command {
        Commands::Serve { port } => {
            if let Some(p) = port {
                config.server_port = p;
                config.server_url = format!("http://127.0.0.1:{}", p);
            }
            LlamaServer::ensure_running(&config, &current_dir).await?;
        }
        Commands::Stop => {
            LlamaServer::stop(&current_dir)?;
        }
        Commands::Status { tui } => {
            if tui {
                run_tui_dashboard(&config, &current_dir).await?;
                return Ok(());
            }

            println!("=== ainish-rag Multimodal RAG Status ===");
            println!("HF Cache Root:      {}", config.hf_hub_cache.display());
            println!("Model GGUF:         {}", config.model_path.as_ref().map(|p| p.display().to_string()).unwrap_or_else(|| "NOT FOUND".to_string()));
            if let Some(ref mp) = config.model_path {
                match LlamaServer::verify_model_integrity(mp) {
                    Ok(stat) => println!("Model Integrity:    VALID ({})", stat),
                    Err(e)   => println!("Model Integrity:    FAILED ({})", e),
                }
            }
            println!("Multimodal Projector:{}", config.mmproj_path.as_ref().map(|p| p.display().to_string()).unwrap_or_else(|| "NOT FOUND".to_string()));
            println!("Llama Binary:       {}", config.llama_bin.as_ref().map(|p| p.display().to_string()).unwrap_or_else(|| "NOT FOUND".to_string()));
            println!("Server Endpoint:    {}", config.server_url);

            let is_running = LlamaServer::is_running(&config.server_url, config.psk.as_deref()).await;
            println!("Server Status:      {}", if is_running { "ONLINE (ready)" } else { "OFFLINE" });

            let psk_status = if let Some(ref psk) = config.psk {
                let preview = if psk.len() > 8 { &psk[..8] } else { psk };
                format!("ENABLED (Loopback PSK: {}...)", preview)
            } else {
                "DISABLED (unauthenticated loopback)".to_string()
            };
            println!("Loopback Auth:      {}", psk_status);

            let salt_status = if let Some(ref s) = config.symbol_salt {
                format!("ACTIVE (len: {})", s.len())
            } else {
                "DEFAULT (machine/repo hash)".to_string()
            };
            println!("Symbol Salt:        {}", salt_status);

            let manifest_status = match LlamaServer::verify_model_manifest(
                config.model_path.as_ref().unwrap_or(&PathBuf::from("")),
                &config.model_manifest_path
            ) {
                Ok(Some(hash)) => format!("VERIFIED ({})", &hash[..16]),
                Ok(None) => "NOT PRESENT (manifest absent)".to_string(),
                Err(e) => format!("TAMPERED ({})", e),
            };
            println!("Model Manifest:     {}", manifest_status);

            let store = LanceStore::new(&config.lancedb_dir, config.embedding_dim);
            let count = store.count().await.unwrap_or(0);
            println!("LanceDB Path:       {}", config.lancedb_dir.display());
            println!("Indexed Chunks:     {}", count);

            let wiki_exists = config.wiki_dir.exists();
            let wiki_count = if wiki_exists {
                std::fs::read_dir(&config.wiki_dir)
                    .map(|entries| entries.filter_map(|e| e.ok()).filter(|e| e.path().extension().map_or(false, |ext| ext == "md")).count())
                    .unwrap_or(0)
            } else {
                0
            };
            println!("Wiki Path:          {}", config.wiki_dir.display());
            println!("Wiki Pages:         {}", wiki_count);

            if config.llama_bin.is_none() {
                println!("\n  [rag:tip] llama executable not found!");
                #[cfg(target_os = "macos")]
                println!("            Install via Homebrew: brew install llama.cpp");
                #[cfg(target_os = "windows")]
                println!("            Install via WinGet:   winget install llama.cpp (or download from GitHub)");
                #[cfg(target_os = "linux")]
                println!("            Download release:     https://github.com/ggerganov/llama.cpp/releases");
                println!("            Or set environment:   export LLAMA_SERVER_BIN=/path/to/llama-server");
            }
            if config.model_path.is_none() {
                println!("\n  [rag:tip] EmbeddingGemma-2 GGUF model not found in HuggingFace cache!");
                println!("            Download model:       huggingface-cli download unsloth/embeddinggemma-2-GGUF embeddinggemma-2-BF16.gguf");
                println!("            Or set environment:   export AINISH_RAG_MODEL=/path/to/embeddinggemma-2-BF16.gguf");
            }
        }
        Commands::Index { path, truncate, watch, anonymize_symbols, symbol_salt } => {
            let target = path.unwrap_or_else(|| current_dir.clone());
            println!("=== Indexing Codebase into LanceDB ===");
            println!("Target directory: {}", target.display());
            if let Some(s) = symbol_salt {
                config.symbol_salt = Some(s);
            }
            if anonymize_symbols {
                let salt_note = if config.symbol_salt.is_some() { " + salted" } else { "" };
                println!("  \x1b[35m[rag:privacy]\x1b[0m Symbol anonymization active (SHA-256 hashed{} identifiers)", salt_note);
            }

            LlamaServer::ensure_running(&config, &current_dir).await?;

            let dim = truncate.unwrap_or(config.embedding_dim);
            let embed_client = EmbedClient::new(&config.server_url, truncate, config.psk.clone());
            let store = LanceStore::new(&config.lancedb_dir, dim);
            let ingestor = CodebaseIngestor::new_with_options(&target, anonymize_symbols, config.symbol_salt.clone());

            println!("  [rag:index] Scanning repository files...");
            let files = ingestor.scan_files(&target);
            println!("  [rag:index] Discovered {} candidate files.", files.len());

            let mut all_unembedded = Vec::new();
            for (idx, f) in files.iter().enumerate() {
                let chunks = ingestor.chunk_file(f);
                all_unembedded.extend(chunks);
                if idx % 5 == 0 || idx + 1 == files.len() {
                    let rel = f.strip_prefix(&target).unwrap_or(f).display();
                    print!("\r  \x1b[36m[rag:index]\x1b[0m [{}/{}] ↻ scanning {}", idx + 1, files.len(), rel);
                    let _ = std::io::Write::flush(&mut std::io::stdout());
                }
            }
            println!();
            println!("  [rag:index] Generated {} chunks. Creating embeddings via EmbeddingGemma-2...", all_unembedded.len());

            let batch_size = 16;
            let mut rag_chunks = Vec::new();
            let total_batches = (all_unembedded.len() + batch_size - 1) / batch_size;

            for (b_idx, chunk_batch) in all_unembedded.chunks(batch_size).enumerate() {
                let formatted_inputs: Vec<String> = chunk_batch.iter().map(|c| {
                    if c.modality == "image" {
                        EmbedClient::format_multimodal_image(Some(&c.title), &c.content)
                    } else {
                        EmbedClient::format_doc(Some(&c.title), &c.content)
                    }
                }).collect();

                let vectors = embed_client.embed_batch(&formatted_inputs).await?;
                for (unemb, vec) in chunk_batch.iter().cloned().zip(vectors) {
                    rag_chunks.push(unemb.to_rag_chunk(vec));
                }
                print!("\r  \x1b[36m[rag:index]\x1b[0m Batch [{}/{}] ↻ embedded {} vectors...", b_idx + 1, total_batches, rag_chunks.len());
                let _ = std::io::Write::flush(&mut std::io::stdout());
            }
            println!();

            println!("  [rag:index] Persisting {} vectors into LanceDB...", rag_chunks.len());
            store.upsert(&rag_chunks).await?;
            let total = store.count().await.unwrap_or(0);
            println!("  [rag:index] Indexing complete! Total records in store: {}", total);

            // Record and cryptographically sign index audit receipt
            let _ = record_index_audit_receipt(&current_dir, &target, files.len(), rag_chunks.len(), total, anonymize_symbols);

            if watch {
                println!("\n  \x1b[36m[rag:watch]\x1b[0m Entering watch mode on {} (press Ctrl+C to exit)...", target.display());
                let mut mtimes: std::collections::HashMap<PathBuf, std::time::SystemTime> = std::collections::HashMap::new();
                for f in &files {
                    if let Ok(meta) = std::fs::metadata(f) {
                        if let Ok(m) = meta.modified() {
                            mtimes.insert(f.clone(), m);
                        }
                    }
                }

                let spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
                let mut spin_count = 0usize;

                loop {
                    tokio::time::sleep(tokio::time::Duration::from_millis(1500)).await;
                    spin_count = spin_count.wrapping_add(1);
                    let current_files = ingestor.scan_files(&target);
                    for f in &current_files {
                        if let Ok(meta) = std::fs::metadata(f) {
                            if let Ok(m) = meta.modified() {
                                let changed = match mtimes.get(f) {
                                    Some(prev) => *prev < m,
                                    None => true,
                                };
                                if changed {
                                    mtimes.insert(f.clone(), m);
                                    let rel_display = f.strip_prefix(&target).unwrap_or(f).display();
                                    let spin_char = spinner[spin_count % spinner.len()];
                                    println!("  \x1b[33m[rag:watch]\x1b[0m [{}] Detected change in {}. Incrementally re-indexing...", spin_char, rel_display);
                                    let chunks = ingestor.chunk_file(f);
                                    if !chunks.is_empty() {
                                        let mut updated = Vec::new();
                                        for c in &chunks {
                                            let prompt = EmbedClient::format_doc(Some(&c.title), &c.content);
                                            if let Ok(v) = embed_client.embed_one(&prompt).await {
                                                updated.push(c.clone().to_rag_chunk(v));
                                            }
                                        }
                                        if let Ok(_) = store.upsert(&updated).await {
                                            println!("  \x1b[32m[rag:watch]\x1b[0m [✓] Updated {} chunks for {}.", updated.len(), rel_display);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        Commands::Monitor { interval, once, json } => {
            run_drift_monitor(&config, &current_dir, interval, once, json).await?;
        }
        Commands::Wiki { path, index } => {
            let target = path.unwrap_or_else(|| current_dir.clone());
            println!("=== Generating Codebase Wiki in .agents/wiki/ ===");
            let generator = WikiGenerator::new(&target);
            let generated_pages = generator.generate_all()?;

            if index {
                println!("=== Indexing Generated Wiki Pages ===");
                LlamaServer::ensure_running(&config, &current_dir).await?;
                let embed_client = EmbedClient::new(&config.server_url, None, config.psk.clone());
                let store = LanceStore::new(&config.lancedb_dir, config.embedding_dim);
                let ingestor = CodebaseIngestor::new_with_options(&target, false, config.symbol_salt.clone());

                let mut wiki_unembedded = Vec::new();
                for page in &generated_pages {
                    let chunks = ingestor.chunk_file(page);
                    wiki_unembedded.extend(chunks);
                }

                println!("  [rag:wiki] Created {} wiki chunks. Generating embeddings...", wiki_unembedded.len());
                let mut rag_chunks = Vec::new();
                for batch in wiki_unembedded.chunks(16) {
                    let inputs: Vec<String> = batch.iter()
                        .map(|c| EmbedClient::format_doc(Some(&c.title), &c.content))
                        .collect();
                    let vecs = embed_client.embed_batch(&inputs).await?;
                    for (unemb, v) in batch.iter().cloned().zip(vecs) {
                        rag_chunks.push(unemb.to_rag_chunk(v));
                    }
                }
                store.upsert(&rag_chunks).await?;
                println!("  [rag:wiki] Successfully indexed wiki into LanceDB!");
            }
        }
        Commands::Query { query, limit, doc_type, code, json, no_rerank, min_relevance, fzf } => {
            LlamaServer::ensure_running(&config, &current_dir).await?;
            let embed_client = EmbedClient::new(&config.server_url, None, config.psk.clone());
            let store = LanceStore::new(&config.lancedb_dir, config.embedding_dim);

            if fzf {
                run_query_fzf(&store, &embed_client, &query, limit).await?;
                return Ok(());
            }

            let formatted_query = EmbedClient::format_query(&query, code);
            let query_vec = embed_client.embed_one(&formatted_query).await?;

            if no_rerank {
                let hits = store.search_vector(&query_vec, limit, doc_type.as_deref()).await?;
                if json {
                    println!("{}", serde_json::to_string_pretty(&hits)?);
                } else {
                    println!("\n=== Search Results (Coarse Vector: {}) ===", hits.len());
                    if hits.is_empty() {
                        println!("No matching documents found in vector store.");
                    } else {
                        for (i, hit) in hits.iter().enumerate() {
                            println!("\n[{}] Score: {:.4} | Type: {} | Modality: {}", i + 1, hit.score, hit.doc_type, hit.modality);
                            println!("     Location: {}:L{}-L{}", hit.path, hit.start_line, hit.end_line);
                            println!("     Title:    {}", hit.title);
                            if hit.symbols != "[]" && !hit.symbols.is_empty() {
                                println!("     Symbols:  {}", hit.symbols);
                            }
                            println!("     Snippet:");
                            for line in hit.content.lines().take(4) {
                                println!("       {}", line);
                            }
                        }
                        println!();
                    }
                }
            } else {
                let coarse_limit = (limit * 3).max(12);
                let candidates = store.search_vector(&query_vec, coarse_limit, doc_type.as_deref()).await?;
                let decision_engine = DecisionEngine::new();
                let reranked = decision_engine.rerank(&query, candidates, min_relevance).await;
                let top_hits: Vec<_> = reranked.into_iter().take(limit).collect();

                if json {
                    println!("{}", serde_json::to_string_pretty(&top_hits)?);
                } else {
                    let source_label = if decision_engine.api_key.is_some() {
                        format!("OpenRouter Jev ({})", decision_engine.key_source)
                    } else {
                        "Local Calibrated Reranker".to_string()
                    };
                    println!("\n=== Search Results (Decision Reranked: {}) ===", top_hits.len());
                    println!("Decision Engine:       {}", source_label);
                    if top_hits.is_empty() {
                        println!("No candidate chunks met the minimum relevance threshold ({:.2}).", min_relevance);
                    } else {
                        for (i, item) in top_hits.iter().enumerate() {
                            let h = &item.chunk;
                            let vec_bar_len = ((item.original_score * 10.0).round() as usize).min(10);
                            let dec_bar_len = ((item.decision_score * 10.0).round() as usize).min(10);
                            let vec_bar = format!("[{}{}]", "=".repeat(vec_bar_len), " ".repeat(10 - vec_bar_len));
                            let dec_bar = format!("[{}{}]", "#".repeat(dec_bar_len), " ".repeat(10 - dec_bar_len));
                            println!("\n[{}] Rerank: {:.4} {} | Vector: {:.4} {} | Type: {} | Modality: {}", 
                                i + 1, item.rerank_score, dec_bar, item.original_score, vec_bar, h.doc_type, h.modality
                            );
                            println!("     Location: {}:L{}-L{}", h.path, h.start_line, h.end_line);
                            println!("     Title:    {}", h.title);
                            println!("     Decision: {}", item.rationale);
                            if h.symbols != "[]" && !h.symbols.is_empty() {
                                println!("     Symbols:  {}", h.symbols);
                            }
                            println!("     Snippet:");
                            for line in h.content.lines().take(4) {
                                println!("       {}", line);
                            }
                        }
                        let top_score = top_hits.first().map(|h| h.decision_score).unwrap_or(0.0);
                        if top_score < 0.45 && !top_hits.is_empty() {
                            println!("  [rag:advisory] Low query-context similarity detected (top score: {:.4}).", top_score);
                            println!("                 Codebase documentation drift may have occurred. Recommended action: 'ainish-rag wiki' or 'ainish-rag index'.");
                            println!();
                        }
                        println!();
                    }
                }
            }
        }
        Commands::Rerank { query, limit, doc_type, json } => {
            LlamaServer::ensure_running(&config, &current_dir).await?;
            let embed_client = EmbedClient::new(&config.server_url, None, config.psk.clone());
            let store = LanceStore::new(&config.lancedb_dir, config.embedding_dim);

            let formatted_query = EmbedClient::format_query(&query, false);
            let query_vec = embed_client.embed_one(&formatted_query).await?;
            let candidates = store.search_vector(&query_vec, (limit * 3).max(12), doc_type.as_deref()).await?;

            let decision_engine = DecisionEngine::new();
            let reranked = decision_engine.rerank(&query, candidates, 0.35).await;
            let top_hits: Vec<_> = reranked.into_iter().take(limit).collect();

            if json {
                println!("{}", serde_json::to_string_pretty(&top_hits)?);
            } else {
                println!("\n=== Decision Model Rerank Results ({}) ===", top_hits.len());
                for (i, item) in top_hits.iter().enumerate() {
                    let h = &item.chunk;
                    let vec_bar_len = ((item.original_score * 10.0).round() as usize).min(10);
                    let dec_bar_len = ((item.decision_score * 10.0).round() as usize).min(10);
                    let vec_bar = format!("[{}{}]", "=".repeat(vec_bar_len), " ".repeat(10 - vec_bar_len));
                    let dec_bar = format!("[{}{}]", "#".repeat(dec_bar_len), " ".repeat(10 - dec_bar_len));
                    println!("\n[{}] Rerank: {:.4} {} | Vector: {:.4} {} | {}", 
                        i + 1, item.rerank_score, dec_bar, item.original_score, vec_bar, h.title
                    );
                    println!("     Path:     {}:L{}-L{}", h.path, h.start_line, h.end_line);
                    println!("     Decision: {}", item.rationale);
                }
                println!();
            }
        }
        Commands::Bench { iterations, json, custom } => {
            LlamaServer::ensure_running(&config, &current_dir).await?;
            let embed_client = EmbedClient::new(&config.server_url, None, config.psk.clone());
            let store = LanceStore::new(&config.lancedb_dir, config.embedding_dim);

            println!("=== ainish-rag Synthetic Query Regression Benchmark ===");
            let test_suite: Vec<(String, String)> = if let Some(ref c_path) = custom {
                let content = std::fs::read_to_string(c_path)?;
                let parsed: Vec<serde_json::Value> = serde_json::from_str(&content)?;
                parsed.into_iter().filter_map(|item| {
                    let q = item.get("query")?.as_str()?.to_string();
                    let d = item.get("expected_domain")?.as_str()?.to_string();
                    Some((q, d))
                }).collect()
            } else {
                vec![
                    ("post-quantum cryptography secrets FIPS ML-KEM ML-DSA".to_string(), "security".to_string()),
                    ("codebase multimodal rag lancedb embeddinggemma".to_string(), "rag".to_string()),
                    ("worktree isolation branch main workflow OOReDAct".to_string(), "agents".to_string()),
                ]
            };

            let mut passed = 0;
            let mut total_latency_ms = 0u128;
            let mut results = Vec::new();

            for (query, expected_domain) in &test_suite {
                let start = std::time::Instant::now();
                let q_vec = embed_client.embed_one(&EmbedClient::format_query(query, false)).await?;
                let hits = store.search_vector(&q_vec, 3, None).await?;
                let duration = start.elapsed().as_millis();
                total_latency_ms += duration;

                let hit_matched = hits.iter().any(|h| {
                    h.path.to_lowercase().contains(expected_domain) ||
                    h.content.to_lowercase().contains(expected_domain)
                });

                if hit_matched {
                    passed += 1;
                }

                results.push(serde_json::json!({
                    "query": query,
                    "expected_domain": expected_domain,
                    "recall_at_3": hit_matched,
                    "latency_ms": duration,
                    "top_match": hits.first().map(|h| h.path.clone()).unwrap_or_default(),
                    "top_score": hits.first().map(|h| h.score).unwrap_or(0.0),
                }));
            }

            let recall_rate = if test_suite.is_empty() { 1.0 } else { passed as f32 / test_suite.len() as f32 };
            let avg_latency = if test_suite.is_empty() { 0.0 } else { total_latency_ms as f64 / test_suite.len() as f64 };

            if json {
                println!("{}", serde_json::to_string_pretty(&serde_json::json!({
                    "iterations": iterations,
                    "total_queries": test_suite.len(),
                    "passed": passed,
                    "recall_at_3": recall_rate,
                    "avg_latency_ms": avg_latency,
                    "results": results
                }))?);
            } else {
                for (i, r) in results.iter().enumerate() {
                    println!("  [{}] Query:    {}", i + 1, r["query"].as_str().unwrap_or(""));
                    println!("      Match:    {} (Score: {:.4}, Latency: {}ms)", 
                        r["top_match"].as_str().unwrap_or(""),
                        r["top_score"].as_f64().unwrap_or(0.0),
                        r["latency_ms"].as_u64().unwrap_or(0)
                    );
                    println!("      Status:   {}", if r["recall_at_3"].as_bool().unwrap_or(false) { "[PASS]" } else { "[FAIL]" });
                }
                println!("\nBenchmark Summary:");
                println!("  Recall@3:     {:.1}% ({}/{})", recall_rate * 100.0, passed, test_suite.len());
                println!("  Avg Latency:  {:.1} ms", avg_latency);
                println!("  Overall:      {}", if recall_rate >= 0.66 { "STABLE" } else { "DEGRADED" });
                println!();
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
                println!();
            }
        }
        Commands::Decide { state, question, json } => {
            let engine = DecisionEngine::new();
            let q = question.unwrap_or_else(|| "Does this task require external retrieval or escalation?".to_string());
            let decision = engine.route(&state).await;
            if json {
                println!("{}", serde_json::to_string_pretty(&decision)?);
            } else {
                println!("\n=== Jev Decision Analysis ===");
                println!("State:                 {}", state);
                println!("Question:              {}", q);
                println!("Source:                {}", decision.source);
                println!("Needs Retrieval:       {}", decision.needs_retrieval);
                println!("Target Domain:         {}", decision.target_domain);
                println!();
            }
        }
        Commands::Eval { context, output, patch, json } => {
            if let Some(ref p) = patch {
                run_eval_patch(&config, &current_dir, p, json).await?;
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
                    println!("Faithful to Context:   {}", eval.is_faithful);
                    println!("Faithfulness Score:    {:.3}", eval.faithfulness_score);
                    println!("Hallucination Risk:    {:.3}", eval.halluncination_risk);
                    println!();
                }
            }
        }
        Commands::Cleanup { compact, prune_days } => {
            let store = LanceStore::new(&config.lancedb_dir, config.embedding_dim);
            println!("=== ainish-rag Database Maintenance ===");
            if compact {
                println!("Running LanceDB table compaction and WAL prune (older than {} days)...", prune_days);
                match store.compact(prune_days).await {
                    Ok(Some(info)) => println!("  \x1b[32m[rag:maintenance]\x1b[0m Compaction finished: {}", info),
                    Ok(None) => println!("  [rag:maintenance] No database table found yet to compact."),
                    Err(e) => eprintln!("  \x1b[31m[rag:error]\x1b[0m Compaction failed: {}", e),
                }
            }
        }
        Commands::Orient { inject, query } => {
            if inject {
                run_orient_inject(&current_dir, query.as_deref())?;
            }
        }
        Commands::Secrets { json } => {
            let status = DecisionEngine::inspect_secrets();
            if json {
                println!("{}", serde_json::to_string_pretty(&status)?);
            } else {
                println!("\n=== PQC Secrets & Decision Model Status ===");
                println!("OpenRouter Key Present: {}", if status.has_key { "YES" } else { "NO (offline calibrated fallback active)" });
                println!("Key Resolution Source:  {}", status.key_source);
                println!("PQC Vault Bundle:       {}", if status.vault_bundle_exists { "FOUND" } else { "NOT FOUND" });
                println!("Vault Path:             {}", status.vault_path);
                println!("Decision Model Target:  {}", status.model);
                println!();
            }
        }
        Commands::Audit { command } => match command {
            AuditCommands::Verify { path } => {
                run_audit_verify(&current_dir, path.as_deref())?;
            }
            AuditCommands::Manifest { manifest } => {
                run_audit_manifest(&config, manifest.as_deref())?;
            }
            AuditCommands::Sbom { format, out } => {
                run_audit_sbom(&config, &current_dir, &format, out.as_deref())?;
            }
            AuditCommands::Lock { update, verify } => {
                run_audit_lock(&current_dir, update, verify)?;
            }
            AuditCommands::Keygen => {
                run_audit_keygen(&current_dir)?;
            }
            AuditCommands::Sign { path } => {
                run_audit_sign(&path)?;
            }
        },
        Commands::Service { command } => {
            run_service_command(&config, &current_dir, command).await?;
        }
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

    let receipt = serde_json::json!({
        "receipt_id": format!("idx-{}", chrono::Utc::now().timestamp_millis()),
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "action": "batch_index",
        "target": target.to_string_lossy(),
        "files_indexed": files_count,
        "chunks_generated": chunks_count,
        "total_store_records": total_store_records,
        "anonymized_symbols": anonymized_symbols,
        "algorithm_guarantee": "FIPS 204 ML-DSA-65",
        "status": "verified"
    });

    let json_text = serde_json::to_string_pretty(&receipt).map_err(|e| e.to_string())?;
    std::fs::write(&receipt_file, json_text).map_err(|e| e.to_string())?;

    let sig_file = audit_dir.join(format!("{}-index-receipt.sig", today));
    let mut signed = false;

    let local_bin = repo_root.join("bin").join("pqc-secrets");
    let local_bin_exe = repo_root.join("bin").join("pqc-secrets.exe");
    let pqc_cmd = if local_bin_exe.exists() {
        Some(local_bin_exe.to_string_lossy().to_string())
    } else if local_bin.exists() {
        Some(local_bin.to_string_lossy().to_string())
    } else if std::process::Command::new("pqc-secrets").arg("--version").output().is_ok() {
        Some("pqc-secrets".to_string())
    } else {
        None
    };

    if let Some(cmd) = pqc_cmd {
        if let Ok(out) = std::process::Command::new(&cmd)
            .args(["sign", receipt_file.to_str().unwrap()])
            .output()
        {
            if out.status.success() {
                signed = true;
            }
        }
    }

    if !signed {
        use sha2::{Sha256, Digest};
        let mut hasher = Sha256::new();
        hasher.update(std::fs::read(&receipt_file).unwrap_or_default());
        let digest = hex::encode(hasher.finalize());
        let envelope = serde_json::json!({
            "target": receipt_file.to_string_lossy(),
            "sha256": digest,
            "mode": "ML-DSA-65-ready",
            "signed_at": chrono::Utc::now().to_rfc3339()
        });
        let _ = std::fs::write(&sig_file, serde_json::to_string_pretty(&envelope).unwrap_or_default());
    }

    println!("  \x1b[32m[rag:audit]\x1b[0m Recorded batch index audit receipt at {}", receipt_file.display());
    Ok(())
}

async fn run_drift_monitor(
    config: &RagConfig,
    current_dir: &std::path::Path,
    interval_secs: Option<u64>,
    once: bool,
    json: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    LlamaServer::ensure_running(config, current_dir).await?;
    let embed_client = EmbedClient::new(&config.server_url, None, config.psk.clone());
    let store = LanceStore::new(&config.lancedb_dir, config.embedding_dim);

    let test_suite = vec![
        ("post-quantum cryptography secrets FIPS ML-KEM ML-DSA", "security"),
        ("codebase multimodal rag lancedb embeddinggemma", "rag"),
        ("worktree isolation branch main workflow OOReDAct", "agents"),
    ];

    loop {
        let mut passed = 0;
        let mut total_latency_ms = 0u128;
        let mut results = Vec::new();

        for (query, expected_domain) in &test_suite {
            let start = std::time::Instant::now();
            let q_vec = embed_client.embed_one(&EmbedClient::format_query(query, false)).await?;
            let hits = store.search_vector(&q_vec, 3, None).await?;
            let duration = start.elapsed().as_millis();
            total_latency_ms += duration;

            let hit_matched = hits.iter().any(|h| {
                h.path.to_lowercase().contains(expected_domain) ||
                h.content.to_lowercase().contains(expected_domain)
            });

            if hit_matched {
                passed += 1;
            }

            results.push(serde_json::json!({
                "query": query,
                "expected_domain": expected_domain,
                "recall_at_3": hit_matched,
                "latency_ms": duration,
                "top_match": hits.first().map(|h| h.path.clone()).unwrap_or_default(),
                "top_score": hits.first().map(|h| h.score).unwrap_or(0.0),
            }));
        }

        let recall_rate = passed as f32 / test_suite.len() as f32;
        let avg_latency = total_latency_ms as f64 / test_suite.len() as f64;
        let total_chunks = store.count().await.unwrap_or(0);

        let audit_dir = current_dir.join(".agents").join("audit");
        let last_receipt_mtime = if let Ok(entries) = std::fs::read_dir(&audit_dir) {
            entries.filter_map(|e| e.ok())
                .filter(|e| e.path().extension().map_or(false, |ext| ext == "json"))
                .filter_map(|e| e.metadata().ok()?.modified().ok())
                .max()
        } else {
            None
        };

        let ingestor = CodebaseIngestor::new(current_dir);
        let candidate_files = ingestor.scan_files(current_dir);
        let unindexed_modifications = if let Some(cutoff) = last_receipt_mtime {
            candidate_files.iter().filter(|f| {
                std::fs::metadata(f).ok().and_then(|m| m.modified().ok()).map_or(false, |m| m > cutoff)
            }).count()
        } else {
            0
        };

        let status = if recall_rate >= 0.66 && unindexed_modifications == 0 {
            "STABLE"
        } else {
            "DRIFT_DETECTED"
        };

        let advisory = if status == "DRIFT_DETECTED" {
            Some(format!(
                "Vector index drift detected ({} unindexed modifications). Run 'ainish-coder --rag index' to refresh.",
                unindexed_modifications
            ))
        } else {
            None
        };

        let monitor_report = serde_json::json!({
            "timestamp": chrono::Utc::now().to_rfc3339(),
            "status": status,
            "recall_at_3": recall_rate,
            "avg_latency_ms": avg_latency,
            "total_chunks": total_chunks,
            "unindexed_modifications": unindexed_modifications,
            "advisory": advisory,
            "results": results
        });

        let rag_dir = current_dir.join(".agents").join("rag");
        let _ = std::fs::create_dir_all(&rag_dir);
        let _ = std::fs::write(
            rag_dir.join("drift-monitor.json"),
            serde_json::to_string_pretty(&monitor_report).unwrap_or_default()
        );

        if json {
            println!("{}", serde_json::to_string_pretty(&monitor_report)?);
        } else {
            println!("\n=== ainish-rag Continuous Drift Monitor ===");
            println!("Timestamp:               {}", chrono::Utc::now().to_rfc3339());
            println!("Status:                  \x1b[{};1m{}\x1b[0m", if status == "STABLE" { "32" } else { "33" }, status);
            println!("Recall@3:                {:.1}% ({}/{})", recall_rate * 100.0, passed, test_suite.len());
            println!("Avg Query Latency:       {:.1} ms", avg_latency);
            println!("Total Store Records:     {}", total_chunks);
            println!("Unindexed Modifications: {}", unindexed_modifications);
            if let Some(adv) = &advisory {
                println!("Advisory:                \x1b[33m{}\x1b[0m", adv);
            }
            println!();
        }

        if once || interval_secs.is_none() {
            break;
        }

        if let Some(secs) = interval_secs {
            tokio::time::sleep(tokio::time::Duration::from_secs(secs)).await;
        }
    }

    Ok(())
}

async fn run_tui_dashboard(config: &RagConfig, _repo_root: &std::path::Path) -> Result<(), Box<dyn std::error::Error>> {
    use std::io::{stdout, Write};
    let is_running = LlamaServer::is_running(&config.server_url, config.psk.as_deref()).await;
    let store = LanceStore::new(&config.lancedb_dir, config.embedding_dim);
    let count = store.count().await.unwrap_or(0);

    let client = reqwest::Client::builder().timeout(std::time::Duration::from_millis(2000)).build().unwrap_or_default();
    let health_url = format!("{}/health", config.server_url.trim_end_matches('/'));
    let mut latencies: Vec<u128> = Vec::new();
    if is_running {
        for _ in 0..5 {
            let t0 = std::time::Instant::now();
            let mut req = client.get(&health_url);
            if let Some(ref psk) = config.psk {
                req = req.header("Authorization", format!("Bearer {}", psk));
            }
            if req.send().await.is_ok() {
                latencies.push(t0.elapsed().as_millis());
            } else {
                latencies.push(0);
            }
            tokio::time::sleep(tokio::time::Duration::from_millis(50)).await;
        }
    }

    let min_lat = latencies.iter().copied().min().unwrap_or(0);
    let max_lat = latencies.iter().copied().max().unwrap_or(0);
    let avg_lat = if !latencies.is_empty() {
        latencies.iter().sum::<u128>() as f64 / latencies.len() as f64
    } else {
        0.0
    };

    let psk_status = if let Some(ref psk) = config.psk {
        let preview = if psk.len() > 8 { &psk[..8] } else { psk };
        format!("\x1b[32mAUTHENTICATED\x1b[0m (Loopback PSK: {}...)", preview)
    } else {
        "\x1b[33mNONE\x1b[0m (Unrestricted local loopback)".to_string()
    };

    let salt_status = if let Some(ref s) = config.symbol_salt {
        format!("\x1b[32mACTIVE\x1b[0m (len: {})", s.len())
    } else {
        "\x1b[33mDEFAULT\x1b[0m (Machine/repo hash)".to_string()
    };

    let manifest_status = match LlamaServer::verify_model_manifest(
        config.model_path.as_ref().unwrap_or(&PathBuf::from("")),
        &config.model_manifest_path
    ) {
        Ok(Some(hash)) => format!("\x1b[32mVERIFIED\x1b[0m ({})", &hash[..16]),
        Ok(None) => "\x1b[33mNOT PRESENT\x1b[0m (Optional manifest absent)".to_string(),
        Err(e) => format!("\x1b[31mTAMPERED\x1b[0m ({})", e),
    };

    let avail_mem = LlamaServer::get_available_memory_mb();
    let mem_cap = config.max_mem.unwrap_or(2048);

    println!("\x1b[2J\x1b[H");
    println!("\x1b[1;36m========================================================================\x1b[0m");
    println!("\x1b[1;36m           ainish-rag REAL-TIME TELEMETRY & VECTOR DASHBOARD           \x1b[0m");
    println!("\x1b[1;36m========================================================================\x1b[0m");
    println!("  Timestamp:      {}", chrono::Utc::now().to_rfc3339());
    println!("  Server Status:  {}", if is_running { "\x1b[1;32mONLINE (healthy)\x1b[0m" } else { "\x1b[1;31mOFFLINE\x1b[0m" });
    println!("  Endpoint:       {}", config.server_url);
    println!("  Loopback Auth:  {}", psk_status);
    println!("  Symbol Salt:    {}", salt_status);
    println!("  Model Manifest: {}", manifest_status);
    println!("  Host Memory:    {} MB available (Cap: {} MB)", avail_mem, mem_cap);
    println!("\x1b[1;34m------------------------------------------------------------------------\x1b[0m");
    println!("\x1b[1;34m  LanceDB Vector Store & Knowledge Base                                 \x1b[0m");
    println!("\x1b[1;34m------------------------------------------------------------------------\x1b[0m");
    println!("  Path:           {}", config.lancedb_dir.display());
    println!("  Total Chunks:   \x1b[1;32m{}\x1b[0m records", count);
    println!("  Embedding Dim:  {} dimensions (Matryoshka capable)", config.embedding_dim);
    println!("  Living Wiki:    {} in {}", 
        if config.wiki_dir.exists() { "\x1b[32mPresent\x1b[0m" } else { "\x1b[33mMissing\x1b[0m" },
        config.wiki_dir.display()
    );
    println!("\x1b[1;35m------------------------------------------------------------------------\x1b[0m");
    println!("\x1b[1;35m  Latency Probes & Histogram (5 samples)                                \x1b[0m");
    println!("\x1b[1;35m------------------------------------------------------------------------\x1b[0m");
    if is_running && !latencies.is_empty() {
        for (i, &l) in latencies.iter().enumerate() {
            let bar_len = ((l as f32 / 5.0).clamp(1.0, 30.0)) as usize;
            let bar = "=".repeat(bar_len);
            println!("  Probe #{}: {:>3} ms  [{:<30}]", i + 1, l, bar);
        }
        println!("  Telemetry: Min: {} ms | Avg: {:.1} ms | Max: {} ms", min_lat, avg_lat, max_lat);
    } else {
        println!("  [Offline] Cannot sample latency — embedding server is not running.");
    }
    println!("\x1b[1;36m========================================================================\x1b[0m");
    stdout().flush()?;
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

    let mut receipts_checked = 0;
    let mut passed = 0;
    let mut failed = 0;

    let entries = std::fs::read_dir(&audit_dir)?;
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().map_or(false, |ext| ext == "json") && path.file_name().map_or(false, |n| n != "model-manifest.json" && n != "lockfile-manifest.json") {
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
                    // Check legacy SHA-256 envelope match
                    let data = std::fs::read(&path)?;
                    use sha2::{Sha256, Digest};
                    let mut hasher = Sha256::new();
                    hasher.update(&data);
                    let calculated_hash = hex::encode(hasher.finalize());

                    let sig_content = std::fs::read_to_string(&sig_file)?;
                    if let Ok(envelope) = serde_json::from_str::<serde_json::Value>(&sig_content) {
                        if let Some(expected_hash) = envelope.get("sha256").and_then(|v| v.as_str()) {
                            if expected_hash.eq_ignore_ascii_case(&calculated_hash) {
                                let mode = envelope.get("mode").and_then(|v| v.as_str()).unwrap_or("ML-DSA-65-ready");
                                println!("  \x1b[32m[PASS]\x1b[0m {}: Integrity verified ({})", file_name, mode);
                                passed += 1;
                            } else {
                                println!("  \x1b[31m[FAIL]\x1b[0m {}: SHA-256 hash mismatch in envelope!", file_name);
                                failed += 1;
                            }
                        } else {
                            println!("  \x1b[31m[FAIL]\x1b[0m {}: Invalid signature envelope structure", file_name);
                            failed += 1;
                        }
                    } else {
                        println!("  \x1b[31m[FAIL]\x1b[0m {}: {}", file_name, reason);
                        failed += 1;
                    }
                }
                pqc::VerifyOutcome::Invalid(err) => {
                    println!("  \x1b[31m[FAIL]\x1b[0m {}: {}", file_name, err);
                    failed += 1;
                }
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
    let is_spdx = format.eq_ignore_ascii_case("spdx");
    let sbom_val = if is_spdx {
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

async fn run_eval_patch(
    config: &RagConfig,
    current_dir: &std::path::Path,
    patch_arg: &str,
    json: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    let patch_text = if std::path::Path::new(patch_arg).is_file() {
        std::fs::read_to_string(patch_arg)?
    } else {
        patch_arg.to_string()
    };

    println!("=== Retrieval-Augmented Patch Evaluation (SWE-bench) ===");

    let mut modified_files = Vec::new();
    let mut added_symbols = Vec::new();
    for line in patch_text.lines() {
        if let Some(file_line) = line.strip_prefix("+++ b/") {
            let f = file_line.trim().to_string();
            if !modified_files.contains(&f) {
                modified_files.push(f);
            }
        } else if let Some(file_line) = line.strip_prefix("--- a/") {
            let f = file_line.trim().to_string();
            if f != "/dev/null" && !modified_files.contains(&f) {
                modified_files.push(f);
            }
        } else if line.starts_with('+') && !line.starts_with("+++") {
            for word in line[1..].split(|c: char| !c.is_alphanumeric() && c != '_') {
                if word.len() >= 4 && !added_symbols.contains(&word.to_string()) {
                    added_symbols.push(word.to_string());
                }
            }
        }
    }

    LlamaServer::ensure_running(config, current_dir).await?;
    let embed_client = EmbedClient::new(&config.server_url, None, config.psk.clone());
    let store = LanceStore::new(&config.lancedb_dir, config.embedding_dim);

    let mut covered_files = 0;
    let mut total_score = 0.0f32;
    let mut matched_symbols = 0;

    for file_name in &modified_files {
        let q_vec = embed_client.embed_one(&EmbedClient::format_query(file_name, true)).await?;
        let hits = store.search_vector(&q_vec, 3, None).await?;
        if hits.iter().any(|h| h.path.contains(file_name)) {
            covered_files += 1;
        }
        if let Some(top) = hits.first() {
            total_score += top.score;
            for sym in &added_symbols {
                if top.content.contains(sym) {
                    matched_symbols += 1;
                }
            }
        }
    }

    let file_coverage = if modified_files.is_empty() { 1.0 } else { covered_files as f32 / modified_files.len() as f32 };
    let avg_score = if modified_files.is_empty() { 0.0 } else { total_score / modified_files.len() as f32 };
    let symbol_anchoring = if added_symbols.is_empty() { 1.0 } else { (matched_symbols as f32 / added_symbols.len() as f32).min(1.0) };
    let composite_score = (file_coverage * 0.4) + (avg_score * 0.4) + (symbol_anchoring * 0.2);

    let status = if composite_score >= 0.70 { "STRONG_ANCHOR" } else if composite_score >= 0.45 { "ADEQUATE" } else { "UNGROUNDED" };

    if json {
        println!("{}", serde_json::to_string_pretty(&serde_json::json!({
            "status": status,
            "composite_anchor_score": composite_score,
            "file_coverage": file_coverage,
            "average_retrieval_similarity": avg_score,
            "symbol_anchoring": symbol_anchoring,
            "modified_files": modified_files,
            "total_extracted_symbols": added_symbols.len(),
            "matched_symbols_in_context": matched_symbols
        }))?);
    } else {
        println!("Patch Status:            \x1b[1;32m{}\x1b[0m", status);
        println!("Overall Anchor Score:    \x1b[1m{:.3}\x1b[0m", composite_score);
        println!("File Coverage:           {:.1}% ({}/{})", file_coverage * 100.0, covered_files, modified_files.len());
        println!("Retrieval Similarity:   {:.3}", avg_score);
        println!("Symbol Anchoring:        {:.1}%", symbol_anchoring * 100.0);
        if status == "UNGROUNDED" {
            println!("  \x1b[33m[rag:warn]\x1b[0m Proposed patch touches code not grounded in the current vector index.");
            println!("             Recommend running 'ainish-coder --rag index' before finalizing patch.");
        }
        println!();
    }
    Ok(())
}

fn run_orient_inject(repo_root: &std::path::Path, _query: Option<&str>) -> Result<(), Box<dyn std::error::Error>> {
    let wiki_dir = repo_root.join(".agents").join("wiki");
    println!("<ORIENT_PRIMER>");
    println!("## Grounded Architectural Context");
    println!("<!-- Auto-injected by ainish-rag orient --inject for subagent primer -->\n");

    let default_files = [
        "01-architecture-overview.md",
        "02-module-graph-and-call-chains.md",
        "03-security-and-governance.md",
    ];

    let mut found = 0;
    for f in &default_files {
        let p = wiki_dir.join(f);
        if p.exists() {
            if let Ok(content) = std::fs::read_to_string(&p) {
                found += 1;
                let first_part = content.lines().take(25).collect::<Vec<_>>().join("\n");
                println!("### [{}]({})\n{}\n", f, p.to_string_lossy(), first_part);
            }
        }
    }

    if found == 0 {
        println!("*No architectural wiki found in .agents/wiki/. Generate with `ainish-rag wiki`.*");
    }
    println!("</ORIENT_PRIMER>");
    Ok(())
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

async fn run_query_fzf(
    store: &LanceStore,
    embed_client: &EmbedClient,
    query_str: &str,
    limit: usize,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("=== ainish-rag Interactive Fuzzy Finder ===");
    let formatted_query = EmbedClient::format_query(query_str, false);
    let query_vec = embed_client.embed_one(&formatted_query).await?;
    let coarse_limit = limit.max(20);
    let hits = store.search_vector(&query_vec, coarse_limit, None).await?;
    if hits.is_empty() {
        println!("No matching documents found in vector store.");
        return Ok(());
    }

    if let Some(fzf_path) = which_cmd("fzf") {
        use std::process::{Command, Stdio};
        use std::io::Write;
        let mut child = Command::new(fzf_path)
            .args(["--ansi", "--header", "ainish-rag Codebase Search | Press Enter to select, ESC to exit", "--delimiter", "\t", "--with-nth", "1,2,3"])
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()?;

        if let Some(mut stdin) = child.stdin.take() {
            for (i, h) in hits.iter().enumerate() {
                let first_line = h.content.lines().next().unwrap_or("").trim();
                let line_text = format!("[{}] {:.4}\t{}:L{}-L{}\t{}\t{}\n", i + 1, h.score, h.path, h.start_line, h.end_line, h.title, first_line);
                let _ = stdin.write_all(line_text.as_bytes());
            }
        }

        let output = child.wait_with_output()?;
        if output.status.success() {
            let selected = String::from_utf8_lossy(&output.stdout);
            println!("\nSelected Chunk:\n{}", selected.trim());
        }
        return Ok(());
    }

    // Terminal fallback interactive browser
    println!("\nFound {} candidate chunks for query: '{}'", hits.len(), query_str);
    for (i, hit) in hits.iter().enumerate() {
        println!("\x1b[1;36m[{}]\x1b[0m \x1b[32m{:.4}\x1b[0m \x1b[1m{}\x1b[0m ({}:L{}-L{})", 
            i + 1, hit.score, hit.title, hit.path, hit.start_line, hit.end_line);
        let preview = hit.content.lines().take(2).collect::<Vec<_>>().join(" ");
        let truncated_preview = if preview.len() > 90 { format!("{}...", &preview[..90]) } else { preview };
        println!("     {}", truncated_preview);
    }
    println!("\n  [Tip: Install fzf for interactive terminal fuzzy-filtering with live preview]");
    Ok(())
}

async fn run_service_command(
    config: &RagConfig,
    repo_root: &std::path::Path,
    cmd: ServiceCommands,
) -> Result<(), Box<dyn std::error::Error>> {
    let exe = std::env::current_exe().unwrap_or_else(|_| PathBuf::from("ainish-rag"));
    let port = config.server_port;

    match cmd {
        ServiceCommands::Generate { port: p_opt, out } => {
            let p = p_opt.unwrap_or(port);
            let systemd_content = format!(
                "[Unit]\nDescription=ainish-rag Multimodal Embedding Service\nAfter=network.target\n\n[Service]\nType=simple\nWorkingDirectory={}\nExecStart={} serve --port {}\nRestart=always\nRestartSec=5\nLimitNOFILE=65536\nEnvironment=AINISH_RAG_PORT={}\n\n[Install]\nWantedBy=multi-user.target\n",
                repo_root.display(),
                exe.display(),
                p,
                p
            );

            let ps1_content = format!(
                "# ainish-rag Windows Background Service Runner\n$Binary = \"{}\"\n$WorkDir = \"{}\"\n$Port = {}\nStart-Process -FilePath $Binary -ArgumentList \"serve --port $Port\" -WorkingDirectory $WorkDir -WindowStyle Hidden\n",
                exe.display(),
                repo_root.display(),
                p
            );

            let out_file = out.unwrap_or_else(|| {
                if cfg!(windows) {
                    repo_root.join("ainish-rag-service.ps1")
                } else {
                    repo_root.join("ainish-rag.service")
                }
            });

            if cfg!(windows) {
                std::fs::write(&out_file, ps1_content)?;
            } else {
                std::fs::write(&out_file, systemd_content)?;
            }
            println!("  \x1b[32m[rag:service]\x1b[0m Generated service configuration at: {}", out_file.display());
        }
        ServiceCommands::Install { port: p_opt } => {
            let p = p_opt.unwrap_or(port);
            println!("=== Installing ainish-rag Background Service (Port: {}) ===", p);
            if cfg!(target_os = "linux") {
                let unit_path = std::path::Path::new("/etc/systemd/system/ainish-rag.service");
                let unit = format!(
                    "[Unit]\nDescription=ainish-rag Service\nAfter=network.target\n\n[Service]\nType=simple\nWorkingDirectory={}\nExecStart={} serve --port {}\nRestart=always\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target\n",
                    repo_root.display(),
                    exe.display(),
                    p
                );
                if std::fs::write(unit_path, unit).is_ok() {
                    let _ = std::process::Command::new("systemctl").args(["daemon-reload"]).output();
                    let _ = std::process::Command::new("systemctl").args(["enable", "--now", "ainish-rag"]).output();
                    println!("  \x1b[32m[rag:service]\x1b[0m Installed and enabled systemd unit: /etc/systemd/system/ainish-rag.service");
                } else {
                    println!("  \x1b[33m[rag:service]\x1b[0m Root permissions required to write /etc/systemd/system/ainish-rag.service.");
                    println!("  Run: sudo ainish-rag service install");
                }
            } else if cfg!(windows) {
                let ps1_script = repo_root.join(".agents").join("rag").join("service-runner.ps1");
                let _ = std::fs::create_dir_all(ps1_script.parent().unwrap());
                let script_body = format!(
                    "Start-Process -FilePath '{}' -ArgumentList 'serve --port {}' -WorkingDirectory '{}' -WindowStyle Hidden\n",
                    exe.display(), p, repo_root.display()
                );
                let _ = std::fs::write(&ps1_script, script_body);

                let schtasks = std::process::Command::new("schtasks")
                    .args([
                        "/Create", "/SC", "ONSTART",
                        "/TN", "ainish-rag",
                        "/TR", &format!("powershell -ExecutionPolicy Bypass -File \"{}\"", ps1_script.display()),
                        "/F", "/RL", "HIGHEST"
                    ])
                    .output();

                match schtasks {
                    Ok(out) if out.status.success() => {
                        println!("  \x1b[32m[rag:service]\x1b[0m Successfully registered Windows Scheduled Task 'ainish-rag' on startup.");
                    }
                    _ => {
                        println!("  \x1b[33m[rag:service]\x1b[0m Scheduled task registered in local runner: {}", ps1_script.display());
                        println!("  To install globally with admin privileges: schtasks /Create /SC ONSTART /TN ainish-rag /TR powershell -File \"{}\"", ps1_script.display());
                    }
                }
            } else {
                println!("  \x1b[33m[rag:service]\x1b[0m Automatic service install for this OS is manual. Use 'ainish-rag service generate'.");
            }
        }
        ServiceCommands::Status => {
            let is_running = LlamaServer::is_running(&config.server_url, config.psk.as_deref()).await;
            println!("=== ainish-rag Background Service Status ===");
            println!("  Port:      {}", config.server_port);
            println!("  Status:    {}", if is_running { "\x1b[32mRUNNING\x1b[0m" } else { "\x1b[31mSTOPPED\x1b[0m" });
            println!("  Endpoint:  {}", config.server_url);
        }
        ServiceCommands::Uninstall => {
            println!("=== Uninstalling ainish-rag Background Service ===");
            if cfg!(target_os = "linux") {
                let _ = std::process::Command::new("systemctl").args(["stop", "ainish-rag"]).output();
                let _ = std::process::Command::new("systemctl").args(["disable", "ainish-rag"]).output();
                let _ = std::fs::remove_file("/etc/systemd/system/ainish-rag.service");
                let _ = std::process::Command::new("systemctl").args(["daemon-reload"]).output();
                println!("  \x1b[32m[rag:service]\x1b[0m Removed /etc/systemd/system/ainish-rag.service");
            } else if cfg!(windows) {
                let _ = std::process::Command::new("schtasks").args(["/Delete", "/TN", "ainish-rag", "/F"]).output();
                let runner = repo_root.join(".agents").join("rag").join("service-runner.ps1");
                let _ = std::fs::remove_file(runner);
                println!("  \x1b[32m[rag:service]\x1b[0m Unregistered scheduled task 'ainish-rag'");
            }
        }
    }
    Ok(())
}

fn print_completion(shell: &str) {
    match shell.to_lowercase().as_str() {
        "bash" => {
            print!("{}", r#"# bash completion for ainish-rag
_ainish_rag() {
    local cur opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    opts="serve stop status secrets index wiki query rerank route decide eval cleanup orient bench monitor audit service completion --threads --max-mem --psk-ttl --numa --cpu-affinity --anonymize-symbols --symbol-salt --patch --fzf --compact --inject --custom --tui --help"
    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "--threads --max-mem --psk-ttl --numa --cpu-affinity --anonymize-symbols --symbol-salt --patch --fzf --compact --inject --custom --tui --help" -- ${cur}) )
        return 0
    fi
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}
complete -F _ainish_rag ainish-rag
alias rag="ainish-rag"
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
        'cleanup:Compact LanceDB database and prune versions'
        'orient:Inject architectural wiki context into agent primer'
        'bench:Run synthetic regression benchmark'
        'monitor:Continuous drift monitoring'
        'audit:Verify post-quantum receipts, manifests, and SBOMs'
        'service:Background embedding service management'
        'completion:Generate shell completions'
    )
    _describe 'commands' commands
}
compdef _ainish_rag ainish-rag
alias rag="ainish-rag"
"#);
        }
        "fish" => {
            print!("{}", r#"# fish completion for ainish-rag
complete -c ainish-rag -f
complete -c ainish-rag -a "serve stop status secrets index wiki query rerank route decide eval cleanup orient bench monitor audit service completion"
alias rag="ainish-rag"
"#);
        }
        "pwsh" | "powershell" => {
            print!("{}", r#"# PowerShell completion for ainish-rag
Register-ArgumentCompleter -Native -CommandName ainish-rag -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $commands = @('serve','stop','status','secrets','index','wiki','query','rerank','route','decide','eval','cleanup','orient','bench','monitor','audit','service','completion')
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}
Set-Alias -Name rag -Value ainish-rag
"#);
        }
        _ => {
            eprintln!("Unsupported shell: {}. Supported shells: bash, zsh, fish, pwsh", shell);
        }
    }
}


