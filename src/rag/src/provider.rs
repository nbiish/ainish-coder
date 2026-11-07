//! PQC-aware embedding provider resolution.
//!
//! Operator intent (environment or the non-secret `.agents/rag/embed-provider.json`) decides
//! between the local llama embedding server and a remote OpenAI-compatible `/embeddings`
//! endpoint. When no explicit intent exists, the provider is auto-detected from embedding
//! credentials configured for OpenRouter or ZenMux: the process environment is consulted first,
//! then the PQC secrets store (`pqc-secrets export --json`, decrypted in memory only).
//!
//! Invariants:
//! * API key material is never written to disk and never logged — only `key_source` names leak.
//! * Auto-detection never overrides an explicit operator choice (`local` stays local).
//! * An explicit `api` intent that cannot be satisfied is reported as `invalid` so callers fail
//!   closed instead of silently spawning the local model.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::OnceLock;
use std::time::Duration;

/// Relative path of the non-secret provider configuration written by
/// `ainish-coder --embed-config` and `ainish-rag embed-provider --write`.
pub const CONFIG_REL: &str = ".agents/rag/embed-provider.json";

/// Width of the LanceDB vector store. Remote (Matryoshka) vectors wider than this are truncated
/// and renormalized before insertion so API embeddings can share the existing store schema.
pub const DEFAULT_STORE_DIM: usize = 768;

/// Canonical embedding key accepted for any provider (per the secrets naming contract).
pub const GENERIC_KEY_NAMES: &[&str] = &["AINISH_EMBED_API_KEY"];
pub const GENERIC_BASE_VARS: &[&str] = &["AINISH_EMBED_API_BASE"];
pub const GENERIC_MODEL_VARS: &[&str] = &["AINISH_EMBED_MODEL"];
pub const GENERIC_DIM_VARS: &[&str] = &["AINISH_EMBED_DIM"];

/// A remote embedding provider reachable through the OpenAI-compatible `/embeddings` shape.
pub struct ProviderSpec {
    pub id: &'static str,
    pub label: &'static str,
    pub api_base: &'static str,
    pub default_model: &'static str,
    /// Secret names, ordered by preference. Consumer prefixes (`LOCALROUTER_`, `AINISHCODER_`),
    /// the legacy plain name, and the provider slug form are all accepted.
    pub key_names: &'static [&'static str],
    pub base_vars: &'static [&'static str],
    pub model_vars: &'static [&'static str],
    pub dim_vars: &'static [&'static str],
}

pub const PROVIDERS: &[ProviderSpec] = &[
    ProviderSpec {
        id: "openrouter",
        label: "OpenRouter",
        api_base: "https://openrouter.ai/api/v1",
        default_model: "openai/text-embedding-3-small",
        key_names: &[
            "OPENROUTER_EMBED_API_KEY",
            "OPENROUTER_API_KEY",
            "LOCALROUTER_OPENROUTER_API_KEY",
            "LOCALROUTER_OPENROUTER_EMBED_API_KEY",
            "AINISHCODER_OPENROUTER_API_KEY",
            "PSIONICS_OPENROUTER_API_KEY",
            "PSIONICS_OPENROUTER_EMBED_API_KEY",
        ],
        base_vars: &["OPENROUTER_EMBED_API_BASE", "OPENROUTER_API_BASE", "OPENROUTER_BASE_URL"],
        model_vars: &["OPENROUTER_EMBED_MODEL", "OPENROUTER_EMBEDDING_MODEL"],
        dim_vars: &["OPENROUTER_EMBED_DIM"],
    },
    ProviderSpec {
        id: "zenmux",
        label: "ZenMux",
        api_base: "https://zenmux.ai/api/v1",
        default_model: "openai/text-embedding-3-small",
        key_names: &[
            "ZENMUX_EMBED_API_KEY",
            "ZENMUX_API_KEY",
            "LOCALROUTER_ZENMUX_API_KEY",
            "LOCALROUTER_ZENMUX_EMBED_API_KEY",
            "AINISHCODER_ZENMUX_API_KEY",
            "PSIONICS_ZENMUX_API_KEY",
            "PSIONICS_ZENMUX_EMBED_API_KEY",
        ],
        base_vars: &["ZENMUX_EMBED_API_BASE", "ZENMUX_API_BASE", "ZENMUX_BASE_URL"],
        model_vars: &["ZENMUX_EMBED_MODEL", "ZENMUX_EMBEDDING_MODEL"],
        dim_vars: &["ZENMUX_EMBED_DIM"],
    },
];

