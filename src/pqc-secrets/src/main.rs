use std::collections::HashMap;
use std::fs::File;
use std::io::{Read, Write};
use std::path::Path;
use serde::Deserialize;
use base64::prelude::*;
use aes_gcm::{Aes256Gcm, Key, Nonce};
use aes_gcm::aead::{Aead, KeyInit, Payload};
use sha3::{Digest, Sha3_256};
use security_framework::passwords::{get_generic_password, set_generic_password, delete_generic_password};
use fips203::ml_kem_768::{self, DecapsKey, EncapsKey, CipherText};
use fips203::traits::{SerDes, Decaps, Encaps};
use ml_kem::kem::{Decapsulate, FromSeed, KeyExport};
use ml_kem::{MlKem768, Seed as MlKemSeed};
use zeroize::Zeroize;

mod vault;

pub(crate) const ALG: &str = "ML-KEM-768";
pub(crate) const BUNDLE_VERSION: u32 = 1;
pub(crate) const DEFAULT_BUNDLE: &str = "~/.config/pqc-secrets/secrets.bundle.json";
pub(crate) const DEFAULT_PUB: &str = "~/.config/pqc-secrets/recipient.pub";
pub(crate) const DEFAULT_SERVICE: &str = "pqc-secrets";
// Default account name matches the Python `pqc-secrets` skill (which originally generated the keypair).
// The legacy v1 binary used "default"; new keypairs since 2026-06-08 are stored under "pqc-secrets-key".
// Override with PQC_KEYCHAIN_ACCOUNT=<name> if your keychain entry uses a different name.
pub(crate) const DEFAULT_ACCOUNT: &str = "pqc-secrets-key";

/// Keychain account override (matches the canonical Python engine's env var).
pub(crate) fn keychain_account() -> String {
    std::env::var("PQC_KEYCHAIN_ACCOUNT").unwrap_or_else(|_| DEFAULT_ACCOUNT.to_string())
}

// FIPS 203 seed-form private key length (d‖z). Canonical store since 2026-08-20.
pub(crate) const SEED_LEN: usize = 64;

pub(crate) const KEYWRAP_AAD: &[u8] = b"pqc-secrets:v1:keywrap";
pub(crate) const DATA_AAD: &[u8] = b"pqc-secrets:v1:data";
const KDF_INFO: &[u8] = b"pqc-secrets:v1:kek";

#[allow(dead_code)]
#[derive(serde::Serialize, Deserialize, Debug)]
pub(crate) struct Bundle {
    pub(crate) version: u32,
    pub(crate) alg: String,
    pub(crate) engine: String,
    pub(crate) created_utc: String,
    pub(crate) recipient: RecipientSection,
    pub(crate) kem: KemSection,
    pub(crate) keywrap: KeywrapSection,
    pub(crate) data: DataSection,
}

#[derive(serde::Serialize, Deserialize, Debug)]
pub(crate) struct RecipientSection {
    pub(crate) public_key_sha3_256: String,
}

#[derive(serde::Serialize, Deserialize, Debug)]
pub(crate) struct KemSection {
    pub(crate) ciphertext_b64: String,
}

#[allow(dead_code)]
#[derive(serde::Serialize, Deserialize, Debug)]
pub(crate) struct KeywrapSection {
    pub(crate) kdf: String,
    pub(crate) aad: String,
    pub(crate) nonce_b64: String,
    pub(crate) ciphertext_b64: String,
}

#[allow(dead_code)]
#[derive(serde::Serialize, Deserialize, Debug)]
pub(crate) struct DataSection {
    pub(crate) aad: String,
    pub(crate) nonce_b64: String,
    pub(crate) ciphertext_b64: String,
}

#[derive(serde::Serialize, Deserialize, Debug)]
pub(crate) struct PublicKeyFile {
    pub(crate) alg: String,
    pub(crate) engine: String,
    pub(crate) public_key_b64: String,
    pub(crate) public_key_sha3_256: String,
    pub(crate) created_utc: String,
}

#[derive(serde::Serialize, Deserialize, Debug)]
pub(crate) struct PayloadSection {
    pub(crate) secrets: HashMap<String, String>,
}

