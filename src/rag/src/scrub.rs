//! Content redaction and privacy-budget accounting.
//!
//! These two lived in `ingest.rs` and `embed.rs`, which were deleted with the vector subsystem on
//! 2026-11-12. They are not vector machinery and must not have gone with it:
//!
//!   * `scrub_sensitive_content` is a security control. It redacts credentials and PII from text
//!     before that text reaches any model, any log, or any generated artifact. Losing it would be a
//!     silent downgrade of a control the contract promises.
//!   * `read_or_init_privacy_budget` records differential-privacy expenditure in a signed ledger.
//!     The vectors it once counted are gone, but the ledger is still the audit trail for privacy
//!     budget, and other code reports on it.
//!
//! Everything else in those modules (chunking, embedding, store access) was the retired path and is
//! gone with it.

use regex::Regex;
use std::sync::LazyLock;

static RE_PRIVATE_KEY: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z0-9 ]*PRIVATE KEY-----")
        .expect("valid regex")
});
static RE_KV_SECRET: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)(api[_-]?key|secret|password|passwd|token|bearer|auth|private[_-]?key)(\s*[:=]\s*)(["']?)([^\s#"',;]{4,})"#)
        .expect("valid regex")
});
static RE_TOKENS: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(concat!(
        r"(?:sk-(?:or-|proj-|ant-)?[A-Za-z0-9_-]{20,}",
        r"|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}",
        r"|(?:AKIA|ASIA)[0-9A-Z]{16}",
        r"|AIza[0-9A-Za-z_-]{35}",
        r"|xox[abprs]-[A-Za-z0-9-]{10,}",
        r"|glpat-[A-Za-z0-9_-]{20}",
        r"|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,})"
    ))
    .expect("valid regex")
});
static RE_EMAIL: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}\b")
        .expect("valid regex")
});
static RE_SSN: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\b\d{3}-\d{2}-\d{4}\b").expect("valid regex"));
static RE_PHONE: LazyLock<Regex> = LazyLock::new(|| {
    // Requires separators so bare numeric literals in code are not matched.
    Regex::new(r"(?:\+\d{1,3}[ .-])?\(?\b\d{3}\)?[ .-]\d{3}[ .-]\d{4}\b").expect("valid regex")
});
static RE_CARD: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\b\d(?:[ -]?\d){12,18}\b").expect("valid regex"));

fn luhn_valid(digits: &str) -> bool {
    let ds: Vec<u32> = digits.chars().filter_map(|c| c.to_digit(10)).collect();
    if ds.len() < 13 || ds.len() > 19 {
        return false;
    }
    let sum: u32 = ds
        .iter()
        .rev()
        .enumerate()
        .map(|(i, &d)| {
            if i % 2 == 1 {
                let x = d * 2;
                if x > 9 { x - 9 } else { x }
            } else {
                d
            }
        })
        .sum();
    sum % 10 == 0
}

/// Removes credentials (key/value secrets, vendor token formats, PEM private keys) and PII
/// (emails, SSNs, separator-formatted phone numbers, Luhn-valid payment card numbers).
///
/// Applied to any text that leaves the process or lands in a generated artifact.
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
        if luhn_valid(m) {
            "[REDACTED:CARD]".to_string()
        } else {
            m.to_string()
        }
    });
    let s = RE_PHONE.replace_all(&s, "[REDACTED:PHONE]");
    s.into_owned()
}

/// Paths that are never source: VCS internals, dependency and build output, tool caches, and
/// generated coordination state. Used by the wiki generator to decide what is a repository file.
pub fn is_ignored_path(path: &std::path::Path) -> bool {
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

/// Reads or initializes `.agents/audit/privacy-budget.json` (and signs it with ML-DSA-65).
pub fn read_or_init_privacy_budget(
    repo_root: &std::path::Path,
    reset: bool,
) -> Result<serde_json::Value, String> {
    let audit_dir = repo_root.join(".agents").join("audit");
    let _ = std::fs::create_dir_all(&audit_dir);
    let ledger_path = audit_dir.join("privacy-budget.json");

    if !reset && ledger_path.exists() {
        if let Ok(content) = std::fs::read_to_string(&ledger_path) {
            if let Ok(val) = serde_json::from_str::<serde_json::Value>(&content) {
                return Ok(val);
            }
        }
    }

    let doc = serde_json::json!({
        "format": "ainish-rag/privacy-budget-ledger/v1",
        "mechanism": "Gaussian-DP-L2",
        "delta": 1e-5,
        "sensitivity": 0.05,
        "cumulative_epsilon": 0.0,
        "total_protected_vectors": 0,
        "updated_at": chrono::Utc::now().to_rfc3339(),
        "expenditure_log": [],
    });
    std::fs::write(&ledger_path, serde_json::to_string_pretty(&doc).unwrap_or_default())
        .map_err(|e| format!("Failed writing privacy budget ledger: {}", e))?;
    let _ = crate::pqc::sign_file(&ledger_path);
    Ok(doc)
}

#[cfg(test)]
mod tests {
    use super::scrub_sensitive_content as scrub;

    #[test]
    fn redacts_pii_and_credentials() {
        let input = "contact jane.doe@example.org or 555-867-5309; ssn 123-45-6789; card 4111 1111 1111 1111\n\
                     api_key = \"abcd1234efgh\"\nAKIAIOSFODNN7EXAMPLE ghp_abcdefghijklmnopqrstuvwxyz0123\n\
                     -----BEGIN PRIVATE KEY-----\nMIIBVQ\n-----END PRIVATE KEY-----";
        let out = scrub(input);
        for leaked in [
            "jane.doe@example.org",
            "867-5309",
            "123-45-6789",
            "4111 1111",
            "abcd1234efgh",
            "AKIAIOSFODNN7EXAMPLE",
            "ghp_abcdef",
            "MIIBVQ",
        ] {
            assert!(!out.contains(leaked), "leaked {leaked}: {out}");
        }
        assert!(
            out.contains("[REDACTED:EMAIL]")
                && out.contains("[REDACTED:CARD]")
                && out.contains("[REDACTED:PRIVATE_KEY]")
        );
    }

    #[test]
    fn preserves_ordinary_code() {
        let code = "let total = 1234567890123; // not luhn\nfn add(a: i32) -> i32 { a + 42 }\nversion = \"1.2.3\"";
        assert_eq!(scrub(code), code);
    }
}