pub fn find_provider(id: &str) -> Option<&'static ProviderSpec> {
    let id = id.trim().to_ascii_lowercase();
    PROVIDERS.iter().find(|p| p.id == id)
}

/// Infers the provider from an API base URL (used when the operator supplied only a base).
pub fn infer_provider_id(api_base: &str) -> Option<&'static str> {
    let base = api_base.trim().to_ascii_lowercase();
    if base.contains("openrouter.ai") {
        Some("openrouter")
    } else if base.contains("zenmux.ai") {
        Some("zenmux")
    } else if base.contains(":11434") || base.contains("local-router") {
        Some("local-router")
    } else {
        None
    }
}

/// Non-secret persisted provider configuration. Never contains key material.
#[derive(Debug, Clone, Default)]
pub struct PersistedConfig {
    pub provider: String,
    pub provider_id: Option<String>,
    pub api_base: Option<String>,
    pub model: Option<String>,
    pub dim: Option<usize>,
}

/// Resolved embedding posture for the current process.
#[derive(Debug, Clone)]
pub struct Resolution {
    /// `local`, `api`, or `invalid` (explicit API intent that cannot be satisfied).
    pub provider: String,
    pub provider_id: Option<String>,
    pub api_base: Option<String>,
    pub model: Option<String>,
    pub dim: Option<usize>,
    /// Secret value held in memory only. Never serialize this field.
    pub key: Option<String>,
    /// `env:NAME` or `pqc:NAME` provenance, safe to print.
    pub key_source: Option<String>,
    /// `operator`, `operator-local`, `config`, `env-auto`, `pqc-auto`, `default-local`.
    pub source: String,
    /// True when the operator pinned the intent (env or persisted config), which suppresses
    /// auto-detection and makes an unsatisfiable API intent a hard error.
    pub explicit: bool,
    pub warnings: Vec<String>,
}

impl Resolution {
    pub fn uses_api(&self) -> bool {
        self.provider == "api" && self.api_base.is_some() && self.model.is_some()
    }

    pub fn is_invalid(&self) -> bool {
        self.provider == "invalid"
    }
}

fn env_nonempty(name: &str) -> Option<String> {
    std::env::var(name)
        .ok()
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
}

fn first_env(names: &[&str]) -> Option<(String, String)> {
    for name in names {
        if let Some(v) = env_nonempty(name) {
            return Some((v, format!("env:{}", name)));
        }
    }
    None
}

fn pqc_disabled() -> bool {
    matches!(env_nonempty("AINISH_RAG_NO_PQC").as_deref(), Some("1") | Some("true") | Some("yes"))
}

/// Decrypts the PQC secret store once per process and keeps the values in memory only.
fn vault_map() -> &'static HashMap<String, String> {
    static VAULT: OnceLock<HashMap<String, String>> = OnceLock::new();
    VAULT.get_or_init(|| {
        if pqc_disabled() {
            return HashMap::new();
        }
        export_secrets().map(|text| parse_secrets(&text)).unwrap_or_default()
    })
}

fn export_secrets() -> Option<String> {
    let mut attempts: Vec<(String, Vec<String>)> = Vec::new();
    if let Some(bin) = env_nonempty("PQC_SECRETS_BIN") {
        attempts.push((bin, vec!["export".into(), "--json".into()]));
    }
    #[cfg(windows)]
    {
        // `.cmd` shims are not directly executable by CreateProcess; route them through cmd.exe.
        attempts.push(("cmd".into(), vec!["/C".into(), "pqc-secrets".into(), "export".into(), "--json".into()]));
    }
    attempts.push(("pqc-secrets".into(), vec!["export".into(), "--json".into()]));

    for (program, args) in attempts {
        let output = Command::new(&program)
            .args(&args)
            .stdin(Stdio::null())
            .output();
        if let Ok(out) = output {
            if out.status.success() && !out.stdout.is_empty() {
                if let Ok(text) = String::from_utf8(out.stdout) {
                    if !text.trim().is_empty() {
                        return Some(text);
                    }
                }
            }
        }
    }
    None
}

