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
}

impl EmbedClient {
    pub fn new(server_url: &str, truncate_dim: Option<usize>) -> Self {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(60))
            .build()
            .unwrap_or_default();

        Self {
            client,
            server_url: server_url.trim_end_matches('/').to_string(),
            truncate_dim,
        }
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
        format!("title: {} | text: {}", t, content.trim())
    }

    /// Format multimodal entry with image placeholder
    pub fn format_multimodal_image(title: Option<&str>, caption: &str) -> String {
        let t = title.unwrap_or("image");
        format!("title: {} | text: <|image|> {}", t, caption.trim())
    }

    /// Embed a batch of formatted input strings
    pub async fn embed_batch(&self, inputs: &[String]) -> Result<Vec<Vec<f32>>, String> {
        if inputs.is_empty() {
            return Ok(Vec::new());
        }

        let url = format!("{}/v1/embeddings", self.server_url);
        let req = EmbeddingRequest {
            model: "embeddinggemma2".to_string(),
            input: inputs.to_vec(),
            encoding_format: "float".to_string(),
        };

        let resp = self.client.post(&url)
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

#[allow(dead_code)]
pub fn cosine_similarity(a: &[f32], b: &[f32]) -> f32 {
    if a.len() != b.len() {
        return 0.0;
    }
    a.iter().zip(b.iter()).map(|(x, y)| x * y).sum()
}
