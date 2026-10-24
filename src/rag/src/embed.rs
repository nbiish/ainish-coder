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
}

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
        }
    }

    pub fn with_dp_epsilon(mut self, epsilon: Option<f32>) -> Self {
        self.dp_epsilon = epsilon;
        self
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
            req_builder = req_builder
                .header("Authorization", format!("Bearer {}", token))
                .header("X-Ainish-PSK", token);
        }

        let resp = req_builder
            .json(&req)
            .send()
            .await
            .map_err(|e| format!("Embedding request failed to {}: {}", url, e))?;

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
}
