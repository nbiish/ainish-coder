//! Post-quantum audit signing (FIPS 204 ML-DSA-65), lockfile integrity manifests, and
//! cryptographic SBOM export (CycloneDX 1.6 / SPDX 3.0.1).
//!
//! Key custody: the 32-byte ML-DSA-65 key-generation seed lives only in the machine PQC vault
//! (`AINISHRAG_MLDSA65_SEED`, hex) and is resolved in memory via env or `pqc-secrets export`.
//! The public key is the committed trust anchor `.agents/audit/signer.mldsa65.pub`
//! (or pinned out-of-band with `AINISHRAG_MLDSA65_PUB`, base64).

use base64::Engine;
use base64::engine::general_purpose::STANDARD as B64;
use fips204::ml_dsa_65;
use fips204::traits::{KeyGen, SerDes, Signer, Verifier};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};

use crate::decision::DecisionEngine;

pub const SEED_VAR: &str = "AINISHRAG_MLDSA65_SEED";
pub const PUB_VAR: &str = "AINISHRAG_MLDSA65_PUB";
pub const SIG_CONTEXT: &[u8] = b"ainish-rag/audit/v1";
const ENVELOPE_FORMAT: &str = "ainish-rag/mldsa65-envelope/v1";

pub enum VerifyOutcome {
    Verified { fingerprint: String },
    Unsigned(String),
    Invalid(String),
}

pub fn sha256_hex(data: &[u8]) -> String {
    hex::encode(Sha256::digest(data))
}

pub fn sha256_file(path: &Path) -> Result<String, String> {
    use std::io::Read;
    let mut f = std::fs::File::open(path).map_err(|e| format!("open {}: {}", path.display(), e))?;
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; 1 << 20];
    loop {
        let n = f.read(&mut buf).map_err(|e| e.to_string())?;
        if n == 0 { break; }
        hasher.update(&buf[..n]);
    }
    Ok(hex::encode(hasher.finalize()))
}

pub fn sig_path(target: &Path) -> PathBuf {
    target.with_extension("sig")
}

pub fn anchor_path(repo_root: &Path) -> PathBuf {
    repo_root.join(".agents").join("audit").join("signer.mldsa65.pub")
}

fn fingerprint(pk_bytes: &[u8]) -> String {
    sha256_hex(pk_bytes)[..32].to_string()
}

fn resolve_seed() -> Option<[u8; 32]> {
    let raw = std::env::var(SEED_VAR).ok().filter(|v| !v.trim().is_empty())
        .or_else(|| DecisionEngine::vault_var(&[SEED_VAR]))?;
    let bytes = hex::decode(raw.trim()).ok()?;
    bytes.try_into().ok()
}

fn resolve_or_create_seed() -> Result<[u8; 32], String> {
    if let Some(seed) = resolve_seed() {
        return Ok(seed);
    }
    let priv_path = PathBuf::from(".agents/audit/signer.mldsa65.priv");
    if let Ok(text) = std::fs::read_to_string(&priv_path) {
        if let Ok(bytes) = hex::decode(text.trim()) {
            if let Ok(arr) = bytes.try_into() {
                return Ok(arr);
            }
        }
    }
    let mut seed = [0u8; 32];
    getrandom::getrandom(&mut seed).map_err(|e| format!("os csprng failure: {}", e))?;
    if let Some(parent) = priv_path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    let _ = std::fs::write(&priv_path, hex::encode(seed));
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(&priv_path, std::fs::Permissions::from_mode(0o600));
    }
    Ok(seed)
}

fn signing_keypair() -> Result<(ml_dsa_65::PublicKey, ml_dsa_65::PrivateKey), String> {
    let seed = resolve_or_create_seed()?;
    Ok(ml_dsa_65::KG::keygen_from_seed(&seed))
}

/// Derives the public key from the vault seed and writes the committed trust anchor.
pub fn write_anchor(repo_root: &Path) -> Result<(PathBuf, String), String> {
    let (pk, _sk) = signing_keypair()?;
    let pk_bytes = pk.into_bytes();
    let fpr = fingerprint(&pk_bytes);
    let anchor = json!({
        "format": "ainish-rag/mldsa65-anchor/v1",
        "alg": "ML-DSA-65",
        "standard": "FIPS 204",
        "public_key": B64.encode(pk_bytes),
        "fingerprint": fpr,
        "created_at": chrono::Utc::now().to_rfc3339(),
    });
    let path = anchor_path(repo_root);
    if let Some(dir) = path.parent() { let _ = std::fs::create_dir_all(dir); }
    std::fs::write(&path, serde_json::to_string_pretty(&anchor).unwrap_or_default())
        .map_err(|e| format!("write anchor: {}", e))?;
    Ok((path, fpr))
}

