use std::collections::HashMap;
use std::env;
use std::path::{Path, PathBuf};
use serde::{Deserialize, Serialize};
use serde_json::json;

/// Latest TypeSafe Jev decision model exposed by OpenRouter's Decisions API.
///
/// The engine always targets the latest decision model automatically; it never downgrades to an
/// older Jev version on its own. `JEV_DECISION_MODEL` remains for diagnostics and testing, and is
/// reported as a pin when it names anything older.
pub const LATEST_JEV_MODEL: &str = "typesafe/jev-1.14";
pub const OPENROUTER_DECISIONS_URL: &str = "https://openrouter.ai/api/alpha/decisions";
/// Loopback base of the local-router proxy (Ollama-compatible `/v1`, plus a Jev catalog entry).
pub const DEFAULT_LOCAL_ROUTER_URL: &str = "http://127.0.0.1:11434";
/// Paths a decisions-capable local router may expose. Probed in order, never assumed.
pub const LOCAL_DECISIONS_PATHS: &[&str] = &["/api/alpha/decisions", "/v1/decisions", "/decisions"];

/// Calibrated noul bands from the TypeSafe guidance: above YES reads as yes, below NO as no, and
/// the band between means the state does not settle the question (code must handle that case).
pub const JEV_NOUL_YES: f32 = 0.70;
pub const JEV_NOUL_NO: f32 = 0.30;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RouteDecision {
    pub needs_retrieval: bool,
    pub retrieval_probability: f32,
    pub target_domain: String,
    pub route_confidence: f32,
    /// Probability that the request depends on recent changes / current branch state rather than
    /// long-lived architecture. Lets agents choose between the wiki and a fresh orient scan.
    #[serde(default)]
    pub context_freshness: f32,
    /// Query specificity classified by Jev (`exact_symbol`, `conceptual_flow`, or `broad_audit`).
    #[serde(default = "default_query_specificity")]
    pub query_specificity: String,
    /// Source modality preference (`code_first`, `docs_first`, or `balanced`).
    #[serde(default = "default_modality_preference")]
    pub modality_preference: String,
    /// Deterministic code-owned retrieval strategy derived from calibrated routing judgments
    /// (`skip_retrieval`, `symbol_anchored`, `hybrid_rerank`, `fresh_orient_first`, `multi_hop_expand`).
    #[serde(default = "default_retrieval_strategy")]
    pub retrieval_strategy: String,
    /// Recommended coarse candidate pool size before two-stage Jev reranking.
    #[serde(default = "default_candidate_pool_size")]
    pub candidate_pool_size: usize,
    /// Context-engineering budget: how many tokens of retrieved context this strategy justifies.
    #[serde(default = "default_context_budget_tokens")]
    pub context_budget_tokens: usize,
    /// One-line action the harness should take before reading retrieved context.
    #[serde(default = "default_next_action")]
    pub next_action: String,
    pub source: String, // "openrouter:<resolved-model>", "local-router:<url>:<model>", or "local-calibrated"
}

fn default_query_specificity() -> String {
    "conceptual_flow".to_string()
}

fn default_modality_preference() -> String {
    "balanced".to_string()
}

fn default_retrieval_strategy() -> String {
    "hybrid_rerank".to_string()
}

fn default_candidate_pool_size() -> usize {
    12
}

fn default_context_budget_tokens() -> usize {
    2000
}

fn default_next_action() -> String {
    next_action_for("hybrid_rerank").to_string()
}

/// Token budget for retrieved context per strategy. The harness should not spend more context
/// than the strategy justifies; `skip_retrieval` spends none.
pub fn context_budget_for(strategy: &str) -> usize {
    match strategy {
        "skip_retrieval" => 0,
        "symbol_anchored" => 1200,
        "fresh_orient_first" => 2600,
        "multi_hop_expand" => 3600,
        _ => 2000,
    }
}

/// One-line next action for the harness, derived from the strategy (context-engineering priming).
pub fn next_action_for(strategy: &str) -> &'static str {
    match strategy {
        "skip_retrieval" => "answer directly; do not retrieve",
        "symbol_anchored" => "query --code with the named symbol or file",
        "fresh_orient_first" => "check git status/log, then orient --inject before trusting stable docs",
        "multi_hop_expand" => "query with the larger pool, then one corrective pass if sufficiency is partial",
        _ => "query with rerank; read decision role and context sufficiency before answering",
    }
}

/// Code-owned mapping from calibrated Jev routing judgments to an actionable retrieval strategy.
pub fn derive_retrieval_strategy(
    needs_retrieval: bool,
    target_domain: &str,
    context_freshness: f32,
    query_specificity: &str,
    modality_preference: &str,
) -> (String, usize) {
    if !needs_retrieval || target_domain == "general_knowledge" {
        return ("skip_retrieval".to_string(), 0);
    }
    if context_freshness >= JEV_NOUL_YES {
        return ("fresh_orient_first".to_string(), 12);
    }
    match query_specificity {
        "exact_symbol" => ("symbol_anchored".to_string(), 10),
        "broad_audit" => ("multi_hop_expand".to_string(), 16),
        _ => {
            if modality_preference == "code_first" {
                ("symbol_anchored".to_string(), 12)
            } else {
                ("hybrid_rerank".to_string(), 12)
            }
        }
    }
}

/// One typed answer from the Jev Decisions API. `kind` mirrors the question type (`noul`,
/// `choice`, `score`, `box`); exactly one value field is populated.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct JevAnswer {
    pub id: String,
    #[serde(rename = "type", default)]
    pub kind: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub noul: Option<f32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub choice: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub score: Option<f32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub confidence: Option<f32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub probabilities: Option<serde_json::Value>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub legend: Option<serde_json::Value>,
}

impl JevAnswer {
    /// Calibrated band for a noul answer (`yes`, `no`, or `unsettled`).
    pub fn band(&self) -> &'static str {
        noul_band(self.noul.unwrap_or(0.5))
    }
}

pub fn noul_band(probability: f32) -> &'static str {
    if probability >= JEV_NOUL_YES {
        "yes"
    } else if probability <= JEV_NOUL_NO {
        "no"
    } else {
        "unsettled"
    }
}

/// Full typed decision set returned by an arbitrary question batch.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DecisionSet {
    pub model: String,
    pub source: String,
    pub answers: Vec<JevAnswer>,
    pub usage: serde_json::Value,
}

/// Outcome of one typed batch, including which transport produced it.
#[derive(Debug, Clone)]
pub struct AskOutcome {
    pub model: String,
    pub answers: HashMap<String, JevAnswer>,
    pub usage: serde_json::Value,
    pub transport: String,
}

/// A loopback local-router that advertises at least one Jev model and may expose a typed
/// decisions route (`/api/alpha/decisions`, `/v1/decisions`, or `/decisions`).
#[derive(Debug, Clone, Serialize)]
pub struct LocalJevRouter {
    pub base_url: String,
    pub jev_models: Vec<String>,
    /// `Some` when the router exposes a decisions-compatible route that answered a probe.
    pub decisions_url: Option<String>,
    /// True when the router only offers chat-completions for Jev (not usable for typed decisions).
    pub chat_only: bool,
}

/// Decision-transport report surfaced by `ainish-rag secrets` and orchestration pre-flight.
#[derive(Debug, Clone, Serialize)]
pub struct JevStatus {
    pub model: String,
    pub latest_model: &'static str,
    pub model_pinned: bool,
    pub endpoint: String,
    pub key_present: bool,
    pub key_source: String,
    pub local_router: Option<LocalJevRouter>,
}