pub(crate) fn expand_user_path(path: &str) -> String {
    if path.starts_with("~/")
        && let Some(home) = std::env::var_os("HOME")
    {
        let home_str = home.to_string_lossy();
        return format!("{}{}", home_str, &path[1..]);
    }
    path.to_string()
}

pub(crate) fn shell_quote(value: &str) -> String {
    let escaped = value.replace('\'', "'\\''");
    format!("'{}'", escaped)
}

pub(crate) fn derive_kek(shared_secret: &[u8]) -> [u8; 32] {
    let mut hasher = Sha3_256::new();
    hasher.update(shared_secret);
    hasher.update(KDF_INFO);
    hasher.finalize().into()
}

pub(crate) fn sha3_256(data: &[u8]) -> [u8; 32] {
    let mut hasher = Sha3_256::new();
    hasher.update(data);
    hasher.finalize().into()
}

pub(crate) fn now_utc() -> String {
    chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Micros, true)
}

pub(crate) fn encrypt_aesgcm(key: &[u8], nonce: &[u8], plaintext: &[u8], aad: &[u8]) -> Result<Vec<u8>, String> {
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(key));
    let payload = Payload {
        msg: plaintext,
        aad,
    };
    cipher.encrypt(Nonce::from_slice(nonce), payload)
        .map_err(|e| format!("AES-GCM encryption failed: {:?}", e))
}

pub(crate) fn decrypt_aesgcm(key: &[u8], nonce: &[u8], ciphertext: &[u8], aad: &[u8]) -> Result<Vec<u8>, String> {
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(key));
    let payload = Payload {
        msg: ciphertext,
        aad,
    };
    cipher.decrypt(Nonce::from_slice(nonce), payload)
        .map_err(|e| format!("AES-GCM decryption failed: {:?}", e))
}

pub(crate) fn parse_env_lines(raw: &str) -> Result<HashMap<String, String>, String> {
    let mut secrets = HashMap::new();
    for line in raw.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        let line_to_parse = trimmed.strip_prefix("export ").unwrap_or(trimmed);
        if let Some(pos) = line_to_parse.find('=') {
            let key = line_to_parse[..pos].trim().to_string();
            let mut val = line_to_parse[pos+1..].trim().to_string();
            if (val.starts_with('"') && val.ends_with('"')) || (val.starts_with('\'') && val.ends_with('\'')) {
                val = val[1..val.len()-1].to_string();
            }
            if !key.is_empty() {
                secrets.insert(key, val);
            }
        } else {
            return Err(format!("Invalid env line (missing '='): {}", trimmed));
        }
    }
    if secrets.is_empty() {
        return Err("No secrets found".to_string());
    }
    Ok(secrets)
}

/// Decode private-key material from the keychain.
///
/// The canonical Python engine stores `sk.hex()` (hex, lower-case, no separator);
/// legacy Rust v1.0.0 stores stored base64 of the 2400-byte expanded decaps key.
/// Hex is tried first when the string is plausibly hex, then base64.
pub(crate) fn decode_keychain_material(raw: &str) -> Result<Vec<u8>, String> {
    let trimmed = raw.trim();
    if !trimmed.is_empty()
        && trimmed.len().is_multiple_of(2)
        && trimmed.chars().all(|c| c.is_ascii_hexdigit())
        && let Ok(bytes) = hex::decode(trimmed)
    {
        return Ok(bytes);
    }
    BASE64_STANDARD
        .decode(trimmed)
        .map_err(|e| format!("keychain key material is neither hex nor base64: {}", e))
}

pub(crate) fn ensure_parent_dir(path: &Path) -> Result<(), std::io::Error> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    Ok(())
}