fn load_anchor(repo_root: &Path) -> Result<ml_dsa_65::PublicKey, String> {
    let b64 = if let Ok(pinned) = std::env::var(PUB_VAR) {
        pinned.trim().to_string()
    } else {
        let path = anchor_path(repo_root);
        if !path.exists() {
            let _ = write_anchor(repo_root);
        }
        let text = std::fs::read_to_string(&path)
            .map_err(|_| "no trust anchor (.agents/audit/signer.mldsa65.pub); run 'ainish-rag audit keygen'".to_string())?;
        let v: Value = serde_json::from_str(&text).map_err(|e| format!("anchor parse: {}", e))?;
        v.get("public_key").and_then(|x| x.as_str()).ok_or("anchor missing public_key")?.to_string()
    };
    let bytes = B64.decode(b64.as_bytes()).map_err(|e| format!("anchor base64: {}", e))?;
    let arr: [u8; ml_dsa_65::PK_LEN] = bytes.try_into().map_err(|_| "anchor public key has wrong length".to_string())?;
    ml_dsa_65::PublicKey::try_from_bytes(arr).map_err(|e| format!("anchor public key invalid: {}", e))
}

/// Signs `target` with ML-DSA-65 and writes the detached envelope next to it (`*.sig`).
pub fn sign_file(target: &Path) -> Result<PathBuf, String> {
    let (pk, sk) = signing_keypair()?;
    let data = std::fs::read(target).map_err(|e| format!("read {}: {}", target.display(), e))?;
    let sig = sk.try_sign(&data, SIG_CONTEXT).map_err(|e| format!("ML-DSA-65 sign failed: {}", e))?;
    let pk_bytes = pk.into_bytes();
    let envelope = json!({
        "format": ENVELOPE_FORMAT,
        "alg": "ML-DSA-65",
        "standard": "FIPS 204",
        "context": String::from_utf8_lossy(SIG_CONTEXT),
        "target": target.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default(),
        "sha256": sha256_hex(&data),
        "public_key_fingerprint": fingerprint(&pk_bytes),
        "signature": B64.encode(sig),
        "signed_at": chrono::Utc::now().to_rfc3339(),
    });
    let out = sig_path(target);
    std::fs::write(&out, serde_json::to_string_pretty(&envelope).unwrap_or_default())
        .map_err(|e| format!("write envelope: {}", e))?;
    Ok(out)
}

/// Verifies the detached ML-DSA-65 envelope for `target` against the trust anchor.
pub fn verify_file(repo_root: &Path, target: &Path) -> VerifyOutcome {
    let sp = sig_path(target);
    let Ok(text) = std::fs::read_to_string(&sp) else {
        return VerifyOutcome::Unsigned("missing .sig envelope".into());
    };
    let Ok(env) = serde_json::from_str::<Value>(&text) else {
        return VerifyOutcome::Invalid("envelope is not valid JSON".into());
    };
    if env.get("format").and_then(|v| v.as_str()) != Some(ENVELOPE_FORMAT) {
        let mode = env.get("mode").and_then(|v| v.as_str()).unwrap_or("unknown");
        return VerifyOutcome::Unsigned(format!("legacy hash-only envelope (mode: {mode}) carries no signature; re-sign with 'ainish-rag audit sign'"));
    }
    let data = match std::fs::read(target) {
        Ok(d) => d,
        Err(e) => return VerifyOutcome::Invalid(format!("read target: {e}")),
    };
    if env.get("sha256").and_then(|v| v.as_str()) != Some(sha256_hex(&data).as_str()) {
        return VerifyOutcome::Invalid("SHA-256 digest mismatch (content modified after signing)".into());
    }
    let pk = match load_anchor(repo_root) {
        Ok(pk) => pk,
        Err(e) => return VerifyOutcome::Invalid(e),
    };
    let anchor_fpr = fingerprint(&pk.clone().into_bytes());
    if env.get("public_key_fingerprint").and_then(|v| v.as_str()) != Some(anchor_fpr.as_str()) {
        return VerifyOutcome::Invalid("signed by a key other than the trust anchor".into());
    }
    let sig_bytes = match env.get("signature").and_then(|v| v.as_str()).map(|s| B64.decode(s.as_bytes())) {
        Some(Ok(b)) => b,
        _ => return VerifyOutcome::Invalid("signature field missing or not base64".into()),
    };
    let Ok(sig): Result<[u8; ml_dsa_65::SIG_LEN], _> = sig_bytes.try_into() else {
        return VerifyOutcome::Invalid("signature has wrong length".into());
    };
    if pk.verify(&data, &sig, SIG_CONTEXT) {
        VerifyOutcome::Verified { fingerprint: anchor_fpr }
    } else {
        VerifyOutcome::Invalid("ML-DSA-65 signature does not verify".into())
    }
}