/// Parses both `pqc-secrets export --json` (`{"secrets":{...}}`) and the line-oriented
/// `export NAME=value` form. Values are trimmed of shell/JSON quoting.
pub fn parse_secrets(text: &str) -> HashMap<String, String> {
    let mut out = HashMap::new();

    if let Ok(value) = serde_json::from_str::<serde_json::Value>(text) {
        let object = value
            .get("secrets")
            .and_then(|s| s.as_object())
            .or_else(|| value.as_object());
        if let Some(object) = object {
            for (name, raw) in object {
                if let Some(s) = raw.as_str() {
                    let clean = s.trim();
                    if !clean.is_empty() && !clean.starts_with('{') {
                        out.insert(name.clone(), clean.to_string());
                    }
                }
            }
            if !out.is_empty() {
                return out;
            }
        }
    }

    for line in text.lines() {
        let line = line.trim();
        let line = line.strip_prefix("export ").unwrap_or(line);
        if let Some((name, raw)) = line.split_once('=') {
            let name = name.trim();
            let value = raw.trim().trim_matches('\'').trim_matches('"').trim();
            if !name.is_empty() && !value.is_empty() {
                out.insert(name.to_string(), value.to_string());
            }
        }
    }
    out
}

fn secret_names(spec: Option<&ProviderSpec>) -> Vec<&'static str> {
    let mut names: Vec<&'static str> = GENERIC_KEY_NAMES.to_vec();
    if let Some(spec) = spec {
        names.extend_from_slice(spec.key_names);
    }
    names
}

/// Resolves a secret from the environment first, then from the PQC store (in memory only).
pub fn resolve_secret(spec: Option<&ProviderSpec>) -> Option<(String, String)> {
    resolve_named_secret(&secret_names(spec))
}

/// Resolves an explicit secret-name list from the environment, then the PQC store.
/// Used by consumers that need one provider's key without the generic `AINISH_EMBED_API_KEY`
/// fallback (e.g. the Jev decision engine needs an OpenRouter key specifically).
/// Also accepts any `<CONSUMER>_<PROVIDER>_[EMBED_]API_KEY` suffix in the PQC vault so stores
/// keyed by sibling consumers (`PSIONICS_`, `LOCALROUTER_`, `AINISHCODER_`, …) resolve cleanly.
pub fn resolve_named_secret(names: &[&str]) -> Option<(String, String)> {
    if let Some(found) = first_env(names) {
        return Some(found);
    }
    if pqc_disabled() {
        return None;
    }
    let vault = vault_map();
    if let Some(exact) = names
        .iter()
        .find_map(|name| vault.get(*name).map(|value| (value.clone(), format!("pqc:{}", name))))
    {
        return Some(exact);
    }
    // Consumer-prefix suffix scan: if the caller asked for `OPENROUTER_API_KEY` or `ZENMUX_API_KEY`,
    // accept `<CONSUMER>_OPENROUTER_EMBED_API_KEY` / `<CONSUMER>_OPENROUTER_API_KEY` deterministically.
    for canonical in names {
        if *canonical == "AINISH_EMBED_API_KEY" {
            continue;
        }
        let suffix = format!("_{}", canonical);
        let mut matched: Vec<(&String, &String)> = vault
            .iter()
            .filter(|(k, v)| !v.trim().is_empty() && k.to_ascii_uppercase().ends_with(&suffix))
            .collect();
        matched.sort_by(|a, b| a.0.cmp(b.0));
        if let Some((k, v)) = matched.first() {
            return Some(((*v).clone(), format!("pqc:{}", k)));
        }
    }
    None
}

fn first_env_var(names: &[&str]) -> Option<String> {
    names.iter().find_map(|name| env_nonempty(name))
}

