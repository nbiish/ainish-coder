#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "kyber-py>=0.2.0",
#     "cryptography>=44.0",
# ]
# ///
"""
PQC Secrets Management — ML-KEM-768 + AES-256-GCM.
Post-quantum encryption for API keys and private data.

Commands:
  keygen   Generate ML-KEM-768 keypair; private → macOS Keychain, public → ~/.config/pqc-secrets/recipient.pub
  pack     Read KEY=VALUE lines from stdin, encrypt, write ~/.config/pqc-secrets/secrets.bundle.json
  export   Decrypt bundle, output shell 'export KEY=VALUE' lines to stdout
  verify   Check bundle integrity, list key names (no values)
  migrate  Migrate keychain entry from old account name to new account name

Environment variables:
  PQC_KEYCHAIN_ACCOUNT       Keychain account name (default: pqc-secrets-key)
  PQC_KEYCHAIN_ACCOUNT_OLD   Old account name for migrate command (default: default)
  PQC_KEYCHAIN_ACCOUNT_NEW   New account name for migrate command (default: pqc-secrets-key)
"""

import base64
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from kyber_py.ml_kem import ML_KEM_768

CONFIG_DIR = Path.home() / ".config" / "pqc-secrets"
PUBKEY_PATH = CONFIG_DIR / "recipient.pub"
BUNDLE_PATH = CONFIG_DIR / "secrets.bundle.json"
KEYCHAIN_SERVICE = "pqc-secrets"
KEYCHAIN_ACCOUNT = os.environ.get("PQC_KEYCHAIN_ACCOUNT", "pqc-secrets-key")
KDF_INFO = b"pqc-secrets:v1:kek"


def _ensure_config_dir() -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_DIR.chmod(0o700)


def cmd_keygen() -> None:
    """Generate ML-KEM-768 keypair. Private → macOS Keychain. Public → disk."""
    _ensure_config_dir()

    pk, sk = ML_KEM_768.keygen()

    # Store private key in macOS Keychain
    sk_hex = sk.hex()
    subprocess.run(
        [
            "security", "add-generic-password",
            "-s", KEYCHAIN_SERVICE,
            "-a", KEYCHAIN_ACCOUNT,
            "-w", sk_hex,
            "-U",
        ],
        check=True,
        capture_output=True,
    )

    # Write public key to disk
    pk_hex = pk.hex()
    PUBKEY_PATH.write_text(pk_hex)
    PUBKEY_PATH.chmod(0o600)

    print(f"ML-KEM-768 keypair generated.")
    print(f"  Private key: macOS Keychain (service={KEYCHAIN_SERVICE}, account={KEYCHAIN_ACCOUNT})")
    print(f"  Public key:  {PUBKEY_PATH}")


