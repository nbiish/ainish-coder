//! pqc-vault — OS-independent PQC vault core (Phase 1).
//!
//! The vault is the canonical identity root: a self-contained, passphrase-wrapped
//! PQC store with **no reliance on any OS security machinery** (keychain, Secure
//! Enclave, DPAPI, Secret Service). Encryption at rest is provided entirely by
//! FIPS-final post-quantum primitives + AES-256-GCM + Argon2id:
//!
//! ```text
//! passphrase ──Argon2id(salt, m/t/p)──▶ 32-byte vault KEK (memory-only, zeroized)
//!                                          │ AES-256-GCM wrap (AAD-bound)
//!            ┌─────────────────────────────┴────────────────────────────┐
//!            ▼                                                          ▼
//!   ML-KEM-768 seed (64 B d‖z)                                ML-DSA-65 seed (32 B ξ)
//! ```
//!
//! Store: `~/.config/pqc-secrets/vault.pqc` (0600 JSON; honors PQC_CONFIG_DIR).
//! Public material (expanded EK fingerprint + DSA verification key) lives in the
//! clear header so `verify` and `audit-verify` never need the passphrase.
//!
//! Session cache: `vault unlock` derives the KEK once and hands it to a hidden
//! `_vault-holder` child process via a stdin pipe (never argv/env/disk). The
//! holder serves unwrap requests over a Unix socket in a 0700 directory and
//! zeroizes on lock, TTL expiry, or drop. `--no-cache` runs stateless.
//! POSIX-only; `--no-cache` is the portable path.
//!
//! Keychain demotion: when a vault exists it wins; the OS keychain is an
//! opt-in convenience (`--use-keychain`) and is never touched by vault code.
//! `vault migrate` is the one-time keychain → vault move with rollback gates
//! and never deletes keychain material (operator deletes manually).
//!
//! Audit chain: `CHAIN1` JSON lines appended to the existing `audit.log`;
//! each record binds prev_hash + ts + seq + action + detail, commits to
//! `this_hash = SHA3-256(...)`, and is ML-DSA-65-signed. Every record is
//! signed; verifying operations are read-only and never append.
//!
//! Fingerprint rule: fingerprints are `sha3:<16 hex prefix of SHA3-256>`.
//! Key/seed material is never printed, logged, or written outside the vault.

use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use argon2::{Algorithm, Argon2, Params, Version};
use base64::prelude::*;
use ml_dsa::{EncodedVerifyingKey, Keypair, MlDsa65, Signature, SignatureEncoding, SigningKey, Signer, Verifier};
use ml_dsa::Seed as DsaSeed;
use ml_kem::kem::{Decapsulate, FromSeed, KeyExport};
use ml_kem::{MlKem768, Seed as KemSeedArr};
use serde::{Deserialize, Serialize};
use sha3::{Digest, Sha3_256};
use zeroize::{Zeroize, Zeroizing};

use crate::{
    decrypt_aesgcm, derive_kek, encrypt_aesgcm, ensure_parent_dir, expand_user_path, keychain_account,
    now_utc, sha3_256, shell_quote, PayloadSection, PublicKeyFile, BUNDLE_VERSION, DEFAULT_SERVICE,
    SEED_LEN,
};

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const VAULT_VERSION: u32 = 1;
const VAULT_FILE: &str = "vault.pqc";
const AUDIT_FILE: &str = "audit.log";
const SIG_ALG: &str = "ML-DSA-65";
const VAULT_ENGINE: &str = "rust-vault-core";

const KEM_SEED_AAD: &[u8] = b"pqc-secrets:vault:v1:kem-seed";
const DSA_SEED_AAD: &[u8] = b"pqc-secrets:vault:v1:dsa-seed";

/// FIPS 204 ML-DSA seed (ξ) length. NOTE: FIPS 204 defines the ML-DSA seed as
/// 32 bytes — the 64-byte `d‖z` convention is ML-KEM-specific (FIPS 203).
const DSA_SEED_LEN: usize = 32;
/// ML-DSA-65 expanded verification key length (FIPS 204 pkEncode).
const DSA_VK_LEN: usize = 1952;
/// Argon2id salt length.
const SALT_LEN: usize = 16;
/// AES-GCM nonce length.
const NONCE_LEN: usize = 12;

/// Default Argon2id parameters: repo SKILL.md §4 row (t=3, m=64 MiB, p=4) —
/// stricter than the OWASP 2025 minimum (m=19 MiB, t=2, p=1).
const KDF_M_COST_KIB: u32 = 65_536;
const KDF_T_COST: u32 = 3;
const KDF_P_COST: u32 = 4;
const KDF_OUT_LEN: usize = 32;

/// Default session TTL: 15 minutes.
const DEFAULT_TTL_SECS: u64 = 900;

/// Hidden subcommand that runs the in-memory session holder.
pub(crate) const HOLDER_ARG: &str = "_vault-holder";
/// Test-only KDF lightener (never set in production). Keeps `cargo test` fast
/// while production defaults stay 64 MiB / t=3 / p=4. Parameters are recorded
/// in the vault header, so light-test vaults remain format-compatible.
const TEST_KDF_LIGHT_ENV: &str = "PQC_VAULT_TEST_KDF_LIGHT";

const CHAIN_PREFIX: &str = "CHAIN1";
const GENESIS_HASH: &str = "0000000000000000000000000000000000000000000000000000000000000000";

fn short_fp(hex64: &str) -> String {
    format!("sha3:{}", &hex64[..16.min(hex64.len())])
}

fn b64(data: &[u8]) -> String {
    BASE64_STANDARD.encode(data)
}

// ---------------------------------------------------------------------------
// Vault file format (vault.pqc, 0600)
// ---------------------------------------------------------------------------

