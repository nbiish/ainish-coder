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
    pub anonymize_symbols: bool,
    pub symbol_salt: Option<String>,
}

impl CodebaseIngestor {
    pub fn new(repo_root: &Path) -> Self {
        Self::new_with_options(repo_root, false, None)
    }

    pub fn new_with_options(repo_root: &Path, anonymize_symbols: bool, symbol_salt: Option<String>) -> Self {
        let repo_name = repo_root
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("repo")
            .to_string();

        Self {
            repo_name,
            repo_root: repo_root.to_path_buf(),
            anonymize_symbols,
            symbol_salt,
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
        let rel_path = match file_path.strip_prefix(&self.repo_root) {
            Ok(p) => p.to_string_lossy().replace('\\', "/"),
            Err(_) => {
                let s = file_path.to_string_lossy().replace('\\', "/");
                if let Some(pos) = s.rfind("/src/") {
                    s[pos + 1..].to_string()
                } else if let Some(pos) = s.rfind("/.agents/") {
                    s[pos + 1..].to_string()
                } else {
                    file_path.file_name().and_then(|n| n.to_str()).unwrap_or("unknown").to_string()
                }
            }
        };
        let rel_path = rel_path.trim_start_matches('/').to_string();

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
        let raw_content = match fs::read_to_string(path) {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        let content = scrub_sensitive_content(&raw_content);

        if content.trim().is_empty() {
            return Vec::new();
        }

        let raw_lines: Vec<&str> = content.lines().collect();
        let extracted_symbols = extract_symbols(&raw_lines, ext);

        let (final_content, final_symbols) = if self.anonymize_symbols && !extracted_symbols.is_empty() {
            anonymize_content_and_symbols(&content, &extracted_symbols, self.symbol_salt.as_deref())
        } else {
            (content, extracted_symbols)
        };
        let symbols_json = serde_json::to_string(&final_symbols).unwrap_or_else(|_| "[]".to_string());

        let lines: Vec<&str> = final_content.lines().collect();
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
        let raw_content = match fs::read_to_string(path) {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        let content = scrub_sensitive_content(&raw_content);

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
        || s.contains("/.agents/rag/") || s.contains("\\.agents\\rag\\")
        || s.contains("/.scrolls") || s.contains("\\.scrolls")
        || s.ends_with(".lock") || s.ends_with(".tmp") || s.ends_with(".log") || s.ends_with(".sig")
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

static RE_PRIVATE_KEY: std::sync::LazyLock<Regex> = std::sync::LazyLock::new(|| {
    Regex::new(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z0-9 ]*PRIVATE KEY-----").expect("valid regex")
});
static RE_KV_SECRET: std::sync::LazyLock<Regex> = std::sync::LazyLock::new(|| {
    Regex::new(r#"(?i)(api[_-]?key|secret|password|passwd|token|bearer|auth|private[_-]?key)(\s*[:=]\s*)(["']?)([^\s#"',;]{4,})"#).expect("valid regex")
});
static RE_TOKENS: std::sync::LazyLock<Regex> = std::sync::LazyLock::new(|| {
    Regex::new(concat!(
        r"(?:sk-(?:or-|proj-|ant-)?[A-Za-z0-9_-]{20,}",
        r"|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}",
        r"|(?:AKIA|ASIA)[0-9A-Z]{16}",
        r"|AIza[0-9A-Za-z_-]{35}",
        r"|xox[abprs]-[A-Za-z0-9-]{10,}",
        r"|glpat-[A-Za-z0-9_-]{20}",
        r"|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,})"
    )).expect("valid regex")
});
static RE_EMAIL: std::sync::LazyLock<Regex> = std::sync::LazyLock::new(|| {
    Regex::new(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}\b").expect("valid regex")
});
static RE_SSN: std::sync::LazyLock<Regex> = std::sync::LazyLock::new(|| {
    Regex::new(r"\b\d{3}-\d{2}-\d{4}\b").expect("valid regex")
});
static RE_PHONE: std::sync::LazyLock<Regex> = std::sync::LazyLock::new(|| {
    // Requires separators so bare numeric literals in code are not matched.
    Regex::new(r"(?:\+\d{1,3}[ .-])?\(?\b\d{3}\)?[ .-]\d{3}[ .-]\d{4}\b").expect("valid regex")
});
static RE_CARD: std::sync::LazyLock<Regex> = std::sync::LazyLock::new(|| {
    Regex::new(r"\b\d(?:[ -]?\d){12,18}\b").expect("valid regex")
});

fn luhn_valid(digits: &str) -> bool {
    let ds: Vec<u32> = digits.chars().filter_map(|c| c.to_digit(10)).collect();
    if ds.len() < 13 || ds.len() > 19 {
        return false;
    }
    let sum: u32 = ds.iter().rev().enumerate().map(|(i, &d)| {
        if i % 2 == 1 { let x = d * 2; if x > 9 { x - 9 } else { x } } else { d }
    }).sum();
    sum % 10 == 0
}

/// Client-side redaction applied to every chunk before it reaches the embedding server or LanceDB.
/// Removes credentials (key/value secrets, vendor token formats, PEM private keys) and PII
/// (emails, SSNs, separator-formatted phone numbers, Luhn-valid payment card numbers).
pub fn scrub_sensitive_content(text: &str) -> String {
    let s = RE_PRIVATE_KEY.replace_all(text, "[REDACTED:PRIVATE_KEY]");
    let s = RE_TOKENS.replace_all(&s, "[REDACTED:TOKEN]");
    let s = RE_KV_SECRET.replace_all(&s, |caps: &regex::Captures| {
        if !caps[3].is_empty() || caps[4].len() >= 16 {
            format!("{}{}{}[REDACTED]", &caps[1], &caps[2], &caps[3])
        } else {
            caps[0].to_string()
        }
    });
    let s = RE_EMAIL.replace_all(&s, "[REDACTED:EMAIL]");
    let s = RE_SSN.replace_all(&s, "[REDACTED:SSN]");
    let s = RE_CARD.replace_all(&s, |caps: &regex::Captures| {
        let m = &caps[0];
        if luhn_valid(m) { "[REDACTED:CARD]".to_string() } else { m.to_string() }
    });
    let s = RE_PHONE.replace_all(&s, "[REDACTED:PHONE]");
    s.into_owned()
}

#[cfg(test)]
mod redaction_tests {
    use super::scrub_sensitive_content as scrub;

    #[test]
    fn redacts_pii_and_credentials() {
        let input = "contact jane.doe@example.org or 555-867-5309; ssn 123-45-6789; card 4111 1111 1111 1111\n\
                     api_key = \"abcd1234efgh\"\nAKIAIOSFODNN7EXAMPLE ghp_abcdefghijklmnopqrstuvwxyz0123\n\
                     -----BEGIN PRIVATE KEY-----\nMIIBVQ\n-----END PRIVATE KEY-----";
        let out = scrub(input);
        for leaked in ["jane.doe@example.org", "867-5309", "123-45-6789", "4111 1111", "abcd1234efgh", "AKIAIOSFODNN7EXAMPLE", "ghp_abcdef", "MIIBVQ"] {
            assert!(!out.contains(leaked), "leaked {leaked}: {out}");
        }
        assert!(out.contains("[REDACTED:EMAIL]") && out.contains("[REDACTED:CARD]") && out.contains("[REDACTED:PRIVATE_KEY]"));
    }

    #[test]
    fn preserves_ordinary_code() {
        let code = "let total = 1234567890123; // not luhn\nfn add(a: i32) -> i32 { a + 42 }\nversion = \"1.2.3\"";
        assert_eq!(scrub(code), code);
    }
}

pub fn anonymize_content_and_symbols(content: &str, symbols: &[String], salt: Option<&str>) -> (String, Vec<String>) {
    let mut replaced_content = content.to_string();
    let mut anon_symbols = Vec::new();
    for sym in symbols {
        let mut hasher = Sha256::new();
        if let Some(s) = salt {
            hasher.update(s.as_bytes());
            hasher.update(b":");
        }
        hasher.update(sym.as_bytes());
        let anon = format!("sym_{}", &hex::encode(hasher.finalize())[..8]);
        anon_symbols.push(anon.clone());
        let pattern = format!(r"\b{}\b", regex::escape(sym));
        if let Ok(re) = Regex::new(&pattern) {
            replaced_content = re.replace_all(&replaced_content, anon.as_str()).to_string();
        }
    }
    (replaced_content, anon_symbols)
}