/// Resolves the effective decision model. Always the latest Jev unless an operator pin is set.
pub fn resolve_jev_model() -> String {
    let requested = env::var("JEV_DECISION_MODEL")
        .ok()
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty());
    match requested.as_deref() {
        None | Some("latest") | Some("typesafe/jev-latest") | Some("typesafe/jev") => {
            LATEST_JEV_MODEL.to_string()
        }
        Some(pin) => pin.to_string(),
    }
}

/// True when `JEV_DECISION_MODEL` pins something other than the latest model. Reported, never hidden.
pub fn is_model_pinned() -> bool {
    let requested = env::var("JEV_DECISION_MODEL")
        .ok()
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty());
    matches!(
        requested.as_deref(),
        Some(value)
            if value != "latest"
                && value != "typesafe/jev-latest"
                && value != LATEST_JEV_MODEL
    )
}

/// Filters a `/v1/models` id list down to Jev candidates (case-insensitive `jev`).
pub fn jev_models_filter(models: &[String]) -> Vec<String> {
    models
        .iter()
        .filter(|id| id.to_ascii_lowercase().contains("jev"))
        .cloned()
        .collect()
}

async fn probe_decisions(client: &reqwest::Client, url: &str) -> bool {
    let payload = json!({
        "model": LATEST_JEV_MODEL,
        "state": "probe",
        "questions": {
            "q": DecisionEngine::noul_question(
                "Does this probe reach a decisions endpoint?",
                "the endpoint answered",
                "the endpoint did not answer"
            )
        }
    });
    matches!(client.post(url).json(&payload).send().await, Ok(response) if response.status().is_success())
}

/// Resolves transport priority order. The default is local-router, OpenRouter, direct configured
/// Jev, then a configured local decisions-compatible model endpoint.
pub fn transport_priority_order() -> Vec<&'static str> {
    let raw = env::var("JEV_TRANSPORT_PRIORITY")
        .or_else(|_| env::var("AINISH_RAG_DECISION_PRIORITY"))
        .unwrap_or_default()
        .to_ascii_lowercase();
    let mut order = Vec::new();
    for part in raw.split(|c: char| c == ',' || c == ';' || c.is_whitespace()) {
        let token = part.trim();
        match token {
            "openrouter" | "or" => {
                if !order.contains(&"openrouter") {
                    order.push("openrouter");
                }
            }
            "local-router" | "localrouter" | "local_router" | "router" => {
                if !order.contains(&"local-router") {
                    order.push("local-router");
                }
            }
            "jev" | "typesafe" | "direct-jev" => {
                if !order.contains(&"jev") {
                    order.push("jev");
                }
            }
            "local-model" | "localmodel" | "local_model" | "model" => {
                if !order.contains(&"local-model") {
                    order.push("local-model");
                }
            }
            _ => {}
        }
    }
    for default_item in ["local-router", "openrouter", "jev", "local-model"] {
        if !order.contains(&default_item) {
            order.push(default_item);
        }
    }
    order
}

/// Probes loopback local-router bases for a Jev catalog entry and a decisions-compatible route.
///
/// Fast-path: checks `GET {base}/api/decisions/status` first (Local Router 1.1.0+, ~2ms, zero
/// upstream cost). When that endpoint is absent, falls back to `GET {base}/v1/models` + a minimal
/// typed POST probe against `/api/alpha/decisions`, `/v1/decisions`, and `/decisions`.
/// A chat-only Jev alias (`openrouter-jev-router`) is reported but never substituted for typed,
/// calibrated decisions.
pub async fn discover_local_router() -> Option<LocalJevRouter> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_millis(1200))
        .build()
        .ok()?;

    let mut bases: Vec<String> = Vec::new();
    if let Ok(configured) = env::var("JEV_LOCAL_ROUTER_URL") {
        let trimmed = configured.trim().trim_end_matches('/').to_string();
        if !trimmed.is_empty() {
            bases.push(trimmed);
        }
    }
    for base in [DEFAULT_LOCAL_ROUTER_URL, "http://localhost:11434"] {
        if !bases.iter().any(|existing| existing == base) {
            bases.push(base.to_string());
        }
    }

    for base in bases {
        // 1. Fast zero-token check via Local Router's native `/api/decisions/status` endpoint.
        let mut status_ready = false;
        let mut status_route: Option<String> = None;
        let mut status_models: Vec<String> = Vec::new();
        if let Ok(status_resp) = client.get(format!("{base}/api/decisions/status")).send().await {
            if status_resp.status().is_success() {
                if let Ok(status_json) = status_resp.json::<serde_json::Value>().await {
                    status_ready = status_json.get("ready").and_then(|v| v.as_bool()).unwrap_or(false);
                    if let Some(routes) = status_json.get("routes").and_then(|r| r.as_array()) {
                        if let Some(first_route) = routes.first().and_then(|r| r.as_str()) {
                            status_route = Some(format!("{base}{first_route}"));
                        }
                    }
                    if let Some(adv) = status_json.get("advertised_models").and_then(|m| m.as_array()) {
                        for item in adv {
                            if let Some(id) = item.get("id").and_then(|v| v.as_str()) {
                                status_models.push(id.to_string());
                            }
                        }
                    }
                }
            }
        }

        let Ok(response) = client.get(format!("{base}/v1/models")).send().await else {
            if status_ready && status_route.is_some() {
                return Some(LocalJevRouter {
                    base_url: base,
                    jev_models: if status_models.is_empty() { vec![LATEST_JEV_MODEL.to_string()] } else { status_models },
                    chat_only: false,
                    decisions_url: status_route,
                });
            }
            continue;
        };
        if !response.status().is_success() {
            continue;
        }
        let Ok(body) = response.json::<serde_json::Value>().await else {
            continue;
        };
        let models: Vec<String> = body
            .get("data")
            .and_then(|data| data.as_array())
            .map(|items| {
                items
                    .iter()
                    .filter_map(|item| item.get("id").and_then(|id| id.as_str()).map(str::to_string))
                    .collect()
            })
            .unwrap_or_default();
        let mut jev_models = jev_models_filter(&models);
        for sm in status_models {
            if !jev_models.contains(&sm) {
                jev_models.push(sm);
            }
        }
        if jev_models.is_empty() {
            continue;
        }

        let mut decisions_url = if status_ready { status_route } else { None };
        if decisions_url.is_none() {
            for path in LOCAL_DECISIONS_PATHS {
                let url = format!("{base}{path}");
                if probe_decisions(&client, &url).await {
                    decisions_url = Some(url);
                    break;
                }
            }
        }

        return Some(LocalJevRouter {
            base_url: base,
            jev_models,
            chat_only: decisions_url.is_none(),
            decisions_url,
        });
    }
    None
}

/// Full decision-transport report.
pub async fn inspect_jev() -> JevStatus {
    let (key, key_source) = DecisionEngine::resolve_api_key();
    JevStatus {
        model: resolve_jev_model(),
        latest_model: LATEST_JEV_MODEL,
        model_pinned: is_model_pinned(),
        endpoint: OPENROUTER_DECISIONS_URL.to_string(),
        key_present: key.is_some(),
        key_source,
        local_router: discover_local_router().await,
    }
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
    /// Calibrated `answers_directly` noul probability in `[0, 1]`.
    #[serde(default, rename = "decision_probability")]
    pub direct_probability: f32,
    /// Calibrated `names_query_symbols` noul probability in `[0, 1]`.
    #[serde(default)]
    pub symbol_support: f32,
    /// Continuous 0..4 utility score from Jev (`utility_i`).
    #[serde(default, rename = "decision_utility")]
    pub utility_score: f32,
    /// Calibrated band (`yes`, `no`, or `unsettled`) for `direct_probability`.
    #[serde(default)]
    pub noul_band: String,
    /// Jev's classification of the artefact: implementation, documentation, test, or generated.
    #[serde(default, rename = "decision_role")]
    pub role: String,
    /// Transport and model that produced this rerank (`openrouter:...`, `local-router:...`, `local-calibrated-rrf`).
    #[serde(default)]
    pub rerank_source: String,
    pub rationale: String,
}

