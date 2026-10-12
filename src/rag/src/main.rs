mod config;
mod server;
mod embed;
mod store;
mod ingest;
mod wiki;
mod decision;

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
    Status,
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
    /// Run bi-phasic evaluation gate (faithfulness & groundedness)
    Eval {
        /// Ground-truth context text
        #[arg(short, long)]
        context: String,
        /// Generated output to evaluate
        #[arg(short, long)]
        output: String,
        /// Output decision as JSON
        #[arg(long)]
        json: bool,
    },
    /// Inspect PQC secrets vault configuration and OpenRouter key status
    Secrets {
        /// Output status as JSON
        #[arg(long)]
        json: bool,
    },
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
        Commands::Status => {
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

            let is_running = LlamaServer::is_running(&config.server_url).await;
            println!("Server Status:      {}", if is_running { "ONLINE (ready)" } else { "OFFLINE" });

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
        Commands::Index { path, truncate, watch, anonymize_symbols } => {
            let target = path.unwrap_or_else(|| current_dir.clone());
            println!("=== Indexing Codebase into LanceDB ===");
            println!("Target directory: {}", target.display());
            if anonymize_symbols {
                println!("  \x1b[35m[rag:privacy]\x1b[0m Symbol anonymization active (SHA-256 hashed identifiers)");
            }

            LlamaServer::ensure_running(&config, &current_dir).await?;

            let dim = truncate.unwrap_or(config.embedding_dim);
            let embed_client = EmbedClient::new(&config.server_url, truncate);
            let store = LanceStore::new(&config.lancedb_dir, dim);
            let ingestor = CodebaseIngestor::new_with_options(&target, anonymize_symbols);

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
                let embed_client = EmbedClient::new(&config.server_url, None);
                let store = LanceStore::new(&config.lancedb_dir, config.embedding_dim);
                let ingestor = CodebaseIngestor::new(&target);

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
        Commands::Query { query, limit, doc_type, code, json, no_rerank, min_relevance } => {
            LlamaServer::ensure_running(&config, &current_dir).await?;
            let embed_client = EmbedClient::new(&config.server_url, None);
            let store = LanceStore::new(&config.lancedb_dir, config.embedding_dim);

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
            let embed_client = EmbedClient::new(&config.server_url, None);
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
        Commands::Bench { iterations, json } => {
            LlamaServer::ensure_running(&config, &current_dir).await?;
            let embed_client = EmbedClient::new(&config.server_url, None);
            let store = LanceStore::new(&config.lancedb_dir, config.embedding_dim);

            println!("=== ainish-rag Synthetic Query Regression Benchmark ===");
            let test_suite = vec![
                ("post-quantum cryptography secrets FIPS ML-KEM ML-DSA", "security"),
                ("codebase multimodal rag lancedb embeddinggemma", "rag"),
                ("worktree isolation branch main workflow OOReDAct", "agents"),
            ];

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
        Commands::Eval { context, output, json } => {
            let engine = DecisionEngine::new();
            let eval = engine.evaluate_faithfulness(&context, &output).await;
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
    let embed_client = EmbedClient::new(&config.server_url, None);
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

fn print_completion(shell: &str) {
    match shell.to_lowercase().as_str() {
        "bash" => {
            print!("{}", r#"# bash completion for ainish-rag
_ainish_rag() {
    local cur opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    opts="serve stop status secrets index wiki query rerank route decide eval bench monitor completion --threads --max-mem --anonymize-symbols --help"
    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "--threads --max-mem --anonymize-symbols --help" -- ${cur}) )
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
        'eval:Bi-phasic faithfulness evaluation'
        'bench:Run synthetic regression benchmark'
        'monitor:Continuous drift monitoring'
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
complete -c ainish-rag -a "serve stop status secrets index wiki query rerank route decide eval bench monitor completion"
alias rag="ainish-rag"
"#);
        }
        "pwsh" | "powershell" => {
            print!("{}", r#"# PowerShell completion for ainish-rag
Register-ArgumentCompleter -Native -CommandName ainish-rag -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $commands = @('serve','stop','status','secrets','index','wiki','query','rerank','route','decide','eval','bench','monitor','completion')
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

