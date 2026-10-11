use std::path::{Path, PathBuf};
use std::fs;
use walkdir::WalkDir;
use regex::Regex;
use sha2::{Sha256, Digest};
use chrono::Utc;
use crate::store::RagChunk;

pub struct CodebaseIngestor {
    repo_name: String,
    repo_root: PathBuf,
}

impl CodebaseIngestor {
    pub fn new(repo_root: &Path) -> Self {
        let repo_name = repo_root
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("repo")
            .to_string();

        Self {
            repo_name,
            repo_root: repo_root.to_path_buf(),
        }
    }

    pub fn scan_files(&self, target_dir: &Path) -> Vec<PathBuf> {
        let mut files = Vec::new();

        for entry in WalkDir::new(target_dir).follow_links(false).into_iter().flatten() {
            if !entry.file_type().is_file() {
                continue;
            }

            let path = entry.path();
            if is_ignored_path(path) {
                continue;
            }

            files.push(path.to_path_buf());
        }

        files
    }

    pub fn chunk_file(&self, file_path: &Path) -> Vec<UnembeddedChunk> {
        let rel_path = file_path
            .strip_prefix(&self.repo_root)
            .unwrap_or(file_path)
            .to_string_lossy()
            .replace('\\', "/");

        let ext = file_path.extension().and_then(|e| e.to_str()).unwrap_or("").to_lowercase();

        // Categorize file
        if is_code_ext(&ext) {
            self.chunk_code_file(file_path, &rel_path, &ext)
        } else if is_doc_ext(&ext) {
            self.chunk_doc_file(file_path, &rel_path)
        } else if is_image_ext(&ext) {
            self.chunk_image_file(file_path, &rel_path, &ext)
        } else if is_audio_ext(&ext) {
            self.chunk_audio_file(file_path, &rel_path, &ext)
        } else if is_video_ext(&ext) {
            self.chunk_video_file(file_path, &rel_path, &ext)
        } else {
            Vec::new()
        }
    }

    fn chunk_code_file(&self, path: &Path, rel_path: &str, ext: &str) -> Vec<UnembeddedChunk> {
        let content = match fs::read_to_string(path) {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };

        if content.trim().is_empty() {
            return Vec::new();
        }

        let lines: Vec<&str> = content.lines().collect();
        let symbols = extract_symbols(&lines, ext);
        let symbols_json = serde_json::to_string(&symbols).unwrap_or_else(|_| "[]".to_string());

        let mut chunks = Vec::new();
        let chunk_size = 60;
        let overlap = 10;
        let mut i = 0;

        while i < lines.len() {
            let end = (i + chunk_size).min(lines.len());
            let chunk_lines = &lines[i..end];
            let chunk_content = chunk_lines.join("\n");

            if !chunk_content.trim().is_empty() {
                let start_line = (i + 1) as i32;
                let end_line = end as i32;
                let title = format!("{}:L{}-L{}", rel_path, start_line, end_line);
                let id = hash_id(rel_path, start_line, end_line);

                chunks.push(UnembeddedChunk {
                    id,
                    repo: self.repo_name.clone(),
                    path: rel_path.to_string(),
                    doc_type: "code".to_string(),
                    modality: "code".to_string(),
                    title,
                    content: chunk_content,
                    symbols: symbols_json.clone(),
                    start_line,
                    end_line,
                });
            }

            if end == lines.len() {
                break;
            }
            i += chunk_size - overlap;
        }

        chunks
    }

    fn chunk_doc_file(&self, path: &Path, rel_path: &str) -> Vec<UnembeddedChunk> {
        let content = match fs::read_to_string(path) {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };

        if content.trim().is_empty() {
            return Vec::new();
        }

        let doc_type = if rel_path.contains("wiki") { "wiki" } else { "doc" };
        let mut chunks = Vec::new();
        let sections = split_markdown_sections(&content);

        for (sec_title, sec_content, start_l, end_l) in sections {
            let title = format!("{} > {}", rel_path, sec_title);
            let id = hash_id(rel_path, start_l, end_l);

            chunks.push(UnembeddedChunk {
                id,
                repo: self.repo_name.clone(),
                path: rel_path.to_string(),
                doc_type: doc_type.to_string(),
                modality: "text".to_string(),
                title,
                content: sec_content,
                symbols: "[]".to_string(),
                start_line: start_l,
                end_line: end_l,
            });
        }

        chunks
    }

    fn chunk_image_file(&self, path: &Path, rel_path: &str, ext: &str) -> Vec<UnembeddedChunk> {
        let size_bytes = fs::metadata(path).map(|m| m.len()).unwrap_or(0);
        let id = hash_id(rel_path, 1, 1);
        let caption = format!("Image asset ({}) size: {} bytes, format: {}", rel_path, size_bytes, ext);

        vec![UnembeddedChunk {
            id,
            repo: self.repo_name.clone(),
            path: rel_path.to_string(),
            doc_type: "image".to_string(),
            modality: "image".to_string(),
            title: format!("Image: {}", rel_path),
            content: caption,
            symbols: "[]".to_string(),
            start_line: 1,
            end_line: 1,
        }]
    }

    fn chunk_audio_file(&self, path: &Path, rel_path: &str, _ext: &str) -> Vec<UnembeddedChunk> {
        let size_bytes = fs::metadata(path).map(|m| m.len()).unwrap_or(0);
        let id = hash_id(rel_path, 1, 1);
        let desc = format!("Audio asset ({}) size: {} bytes, format: <|audio|>", rel_path, size_bytes);

        vec![UnembeddedChunk {
            id,
            repo: self.repo_name.clone(),
            path: rel_path.to_string(),
            doc_type: "audio".to_string(),
            modality: "audio".to_string(),
            title: format!("Audio: {}", rel_path),
            content: desc,
            symbols: "[]".to_string(),
            start_line: 1,
            end_line: 1,
        }]
    }