/// Reads the persisted, non-secret provider configuration. Malformed files are ignored.
/// Worktrees without a local override inherit the canonical repository's configuration.
pub fn read_config(repo_root: &Path) -> Option<PersistedConfig> {
    let local_path = repo_root.join(CONFIG_REL);
    let path = if local_path.is_file() {
        local_path
    } else {
        let canonical = crate::config::resolve_canonical_repo_root(repo_root).join(CONFIG_REL);
        if canonical.is_file() { canonical } else { return None; }
    };
    let text = std::fs::read_to_string(path).ok()?;
    let value: serde_json::Value = serde_json::from_str(&text).ok()?;
    let string_field = |key: &str| -> Option<String> {
        value
            .get(key)
            .and_then(|v| v.as_str())
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
    };
    let provider = string_field("provider")?.to_ascii_lowercase();
    let dim = value.get("dim").and_then(|v| match v {
        serde_json::Value::Number(n) => n.as_u64().map(|n| n as usize),
        serde_json::Value::String(s) => s.trim().parse::<usize>().ok(),
        _ => None,
    });
    Some(PersistedConfig {
        provider,
        provider_id: string_field("provider_id"),
        api_base: string_field("api_base"),
        model: string_field("model"),
        dim,
    })
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Intent {
    Local,
    Api,
    Auto,
}

fn resolve_intent(
    persisted: Option<&PersistedConfig>,
    override_intent: Option<&str>,
) -> (Intent, Option<String>, bool, bool) {
    // (intent, pinned provider id, explicit, warning-unknown-provider)
    let env_intent = override_intent
        .map(|v| v.trim().to_ascii_lowercase())
        .filter(|v| !v.is_empty())
        .or_else(|| env_nonempty("AINISH_EMBED_PROVIDER").map(|v| v.to_ascii_lowercase()));
    match env_intent.as_deref() {
        Some("local") | Some("off") | Some("none") | Some("llama") => (Intent::Local, None, true, false),
        Some("api") => (Intent::Api, None, true, false),
        Some("openrouter") | Some("zenmux") => (Intent::Api, env_intent.clone(), true, false),
        // `auto` is explicitly non-pinning: detection stays free to pick a provider (or fall
        // back to local) each run, and `--write` must never persist a `local` verdict for it.
        Some("auto") => (Intent::Auto, None, false, false),
        Some(_) => (Intent::Auto, None, true, true),
        None => match persisted.map(|p| p.provider.as_str()) {
            Some("local") => (Intent::Local, None, true, false),
            Some("api") => (Intent::Api, persisted.and_then(|p| p.provider_id.clone()), true, false),
            Some("openrouter") | Some("zenmux") => (
                Intent::Api,
                persisted.map(|p| p.provider.clone()),
                true,
                false,
            ),
            _ => (Intent::Auto, None, false, false),
        },
    }
}

fn api_resolution(
    repo_root: &Path,
    persisted: Option<&PersistedConfig>,
    explicit: bool,
    pinned: Option<String>,
    mut source: String,
) -> Resolution {
    let mut warnings = Vec::new();

    let mut provider_id = pinned
        .clone()
        .or_else(|| persisted.and_then(|p| p.provider_id.clone()))
        .or_else(|| {
            persisted
                .and_then(|p| p.api_base.as_deref())
                .and_then(infer_provider_id)
                .map(|s| s.to_string())
        })
        .map(|s| s.to_ascii_lowercase());
    let spec = provider_id.as_deref().and_then(find_provider);

    let api_base = first_env_var(GENERIC_BASE_VARS)
        .or_else(|| spec.map(|s| first_env_var(s.base_vars)).flatten())
        .or_else(|| persisted.and_then(|p| p.api_base.clone()))
        .or_else(|| spec.map(|s| s.api_base.to_string()));

    let model = first_env_var(GENERIC_MODEL_VARS)
        .or_else(|| spec.map(|s| first_env_var(s.model_vars)).flatten())
        .or_else(|| persisted.and_then(|p| p.model.clone()))
        .or_else(|| spec.map(|s| s.default_model.to_string()));

    let dim = first_env_var(GENERIC_DIM_VARS)
        .or_else(|| spec.map(|s| first_env_var(s.dim_vars)).flatten())
        .and_then(|v| v.parse::<usize>().ok())
        .or_else(|| persisted.and_then(|p| p.dim));

    if provider_id.is_none() {
        if let Some(base) = api_base.as_deref() {
            provider_id = infer_provider_id(base).map(|s| s.to_string());
        }
    }

    let secret = resolve_secret(provider_id.as_deref().and_then(find_provider));

    if api_base.is_none() || model.is_none() {
        warnings.push(
            "API embedding intent is incomplete: set --embed-config --provider api --api-base <url> --model <name> (or AINISH_EMBED_API_BASE / AINISH_EMBED_MODEL)".to_string(),
        );
        return Resolution {
            provider: if explicit { "invalid".to_string() } else { "local".to_string() },
            provider_id,
            api_base,
            model,
            dim,
            key: secret.as_ref().map(|(v, _)| v.clone()),
            key_source: secret.map(|(_, s)| s),
            source: if explicit { "operator".to_string() } else { "default-local".to_string() },
            explicit,
            warnings,
        };
    }

    if secret.is_none() {
        warnings.push(format!(
            "No API key resolved for {}; the endpoint will be called unauthenticated (set AINISH_EMBED_API_KEY or a provider key)",
            provider_id.as_deref().unwrap_or("the configured provider")
        ));
    }

    if source.is_empty() {
        source = if explicit { "operator".to_string() } else { "env-auto".to_string() };
    }

    let _ = repo_root;
    Resolution {
        provider: "api".to_string(),
        provider_id,
        api_base,
        model,
        dim,
        key: secret.as_ref().map(|(v, _)| v.clone()),
        key_source: secret.map(|(_, s)| s),
        source,
        explicit,
        warnings,
    }
}

/// Auto-detects a remote embedding provider from environment variables and the PQC store.
fn auto_resolution(repo_root: &Path) -> Resolution {
    let mut warnings = Vec::new();

    let generic_base = first_env_var(GENERIC_BASE_VARS);
    let generic_model = first_env_var(GENERIC_MODEL_VARS);
    let generic_dim = first_env_var(GENERIC_DIM_VARS).and_then(|v| v.parse::<usize>().ok());
    let generic_secret = resolve_secret(None);

    // Explicit base (with or without a generic key) identifies the provider by host.
    if generic_base.is_some() {
        let provider_id = generic_base.as_deref().and_then(infer_provider_id).map(|s| s.to_string());
        let spec = provider_id.as_deref().and_then(find_provider);
        let base = generic_base.clone();
        let model = generic_model
            .clone()
            .or_else(|| spec.and_then(|s| first_env_var(s.model_vars)))
            .or_else(|| spec.map(|s| s.default_model.to_string()));
        let secret = generic_secret
            .clone()
            .or_else(|| resolve_secret(spec))
            .or_else(|| spec.and_then(|s| resolve_secret(Some(s))));
        if base.is_some() && model.is_some() {
            if secret.is_none() {
                warnings.push("AINISH_EMBED_API_BASE is set but no embedding API key was resolved".to_string());
            }
            return Resolution {
                provider: "api".to_string(),
                provider_id,
                api_base: base,
                model,
                dim: generic_dim,
                key: secret.as_ref().map(|(v, _)| v.clone()),
                key_source: secret.map(|(_, s)| s),
                source: "env-auto".to_string(),
                explicit: false,
                warnings,
            };
        }
        warnings.push("AINISH_EMBED_API_BASE is set but no embedding model could be resolved".to_string());
    }

    // Provider catalog scan: the first provider with a resolvable key wins (OpenRouter first).
    for spec in PROVIDERS {
        let Some(secret) = resolve_secret(Some(spec)) else {
            continue;
        };
        let base = first_env_var(spec.base_vars).unwrap_or_else(|| spec.api_base.to_string());
        let model = first_env_var(spec.model_vars).unwrap_or_else(|| spec.default_model.to_string());
        let dim = first_env_var(spec.dim_vars).and_then(|v| v.parse::<usize>().ok());
        let from_pqc = secret.1.starts_with("pqc:");
        return Resolution {
            provider: "api".to_string(),
            provider_id: Some(spec.id.to_string()),
            api_base: Some(base),
            model: Some(model),
            dim,
            key: Some(secret.0),
            key_source: Some(secret.1),
            source: if from_pqc { "pqc-auto".to_string() } else { "env-auto".to_string() },
            explicit: false,
            warnings,
        };
    }

    let _ = repo_root;
    Resolution {
        provider: "local".to_string(),
        provider_id: None,
        api_base: None,
        model: None,
        dim: generic_dim,
        key: generic_secret.as_ref().map(|(v, _)| v.clone()),
        key_source: generic_secret.map(|(_, s)| s),
        source: "default-local".to_string(),
        explicit: false,
        warnings,
    }
}

/// Resolves the embedding provider for `repo_root`, honoring operator intent before detection.
pub fn resolve(repo_root: &Path) -> Resolution {
    resolve_with(repo_root, None)
}

/// Resolves the embedding provider, allowing a one-shot intent override (used by
/// `ainish-rag embed-provider --provider <id>` and `ainish-coder --embed-config --detect`).
pub fn resolve_with(repo_root: &Path, override_intent: Option<&str>) -> Resolution {
    let persisted = read_config(repo_root);
    let (intent, pinned, explicit, unknown) = resolve_intent(persisted.as_ref(), override_intent);

    if unknown {
        let mut r = auto_resolution(repo_root);
        r.warnings.push(
            "Unknown AINISH_EMBED_PROVIDER value; expected local|api|auto|openrouter|zenmux".to_string(),
        );
        return r;
    }

    match intent {
        Intent::Local => Resolution {
            provider: "local".to_string(),
            provider_id: None,
            api_base: None,
            model: None,
            dim: persisted.as_ref().and_then(|p| p.dim),
            key: None,
            key_source: None,
            source: "operator-local".to_string(),
            explicit,
            warnings: Vec::new(),
        },
        Intent::Api => api_resolution(repo_root, persisted.as_ref(), explicit, pinned, "operator".to_string()),
        Intent::Auto => auto_resolution(repo_root),
    }
}

/// Writes the non-secret provider configuration. Key material is never persisted.
pub fn write_config(repo_root: &Path, resolution: &Resolution) -> Result<PathBuf, String> {
    let path = repo_root.join(CONFIG_REL);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|e| format!("failed to create {}: {}", parent.display(), e))?;
    }
    let provider = match resolution.provider.as_str() {
        "api" => "api",
        "invalid" => "api",
        _ => "local",
    };
    let doc = serde_json::json!({
        "format": "ainish-rag/embed-provider/v1",
        "provider": provider,
        "provider_id": resolution.provider_id,
        "api_base": resolution.api_base,
        "model": resolution.model,
        "dim": resolution.dim,
        "key_source": resolution.key_source,
        "source": resolution.source,
        "updated_at": chrono::Utc::now().to_rfc3339(),
    });
    std::fs::write(&path, serde_json::to_string_pretty(&doc).unwrap_or_default())
        .map_err(|e| format!("failed to write {}: {}", path.display(), e))?;
    Ok(path)
}

