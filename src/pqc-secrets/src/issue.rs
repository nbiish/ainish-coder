//! Device-key issuance (`issue`) and cross-machine secret transfer (`envelope`)
//! for the pqc-secrets Rust engine.
//!
//! `issue <template> <name>` mints a high-entropy device key from the OS CSPRNG
//! and packs it into the PQC bundle through the existing pack path (same bundle
//! format, AADs, and KDF as `cmd_pack`). `wtf` is the first built-in template
//! and emits a ready-to-eval env line plus the wtf-agent-hub enrollment JSON
//! (skill §2 shape: `{"hub_url":…,"device":…,"key":…}`).
//!
//! `envelope export|import` moves secrets across machines as an ML-KEM-768-
//! wrapped, ML-DSA-65-signed envelope. Import **verifies the signature before
//! any decapsulation** and fails closed on the slightest mismatch.
//!
//! NOTE (integration): issuance currently writes through the existing bundle
//! path (pack semantics). Phase 1 of the vault plan rewires issuance through
//! the vault so merges into an existing bundle happen without exposing
//! plaintext — see `.agents/tasks/TASK.2026-08-30.pqc-issuance-transit.md`.
//!
//! Security notes:
//! - Secret values are only ever printed shell-quoted (`export KEY='…'`) or
//!   JSON-quoted (enrollment JSON) and are never logged; stderr carries
//!   metadata and fingerprints only.
//! - Tests in this file are pure in-memory with synthetic keys — they never
//!   touch the OS keychain or the live bundle paths. Keychain-touching code
//!   paths are exercised only via sandboxed subprocess runs.

use std::collections::HashMap;
use std::fs::File;
use std::io::{Read, Write};
use std::path::{Path, PathBuf};

use base64::prelude::*;
use fips203::ml_kem_768;
use fips203::traits::{Decaps, Encaps, SerDes};
use ml_dsa::{
    EncodedSignature, EncodedVerifyingKey, Keypair, MlDsa65, Seed, Signature, Signer, SigningKey,
    Verifier, VerifyingKey,
};
use ml_kem::kem::{Decapsulate, FromSeed};
use ml_kem::{KeyExport, MlKem768, Seed as MlKemSeed};
use security_framework::passwords::{get_generic_password, set_generic_password};
use zeroize::Zeroize;

// Shared engine primitives live in main.rs (single source of truth for the
// bundle format). Visibility is pub(crate) there; all new logic stays here.
use crate::{
    decrypt_aesgcm, decode_keychain_material, derive_kek, encrypt_aesgcm, ensure_parent_dir,
    expand_user_path, keychain_account, now_utc, parse_env_lines, sha3_256, shell_quote, Bundle,
    DataSection, KemSection, KeywrapSection, PayloadSection, PublicKeyFile, RecipientSection, ALG,
    BUNDLE_VERSION, DATA_AAD, DEFAULT_BUNDLE, DEFAULT_PUB, DEFAULT_SERVICE, KEYWRAP_AAD, SEED_LEN,
};

/// Default hub endpoint used in the enrollment JSON when `--hub-url` is not
/// given. Placeholder by design — the operator substitutes the real hub.
const DEFAULT_HUB_URL: &str = "http://HUB:7800";

const ENVELOPE_VERSION: u32 = 1;
const ENVELOPE_ALG: &str = "ML-KEM-768+ML-DSA-65";
/// AAD namespacing: all envelope AEAD payloads live under `pqc-secrets:v1:envelope:*`.
const ENVELOPE_DATA_AAD: &[u8] = b"pqc-secrets:v1:envelope:data";
/// Domain separator prefixed to every signed payload (ML-DSA signs message
/// bytes; this namespaces them away from any other signed surface).
const ENVELOPE_SIG_DOMAIN: &[u8] = b"pqc-secrets:v1:envelope:sig";

/// FIPS 204 ML-DSA-65 encoded verifying key length (bytes).
const MLDSA65_VK_LEN: usize = 1952;
/// FIPS 204 ML-DSA-65 signature length (bytes).
const MLDSA65_SIG_LEN: usize = 3309;
/// Keychain account suffix for the ML-DSA-65 envelope-signing key.
const SIGNING_KEY_ACCOUNT_SUFFIX: &str = "-mldsa65";

/// Versioned transfer envelope: ML-KEM-768-wrapped AES-256-GCM payload,
/// signed with ML-DSA-65. Field names and order are the wire contract.
#[derive(serde::Serialize, serde::Deserialize, Debug)]
struct Envelope {
    version: u32,
    alg: String,
    recipient_key_sha3_256: String,
    signer_pubkey: String,
    sig: String,
    kem_ct_b64: String,
    nonce_b64: String,
    ct_b64: String,
}

/// wtf-agent-hub enrollment JSON (skill §2 shape, printed once).
/// serde_json quotes `key`; the value is never emitted unquoted anywhere.
#[derive(serde::Serialize)]
struct WtfEnrollment<'a> {
    hub_url: &'a str,
    device: &'a str,
    key: &'a str,
}

// ---------------------------------------------------------------------------
// Entry point (called from main.rs's single match arm)
// ---------------------------------------------------------------------------

/// Route `pqc-secrets issue …` / `pqc-secrets envelope …`.
/// `args[0]` is the subcommand name itself.
pub(crate) fn dispatch(args: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    let (cmd, rest) = match args.split_first() {
        Some((cmd, rest)) => (cmd.as_str(), rest),
        None => return Err("missing subcommand (issue|envelope)".into()),
    };
    match cmd {
        "issue" => cmd_issue(rest),
        "envelope" => cmd_envelope(rest),
        other => Err(format!("Unknown command: {}", other).into()),
    }
}

// ---------------------------------------------------------------------------
// issue <template> <name>
// ---------------------------------------------------------------------------

