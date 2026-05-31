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
"""

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
KEYCHAIN_ACCOUNT = "default"


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
    return bytes.fromhex(result.stdout.strip())


def _load_public_key() -> bytes:
    """Load ML-KEM-768 public key from disk."""
    if not PUBKEY_PATH.exists():
        print(f"ERROR: Public key not found at {PUBKEY_PATH}. Run 'keygen' first.", file=sys.stderr)
        sys.exit(1)
    return bytes.fromhex(PUBKEY_PATH.read_text().strip())


def cmd_pack() -> None:
    """Read KEY=VALUE lines from stdin, encrypt via AES-256-GCM + ML-KEM-768."""
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

    # Encapsulate: shared_secret = DEK (32 bytes), ciphertext_kem = wrapped key (1088 bytes)
    shared_secret, ciphertext_kem = ML_KEM_768.encaps(pk)

    # Encrypt entries with AES-256-GCM using the shared secret as the key
    nonce = os.urandom(12)
    aesgcm = AESGCM(shared_secret)
    plaintext = json.dumps(entries, sort_keys=True).encode("utf-8")
    ciphertext_aes = aesgcm.encrypt(nonce, plaintext, b"")

    bundle = {
        "version": 1,
        "kem": {
            "algorithm": "ML-KEM-768",
            "ciphertext": ciphertext_kem.hex(),
        },
        "data": {
            "algorithm": "AES-256-GCM",
            "nonce": nonce.hex(),
            "ciphertext": ciphertext_aes.hex(),
        },
    }

    BUNDLE_PATH.write_text(json.dumps(bundle, indent=2, sort_keys=True))
    BUNDLE_PATH.chmod(0o600)
    print(f"Secrets packed: {len(entries)} keys → {BUNDLE_PATH}")


def cmd_export() -> None:
    """Decrypt bundle and output shell export lines."""
    if not BUNDLE_PATH.exists():
        print(f"ERROR: Bundle not found at {BUNDLE_PATH}. Run 'pack' first.", file=sys.stderr)
        sys.exit(1)

    sk = _load_private_key()
    bundle = json.loads(BUNDLE_PATH.read_text())

    # Decapsulate DEK
    ciphertext_kem = bytes.fromhex(bundle["kem"]["ciphertext"])
    dek = ML_KEM_768.decaps(sk, ciphertext_kem)

    # Decrypt entries
    nonce = bytes.fromhex(bundle["data"]["nonce"])
    ciphertext = bytes.fromhex(bundle["data"]["ciphertext"])
    aesgcm = AESGCM(dek)
    plaintext = aesgcm.decrypt(nonce, ciphertext, b"")

    entries = json.loads(plaintext)
    for key, value in entries.items():
        print(f"export {key}={value}")


def cmd_verify() -> None:
    """Verify bundle can be decrypted; list key names only."""
    if not BUNDLE_PATH.exists():
        print(f"Bundle not found at {BUNDLE_PATH}")
        sys.exit(1)

    sk = _load_private_key()
    bundle = json.loads(BUNDLE_PATH.read_text())

    ek = bytes.fromhex(bundle["kem"]["ciphertext"])
    dek = ML_KEM_768.decaps(sk, ek)

    nonce = bytes.fromhex(bundle["data"]["nonce"])
    ciphertext = bytes.fromhex(bundle["data"]["ciphertext"])
    aesgcm = AESGCM(dek)
    plaintext = aesgcm.decrypt(nonce, ciphertext, b"")

    entries = json.loads(plaintext)
    print(f"Bundle valid: {len(entries)} keys")
    for key in sorted(entries.keys()):
        print(f"  {key}")


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: pqc_secrets.py <keygen|pack|export|verify>", file=sys.stderr)
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
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        print("Usage: pqc_secrets.py <keygen|pack|export|verify>", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
