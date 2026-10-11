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
        }
        Commands::Index { path, truncate } => {
            let target = path.unwrap_or_else(|| current_dir.clone());
            println!("=== Indexing Codebase into LanceDB ===");
            println!("Target directory: {}", target.display());

            LlamaServer::ensure_running(&config, &current_dir).await?;

            let dim = truncate.unwrap_or(config.embedding_dim);
            let embed_client = EmbedClient::new(&config.server_url, truncate);
            let store = LanceStore::new(&config.lancedb_dir, dim);
            let ingestor = CodebaseIngestor::new(&target);

            println!("  [rag:index] Scanning repository files...");
            let files = ingestor.scan_files(&target);
            println!("  [rag:index] Discovered {} candidate files.", files.len());

            let mut all_unembedded = Vec::new();
            for f in &files {
                let chunks = ingestor.chunk_file(f);
                all_unembedded.extend(chunks);
            }
            println!("  [rag:index] Generated {} chunks. Creating embeddings via EmbeddingGemma-2...", all_unembedded.len());

            let batch_size = 16;
            let mut rag_chunks = Vec::new();

            for chunk_batch in all_unembedded.chunks(batch_size) {
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
                print!(".");
                let _ = std::io::Write::flush(&mut std::io::stdout());
            }
            println!();

            println!("  [rag:index] Persisting {} vectors into LanceDB...", rag_chunks.len());
            store.upsert(&rag_chunks).await?;
            let total = store.count().await.unwrap_or(0);
            println!("  [rag:index] Indexing complete! Total records in store: {}", total);
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
                            println!("\n[{}] Rerank: {:.4} (Vector: {:.4}, Decision: {:.4}) | Type: {} | Modality: {}", 
                                i + 1, item.rerank_score, item.original_score, item.decision_score, h.doc_type, h.modality
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
                    println!("\n[{}] Rerank: {:.4} (Vector: {:.4}, Decision: {:.4}) | {}", 
                        i + 1, item.rerank_score, item.original_score, item.decision_score, h.title
                    );
                    println!("     Path:     {}:L{}-L{}", h.path, h.start_line, h.end_line);
                    println!("     Decision: {}", item.rationale);
                }
                println!();
            }
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