fn cmd_keygen(pub_out_raw: &str, force_keychain: bool) -> Result<(), Box<dyn std::error::Error>> {
    // Keychain demotion (Phase 1): the OS keychain is an opt-in convenience,
    // never the source of truth. When a vault exists it is the canonical
    // identity root — refuse silent keychain keygen (fail closed).
    if !force_keychain && vault::vault_exists() {
        return Err(
            "Refusing keychain keygen: a vault exists and is the canonical identity root \
             (the OS keychain is demoted to an opt-in convenience via --use-keychain).\
             \n  - Manage the identity via: pqc-secrets vault <init|status|export-identity|...>\
             \n  - Force legacy keychain keygen anyway: pqc-secrets keygen --use-keychain"
                .into(),
        );
    }
    let pub_path_str = expand_user_path(pub_out_raw);
    let pub_path = Path::new(&pub_path_str);
    
    println!("Generating ML-KEM-768 keypair (seed-form store)...");
    // Seed-form generation (FIPS 203): the 64-byte d‖z seed is the canonical
    // private-key serialization since 2026-08-20 — parity with the canonical
    // Python engine. Expansion uses RustCrypto ml-kem (FromSeed).
    let mut seed = [0u8; SEED_LEN];
    getrandom::fill(&mut seed)?;
    let seed_arr = MlKemSeed::from(seed);
    let (_dk, ek) = MlKem768::from_seed(&seed_arr);

    // Store the seed hex-encoded in the Keychain (Python engine reads hex-first).
    let seed_hex = hex::encode(seed);
    seed.zeroize();

    // Delete first to avoid duplicate errors
    let account = keychain_account();
    let _ = delete_generic_password(DEFAULT_SERVICE, &account);
    set_generic_password(DEFAULT_SERVICE, &account, seed_hex.as_bytes())?;

    // Write public key file (engine-JSON format, readable by both engines)
    let mut ek_fixed = [0u8; ml_kem_768::EK_LEN];
    ek_fixed.copy_from_slice(ek.to_bytes().as_slice());
    let ek_b64 = BASE64_STANDARD.encode(ek_fixed);
    let ek_sha3 = sha3_256(&ek_fixed);
    
    let pub_file_content = PublicKeyFile {
        alg: ALG.to_string(),
        engine: "rust-fips203".to_string(),
        public_key_b64: ek_b64,
        public_key_sha3_256: hex::encode(ek_sha3),
        created_utc: now_utc(),
    };
    
    ensure_parent_dir(pub_path)?;
    let mut file = File::create(pub_path)?;
    file.write_all(serde_json::to_string_pretty(&pub_file_content)?.as_bytes())?;
    
    println!("Public key written to {:?}", pub_path);
    println!("Private key (64-byte FIPS 203 seed, hex) stored securely in macOS Keychain.");
    Ok(())
}