/// Simple flag/positional parser shared by the issue/envelope subcommands.
/// `--name VALUE` consumes the next arg; `--flag` is boolean; `--name=VALUE`
/// inline form is also accepted.
struct ArgScanner<'a> {
    positionals: Vec<&'a str>,
    flags: HashMap<&'a str, Option<String>>,
}

impl<'a> ArgScanner<'a> {
    fn scan(args: &'a [String]) -> Self {
        let mut positionals = Vec::new();
        let mut flags: HashMap<&str, Option<String>> = HashMap::new();
        let mut iter = args.iter();
        while let Some(arg) = iter.next() {
            let arg = arg.as_str();
            if let Some(name) = arg.strip_prefix("--") {
                if let Some((key, inline_val)) = name.split_once('=') {
                    flags.insert(key, Some(inline_val.to_string()));
                } else if iter.as_slice().first().is_some_and(|n| n.starts_with("--")) {
                    flags.insert(name, None);
                } else {
                    flags.insert(name, iter.next().cloned());
                }
            } else {
                positionals.push(arg);
            }
        }
        Self { positionals, flags }
    }

    fn value(&self, name: &str) -> Option<&str> {
        self.flags.get(name).and_then(|v| v.as_deref())
    }

    fn present(&self, name: &str) -> bool {
        self.flags.contains_key(name)
    }
}

/// Validate a device name and derive its env var key:
/// `[A-Za-z0-9_-]+`, no leading digit; uppercased, `-` folded to `_`.
fn wtf_env_key(name: &str) -> Result<String, String> {
    let invalid = |why: &str| format!("invalid device name {:?}: {}", name, why);
    if name.is_empty() {
        return Err(invalid("empty"));
    }
    if name.chars().next().is_some_and(|c| c.is_ascii_digit()) {
        return Err(invalid("must not start with a digit"));
    }
    if !name
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
    {
        return Err(invalid("allowed characters are [A-Za-z0-9_-]"));
    }
    Ok(format!(
        "WTF_{}_SECRET",
        name.to_uppercase().replace('-', "_")
    ))
}

/// Mint a 256-bit key from the OS CSPRNG, hex-encoded (64 chars).
/// The value is returned to the caller only; it is never logged here.
fn mint_device_key() -> Result<String, String> {
    let mut raw = [0u8; 32];
    getrandom::fill(&mut raw).map_err(|e| format!("CSPRNG failure: {}", e))?;
    let hex_val = hex::encode(raw);
    raw.zeroize();
    Ok(hex_val)
}

/// Load an ML-KEM-768 recipient public key file (engine JSON or raw hex) —
/// the same accepted formats as `cmd_pack`.
fn load_recipient_pub(pub_path: &Path) -> Result<[u8; ml_kem_768::EK_LEN], String> {
    let mut file =
        File::open(pub_path).map_err(|e| format!("cannot open {}: {}", pub_path.display(), e))?;
    let mut content = String::new();
    file.read_to_string(&mut content)
        .map_err(|e| format!("cannot read {}: {}", pub_path.display(), e))?;
    let pub_file: PublicKeyFile = match serde_json::from_str::<PublicKeyFile>(&content) {
        Ok(pf) => pf,
        Err(_) => {
            let ek_bytes = hex::decode(content.trim())
                .map_err(|_| "public key file is neither engine JSON nor raw hex".to_string())?;
            let ek: [u8; ml_kem_768::EK_LEN] = ek_bytes.try_into().map_err(|bytes: Vec<u8>| {
                format!(
                    "hex public key has incorrect length: {} bytes (expected {})",
                    bytes.len(),
                    ml_kem_768::EK_LEN
                )
            })?;
            return Ok(ek);
        }
    };
    if pub_file.alg != ALG {
        return Err(format!(
            "unsupported algorithm in public key: {}",
            pub_file.alg
        ));
    }
    let ek_bytes = BASE64_STANDARD
        .decode(pub_file.public_key_b64.trim())
        .map_err(|e| format!("invalid base64 in public key: {}", e))?;
    let ek: [u8; ml_kem_768::EK_LEN] = ek_bytes
        .try_into()
        .map_err(|_| format!("invalid public key size (expected {} bytes)", ml_kem_768::EK_LEN))?;
    Ok(ek)
}