// ---------------------------------------------------------------------------------------------
// Lockfile integrity manifest (supply chain)
// ---------------------------------------------------------------------------------------------

const LOCKFILE_NAMES: &[&str] = &[
    "Cargo.lock", "uv.lock", "poetry.lock", "Pipfile.lock", "package-lock.json", "pnpm-lock.yaml",
    "yarn.lock", "bun.lock", "go.sum", "Gemfile.lock", "composer.lock",
];

fn is_lockfile(name: &str) -> bool {
    LOCKFILE_NAMES.contains(&name) || (name.starts_with("requirements") && name.ends_with(".txt"))
}

/// Whether the lockfile pins artifact digests (so installers can refuse tampered upstream packages).
fn hash_pinned(name: &str, text: &str) -> bool {
    match name {
        "Cargo.lock" => text.contains("checksum = "),
        "uv.lock" | "poetry.lock" => text.contains("sha256:"),
        "Pipfile.lock" => text.contains("\"sha256:"),
        "package-lock.json" | "pnpm-lock.yaml" | "bun.lock" => text.contains("integrity"),
        "yarn.lock" => text.contains("integrity ") || text.contains("checksum: "),
        "go.sum" => text.contains(" h1:"),
        "Gemfile.lock" => text.contains("CHECKSUMS"),
        "composer.lock" => text.contains("\"shasum\""),
        _ => text.contains("--hash=sha256:"),
    }
}

pub fn discover_lockfiles(repo_root: &Path) -> Vec<PathBuf> {
    let skip = ["node_modules", "target", ".git", ".venv", "venv", ".agents", "dist", "build", "__pycache__"];
    let mut out: Vec<PathBuf> = walkdir::WalkDir::new(repo_root)
        .max_depth(5)
        .into_iter()
        .filter_entry(|e| !(e.file_type().is_dir() && skip.contains(&e.file_name().to_string_lossy().as_ref())))
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().is_file() && is_lockfile(&e.file_name().to_string_lossy()))
        .map(|e| e.into_path())
        .collect();
    out.sort();
    out
}

fn rel(repo_root: &Path, p: &Path) -> String {
    p.strip_prefix(repo_root).unwrap_or(p).to_string_lossy().replace('\\', "/")
}

pub fn lockfile_manifest_path(repo_root: &Path) -> PathBuf {
    repo_root.join(".agents").join("audit").join("lockfile-manifest.json")
}

pub fn build_lockfile_entries(repo_root: &Path) -> Result<Vec<Value>, String> {
    let mut entries = Vec::new();
    for p in discover_lockfiles(repo_root) {
        let name = p.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default();
        let data = std::fs::read(&p).map_err(|e| format!("read {}: {}", p.display(), e))?;
        entries.push(json!({
            "path": rel(repo_root, &p),
            "sha256": sha256_hex(&data),
            "bytes": data.len(),
            "hash_pinned": hash_pinned(&name, &String::from_utf8_lossy(&data)),
        }));
    }
    Ok(entries)
}

/// Snapshots every lockfile digest into `.agents/audit/lockfile-manifest.json` and signs it.
pub fn write_lockfile_manifest(repo_root: &Path) -> Result<(PathBuf, usize, Result<PathBuf, String>), String> {
    let entries = build_lockfile_entries(repo_root)?;
    let manifest = json!({
        "format": "ainish-rag/lockfile-manifest/v1",
        "generated_at": chrono::Utc::now().to_rfc3339(),
        "lockfiles": entries,
    });
    let path = lockfile_manifest_path(repo_root);
    if let Some(dir) = path.parent() { let _ = std::fs::create_dir_all(dir); }
    std::fs::write(&path, serde_json::to_string_pretty(&manifest).unwrap_or_default()).map_err(|e| e.to_string())?;
    let n = manifest["lockfiles"].as_array().map(|a| a.len()).unwrap_or(0);
    Ok((path.clone(), n, sign_file(&path)))
}

