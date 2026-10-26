use serde::{Deserialize, Serialize};
use std::time::Duration;

#[derive(Debug, Serialize)]
struct EmbeddingRequest {
    model: String,
    input: Vec<String>,
    encoding_format: String,
}

#[derive(Debug, Deserialize)]
struct EmbeddingData {
    embedding: Vec<f32>,
    index: usize,
}

#[derive(Debug, Deserialize)]
struct EmbeddingResponse {
    data: Vec<EmbeddingData>,
}

#[derive(Clone)]
pub struct EmbedClient {
    client: reqwest::Client,
    server_url: String,
    truncate_dim: Option<usize>,
    pub psk: Option<String>,
    pub dp_epsilon: Option<f32>,
    pub repo_root: Option<std::path::PathBuf>,
    adaptive_batch_size: std::sync::Arc<std::sync::atomic::AtomicUsize>,
}

static PSK_GUARD: crate::server::PskAuthGuard = crate::server::PskAuthGuard::new(5);

impl EmbedClient {
    pub fn new(server_url: &str, truncate_dim: Option<usize>, psk: Option<String>) -> Self {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(60))
            .build()
            .unwrap_or_default();

        Self {
            client,
            server_url: server_url.trim_end_matches('/').to_string(),
            truncate_dim,
            psk,
            dp_epsilon: None,
            repo_root: None,
            adaptive_batch_size: std::sync::Arc::new(std::sync::atomic::AtomicUsize::new(16)),
        }
    }

    pub fn with_dp_epsilon(mut self, epsilon: Option<f32>) -> Self {
        self.dp_epsilon = epsilon;
        self
    }

    pub fn with_repo_root(mut self, root: &std::path::Path) -> Self {
        self.repo_root = Some(root.to_path_buf());
        self
    }

    /// Returns the current dynamically scaled batch size based on observed loopback RTT
    pub fn recommended_batch_size(&self) -> usize {
        self.adaptive_batch_size.load(std::sync::atomic::Ordering::Relaxed)
    }

    /// Updates adaptive batch size based on observed round-trip latency in milliseconds
    pub fn record_rtt_and_scale_batch(&self, rtt_ms: u128) -> usize {
        use std::sync::atomic::Ordering;
        let current = self.adaptive_batch_size.load(Ordering::Relaxed);
        let next = if rtt_ms < 120 {
            (current * 2).min(64)
        } else if rtt_ms > 600 {
            (current / 2).max(4)
        } else {
            current
        };
        self.adaptive_batch_size.store(next, Ordering::Relaxed);
        next
    }

    /// Format query with asymmetric task prefix
    pub fn format_query(query: &str, is_code: bool) -> String {
        if is_code {
            format!("task: code retrieval | query: {}", query.trim())
        } else {
            format!("task: search result | query: {}", query.trim())
        }
    }

    /// Format document with title prefix
    pub fn format_doc(title: Option<&str>, content: &str) -> String {
        let t = title.filter(|s| !s.trim().is_empty()).unwrap_or("none");
        let trimmed = content.trim();
        let safe_text = if trimmed.len() > 6000 {
            &trimmed[..6000]
        } else {
            trimmed
        };
        format!("title: {} | text: {}", t, safe_text)
    }

    /// Format multimodal entry with image placeholder
    pub fn format_multimodal_image(title: Option<&str>, caption: &str) -> String {
        let t = title.unwrap_or("image");
        format!("title: {} | text: <|image|> {}", t, caption.trim())
    }

    /// Embed a batch of formatted input strings with loopback DNS-rebinding protection and rate limiting
    pub async fn embed_batch(&self, inputs: &[String]) -> Result<Vec<Vec<f32>>, String> {
        if inputs.is_empty() {
            return Ok(Vec::new());
        }

        // Real-time anti-DNS rebinding and IP-binding verification
        crate::server::AntiDnsRebinding::validate_host(&self.server_url)?;

        // Automated loopback rate limiting: ensure inter-request spacing to prevent server overload
        tokio::time::sleep(Duration::from_millis(15)).await;

        let url = format!("{}/v1/embeddings", self.server_url);
        let req = EmbeddingRequest {
            model: "embeddinggemma2".to_string(),
            input: inputs.to_vec(),
            encoding_format: "float".to_string(),
        };

        let mut req_builder = self.client.post(&url)
            .header("Host", "127.0.0.1")
            .header("Origin", "http://127.0.0.1")
            .header("X-Requested-With", "ainish-rag");

        if let Some(token) = &self.psk {
            if let Some(ref root) = self.repo_root {
                let psk_file = root.join(".agents").join("rag").join("session.psk");
                if let Ok(expected) = std::fs::read_to_string(&psk_file) {
                    let exp_clean = expected.trim();
                    if !exp_clean.is_empty() {
                        PSK_GUARD.verify(exp_clean, token.trim())?;
                    }
                }
            }
            req_builder = req_builder
                .header("Authorization", format!("Bearer {}", token))
                .header("X-Ainish-PSK", token);
        }

        let t0 = std::time::Instant::now();
        let resp = req_builder
            .json(&req)
            .send()
            .await
            .map_err(|e| format!("Embedding request failed to {}: {}", url, e))?;
        let rtt_ms = t0.elapsed().as_millis();
        self.record_rtt_and_scale_batch(rtt_ms);

        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            return Err(format!("Embedding server returned {}: {}", status, body));
        }

        let parsed: EmbeddingResponse = resp.json()
            .await
            .map_err(|e| format!("Failed to parse embedding response: {}", e))?;

        let mut sorted = parsed.data;
        sorted.sort_by_key(|d| d.index);

        let mut results = Vec::with_capacity(sorted.len());
        for item in sorted {
            let mut vec = item.embedding;
            if let Some(dim) = self.truncate_dim {
                if dim < vec.len() {
                    vec.truncate(dim);
                    l2_normalize(&mut vec);
                }
            }

            if let Some(eps) = self.dp_epsilon {
                apply_differential_privacy_noise(&mut vec, eps, 0.05);
            }

            results.push(vec);
        }

        if let Some(eps) = self.dp_epsilon {
            if let Some(ref root) = self.repo_root {
                let _ = record_privacy_budget_expenditure(root, eps, results.len(), "embed_batch");
            }
        }

        Ok(results)
    }

    /// Embed a single input
    pub async fn embed_one(&self, input: &str) -> Result<Vec<f32>, String> {
        let batch = self.embed_batch(&[input.to_string()]).await?;
        batch.into_iter().next().ok_or_else(|| "Empty embedding result".to_string())
    }
}