#[derive(Serialize, Deserialize, Debug)]
struct VaultHeader {
    version: u32,
    alg: String,
    sig_alg: String,
    engine: String,
    created_utc: String,
    kdf: VaultKdf,
    identity: VaultIdentity,
    kem_seed: WrappedBlob,
    dsa_seed: WrappedBlob,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct VaultKdf {
    name: String,
    salt_b64: String,
    m_cost_kib: u32,
    t_cost: u32,
    p_cost: u32,
    output_len: u32,
}

#[derive(Serialize, Deserialize, Debug)]
struct VaultIdentity {
    /// SHA3-256 hex (64 chars) of the expanded ML-KEM-768 encapsulation key.
    kem_pub_sha3_256: String,
    /// ML-DSA-65 verification key (public material) — enables keychain-free
    /// and passphrase-free `verify` / `audit-verify`.
    dsa_pub_b64: String,
    /// SHA3-256 hex of the encoded verification key.
    dsa_pub_sha3_256: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct WrappedBlob {
    aad: String,
    nonce_b64: String,
    ciphertext_b64: String,
}

pub fn config_dir() -> PathBuf {
    match std::env::var_os("PQC_CONFIG_DIR") {
        Some(v) => PathBuf::from(v),
        None => PathBuf::from(expand_user_path("~/.config/pqc-secrets")),
    }
}

fn vault_path() -> PathBuf {
    config_dir().join(VAULT_FILE)
}

fn audit_log_path() -> PathBuf {
    config_dir().join(AUDIT_FILE)
}

pub(crate) fn vault_exists() -> bool {
    vault_path().exists()
}

fn ensure_config_dir() -> Result<(), String> {
    let dir = config_dir();
    std::fs::create_dir_all(&dir).map_err(|e| format!("cannot create config dir {:?}: {}", dir, e))?;
    std::fs::set_permissions(&dir, std::fs::Permissions::from_mode(0o700))
        .map_err(|e| format!("cannot chmod 700 config dir: {}", e))?;
    Ok(())
}

fn load_vault() -> Result<VaultHeader, String> {
    let path = vault_path();
    let raw = std::fs::read_to_string(&path)
        .map_err(|_| format!("vault not found at {:?} — run `pqc-secrets vault init` (or `vault migrate`)", path))?;
    let header: VaultHeader = serde_json::from_str(&raw).map_err(|e| format!("vault corrupt: {}", e))?;
    if header.version != VAULT_VERSION {
        return Err(format!("unsupported vault version {}", header.version));
    }
    if header.alg != crate::ALG || header.sig_alg != SIG_ALG {
        return Err(format!("unsupported vault algorithms: {} / {}", header.alg, header.sig_alg));
    }
    Ok(header)
}

/// Atomically write the vault file with 0600 permissions (temp + rename).
fn save_vault(header: &VaultHeader) -> Result<(), String> {
    ensure_config_dir()?;
    let path = vault_path();
    let tmp = path.with_extension("pqc.tmp");
    let json = serde_json::to_string_pretty(header).map_err(|e| format!("vault serialize: {}", e))?;
    {
        let mut f = std::fs::File::create(&tmp).map_err(|e| format!("vault write: {}", e))?;
        f.write_all(json.as_bytes()).map_err(|e| format!("vault write: {}", e))?;
        f.sync_all().ok();
    }
    std::fs::set_permissions(&tmp, std::fs::Permissions::from_mode(0o600))
        .map_err(|e| format!("vault chmod: {}", e))?;
    std::fs::rename(&tmp, &path).map_err(|e| format!("vault rename: {}", e))?;
    Ok(())
}

// ---------------------------------------------------------------------------
// Crypto: Argon2id KEK + blob wrap/unwrap + identity expansion
// ---------------------------------------------------------------------------

/// Derive the 32-byte vault KEK from the header KDF params + passphrase.
/// All intermediate material lives in Zeroizing buffers.
fn derive_kek_argon2(kdf: &VaultKdf, passphrase: &[u8]) -> Result<Zeroizing<[u8; KDF_OUT_LEN]>, String> {
    if kdf.name != "argon2id" {
        return Err(format!("unsupported vault KDF: {}", kdf.name));
    }
    let salt = BASE64_STANDARD
        .decode(kdf.salt_b64.trim())
        .map_err(|e| format!("vault KDF salt corrupt: {}", e))?;
    if salt.len() < SALT_LEN {
        return Err("vault KDF salt too short".to_string());
    }
    let params = Params::new(kdf.m_cost_kib, kdf.t_cost, kdf.p_cost, Some(KDF_OUT_LEN))
        .map_err(|e| format!("vault KDF params invalid: {}", e))?;
    let argon = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
    let mut out = Zeroizing::new([0u8; KDF_OUT_LEN]);
    argon
        .hash_password_into(passphrase, &salt, &mut out[..])
        .map_err(|e| format!("argon2id derivation failed: {}", e))?;
    Ok(out)
}

fn default_kdf() -> VaultKdf {
    // Test-only lightener keeps `cargo test` fast; production defaults are
    // unchanged (and each vault records its own params in the header).
    let light = std::env::var(TEST_KDF_LIGHT_ENV).as_deref() == Ok("1");
    let mut salt = [0u8; SALT_LEN];
    getrandom::fill(&mut salt).expect("OS CSPRNG unavailable");
    VaultKdf {
        name: "argon2id".to_string(),
        salt_b64: b64(&salt),
        m_cost_kib: if light { 8_192 } else { KDF_M_COST_KIB },
        t_cost: if light { 1 } else { KDF_T_COST },
        p_cost: if light { 1 } else { KDF_P_COST },
        output_len: KDF_OUT_LEN as u32,
    }
}

fn wrap_blob(kek: &[u8; KDF_OUT_LEN], plaintext: &[u8], aad: &[u8]) -> Result<WrappedBlob, String> {
    let mut nonce = [0u8; NONCE_LEN];
    getrandom::fill(&mut nonce).map_err(|e| format!("CSPRNG: {}", e))?;
    let ciphertext = encrypt_aesgcm(kek, &nonce, plaintext, aad)?;
    Ok(WrappedBlob {
        aad: String::from_utf8_lossy(aad).to_string(),
        nonce_b64: b64(&nonce),
        ciphertext_b64: b64(&ciphertext),
    })
}

fn unwrap_blob(kek: &[u8; KDF_OUT_LEN], blob: &WrappedBlob, expected_aad: &[u8]) -> Result<Zeroizing<Vec<u8>>, String> {
    if blob.aad.as_bytes() != expected_aad {
        return Err("vault blob AAD mismatch (fail closed)".to_string());
    }
    let nonce = BASE64_STANDARD
        .decode(blob.nonce_b64.trim())
        .map_err(|e| format!("vault blob nonce corrupt: {}", e))?;
    let ciphertext = BASE64_STANDARD
        .decode(blob.ciphertext_b64.trim())
        .map_err(|e| format!("vault blob ciphertext corrupt: {}", e))?;
    let plaintext = decrypt_aesgcm(kek, &nonce, &ciphertext, expected_aad)
        .map_err(|_| "vault unwrap failed (wrong passphrase or tampered vault)".to_string())?;
    Ok(Zeroizing::new(plaintext))
}

/// Unwrapped identity, memory-only. Seeds zeroize on drop.
struct UnwrappedIdentity {
    kem_seed: Zeroizing<[u8; SEED_LEN]>,
    dsa_seed: Zeroizing<[u8; DSA_SEED_LEN]>,
}

impl std::fmt::Debug for UnwrappedIdentity {
    /// Deliberately prints only lengths — seed material must never be logged.
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("UnwrappedIdentity")
            .field("kem_seed_len", &self.kem_seed.len())
            .field("dsa_seed_len", &self.dsa_seed.len())
            .finish()
    }
}

impl UnwrappedIdentity {
    /// Expanded ML-KEM-768 encapsulation key (1184 bytes).
    fn kem_pub(&self) -> Result<Zeroizing<Vec<u8>>, String> {
        let seed_arr: [u8; SEED_LEN] = *self.kem_seed;
        let seed = KemSeedArr::from(seed_arr);
        let (_dk, ek) = MlKem768::from_seed(&seed);
        let bytes = ek.to_bytes();
        Ok(Zeroizing::new(bytes.as_slice().to_vec()))
    }

    /// ML-DSA-65 signing key expanded from the wrapped seed.
    fn signing_key(&self) -> Result<SigningKey<MlDsa65>, String> {
        let seed_arr: [u8; DSA_SEED_LEN] = *self.dsa_seed;
        let seed = DsaSeed::from(seed_arr);
        Ok(SigningKey::<MlDsa65>::from_seed(&seed))
    }

