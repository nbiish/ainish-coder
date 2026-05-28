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
use fips203::ml_kem_768::{self, KG, DecapsKey, EncapsKey, CipherText};
use fips203::traits::{SerDes, Decaps, Encaps, KeyGen};
use zeroize::Zeroize;

const ALG: &str = "ML-KEM-768";
const BUNDLE_VERSION: u32 = 1;
const DEFAULT_BUNDLE: &str = "~/.config/pqc-secrets/secrets.bundle.json";
const DEFAULT_PUB: &str = "~/.config/pqc-secrets/recipient.pub";
const DEFAULT_SERVICE: &str = "pqc-secrets";
const DEFAULT_ACCOUNT: &str = "default";

const KEYWRAP_AAD: &[u8] = b"pqc-secrets:v1:keywrap";
const DATA_AAD: &[u8] = b"pqc-secrets:v1:data";
const KDF_INFO: &[u8] = b"pqc-secrets:v1:kek";

#[allow(dead_code)]
#[derive(serde::Serialize, Deserialize, Debug)]
struct Bundle {
    version: u32,
    alg: String,
    engine: String,
    created_utc: String,
    recipient: RecipientSection,
    kem: KemSection,
    keywrap: KeywrapSection,
    data: DataSection,
}

#[derive(serde::Serialize, Deserialize, Debug)]
struct RecipientSection {
    public_key_sha3_256: String,
}

#[derive(serde::Serialize, Deserialize, Debug)]
struct KemSection {
    ciphertext_b64: String,
}

#[allow(dead_code)]
#[derive(serde::Serialize, Deserialize, Debug)]
struct KeywrapSection {
    kdf: String,
    aad: String,
    nonce_b64: String,
    ciphertext_b64: String,
}

#[allow(dead_code)]
#[derive(serde::Serialize, Deserialize, Debug)]
struct DataSection {
    aad: String,
    nonce_b64: String,
    ciphertext_b64: String,
}

#[derive(serde::Serialize, Deserialize, Debug)]
struct PublicKeyFile {
    alg: String,
    engine: String,
    public_key_b64: String,
    public_key_sha3_256: String,
    created_utc: String,
}

#[derive(serde::Serialize, Deserialize, Debug)]
struct PayloadSection {
    secrets: HashMap<String, String>,
}

fn expand_user_path(path: &str) -> String {
    if path.starts_with("~/") {
        if let Some(home) = std::env::var_os("HOME") {
            let home_str = home.to_string_lossy();
            return format!("{}{}", home_str, &path[1..]);
        }
    }
    path.to_string()
}

fn shell_quote(value: &str) -> String {
    let escaped = value.replace('\'', "'\\''");
    format!("'{}'", escaped)
}

fn derive_kek(shared_secret: &[u8]) -> [u8; 32] {
    let mut hasher = Sha3_256::new();
    hasher.update(shared_secret);
    hasher.update(KDF_INFO);
    hasher.finalize().into()
}

fn sha3_256(data: &[u8]) -> [u8; 32] {
    let mut hasher = Sha3_256::new();
    hasher.update(data);
    hasher.finalize().into()
}

fn now_utc() -> String {
    chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Micros, true)
}

fn encrypt_aesgcm(key: &[u8], nonce: &[u8], plaintext: &[u8], aad: &[u8]) -> Result<Vec<u8>, String> {
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(key));
    let payload = Payload {
        msg: plaintext,
        aad,
    };
    cipher.encrypt(Nonce::from_slice(nonce), payload)
        .map_err(|e| format!("AES-GCM encryption failed: {:?}", e))
}

fn decrypt_aesgcm(key: &[u8], nonce: &[u8], ciphertext: &[u8], aad: &[u8]) -> Result<Vec<u8>, String> {
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(key));
    let payload = Payload {
        msg: ciphertext,
        aad,
    };
    cipher.decrypt(Nonce::from_slice(nonce), payload)
        .map_err(|e| format!("AES-GCM decryption failed: {:?}", e))
}

fn parse_env_lines(raw: &str) -> Result<HashMap<String, String>, String> {
    let mut secrets = HashMap::new();
    for line in raw.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        let line_to_parse = if trimmed.starts_with("export ") {
            &trimmed[7..]
        } else {
            trimmed
        };
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

fn ensure_parent_dir(path: &Path) -> Result<(), std::io::Error> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    Ok(())
}