pub fn l2_normalize(vec: &mut [f32]) {
    let norm_sq: f32 = vec.iter().map(|x| x * x).sum();
    let norm = norm_sq.sqrt();
    if norm > 1e-12 {
        for x in vec.iter_mut() {
            *x /= norm;
        }
    }
}

/// Applies Gaussian differential privacy noise to embedding coordinates to prevent membership inference attacks
pub fn apply_differential_privacy_noise(vec: &mut [f32], epsilon: f32, sensitivity: f32) {
    if epsilon <= 0.0 || vec.is_empty() {
        return;
    }
    // Standard Gaussian DP mechanism: sigma = sensitivity * sqrt(2 * ln(1.25 / delta)) / epsilon (delta = 1e-5)
    let sigma = (sensitivity * 4.845) / epsilon;

    let mut seed_bytes = [0u8; 8];
    for chunk in vec.chunks_mut(2) {
        let _ = getrandom::getrandom(&mut seed_bytes);
        let u1 = ((u32::from_ne_bytes([seed_bytes[0], seed_bytes[1], seed_bytes[2], seed_bytes[3]]) as f64 + 1.0) / 4294967297.0) as f32;
        let u2 = ((u32::from_ne_bytes([seed_bytes[4], seed_bytes[5], seed_bytes[6], seed_bytes[7]]) as f64 + 1.0) / 4294967297.0) as f32;

        let r = (-2.0 * u1.ln()).sqrt();
        let theta = 2.0 * std::f32::consts::PI * u2;
        let z0 = r * theta.cos() * sigma;
        let z1 = r * theta.sin() * sigma;

        chunk[0] += z0;
        if chunk.len() > 1 {
            chunk[1] += z1;
        }
    }
    l2_normalize(vec);
}