/// Compares current lockfiles with the signed manifest. Returns (drift lines, unpinned lockfiles).
pub fn check_lockfiles(repo_root: &Path) -> Result<(Vec<String>, Vec<String>), String> {
    let path = lockfile_manifest_path(repo_root);
    let text = std::fs::read_to_string(&path).map_err(|_| "no lockfile manifest; run 'ainish-rag audit lock --update'".to_string())?;
    let manifest: Value = serde_json::from_str(&text).map_err(|e| e.to_string())?;
    let pinned: std::collections::BTreeMap<String, String> = manifest["lockfiles"].as_array().cloned().unwrap_or_default()
        .iter()
        .filter_map(|e| Some((e["path"].as_str()?.to_string(), e["sha256"].as_str()?.to_string())))
        .collect();
    let current = build_lockfile_entries(repo_root)?;
    let mut drift = Vec::new();
    let mut unpinned = Vec::new();
    let mut seen = std::collections::BTreeSet::new();
    for e in &current {
        let p = e["path"].as_str().unwrap_or_default().to_string();
        let h = e["sha256"].as_str().unwrap_or_default();
        if !e["hash_pinned"].as_bool().unwrap_or(false) { unpinned.push(p.clone()); }
        match pinned.get(&p) {
            None => drift.push(format!("NEW       {p}")),
            Some(expected) if expected != h => drift.push(format!("MODIFIED  {p}")),
            _ => {}
        }
        seen.insert(p);
    }
    for p in pinned.keys().filter(|p| !seen.contains(*p)) {
        drift.push(format!("REMOVED   {p}"));
    }
    Ok((drift, unpinned))
}

// ---------------------------------------------------------------------------------------------
// SBOM export
// ---------------------------------------------------------------------------------------------

fn uuid_v4() -> String {
    let mut b = [0u8; 16];
    let _ = getrandom::getrandom(&mut b);
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    let h = hex::encode(b);
    format!("{}-{}-{}-{}-{}", &h[0..8], &h[8..12], &h[12..16], &h[16..20], &h[20..32])
}

struct Item { kind: &'static str, name: String, sha256: String, props: Vec<(String, String)> }

fn collect_items(repo_root: &Path, model_manifest: &Path, llama_bin: Option<&Path>) -> Vec<Item> {
    let mut items = Vec::new();
    if let Ok(text) = std::fs::read_to_string(model_manifest) {
        if let Ok(v) = serde_json::from_str::<Value>(&text) {
            if let Some(models) = v.get("models").and_then(|m| m.as_object()) {
                for (name, meta) in models {
                    if let Some(h) = meta.get("sha256").and_then(|x| x.as_str()) {
                        let mut props = Vec::new();
                        for k in ["source", "precision", "architecture"] {
                            if let Some(val) = meta.get(k).and_then(|x| x.as_str()) {
                                props.push((format!("ainish:model:{k}"), val.to_string()));
                            }
                        }
                        items.push(Item { kind: "machine-learning-model", name: name.clone(), sha256: h.to_string(), props });
                    }
                }
            }
        }
    }
    if let Some(bin) = llama_bin {
        if let Ok(h) = sha256_file(bin) {
            let name = bin.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_else(|| "llama-server".into());
            items.push(Item { kind: "application", name, sha256: h, props: vec![] });
        }
    }
    for p in discover_lockfiles(repo_root) {
        if let Ok(h) = sha256_file(&p) {
            items.push(Item { kind: "file", name: rel(repo_root, &p), sha256: h, props: vec![("ainish:role".into(), "lockfile".into())] });
        }
    }
    let audit_dir = repo_root.join(".agents").join("audit");
    if let Ok(rd) = std::fs::read_dir(&audit_dir) {
        let mut receipts: Vec<PathBuf> = rd.flatten().map(|e| e.path())
            .filter(|p| p.file_name().map_or(false, |n| n.to_string_lossy().ends_with("-index-receipt.json")))
            .collect();
        receipts.sort();
        for p in receipts {
            if let Ok(h) = sha256_file(&p) {
                let status = match verify_file(repo_root, &p) {
                    VerifyOutcome::Verified { .. } => "ML-DSA-65 verified".to_string(),
                    VerifyOutcome::Unsigned(r) => format!("unsigned: {r}"),
                    VerifyOutcome::Invalid(r) => format!("invalid: {r}"),
                };
                items.push(Item { kind: "data", name: rel(repo_root, &p), sha256: h, props: vec![("ainish:signature".into(), status)] });
            }
        }
    }
    items
}

fn signer_fpr(repo_root: &Path) -> Option<String> {
    load_anchor(repo_root).ok().map(|pk| fingerprint(&pk.into_bytes()))
}

pub fn build_cyclonedx(repo_root: &Path, model_manifest: &Path, llama_bin: Option<&Path>) -> Value {
    let repo_name = repo_root.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_else(|| "repository".into());
    let components: Vec<Value> = collect_items(repo_root, model_manifest, llama_bin).into_iter().enumerate().map(|(i, it)| {
        let mut c = json!({
            "type": it.kind,
            "bom-ref": format!("ainish:{}:{}", it.kind, i),
            "name": it.name,
            "hashes": [{ "alg": "SHA-256", "content": it.sha256 }],
        });
        if !it.props.is_empty() {
            c["properties"] = Value::Array(it.props.into_iter().map(|(n, v)| json!({"name": n, "value": v})).collect());
        }
        c
    }).collect();
    json!({
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        "serialNumber": format!("urn:uuid:{}", uuid_v4()),
        "version": 1,
        "metadata": {
            "timestamp": chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Secs, true),
            "tools": { "components": [{ "type": "application", "name": "ainish-rag", "version": env!("CARGO_PKG_VERSION") }] },
            "component": { "type": "application", "bom-ref": "ainish:root", "name": repo_name },
        },
        "components": components,
        "properties": [
            { "name": "ainish:signature:alg", "value": "ML-DSA-65 (FIPS 204), detached envelope" },
            { "name": "ainish:signature:context", "value": String::from_utf8_lossy(SIG_CONTEXT) },
            { "name": "ainish:signature:signer-fingerprint", "value": signer_fpr(repo_root).unwrap_or_else(|| "none".into()) },
        ],
    })
}