    /// ML-DSA-65 verification key (encoded, DSA_VK_LEN bytes).
    fn dsa_pub(&self) -> Result<Zeroizing<Vec<u8>>, String> {
        let vk = self.signing_key()?.verifying_key();
        Ok(Zeroizing::new(vk.encode().to_vec()))
    }
}

fn dsa_vk_from_bytes(vk_bytes: &[u8]) -> Result<ml_dsa::VerifyingKey<MlDsa65>, String> {
    if vk_bytes.len() != DSA_VK_LEN {
        return Err(format!(
            "verification key has wrong length: {} (expected {})",
            vk_bytes.len(),
            DSA_VK_LEN
        ));
    }
    // Fail closed on wrong length before conversion.
    let enc = EncodedVerifyingKey::<MlDsa65>::try_from(vk_bytes)
        .map_err(|e| format!("verification key decode failed: {}", e))?;
    Ok(ml_dsa::VerifyingKey::<MlDsa65>::decode(&enc))
}

// ---------------------------------------------------------------------------
// Passphrase handling
// ---------------------------------------------------------------------------

/// Read the vault passphrase: PQC_VAULT_PASSPHRASE env (non-interactive /
/// scripted use; never persisted) or an interactive /dev/tty prompt.
fn read_passphrase(confirm: bool) -> Result<String, String> {
    if let Ok(p) = std::env::var("PQC_VAULT_PASSPHRASE") {
        return Ok(p);
    }
    let pass = rpassword::prompt_password("Vault passphrase: ")
        .map_err(|e| format!("passphrase prompt failed: {}", e))?;
    if confirm {
        let again = rpassword::prompt_password("Confirm passphrase: ")
            .map_err(|e| format!("passphrase prompt failed: {}", e))?;
        if pass != again {
            return Err("passphrases do not match".to_string());
        }
    }
    Ok(pass)
}

/// Get the unwrapped identity: session holder first (no re-derivation), else
/// derive the KEK from the passphrase (env / prompt) and unwrap in-memory.
fn obtain_identity() -> Result<UnwrappedIdentity, String> {
    if let Some(resp) = session_request(&HolderReq::Unwrap)
        && resp.ok
        && let (Some(kem_hex), Some(dsa_hex)) = (resp.kem_seed_hex, resp.dsa_seed_hex)
    {
        let kem = Zeroizing::new(hex::decode(&kem_hex).map_err(|_| "holder returned corrupt kem seed")?);
        let dsa = Zeroizing::new(hex::decode(&dsa_hex).map_err(|_| "holder returned corrupt dsa seed")?);
        let mut kem_arr = Zeroizing::new([0u8; SEED_LEN]);
        kem_arr.copy_from_slice(&kem);
        let mut dsa_arr = Zeroizing::new([0u8; DSA_SEED_LEN]);
        dsa_arr.copy_from_slice(&dsa);
        return Ok(UnwrappedIdentity { kem_seed: kem_arr, dsa_seed: dsa_arr });
        // Holder present but rejected (e.g. vault replaced) → fall through to
        // the passphrase path; holder seed material is never surfaced.
    }
    let header = load_vault()?;
    let mut pass = read_passphrase(false)?;
    let kek = derive_kek_argon2(&header.kdf, pass.as_bytes())?;
    pass.zeroize();
    let kem = unwrap_blob(&kek, &header.kem_seed, KEM_SEED_AAD)?;
    let dsa = unwrap_blob(&kek, &header.dsa_seed, DSA_SEED_AAD)?;
    let mut kem_arr = Zeroizing::new([0u8; SEED_LEN]);
    kem_arr.copy_from_slice(&kem);
    let mut dsa_arr = Zeroizing::new([0u8; DSA_SEED_LEN]);
    dsa_arr.copy_from_slice(&dsa);
    Ok(UnwrappedIdentity { kem_seed: kem_arr, dsa_seed: dsa_arr })
}

// ---------------------------------------------------------------------------
// Session holder (in-memory TTL cache; POSIX Unix-socket IPC)
// ---------------------------------------------------------------------------

#[derive(Serialize, Deserialize)]
enum HolderReq {
    Status,
    Unwrap,
    Lock,
}

#[derive(Serialize, Deserialize, Default)]
struct HolderResp {
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    remaining: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    kem_fp: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    dsa_fp: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    kem_seed_hex: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    dsa_seed_hex: Option<String>,
}

fn session_socket_dir() -> Result<PathBuf, String> {
    let dir_hash = hex::encode(&sha3_256(config_dir().to_string_lossy().as_bytes())[..6]);
    Ok(std::env::temp_dir().join(format!("pqc-vault-sess-{}", dir_hash)))
}

fn session_socket_path() -> Result<PathBuf, String> {
    Ok(session_socket_dir()?.join("session.sock"))
}

/// One request/response exchange over the session socket. Connection failures
/// map to None (no active session) — never to stored material.
fn session_request(req: &HolderReq) -> Option<HolderResp> {
    let path = session_socket_path().ok()?;
    let mut stream = UnixStream::connect(path).ok()?;
    stream.set_read_timeout(Some(Duration::from_secs(5))).ok()?;
    stream.set_write_timeout(Some(Duration::from_secs(5))).ok()?;
    let line = serde_json::to_string(req).ok()?;
    stream.write_all(line.as_bytes()).ok()?;
    stream.write_all(b"\n").ok()?;
    let mut reader = BufReader::new(stream);
    let mut resp_line = String::new();
    reader.read_line(&mut resp_line).ok()?;
    serde_json::from_str(resp_line.trim()).ok()
}

/// Query the session; returns remaining TTL seconds when unlocked.
fn session_status() -> Option<u64> {
    let resp = session_request(&HolderReq::Status)?;
    if resp.ok { resp.remaining } else { None }
}

/// The holder body: holds ONLY the KEK in process memory, serves
/// status/unwrap/lock over the socket, zeroizes on lock/TTL/drop.
fn holder_serve_with_kek(kek: Zeroizing<[u8; KDF_OUT_LEN]>, ttl_secs: u64) -> Result<(), String> {
    let sock_dir = session_socket_dir()?;
    std::fs::create_dir_all(&sock_dir).map_err(|e| format!("holder: socket dir: {}", e))?;
    std::fs::set_permissions(&sock_dir, std::fs::Permissions::from_mode(0o700))
        .map_err(|e| format!("holder: socket dir chmod: {}", e))?;
    let sock_path = sock_dir.join("session.sock");
    let _ = std::fs::remove_file(&sock_path);
    let listener = UnixListener::bind(&sock_path).map_err(|e| format!("holder: bind: {}", e))?;
    listener
        .set_nonblocking(true)
        .map_err(|e| format!("holder: nonblocking: {}", e))?;

    let deadline = Instant::now() + Duration::from_secs(ttl_secs);
    let mut locked_cleanly = false;

    loop {
        if Instant::now() >= deadline {
            // TTL expiry: best-effort signed audit record, then zeroize.
            if let Ok(header) = load_vault() {
                let _ = holder_audit_append(&header, &kek, "vault-ttl-expire", &format!("ttl={}s", ttl_secs));
            }
            break;
        }
        match listener.accept() {
            Ok((mut stream, _)) => {
                let _ = stream.set_read_timeout(Some(Duration::from_secs(5)));
                let mut line = String::new();
                {
                    let mut reader = BufReader::new(&stream);
                    if reader.read_line(&mut line).is_err() {
                        continue;
                    }
                }
                let req: HolderReq = match serde_json::from_str(line.trim()) {
                    Ok(r) => r,
                    Err(_) => continue,
                };
                let resp = match req {
                    HolderReq::Status => {
                        let remaining = deadline.saturating_duration_since(Instant::now()).as_secs();
                        match load_vault() {
                            Ok(header) => HolderResp {
                                ok: true,
                                remaining: Some(remaining),
                                kem_fp: Some(short_fp(&header.identity.kem_pub_sha3_256)),
                                dsa_fp: Some(short_fp(&header.identity.dsa_pub_sha3_256)),
                                ..Default::default()
                            },
                            Err(e) => HolderResp { ok: false, error: Some(e), ..Default::default() },
                        }
                    }
                    HolderReq::Unwrap => {
                        let remaining = deadline.saturating_duration_since(Instant::now()).as_secs();
                        match load_vault().and_then(|header| {
                            let kem = unwrap_blob(&kek, &header.kem_seed, KEM_SEED_AAD)?;
                            let dsa = unwrap_blob(&kek, &header.dsa_seed, DSA_SEED_AAD)?;
                            Ok((header, kem, dsa))
                        }) {
                            Ok((header, kem, dsa)) => HolderResp {
                                ok: true,
                                remaining: Some(remaining),
                                kem_fp: Some(short_fp(&header.identity.kem_pub_sha3_256)),
                                dsa_fp: Some(short_fp(&header.identity.dsa_pub_sha3_256)),
                                kem_seed_hex: Some(hex::encode(kem.as_slice())),
                                dsa_seed_hex: Some(hex::encode(dsa.as_slice())),
                                ..Default::default()
                            },
                            Err(e) => HolderResp { ok: false, error: Some(e), ..Default::default() },
                        }
                    }
                    HolderReq::Lock => {
                        if let Ok(header) = load_vault() {
                            let _ = holder_audit_append(&header, &kek, "vault-lock", "by=request");
                        }
                        locked_cleanly = true;
                        HolderResp { ok: true, ..Default::default() }
                    }
                };
                let out = serde_json::to_string(&resp).unwrap_or_else(|_| "{\"ok\":false}".to_string());
                let _ = stream.write_all(out.as_bytes());
                let _ = stream.write_all(b"\n");
                let _ = stream.flush();
                if locked_cleanly {
                    break;
                }
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                std::thread::sleep(Duration::from_millis(200));
            }
            Err(_) => break,
        }
    }

    let _ = std::fs::remove_file(&sock_path);
    drop(listener);
    drop(kek); // Zeroizing wipes the KEK here.
    Ok(())
}

/// Append a signed audit record using the holder's held KEK (unwrap → sign).
fn holder_audit_append(header: &VaultHeader, kek: &[u8; KDF_OUT_LEN], action: &str, detail: &str) -> Result<(), String> {
    let dsa = unwrap_blob(kek, &header.dsa_seed, DSA_SEED_AAD)?;
    let mut arr = Zeroizing::new([0u8; DSA_SEED_LEN]);
    arr.copy_from_slice(&dsa);
    let identity = UnwrappedIdentity { kem_seed: Zeroizing::new([0u8; SEED_LEN]), dsa_seed: arr };
    let sk = identity.signing_key()?;
    audit_chain_append(action, detail, &sk)
}

/// Spawn the hidden holder child; KEK crosses via stdin pipe only.
fn spawn_holder(kek: &Zeroizing<[u8; KDF_OUT_LEN]>, ttl_secs: u64) -> Result<(), String> {
    use std::process::{Command, Stdio};
    let exe = std::env::current_exe().map_err(|e| format!("current_exe: {}", e))?;
    let mut child = Command::new(exe)
        .args([HOLDER_ARG, &ttl_secs.to_string()])
        .stdin(std::process::Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| format!("holder spawn: {}", e))?;
    {
        let mut stdin = child.stdin.take().ok_or("holder stdin unavailable")?;
        stdin.write_all(kek.as_slice()).map_err(|e| format!("holder KEK pipe: {}", e))?;
        // stdin dropped here → holder proceeds with KEK in memory only.
    }
    // Wait for the socket to answer.
    for _ in 0..50 {
        if child.try_wait().map_err(|e| format!("holder wait: {}", e))?.is_some() {
            return Err("holder exited immediately (refusing to serve)".to_string());
        }
        if session_request(&HolderReq::Status).map(|r| r.ok).unwrap_or(false) {
            return Ok(());
        }
        std::thread::sleep(Duration::from_millis(100));
    }
    let _ = child.kill();
    Err("holder failed to become ready in 5s".to_string())
}

fn parse_ttl(raw: Option<&String>) -> Result<u64, String> {
    let Some(text) = raw else { return Ok(DEFAULT_TTL_SECS) };
    let text = text.trim();
    let (digits, mult) = match text.chars().last() {
        Some('s') => (&text[..text.len() - 1], 1u64),
        Some('m') => (&text[..text.len() - 1], 60),
        Some('h') => (&text[..text.len() - 1], 3600),
        _ => (text, 1),
    };
    digits
        .parse::<u64>()
        .map(|n| n.saturating_mul(mult))
        .map_err(|_| format!("invalid --ttl value: {} (use seconds, or Ns/Nm/Nh)", text))
}

// ---------------------------------------------------------------------------
// Audit hash chain (signed)
// ---------------------------------------------------------------------------

#[derive(Serialize, Deserialize, Debug)]
struct ChainRecord {
    v: u32,
    seq: u64,
    prev_hash: String,
    ts: String,
    actor: String,
    action: String,
    detail: String,
    this_hash: String,
    sig_b64: String,
}

fn chain_hash(prev_hash: &str, ts: &str, seq: u64, action: &str, detail: &str) -> [u8; 32] {
    let mut hasher = Sha3_256::new();
    hasher.update(CHAIN_PREFIX.as_bytes());
    hasher.update(prev_hash.as_bytes());
    hasher.update(b"|");
    hasher.update(ts.as_bytes());
    hasher.update(b"|");
    hasher.update(seq.to_string().as_bytes());
    hasher.update(b"|");
    hasher.update(action.as_bytes());
    hasher.update(b"|");
    hasher.update(detail.as_bytes());
    hasher.finalize().into()
}

/// Read the current chain head: (next_seq, prev_hash).
fn audit_chain_head() -> Result<(u64, String), String> {
    let path = audit_log_path();
    if !path.exists() {
        return Ok((0, GENESIS_HASH.to_string()));
    }
    let raw = std::fs::read_to_string(&path).map_err(|e| format!("audit read: {}", e))?;
    let mut head: Option<(u64, String)> = None;
    for line in raw.lines() {
        if let Some(json) = line.strip_prefix(&format!("{}\t", CHAIN_PREFIX)) {
            let rec: ChainRecord =
                serde_json::from_str(json).map_err(|e| format!("audit chain corrupt (unparseable record): {}", e))?;
            head = Some((rec.seq + 1, rec.this_hash));
        }
    }
    Ok(head.unwrap_or((0, GENESIS_HASH.to_string())))
}

/// Append one signed record to the audit chain. Requires the signing identity
/// (every appending op holds it); verifying ops never append.
fn audit_chain_append(action: &str, detail: &str, sk: &SigningKey<MlDsa65>) -> Result<(), String> {
    let (seq, prev_hash) = audit_chain_head()?;
    let ts = now_utc();
    let this_hash = chain_hash(&prev_hash, &ts, seq, action, detail);
    let sig = sk.sign(&this_hash);
    let rec = ChainRecord {
        v: 1,
        seq,
        prev_hash,
        ts,
        actor: VAULT_ENGINE.to_string(),
        action: action.to_string(),
        detail: detail.to_string(),
        this_hash: hex::encode(this_hash),
        sig_b64: b64(&sig.to_vec()),
    };
    let line = format!("{}\t{}\n", CHAIN_PREFIX, serde_json::to_string(&rec).map_err(|e| e.to_string())?);
    let path = audit_log_path();
    ensure_parent_dir(&path).map_err(|e| format!("audit dir: {}", e))?;
    let mut f = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
        .map_err(|e| format!("audit open: {}", e))?;
    f.write_all(line.as_bytes()).map_err(|e| format!("audit write: {}", e))?;
    std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o600))
        .map_err(|e| format!("audit chmod: {}", e))?;
    Ok(())
}