def _load_private_key() -> bytes:
    """Load ML-KEM-768 private key from macOS Keychain."""
    result = subprocess.run(
        [
            "security", "find-generic-password",
            "-s", KEYCHAIN_SERVICE,
            "-a", KEYCHAIN_ACCOUNT,
            "-w",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    raw = result.stdout.strip()
    try:
        return bytes.fromhex(raw)
    except ValueError:
        return base64.b64decode(raw)


def _load_public_key() -> bytes:
    """Load ML-KEM-768 public key from disk.

    Supports both formats:
    - Rust engine (JSON): {"public_key_b64": "...", "engine": "rust-fips203"}
    - Legacy Python (hex): raw hex string
    """
    if not PUBKEY_PATH.exists():
        print(f"ERROR: Public key not found at {PUBKEY_PATH}. Run 'keygen' first.", file=sys.stderr)
        sys.exit(1)
    raw = PUBKEY_PATH.read_text().strip()
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict) and "public_key_b64" in parsed:
            return base64.b64decode(parsed["public_key_b64"])
    except (json.JSONDecodeError, ValueError):
        pass
    return bytes.fromhex(raw)


def cmd_pack() -> None:
    """Read KEY=VALUE lines from stdin, encrypt via AES-256-GCM + ML-KEM-768.

    Produces a Rust-compatible bundle with keywrap layer and AAD.
    """
    _ensure_config_dir()

    pk = _load_public_key()
    lines = sys.stdin.read().strip()
    if not lines:
        print("ERROR: No input provided on stdin.", file=sys.stderr)
        sys.exit(1)

    # Parse KEY=VALUE pairs
    entries: dict[str, str] = {}
    for line in lines.split("\n"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        entries[key.strip()] = value.strip()

    if not entries:
        print("ERROR: No valid KEY=VALUE pairs found in input.", file=sys.stderr)
        sys.exit(1)

    # Generate random data key (32 bytes)
    data_key = os.urandom(32)

    # Encrypt payload with data key
    data_nonce = os.urandom(12)
    payload_plaintext = json.dumps({"secrets": entries}, sort_keys=True).encode("utf-8")
    data_ciphertext = AESGCM(data_key).encrypt(data_nonce, payload_plaintext, b"pqc-secrets:v1:data")

    # ML-KEM encapsulation
    shared_secret, ciphertext_kem = ML_KEM_768.encaps(pk)

    # Derive KEK from shared secret
    kek = hashlib.sha3_256(shared_secret + KDF_INFO).digest()

    # Wrap data key with KEK
    keywrap_nonce = os.urandom(12)
    keywrap_ciphertext = AESGCM(kek).encrypt(keywrap_nonce, data_key, b"pqc-secrets:v1:keywrap")

    bundle = {
        "version": 1,
        "alg": "ML-KEM-768",
        "engine": "kyber-py",
        "created_utc": __import__("datetime").datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.") + f"{__import__("datetime").datetime.utcnow().microsecond:06d}Z",
        "recipient": {
            "public_key_sha3_256": hashlib.sha3_256(pk).hexdigest(),
        },
        "kem": {
            "ciphertext_b64": base64.b64encode(ciphertext_kem).decode(),
        },
        "keywrap": {
            "kdf": "SHA3-256",
            "aad": "pqc-secrets:v1:keywrap",
            "nonce_b64": base64.b64encode(keywrap_nonce).decode(),
            "ciphertext_b64": base64.b64encode(keywrap_ciphertext).decode(),
        },
        "data": {
            "aad": "pqc-secrets:v1:data",
            "nonce_b64": base64.b64encode(data_nonce).decode(),
            "ciphertext_b64": base64.b64encode(data_ciphertext).decode(),
        },
    }

    BUNDLE_PATH.write_text(json.dumps(bundle, indent=2, sort_keys=True))
    BUNDLE_PATH.chmod(0o600)
    print(f"Secrets packed: {len(entries)} keys → {BUNDLE_PATH}")


def _decrypt_bundle(bundle: dict, sk: bytes) -> dict[str, str]:
    """Decrypt a bundle, handling both legacy (hex) and Rust-engine (b64+keywrap) formats."""
    # Decapsulate DEK from KEM ciphertext
    kem = bundle["kem"]
    if "ciphertext_b64" in kem:
        ciphertext_kem = base64.b64decode(kem["ciphertext_b64"])
    else:
        ciphertext_kem = bytes.fromhex(kem["ciphertext"])
    dek = ML_KEM_768.decaps(sk, ciphertext_kem)

    # Derive the data key (DK)
    if "keywrap" in bundle:
        kw = bundle["keywrap"]
        kw_ct = base64.b64decode(kw["ciphertext_b64"])
        kw_nonce = base64.b64decode(kw["nonce_b64"])
        kw_aad = kw.get("aad", "pqc-secrets:v1:keywrap").encode("utf-8")
        kek = hashlib.sha3_256(dek + KDF_INFO).digest() if kw.get("kdf") == "SHA3-256" else dek
        dk = AESGCM(kek).decrypt(kw_nonce, kw_ct, kw_aad)
    else:
        dk = dek

    # Decrypt the data payload
    data_sec = bundle["data"]
    if "nonce_b64" in data_sec:
        nonce = base64.b64decode(data_sec["nonce_b64"])
    else:
        nonce = bytes.fromhex(data_sec["nonce"])
    if "ciphertext_b64" in data_sec:
        ciphertext = base64.b64decode(data_sec["ciphertext_b64"])
    else:
        ciphertext = bytes.fromhex(data_sec["ciphertext"])
    data_aad = data_sec.get("aad", "").encode("utf-8")

    plaintext = AESGCM(dk).decrypt(nonce, ciphertext, data_aad)
    return json.loads(plaintext)


def cmd_export() -> None:
    """Decrypt bundle and output shell export lines."""
    if not BUNDLE_PATH.exists():
        print(f"ERROR: Bundle not found at {BUNDLE_PATH}. Run 'pack' first.", file=sys.stderr)
        sys.exit(1)

    sk = _load_private_key()
    bundle = json.loads(BUNDLE_PATH.read_text())
    payload = _decrypt_bundle(bundle, sk)

    # Rust engine wraps secrets in {"secrets": {...}}; legacy packs directly
    entries = payload.get("secrets", payload) if isinstance(payload, dict) and "secrets" in payload else payload

    for key, value in entries.items():
        print(f"export {key}={value}")


def cmd_verify() -> None:
    """Verify bundle can be decrypted; list key names only."""
    if not BUNDLE_PATH.exists():
        print(f"Bundle not found at {BUNDLE_PATH}")
        sys.exit(1)

    sk = _load_private_key()
    bundle = json.loads(BUNDLE_PATH.read_text())
    payload = _decrypt_bundle(bundle, sk)

    entries = payload.get("secrets", payload) if isinstance(payload, dict) and "secrets" in payload else payload

    print(f"Bundle valid: {len(entries)} keys")
    for key in sorted(entries.keys()):
        print(f"  {key}")


def cmd_migrate() -> None:
    """Migrate keychain entry from old account name to new account name."""
    old_account = os.environ.get("PQC_KEYCHAIN_ACCOUNT_OLD", "default")
    new_account = os.environ.get("PQC_KEYCHAIN_ACCOUNT_NEW", KEYCHAIN_ACCOUNT)

    if old_account == new_account:
        print(f"Old and new account names are the same ({old_account}). Nothing to migrate.")
        return

    # Read from old account
    try:
        result = subprocess.run(
            [
                "security", "find-generic-password",
                "-s", KEYCHAIN_SERVICE,
                "-a", old_account,
                "-w",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        sk_hex = result.stdout.strip()
    except subprocess.CalledProcessError:
        print(f"ERROR: No keychain entry found for service={KEYCHAIN_SERVICE}, account={old_account}", file=sys.stderr)
        sys.exit(1)

    # Delete old entry
    subprocess.run(
        [
            "security", "delete-generic-password",
            "-s", KEYCHAIN_SERVICE,
            "-a", old_account,
        ],
        check=False,
        capture_output=True,
    )

    # Add new entry
    subprocess.run(
        [
            "security", "add-generic-password",
            "-s", KEYCHAIN_SERVICE,
            "-a", new_account,
            "-w", sk_hex,
            "-U",
        ],
        check=True,
        capture_output=True,
    )

    print(f"Migrated keychain entry: service={KEYCHAIN_SERVICE}, account={old_account} → {new_account}")


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: pqc_secrets.py <keygen|pack|export|verify|migrate>", file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "keygen":
        cmd_keygen()
    elif cmd == "pack":
        cmd_pack()
    elif cmd == "export":
        cmd_export()
    elif cmd == "verify":
        cmd_verify()
    elif cmd == "migrate":
        cmd_migrate()
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        print("Usage: pqc_secrets.py <keygen|pack|export|verify|migrate>", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