/// Removes the persisted provider configuration (reverts to auto-detection).
pub fn clear_config(repo_root: &Path) -> Result<bool, String> {
    let path = repo_root.join(CONFIG_REL);
    if path.exists() {
        std::fs::remove_file(&path).map_err(|e| format!("failed to remove {}: {}", path.display(), e))?;
        Ok(true)
    } else {
        Ok(false)
    }
}

/// Relative path of the index fingerprint written after a successful index run.
pub const INDEX_FINGERPRINT_REL: &str = ".agents/rag/index-fingerprint.json";

/// Stable identity of the embedding model that produced the vectors in the store.
pub fn identity_for(provider: &str, provider_id: Option<&str>, model: Option<&str>) -> String {
    if provider == "api" {
        format!(
            "api:{}:{}",
            provider_id.unwrap_or("custom"),
            model.unwrap_or("unknown-model")
        )
    } else {
        "local:embeddinggemma-2".to_string()
    }
}

/// Records which embedding model built the vector store, so a provider switch is detectable.
pub fn write_index_fingerprint(repo_root: &Path, identity: &str, dim: usize) -> Result<PathBuf, String> {
    let path = repo_root.join(INDEX_FINGERPRINT_REL);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|e| format!("failed to create {}: {}", parent.display(), e))?;
    }
    let doc = serde_json::json!({
        "format": "ainish-rag/index-fingerprint/v1",
        "identity": identity,
        "dim": dim,
        "updated_at": chrono::Utc::now().to_rfc3339(),
    });
    std::fs::write(&path, serde_json::to_string_pretty(&doc).unwrap_or_default())
        .map_err(|e| format!("failed to write {}: {}", path.display(), e))?;
    Ok(path)
}