    fn chunk_video_file(&self, path: &Path, rel_path: &str, _ext: &str) -> Vec<UnembeddedChunk> {
        let size_bytes = fs::metadata(path).map(|m| m.len()).unwrap_or(0);
        let id = hash_id(rel_path, 1, 1);
        let desc = format!("Video recording/clip ({}) size: {} bytes, format: <|video|>", rel_path, size_bytes);

        vec![UnembeddedChunk {
            id,
            repo: self.repo_name.clone(),
            path: rel_path.to_string(),
            doc_type: "video".to_string(),
            modality: "video".to_string(),
            title: format!("Video: {}", rel_path),
            content: desc,
            symbols: "[]".to_string(),
            start_line: 1,
            end_line: 1,
        }]
    }
}

#[derive(Clone, Debug)]
pub struct UnembeddedChunk {
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
}

impl UnembeddedChunk {
    pub fn to_rag_chunk(self, vector: Vec<f32>) -> RagChunk {
        RagChunk {
            id: self.id,
            repo: self.repo,
            path: self.path,
            doc_type: self.doc_type,
            modality: self.modality,
            title: self.title,
            content: self.content,
            symbols: self.symbols,
            start_line: self.start_line,
            end_line: self.end_line,
            vector,
            updated_at: Utc::now().to_rfc3339(),
        }
    }
}

pub fn is_ignored_path(path: &Path) -> bool {
    let s = path.to_string_lossy();
    s.contains("/.git/") || s.contains("\\.git\\")
        || s.contains("/node_modules/") || s.contains("\\node_modules\\")
        || s.contains("/target/") || s.contains("\\target\\")
        || s.contains("/.venv/") || s.contains("\\.venv\\")
        || s.contains("/__pycache__/") || s.contains("\\__pycache__\\")
        || s.contains("/.agents/rag/lancedb/") || s.contains("\\.agents\\rag\\lancedb\\")
        || s.contains("/.scrolls") || s.contains("\\.scrolls")
        || s.ends_with(".lock") || s.ends_with(".tmp") || s.ends_with(".log")
}

fn is_code_ext(ext: &str) -> bool {
    matches!(
        ext,
        "rs" | "py" | "ts" | "js" | "tsx" | "jsx" | "go" | "sh" | "bash"
        | "ps1" | "c" | "cpp" | "h" | "hpp" | "toml" | "json" | "yaml" | "yml" | "html" | "css"
    )
}

fn is_doc_ext(ext: &str) -> bool {
    matches!(ext, "md" | "txt" | "markdown" | "rst" | "org")
}

fn is_image_ext(ext: &str) -> bool {
    matches!(ext, "png" | "jpg" | "jpeg" | "svg" | "webp" | "gif" | "bmp")
}

fn is_audio_ext(ext: &str) -> bool {
    matches!(ext, "mp3" | "wav" | "ogg" | "flac" | "m4a")
}

fn is_video_ext(ext: &str) -> bool {
    matches!(ext, "mp4" | "mkv" | "webm" | "mov" | "avi")
}

fn extract_symbols(lines: &[&str], ext: &str) -> Vec<String> {
    let mut symbols = Vec::new();
    let pattern = match ext {
        "rs" => r"(?:pub\s+)?(?:fn|struct|enum|trait|type|const)\s+([A-Za-z0-9_]+)",
        "py" => r"(?:def|class)\s+([A-Za-z0-9_]+)",
        "ts" | "tsx" | "js" | "jsx" => r"(?:export\s+)?(?:function|class|interface|type|const)\s+([A-Za-z0-9_]+)",
        "go" => r"func\s+(?:\([^\)]+\)\s+)?([A-Za-z0-9_]+)",
        _ => return Vec::new(),
    };

    if let Ok(re) = Regex::new(pattern) {
        for line in lines {
            if let Some(cap) = re.captures(line) {
                if let Some(m) = cap.get(1) {
                    let sym = m.as_str().to_string();
                    if !symbols.contains(&sym) {
                        symbols.push(sym);
                    }
                }
            }
        }
    }

    symbols
}

fn split_markdown_sections(content: &str) -> Vec<(String, String, i32, i32)> {
    let mut sections = Vec::new();
    let lines: Vec<&str> = content.lines().collect();
    let mut current_title = "Overview".to_string();
    let mut current_lines = Vec::new();
    let mut start_line = 1;

    for (idx, line) in lines.iter().enumerate() {
        if line.starts_with("# ") || line.starts_with("## ") || line.starts_with("### ") {
            if !current_lines.is_empty() {
                sections.push((
                    current_title.clone(),
                    current_lines.join("\n"),
                    start_line,
                    idx as i32,
                ));
                current_lines.clear();
            }
            current_title = line.trim_start_matches('#').trim().to_string();
            start_line = (idx + 1) as i32;
        }
        current_lines.push(*line);
    }

    if !current_lines.is_empty() {
        sections.push((
            current_title,
            current_lines.join("\n"),
            start_line,
            lines.len() as i32,
        ));
    }

    sections
}

fn hash_id(path: &str, start_l: i32, end_l: i32) -> String {
    let mut hasher = Sha256::new();
    hasher.update(path.as_bytes());
    hasher.update(start_l.to_string().as_bytes());
    hasher.update(end_l.to_string().as_bytes());
    let res = hasher.finalize();
    hex::encode(&res[..8])
}