fn cmd_pack(pub_in_raw: &str, bundle_out_raw: &str) -> Result<(), Box<dyn std::error::Error>> {
    let pub_path_str = expand_user_path(pub_in_raw);
    let pub_path = Path::new(&pub_path_str);
    
    let bundle_path_str = expand_user_path(bundle_out_raw);
    let bundle_path = Path::new(&bundle_path_str);
    
    if !pub_path.exists() {
        return Err(format!("Public key file not found at {:?}", pub_path).into());
    }
    
    // Load public key — engine JSON (Rust) or raw hex (canonical Python engine).
    let mut file = File::open(pub_path)?;
    let mut content = String::new();
    file.read_to_string(&mut content)?;
    let pub_file: PublicKeyFile = match serde_json::from_str::<PublicKeyFile>(&content) {
        Ok(pf) => pf,
        Err(_) => {
            let ek_bytes = hex::decode(content.trim())
                .map_err(|_| "Public key file is neither engine JSON nor raw hex")?;
            if ek_bytes.len() != ml_kem_768::EK_LEN {
                return Err(format!(
                    "Hex public key has incorrect length: {} bytes (expected {})",
                    ek_bytes.len(),
                    ml_kem_768::EK_LEN
                )
                .into());
            }
            PublicKeyFile {
                alg: ALG.to_string(),
                engine: "py-native-mlkem".to_string(),
                public_key_b64: BASE64_STANDARD.encode(&ek_bytes),
                public_key_sha3_256: hex::encode(sha3_256(&ek_bytes)),
                created_utc: now_utc(),
            }
        }
    };
    
    if pub_file.alg != ALG {
        return Err(format!("Unsupported algorithm in public key: {}", pub_file.alg).into());
    }
    
    let ek_bytes = BASE64_STANDARD.decode(pub_file.public_key_b64.trim())?;
    let ek_array: [u8; ml_kem_768::EK_LEN] = ek_bytes.try_into()
        .map_err(|_| "Invalid public key size")?;
    let ek = EncapsKey::try_from_bytes(ek_array)
        .map_err(|e| format!("Failed to import public key: {}", e))?;
        
    // Read secrets from stdin
    let mut stdin_raw = String::new();
    std::io::stdin().read_to_string(&mut stdin_raw)?;
    let secrets = parse_env_lines(&stdin_raw)?;
    
    // Encrypt payload
    let payload_struct = PayloadSection { secrets };
    let payload_bytes = serde_json::to_vec(&payload_struct)?;
    
    // Generate data key (32 bytes)
    let mut data_key = [0u8; 32];
    getrandom::fill(&mut data_key)?;
    
    // Encrypt payload with data key
    let mut data_nonce = [0u8; 12];
    getrandom::fill(&mut data_nonce)?;
    let data_ciphertext = encrypt_aesgcm(&data_key, &data_nonce, &payload_bytes, DATA_AAD)?;
    
    // ML-KEM Encapsulation
    let (shared_secret, ct) = ek.try_encaps()
        .map_err(|e| format!("ML-KEM encapsulation failed: {}", e))?;
    let mut shared_secret_bytes = shared_secret.into_bytes();
    let ct_bytes = ct.into_bytes();
    
    // Derive KEK
    let mut kek = derive_kek(&shared_secret_bytes);
    
    // Encrypt data key with KEK (keywrap)
    let mut keywrap_nonce = [0u8; 12];
    getrandom::fill(&mut keywrap_nonce)?;
    let keywrap_ciphertext = encrypt_aesgcm(&kek, &keywrap_nonce, &data_key, KEYWRAP_AAD)?;
    
    // Zeroize sensitive material
    shared_secret_bytes.zeroize();
    kek.zeroize();
    data_key.zeroize();
    
    // Build bundle
    let ek_sha3 = sha3_256(&ek_array);
    let bundle = Bundle {
        version: BUNDLE_VERSION,
        alg: ALG.to_string(),
        engine: "rust-fips203".to_string(),
        created_utc: now_utc(),
        recipient: RecipientSection {
            public_key_sha3_256: hex::encode(ek_sha3),
        },
        kem: KemSection {
            ciphertext_b64: BASE64_STANDARD.encode(ct_bytes),
        },
        keywrap: KeywrapSection {
            kdf: "SHA3-256".to_string(),
            aad: String::from_utf8(KEYWRAP_AAD.to_vec())?,
            nonce_b64: BASE64_STANDARD.encode(keywrap_nonce),
            ciphertext_b64: BASE64_STANDARD.encode(keywrap_ciphertext),
        },
        data: DataSection {
            aad: String::from_utf8(DATA_AAD.to_vec())?,
            nonce_b64: BASE64_STANDARD.encode(data_nonce),
            ciphertext_b64: BASE64_STANDARD.encode(data_ciphertext),
        },
    };
    
    ensure_parent_dir(bundle_path)?;
    let mut file = File::create(bundle_path)?;
    file.write_all(serde_json::to_string_pretty(&bundle)?.as_bytes())?;
    
    println!("Bundle written to {:?}", bundle_path);
    Ok(())
}

