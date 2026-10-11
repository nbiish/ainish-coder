use std::env;
use std::path::{Path, PathBuf};
use serde::{Deserialize, Serialize};
use serde_json::json;

pub const DEFAULT_JEV_MODEL: &str = "typesafe/jev-1.13";
pub const OPENROUTER_DECISIONS_URL: &str = "https://openrouter.ai/api/alpha/decisions";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RouteDecision {
    pub needs_retrieval: bool,
    pub retrieval_probability: f32,
    pub target_domain: String,
    pub route_confidence: f32,
    pub source: String, // "openrouter-jev" or "local-calibrated"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[allow(dead_code)]
pub struct RelevanceDecision {
    pub chunk_index: usize,
    pub is_relevant: bool,
    pub score: f32,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RerankResult {
    pub chunk: crate::store::SearchHit,
    pub original_score: f32,
    pub decision_score: f32,
    pub rerank_score: f32,
    pub is_relevant: bool,
    pub rationale: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EvaluationDecision {
    pub is_faithful: bool,
    pub faithfulness_score: f32,
    pub halluncination_risk: f32,
    pub evaluation_source: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecretsStatus {
    pub has_key: bool,
    pub key_source: String,
    pub vault_bundle_exists: bool,
    pub vault_path: String,
    pub model: String,
}

pub struct DecisionEngine {
    pub api_key: Option<String>,
    pub key_source: String,
    pub model: String,
    client: reqwest::Client,
}

impl DecisionEngine {
    pub fn new() -> Self {
        let (api_key, key_source) = Self::resolve_api_key();
        let model = env::var("JEV_DECISION_MODEL")
            .unwrap_or_else(|_| DEFAULT_JEV_MODEL.to_string());
        
        Self {
            api_key,
            key_source,
            model,
            client: reqwest::Client::builder()
                .timeout(std::time::Duration::from_secs(12))
                .build()
                .unwrap_or_default(),
        }
    }

    /// Resolves the OpenRouter API key:
    /// 1. Direct environment variable (OPENROUTER_API_KEY / ROUTER_API_KEY)
    /// 2. On-demand decryption from PQC secrets vault (~/.config/pqc-secrets/secrets.bundle.json)
    /// 3. Offline calibrated fallback
    pub fn resolve_api_key() -> (Option<String>, String) {
        // 1. Direct environment variable
        for var_name in &["OPENROUTER_API_KEY", "ROUTER_API_KEY"] {
            if let Ok(val) = env::var(var_name) {
                let trimmed = val.trim();
                if !trimmed.is_empty() {
                    return (Some(trimmed.to_string()), format!("env:{}", var_name));
                }
            }
        }

        // 2. Query PQC secrets vault on demand (never persists plaintext)
        if let Some(key) = Self::load_from_pqc_secrets() {
            return (Some(key), "pqc-secrets-vault".to_string());
        }

        (None, "local-calibrated-fallback".to_string())
    }

    /// Resolves the PQC secrets bundle path across Windows, WSL, Linux, and macOS
    pub fn find_pqc_vault_bundle() -> Option<PathBuf> {
        // 1. Explicit environment variable overrides
        if let Ok(val) = env::var("PQC_VAULT_PATH") {
            let p = PathBuf::from(val);
            if p.exists() {
                return Some(p);
            }
        }
        if let Ok(val) = env::var("PQC_SECRETS_DIR") {
            let p = PathBuf::from(val).join("secrets.bundle.json");
            if p.exists() {
                return Some(p);
            }
        }
        if let Ok(val) = env::var("XDG_CONFIG_HOME") {
            let p = PathBuf::from(val).join("pqc-secrets").join("secrets.bundle.json");
            if p.exists() {
                return Some(p);
            }
        }

        let mut candidates = Vec::new();

        // 2. POSIX home (~/.config/pqc-secrets/...) and macOS Application Support
        if let Ok(home) = env::var("HOME") {
            let hp = PathBuf::from(home);
            candidates.push(hp.join(".config").join("pqc-secrets").join("secrets.bundle.json"));
            candidates.push(hp.join("Library").join("Application Support").join("pqc-secrets").join("secrets.bundle.json"));
        }

        // 3. Windows profile (%USERPROFILE%/.config/pqc-secrets/...)
        if let Ok(up) = env::var("USERPROFILE") {
            let upp = PathBuf::from(up);
            candidates.push(upp.join(".config").join("pqc-secrets").join("secrets.bundle.json"));
        }
        if let Ok(appdata) = env::var("APPDATA") {
            candidates.push(PathBuf::from(appdata).join("pqc-secrets").join("secrets.bundle.json"));
        }

        // 4. WSL bridging: inspect mounted Windows user profiles (/mnt/c/Users/*/.config/...)
        let wsl_c_users = Path::new("/mnt/c/Users");
        if wsl_c_users.is_dir() {
            if let Ok(entries) = std::fs::read_dir(wsl_c_users) {
                for entry in entries.flatten() {
                    let p = entry.path();
                    if p.is_dir() {
                        let vault = p.join(".config").join("pqc-secrets").join("secrets.bundle.json");
                        if vault.exists() {
                            candidates.push(vault);
                        }
                    }
                }
            }
        }

        for c in candidates {
            if c.exists() {
                return Some(c);
            }
        }

        None
    }

    /// Inspects PQC secrets vault configuration without exposing secret values
    pub fn inspect_secrets() -> SecretsStatus {
        let (api_key, key_source) = Self::resolve_api_key();
        let model = env::var("JEV_DECISION_MODEL")
            .unwrap_or_else(|_| DEFAULT_JEV_MODEL.to_string());

        let detected_vault = Self::find_pqc_vault_bundle();
        let vault_exists = detected_vault.is_some();
        let vault_path = detected_vault
            .map(|p| p.to_string_lossy().to_string())
            .unwrap_or_else(|| {
                let home = env::var("USERPROFILE").or_else(|_| env::var("HOME")).unwrap_or_default();
                PathBuf::from(&home).join(".config").join("pqc-secrets").join("secrets.bundle.json").to_string_lossy().to_string()
            });

        SecretsStatus {
            has_key: api_key.is_some(),
            key_source,
            vault_bundle_exists: vault_exists,
            vault_path,
            model,
        }
    }

    /// Executes pqc-secrets export and extracts the OpenRouter key in memory
    fn load_from_pqc_secrets() -> Option<String> {
        // Try standalone pqc-secrets binary / script in PATH and common relative paths across platforms
        let mut attempts = vec![
            ("pqc-secrets".to_string(), vec!["export".to_string()]),
            ("bin/pqc-secrets".to_string(), vec!["export".to_string()]),
            ("../bin/pqc-secrets".to_string(), vec!["export".to_string()]),
        ];

        if let Ok(home) = env::var("HOME") {
            let user_local_pqc = PathBuf::from(&home).join(".local").join("bin").join("pqc-secrets");
            if user_local_pqc.is_file() {
                attempts.push((user_local_pqc.to_string_lossy().to_string(), vec!["export".to_string()]));
            }
        }

        for (cmd, args) in &attempts {
            if let Ok(output) = std::process::Command::new(cmd).args(args).output() {
                if output.status.success() {
                    if let Ok(stdout) = String::from_utf8(output.stdout) {
                        if let Some(key) = Self::parse_pqc_export(&stdout) {
                            return Some(key);
                        }
                    }
                }
            }
        }

        // Try via uv, python3, python, or py with script discovery
        let mut script_candidates = vec![
            PathBuf::from(".agents/skills/pqc-secrets/scripts/pqc_secrets.py"),
            PathBuf::from("../.agents/skills/pqc-secrets/scripts/pqc_secrets.py"),
            PathBuf::from("D:/Code/ainish-coder/.agents/skills/pqc-secrets/scripts/pqc_secrets.py"),
            PathBuf::from("/mnt/c/Code/ainish-coder/.agents/skills/pqc-secrets/scripts/pqc_secrets.py"),
        ];

        if let Ok(home) = env::var("HOME") {
            script_candidates.push(PathBuf::from(home).join(".agents").join("skills").join("pqc-secrets").join("scripts").join("pqc_secrets.py"));
        }
        if let Ok(up) = env::var("USERPROFILE") {
            script_candidates.push(PathBuf::from(up).join(".agents").join("skills").join("pqc-secrets").join("scripts").join("pqc_secrets.py"));
        }

        let pqc_script = script_candidates.into_iter().find(|p| p.is_file());

        if let Some(script_path) = pqc_script {
            let script_str = script_path.to_string_lossy().to_string();
            let mut runner_candidates = vec!["uv".to_string(), "python3".to_string(), "python".to_string(), "py".to_string()];

            if let Ok(home) = env::var("HOME") {
                let user_uv = PathBuf::from(home).join(".local").join("bin").join("uv");
                if user_uv.is_file() {
                    runner_candidates.insert(0, user_uv.to_string_lossy().to_string());
                }
            }
            if let Ok(up) = env::var("USERPROFILE") {
                let hermes_uv = PathBuf::from(up).join("AppData").join("Local").join("hermes").join("bin").join("uv.exe");
                if hermes_uv.is_file() {
                    runner_candidates.insert(0, hermes_uv.to_string_lossy().to_string());
                }
            }

            for runner in runner_candidates {
                let args = if runner.contains("uv") {
                    vec!["run", &script_str, "export"]
                } else {
                    vec![&script_str, "export"]
                };

                if let Ok(output) = std::process::Command::new(&runner).args(&args).output() {
                    if output.status.success() {
                        if let Ok(stdout) = String::from_utf8(output.stdout) {
                            if let Some(key) = Self::parse_pqc_export(&stdout) {
                                return Some(key);
                            }
                        }
                    }
                }
            }
        }

        None
    }

    fn parse_pqc_export(stdout: &str) -> Option<String> {
        for line in stdout.lines() {
            let line = line.trim();
            if let Some(rest) = line.strip_prefix("export ") {
                if let Some((k, v)) = rest.split_once('=') {
                    let k = k.trim();
                    let v = v.trim().trim_matches('\'').trim_matches('"');
                    if (k == "OPENROUTER_API_KEY" || k == "ROUTER_API_KEY") && !v.is_empty() {
                        return Some(v.to_string());
                    }
                }
            }
        }
        None
    }

    /// Evaluates if a query requires retrieval, and which domain to route to.
    pub async fn route(&self, prompt: &str) -> RouteDecision {
        if let Some(ref api_key) = self.api_key {
            if let Ok(decision) = self.route_via_jev(prompt, api_key).await {
                return decision;
            }
        }
        self.route_local(prompt)
    }

    /// Calls TypeSafe Jev model on OpenRouter Decisions API
    async fn route_via_jev(&self, prompt: &str, api_key: &str) -> Result<RouteDecision, Box<dyn std::error::Error + Send + Sync>> {
        let questions = json!({
            "needs_retrieval": {
                "type": "noul",
                "instructions": "Does answering this coding or engineering prompt require retrieving codebase symbols, architecture, or documentation context?"
            },
            "domain_target": {
                "type": "choice",
                "options": ["codebase_symbols", "architectural_wiki", "security_governance", "technical_debt", "general_knowledge"],
                "instructions": "Which domain best categorizes the information needed for this request?"
            }
        });

        let payload = json!({
            "model": self.model,
            "state": prompt,
            "questions": questions
        });

        let res = self.client.post(OPENROUTER_DECISIONS_URL)
            .header("Authorization", format!("Bearer {}", api_key))
            .header("Content-Type", "application/json")
            .header("HTTP-Referer", "https://github.com/nbiish/ainish-coder")
            .header("X-Title", "ainish-rag")
            .json(&payload)
            .send()
            .await?;

        if !res.status().is_success() {
            let err_txt = res.text().await.unwrap_or_default();
            return Err(format!("Jev API HTTP error: {}", err_txt).into());
        }

        let body: serde_json::Value = res.json().await?;
        let root = body.get("decisions").unwrap_or(&body);

        let mut needs_retrieval = true;
        let mut prob = 0.85;
        if let Some(nr) = root.get("needs_retrieval") {
            if let Some(val) = nr.get("value").and_then(|v| v.as_bool()) {
                needs_retrieval = val;
            }
            if let Some(p) = nr.get("probability").and_then(|v| v.as_f64()) {
                prob = p as f32;
            }
        }

        let mut target_domain = "codebase_symbols".to_string();
        let mut conf = 0.80;
        if let Some(dom) = root.get("domain_target") {
            if let Some(val) = dom.get("value").and_then(|v| v.as_str()) {
                target_domain = val.to_string();
            }
            if let Some(p) = dom.get("probability").and_then(|v| v.as_f64()) {
                conf = p as f32;
            }
        }

        Ok(RouteDecision {
            needs_retrieval,
            retrieval_probability: prob,
            target_domain,
            route_confidence: conf,
            source: format!("openrouter:{}", self.model),
        })
    }

    /// Calibrated fallback decision logic when offline or without OpenRouter key
    pub fn route_local(&self, prompt: &str) -> RouteDecision {
        let p_lower = prompt.to_lowercase();

        let self_contained = p_lower.starts_with("hello") ||
            p_lower.starts_with("echo ") ||
            p_lower.starts_with("format json") ||
            (p_lower.contains("2 + 2") || p_lower.contains("what is 10 +"));

        if self_contained {
            return RouteDecision {
                needs_retrieval: false,
                retrieval_probability: 0.15,
                target_domain: "general_knowledge".to_string(),
                route_confidence: 0.95,
                source: "local-calibrated".to_string(),
            };
        }

        let (domain, conf) = if p_lower.contains("pqc") || p_lower.contains("fips") || p_lower.contains("security") || p_lower.contains("secret") || p_lower.contains("zero-trust") {
            ("security_governance".to_string(), 0.95)
        } else if p_lower.contains("architecture") || p_lower.contains("system design") || p_lower.contains("component") || p_lower.contains("pipeline") {
            ("architectural_wiki".to_string(), 0.92)
        } else if p_lower.contains("debt") || p_lower.contains("todo") || p_lower.contains("refactor") || p_lower.contains("smell") {
            ("technical_debt".to_string(), 0.88)
        } else if p_lower.contains("fn ") || p_lower.contains("struct ") || p_lower.contains("class ") || p_lower.contains("method") || p_lower.contains("symbol") || p_lower.contains("call") {
            ("codebase_symbols".to_string(), 0.90)
        } else {
            ("codebase_symbols".to_string(), 0.75)
        };

        RouteDecision {
            needs_retrieval: true,
            retrieval_probability: 0.88,
            target_domain: domain,
            route_confidence: conf,
            source: "local-calibrated".to_string(),
        }
    }

    /// Two-Stage RAG: Rerank candidate chunks using the decision model
    pub async fn rerank(
        &self,
        query: &str,
        candidates: Vec<crate::store::SearchHit>,
        min_relevance: f32,
    ) -> Vec<RerankResult> {
        if candidates.is_empty() {
            return Vec::new();
        }

        if let Some(ref api_key) = self.api_key {
            if let Ok(results) = self.rerank_via_jev(query, &candidates, api_key, min_relevance).await {
                return results;
            }
        }

        self.rerank_local(query, candidates, min_relevance)
    }

    /// Calls TypeSafe Jev model on OpenRouter Decisions API to evaluate and score candidates
    async fn rerank_via_jev(
        &self,
        query: &str,
        candidates: &[crate::store::SearchHit],
        api_key: &str,
        min_relevance: f32,
    ) -> Result<Vec<RerankResult>, Box<dyn std::error::Error + Send + Sync>> {
        let mut reranked = Vec::new();

        for chunk in candidates.iter().take(12) {
            let snippet = if chunk.content.len() > 1200 { &chunk.content[..1200] } else { &chunk.content };
            let state = format!("QUERY: {}\n\nCONTEXT CHUNK [{}]:\nTitle: {}\n{}", 
                query, chunk.path, chunk.title, snippet
            );

            let questions = json!({
                "is_relevant": {
                    "type": "noul",
                    "instructions": "Is this context chunk directly relevant and high-utility for answering or implementing the query?"
                },
                "utility_score": {
                    "type": "score",
                    "instructions": "Rate how useful this context chunk is on a 1-5 scale."
                }
            });

            let payload = json!({
                "model": self.model,
                "state": state,
                "questions": questions
            });

            let mut is_rel = true;
            let mut decision_score = chunk.score;
            let mut rationale = "Jev calibrated decision".to_string();

            if let Ok(res) = self.client.post(OPENROUTER_DECISIONS_URL)
                .header("Authorization", format!("Bearer {}", api_key))
                .header("Content-Type", "application/json")
                .header("HTTP-Referer", "https://github.com/nbiish/ainish-coder")
                .header("X-Title", "ainish-rag-rerank")
                .json(&payload)
                .send()
                .await
            {
                if res.status().is_success() {
                    if let Ok(body) = res.json::<serde_json::Value>().await {
                        let root = body.get("decisions").unwrap_or(&body);
                        if let Some(rel) = root.get("is_relevant") {
                            if let Some(v) = rel.get("value").and_then(|v| v.as_bool()) {
                                is_rel = v;
                            }
                            if let Some(p) = rel.get("probability").and_then(|v| v.as_f64()) {
                                decision_score = p as f32;
                            }
                        }
                        if let Some(score_obj) = root.get("utility_score") {
                            if let Some(val) = score_obj.get("value").and_then(|v| v.as_f64()) {
                                decision_score = (val as f32) / 5.0;
                            }
                        }
                        rationale = format!("Jev decision utility: {:.3} (is_rel: {})", decision_score, is_rel);
                    }
                }
            }

            let combined = if is_rel {
                (decision_score * 0.70) + (chunk.score * 0.30)
            } else {
                (decision_score * 0.30) + (chunk.score * 0.20)
            };

            if combined >= min_relevance {
                let mut updated_chunk = chunk.clone();
                updated_chunk.score = combined;
                reranked.push(RerankResult {
                    chunk: updated_chunk,
                    original_score: chunk.score,
                    decision_score,
                    rerank_score: combined,
                    is_relevant: is_rel,
                    rationale,
                });
            }
        }

        reranked.sort_by(|a, b| b.rerank_score.partial_cmp(&a.rerank_score).unwrap_or(std::cmp::Ordering::Equal));
        Ok(reranked)
    }

    /// Calibrated local reranking fallback based on lexical coverage, symbol overlap, and vector similarity
    pub fn rerank_local(
        &self,
        query: &str,
        candidates: Vec<crate::store::SearchHit>,
        min_relevance: f32,
    ) -> Vec<RerankResult> {
        let q_lower = query.to_lowercase();
        let q_terms: Vec<&str> = q_lower.split_whitespace().filter(|t| t.len() > 2).collect();

        let mut reranked = Vec::new();

        for chunk in candidates {
            let content_lower = chunk.content.to_lowercase();
            let title_lower = chunk.title.to_lowercase();
            let symbols_lower = chunk.symbols.to_lowercase();

            // 1. Lexical term coverage
            let term_matches = q_terms.iter().filter(|t| content_lower.contains(*t)).count();
            let term_ratio = if !q_terms.is_empty() {
                term_matches as f32 / q_terms.len() as f32
            } else {
                0.0
            };

            // 2. Title & symbol boost
            let title_match = q_terms.iter().any(|t| title_lower.contains(*t));
            let symbol_match = q_terms.iter().any(|t| symbols_lower.contains(*t));
            let boost = (if title_match { 0.15 } else { 0.0 }) + (if symbol_match { 0.15 } else { 0.0 });

            // 3. Calibrated decision score: 50% vector similarity + 30% term coverage + 20% symbol/title boost
            let decision_score = (chunk.score * 0.50) + (term_ratio * 0.30) + boost;
            let is_relevant = decision_score >= min_relevance;

            if is_relevant {
                let mut updated_chunk = chunk.clone();
                updated_chunk.score = decision_score;
                reranked.push(RerankResult {
                    chunk: updated_chunk,
                    original_score: chunk.score,
                    decision_score,
                    rerank_score: decision_score,
                    is_relevant: true,
                    rationale: format!("Local calibrated rerank (terms: {}/{}, title: {}, symbols: {})", term_matches, q_terms.len(), title_match, symbol_match),
                });
            }
        }

        reranked.sort_by(|a, b| b.rerank_score.partial_cmp(&a.rerank_score).unwrap_or(std::cmp::Ordering::Equal));
        reranked
    }

    /// Evaluates candidate chunks for relevance to filter distractor noise
    #[allow(dead_code)]
    pub async fn filter_chunks(
        &self,
        query: &str,
        chunks: &[crate::store::SearchHit],
        min_relevance: f32,
    ) -> Vec<RelevanceDecision> {
        let mut results = Vec::new();

        for (idx, item) in chunks.iter().enumerate() {
            let text_lower = item.content.to_lowercase();
            let query_terms: Vec<&str> = query.split_whitespace().collect();
            let matching_terms = query_terms.iter().filter(|t| text_lower.contains(&t.to_lowercase())).count();
            
            let lexical_ratio = if !query_terms.is_empty() {
                matching_terms as f32 / query_terms.len() as f32
            } else {
                0.0
            };

            let combined_score = (item.score * 0.7) + (lexical_ratio * 0.3);
            let is_relevant = combined_score >= min_relevance;

            results.push(RelevanceDecision {
                chunk_index: idx,
                is_relevant,
                score: combined_score,
                reason: if is_relevant {
                    format!("Semantic similarity {:.3} with lexical support", item.score)
                } else {
                    format!("Score {:.3} below threshold {:.3}", combined_score, min_relevance)
                },
            });
        }

        results
    }

    /// Bi-phasic evaluation: checks output faithfulness against retrieved context
    pub async fn evaluate_faithfulness(&self, context: &str, output: &str) -> EvaluationDecision {
        if let Some(ref api_key) = self.api_key {
            let questions = json!({
                "is_faithful": {
                    "type": "noul",
                    "instructions": "Is the output completely faithful to the provided context, without unverified claims or hallucinations?"
                },
                "faithfulness_score": {
                    "type": "score",
                    "instructions": "Rate the factual consistency of the output relative to context on a 1-5 scale."
                }
            });

            let state = format!("CONTEXT:\n{}\n\nOUTPUT TO EVALUATE:\n{}", 
                if context.len() > 2000 { &context[..2000] } else { context },
                if output.len() > 1000 { &output[..1000] } else { output }
            );

            let payload = json!({
                "model": self.model,
                "state": state,
                "questions": questions
            });

            if let Ok(res) = self.client.post(OPENROUTER_DECISIONS_URL)
                .header("Authorization", format!("Bearer {}", api_key))
                .header("Content-Type", "application/json")
                .json(&payload)
                .send()
                .await
            {
                if res.status().is_success() {
                    if let Ok(body) = res.json::<serde_json::Value>().await {
                        let root = body.get("decisions").unwrap_or(&body);
                        let mut is_faithful = true;
                        let mut prob = 0.90;
                        if let Some(f) = root.get("is_faithful") {
                            if let Some(v) = f.get("value").and_then(|v| v.as_bool()) {
                                is_faithful = v;
                            }
                            if let Some(p) = f.get("probability").and_then(|v| v.as_f64()) {
                                prob = p as f32;
                            }
                        }

                        return EvaluationDecision {
                            is_faithful,
                            faithfulness_score: prob,
                            halluncination_risk: 1.0 - prob,
                            evaluation_source: format!("openrouter:{}", self.model),
                        };
                    }
                }
            }
        }

        let out_lower = output.to_lowercase();
        let ctx_lower = context.to_lowercase();
        let words: Vec<&str> = out_lower.split_whitespace().filter(|w| w.len() > 4).collect();
        let grounded_count = words.iter().filter(|w| ctx_lower.contains(*w)).count();
        let ratio = if !words.is_empty() { grounded_count as f32 / words.len() as f32 } else { 1.0 };

        EvaluationDecision {
            is_faithful: ratio >= 0.40,
            faithfulness_score: ratio,
            halluncination_risk: (1.0 - ratio).max(0.0),
            evaluation_source: "local-heuristic".to_string(),
        }
    }
}