/// Encrypt and write a fresh bundle — the existing pack path (same structures,
/// AADs and KDF as `cmd_pack`, so output is byte-compatible with `pack`).
///
/// NOTE (Phase 1): issuance writes through this bundle path today; it will be
/// rewired through the vault at integration.
fn seal_bundle_file(
    secrets: &HashMap<String, String>,
    ek: &[u8; ml_kem_768::EK_LEN],
    bundle_path: &Path,
) -> Result<(), String> {
    let payload_struct = PayloadSection {
        secrets: secrets.clone(),
    };
    let payload_bytes = serde_json::to_vec(&payload_struct)
        .map_err(|e| format!("payload serialization failed: {}", e))?;

    let mut data_key = [0u8; 32];
    getrandom::fill(&mut data_key).map_err(|e| format!("CSPRNG failure: {}", e))?;
    let mut data_nonce = [0u8; 12];
    getrandom::fill(&mut data_nonce).map_err(|e| format!("CSPRNG failure: {}", e))?;
    let data_ciphertext = encrypt_aesgcm(&data_key, &data_nonce, &payload_bytes, DATA_AAD)?;

    let encaps_key = ml_kem_768::EncapsKey::try_from_bytes(*ek)
        .map_err(|e| format!("failed to import public key: {}", e))?;
    let (shared_secret, ct) = encaps_key
        .try_encaps()
        .map_err(|e| format!("ML-KEM encapsulation failed: {}", e))?;
    let mut shared_secret_bytes = shared_secret.into_bytes();
    let ct_bytes = ct.into_bytes();

    let mut kek = derive_kek(&shared_secret_bytes);

    let mut keywrap_nonce = [0u8; 12];
    getrandom::fill(&mut keywrap_nonce).map_err(|e| format!("CSPRNG failure: {}", e))?;
    let keywrap_ciphertext = encrypt_aesgcm(&kek, &keywrap_nonce, &data_key, KEYWRAP_AAD)?;

    shared_secret_bytes.zeroize();
    kek.zeroize();
    data_key.zeroize();

    let bundle = Bundle {
        version: BUNDLE_VERSION,
        alg: ALG.to_string(),
        engine: "rust-fips203".to_string(),
        created_utc: now_utc(),
        recipient: RecipientSection {
            public_key_sha3_256: hex::encode(sha3_256(ek)),
        },
        kem: KemSection {
            ciphertext_b64: BASE64_STANDARD.encode(ct_bytes),
        },
        keywrap: KeywrapSection {
            kdf: "SHA3-256".to_string(),
            aad: String::from_utf8(KEYWRAP_AAD.to_vec())
                .map_err(|e| format!("AAD encode failed: {}", e))?,
            nonce_b64: BASE64_STANDARD.encode(keywrap_nonce),
            ciphertext_b64: BASE64_STANDARD.encode(keywrap_ciphertext),
        },
        data: DataSection {
            aad: String::from_utf8(DATA_AAD.to_vec())
                .map_err(|e| format!("AAD encode failed: {}", e))?,
            nonce_b64: BASE64_STANDARD.encode(data_nonce),
            ciphertext_b64: BASE64_STANDARD.encode(data_ciphertext),
        },
    };

    ensure_parent_dir(bundle_path).map_err(|e| format!("cannot create bundle directory: {}", e))?;
    let mut file = File::create(bundle_path).map_err(|e| format!("cannot write bundle: {}", e))?;
    let bundle_json = serde_json::to_string_pretty(&bundle)
        .map_err(|e| format!("bundle serialization failed: {}", e))?;
    file.write_all(bundle_json.as_bytes())
        .map_err(|e| format!("cannot write bundle: {}", e))?;
    Ok(())
}