fn cmd_export(bundle_in_raw: &str, force_keychain: bool) -> Result<(), Box<dyn std::error::Error>> {
    let bundle_path_str = expand_user_path(bundle_in_raw);
    let bundle_path = Path::new(&bundle_path_str);

    if !bundle_path.exists() {
        eprintln!("Error: Bundle file not found at {:?}", bundle_path);
        std::process::exit(1);
    }

    // Vault-first (Phase 1): when a vault exists it is the canonical identity
    // root — decapsulate via the vault instead of the OS keychain. Existing
    // no-vault behavior is unchanged; --use-keychain forces the legacy path.
    if !force_keychain && vault::vault_exists() {
        return vault::cmd_export_via_vault(bundle_path);
    }

    // Read bundle JSON
    let mut file = File::open(bundle_path)?;
    let mut contents = String::new();
    file.read_to_string(&mut contents)?;
    let bundle: Bundle = serde_json::from_str(&contents)?;

    if bundle.version != BUNDLE_VERSION {
        eprintln!("Error: Unsupported bundle version {}", bundle.version);
        std::process::exit(1);
    }
    if bundle.alg != ALG {
        eprintln!("Error: Unsupported alg {}", bundle.alg);
        std::process::exit(1);
    }

    // Get key from macOS Keychain
    let account = keychain_account();
    let secret_b64_bytes = match get_generic_password(DEFAULT_SERVICE, &account) {
        Ok(bytes) => bytes,
        Err(e) => {
            eprintln!("Error: Private key not found in Keychain (service={}, account={}). Reason: {:?}", 
                      DEFAULT_SERVICE, account, e);
            std::process::exit(1);
        }
    };

    // Decode private-key material: hex seed-form (canonical since 2026-08-20)
    // or base64 expanded-form (legacy v1.0.0 stores).
    let mut secret_raw = String::from_utf8(secret_b64_bytes)?;
    let mut secret_key_bytes = decode_keychain_material(&secret_raw)?;
    secret_raw.zeroize();

    let kem_ciphertext_bytes = BASE64_STANDARD.decode(bundle.kem.ciphertext_b64.trim())?;

    let mut shared_secret_bytes: Vec<u8> = match secret_key_bytes.len() {
        SEED_LEN => {
            // Seed form (FIPS 203 d‖z): expand via RustCrypto ml-kem.
            let seed_bytes: [u8; SEED_LEN] = secret_key_bytes.as_slice().try_into()
                .map_err(|_| "Failed to load 64-byte ML-KEM seed")?;
            secret_key_bytes.zeroize();
            let seed = MlKemSeed::from(seed_bytes);
            let (dk, _ek) = MlKem768::from_seed(&seed);
            let ssk = dk.decapsulate_slice(&kem_ciphertext_bytes)
                .map_err(|e| format!("ML-KEM seed-form decapsulation failed: {}", e))?;
            ssk.as_slice().to_vec()
        }
        len if len == ml_kem_768::DK_LEN => {
            // Legacy expanded decaps key (pre-2026-08-20 stores).
            let mut dk_array = [0u8; ml_kem_768::DK_LEN];
            dk_array.copy_from_slice(&secret_key_bytes);
            secret_key_bytes.zeroize();
            let dk = DecapsKey::try_from_bytes(dk_array)
                .map_err(|e| format!("Failed to import decapsulation key: {}", e))?;
            let ct_array: [u8; ml_kem_768::CT_LEN] = kem_ciphertext_bytes.as_slice().try_into()
                .map_err(|_| "KEM Ciphertext has incorrect length")?;
            let ct = CipherText::try_from_bytes(ct_array)
                .map_err(|e| format!("Failed to import KEM ciphertext: {}", e))?;
            let shared_secret = dk.try_decaps(&ct)
                .map_err(|e| format!("ML-KEM decapsulation failed: {}", e))?;
            shared_secret.into_bytes().to_vec()
        }
        len => {
            eprintln!(
                "Error: Keychain key material has unexpected length: {} bytes (expected {} seed-form or {} expanded-form)",
                len,
                SEED_LEN,
                ml_kem_768::DK_LEN
            );
            std::process::exit(1);
        }
    };

    // Derive KEK
    let mut kek = derive_kek(&shared_secret_bytes);
    shared_secret_bytes.zeroize();

    // Decrypt data key from keywrap
    let keywrap_nonce = BASE64_STANDARD.decode(bundle.keywrap.nonce_b64.trim())?;
    let keywrap_ciphertext = BASE64_STANDARD.decode(bundle.keywrap.ciphertext_b64.trim())?;
    let mut data_key = decrypt_aesgcm(&kek, &keywrap_nonce, &keywrap_ciphertext, KEYWRAP_AAD)?;

    // Decrypt data payload
    let data_nonce = BASE64_STANDARD.decode(bundle.data.nonce_b64.trim())?;
    let data_ciphertext = BASE64_STANDARD.decode(bundle.data.ciphertext_b64.trim())?;
    let payload_bytes = decrypt_aesgcm(&data_key, &data_nonce, &data_ciphertext, DATA_AAD)?;

    // Zeroize sensitive materials
    kek.zeroize();
    data_key.zeroize();

    // Parse payload JSON containing secrets
    let payload: PayloadSection = serde_json::from_slice(&payload_bytes)?;

    // Print shell exports
    let mut keys: Vec<&String> = payload.secrets.keys().collect();
    keys.sort();
    for key in keys {
        let value = &payload.secrets[key];
        println!("export {}={}", key, shell_quote(value));
    }

    Ok(())
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: pqc-secrets <keygen|pack|export|vault> [args]");
        std::process::exit(1);
    }
    
    let result = match args[1].as_str() {
        "keygen" => {
            let mut force_keychain = false;
            let positional: Vec<&String> = args[2..]
                .iter()
                .filter(|a| {
                    if a.as_str() == "--use-keychain" {
                        force_keychain = true;
                        false
                    } else {
                        true
                    }
                })
                .collect();
            let pub_out = positional.first().map(|s| s.as_str()).unwrap_or(DEFAULT_PUB);
            cmd_keygen(pub_out, force_keychain)
        }
        "pack" => {
            let pub_in = args.get(2).map(|s| s.as_str()).unwrap_or(DEFAULT_PUB);
            let bundle_out = args.get(3).map(|s| s.as_str()).unwrap_or(DEFAULT_BUNDLE);
            cmd_pack(pub_in, bundle_out)
        }
        "export" => {
            let mut force_keychain = false;
            let positional: Vec<&String> = args[2..]
                .iter()
                .filter(|a| {
                    if a.as_str() == "--use-keychain" {
                        force_keychain = true;
                        false
                    } else {
                        true
                    }
                })
                .collect();
            let bundle_in = positional.first().map(|s| s.as_str()).unwrap_or(DEFAULT_BUNDLE);
            cmd_export(bundle_in, force_keychain)
        }
        "vault" => vault::dispatch(&args[2..]),
        // Hidden in-memory session holder (spawned by `vault unlock`; KEK on
        // stdin). Routed at top level because the parent spawns it directly.
        vault::HOLDER_ARG => vault::dispatch(&args[1..]),
        cmd => {
            eprintln!("Unknown command: {}", cmd);
            std::process::exit(1);
        }
    };
    
    if let Err(e) = result {
        eprintln!("Error: {}", e);
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decode_keychain_material_hex_seed() {
        let seed = [0xABu8; SEED_LEN];
        let encoded = hex::encode(seed);
        assert_eq!(decode_keychain_material(&encoded).unwrap(), seed.to_vec());
    }

    #[test]
    fn decode_keychain_material_base64_expanded() {
        let dk = [0x5Au8; 2400];
        let encoded = BASE64_STANDARD.encode(dk);
        assert_eq!(decode_keychain_material(&encoded).unwrap(), dk.to_vec());
    }

    #[test]
    fn decode_keychain_material_rejects_junk() {
        assert!(decode_keychain_material("definitely not key material!!").is_err());
    }

    /// Cross-implementation interop: seed-form keypair expanded by RustCrypto
    /// ml-kem must decapsulate ciphertexts produced by the fips203 engine's
    /// encapsulation (this is exactly the live bundle + seed-store scenario).
    #[test]
    fn fips203_encaps_ml_kem_seed_decaps_interop() {
        let mut seed = [0u8; SEED_LEN];
        getrandom::fill(&mut seed).unwrap();
        let seed_arr = MlKemSeed::from(seed);
        let (dk, ek) = MlKem768::from_seed(&seed_arr);

        let mut ek_fixed = [0u8; ml_kem_768::EK_LEN];
        ek_fixed.copy_from_slice(ek.to_bytes().as_slice());
        let fek = ml_kem_768::EncapsKey::try_from_bytes(ek_fixed).unwrap();
        let (ss, ct) = fek.try_encaps().unwrap();
        let ct_bytes = ct.into_bytes();

        let ssk = dk.decapsulate_slice(&ct_bytes).unwrap();
        assert_eq!(ss.into_bytes().as_slice(), ssk.as_slice());
    }
}