pub fn build_spdx3(repo_root: &Path, model_manifest: &Path, llama_bin: Option<&Path>) -> Value {
    let repo_name = repo_root.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_else(|| "repository".into());
    let doc_id = format!("urn:ainish:spdx:{}", uuid_v4());
    let ci = "_:creationinfo";
    let mut graph = vec![
        json!({ "type": "CreationInfo", "@id": ci, "specVersion": "3.0.1",
                "created": chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Secs, true),
                "createdBy": [format!("{doc_id}#agent")], "createdUsing": [format!("{doc_id}#tool")] }),
        json!({ "type": "SoftwareAgent", "spdxId": format!("{doc_id}#agent"), "creationInfo": ci, "name": "ainish-rag" }),
        json!({ "type": "Tool", "spdxId": format!("{doc_id}#tool"), "creationInfo": ci, "name": format!("ainish-rag {}", env!("CARGO_PKG_VERSION")) }),
    ];
    let mut element_ids = Vec::new();
    for (i, it) in collect_items(repo_root, model_manifest, llama_bin).into_iter().enumerate() {
        let id = format!("{doc_id}#e{i}");
        let purpose = match it.kind { "machine-learning-model" => "model", "application" => "application", "data" => "data", _ => "file" };
        let mut el = json!({
            "type": "software_File", "spdxId": id, "creationInfo": ci, "name": it.name,
            "software_primaryPurpose": purpose,
            "verifiedUsing": [{ "type": "Hash", "algorithm": "sha256", "hashValue": it.sha256 }],
        });
        if !it.props.is_empty() {
            el["comment"] = Value::String(it.props.iter().map(|(n, v)| format!("{n}={v}")).collect::<Vec<_>>().join("; "));
        }
        element_ids.push(id);
        graph.push(el);
    }
    graph.push(json!({
        "type": "SpdxDocument", "spdxId": doc_id, "creationInfo": ci,
        "name": format!("{repo_name} ainish-rag supply-chain SBOM"),
        "comment": format!("Detached ML-DSA-65 (FIPS 204) envelope; signer fingerprint {}", signer_fpr(repo_root).unwrap_or_else(|| "none".into())),
        "element": element_ids.clone(), "rootElement": element_ids,
    }));
    json!({ "@context": "https://spdx.org/rdf/3.0.1/spdx-context.jsonld", "@graph": graph })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mldsa65_roundtrip_and_tamper_detection() {
        let (pk, sk) = ml_dsa_65::KG::keygen_from_seed(&[7u8; 32]);
        let msg = b"receipt";
        let sig = sk.try_sign(msg, SIG_CONTEXT).unwrap();
        assert!(pk.verify(msg, &sig, SIG_CONTEXT));
        assert!(!pk.verify(b"receipT", &sig, SIG_CONTEXT));
        assert!(!pk.verify(msg, &sig, b"other-context"));
    }

    #[test]
    fn lockfile_pinning_detection() {
        assert!(hash_pinned("Cargo.lock", "checksum = \"ab\""));
        assert!(!hash_pinned("requirements.txt", "requests==2.0"));
        assert!(hash_pinned("requirements.txt", "requests==2.0 --hash=sha256:ab"));
    }
}