/// Replay and verify the whole chain: hash links + per-record ML-DSA-65
/// signatures against the vault's pinned verification key. Fail-closed.
fn cmd_audit_verify() -> Result<(), String> {
    let header = load_vault()?;
    let vk_bytes = BASE64_STANDARD
        .decode(header.identity.dsa_pub_b64.trim())
        .map_err(|e| format!("vault vk corrupt: {}", e))?;
    let vk = dsa_vk_from_bytes(&vk_bytes)?;
    let path = audit_log_path();
    let raw = std::fs::read_to_string(&path).map_err(|_| format!("no audit log at {:?}", path))?;

    let mut legacy_lines: usize = 0;
    let mut chain: Vec<ChainRecord> = Vec::new();
    for (idx, line) in raw.lines().enumerate() {
        if line.is_empty() {
            continue;
        }
        match line.strip_prefix(&format!("{}\t", CHAIN_PREFIX)) {
            Some(json) => {
                let rec: ChainRecord = serde_json::from_str(json)
                    .map_err(|_| format!("chain record at line {} is corrupt (fail closed)", idx + 1))?;
                chain.push(rec);
            }
            None => legacy_lines += 1,
        }
    }

    let mut prev_hash = GENESIS_HASH.to_string();
    for (expected_seq, rec) in (0_u64..).zip(chain.iter()) {
        if rec.seq != expected_seq {
            return Err(format!(
                "audit chain broken at seq {} (expected {}) — sequence gap or reorder",
                rec.seq, expected_seq
            ));
        }
        if rec.prev_hash != prev_hash {
            return Err(format!("audit chain broken at seq {}: prev_hash mismatch", rec.seq));
        }
        if rec.v != 1 {
            return Err(format!("audit chain record seq {} has unknown version {}", rec.seq, rec.v));
        }
        let expect_hash = chain_hash(&rec.prev_hash, &rec.ts, rec.seq, &rec.action, &rec.detail);
        if hex::encode(expect_hash) != rec.this_hash {
            return Err(format!(
                "audit chain TAMPERED at seq {}: this_hash mismatch (record content modified)",
                rec.seq
            ));
        }
        let sig_bytes = BASE64_STANDARD
            .decode(rec.sig_b64.trim())
            .map_err(|_| format!("audit record seq {} has corrupt signature", rec.seq))?;
        let sig = Signature::<MlDsa65>::try_from(sig_bytes.as_slice())
            .map_err(|_| format!("audit record seq {} signature undecodable", rec.seq))?;
        vk.verify(&expect_hash, &sig)
            .map_err(|_| format!("audit chain TAMPERED at seq {}: invalid ML-DSA-65 signature", rec.seq))?;
        prev_hash = rec.this_hash.clone();
    }

    println!(
        "audit-verify OK: {} signed record(s), {} legacy line(s), head={}",
        chain.len(),
        legacy_lines,
        short_fp(&prev_hash)
    );
    Ok(())
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

fn cmd_init(_rest: &[String]) -> Result<(), String> {
    if vault_exists() {
        return Err(format!(
            "vault already exists at {:?} — init is one-time (use `vault migrate` to adopt a keychain identity)",
            vault_path()
        ));
    }
    ensure_config_dir()?;

    // Fresh ML-KEM-768 identity (FIPS 203 seed form, 64-byte d‖z).
    let mut kem_seed = Zeroizing::new([0u8; SEED_LEN]);
    getrandom::fill(kem_seed.as_mut()).map_err(|e| format!("CSPRNG: {}", e))?;
    // Fresh ML-DSA-65 identity (FIPS 204 seed form, 32-byte ξ).
    let mut dsa_seed = Zeroizing::new([0u8; DSA_SEED_LEN]);
    getrandom::fill(dsa_seed.as_mut()).map_err(|e| format!("CSPRNG: {}", e))?;

    let identity = UnwrappedIdentity { kem_seed: kem_seed.clone(), dsa_seed: dsa_seed.clone() };
    let kem_pub = identity.kem_pub()?;
    let dsa_pub = identity.dsa_pub()?;
    let kem_fp_full = hex::encode(sha3_256(&kem_pub));
    let dsa_fp_full = hex::encode(sha3_256(&dsa_pub));

    let mut pass = read_passphrase(true)?;
    let kdf = default_kdf();
    let kek = derive_kek_argon2(&kdf, pass.as_bytes())?;
    pass.zeroize();

    let header = VaultHeader {
        version: VAULT_VERSION,
        alg: crate::ALG.to_string(),
        sig_alg: SIG_ALG.to_string(),
        engine: VAULT_ENGINE.to_string(),
        created_utc: now_utc(),
        identity: VaultIdentity {
            kem_pub_sha3_256: kem_fp_full.clone(),
            dsa_pub_b64: b64(&dsa_pub),
            dsa_pub_sha3_256: dsa_fp_full.clone(),
        },
        kem_seed: wrap_blob(&kek, kem_seed.as_slice(), KEM_SEED_AAD)?,
        dsa_seed: wrap_blob(&kek, dsa_seed.as_slice(), DSA_SEED_AAD)?,
        kdf,
    };
    save_vault(&header)?;

    let sk = identity.signing_key()?;
    audit_chain_append(
        "vault-init",
        &format!("kem-fp={}; dsa-fp={}", short_fp(&kem_fp_full), short_fp(&dsa_fp_full)),
        &sk,
    )?;

    println!("Vault created at {:?}", vault_path());
    println!(
        "  kdf:     argon2id m={}KiB t={} p={}",
        header.kdf.m_cost_kib, header.kdf.t_cost, header.kdf.p_cost
    );
    println!("  kem-fp:  {} (ML-KEM-768, FIPS 203 seed-form at rest)", short_fp(&kem_fp_full));
    println!("  dsa-fp:  {} (ML-DSA-65, FIPS 204 seed-form at rest)", short_fp(&dsa_fp_full));
    println!("Next: vault export-identity --pub-out ~/.config/pqc-secrets/recipient.pub  (then pack against it)");
    println!("      or: vault migrate  (adopt the existing keychain identity instead)");
    Ok(())
}

fn cmd_unlock(rest: &[String]) -> Result<(), String> {
    let mut no_cache = false;
    let mut ttl_raw: Option<&String> = None;
    let mut i = 0;
    while i < rest.len() {
        match rest[i].as_str() {
            "--no-cache" => no_cache = true,
            "--ttl" => {
                i += 1;
                ttl_raw = rest.get(i);
            }
            other => return Err(format!("vault unlock: unknown argument: {}", other)),
        }
        i += 1;
    }
    let ttl = parse_ttl(ttl_raw)?;

    let header = load_vault()?;

    // Already unlocked? Report, refresh nothing.
    if let Some(remaining) = session_status() {
        println!("Vault already unlocked (TTL remaining: {}s). Use `vault lock` to lock.", remaining);
        return Ok(());
    }

    let mut pass = read_passphrase(false)?;
    let kek = derive_kek_argon2(&header.kdf, pass.as_bytes())?;
    pass.zeroize();

    // Fail closed on wrong passphrase: GCM auth must succeed on the seed blobs.
    let kem = unwrap_blob(&kek, &header.kem_seed, KEM_SEED_AAD)?;
    let dsa = unwrap_blob(&kek, &header.dsa_seed, DSA_SEED_AAD)?;

    let kem_fp = short_fp(&header.identity.kem_pub_sha3_256);
    let dsa_fp = short_fp(&header.identity.dsa_pub_sha3_256);

    let mut kem_arr = Zeroizing::new([0u8; SEED_LEN]);
    kem_arr.copy_from_slice(&kem);
    let mut dsa_arr = Zeroizing::new([0u8; DSA_SEED_LEN]);
    dsa_arr.copy_from_slice(&dsa);
    let identity = UnwrappedIdentity { kem_seed: kem_arr, dsa_seed: dsa_arr };

    if no_cache {
        audit_chain_append("vault-unlock", "mode=no-cache", &identity.signing_key()?)?;
        println!("Vault passphrase verified (no-cache mode; nothing is cached).");
        println!("  kem-fp: {}", kem_fp);
        println!("  dsa-fp: {}", dsa_fp);
        return Ok(());
    }

    spawn_holder(&kek, ttl)?;
    audit_chain_append("vault-unlock", &format!("ttl={}s", ttl), &identity.signing_key()?)?;
    println!("Vault unlocked (session TTL: {}s).", ttl);
    println!("  kem-fp: {}", kem_fp);
    println!("  dsa-fp: {}", dsa_fp);
    Ok(())
}

fn cmd_lock(_rest: &[String]) -> Result<(), String> {
    match session_request(&HolderReq::Lock) {
        Some(resp) if resp.ok => {
            println!("Vault locked; session key material zeroized.");
            Ok(())
        }
        Some(resp) => Err(resp.error.unwrap_or_else(|| "lock failed".to_string())),
        None => {
            println!("No active session.");
            Ok(())
        }
    }
}

fn cmd_status(_rest: &[String]) -> Result<(), String> {
    if !vault_exists() {
        println!("vault:   none");
        println!("mode:    legacy (keychain / machine.kek file store)");
        println!("hint:    pqc-secrets vault init   |   pqc-secrets vault migrate");
        return Ok(());
    }
    let header = load_vault()?;
    println!("vault:   {:?}", vault_path());
    println!("alg:     {} + {}", header.alg, header.sig_alg);
    println!(
        "kdf:     argon2id m={}KiB t={} p={}",
        header.kdf.m_cost_kib, header.kdf.t_cost, header.kdf.p_cost
    );
    println!("kem-fp:  {}", short_fp(&header.identity.kem_pub_sha3_256));
    println!("dsa-fp:  {}", short_fp(&header.identity.dsa_pub_sha3_256));
    match session_status() {
        Some(remaining) => println!("session: unlocked (TTL remaining: {}s)", remaining),
        None => println!("session: locked"),
    }
    Ok(())
}

fn cmd_export_identity(rest: &[String]) -> Result<(), String> {
    let mut pub_out: Option<String> = None;
    let mut i = 0;
    while i < rest.len() {
        match rest[i].as_str() {
            "--pub-out" => {
                i += 1;
                pub_out = rest.get(i).cloned();
            }
            other => return Err(format!("vault export-identity: unknown argument: {}", other)),
        }
        i += 1;
    }

    let header = load_vault()?;
    let identity = obtain_identity()?;
    let kem_pub = identity.kem_pub()?;
    let kem_fp_full = hex::encode(sha3_256(&kem_pub));
    if kem_fp_full != header.identity.kem_pub_sha3_256 {
        return Err("unwrapped identity does not match vault header (fail closed)".to_string());
    }

    if let Some(raw) = pub_out {
        let path = PathBuf::from(expand_user_path(&raw));
        let pub_file = PublicKeyFile {
            alg: crate::ALG.to_string(),
            engine: VAULT_ENGINE.to_string(),
            public_key_b64: b64(&kem_pub),
            public_key_sha3_256: kem_fp_full.clone(),
            created_utc: now_utc(),
        };
        ensure_parent_dir(&path).map_err(|e| format!("pub-out dir: {}", e))?;
        let json = serde_json::to_string_pretty(&pub_file).map_err(|e| e.to_string())?;
        std::fs::write(&path, json).map_err(|e| format!("pub-out write: {}", e))?;
        println!("Public encapsulation key written to {:?} (safe to commit).", path);
    }

    println!("  kem-fp: {} (ML-KEM-768)", short_fp(&kem_fp_full));
    println!("  dsa-fp: {} (ML-DSA-65)", short_fp(&header.identity.dsa_pub_sha3_256));
    Ok(())
}

fn sig_path_for(file_path: &Path) -> PathBuf {
    PathBuf::from(format!("{}.sig", file_path.display()))
}

fn cmd_sign(rest: &[String]) -> Result<(), String> {
    let Some(file_raw) = rest.first() else {
        return Err("usage: pqc-secrets vault sign <FILE>".to_string());
    };
    let file_path = PathBuf::from(expand_user_path(file_raw));
    let data = std::fs::read(&file_path).map_err(|e| format!("read {:?}: {}", file_path, e))?;

    let header = load_vault()?;
    let identity = obtain_identity()?;
    let sk = identity.signing_key()?;
    let sig = sk.sign(&data);

    let file_fp_full = hex::encode(sha3_256(&data));
    let sig_rec = serde_json::json!({
        "alg": SIG_ALG,
        "file_sha3_256": file_fp_full,
        "dsa_pub_sha3_256": header.identity.dsa_pub_sha3_256,
        "sig_b64": b64(&sig.to_vec()),
        "created_utc": now_utc(),
    });
    let sig_path = sig_path_for(&file_path);
    std::fs::write(&sig_path, serde_json::to_string_pretty(&sig_rec).map_err(|e| e.to_string())?)
        .map_err(|e| format!("write signature: {}", e))?;

    audit_chain_append(
        "vault-sign",
        &format!("file-fp={}; sig={}", short_fp(&file_fp_full), sig_path.display()),
        &sk,
    )?;
    println!("Signed {:?} -> {:?} (ML-DSA-65 detached)", file_path, sig_path);
    Ok(())
}

fn cmd_verify(rest: &[String]) -> Result<(), String> {
    let Some(file_raw) = rest.first() else {
        return Err("usage: pqc-secrets vault verify <FILE> [SIGFILE]".to_string());
    };
    let file_path = PathBuf::from(expand_user_path(file_raw));
    let sig_path = match rest.get(1) {
        Some(s) => PathBuf::from(expand_user_path(s)),
        None => sig_path_for(&file_path),
    };
    let data = std::fs::read(&file_path).map_err(|e| format!("read {:?}: {}", file_path, e))?;
    let sig_raw = std::fs::read_to_string(&sig_path).map_err(|e| format!("read {:?}: {}", sig_path, e))?;
    let sig_rec: serde_json::Value =
        serde_json::from_str(&sig_raw).map_err(|e| format!("signature file corrupt: {}", e))?;

    // Fail closed on anything unexpected.
    if sig_rec.get("alg").and_then(|v| v.as_str()) != Some(SIG_ALG) {
        return Err("signature alg mismatch (fail closed)".to_string());
    }
    let file_fp_full = hex::encode(sha3_256(&data));
    if sig_rec.get("file_sha3_256").and_then(|v| v.as_str()) != Some(file_fp_full.as_str()) {
        return Err("FILE CONTENT TAMPERED: file digest does not match signature".to_string());
    }

    // Verify against the vault's pinned verification key (public material only;
    // no passphrase needed — the vault header pins which key is trusted).
    let header = load_vault()?;
    if sig_rec.get("dsa_pub_sha3_256").and_then(|v| v.as_str())
        != Some(header.identity.dsa_pub_sha3_256.as_str())
    {
        return Err("signature was not made by the vault identity (key fingerprint mismatch)".to_string());
    }
    let vk_bytes = BASE64_STANDARD
        .decode(header.identity.dsa_pub_b64.trim())
        .map_err(|e| format!("vault vk corrupt: {}", e))?;
    let vk = dsa_vk_from_bytes(&vk_bytes)?;
    let sig_bytes = BASE64_STANDARD
        .decode(sig_rec.get("sig_b64").and_then(|v| v.as_str()).ok_or("signature missing sig_b64")?)
        .map_err(|e| format!("sig_b64 corrupt: {}", e))?;
    let sig = Signature::<MlDsa65>::try_from(sig_bytes.as_slice())
        .map_err(|_| "signature undecodable (corrupt or truncated)".to_string())?;
    vk.verify(&data, &sig).map_err(|_| "SIGNATURE INVALID (fail closed)".to_string())?;

    println!(
        "verify OK: {:?} authentic under vault ML-DSA-65 identity (file-fp={})",
        file_path,
        short_fp(&file_fp_full)
    );
    Ok(())
}

fn cmd_migrate(rest: &[String]) -> Result<(), String> {
    let dry_run = rest.iter().any(|a| a == "--dry-run");
    if vault_exists() {
        return Err(format!("vault already exists at {:?} — migrate is one-time", vault_path()));
    }

    if dry_run {
        println!("DRY RUN — vault migrate plan (no writes performed):");
        println!(
            "  1. read keychain identity (service={}, account={})",
            DEFAULT_SERVICE,
            keychain_account()
        );
        println!("  2. require 64-byte FIPS 203 seed-form material (fail closed otherwise)");
        println!(
            "  3. prompt passphrase → Argon2id (m={}KiB t={} p={}) → 32-byte KEK",
            KDF_M_COST_KIB, KDF_T_COST, KDF_P_COST
        );
        println!(
            "  4. AES-256-GCM-wrap: KEM seed (d‖z) + fresh ML-DSA-65 seed → {:?} (0600)",
            vault_path()
        );
        println!("  5. re-read + unwrap + byte-roundtrip fingerprint check (before == after)");
        println!("  6. on any mismatch: delete the just-written vault (rollback), exit 1");
        println!("  7. NEVER delete or modify keychain material — you delete it manually after confirming");
        return Ok(());
    }

    ensure_config_dir()?;

    // Gate 1: unwrap the keychain identity (read-only; never mutated).
    let account = keychain_account();
    let stored = security_framework::passwords::get_generic_password(DEFAULT_SERVICE, &account)
        .map_err(|e| format!("keychain entry not found (service={}, account={}): {:?}", DEFAULT_SERVICE, account, e))?;
    let mut secret_raw = String::from_utf8(stored).map_err(|_| "keychain material not UTF-8".to_string())?;
    let material = crate::decode_keychain_material(&secret_raw)?;
    secret_raw.zeroize();
    if material.len() != SEED_LEN {
        if material.len() == 2400 {
            return Err(
                "keychain holds a legacy 2400-byte expanded key — the FIPS 203 seed cannot be recovered \
                 from it. Rotate first (keygen + re-pack), then migrate."
                    .to_string(),
            );
        }
        return Err(format!("keychain material has unexpected length {}", material.len()));
    }
    let mut kem_seed = Zeroizing::new([0u8; SEED_LEN]);
    kem_seed.copy_from_slice(&material);

    // Fingerprints BEFORE (seed digest + expanded-EK digest).
    let seed_hash_before = hex::encode(sha3_256(kem_seed.as_slice()));
    let identity = UnwrappedIdentity { kem_seed: kem_seed.clone(), dsa_seed: Zeroizing::new([0u8; DSA_SEED_LEN]) };
    let kem_pub_before = hex::encode(sha3_256(&identity.kem_pub()?));

    // Fresh ML-DSA-65 signing identity for the vault.
    let mut dsa_seed = Zeroizing::new([0u8; DSA_SEED_LEN]);
    getrandom::fill(dsa_seed.as_mut()).map_err(|e| format!("CSPRNG: {}", e))?;
    let identity = UnwrappedIdentity { kem_seed: kem_seed.clone(), dsa_seed: dsa_seed.clone() };
    let dsa_pub = identity.dsa_pub()?;
    let dsa_fp_full = hex::encode(sha3_256(&dsa_pub));

    // Gate 2: wrap under the passphrase KEK and write the vault.
    let mut pass = read_passphrase(true)?;
    let kdf = default_kdf();
    let kek = derive_kek_argon2(&kdf, pass.as_bytes())?;
    pass.zeroize();
    let header = VaultHeader {
        version: VAULT_VERSION,
        alg: crate::ALG.to_string(),
        sig_alg: SIG_ALG.to_string(),
        engine: VAULT_ENGINE.to_string(),
        created_utc: now_utc(),
        identity: VaultIdentity {
            kem_pub_sha3_256: kem_pub_before.clone(),
            dsa_pub_b64: b64(&dsa_pub),
            dsa_pub_sha3_256: dsa_fp_full.clone(),
        },
        kem_seed: wrap_blob(&kek, kem_seed.as_slice(), KEM_SEED_AAD)?,
        dsa_seed: wrap_blob(&kek, dsa_seed.as_slice(), DSA_SEED_AAD)?,
        kdf,
    };
    save_vault(&header)?;

    // Gate 3: byte-roundtrip verification (fresh derivation, fresh unwrap).
    let roundtrip = (|| -> Result<bool, String> {
        let stored = load_vault()?;
        let mut pass = read_passphrase(false)?;
        let kek = derive_kek_argon2(&stored.kdf, pass.as_bytes())?;
        pass.zeroize();
        let kem = unwrap_blob(&kek, &stored.kem_seed, KEM_SEED_AAD)?;
        let dsa = unwrap_blob(&kek, &stored.dsa_seed, DSA_SEED_AAD)?;
        let mut kem_arr = Zeroizing::new([0u8; SEED_LEN]);
        kem_arr.copy_from_slice(&kem);
        let mut dsa_arr = Zeroizing::new([0u8; DSA_SEED_LEN]);
        dsa_arr.copy_from_slice(&dsa);
        let id = UnwrappedIdentity { kem_seed: kem_arr, dsa_seed: dsa_arr };
        let seed_hash_after = hex::encode(sha3_256(id.kem_seed.as_slice()));
        let kem_pub_after = hex::encode(sha3_256(&id.kem_pub()?));
        Ok(seed_hash_after == seed_hash_before
            && kem_pub_after == kem_pub_before
            && kem_pub_after == stored.identity.kem_pub_sha3_256)
    })();

    match roundtrip {
        Ok(true) => {
            let sk = identity.signing_key()?;
            audit_chain_append(
                "vault-migrate",
                &format!(
                    "mode=live; kem-fp={}; dsa-fp={}; roundtrip=ok",
                    short_fp(&kem_pub_before),
                    short_fp(&dsa_fp_full)
                ),
                &sk,
            )?;
            println!("vault migrate OK — rollback gates passed (seed fingerprint before == after).");
            println!("  vault:   {:?} (0600)", vault_path());
            println!("  kem-fp:  {}", short_fp(&kem_pub_before));
            println!("  dsa-fp:  {}", short_fp(&dsa_fp_full));
            println!("  keychain entry UNCHANGED — delete it manually only after you confirm:");
            println!("      security delete-generic-password -s {} -a {}", DEFAULT_SERVICE, account);
            Ok(())
        }
        Ok(false) => {
            let _ = std::fs::remove_file(vault_path());
            Err(
                "ROUNDTRIP MISMATCH — rolled back: the just-written vault was deleted; keychain material untouched"
                    .to_string(),
            )
        }
        Err(e) => {
            let _ = std::fs::remove_file(vault_path());
            Err(format!(
                "roundtrip verification failed ({}) — rolled back; keychain material untouched",
                e
            ))
        }
    }
}

/// `export` via the vault identity (vault-first routing from main.rs).
pub(crate) fn cmd_export_via_vault(bundle_path: &Path) -> Result<(), Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(bundle_path)?;
    let bundle: crate::Bundle = serde_json::from_str(&raw)?;
    if bundle.version != BUNDLE_VERSION {
        return Err(format!("unsupported bundle version {}", bundle.version).into());
    }
    if bundle.alg != crate::ALG {
        return Err(format!("unsupported bundle alg {}", bundle.alg).into());
    }

    let identity = obtain_identity().map_err(|e| -> Box<dyn std::error::Error> { e.into() })?;

    // Expand the decapsulation key from the vault seed and decapsulate.
    let seed_arr: [u8; SEED_LEN] = *identity.kem_seed;
    let seed = KemSeedArr::from(seed_arr);
    let (dk, _ek) = MlKem768::from_seed(&seed);
    let kem_ct = BASE64_STANDARD.decode(bundle.kem.ciphertext_b64.trim())?;
    let shared = dk
        .decapsulate_slice(&kem_ct)
        .map_err(|e| format!("ML-KEM vault decapsulation failed: {}", e))?;

    let mut kek = derive_kek(shared.as_slice());
    let keywrap_nonce = BASE64_STANDARD.decode(bundle.keywrap.nonce_b64.trim())?;
    let keywrap_ct = BASE64_STANDARD.decode(bundle.keywrap.ciphertext_b64.trim())?;
    let mut data_key = decrypt_aesgcm(&kek, &keywrap_nonce, &keywrap_ct, crate::KEYWRAP_AAD)?;
    kek.zeroize();

    let data_nonce = BASE64_STANDARD.decode(bundle.data.nonce_b64.trim())?;
    let data_ct = BASE64_STANDARD.decode(bundle.data.ciphertext_b64.trim())?;
    let payload_bytes = decrypt_aesgcm(&data_key, &data_nonce, &data_ct, crate::DATA_AAD)?;
    data_key.zeroize();

    let payload: PayloadSection = serde_json::from_slice(&payload_bytes)?;
    let mut keys: Vec<&String> = payload.secrets.keys().collect();
    keys.sort();
    for key in keys {
        println!("export {}={}", key, shell_quote(&payload.secrets[key]));
    }
    Ok(())
}