/// `pqc-secrets issue <template> <name> [PUB_PATH] [BUNDLE_PATH]
///                                 [--hub-url URL] [--json] [--force]`
///
/// Templates: `wtf` — mint a 64-hex device key, pack it into the PQC bundle as
/// `WTF_<NAME>_SECRET` via the existing pack path, and print a ready-to-eval
/// env line plus the wtf-agent-hub enrollment JSON. The minted value appears
/// only shell-quoted / JSON-quoted; it is never logged.
fn cmd_issue(rest: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    const USAGE: &str = "usage: pqc-secrets issue <template> <name> [PUB_PATH] [BUNDLE_PATH] [--hub-url URL] [--json] [--force]";
    let scanner = ArgScanner::scan(rest);
    let mut positionals = scanner.positionals.iter();
    let template = positionals
        .next()
        .copied()
        .ok_or(USAGE)?;
    let name = positionals
        .next()
        .copied()
        .ok_or(USAGE)?;
    let pub_path = PathBuf::from(expand_user_path(
        positionals.next().copied().unwrap_or(DEFAULT_PUB),
    ));
    let bundle_path = PathBuf::from(expand_user_path(
        positionals.next().copied().unwrap_or(DEFAULT_BUNDLE),
    ));
    if positionals.next().is_some() {
        return Err("too many positional arguments (expected: template name [PUB_PATH] [BUNDLE_PATH])".into());
    }
    let hub_url = scanner.value("hub-url").unwrap_or(DEFAULT_HUB_URL).to_string();
    let json_only = scanner.present("json");
    let force = scanner.present("force");

    if template != "wtf" {
        return Err(format!(
            "unknown issue template {:?} (available templates: wtf)",
            template
        )
        .into());
    }
    let env_key = wtf_env_key(name)?;

    // Footgun guard: like `pack`, this writes a fresh bundle. Unlike `pack`,
    // issuance mints a single key — silently destroying an existing bundle
    // would lose every other secret. Refuse unless explicitly forced.
    if bundle_path.exists() && !force {
        return Err(format!(
            "refusing to overwrite existing bundle {} (pass --force to override; issuance will merge through the vault at Phase 1 integration)",
            bundle_path.display()
        )
        .into());
    }

    let value = mint_device_key()?;

    let mut secrets = HashMap::new();
    secrets.insert(env_key.clone(), value.clone());
    seal_bundle_file(&secrets, &load_recipient_pub(&pub_path)?, &bundle_path)?;

    let enrollment_json = serde_json::to_string(&WtfEnrollment {
        hub_url: &hub_url,
        device: name,
        key: &value,
    })?;

    if json_only {
        println!("{}", enrollment_json);
    } else {
        println!("export {}={}", env_key, shell_quote(&value));
        println!("{}", enrollment_json);
        eprintln!(
            "Minted {} (64 hex chars); bundle written to {}",
            env_key,
            bundle_path.display()
        );
        eprintln!(
            "stdout line 1 is the eval line; line 2 is the enrollment JSON (--json for JSON-only output)"
        );
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// envelope export | import
// ---------------------------------------------------------------------------

/// `pqc-secrets envelope export --recipient <PUB> [--in FILE] [--out FILE]`
/// `pqc-secrets envelope import [--in FILE] [--out FILE]`
fn cmd_envelope(rest: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    let (sub, sub_rest) = match rest.split_first() {
        Some(pair) => pair,
        None => {
            return Err(
                "usage: pqc-secrets envelope <export|import> [--in FILE] [--out FILE] [--recipient PUB]"
                    .into(),
            )
        }
    };
    match sub.as_str() {
        "export" => envelope_export(sub_rest),
        "import" => envelope_import(sub_rest),
        other => Err(format!(
            "unknown envelope subcommand {:?} (expected: export|import)",
            other
        )
        .into()),
    }
}

/// Keychain account for the ML-DSA-65 envelope-signing key — always namespaced
/// under the ML-KEM account override so sandboxed runs never collide with
/// production (`pqc-secrets-key` and `pqc-secrets-key-mldsa65` are distinct
/// accounts; the sandbox uses `pqc-secrets-vtest-issue-mldsa65`).
fn signing_account() -> String {
    format!("{}{}", keychain_account(), SIGNING_KEY_ACCOUNT_SUFFIX)
}

/// Load the local ML-DSA-65 signing key from the keychain, provisioning a new
/// keypair from the OS CSPRNG on first use. The 32-byte seed is stored hex
/// (same storage convention as the ML-KEM seed); only a fingerprint is printed.
fn load_or_create_signing_key() -> Result<SigningKey<MlDsa65>, Box<dyn std::error::Error>> {
    let account = signing_account();
    if let Ok(stored) = get_generic_password(DEFAULT_SERVICE, &account) {
        let mut material = String::from_utf8(stored).map_err(|_| {
            "corrupt ML-DSA-65 signing key material in keychain (not UTF-8)".to_string()
        })?;
        let decoded = hex::decode(material.trim()).map_err(|_| {
            "corrupt ML-DSA-65 signing key in keychain (expected 64-char hex seed)".to_string()
        });
        material.zeroize();
        let seed_bytes: [u8; 32] = decoded?
            .try_into()
            .map_err(|_| {
                "corrupt ML-DSA-65 signing key in keychain (seed must be 32 bytes)".to_string()
            })?;
        return Ok(SigningKey::<MlDsa65>::from_seed(&Seed::from(seed_bytes)));
    }

    let mut seed_bytes = [0u8; 32];
    getrandom::fill(&mut seed_bytes)?;
    let signing_key = SigningKey::<MlDsa65>::from_seed(&Seed::from(seed_bytes));
    let mut seed_hex = hex::encode(seed_bytes);
    seed_bytes.zeroize();
    set_generic_password(DEFAULT_SERVICE, &account, seed_hex.as_bytes())?;
    seed_hex.zeroize();

    let vk_bytes = signing_key.verifying_key().encode();
    let fp = &hex::encode(sha3_256(vk_bytes.as_slice()))[..16];
    eprintln!(
        "Provisioned new ML-DSA-65 signing key (keychain account: {}, fingerprint sha3:{}…)",
        account, fp
    );
    Ok(signing_key)
}

/// Canonical byte sequence covered by the ML-DSA-65 signature:
/// domain || version(LE) || alg || 0x00 || recipient-fp-hex || 0x00 || kem_ct || nonce || ct.
fn envelope_signed_payload(
    version: u32,
    alg: &str,
    recipient_fp_hex: &str,
    kem_ct: &[u8],
    nonce: &[u8],
    ct: &[u8],
) -> Vec<u8> {
    let mut buf = Vec::with_capacity(
        ENVELOPE_SIG_DOMAIN.len()
            + 4
            + alg.len()
            + 2
            + recipient_fp_hex.len()
            + kem_ct.len()
            + nonce.len()
            + ct.len(),
    );
    buf.extend_from_slice(ENVELOPE_SIG_DOMAIN);
    buf.extend_from_slice(&version.to_le_bytes());
    buf.extend_from_slice(alg.as_bytes());
    buf.push(0x00);
    buf.extend_from_slice(recipient_fp_hex.as_bytes());
    buf.push(0x00);
    buf.extend_from_slice(kem_ct);
    buf.extend_from_slice(nonce);
    buf.extend_from_slice(ct);
    buf
}

/// Pure seal: encrypt `secrets` for the recipient's ML-KEM-768 public key and
/// sign every wire field with the given ML-DSA-65 signing key. No keychain,
/// no filesystem — unit-testable with synthetic keys.
fn seal_envelope(
    secrets: &HashMap<String, String>,
    recipient_ek: &[u8; ml_kem_768::EK_LEN],
    signing_key: &SigningKey<MlDsa65>,
) -> Result<Envelope, String> {
    let payload_struct = PayloadSection {
        secrets: secrets.clone(),
    };
    let payload_bytes = serde_json::to_vec(&payload_struct)
        .map_err(|e| format!("payload serialization failed: {}", e))?;

    // ML-KEM-768 encapsulation → KEK → AES-256-GCM payload.
    let encaps_key = ml_kem_768::EncapsKey::try_from_bytes(*recipient_ek)
        .map_err(|e| format!("failed to import recipient public key: {}", e))?;
    let (shared_secret, ct) = encaps_key
        .try_encaps()
        .map_err(|e| format!("ML-KEM encapsulation failed: {}", e))?;
    let mut shared_secret_bytes = shared_secret.into_bytes();
    let kem_ct_bytes = ct.into_bytes();
    let mut kek = derive_kek(&shared_secret_bytes);
    shared_secret_bytes.zeroize();

    let mut nonce = [0u8; 12];
    getrandom::fill(&mut nonce).map_err(|e| format!("CSPRNG failure: {}", e))?;
    let ct_bytes = encrypt_aesgcm(&kek, &nonce, &payload_bytes, ENVELOPE_DATA_AAD)?;
    kek.zeroize();

    // ML-DSA-65 signature over the canonical wire fields (fail-closed import
    // depends on this covering every authenticated element).
    let vk_bytes = signing_key.verifying_key().encode();
    let recipient_fp_hex = hex::encode(sha3_256(recipient_ek));
    let signed = envelope_signed_payload(
        ENVELOPE_VERSION,
        ENVELOPE_ALG,
        &recipient_fp_hex,
        &kem_ct_bytes,
        &nonce,
        &ct_bytes,
    );
    let signature = signing_key.sign(&signed);

    Ok(Envelope {
        version: ENVELOPE_VERSION,
        alg: ENVELOPE_ALG.to_string(),
        recipient_key_sha3_256: recipient_fp_hex,
        signer_pubkey: BASE64_STANDARD.encode(vk_bytes.as_slice()),
        sig: BASE64_STANDARD.encode(signature.encode().as_slice()),
        kem_ct_b64: BASE64_STANDARD.encode(kem_ct_bytes),
        nonce_b64: BASE64_STANDARD.encode(nonce),
        ct_b64: BASE64_STANDARD.encode(ct_bytes),
    })
}

/// Decode an ML-DSA-65 verifying key from raw encoded bytes (1952 for ML-DSA-65).
fn decode_verifying_key(bytes: &[u8]) -> Result<VerifyingKey<MlDsa65>, String> {
    if bytes.len() != MLDSA65_VK_LEN {
        return Err(format!(
            "signer_pubkey has wrong length: {} bytes (expected {} for ML-DSA-65)",
            bytes.len(),
            MLDSA65_VK_LEN
        ));
    }
    let encoded = EncodedVerifyingKey::<MlDsa65>::try_from(bytes)
        .map_err(|_| "signer_pubkey is not a valid ML-DSA-65 encoded key".to_string())?;
    Ok(VerifyingKey::<MlDsa65>::decode(&encoded))
}

/// Decode an ML-DSA-65 signature from raw encoded bytes (3309 for ML-DSA-65).
fn decode_signature(bytes: &[u8]) -> Result<Signature<MlDsa65>, String> {
    if bytes.len() != MLDSA65_SIG_LEN {
        return Err(format!(
            "sig has wrong length: {} bytes (expected {} for ML-DSA-65)",
            bytes.len(),
            MLDSA65_SIG_LEN
        ));
    }
    let encoded = EncodedSignature::<MlDsa65>::try_from(bytes)
        .map_err(|_| "sig is not a valid ML-DSA-65 encoded signature".to_string())?;
    Signature::<MlDsa65>::decode(&encoded)
        .ok_or_else(|| "sig is not a valid ML-DSA-65 signature".to_string())
}

/// Pure open: verify the ML-DSA-65 signature FIRST, then decapsulate with the
/// provided local private-key material (FIPS 203 seed form or legacy expanded
/// form) and decrypt the payload. Fails closed before any decapsulation if the
/// signature, algorithm tag, or recipient fingerprint do not check out.
fn open_envelope(
    envelope: &Envelope,
    local_key_material: &[u8],
) -> Result<HashMap<String, String>, String> {
    // 1. Version + algorithm gate (before touching any key material).
    if envelope.version != ENVELOPE_VERSION {
        return Err(format!(
            "unsupported envelope version {} (expected {})",
            envelope.version, ENVELOPE_VERSION
        ));
    }
    if envelope.alg != ENVELOPE_ALG {
        return Err(format!(
            "unsupported envelope alg {:?} (expected {:?})",
            envelope.alg, ENVELOPE_ALG
        ));
    }

    // 2. Decode signature inputs.
    let signer_pubkey = BASE64_STANDARD
        .decode(envelope.signer_pubkey.trim())
        .map_err(|e| format!("invalid base64 in signer_pubkey: {}", e))?;
    let verifying_key = decode_verifying_key(&signer_pubkey)?;
    let sig_bytes = BASE64_STANDARD
        .decode(envelope.sig.trim())
        .map_err(|e| format!("invalid base64 in sig: {}", e))?;
    let signature = decode_signature(&sig_bytes)?;
    let kem_ct_bytes = BASE64_STANDARD
        .decode(envelope.kem_ct_b64.trim())
        .map_err(|e| format!("invalid base64 in kem_ct_b64: {}", e))?;
    let nonce = BASE64_STANDARD
        .decode(envelope.nonce_b64.trim())
        .map_err(|e| format!("invalid base64 in nonce_b64: {}", e))?;
    let ct_bytes = BASE64_STANDARD
        .decode(envelope.ct_b64.trim())
        .map_err(|e| format!("invalid base64 in ct_b64: {}", e))?;
    if nonce.len() != 12 {
        return Err(format!("nonce must be 12 bytes (got {})", nonce.len()));
    }

    // 3. FAIL CLOSED: verify the ML-DSA-65 signature over the canonical wire
    //    fields BEFORE any decapsulation attempt. A tampered kem_ct/nonce/ct
    //    or swapped signer must abort here — the ML-KEM private key is never
    //    exercised against attacker-chosen inputs.
    let signed = envelope_signed_payload(
        envelope.version,
        &envelope.alg,
        envelope.recipient_key_sha3_256.trim(),
        &kem_ct_bytes,
        &nonce,
        &ct_bytes,
    );
    verifying_key
        .verify(&signed, &signature)
        .map_err(|_| {
            "envelope signature verification FAILED — refusing to decapsulate (fail closed)"
                .to_string()
        })?;

    // 4. Signature is authentic — now (and only now) decapsulate.
    let mut shared_secret_bytes: Vec<u8> = match local_key_material.len() {
        SEED_LEN => {
            let seed_bytes: [u8; SEED_LEN] = local_key_material
                .try_into()
                .map_err(|_| "failed to load 64-byte ML-KEM seed".to_string())?;
            let seed = MlKemSeed::from(seed_bytes);
            let (dk, ek) = MlKem768::from_seed(&seed);
            // Defense-in-depth: with the seed form we can reconstruct the EK,
            // so check the envelope was sealed for THIS identity. (The legacy
            // expanded form stores no EK, so the check is skipped there —
            // decapsulation itself still binds the envelope to this key.)
            let local_fp = hex::encode(sha3_256(ek.to_bytes().as_slice()));
            if local_fp != envelope.recipient_key_sha3_256.trim() {
                return Err(
                    "envelope was sealed for a different recipient (recipient_key_sha3_256 mismatch)"
                        .to_string(),
                );
            }
            let ssk = dk
                .decapsulate_slice(&kem_ct_bytes)
                .map_err(|e| format!("ML-KEM seed-form decapsulation failed: {}", e))?;
            ssk.as_slice().to_vec()
        }
        len if len == ml_kem_768::DK_LEN => {
            let mut dk_array = [0u8; ml_kem_768::DK_LEN];
            dk_array.copy_from_slice(local_key_material);
            let dk = ml_kem_768::DecapsKey::try_from_bytes(dk_array)
                .map_err(|e| format!("failed to import decapsulation key: {}", e))?;
            let ct_array: [u8; ml_kem_768::CT_LEN] = kem_ct_bytes
                .as_slice()
                .try_into()
                .map_err(|_| "KEM ciphertext has incorrect length".to_string())?;
            let ct = ml_kem_768::CipherText::try_from_bytes(ct_array)
                .map_err(|e| format!("failed to import KEM ciphertext: {}", e))?;
            let shared_secret = dk
                .try_decaps(&ct)
                .map_err(|e| format!("ML-KEM decapsulation failed: {}", e))?;
            shared_secret.into_bytes().to_vec()
        }
        len => {
            return Err(format!(
                "local key material has unexpected length: {} bytes (expected {} seed-form or {} expanded-form)",
                len,
                SEED_LEN,
                ml_kem_768::DK_LEN
            ));
        }
    };

    let mut kek = derive_kek(&shared_secret_bytes);
    shared_secret_bytes.zeroize();

    let payload_bytes = decrypt_aesgcm(&kek, &nonce, &ct_bytes, ENVELOPE_DATA_AAD)?;
    kek.zeroize();

    let payload: PayloadSection = serde_json::from_slice(&payload_bytes)
        .map_err(|e| format!("envelope payload is not valid secrets JSON: {}", e))?;
    Ok(payload.secrets)
}

fn envelope_export(rest: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    let scanner = ArgScanner::scan(rest);
    let recipient = scanner
        .value("recipient")
        .ok_or("envelope export requires --recipient <PUB>")?;
    let out_path = scanner.value("out");

    // Secrets from --in FILE or stdin (plain KEY=VAL lines, pack-compatible).
    let mut raw = String::new();
    match scanner.value("in") {
        Some(in_path) => File::open(in_path)
            .map_err(|e| format!("cannot open {}: {}", in_path, e))?
            .read_to_string(&mut raw)
            .map_err(|e| format!("cannot read {}: {}", in_path, e))?,
        None => std::io::stdin()
            .read_to_string(&mut raw)
            .map_err(|e| format!("cannot read stdin: {}", e))?,
    };
    let secrets = parse_env_lines(&raw)?;

    let pub_path_expanded = expand_user_path(recipient);
    let recipient_ek = load_recipient_pub(Path::new(&pub_path_expanded))?;

    // Provision/load the local ML-DSA-65 signing key (keychain, own account).
    let signing_key = load_or_create_signing_key()?;
    let envelope = seal_envelope(&secrets, &recipient_ek, &signing_key)?;

    let envelope_json = serde_json::to_string_pretty(&envelope)?;
    match out_path {
        Some(path) => {
            let out = expand_user_path(path);
            ensure_parent_dir(Path::new(&out))?;
            File::create(&out)?.write_all(envelope_json.as_bytes())?;
            eprintln!("Envelope written to {}", out);
        }
        None => println!("{}", envelope_json),
    }

    let vk_bytes = signing_key.verifying_key().encode();
    let fp = &hex::encode(sha3_256(vk_bytes.as_slice()))[..16];
    eprintln!(
        "Envelope signed ({} secret(s)); signer fingerprint sha3:{}… — verify the fingerprint with the recipient out-of-band",
        secrets.len(),
        fp
    );
    Ok(())
}

fn envelope_import(rest: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    let scanner = ArgScanner::scan(rest);
    let out_path = scanner.value("out");

    let mut raw = String::new();
    match scanner.value("in") {
        Some(in_path) => File::open(in_path)
            .map_err(|e| format!("cannot open {}: {}", in_path, e))?
            .read_to_string(&mut raw)
            .map_err(|e| format!("cannot read {}: {}", in_path, e))?,
        None => std::io::stdin()
            .read_to_string(&mut raw)
            .map_err(|e| format!("cannot read stdin: {}", e))?,
    };
    let envelope: Envelope = serde_json::from_str(raw.trim())
        .map_err(|e| format!("input is not a valid envelope JSON: {}", e))?;

    // Local ML-KEM-768 private material (keychain; same decode path as export).
    let account = keychain_account();
    let stored = get_generic_password(DEFAULT_SERVICE, &account).map_err(|e| {
        format!(
            "local ML-KEM-768 private key not found in keychain (service={}, account={}): {:?}",
            DEFAULT_SERVICE, account, e
        )
    })?;
    let mut material = String::from_utf8(stored)
        .map_err(|_| "keychain key material is not UTF-8".to_string())?;
    let mut local_key = decode_keychain_material(&material)?;
    material.zeroize();

    // Signature verification happens inside open_envelope BEFORE the local key
    // is exercised; on failure this returns without any decapsulation.
    let secrets = open_envelope(&envelope, &local_key);
    local_key.zeroize();
    let secrets = secrets?;

    // Emit shell exports (same quoting contract as `export`).
    let mut keys: Vec<&String> = secrets.keys().collect();
    keys.sort();
    let mut lines = String::new();
    for key in keys {
        lines.push_str(&format!(
            "export {}={}\n",
            key,
            shell_quote(&secrets[key])
        ));
    }

    match out_path {
        Some(path) => {
            let out = expand_user_path(path);
            ensure_parent_dir(Path::new(&out))?;
            let mut file = File::create(&out)?;
            file.write_all(lines.as_bytes())?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                file.set_permissions(std::fs::Permissions::from_mode(0o600))?;
            }
            eprintln!(
                "WARNING: plaintext env lines written to {} (mode 0600) — PQC violation if kept; delete after use",
                out
            );
        }
        None => print!("{}", lines),
    }

    let signer_fp = sha3_256(
        &BASE64_STANDARD
            .decode(envelope.signer_pubkey.trim())
            .map_err(|e| format!("invalid base64 in signer_pubkey: {}", e))?,
    );
    eprintln!(
        "Envelope accepted ({} secret(s)); signature verified for signer sha3:{}…",
        secrets.len(),
        &hex::encode(signer_fp)[..16]
    );
    Ok(())
}

// ---------------------------------------------------------------------------
// Tests — pure in-memory, synthetic keys only. These never touch the OS
// keychain, ~/.config/pqc-secrets, or any live path (2026-08-30 incident rule).
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    /// Synthetic ML-KEM-768 keypair (CSPRNG seed → EK/DK) for tests.
    fn synthetic_kem() -> ([u8; SEED_LEN], [u8; ml_kem_768::EK_LEN]) {
        let mut seed = [0u8; SEED_LEN];
        getrandom::fill(&mut seed).unwrap();
        let seed_arr = MlKemSeed::from(seed);
        let (_dk, ek) = MlKem768::from_seed(&seed_arr);
        let mut ek_fixed = [0u8; ml_kem_768::EK_LEN];
        ek_fixed.copy_from_slice(ek.to_bytes().as_slice());
        (seed, ek_fixed)
    }

    fn synthetic_signing_key() -> (SigningKey<MlDsa65>, [u8; 32]) {
        let mut seed = [0u8; 32];
        getrandom::fill(&mut seed).unwrap();
        (SigningKey::<MlDsa65>::from_seed(&Seed::from(seed)), seed)
    }

    fn test_secrets() -> HashMap<String, String> {
        HashMap::from([
            (
                "WTF_TESTDEV_SECRET".to_string(),
                "ab12".repeat(16),
            ),
            (
                "SOME_API_KEY".to_string(),
                "value with spaces and 'quotes'".to_string(),
            ),
        ])
    }

    /// Small non-crypto uniqueness helper for test tmp dirs.
    fn test_dir_nonce() -> u64 {
        let mut buf = [0u8; 8];
        getrandom::fill(&mut buf).unwrap();
        u64::from_le_bytes(buf)
    }

    #[test]
    fn wtf_env_key_derivation_and_validation() {
        assert_eq!(wtf_env_key("testdev").unwrap(), "WTF_TESTDEV_SECRET");
        assert_eq!(
            wtf_env_key("my-device_1").unwrap(),
            "WTF_MY_DEVICE_1_SECRET"
        );
        assert!(wtf_env_key("").is_err());
        assert!(wtf_env_key("1abc").is_err());
        assert!(wtf_env_key("bad name").is_err());
        assert!(wtf_env_key("bad.name").is_err());
    }

    #[test]
    fn minted_device_key_is_64_hex() {
        let key = mint_device_key().unwrap();
        assert_eq!(key.len(), 64);
        assert!(key.chars().all(|c| c.is_ascii_hexdigit()));
        assert_ne!(key, mint_device_key().unwrap(), "CSPRNG must not repeat");
    }

    #[test]
    fn envelope_seal_open_roundtrip() {
        let (kem_seed, ek) = synthetic_kem();
        let (signing_key, _signing_seed) = synthetic_signing_key();
        let secrets = test_secrets();

        let envelope = seal_envelope(&secrets, &ek, &signing_key).unwrap();
        assert_eq!(envelope.version, 1);
        assert_eq!(envelope.alg, "ML-KEM-768+ML-DSA-65");
        assert_eq!(envelope.recipient_key_sha3_256.len(), 64);

        // Wire-format sanity: JSON round-trips with the exact contract fields.
        let json = serde_json::to_string(&envelope).unwrap();
        let parsed: Envelope = serde_json::from_str(&json).unwrap();
        for field in [
            "version",
            "alg",
            "recipient_key_sha3_256",
            "signer_pubkey",
            "sig",
            "kem_ct_b64",
            "nonce_b64",
            "ct_b64",
        ] {
            assert!(
                json.contains(field),
                "envelope JSON missing field {}",
                field
            );
        }

        let opened = open_envelope(&parsed, &kem_seed).unwrap();
        assert_eq!(opened, secrets);
    }

    #[test]
    fn envelope_tampered_payload_fails_closed_before_decapsulation() {
        let (kem_seed, ek) = synthetic_kem();
        let (signing_key, _signing_seed) = synthetic_signing_key();

        let mut envelope = seal_envelope(&test_secrets(), &ek, &signing_key).unwrap();
        // Flip one bit of the ciphertext.
        let mut ct = BASE64_STANDARD.decode(envelope.ct_b64.as_bytes()).unwrap();
        ct[0] ^= 0x01;
        envelope.ct_b64 = BASE64_STANDARD.encode(&ct);

        let err = open_envelope(&envelope, &kem_seed).unwrap_err();
        // The signature gate must be what rejected it — before any decapsulation.
        assert!(
            err.contains("signature verification FAILED"),
            "expected fail-closed signature error, got: {}",
            err
        );
    }

    #[test]
    fn envelope_wrong_signer_rejected() {
        let (kem_seed, ek) = synthetic_kem();
        let (signing_key, _signing_seed) = synthetic_signing_key();
        let (other_key, _other_seed) = synthetic_signing_key();

        let mut envelope = seal_envelope(&test_secrets(), &ek, &signing_key).unwrap();
        // Swap in a different (valid) signer pubkey.
        envelope.signer_pubkey = BASE64_STANDARD
            .encode(other_key.verifying_key().encode().as_slice());

        let err = open_envelope(&envelope, &kem_seed).unwrap_err();
        assert!(
            err.contains("signature verification FAILED"),
            "got: {}",
            err
        );
    }

    #[test]
    fn envelope_wrong_recipient_rejected() {
        let (kem_seed, _ek) = synthetic_kem();
        let (_other_seed, other_ek) = synthetic_kem();
        let (signing_key, _signing_seed) = synthetic_signing_key();

        // Sealed for another recipient entirely.
        let envelope = seal_envelope(&test_secrets(), &other_ek, &signing_key).unwrap();
        let err = open_envelope(&envelope, &kem_seed).unwrap_err();
        assert!(
            err.contains("different recipient") || err.contains("decapsulation failed"),
            "got: {}",
            err
        );
    }

    #[test]
    fn envelope_rejects_unknown_version_and_alg_before_keys() {
        let mut envelope = Envelope {
            version: 99,
            alg: ENVELOPE_ALG.to_string(),
            recipient_key_sha3_256: "00".repeat(32),
            signer_pubkey: String::new(),
            sig: String::new(),
            kem_ct_b64: String::new(),
            nonce_b64: String::new(),
            ct_b64: String::new(),
        };
        let err = open_envelope(&envelope, &[0u8; SEED_LEN]).unwrap_err();
        assert!(
            err.contains("unsupported envelope version"),
            "got: {}",
            err
        );

        envelope.version = ENVELOPE_VERSION;
        envelope.alg = "RSA-OAEP".to_string(); // banned classical algorithm must be refused
        let err = open_envelope(&envelope, &[0u8; SEED_LEN]).unwrap_err();
        assert!(err.contains("unsupported envelope alg"), "got: {}", err);
    }

    #[test]
    fn parse_env_lines_supports_pack_compatible_input() {
        let parsed = parse_env_lines("# comment\nexport A=plain\nB=two words\n\n").unwrap();
        assert_eq!(parsed.get("A").map(String::as_str), Some("plain"));
        assert_eq!(parsed.get("B").map(String::as_str), Some("two words"));
        assert!(parse_env_lines("\n").is_err(), "empty input must error");
    }

    #[test]
    fn issue_writes_pack_compatible_bundle_with_minted_key() {
        let dir = std::env::temp_dir().join(format!(
            "pqc-issue-test-{}-{}",
            std::process::id(),
            test_dir_nonce()
        ));
        fs::create_dir_all(&dir).unwrap();

        // Recipient file (engine JSON format) — synthetic key, tmp path only.
        let (kem_seed, ek) = synthetic_kem();
        let pub_path = dir.join("recipient.pub");
        let pub_file = PublicKeyFile {
            alg: ALG.to_string(),
            engine: "test-synthetic".to_string(),
            public_key_b64: BASE64_STANDARD.encode(ek),
            public_key_sha3_256: hex::encode(sha3_256(&ek)),
            created_utc: now_utc(),
        };
        fs::write(
            &pub_path,
            serde_json::to_string_pretty(&pub_file).unwrap(),
        )
        .unwrap();

        // Mint + seal through the issue path primitives.
        let env_key = wtf_env_key("testdev").unwrap();
        let value = mint_device_key().unwrap();
        let mut secrets = HashMap::new();
        secrets.insert(env_key.clone(), value.clone());
        let bundle_path = dir.join("secrets.bundle.json");
        seal_bundle_file(
            &secrets,
            &load_recipient_pub(&pub_path).unwrap(),
            &bundle_path,
        )
        .unwrap();

        // Read the bundle back and open it with the synthetic seed.
        let bundle: Bundle =
            serde_json::from_str(&fs::read_to_string(&bundle_path).unwrap()).unwrap();
        assert_eq!(bundle.version, BUNDLE_VERSION);
        assert_eq!(
            bundle.recipient.public_key_sha3_256,
            hex::encode(sha3_256(&ek))
        );

        let kem_ct = BASE64_STANDARD
            .decode(bundle.kem.ciphertext_b64.as_bytes())
            .unwrap();
        let seed_arr = MlKemSeed::from(kem_seed);
        let (dk, _ek) = MlKem768::from_seed(&seed_arr);
        let ssk = dk.decapsulate_slice(&kem_ct).unwrap();
        let mut kek = derive_kek(ssk.as_slice());
        let keywrap_nonce = BASE64_STANDARD
            .decode(bundle.keywrap.nonce_b64.as_bytes())
            .unwrap();
        let keywrap_ct = BASE64_STANDARD
            .decode(bundle.keywrap.ciphertext_b64.as_bytes())
            .unwrap();
        let data_key = decrypt_aesgcm(&kek, &keywrap_nonce, &keywrap_ct, KEYWRAP_AAD).unwrap();
        kek.zeroize();
        let data_nonce = BASE64_STANDARD
            .decode(bundle.data.nonce_b64.as_bytes())
            .unwrap();
        let data_ct = BASE64_STANDARD
            .decode(bundle.data.ciphertext_b64.as_bytes())
            .unwrap();
        let payload_bytes =
            decrypt_aesgcm(&data_key, &data_nonce, &data_ct, DATA_AAD).unwrap();
        let payload: PayloadSection = serde_json::from_slice(&payload_bytes).unwrap();

        assert_eq!(
            payload.secrets.get(&env_key).map(String::as_str),
            Some(value.as_str())
        );
        assert_eq!(value.len(), 64);

        fs::remove_dir_all(&dir).unwrap();
    }
}
