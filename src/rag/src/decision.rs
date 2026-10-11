use std::env;
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
pub struct RelevanceDecision {
    pub chunk_index: usize,
    pub is_relevant: bool,
    pub score: f32,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EvaluationDecision {
    pub is_faithful: bool,
    pub faithfulness_score: f32,
    pub halluncination_risk: f32,
    pub evaluation_source: String,
}

pub struct DecisionEngine {
    api_key: Option<String>,
    model: String,
    client: reqwest::Client,
}

impl DecisionEngine {
    pub fn new() -> Self {
        let api_key = env::var("OPENROUTER_API_KEY")
            .ok()
            .or_else(|| env::var("ROUTER_API_KEY").ok());
        let model = env::var("JEV_DECISION_MODEL")
            .unwrap_or_else(|_| DEFAULT_JEV_MODEL.to_string());
        
        Self {
            api_key,
            model,
            client: reqwest::Client::builder()
                .timeout(std::time::Duration::from_secs(10))
                .build()
                .unwrap_or_default(),
        }
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
        
        // Extract decisions (handles both nested .decisions or top-level)
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

        // Check if query is self-contained / no retrieval needed (e.g. simple syntax, greeting, math)
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

        // Domain classification
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

    /// Evaluates candidate chunks for relevance to filter distractor noise
    pub async fn filter_chunks(
        &self,
        query: &str,
        chunks: &[crate::store::SearchHit],
        min_relevance: f32,
    ) -> Vec<RelevanceDecision> {
        let mut results = Vec::new();

        for (idx, item) in chunks.iter().enumerate() {
            // Local keyword & similarity calibration
            let text_lower = item.content.to_lowercase();
            let query_terms: Vec<&str> = query.split_whitespace().collect();
            let matching_terms = query_terms.iter().filter(|t| text_lower.contains(&t.to_lowercase())).count();
            
            // Combining cosine similarity with lexical overlap for calibrated score
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

        // Local heuristic fallback
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