/// Hidden holder entry: `pqc-secrets _vault-holder <ttl_secs>` (KEK on stdin).
fn cmd_holder(rest: &[String]) -> Result<(), String> {
    let ttl: u64 = rest
        .first()
        .and_then(|s| s.parse().ok())
        .ok_or("holder: missing/invalid TTL argument".to_string())?;
    let mut kek = Zeroizing::new([0u8; KDF_OUT_LEN]);
    std::io::stdin()
        .read_exact(&mut kek[..])
        .map_err(|_| "holder: missing KEK on stdin".to_string())?;
    holder_serve_with_kek(kek, ttl)
}

fn vault_usage() -> String {
    "usage: pqc-secrets vault <init|unlock|lock|status|export-identity|sign|verify|audit-verify|migrate> [args]"
        .to_string()
}

/// Dispatch `pqc-secrets vault ...`. All errors fail closed (exit != 0).
pub fn dispatch(args: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    let result = match args.first().map(|s| s.as_str()) {
        Some("init") => cmd_init(&args[1..]),
        Some("unlock") => cmd_unlock(&args[1..]),
        Some("lock") => cmd_lock(&args[1..]),
        Some("status") => cmd_status(&args[1..]),
        Some("export-identity") => cmd_export_identity(&args[1..]),
        Some("sign") => cmd_sign(&args[1..]),
        Some("verify") => cmd_verify(&args[1..]),
        Some("audit-verify") => cmd_audit_verify(),
        Some("migrate") => cmd_migrate(&args[1..]),
        Some(HOLDER_ARG) => cmd_holder(&args[1..]),
        _ => Err(vault_usage()),
    };
    result.map_err(|e| -> Box<dyn std::error::Error> { e.into() })
}