/// Evaluates collective context sufficiency across reranked candidates (Corrective RAG / CRAG):
/// * `"sufficient"` — at least one primary candidate is in the settled `yes` band (`>= 0.70`) with solid utility, or top combined score `>= 0.62`.
/// * `"insufficient"` — no candidates, all candidates in the `no` band (`<= 0.30`), or top combined score `< 0.42`.
/// * `"partial_unsettled"` — top candidates sit in the unsettled band (`0.30 < p < 0.70`), triggering a CRAG corrective retrieval pass.
pub fn evaluate_context_sufficiency(results: &[RerankResult]) -> &'static str {
    if results.is_empty() {
        return "insufficient";
    }
    let has_settled_yes = results.iter().take(3).any(|r| {
        (r.noul_band == "yes" || r.direct_probability >= JEV_NOUL_YES)
            && r.utility_score >= 2.4
            && r.role != "generated"
    });
    let top_score = results.first().map(|r| r.rerank_score).unwrap_or(0.0);
    if has_settled_yes || top_score >= 0.62 {
        return "sufficient";
    }
    let all_no = results.iter().all(|r| r.noul_band == "no" || r.direct_probability <= JEV_NOUL_NO);
    if all_no || top_score < 0.42 {
        return "insufficient";
    }
    "partial_unsettled"
}