/// Returns a warning when the store was built with a different embedding model than the one in
/// use. Vectors from different models are not comparable, so retrieval would silently degrade.
pub fn index_mismatch_warning(repo_root: &Path, identity: &str) -> Option<String> {
    let local_path = repo_root.join(INDEX_FINGERPRINT_REL);
    let path = if local_path.is_file() {
        local_path
    } else {
        let canonical = crate::config::resolve_canonical_repo_root(repo_root).join(INDEX_FINGERPRINT_REL);
        if canonical.is_file() { canonical } else { return None; }
    };
    let text = std::fs::read_to_string(path).ok()?;
    let value: serde_json::Value = serde_json::from_str(&text).ok()?;
    let recorded = value.get("identity").and_then(|v| v.as_str())?.trim();
    if recorded.is_empty() || recorded == identity {
        return None;
    }
    Some(format!(
        "Vector index was built with '{}' but embeddings now come from '{}'; \
         run `ainish-rag index --rebuild` to rebuild the store before trusting retrieval results",
        recorded, identity
    ))
}

/// One-shot embedding probe against a remote endpoint. Returns the produced vector width.
/// Used to fail closed on auto-detected providers that reject the key or the model.
pub async fn probe(api_base: &str, model: &str, key: Option<&str>, timeout: Duration) -> Result<usize, String> {
    let client = reqwest::Client::builder()
        .timeout(timeout)
        .build()
        .map_err(|e| format!("failed to build probe client: {}", e))?;
    let url = format!("{}/embeddings", api_base.trim_end_matches('/'));
    let mut request = client
        .post(&url)
        .header("Content-Type", "application/json")
        .json(&serde_json::json!({
            "model": model,
            "input": ["ainish-rag provider probe"],
            "encoding_format": "float",
        }));
    if let Some(key) = key {
        request = request.header("Authorization", format!("Bearer {}", key));
    }
    let response = request
        .send()
        .await
        .map_err(|e| format!("embedding endpoint {} unreachable: {}", url, e))?;
    let status = response.status();
    if !status.is_success() {
        let body = response.text().await.unwrap_or_default();
        let body: String = body.chars().take(300).collect();
        return Err(format!("embedding endpoint {} returned {}: {}", url, status, body));
    }
    let value: serde_json::Value = response
        .json()
        .await
        .map_err(|e| format!("embedding endpoint {} returned unparseable JSON: {}", url, e))?;
    let dim = value
        .get("data")
        .and_then(|d| d.get(0))
        .and_then(|d| d.get("embedding"))
        .and_then(|e| e.as_array())
        .map(|a| a.len())
        .unwrap_or(0);
    if dim == 0 {
        return Err(format!("embedding endpoint {} returned an empty vector", url));
    }
    Ok(dim)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    // Environment mutation is process-global; serialize the tests that touch it.
    static ENV_LOCK: Mutex<()> = Mutex::new(());

    #[test]
    fn test_provider_catalog_entries_are_openai_compatible() {
        assert_eq!(PROVIDERS.len(), 2);
        for spec in PROVIDERS {
            assert!(spec.api_base.starts_with("https://"));
            assert!(spec.api_base.ends_with("/api/v1"));
            assert!(!spec.default_model.is_empty());
            // Consumer-prefixed names carry the canonical plain name as the last resort.
            assert!(spec.key_names.iter().any(|n| n.starts_with("LOCALROUTER_")));
            assert!(spec.key_names.iter().all(|n| n.ends_with("API_KEY")));
        }
        assert_eq!(find_provider("zenmux").map(|s| s.id), Some("zenmux"));
        assert!(find_provider("nope").is_none());
    }

    #[test]
    fn test_infer_provider_from_base() {
        assert_eq!(infer_provider_id("https://openrouter.ai/api/v1"), Some("openrouter"));
        assert_eq!(infer_provider_id("https://zenmux.ai/api/v1"), Some("zenmux"));
        assert_eq!(infer_provider_id("http://127.0.0.1:1234/v1"), None);
    }

    #[test]
    fn test_parse_secrets_json_and_export_lines() {
        let json = r#"{"secrets":{"LOCALROUTER_OPENROUTER_API_KEY":"sk-or-v1-abc","LOCALROUTER_ZENMUX_API_KEY":"zm-123"}}"#;
        let parsed = parse_secrets(json);
        assert_eq!(parsed.get("LOCALROUTER_OPENROUTER_API_KEY").map(String::as_str), Some("sk-or-v1-abc"));
        assert_eq!(parsed.get("LOCALROUTER_ZENMUX_API_KEY").map(String::as_str), Some("zm-123"));

        let lines = "export OPENROUTER_API_KEY='sk-or-v1-xyz'\nZENMUX_API_KEY=zm-456\n";
        let parsed = parse_secrets(lines);
        assert_eq!(parsed.get("OPENROUTER_API_KEY").map(String::as_str), Some("sk-or-v1-xyz"));
        assert_eq!(parsed.get("ZENMUX_API_KEY").map(String::as_str), Some("zm-456"));
    }

    #[test]
    fn test_explicit_local_intent_wins_over_detected_keys() {
        let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        let dir = std::env::temp_dir().join(format!("ainish-provider-local-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        unsafe {
            std::env::set_var("AINISH_EMBED_PROVIDER", "local");
            std::env::set_var("AINISH_EMBED_API_KEY", "sk-test");
            std::env::remove_var("AINISH_RAG_NO_PQC");
        }
        let r = resolve(&dir);
        assert_eq!(r.provider, "local");
        assert!(r.explicit);
        assert!(!r.uses_api());
        unsafe {
            std::env::remove_var("AINISH_EMBED_PROVIDER");
            std::env::remove_var("AINISH_EMBED_API_KEY");
        }
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_auto_override_is_non_pinning_when_nothing_is_detected() {
        let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        let dir = std::env::temp_dir().join(format!("ainish-provider-auto-none-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        unsafe {
            std::env::remove_var("AINISH_EMBED_PROVIDER");
            std::env::remove_var("AINISH_EMBED_API_KEY");
            std::env::remove_var("OPENROUTER_API_KEY");
            std::env::remove_var("ZENMUX_API_KEY");
            std::env::set_var("AINISH_RAG_NO_PQC", "1");
        }
        // `--provider auto` with no credentials must not count as an operator pin, otherwise
        // `--write` would persist `local` and a later-added key would be ignored.
        let r = resolve_with(&dir, Some("auto"));
        assert_eq!(r.provider, "local");
        assert!(!r.explicit);
        unsafe { std::env::remove_var("AINISH_RAG_NO_PQC") };
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_auto_detection_uses_provider_defaults_with_env_key() {
        let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        let dir = std::env::temp_dir().join(format!("ainish-provider-auto-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        unsafe {
            std::env::remove_var("AINISH_EMBED_PROVIDER");
            std::env::remove_var("AINISH_EMBED_API_BASE");
            std::env::remove_var("AINISH_EMBED_MODEL");
            std::env::set_var("OPENROUTER_API_KEY", "sk-or-test");
            std::env::set_var("AINISH_RAG_NO_PQC", "1");
        }
        let r = resolve(&dir);
        assert_eq!(r.provider, "api");
        assert_eq!(r.provider_id.as_deref(), Some("openrouter"));
        assert_eq!(r.api_base.as_deref(), Some("https://openrouter.ai/api/v1"));
        assert_eq!(r.model.as_deref(), Some("openai/text-embedding-3-small"));
        assert_eq!(r.key_source.as_deref(), Some("env:OPENROUTER_API_KEY"));
        assert!(!r.explicit);
        unsafe {
            std::env::remove_var("OPENROUTER_API_KEY");
            std::env::remove_var("AINISH_RAG_NO_PQC");
        }
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_persisted_config_round_trips_without_key_material() {
        let dir = std::env::temp_dir().join(format!("ainish-provider-cfg-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let resolution = Resolution {
            provider: "api".into(),
            provider_id: Some("zenmux".into()),
            api_base: Some("https://zenmux.ai/api/v1".into()),
            model: Some("openai/text-embedding-3-small".into()),
            dim: Some(768),
            key: Some("super-secret-value".into()),
            key_source: Some("pqc:LOCALROUTER_ZENMUX_API_KEY".into()),
            source: "pqc-auto".into(),
            explicit: false,
            warnings: Vec::new(),
        };
        let path = write_config(&dir, &resolution).unwrap();
        let text = std::fs::read_to_string(&path).unwrap();
        assert!(!text.contains("super-secret-value"), "API key must never be persisted");
        assert!(text.contains("pqc:LOCALROUTER_ZENMUX_API_KEY"));
        let persisted = read_config(&dir).expect("config must round-trip");
        assert_eq!(persisted.provider, "api");
        assert_eq!(persisted.provider_id.as_deref(), Some("zenmux"));
        assert_eq!(persisted.dim, Some(768));
        assert!(clear_config(&dir).unwrap());
        assert!(!path.exists());
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_index_fingerprint_detects_provider_switch() {
        let dir = std::env::temp_dir().join(format!("ainish-provider-fingerprint-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let local_id = identity_for("local", None, None);
        let api_id = identity_for("api", Some("openrouter"), Some("openai/text-embedding-3-small"));
        assert_ne!(local_id, api_id);

        write_index_fingerprint(&dir, &local_id, 768).unwrap();
        assert!(index_mismatch_warning(&dir, &local_id).is_none());
        let warning = index_mismatch_warning(&dir, &api_id).expect("provider switch must warn");
        assert!(warning.contains("index --rebuild"));
        assert!(warning.contains("openrouter"));

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_explicit_api_without_base_or_model_is_invalid() {
        let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        let dir = std::env::temp_dir().join(format!("ainish-provider-invalid-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        unsafe {
            std::env::set_var("AINISH_EMBED_PROVIDER", "api");
            std::env::remove_var("AINISH_EMBED_API_BASE");
            std::env::remove_var("AINISH_EMBED_MODEL");
            std::env::remove_var("AINISH_RAG_NO_PQC");
        }
        let r = resolve(&dir);
        assert!(r.is_invalid());
        assert!(!r.uses_api());
        assert!(r.explicit);
        assert!(!r.warnings.is_empty());
        unsafe { std::env::remove_var("AINISH_EMBED_PROVIDER") };
        let _ = std::fs::remove_dir_all(&dir);
    }
}