fn cmd_keygen(pub_out_raw: &str) -> Result<(), Box<dyn std::error::Error>> {
    let pub_path_str = expand_user_path(pub_out_raw);
    let pub_path = Path::new(&pub_path_str);
    
    println!("Generating ML-KEM-768 keypair...");
    let (ek, dk) = KG::try_keygen().map_err(|e| format!("ML-KEM keygen failed: {}", e))?;
    
    let ek_bytes = ek.into_bytes();
    let dk_bytes = dk.into_bytes();
    
    // Store private key in Keychain
    let dk_b64 = BASE64_STANDARD.encode(dk_bytes);
    
    // Delete first to avoid duplicate errors
    let _ = delete_generic_password(DEFAULT_SERVICE, DEFAULT_ACCOUNT);
    set_generic_password(DEFAULT_SERVICE, DEFAULT_ACCOUNT, dk_b64.as_bytes())?;
    
    // Write public key file
    let ek_b64 = BASE64_STANDARD.encode(ek_bytes);
    let ek_sha3 = sha3_256(&ek_bytes);
    
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
    println!("Private key stored securely in macOS Keychain.");
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
    
    // Load public key
    let mut file = File::open(pub_path)?;
    let mut content = String::new();
    file.read_to_string(&mut content)?;
    let pub_file: PublicKeyFile = serde_json::from_str(&content)?;
    
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

fn cmd_export(bundle_in_raw: &str) -> Result<(), Box<dyn std::error::Error>> {
    let bundle_path_str = expand_user_path(bundle_in_raw);
    let bundle_path = Path::new(&bundle_path_str);

    if !bundle_path.exists() {
        eprintln!("Error: Bundle file not found at {:?}", bundle_path);
        std::process::exit(1);
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
    let secret_b64_bytes = match get_generic_password(DEFAULT_SERVICE, DEFAULT_ACCOUNT) {
        Ok(bytes) => bytes,
        Err(e) => {
            eprintln!("Error: Private key not found in Keychain (service={}, account={}). Reason: {:?}", 
                      DEFAULT_SERVICE, DEFAULT_ACCOUNT, e);
            std::process::exit(1);
        }
    };

    // Decode private key
    let mut secret_b64 = String::from_utf8(secret_b64_bytes)?;
    let secret_b64_trimmed = secret_b64.trim();
    let secret_key_bytes = BASE64_STANDARD.decode(secret_b64_trimmed)?;
    secret_b64.zeroize();

    if secret_key_bytes.len() != ml_kem_768::DK_LEN {
        eprintln!("Error: Decapsulation key has incorrect length: {} bytes (expected {})", 
                  secret_key_bytes.len(), ml_kem_768::DK_LEN);
        std::process::exit(1);
    }

    // ML-KEM Decapsulation
    let dk_array: [u8; ml_kem_768::DK_LEN] = secret_key_bytes.try_into().unwrap();
    let dk = DecapsKey::try_from_bytes(dk_array)
        .map_err(|e| format!("Failed to import decapsulation key: {}", e))?;

    let kem_ciphertext_bytes = BASE64_STANDARD.decode(bundle.kem.ciphertext_b64.trim())?;
    let ct_array: [u8; ml_kem_768::CT_LEN] = kem_ciphertext_bytes.try_into()
        .map_err(|_| "KEM Ciphertext has incorrect length")?;
    let ct = CipherText::try_from_bytes(ct_array)
        .map_err(|e| format!("Failed to import KEM ciphertext: {}", e))?;

    let shared_secret = dk.try_decaps(&ct)
        .map_err(|e| format!("ML-KEM decapsulation failed: {}", e))?;

    let shared_secret_bytes = shared_secret.into_bytes();

    // Derive KEK
    let mut kek = derive_kek(&shared_secret_bytes);

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
        eprintln!("Usage: pqc-secrets <keygen|pack|export> [args]");
        std::process::exit(1);
    }
    
    let result = match args[1].as_str() {
        "keygen" => {
            let pub_out = args.get(2).map(|s| s.as_str()).unwrap_or(DEFAULT_PUB);
            cmd_keygen(pub_out)
        }
        "pack" => {
            let pub_in = args.get(2).map(|s| s.as_str()).unwrap_or(DEFAULT_PUB);
            let bundle_out = args.get(3).map(|s| s.as_str()).unwrap_or(DEFAULT_BUNDLE);
            cmd_pack(pub_in, bundle_out)
        }
        "export" => {
            let bundle_in = args.get(2).map(|s| s.as_str()).unwrap_or(DEFAULT_BUNDLE);
            cmd_export(bundle_in)
        }
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