/// Extracts high-signal identifier/symbol tokens from top partial candidates + query to drive a
/// second-stage CRAG corrective retrieval query when the initial pass is `partial_unsettled` or `insufficient`.
pub fn extract_corrective_expansion_terms(
    query: &str,
    candidates: &[crate::store::SearchHit],
) -> Vec<String> {
    let q_lower = query.to_lowercase();
    let mut terms: Vec<String> = Vec::new();
    for hit in candidates.iter().take(4) {
        for raw in hit.symbols.split(|c: char| !c.is_alphanumeric() && c != '_') {
            let sym = raw.trim();
            if sym.len() >= 4
                && !q_lower.contains(&sym.to_lowercase())
                && !terms.iter().any(|t| t.eq_ignore_ascii_case(sym))
            {
                terms.push(sym.to_string());
                if terms.len() >= 6 {
                    return terms;
                }
            }
        }
        if let Some(stem) = Path::new(&hit.path).file_stem().and_then(|s| s.to_str()) {
            if stem.len() >= 4
                && !q_lower.contains(&stem.to_lowercase())
                && !terms.iter().any(|t| t.eq_ignore_ascii_case(stem))
            {
                terms.push(stem.to_string());
                if terms.len() >= 6 {
                    return terms;
                }
            }
        }
    }
    terms
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EvaluationDecision {
    pub is_faithful: bool,
    pub faithfulness_score: f32,
    pub halluncination_risk: f32,
    /// Calibrated probability (`contradicts_context` noul) that the output directly contradicts the context.
    #[serde(default)]
    pub contradiction_probability: f32,
    /// Normalized completeness score (`[0, 1]`) measuring coverage of key facts in the context.
    #[serde(default = "default_completeness")]
    pub completeness_score: f32,
    /// Code-owned verdict band (`grounded`, `contradiction_detected`, `unsettled_grounding`, `unsupported`).
    #[serde(default = "default_verdict_band")]
    pub verdict_band: String,
    pub evaluation_source: String,
}

fn default_completeness() -> f32 {
    0.80
}

fn default_verdict_band() -> String {
    "grounded".to_string()
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
        let model = resolve_jev_model();

        Self {
            api_key,
            key_source,
            model,
            client: reqwest::Client::builder()
                .timeout(std::time::Duration::from_secs(
                env::var("AINISH_RAG_TIMEOUT").ok().and_then(|s| s.parse().ok()).unwrap_or(8)
            ))
                .build()
                .unwrap_or_default(),
        }
    }

    /// Builds a noul (calibrated yes/no) question. `criteria` is mandatory on the Decisions API.
    pub fn noul_question(instructions: &str, true_case: &str, false_case: &str) -> serde_json::Value {
        json!({
            "type": "noul",
            "instructions": instructions,
            "criteria": { "true": true_case, "false": false_case }
        })
    }

    /// Builds a choice question from `(option, description)` pairs.
    pub fn choice_question(instructions: &str, options: &[(&str, &str)]) -> serde_json::Value {
        let names: Vec<&str> = options.iter().map(|(name, _)| *name).collect();
        let mut criteria = serde_json::Map::new();
        for (name, description) in options {
            criteria.insert((*name).to_string(), json!(description));
        }
        json!({
            "type": "choice",
            "instructions": instructions,
            "options": names,
            "criteria": criteria
        })
    }

    /// Builds a score question. The API expects `levels` (1..=n) plus one criterion per level, and
    /// answers with a continuous score in `[0, n-1]`.
    pub fn score_question(instructions: &str, level_criteria: &[&str]) -> serde_json::Value {
        let levels: Vec<usize> = (1..=level_criteria.len()).collect();
        json!({
            "type": "score",
            "instructions": instructions,
            "levels": levels,
            "criteria": level_criteria
        })
    }

    /// Sends one typed question batch over the first usable configured transport.
    ///
    /// Both OpenRouter's Decisions API and the loopback `local-router` decisions proxy target the
    /// latest Jev model (`typesafe/jev-1.14`) with no silent older-model downgrade.
    async fn ask(
        &self,
        state: &str,
        questions: &serde_json::Value,
    ) -> Result<AskOutcome, String> {
        let mut errors: Vec<String> = Vec::new();
        for transport in transport_priority_order() {
            match transport {
                "local-router" => {
                    if let Some(router) = discover_local_router().await {
                        match router.decisions_url.as_deref() {
                            Some(url) => match self.post_decisions(url, None, state, questions).await {
                                Ok(outcome) => return Ok(outcome),
                                Err(error) => errors.push(format!("local-router {}: {}", router.base_url, error)),
                            },
                            None => errors.push(format!(
                                "local-router {} advertises Jev chat models ({}) but exposes no decisions route",
                                router.base_url,
                                router.jev_models.join(", ")
                            )),
                        }
                    }
                }
                "openrouter" => {
                    if let Some(key) = self.api_key.as_ref() {
                        match self.post_decisions(OPENROUTER_DECISIONS_URL, Some(key), state, questions).await {
                            Ok(outcome) => return Ok(outcome),
                            Err(error) => errors.push(error),
                        }
                    } else {
                        errors.push("no OpenRouter key resolved (set OPENROUTER_API_KEY or store LOCALROUTER_OPENROUTER_API_KEY in the PQC vault)".to_string());
                    }
                }
                "jev" => {
                    let endpoint = env::var("JEV_API_URL")
                        .or_else(|_| env::var("TYPESAFE_API_URL"))
                        .ok()
                        .filter(|value| !value.trim().is_empty());
                    let key = Self::resolve_jev_api_key();
                    if let (Some(endpoint), Some(key)) = (endpoint.as_ref(), key.as_ref()) {
                        match self.post_decisions(endpoint, Some(key), state, questions).await {
                            Ok(outcome) => return Ok(outcome),
                            Err(error) => errors.push(format!("jev {}: {}", endpoint, error)),
                        }
                    } else if endpoint.is_some() {
                        errors.push("direct Jev endpoint configured but no TypeSafe/Jev API key resolved".to_string());
                    }
                }
                "local-model" => {
                    if let Ok(endpoint) = env::var("JEV_LOCAL_MODEL_URL") {
                        if !endpoint.trim().is_empty() {
                            let key = env::var("JEV_LOCAL_MODEL_API_KEY")
                                .ok()
                                .filter(|value| !value.trim().is_empty());
                            match self.post_decisions(&endpoint, key.as_ref(), state, questions).await {
                                Ok(outcome) => return Ok(outcome),
                                Err(error) => errors.push(format!("local-model {}: {}", endpoint, error)),
                            }
                        }
                    }
                }
                _ => {}
            }
        }

        Err(if errors.is_empty() {
            "no Jev decision transport available".to_string()
        } else {
            errors.join("; ")
        })
    }

    /// POSTs one typed batch to a specific decisions endpoint. The key is only sent to OpenRouter.
    async fn post_decisions(
        &self,
        endpoint: &str,
        key: Option<&String>,
        state: &str,
        questions: &serde_json::Value,
    ) -> Result<AskOutcome, String> {
        let payload = json!({ "model": self.model, "state": state, "questions": questions });
        let mut request = self.client.post(endpoint)
            .header("Content-Type", "application/json")
            .header("HTTP-Referer", "https://github.com/nbiish/ainish-coder")
            .header("X-Title", "ainish-rag-decisions");
        if let Some(key) = key {
            request = request.header("Authorization", format!("Bearer {}", key));
        }
        let response = request
            .json(&payload)
            .send()
            .await
            .map_err(|e| format!("Jev request to {} failed: {}", endpoint, e))?;
        let status = response.status();
        let body_text = response.text().await.unwrap_or_default();
        if !status.is_success() {
            return Err(format!(
                "Jev API {} at {} for {}: {}",
                status,
                endpoint,
                self.model,
                truncate_chars(&body_text, 300)
            ));
        }

        let body: serde_json::Value = serde_json::from_str(&body_text)
            .map_err(|e| format!("Jev response was not JSON: {}", e))?;
        let resolved_model = body.get("model").and_then(|v| v.as_str()).unwrap_or(&self.model).to_string();
        let answers = parse_jev_answers(&body);
        if answers.is_empty() {
            return Err("Jev response contained no answers".to_string());
        }
        let usage = body.get("usage").cloned().unwrap_or(serde_json::Value::Null);
        let transport = if endpoint.contains("openrouter.ai") {
            "openrouter".to_string()
        } else if env::var("JEV_API_URL").ok().as_deref() == Some(endpoint)
            || env::var("TYPESAFE_API_URL").ok().as_deref() == Some(endpoint)
        {
            "jev".to_string()
        } else if endpoint.starts_with("http://127.0.0.1")
            || endpoint.starts_with("http://localhost")
        {
            format!("local-router:{}", endpoint)
        } else {
            format!("local-model:{}", endpoint)
        };
        Ok(AskOutcome { model: resolved_model, answers, usage, transport })
    }

    /// Public typed decision primitive used by `ainish-rag decide --questions`.
    pub async fn decide(&self, state: &str, questions: &serde_json::Value) -> Result<DecisionSet, String> {
        let outcome = self.ask(state, questions).await?;
        let mut ordered: Vec<JevAnswer> = outcome.answers.into_values().collect();
        ordered.sort_by(|a, b| a.id.cmp(&b.id));
        Ok(DecisionSet {
            source: format!("{}:{}", outcome.transport, outcome.model),
            model: outcome.model,
            answers: ordered,
            usage: outcome.usage,
        })
    }

    /// Resolves the OpenRouter API key, accepting the consumer-prefixed names that the PQC store
    /// actually carries (`LOCALROUTER_OPENROUTER_API_KEY`, `AINISHCODER_OPENROUTER_API_KEY`, …):
    /// 1. Environment, then the PQC store, through the shared provider resolver.
    /// 2. Legacy direct env names and the historical `vault_var` path for exotic stores.
    /// 3. Offline calibrated fallback.
    pub fn resolve_api_key() -> (Option<String>, String) {
        const OPENROUTER_KEY_NAMES: &[&str] = &[
            "OPENROUTER_API_KEY",
            "ROUTER_API_KEY",
            "OPENROUTER_EMBED_API_KEY",
            "LOCALROUTER_OPENROUTER_API_KEY",
            "LOCALROUTER_OPENROUTER_EMBED_API_KEY",
            "AINISHCODER_OPENROUTER_API_KEY",
            "PSIONICS_OPENROUTER_API_KEY",
            "PSIONICS_OPENROUTER_EMBED_API_KEY",
        ];
        if let Some((key, source)) = crate::provider::resolve_named_secret(OPENROUTER_KEY_NAMES) {
            return (Some(key), source);
        }

        // Legacy fallback for stores reached only through the older vault_var discovery path.
        for var_name in OPENROUTER_KEY_NAMES {
            if let Ok(val) = env::var(var_name) {
                let trimmed = val.trim();
                if !trimmed.is_empty() {
                    return (Some(trimmed.to_string()), format!("env:{}", var_name));
                }
            }
        }
        if let Some(key) = Self::vault_var(OPENROUTER_KEY_NAMES) {
            return (Some(key), "pqc-secrets-vault".to_string());
        }

        (None, "local-calibrated-fallback".to_string())
    }

    fn resolve_jev_api_key() -> Option<String> {
        const JEV_KEY_NAMES: &[&str] = &[
            "TYPESAFE_API_KEY",
            "TYPESAFEAI_API_KEY",
            "TYPESAFE_JEV_API_KEY",
            "JEV_API_KEY",
        ];
        crate::provider::resolve_named_secret(JEV_KEY_NAMES)
            .map(|(key, _)| key)
            .or_else(|| {
                JEV_KEY_NAMES.iter().find_map(|name| {
                    env::var(name)
                        .ok()
                        .filter(|value| !value.trim().is_empty())
                })
            })
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
        let model = resolve_jev_model();

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

    /// Executes pqc-secrets export and extracts the first matching key in memory (never persisted).
    pub fn vault_var(names: &[&str]) -> Option<String> {
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
                        if let Some(key) = Self::parse_pqc_export(&stdout, names) {
                            return Some(key);
                        }
                    }
                }
            }
        }

        // Try via uv, python3, python, or py with script discovery.
        //
        // The engine is resolved from BOTH layouts on purpose: the ainish-coder
        // checkout ships it under skills-to-distribute/skills/, while a consumer
        // repo receives a vendored copy at .agents/skills/. Probing only one of
        // them makes the decision path silently unavailable in the other.
        let mut script_candidates = vec![
            PathBuf::from("skills-to-distribute/skills/pqc-secrets/scripts/pqc_secrets.py"),
            PathBuf::from("../skills-to-distribute/skills/pqc-secrets/scripts/pqc_secrets.py"),
            PathBuf::from("D:/Code/ainish-coder/skills-to-distribute/skills/pqc-secrets/scripts/pqc_secrets.py"),
            PathBuf::from("/mnt/c/Code/ainish-coder/skills-to-distribute/skills/pqc-secrets/scripts/pqc_secrets.py"),
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
                            if let Some(key) = Self::parse_pqc_export(&stdout, names) {
                                return Some(key);
                            }
                        }
                    }
                }
            }
        }

        None
    }

    fn parse_pqc_export(stdout: &str, names: &[&str]) -> Option<String> {
        for line in stdout.lines() {
            let line = line.trim();
            if let Some(rest) = line.strip_prefix("export ") {
                if let Some((k, v)) = rest.split_once('=') {
                    let k = k.trim();
                    let v = v.trim().trim_matches('\'').trim_matches('"');
                    if names.contains(&k) && !v.is_empty() {
                        return Some(v.to_string());
                    }
                }
            }
        }
        None
    }

    /// Evaluates if a query requires retrieval, which domain it targets, its specificity and
    /// modality preference, and how much it depends on fresh branch state. Always attempts the
    /// prioritized Jev transports (OpenRouter + Local Router) before falling back to local calibration.
    pub async fn route(&self, prompt: &str) -> RouteDecision {
        if let Ok(decision) = self.route_via_jev(prompt).await {
            return decision;
        }
        self.route_local(prompt)
    }

    /// Adaptive RAG routing: sends five typed judgments in one parallel Jev batch, then derives a
    /// deterministic `retrieval_strategy` and `candidate_pool_size` in code.
    async fn route_via_jev(&self, prompt: &str) -> Result<RouteDecision, Box<dyn std::error::Error + Send + Sync>> {
        let questions = json!({
            "needs_retrieval": Self::noul_question(
                "Does answering this request require retrieving this repository's code, architecture wiki, or coordination context instead of relying on general knowledge?",
                "the answer depends on files, symbols, documentation, or task history that live in this repository",
                "the request is self-contained or answerable from general knowledge"
            ),
            "domain_target": Self::choice_question(
                "Which part of this repository's context would best answer the request?",
                &[
                    ("codebase_symbols", "source code, symbol definitions, call sites, or APIs in the repository"),
                    ("architectural_wiki", "system architecture, component relationships, data flow, or design rationale"),
                    ("security_governance", "security policy, PQC, secrets handling, audit, or compliance rules"),
                    ("technical_debt", "known gaps, TODOs, refactors, drift, or maintenance risk"),
                    ("general_knowledge", "language or tooling knowledge that does not depend on this repository"),
                ]
            ),
            "context_freshness": Self::noul_question(
                "Does the request concern recent changes, the current branch, or today's work rather than long-lived architecture?",
                "it asks about recent edits, uncommitted work, the current branch, or today's activity",
                "it asks about stable architecture or long-lived behaviour"
            ),
            "query_specificity": Self::choice_question(
                "How specific is the lookup required by this request?",
                &[
                    ("exact_symbol", "names a specific function, struct, file path, CLI flag, or error string"),
                    ("conceptual_flow", "asks how a subsystem, protocol, or component interaction works"),
                    ("broad_audit", "asks for a multi-file audit, repo-wide review, or broad architectural scan"),
                ]
            ),
            "modality_preference": Self::choice_question(
                "Which artefact modality should retrieval prioritize first?",
                &[
                    ("code_first", "shipping source code and symbol definitions"),
                    ("docs_first", "architectural wiki pages, PRD (llms.txt), or governing contracts (AGENTS.md)"),
                    ("balanced", "a mix of implementation code and architectural documentation"),
                ]
            )
        });

        let outcome = self.ask(prompt, &questions).await?;
        let answers = outcome.answers;
        let retrieval_probability = answers.get("needs_retrieval").and_then(|a| a.noul).unwrap_or(0.85);
        let needs_retrieval = retrieval_probability >= 0.5;
        let target_domain = answers
            .get("domain_target")
            .and_then(|a| a.choice.clone())
            .unwrap_or_else(|| "codebase_symbols".to_string());
        let route_confidence = answers
            .get("domain_target")
            .and_then(|a| a.confidence)
            .unwrap_or(0.80);
        let context_freshness = answers.get("context_freshness").and_then(|a| a.noul).unwrap_or(0.5);
        let query_specificity = answers
            .get("query_specificity")
            .and_then(|a| a.choice.clone())
            .unwrap_or_else(|| {
                if target_domain == "codebase_symbols" {
                    "exact_symbol".to_string()
                } else {
                    "conceptual_flow".to_string()
                }
            });
        let modality_preference = answers
            .get("modality_preference")
            .and_then(|a| a.choice.clone())
            .unwrap_or_else(|| match target_domain.as_str() {
                "codebase_symbols" => "code_first".to_string(),
                "architectural_wiki" | "security_governance" => "docs_first".to_string(),
                _ => "balanced".to_string(),
            });
        let (retrieval_strategy, candidate_pool_size) = derive_retrieval_strategy(
            needs_retrieval,
            &target_domain,
            context_freshness,
            &query_specificity,
            &modality_preference,
        );
        let context_budget_tokens = context_budget_for(&retrieval_strategy);
        let next_action = next_action_for(&retrieval_strategy).to_string();

        Ok(RouteDecision {
            needs_retrieval,
            retrieval_probability,
            target_domain,
            route_confidence,
            context_freshness,
            query_specificity,
            modality_preference,
            retrieval_strategy,
            candidate_pool_size,
            context_budget_tokens,
            next_action,
            source: format!("{}:{}", outcome.transport, outcome.model),
        })
    }

    /// Calibrated fallback decision logic when offline or when both OpenRouter and Local Router are unreachable
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
                context_freshness: 0.10,
                query_specificity: "exact_symbol".to_string(),
                modality_preference: "balanced".to_string(),
                retrieval_strategy: "skip_retrieval".to_string(),
                candidate_pool_size: 0,
                context_budget_tokens: 0,
                next_action: next_action_for("skip_retrieval").to_string(),
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

        let freshness = if p_lower.contains("today") || p_lower.contains("recent") || p_lower.contains("branch") || p_lower.contains("latest") || p_lower.contains("diff") {
            0.80
        } else {
            0.50
        };
        let specificity = if p_lower.contains("audit") || p_lower.contains("every ") || p_lower.contains("all ") || p_lower.contains("across ") {
            "broad_audit".to_string()
        } else if p_lower.contains("::") || p_lower.contains(".rs") || p_lower.contains(".py") || p_lower.contains("fn ") || p_lower.contains("--") {
            "exact_symbol".to_string()
        } else {
            "conceptual_flow".to_string()
        };
        let modality = match domain.as_str() {
            "codebase_symbols" => "code_first".to_string(),
            "architectural_wiki" | "security_governance" => "docs_first".to_string(),
            _ => "balanced".to_string(),
        };
        let (strategy, pool_size) = derive_retrieval_strategy(true, &domain, freshness, &specificity, &modality);

        RouteDecision {
            needs_retrieval: true,
            retrieval_probability: 0.88,
            target_domain: domain,
            route_confidence: conf,
            context_freshness: freshness,
            query_specificity: specificity,
            modality_preference: modality,
            retrieval_strategy: strategy.clone(),
            candidate_pool_size: pool_size,
            context_budget_tokens: context_budget_for(&strategy),
            next_action: next_action_for(&strategy).to_string(),
            source: "local-calibrated".to_string(),
        }
    }

    /// Two-Stage RAG: Rerank candidate chunks using the prioritized Jev transports (OpenRouter + Local Router)
    pub async fn rerank(
        &self,
        query: &str,
        candidates: Vec<crate::store::SearchHit>,
        min_relevance: f32,
    ) -> Vec<RerankResult> {
        if candidates.is_empty() {
            return Vec::new();
        }

        if let Ok(results) = self.rerank_via_jev(query, &candidates, min_relevance).await {
            return results;
        }

        self.rerank_local(query, candidates, min_relevance)
    }

    /// Calls TypeSafe Jev model on OpenRouter Decisions API to evaluate and score candidates
    /// Two-stage rerank: one typed question batch judges every candidate (Jev runs the questions
    /// in parallel), then code combines the judgments with the vector score.
    async fn rerank_via_jev(
        &self,
        query: &str,
        candidates: &[crate::store::SearchHit],
        min_relevance: f32,
    ) -> Result<Vec<RerankResult>, Box<dyn std::error::Error + Send + Sync>> {
        let capped: Vec<&crate::store::SearchHit> = candidates.iter().take(12).collect();
        if capped.is_empty() {
            return Ok(Vec::new());
        }

        let mut questions = serde_json::Map::new();
        for (index, chunk) in capped.iter().enumerate() {
            let excerpt = truncate_chars(&chunk.content, 900);
            let context = format!(
                "Candidate {}: file {}, type {}, title {}.\nExcerpt:\n{}",
                index + 1, chunk.path, chunk.doc_type, chunk.title, excerpt
            );
            questions.insert(
                format!("answers_directly_{}", index),
                Self::noul_question(
                    &format!("{}\n\nDoes this excerpt provide the specific fact, symbol, or implementation the query needs?", context),
                    "the excerpt states the definition, behaviour, or symbol the query asks for",
                    "the excerpt is only topically related or answers a different question",
                ),
            );
            questions.insert(
                format!("names_query_symbols_{}", index),
                Self::noul_question(
                    &format!("{}\n\nDoes this excerpt contain any symbol, file, or API named in the query?", context),
                    "at least one symbol or API named by the query appears in the excerpt",
                    "none of the query's named symbols or APIs appear",
                ),
            );
            questions.insert(
                format!("utility_{}", index),
                Self::score_question(
                    &format!("{}\n\nHow useful is this excerpt for answering the query?", context),
                    &[
                        "unrelated to the query",
                        "tangential background",
                        "related but incomplete",
                        "directly useful evidence",
                        "the canonical implementation or reference",
                    ],
                ),
            );
            questions.insert(
                format!("chunk_role_{}", index),
                Self::choice_question(
                    &format!("{}\n\nWhat kind of artefact is this excerpt from?", context),
                    &[
                        ("implementation", "production source code or shipping configuration"),
                        ("documentation", "prose, PRD, wiki, or comments that explain behaviour"),
                        ("test", "test code, fixtures, or benchmarks"),
                        ("generated", "vendored, generated, or minified content with no clear authorship"),
                    ],
                ),
            );
        }

        let state = format!(
            "Query: {}\nTask: rank retrieved context for a coding agent. Prefer primary sources over generated or vendored material.",
            query
        );
        let outcome = self.ask(&state, &serde_json::Value::Object(questions)).await?;
        let answers = outcome.answers;
        let model = outcome.model;
        let transport = outcome.transport;

        let mut reranked = Vec::new();
        for (index, chunk) in capped.iter().enumerate() {
            let direct = answers
                .get(&format!("answers_directly_{}", index))
                .and_then(|answer| answer.noul)
                .unwrap_or(0.5);
            let symbol_support = answers
                .get(&format!("names_query_symbols_{}", index))
                .and_then(|answer| answer.noul)
                .unwrap_or(0.5);
            let utility_raw = answers
                .get(&format!("utility_{}", index))
                .and_then(|answer| answer.score)
                .unwrap_or(2.0);
            let utility = (utility_raw / 4.0).clamp(0.0, 1.0);
            let role = answers
                .get(&format!("chunk_role_{}", index))
                .and_then(|answer| answer.choice.clone())
                .unwrap_or_else(|| "unknown".to_string());

            // 45% direct answer, 25% symbol grounding, 30% continuous utility; generated/vendored
            // material is discounted, settled primary implementations receive a grounding bonus,
            // and CRAG hard negatives (direct in the `no` band with low utility) are suppressed so
            // high-vector-similarity distractors cannot masquerade as relevant.
            let decision_score = (0.45 * direct) + (0.25 * symbol_support) + (0.30 * utility);
            let role_penalty = match role.as_str() {
                "generated" => 0.08,
                "test" => 0.03,
                _ => 0.0,
            };
            let primary_bonus = if role == "implementation" && direct >= JEV_NOUL_YES && symbol_support >= 0.50 {
                0.04
            } else {
                0.0
            };
            let distractor_penalty = if direct <= JEV_NOUL_NO && utility_raw < 2.0 {
                0.12
            } else {
                0.0
            };
            let adjusted_decision = (decision_score + primary_bonus - role_penalty - distractor_penalty).clamp(0.0, 1.0);
            let band = noul_band(direct);
            let combined = if direct <= JEV_NOUL_NO && utility_raw < 2.0 {
                (adjusted_decision * 0.80) + (chunk.score.min(0.45) * 0.20)
            } else if band == "unsettled" {
                (adjusted_decision * 0.65) + (chunk.score * 0.35)
            } else {
                (adjusted_decision * 0.70) + (chunk.score * 0.30)
            };
            let is_relevant = direct >= 0.5;
            let rerank_source = format!("{}:{}", transport, model);
            let rationale = format!(
                "Jev {}: direct {:.2} ({}), symbols {:.2}, utility {:.2}/4 [{}], vector {:.2}",
                rerank_source,
                direct,
                band,
                symbol_support,
                utility_raw,
                role,
                chunk.score
            );

            if combined >= min_relevance {
                let mut updated_chunk = (*chunk).clone();
                updated_chunk.score = combined;
                reranked.push(RerankResult {
                    chunk: updated_chunk,
                    original_score: chunk.score,
                    decision_score,
                    rerank_score: combined,
                    is_relevant,
                    direct_probability: direct,
                    symbol_support,
                    utility_score: utility_raw,
                    noul_band: band.to_string(),
                    role,
                    rerank_source,
                    rationale,
                });
            }
        }

        reranked.sort_by(|a, b| b.rerank_score.partial_cmp(&a.rerank_score).unwrap_or(std::cmp::Ordering::Equal));
        Ok(reranked)
    }

    /// Calibrated local reranking fallback with Reciprocal Rank Fusion (RRF with K=60), lexical matching, and symbol boost
    pub fn rerank_local(
        &self,
        query: &str,
        candidates: Vec<crate::store::SearchHit>,
        min_relevance: f32,
    ) -> Vec<RerankResult> {
        let q_lower = query.to_lowercase();
        let q_terms: Vec<&str> = q_lower.split_whitespace().filter(|t| t.len() > 2).collect();
        let k = 60.0;
        let n = candidates.len();

        // 1. Compute lexical coverage ranking for RRF
        let mut lexical_scored: Vec<(usize, f32)> = candidates
            .iter()
            .enumerate()
            .map(|(idx, chunk)| {
                let text = chunk.content.to_lowercase();
                let title = chunk.title.to_lowercase();
                let sym = chunk.symbols.to_lowercase();
                let matches = q_terms.iter().filter(|t| text.contains(*t) || title.contains(*t) || sym.contains(*t)).count();
                let ratio = if !q_terms.is_empty() { matches as f32 / q_terms.len() as f32 } else { 0.0 };
                (idx, ratio)
            })
            .collect();
        lexical_scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

        let mut reranked = Vec::new();

        for (vec_rank, chunk) in candidates.into_iter().enumerate() {
            let lex_rank = lexical_scored.iter().position(|(idx, _)| *idx == vec_rank).unwrap_or(n);
            // SOTA Reciprocal Rank Fusion blending dense vector rank + sparse lexical rank
            let rrf_raw = (0.50 / (k + (vec_rank as f32 + 1.0))) + (0.50 / (k + (lex_rank as f32 + 1.0)));
            let rrf_norm = (rrf_raw * (k + 1.0)).min(1.0);

            let content_lower = chunk.content.to_lowercase();
            let title_lower = chunk.title.to_lowercase();
            let symbols_lower = chunk.symbols.to_lowercase();

            let term_matches = q_terms.iter().filter(|t| content_lower.contains(*t)).count();
            let term_ratio = if !q_terms.is_empty() {
                term_matches as f32 / q_terms.len() as f32
            } else {
                0.0
            };

            let title_match = q_terms.iter().any(|t| title_lower.contains(*t));
            let symbol_match = q_terms.iter().any(|t| symbols_lower.contains(*t));
            let boost = (if title_match { 0.15 } else { 0.0 }) + (if symbol_match { 0.15 } else { 0.0 });

            // Blended decision score: 40% RRF fusion + 30% vector score + 20% term coverage + 10% symbol/title boost
            let decision_score = (rrf_norm * 0.40) + (chunk.score * 0.30) + (term_ratio * 0.20) + boost;
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
                    direct_probability: decision_score,
                    symbol_support: if symbol_match { 0.85 } else { term_ratio },
                    utility_score: (decision_score * 4.0).clamp(0.0, 4.0),
                    noul_band: noul_band(decision_score).to_string(),
                    role: "unknown".to_string(),
                    rerank_source: "local-calibrated-rrf".to_string(),
                    rationale: format!("RRF hybrid fusion (rrf: {:.3}, terms: {}/{}, title: {}, symbols: {})", rrf_norm, term_matches, q_terms.len(), title_match, symbol_match),
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

    /// Bi-phasic evaluation: checks output faithfulness, contradiction risk, and completeness
    /// against retrieved context using one parallel Jev batch (OpenRouter + Local Router).
    pub async fn evaluate_faithfulness(&self, context: &str, output: &str) -> EvaluationDecision {
        let questions = json!({
            "is_faithful": Self::noul_question(
                "Is the output grounded in the provided context, without claims the context does not support?",
                "every claim in the output is supported by the context",
                "the output adds claims or specifics that the context does not contain"
            ),
            "faithfulness_score": Self::score_question(
                "How completely does the output stay within the provided context?",
                &[
                    "the output contradicts the context",
                    "mostly unsupported by the context",
                    "partly grounded with unsupported gaps",
                    "grounded with minor gaps",
                    "fully grounded in the context",
                ]
            ),
            "contradicts_context": Self::noul_question(
                "Does the output state any claim, rule, or detail that directly contradicts or inverts the provided context?",
                "the output states at least one claim that directly conflicts with or inverts the context",
                "the output does not contradict the provided context"
            ),
            "completeness_score": Self::score_question(
                "How completely does the output cover the key facts, symbols, and constraints in the provided context?",
                &[
                    "omits almost all relevant facts from the context",
                    "covers only a minor part of the relevant context",
                    "covers the main point with notable omissions",
                    "covers nearly all key facts and symbols",
                    "comprehensive coverage of the relevant context",
                ]
            )
        });

        let state = format!(
            "CONTEXT:\n{}\n\nOUTPUT TO EVALUATE:\n{}",
            truncate_chars(context, 4000),
            truncate_chars(output, 2000)
        );

        if let Ok(outcome) = self.ask(&state, &questions).await {
            let answers = outcome.answers;
            let noul = answers.get("is_faithful").and_then(|answer| answer.noul).unwrap_or(0.9);
            let score = answers
                .get("faithfulness_score")
                .and_then(|answer| answer.score)
                .unwrap_or(3.6);
            let score_norm = (score / 4.0).clamp(0.0, 1.0);
            let contradiction = answers
                .get("contradicts_context")
                .and_then(|answer| answer.noul)
                .unwrap_or(0.05);
            let completeness_raw = answers
                .get("completeness_score")
                .and_then(|answer| answer.score)
                .unwrap_or(3.2);
            let completeness_norm = (completeness_raw / 4.0).clamp(0.0, 1.0);

            let base_faithfulness = (0.6 * noul) + (0.4 * score_norm);
            let has_contradiction = contradiction >= JEV_NOUL_YES;
            let faithfulness = if has_contradiction {
                base_faithfulness.min(1.0 - contradiction)
            } else {
                base_faithfulness
            };
            let is_faithful = !has_contradiction && noul >= 0.5 && score_norm >= 0.4;
            let verdict_band = if has_contradiction {
                "contradiction_detected"
            } else if noul >= JEV_NOUL_YES && score_norm >= 0.6 {
                "grounded"
            } else if noul <= JEV_NOUL_NO || score_norm < 0.4 {
                "unsupported"
            } else {
                "unsettled_grounding"
            };

            return EvaluationDecision {
                is_faithful,
                faithfulness_score: faithfulness,
                halluncination_risk: (1.0 - faithfulness).max(0.0),
                contradiction_probability: contradiction,
                completeness_score: completeness_norm,
                verdict_band: verdict_band.to_string(),
                evaluation_source: format!("{}:{}", outcome.transport, outcome.model),
            };
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
            contradiction_probability: 0.0,
            completeness_score: ratio,
            verdict_band: if ratio >= 0.70 { "grounded" } else if ratio >= 0.40 { "unsettled_grounding" } else { "unsupported" }.to_string(),
            evaluation_source: "local-heuristic".to_string(),
        }
    }
}

/// Parses typed Jev answers from the Decisions API envelope.
///
/// Current shape: `{"answers":{"q":{"type":"noul","noul":0.97}}}`; the legacy
/// `{"decisions":{...}}` shape with `value`/`probability` is still accepted defensively.
pub fn parse_jev_answers(body: &serde_json::Value) -> HashMap<String, JevAnswer> {
    let root = body
        .get("answers")
        .or_else(|| body.get("decisions"))
        .unwrap_or(body);
    let Some(object) = root.as_object() else {
        return HashMap::new();
    };

    let mut answers = HashMap::new();
    for (id, value) in object {
        let Some(fields) = value.as_object() else { continue };
        let kind = fields.get("type").and_then(|v| v.as_str()).unwrap_or("").to_string();

        let noul = fields
            .get("noul")
            .and_then(|v| v.as_f64())
            .map(|v| v as f32)
            .or_else(|| fields.get("probability").and_then(|v| v.as_f64()).map(|v| v as f32))
            .or_else(|| {
                fields.get("value").and_then(|v| v.as_bool()).map(|b| if b { 0.95 } else { 0.05 })
            });
        let choice = fields
            .get("choice")
            .and_then(|v| v.as_str())
            .map(str::to_string)
            .or_else(|| fields.get("value").and_then(|v| v.as_str()).map(str::to_string));
        let score = fields
            .get("score")
            .and_then(|v| v.as_f64())
            .map(|v| v as f32)
            .or_else(|| {
                if kind.is_empty() {
                    fields.get("value").and_then(|v| v.as_f64()).map(|v| v as f32)
                } else {
                    None
                }
            });

        answers.insert(
            id.clone(),
            JevAnswer {
                id: id.clone(),
                kind,
                noul,
                choice,
                score,
                confidence: fields.get("confidence").and_then(|v| v.as_f64()).map(|v| v as f32),
                probabilities: fields.get("probabilities").cloned(),
                legend: fields.get("legend").cloned(),
            },
        );
    }
    answers
}

/// UTF-8-safe truncation. The previous byte slicing could panic on multi-byte content.
pub fn truncate_chars(text: &str, max_chars: usize) -> String {
    if text.chars().count() <= max_chars {
        return text.to_string();
    }
    let mut out: String = text.chars().take(max_chars).collect();
    out.push('…');
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    // Environment mutation is process-global; serialize the tests that touch it.
    static ENV_LOCK: Mutex<()> = Mutex::new(());

    #[test]
    fn test_model_defaults_to_latest() {
        let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        unsafe { std::env::remove_var("JEV_DECISION_MODEL") };
        assert_eq!(resolve_jev_model(), LATEST_JEV_MODEL);
        assert!(!is_model_pinned());

        for alias in ["latest", "typesafe/jev-latest"] {
            unsafe { std::env::set_var("JEV_DECISION_MODEL", alias) };
            assert_eq!(resolve_jev_model(), LATEST_JEV_MODEL);
            assert!(!is_model_pinned());
        }
        unsafe { std::env::remove_var("JEV_DECISION_MODEL") };
    }

    #[test]
    fn test_explicit_older_pin_is_reported_but_honored() {
        let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        unsafe { std::env::set_var("JEV_DECISION_MODEL", "typesafe/jev-1.13") };
        assert_eq!(resolve_jev_model(), "typesafe/jev-1.13");
        assert!(is_model_pinned(), "an older pin must be reported, not hidden");
        unsafe { std::env::remove_var("JEV_DECISION_MODEL") };
    }

    #[test]
    fn test_local_router_model_filter() {
        let models = vec![
            "openrouter-jev-router".to_string(),
            "zenmux-deepseek-v4.1-flash".to_string(),
            "typesafe-jev".to_string(),
        ];
        let jev = jev_models_filter(&models);
        assert_eq!(jev, vec!["openrouter-jev-router", "typesafe-jev"]);
        assert!(jev_models_filter(&["chat-model".to_string()]).is_empty());
    }

    #[test]
    fn test_local_decisions_paths_are_probed_in_order() {
        assert_eq!(LOCAL_DECISIONS_PATHS[0], "/api/alpha/decisions");
        assert!(DEFAULT_LOCAL_ROUTER_URL.ends_with(":11434"));
    }

    #[test]
    fn test_parse_current_typed_answers() {
        let body = serde_json::json!({
            "model": "typesafe/jev-1.14-20261014",
            "answers": {
                "needs_retrieval": {"type": "noul", "noul": 0.91},
                "domain": {"type": "choice", "choice": "architectural_wiki", "probabilities": {"architectural_wiki": 0.82}, "confidence": 0.82},
                "utility": {"type": "score", "score": 3.61, "legend": {"0": "unrelated"}, "confidence": 0.67}
            }
        });
        let answers = parse_jev_answers(&body);
        assert_eq!(answers.len(), 3);
        assert!((answers["needs_retrieval"].noul.unwrap() - 0.91).abs() < 1e-6);
        assert_eq!(answers["domain"].choice.as_deref(), Some("architectural_wiki"));
        assert!((answers["domain"].confidence.unwrap() - 0.82).abs() < 1e-6);
        assert!((answers["utility"].score.unwrap() - 3.61).abs() < 1e-4);
        assert!(answers["utility"].legend.is_some());
    }

    #[test]
    fn test_parse_legacy_value_probability_shape() {
        let body = serde_json::json!({
            "decisions": {
                "needs_retrieval": {"value": true, "probability": 0.93},
                "domain": {"value": "security_governance", "probability": 0.71}
            }
        });
        let answers = parse_jev_answers(&body);
        assert_eq!(answers["needs_retrieval"].band(), "yes");
        assert_eq!(answers["domain"].choice.as_deref(), Some("security_governance"));
    }

    #[test]
    fn test_questions_carry_mandatory_criteria() {
        // Regression: the Decisions API rejects noul/choice/score questions without `criteria`.
        let noul = DecisionEngine::noul_question("Does the file use LanceDB?", "it connects to LanceDB", "it does not");
        assert_eq!(noul["type"], "noul");
        assert_eq!(noul["criteria"]["true"], "it connects to LanceDB");

        let choice = DecisionEngine::choice_question("Which component?", &[("store", "vector storage"), ("api", "http surface")]);
        assert_eq!(choice["options"].as_array().unwrap().len(), 2);
        assert_eq!(choice["criteria"]["store"], "vector storage");

        let score = DecisionEngine::score_question("How useful?", &["unrelated", "related", "canonical"]);
        assert_eq!(score["levels"].as_array().unwrap().len(), 3);
        assert_eq!(score["criteria"].as_array().unwrap().len(), 3);
    }

    #[test]
    fn test_noul_bands_follow_calibration() {
        assert_eq!(noul_band(0.95), "yes");
        assert_eq!(noul_band(0.70), "yes");
        assert_eq!(noul_band(0.50), "unsettled");
        assert_eq!(noul_band(0.30), "no");
        assert_eq!(noul_band(0.02), "no");
    }

    #[test]
    fn test_derive_retrieval_strategy_maps_calibrated_signals() {
        assert_eq!(derive_retrieval_strategy(false, "codebase_symbols", 0.2, "exact_symbol", "code_first").0, "skip_retrieval");
        assert_eq!(derive_retrieval_strategy(true, "general_knowledge", 0.2, "conceptual_flow", "balanced").0, "skip_retrieval");
        assert_eq!(derive_retrieval_strategy(true, "codebase_symbols", 0.85, "exact_symbol", "code_first").0, "fresh_orient_first");
        assert_eq!(derive_retrieval_strategy(true, "codebase_symbols", 0.2, "exact_symbol", "code_first"), ("symbol_anchored".to_string(), 10));
        assert_eq!(derive_retrieval_strategy(true, "architectural_wiki", 0.2, "broad_audit", "docs_first"), ("multi_hop_expand".to_string(), 16));
        assert_eq!(derive_retrieval_strategy(true, "architectural_wiki", 0.2, "conceptual_flow", "docs_first"), ("hybrid_rerank".to_string(), 12));
    }

    #[test]
    fn test_context_sufficiency_classifies_crag_bands() {
        let make = |prob: f32, utility: f32, score: f32, role: &str| RerankResult {
            chunk: crate::store::SearchHit {
                id: "test".into(),
                repo: "ainish-coder".into(),
                path: "src/lib.rs".into(),
                doc_type: "code".into(),
                modality: "code".into(),
                title: "lib".into(),
                content: "content".into(),
                symbols: "[]".into(),
                start_line: 1,
                end_line: 1,
                score,
            },
            original_score: score,
            decision_score: score,
            rerank_score: score,
            is_relevant: true,
            direct_probability: prob,
            symbol_support: 0.6,
            utility_score: utility,
            noul_band: noul_band(prob).to_string(),
            role: role.to_string(),
            rerank_source: "test".into(),
            rationale: String::new(),
        };
        assert_eq!(evaluate_context_sufficiency(&[]), "insufficient");
        assert_eq!(evaluate_context_sufficiency(&[make(0.05, 1.0, 0.3, "implementation")]), "insufficient");
        assert_eq!(evaluate_context_sufficiency(&[make(0.90, 3.5, 0.7, "implementation")]), "sufficient");
        assert_eq!(evaluate_context_sufficiency(&[make(0.50, 2.5, 0.5, "documentation")]), "partial_unsettled");
    }

    #[test]
    fn test_transport_priority_default_and_override() {
        let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        unsafe {
            std::env::remove_var("JEV_TRANSPORT_PRIORITY");
            std::env::remove_var("AINISH_RAG_DECISION_PRIORITY");
        }
        assert_eq!(
            transport_priority_order(),
            vec!["local-router", "openrouter", "jev", "local-model"]
        );

        unsafe { std::env::set_var("JEV_TRANSPORT_PRIORITY", "jev,local-model") };
        assert_eq!(
            transport_priority_order(),
            vec!["jev", "local-model", "local-router", "openrouter"]
        );
        unsafe { std::env::remove_var("JEV_TRANSPORT_PRIORITY") };
    }

    #[test]
    fn test_corrective_expansion_terms_prefer_new_symbols() {
        let hits = vec![crate::store::SearchHit {
            id: "test".into(),
            repo: "ainish-coder".into(),
            path: "src/rag/src/provider.rs".into(),
            doc_type: "code".into(),
            modality: "code".into(),
            title: "provider".into(),
            content: "fn resolve_named_secret()".into(),
            symbols: "[\"resolve_named_secret\",\"provider\"]".into(),
            start_line: 1,
            end_line: 10,
            score: 0.4,
        }];
        let terms = extract_corrective_expansion_terms("how does provider resolve embedding keys", &hits);
        assert!(terms.contains(&"resolve_named_secret".to_string()));
        assert!(!terms.contains(&"provider".to_string()), "query terms and file stems already present must not be re-added");
    }

    #[test]
    fn test_truncate_chars_is_utf8_safe() {
        let text = "é".repeat(10);
        let cut = truncate_chars(&text, 4);
        assert_eq!(cut.chars().count(), 5); // 4 chars + ellipsis
        assert_eq!(cut.chars().filter(|c| *c == 'é').count(), 4);
        assert_eq!(truncate_chars("short", 10), "short");
    }
}