// ---------------------------------------------------------------------------
// Tests — sandboxed ONLY: temp PQC_CONFIG_DIR, sandbox keychain account name
// (never used by vault ops, but mandated by the incident postmortem),
// synthetic passphrase. Tests are serialized because the sandbox is
// process-env based; env is set via unsafe blocks (edition 2024) and never
// outlives a test.
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    static TEST_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

    const PASS: &str = "synthetic-vtest-passphrase";

    /// SAFETY: callers hold TEST_LOCK; no other test thread reads env
    /// concurrently (edition 2024 marks env mutation unsafe).
    fn set_env(key: &str, value: &str) {
        unsafe { std::env::set_var(key, value) };
    }

    /// Point the vault at a throwaway config dir. NEVER touches the live store.
    fn sandbox(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("pqc-vault-test-{}-{}", std::process::id(), name));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        set_env("PQC_CONFIG_DIR", dir.to_str().unwrap());
        set_env("PQC_VAULT_PASSPHRASE", PASS);
        set_env(TEST_KDF_LIGHT_ENV, "1");
        // Sandbox keychain account per incident mandate (vault ops never read
        // it, but the env must name the sandbox account, never the live one).
        set_env("PQC_KEYCHAIN_ACCOUNT", "pqc-secrets-vtest-vault");
        dir
    }

    fn init_vault(name: &str) -> (std::sync::MutexGuard<'static, ()>, PathBuf) {
        let guard = TEST_LOCK.lock().unwrap_or_else(|p| p.into_inner());
        let dir = sandbox(name);
        cmd_init(&[]).expect("vault init");
        (guard, dir)
    }

    /// Direct passphrase unwrap (the exact path the CLI uses without a session).
    fn unlock_identity() -> UnwrappedIdentity {
        let header = load_vault().unwrap();
        let mut pass = PASS.to_string();
        let kek = derive_kek_argon2(&header.kdf, pass.as_bytes()).unwrap();
        pass.zeroize();
        let kem = unwrap_blob(&kek, &header.kem_seed, KEM_SEED_AAD).unwrap();
        let dsa = unwrap_blob(&kek, &header.dsa_seed, DSA_SEED_AAD).unwrap();
        let mut kem_arr = Zeroizing::new([0u8; SEED_LEN]);
        kem_arr.copy_from_slice(&kem);
        let mut dsa_arr = Zeroizing::new([0u8; DSA_SEED_LEN]);
        dsa_arr.copy_from_slice(&dsa);
        UnwrappedIdentity { kem_seed: kem_arr, dsa_seed: dsa_arr }
    }

    #[test]
    fn vault_roundtrip_init_unlock_export_identity() {
        let (_g, dir) = init_vault("roundtrip");
        let header = load_vault().unwrap();

        // init → unlock (passphrase verify path) → export-identity roundtrip.
        set_env("PQC_VAULT_PASSPHRASE", PASS);
        cmd_unlock(&["--no-cache".to_string()]).expect("no-cache unlock must verify the passphrase");

        let identity = unlock_identity();
        let kem_pub = identity.kem_pub().unwrap();
        let fp = hex::encode(sha3_256(&kem_pub));
        assert_eq!(fp, header.identity.kem_pub_sha3_256, "wrapped seed must roundtrip to the header fingerprint");

        // export-identity writes a pack-compatible public key file.
        let pub_path = dir.join("recipient.pub");
        cmd_export_identity(&["--pub-out".to_string(), pub_path.to_string_lossy().to_string()])
            .expect("export-identity");
        let pub_json = std::fs::read_to_string(&pub_path).unwrap();
        let pub_file: PublicKeyFile = serde_json::from_str(&pub_json).unwrap();
        assert_eq!(pub_file.public_key_sha3_256, header.identity.kem_pub_sha3_256);
        assert_eq!(BASE64_STANDARD.decode(pub_file.public_key_b64).unwrap().len(), 1184);
    }

    #[test]
    fn wrong_passphrase_fails_closed() {
        let (_g, _dir) = init_vault("wrongpass");
        set_env("PQC_VAULT_PASSPHRASE", "definitely-not-the-passphrase");
        let err = obtain_identity().expect_err("wrong passphrase must fail closed");
        assert!(err.contains("wrong passphrase") || err.contains("unwrap failed"), "err={}", err);
    }

    #[test]
    fn session_holder_ttl_expiry() {
        let (_g, _dir) = init_vault("ttl");
        // In-process holder (cargo tests cannot re-exec the test harness as the
        // binary): serve a 1s TTL session in a thread and exercise the client.
        let header = load_vault().unwrap();
        let mut pass = PASS.to_string();
        let kek = derive_kek_argon2(&header.kdf, pass.as_bytes()).unwrap();
        pass.zeroize();
        let handle = std::thread::spawn(move || holder_serve_with_kek(kek, 1).unwrap());

        // Wait for readiness.
        let mut ready = false;
        for _ in 0..50 {
            if session_request(&HolderReq::Status).map(|r| r.ok).unwrap_or(false) {
                ready = true;
                break;
            }
            std::thread::sleep(Duration::from_millis(100));
        }
        assert!(ready, "holder did not become ready");
        assert!(session_status().is_some(), "session should report remaining TTL");

        // Unwrap via the session (the production obtain_identity path).
        set_env("PQC_VAULT_PASSPHRASE", "unused-should-not-prompt");
        let identity = obtain_identity().unwrap();
        let fp = hex::encode(sha3_256(&identity.kem_pub().unwrap()));
        assert_eq!(fp, header.identity.kem_pub_sha3_256, "session unwrap must match header fingerprint");

        // TTL expiry: after >1s the holder must be gone (socket cleaned up).
        std::thread::sleep(Duration::from_millis(1600));
        handle.join().unwrap();
        assert!(
            !session_socket_path().unwrap().exists(),
            "holder must remove its socket on TTL expiry"
        );
    }

    #[test]
    fn sign_verify_and_tamper_detection() {
        let (_g, dir) = init_vault("signverify");
        let file_path = dir.join("artifact.txt");
        std::fs::write(&file_path, b"artifact-bytes-for-signing").unwrap();

        cmd_sign(&[file_path.to_string_lossy().to_string()]).expect("sign");
        cmd_verify(&[file_path.to_string_lossy().to_string()]).expect("verify must pass");

        // Tamper with the signed file → fail closed.
        std::fs::write(&file_path, b"artifact-bytes-for-signinG").unwrap();
        let err = cmd_verify(&[file_path.to_string_lossy().to_string()])
            .expect_err("tampered file must fail verification");
        assert!(err.contains("TAMPERED") || err.contains("INVALID"), "err={}", err);

        // A forged signature file (unknown identity) must fail too.
        let forged = dir.join("forged.sig");
        std::fs::write(
            &forged,
            r#"{"alg":"ML-DSA-65","file_sha3_256":"00","dsa_pub_sha3_256":"00","sig_b64":"AAA="}"#,
        )
        .unwrap();
        assert!(cmd_verify(&[file_path.to_string_lossy().to_string(), forged.to_string_lossy().to_string()]).is_err());
    }

    #[test]
    fn audit_chain_verify_and_tamper_detection() {
        let (_g, dir) = init_vault("auditchain");
        // Three signed records: vault-init (from cmd_init) + unlock + sign.
        let file_path = dir.join("artifact.txt");
        std::fs::write(&file_path, b"chain-artifact").unwrap();
        cmd_unlock(&["--no-cache".to_string()]).unwrap();
        cmd_sign(&[file_path.to_string_lossy().to_string()]).unwrap();

        cmd_audit_verify().expect("chain must verify");

        // Tamper with one record's action → replay must fail closed.
        let log_path = audit_log_path();
        let raw = std::fs::read_to_string(&log_path).unwrap();
        let tampered = raw.replace("vault-unlock", "vault-unlock-TAMPERED");
        std::fs::write(&log_path, tampered).unwrap();
        let err = cmd_audit_verify().expect_err("tampered chain must fail");
        assert!(err.contains("TAMPERED") || err.contains("broken"), "err={}", err);
    }

    #[test]
    fn migrate_dry_run_prints_plan_without_writes() {
        let (_g, _dir) = init_vault("dryrun"); // vault exists → migrate must refuse (even dry-run)
        let err = cmd_migrate(&["--dry-run".to_string()]).expect_err("existing vault must refuse migrate");
        assert!(err.contains("one-time"), "err={}", err);

        // No-vault sandbox: dry-run prints the plan, writes nothing.
        let dir2 = std::env::temp_dir().join(format!("pqc-vault-test-{}-dryrun2", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir2);
        std::fs::create_dir_all(&dir2).unwrap();
        set_env("PQC_CONFIG_DIR", dir2.to_str().unwrap());
        assert!(!vault_exists());
        cmd_migrate(&["--dry-run".to_string()]).expect("dry-run must succeed");
        assert!(!vault_exists(), "dry-run must not write a vault");
    }

    /// Vault blob AAD pinning: a blob evaluated against the wrong AAD must fail.
    #[test]
    fn aad_mismatch_fails_closed() {
        let (_g, _dir) = init_vault("aadpin");
        let header = load_vault().unwrap();
        let mut pass = PASS.to_string();
        let kek = derive_kek_argon2(&header.kdf, pass.as_bytes()).unwrap();
        pass.zeroize();
        let err =
            unwrap_blob(&kek, &header.kem_seed, DSA_SEED_AAD).expect_err("AAD pinning must fail closed");
        assert!(err.contains("AAD mismatch"), "err={}", err);
    }
}