#[allow(dead_code)]
pub fn cosine_similarity(a: &[f32], b: &[f32]) -> f32 {
    if a.len() != b.len() {
        return 0.0;
    }
    a.iter().zip(b.iter()).map(|(x, y)| x * y).sum()
}

/// Tracks cumulative differential privacy budget expenditure (`epsilon` ledger) in `.agents/audit/privacy-budget.json`
pub fn record_privacy_budget_expenditure(
    repo_root: &std::path::Path,
    epsilon: f32,
    vectors_count: usize,
    operation: &str,
) -> Result<std::path::PathBuf, String> {
    let audit_dir = repo_root.join(".agents").join("audit");
    let _ = std::fs::create_dir_all(&audit_dir);
    let ledger_path = audit_dir.join("privacy-budget.json");

    let mut total_epsilon = 0.0f64;
    let mut total_vectors = 0usize;
    let mut sessions: Vec<serde_json::Value> = Vec::new();

    if ledger_path.exists() {
        if let Ok(content) = std::fs::read_to_string(&ledger_path) {
            if let Ok(val) = serde_json::from_str::<serde_json::Value>(&content) {
                total_epsilon = val.get("cumulative_epsilon").and_then(|v| v.as_f64()).unwrap_or(0.0);
                total_vectors = val.get("total_Protected_vectors").or_else(|| val.get("total_protected_vectors")).and_then(|v| v.as_u64()).unwrap_or(0) as usize;
                if let Some(arr) = val.get("expenditure_log").and_then(|a| a.as_array()) {
                    sessions = arr.clone();
                }
            }
        }
    }

    // Composition theorem: track session epsilon expenditure
    let session_eps = epsilon as f64;
    total_epsilon += session_eps;
    total_vectors += vectors_count;

    sessions.push(serde_json::json!({
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "operation": operation,
        "session_epsilon": session_eps,
        "vectors_perturbed": vectors_count,
        "cumulative_epsilon": (total_epsilon * 10000.0).round() / 10000.0,
    }));
    if sessions.len() > 100 {
        let drain_count = sessions.len() - 100;
        sessions.drain(0..drain_count);
    }

    let doc = serde_json::json!({
        "format": "ainish-rag/privacy-budget-ledger/v1",
        "mechanism": "Gaussian-DP-L2",
        "delta": 1e-5,
        "sensitivity": 0.05,
        "cumulative_epsilon": (total_epsilon * 10000.0).round() / 10000.0,
        "total_protected_vectors": total_vectors,
        "updated_at": chrono::Utc::now().to_rfc3339(),
        "expenditure_log": sessions,
    });

    std::fs::write(&ledger_path, serde_json::to_string_pretty(&doc).unwrap_or_default())
        .map_err(|e| format!("Failed writing privacy budget ledger: {}", e))?;
    Ok(ledger_path)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dp_noise_injection_preserves_l2_norm() {
        let mut vec = vec![0.577, 0.577, 0.577];
        l2_normalize(&mut vec);
        let original = vec.clone();

        apply_differential_privacy_noise(&mut vec, 1.0, 0.05);

        // Vector should have changed due to noise
        assert_ne!(vec, original);
        // Norm should remain approximately 1.0
        let norm_sq: f32 = vec.iter().map(|x| x * x).sum();
        assert!((norm_sq.sqrt() - 1.0).abs() < 1e-4);
    }

    #[test]
    fn test_adaptive_batch_scaling() {
        let client = EmbedClient::new("http://127.0.0.1:8080", None, None);
        assert_eq!(client.recommended_batch_size(), 16);
        // Fast loopback response (<120ms) scales batch size up
        assert_eq!(client.record_rtt_and_scale_batch(45), 32);
        assert_eq!(client.record_rtt_and_scale_batch(80), 64);
        // Heavy load (>600ms) scales batch size down
        assert_eq!(client.record_rtt_and_scale_batch(750), 32);
        assert_eq!(client.record_rtt_and_scale_batch(900), 16);
    }
}
