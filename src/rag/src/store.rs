use lancedb::connect;
use lancedb::query::{ExecutableQuery, QueryBase};
use arrow_schema::{Schema, Field, DataType};
use arrow_array::{
    RecordBatch, StringArray, Int32Array, Float32Array, FixedSizeListArray,
    RecordBatchIterator, ArrayRef,
};
use arrow_array::cast::AsArray;
use futures::StreamExt;
use std::sync::Arc;
use std::path::Path;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RagChunk {
    pub id: String,
    pub repo: String,
    pub path: String,
    pub doc_type: String,
    pub modality: String,
    pub title: String,
    pub content: String,
    pub symbols: String,
    pub start_line: i32,
    pub end_line: i32,
    pub vector: Vec<f32>,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchHit {
    pub id: String,
    pub repo: String,
    pub path: String,
    pub doc_type: String,
    pub modality: String,
    pub title: String,
    pub content: String,
    pub symbols: String,
    pub start_line: i32,
    pub end_line: i32,
    pub score: f32,
}

pub struct LanceStore {
    db_uri: String,
    embedding_dim: i32,
}

impl LanceStore {
    pub fn new(lancedb_dir: &Path, embedding_dim: usize) -> Self {
        Self {
            db_uri: lancedb_dir.to_string_lossy().to_string(),
            embedding_dim: embedding_dim as i32,
        }
    }

    fn schema(&self) -> Arc<Schema> {
        Arc::new(Schema::new(vec![
            Field::new("id", DataType::Utf8, false),
            Field::new("repo", DataType::Utf8, false),
            Field::new("path", DataType::Utf8, false),
            Field::new("doc_type", DataType::Utf8, false),
            Field::new("modality", DataType::Utf8, false),
            Field::new("title", DataType::Utf8, false),
            Field::new("content", DataType::Utf8, false),
            Field::new("symbols", DataType::Utf8, false),
            Field::new("start_line", DataType::Int32, false),
            Field::new("end_line", DataType::Int32, false),
            Field::new(
                "vector",
                DataType::FixedSizeList(
                    Arc::new(Field::new("item", DataType::Float32, true)),
                    self.embedding_dim,
                ),
                false,
            ),
            Field::new("updated_at", DataType::Utf8, false),
        ]))
    }

    fn chunks_to_batch(&self, chunks: &[RagChunk]) -> Result<RecordBatch, String> {
        let n = chunks.len();
        let mut ids = Vec::with_capacity(n);
        let mut repos = Vec::with_capacity(n);
        let mut paths = Vec::with_capacity(n);
        let mut doc_types = Vec::with_capacity(n);
        let mut modalities = Vec::with_capacity(n);
        let mut titles = Vec::with_capacity(n);
        let mut contents = Vec::with_capacity(n);
        let mut symbols = Vec::with_capacity(n);
        let mut start_lines = Vec::with_capacity(n);
        let mut end_lines = Vec::with_capacity(n);
        let mut updated_ats = Vec::with_capacity(n);
        let mut flat_vectors = Vec::with_capacity(n * (self.embedding_dim as usize));

        for c in chunks {
            ids.push(c.id.as_str());
            repos.push(c.repo.as_str());
            paths.push(c.path.as_str());
            doc_types.push(c.doc_type.as_str());
            modalities.push(c.modality.as_str());
            titles.push(c.title.as_str());
            contents.push(c.content.as_str());
            symbols.push(c.symbols.as_str());
            start_lines.push(c.start_line);
            end_lines.push(c.end_line);
            updated_ats.push(c.updated_at.as_str());

            if c.vector.len() == (self.embedding_dim as usize) {
                flat_vectors.extend_from_slice(&c.vector);
            } else {
                let mut v = c.vector.clone();
                v.resize(self.embedding_dim as usize, 0.0);
                flat_vectors.extend_from_slice(&v);
            }
        }

        let vector_values = Arc::new(Float32Array::from(flat_vectors));
        let vectors = FixedSizeListArray::try_new(
            Arc::new(Field::new("item", DataType::Float32, true)),
            self.embedding_dim,
            vector_values,
            None,
        ).map_err(|e| format!("Failed to build vector array: {}", e))?;

        let columns: Vec<ArrayRef> = vec![
            Arc::new(StringArray::from(ids)),
            Arc::new(StringArray::from(repos)),
            Arc::new(StringArray::from(paths)),
            Arc::new(StringArray::from(doc_types)),
            Arc::new(StringArray::from(modalities)),
            Arc::new(StringArray::from(titles)),
            Arc::new(StringArray::from(contents)),
            Arc::new(StringArray::from(symbols)),
            Arc::new(Int32Array::from(start_lines)),
            Arc::new(Int32Array::from(end_lines)),
            Arc::new(vectors),
            Arc::new(StringArray::from(updated_ats)),
        ];

        RecordBatch::try_new(self.schema(), columns)
            .map_err(|e| format!("Failed to build RecordBatch: {}", e))
    }

    pub async fn upsert(&self, chunks: &[RagChunk]) -> Result<usize, String> {
        if chunks.is_empty() {
            return Ok(0);
        }

        let db = connect(&self.db_uri)
            .execute()
            .await
            .map_err(|e| format!("Failed to connect to LanceDB at {}: {}", self.db_uri, e))?;

        let schema = self.schema();
        let batch = self.chunks_to_batch(chunks)?;
        let reader = RecordBatchIterator::new(vec![Ok(batch)], schema.clone());

        let table_name = "codebase_rag";
        let table_names = db.table_names().execute().await.map_err(|e| e.to_string())?;

        if table_names.iter().any(|t| t == table_name) {
            let table = db.open_table(table_name).execute().await.map_err(|e| e.to_string())?;
            table.add(Box::new(reader)).execute().await.map_err(|e| e.to_string())?;
        } else {
            db.create_table(table_name, Box::new(reader)).execute().await.map_err(|e| e.to_string())?;
        }

        Ok(chunks.len())
    }

    pub async fn search_vector(&self, query_vec: &[f32], limit: usize, type_filter: Option<&str>) -> Result<Vec<SearchHit>, String> {
        let db = connect(&self.db_uri)
            .execute()
            .await
            .map_err(|e| format!("Failed to connect to LanceDB at {}: {}", self.db_uri, e))?;

        let table_name = "codebase_rag";
        let table = match db.open_table(table_name).execute().await {
            Ok(t) => t,
            Err(_) => return Ok(Vec::new()),
        };

        let mut query = table.vector_search(query_vec.to_vec())
            .map_err(|e| format!("Vector search query error: {}", e))?;

        if let Some(f) = type_filter {
            let filter_str = format!("doc_type = '{}'", f);
            query = query.only_if(filter_str);
        }

        let mut stream = query.limit(limit)
            .execute()
            .await
            .map_err(|e| format!("Failed to execute vector search: {}", e))?;

        let mut hits = Vec::new();

        while let Some(batch_res) = stream.next().await {
            let batch = batch_res.map_err(|e| format!("Error reading search batch: {}", e))?;
            let ids = batch.column_by_name("id").and_then(|c| c.as_string_opt::<i32>());
            let repos = batch.column_by_name("repo").and_then(|c| c.as_string_opt::<i32>());
            let paths = batch.column_by_name("path").and_then(|c| c.as_string_opt::<i32>());
            let doc_types = batch.column_by_name("doc_type").and_then(|c| c.as_string_opt::<i32>());
            let modalities = batch.column_by_name("modality").and_then(|c| c.as_string_opt::<i32>());
            let titles = batch.column_by_name("title").and_then(|c| c.as_string_opt::<i32>());
            let contents = batch.column_by_name("content").and_then(|c| c.as_string_opt::<i32>());
            let symbols = batch.column_by_name("symbols").and_then(|c| c.as_string_opt::<i32>());
            let start_lines = batch.column_by_name("start_line").and_then(|c| c.as_primitive_opt::<arrow_array::types::Int32Type>());
            let end_lines = batch.column_by_name("end_line").and_then(|c| c.as_primitive_opt::<arrow_array::types::Int32Type>());
            let distances = batch.column_by_name("_distance").and_then(|c| c.as_primitive_opt::<arrow_array::types::Float32Type>());

            let row_count = batch.num_rows();
            for i in 0..row_count {
                let id = ids.map(|a| a.value(i).to_string()).unwrap_or_default();
                let repo = repos.map(|a| a.value(i).to_string()).unwrap_or_default();
                let path = paths.map(|a| a.value(i).to_string()).unwrap_or_default();
                let doc_type = doc_types.map(|a| a.value(i).to_string()).unwrap_or_default();
                let modality = modalities.map(|a| a.value(i).to_string()).unwrap_or_default();
                let title = titles.map(|a| a.value(i).to_string()).unwrap_or_default();
                let content = contents.map(|a| a.value(i).to_string()).unwrap_or_default();
                let sym = symbols.map(|a| a.value(i).to_string()).unwrap_or_default();
                let s_line = start_lines.map(|a| a.value(i)).unwrap_or(0);
                let e_line = end_lines.map(|a| a.value(i)).unwrap_or(0);
                let dist = distances.map(|a| a.value(i)).unwrap_or(0.0);
                // Convert distance to similarity score
                let score = 1.0 / (1.0 + dist.max(0.0));

                hits.push(SearchHit {
                    id,
                    repo,
                    path,
                    doc_type,
                    modality,
                    title,
                    content,
                    symbols: sym,
                    start_line: s_line,
                    end_line: e_line,
                    score,
                });
            }
        }

        hits.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap_or(std::cmp::Ordering::Equal));
        Ok(hits)
    }

    pub async fn count(&self) -> Result<usize, String> {
        let db = connect(&self.db_uri)
            .execute()
            .await
            .map_err(|e| format!("Failed to connect to LanceDB at {}: {}", self.db_uri, e))?;

        let table_name = "codebase_rag";
        let table = match db.open_table(table_name).execute().await {
            Ok(t) => t,
            Err(_) => return Ok(0),
        };

        table.count_rows(None).await.map_err(|e| e.to_string())
    }
}
