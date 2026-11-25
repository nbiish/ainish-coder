#!/usr/bin/env python3
"""Post-Quantum Cryptographic (PQC) Agent-Read-Only Cross-Machine Federation CoD Engine.

Provides end-to-end post-quantum confidential and authenticated exchange of
`.agents/federation/{YYYY-MM-DD}.md` Chain of Draft (CoD) ledgers between connected machines:

  - Key Encapsulation:  FIPS 203 ML-KEM-768 (64-byte seed form)
  - Digital Signatures: FIPS 204 ML-DSA-65  (32-byte seed form)
  - Symmetric AEAD:     SP 800-38D AES-256-GCM with AAD-pinned headers
  - KDF / Fingerprints: HKDF-SHA3-256 / SHA3-256
  - Agent Read-Only:    OS-level read-only lock (chmod 444 + macOS uchg / Windows +R)
  - Zero-Secret Guard:  Deterministic git-metadata CoD generation + fail-closed secret/PII/bidi scrubber
  - No Silent Downgrade: Refuses to operate if FIPS 203/204 primitives are unavailable
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

ENVELOPE_FORMAT = "ainish-coder/federation-envelope/v1"
PUBKEY_FORMAT = "ainish-coder/federation-pubkey/v1"
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
ENTRY_SPLIT_RE = re.compile(r"(?m)^(?=### \[)")
ENTRY_TS_RE = re.compile(r"^### \[([^\]]+)\]")
MACHINE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")

# Fail-closed secret/token/PII patterns: scrubbed before signing AND after decryption.
_SECRET_PATTERNS: Tuple[Tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"-----BEGIN [A-Z0-9 ]+PRIVATE KEY-----.*?-----END [A-Z0-9 ]+PRIVATE KEY-----", re.S), "[REDACTED-KEY]"),
    (re.compile(r"\b(?:sk-[A-Za-z0-9_-]{12,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b"), "[REDACTED-TOKEN]"),
    (re.compile(r"\b(?:AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,})\b"), "[REDACTED-TOKEN]"),
    (re.compile(r"(?i)\b(bearer\s+)[A-Za-z0-9._~+/=-]{16,}"), r"\1[REDACTED]"),
    (re.compile(r"(?i)\b([A-Z0-9_]*(?:API_KEY|SECRET|TOKEN|PASSWORD|PASSPHRASE|PRIVATE_KEY)[A-Z0-9_]*)\s*[:=]\s*\S+"), r"\1=[REDACTED]"),
    (re.compile(r"(?i)(/Users/|/home/|C:\\Users\\|C:/Users/)[A-Za-z0-9._-]+"), r"\1<user>"),
    (re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b"), "<ip>"),
    (re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"), "<email>"),
)

# Paths that must never appear in federation scope lines.
_SENSITIVE_PATH_RE = re.compile(
    r"(?i)(^|/)\.env(\.|$)|\.priv$|\.sk$|\.pem$|\.key$|\.p12$|\.pfx$|vault\.pqc|machine\.kek|secrets\.bundle\.json|credentials|id_rsa|id_ed25519"
)

# ANSI escapes, control chars (except \n/\t), and Trojan Source Unicode bidi overrides.
_ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
_BIDI_AND_CTRL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f\u202a-\u202e\u2066-\u2069\u200e\u200f]")


def _require_pqc():
    """Import native FIPS 203 (ML-KEM-768), FIPS 204 (ML-DSA-65), AES-256-GCM, and HKDF-SHA3-256."""
    try:
        from cryptography.hazmat.primitives import hashes
        from cryptography.hazmat.primitives.asymmetric import mldsa, mlkem
        from cryptography.hazmat.primitives.ciphers.aead import AESGCM
        from cryptography.hazmat.primitives.kdf.hkdf import HKDF
    except Exception as exc:
        raise RuntimeError(
            f"PQC federation requires cryptography with FIPS 203 ML-KEM-768 and FIPS 204 ML-DSA-65 "
            f"(no plaintext downgrade permitted): {exc}"
        ) from exc
    if not hasattr(mlkem, "MLKEM768PrivateKey") or not hasattr(mldsa, "MLDSA65PrivateKey"):
        raise RuntimeError(
            "Installed cryptography package lacks MLKEM768PrivateKey / MLDSA65PrivateKey "
            "(no plaintext downgrade permitted)."
        )
    return mlkem, mldsa, AESGCM, HKDF, hashes


def _sha3_fpr(raw: bytes) -> str:
    return "sha3:" + hashlib.sha3_256(raw).hexdigest()[:16]


def _b64e(raw: bytes) -> str:
    return base64.b64encode(raw).decode("ascii")


def _b64d(text: str) -> bytes:
    return base64.b64decode(text.encode("ascii"), validate=True)


def _validate_machine(name: str) -> str:
    if not MACHINE_RE.match(name):
        raise ValueError(f"invalid machine name: {name!r}")
    return name


def _validate_date(date_str: str) -> str:
    if not DATE_RE.match(date_str):
        raise ValueError(f"invalid UTC date (expected YYYY-MM-DD): {date_str!r}")
    return date_str


def default_keys_root(override: Optional[str] = None) -> Path:
    base = override or os.environ.get("AINISH_FEDERATION_KEYS_DIR")
    if base:
        return Path(base).expanduser()
    return Path.home() / ".config" / "ainish-coder" / "federation-keys"


def _mkdir_private(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    if os.name != "nt":
        try:
            os.chmod(path, 0o700)
        except OSError:
            pass


def _write_private_bytes(path: Path, data: bytes) -> None:
    _mkdir_private(path.parent)
    fd, tmp = tempfile.mkstemp(prefix=".pqc-", dir=str(path.parent))
    try:
        if os.name != "nt":
            try:
                os.fchmod(fd, 0o600)
            except OSError:
                pass
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
        os.replace(tmp, path)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def unlock_readonly(path: Path) -> None:
    """Clear OS-level read-only lock so authorized PQC tooling may update the file atomically."""
    if not path.exists() or path.is_symlink():
        return
    if hasattr(os, "chflags"):
        try:
            st = os.stat(path)
            if st.st_flags & 0x0002:  # UF_IMMUTABLE (uchg)
                os.chflags(path, st.st_flags & ~0x0002)
        except OSError:
            pass
    if os.name == "nt":
        try:
            subprocess.run(["attrib", "-R", str(path)], capture_output=True, check=False)
        except OSError:
            pass
    try:
        os.chmod(path, 0o644)
    except OSError:
        pass


def lock_readonly(path: Path) -> None:
    """Apply OS-level read-only lock (agent read-only space): chmod 444 + uchg (macOS) / +R (Windows)."""
    if not path.exists() or path.is_symlink():
        return
    try:
        os.chmod(path, 0o444)
    except OSError:
        pass
    if os.environ.get("AINISH_FEDERATION_NO_IMMUTABLE") == "1":
        return
    if hasattr(os, "chflags"):
        try:
            st = os.stat(path)
            os.chflags(path, st.st_flags | 0x0002)  # UF_IMMUTABLE (uchg)
        except OSError:
            pass
    elif os.name == "nt":
        try:
            subprocess.run(["attrib", "+R", str(path)], capture_output=True, check=False)
        except OSError:
            pass


def scrub_text(text: str, max_len: int = 200) -> str:
    """Strip ANSI/bidi/control chars and redact secrets, tokens, emails, IPs, and home paths."""
    cleaned = _ANSI_RE.sub("", text)
    cleaned = _BIDI_AND_CTRL_RE.sub("", cleaned)
    for pat, repl in _SECRET_PATTERNS:
        cleaned = pat.sub(repl, cleaned)
    cleaned = " ".join(cleaned.splitlines()).strip()
    if len(cleaned) > max_len:
        cleaned = cleaned[: max_len - 1].rstrip() + "…"
    return cleaned


def scrub_entry_block(block: str) -> Optional[str]:
    """Validate and scrub a single CoD entry block. Returns None if malformed."""
    lines = [ln.rstrip() for ln in block.replace("\r\n", "\n").splitlines() if ln.strip()]
    if not lines or not lines[0].startswith("### ["):
        return None
    header = scrub_text(lines[0], max_len=200)
    if not ENTRY_TS_RE.match(header):
        return None
    out = [header]
    allowed_prefixes = ("- scope:", "- cod:", "- integrate:", "- pqc:")
    for ln in lines[1:]:
        s = ln.strip()
        if not s.startswith(allowed_prefixes):
            continue
        out.append(scrub_text(s, max_len=220))
    return "\n".join(out)


def split_federation_doc(text: str) -> Tuple[str, List[str]]:
    norm = text.replace("\r\n", "\n")
    parts = ENTRY_SPLIT_RE.split(norm)
    header = parts[0].rstrip() if parts else ""
    entries: List[str] = []
    for raw in parts[1:]:
        cleaned = scrub_entry_block(raw)
        if cleaned:
            entries.append(cleaned)
    return header, entries


def merge_federation_entries(
    dest_path: Path,
    incoming_entries: List[str],
    fallback_header: str = "",
    date_str: Optional[str] = None,
) -> bool:
    """Deterministically union-merge CoD entries into `dest_path` and lock read-only. Returns True if changed."""
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    existing_text = ""
    dst_hdr = ""
    dst_entries: List[str] = []
    if dest_path.is_file() and not dest_path.is_symlink():
        existing_text = dest_path.read_text(encoding="utf-8", errors="replace")
        dst_hdr, dst_entries = split_federation_doc(existing_text)

    header = dst_hdr if ("<PROTOCOL>" in dst_hdr and "</PROTOCOL>" in dst_hdr) else (fallback_header or dst_hdr)
    if date_str and "{DATE}" in header:
        header = header.replace("{DATE}", date_str)

    seen = set()
    merged: List[str] = []
    for raw in dst_entries + incoming_entries:
        cleaned = scrub_entry_block(raw)
        if cleaned and cleaned not in seen:
            seen.add(cleaned)
            merged.append(cleaned)

    def _sort_key(blk: str) -> Tuple[str, str]:
        m = ENTRY_TS_RE.match(blk)
        return (m.group(1) if m else "", blk)

    merged.sort(key=_sort_key)

    chunks = []
    if header:
        chunks.append(header.rstrip())
    if merged:
        chunks.append("\n\n".join(merged))
    rendered = ("\n\n".join(chunks).rstrip() + "\n") if chunks else ""

    if dest_path.is_file() and existing_text.replace("\r\n", "\n") == rendered:
        lock_readonly(dest_path)
        return False

    unlock_readonly(dest_path)
    fd, tmp_path = tempfile.mkstemp(prefix=".fed-pqc-", dir=str(dest_path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(rendered)
        os.chmod(tmp_path, 0o644)
        os.replace(tmp_path, dest_path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise
    lock_readonly(dest_path)
    return True


def init_identity(machine: str, keys_root: Path) -> Dict[str, Any]:
    """Create or load this machine's FIPS 203 ML-KEM-768 + FIPS 204 ML-DSA-65 federation identity."""
    mlkem, mldsa, _, _, _ = _require_pqc()
    machine = _validate_machine(machine)
    mdir = keys_root / machine
    _mkdir_private(mdir)
    kem_seed_p = mdir / "kem.mlkem768.seed"
    sig_seed_p = mdir / "sig.mldsa65.seed"
    pub_p = mdir / "identity.pub.json"

    if kem_seed_p.is_file() and sig_seed_p.is_file():
        kem_seed = kem_seed_p.read_bytes()
        sig_seed = sig_seed_p.read_bytes()
        kem_sk = mlkem.MLKEM768PrivateKey.from_seed_bytes(kem_seed)
        sig_sk = mldsa.MLDSA65PrivateKey.from_seed_bytes(sig_seed)
    else:
        kem_seed = os.urandom(64)
        sig_seed = os.urandom(32)
        kem_sk = mlkem.MLKEM768PrivateKey.from_seed_bytes(kem_seed)
        sig_sk = mldsa.MLDSA65PrivateKey.from_seed_bytes(sig_seed)
        _write_private_bytes(kem_seed_p, kem_seed)
        _write_private_bytes(sig_seed_p, sig_seed)

    kem_pub = kem_sk.public_key().public_bytes_raw()
    sig_pub = sig_sk.public_key().public_bytes_raw()
    pub_doc: Dict[str, Any] = {
        "format": PUBKEY_FORMAT,
        "machine": machine,
        "kem_alg": "ML-KEM-768",
        "sig_alg": "ML-DSA-65",
        "mlkem768_pub_b64": _b64e(kem_pub),
        "mldsa65_pub_b64": _b64e(sig_pub),
        "kem_fpr": _sha3_fpr(kem_pub),
        "sig_fpr": _sha3_fpr(sig_pub),
    }
    pub_bytes = (json.dumps(pub_doc, indent=2, sort_keys=True) + "\n").encode("utf-8")
    if not pub_p.is_file() or pub_p.read_bytes() != pub_bytes:
        fd, tmp = tempfile.mkstemp(prefix=".pub-", dir=str(mdir))
        try:
            with os.fdopen(fd, "wb") as fh:
                fh.write(pub_bytes)
            os.chmod(tmp, 0o644)
            os.replace(tmp, pub_p)
        except Exception:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise
    return pub_doc


def _load_private_keys(machine: str, keys_root: Path):
    mlkem, mldsa, _, _, _ = _require_pqc()
    machine = _validate_machine(machine)
    mdir = keys_root / machine
    kem_seed_p = mdir / "kem.mlkem768.seed"
    sig_seed_p = mdir / "sig.mldsa65.seed"
    if not kem_seed_p.is_file() or not sig_seed_p.is_file():
        init_identity(machine, keys_root)
    kem_sk = mlkem.MLKEM768PrivateKey.from_seed_bytes(kem_seed_p.read_bytes())
    sig_sk = mldsa.MLDSA65PrivateKey.from_seed_bytes(sig_seed_p.read_bytes())
    return kem_sk, sig_sk


def _parse_pubkey_doc(raw: Dict[str, Any], expected_peer: str) -> Tuple[bytes, bytes, str, str]:
    if raw.get("format") != PUBKEY_FORMAT:
        raise ValueError(f"unexpected peer pubkey format: {raw.get('format')!r}")
    if raw.get("machine") != expected_peer:
        raise ValueError(f"peer pubkey machine mismatch: got {raw.get('machine')!r}, expected {expected_peer!r}")
    if raw.get("kem_alg") != "ML-KEM-768" or raw.get("sig_alg") != "ML-DSA-65":
        raise ValueError("peer pubkey must declare ML-KEM-768 and ML-DSA-65")
    kem_pub = _b64d(str(raw["mlkem768_pub_b64"]))
    sig_pub = _b64d(str(raw["mldsa65_pub_b64"]))
    kem_fpr = _sha3_fpr(kem_pub)
    sig_fpr = _sha3_fpr(sig_pub)
    if raw.get("kem_fpr") != kem_fpr or raw.get("sig_fpr") != sig_fpr:
        raise ValueError("peer pubkey fingerprint does not match raw public key bytes")
    return kem_pub, sig_pub, kem_fpr, sig_fpr


def trust_peer(machine: str, peer: str, pub_file: Path, keys_root: Path, rotate: bool = False) -> Dict[str, str]:
    """Pin peer's PQC public keys on first exchange; fail closed on unexpected key change."""
    _require_pqc()
    machine = _validate_machine(machine)
    peer = _validate_machine(peer)
    incoming = json.loads(pub_file.read_text(encoding="utf-8"))
    _, _, kem_fpr, sig_fpr = _parse_pubkey_doc(incoming, peer)

    peers_dir = keys_root / machine / "peers"
    _mkdir_private(peers_dir)
    pinned_p = peers_dir / f"{peer}.pub.json"
    if pinned_p.is_file() and not rotate:
        existing = json.loads(pinned_p.read_text(encoding="utf-8"))
        _, _, old_kem, old_sig = _parse_pubkey_doc(existing, peer)
        if old_kem != kem_fpr or old_sig != sig_fpr:
            raise PermissionError(
                f"FAIL CLOSED: PQC identity fingerprint changed for peer '{peer}' "
                f"(pinned kem={old_kem} sig={old_sig}, received kem={kem_fpr} sig={sig_fpr}). "
                f"Refusing transfer; re-pin explicitly with --rotate-peer if intentional."
            )
        return {"status": "pinned-match", "kem_fpr": kem_fpr, "sig_fpr": sig_fpr}

    out = (json.dumps(incoming, indent=2, sort_keys=True) + "\n").encode("utf-8")
    fd, tmp = tempfile.mkstemp(prefix=".peer-", dir=str(peers_dir))
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(out)
        os.chmod(tmp, 0o644)
        os.replace(tmp, pinned_p)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    return {"status": "pinned-new" if not rotate else "rotated", "kem_fpr": kem_fpr, "sig_fpr": sig_fpr}


def _load_trusted_peer(machine: str, peer: str, keys_root: Path) -> Tuple[bytes, bytes, str, str]:
    pinned_p = keys_root / _validate_machine(machine) / "peers" / f"{_validate_machine(peer)}.pub.json"
    if not pinned_p.is_file():
        raise PermissionError(f"peer '{peer}' is not pinned in {pinned_p}; exchange & trust public keys first")
    return _parse_pubkey_doc(json.loads(pinned_p.read_text(encoding="utf-8")), peer)


def seal_envelope(
    machine: str,
    peer: str,
    in_file: Path,
    out_file: Path,
    date_str: str,
    keys_root: Path,
    repo_name: str = "",
) -> Dict[str, Any]:
    """Scrub, ML-DSA-65 sign, and ML-KEM-768 + AES-256-GCM seal a federation CoD ledger for `peer`."""
    mlkem, _, AESGCM, HKDF, hashes = _require_pqc()
    machine = _validate_machine(machine)
    peer = _validate_machine(peer)
    date_str = _validate_date(date_str)

    _, sig_sk = _load_private_keys(machine, keys_root)
    sender_sig_fpr = _sha3_fpr(sig_sk.public_key().public_bytes_raw())
    peer_kem_raw, _, peer_kem_fpr, _ = _load_trusted_peer(machine, peer, keys_root)
    peer_kem_pk = mlkem.MLKEM768PublicKey.from_public_bytes(peer_kem_raw)

    raw_text = in_file.read_text(encoding="utf-8", errors="replace")
    _, entries = split_federation_doc(raw_text)

    payload_obj = {
        "date": date_str,
        "sender": machine,
        "recipient": peer,
        "repo": scrub_text(repo_name, max_len=80),
        "sent_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "entries": entries,
    }
    payload_bytes = json.dumps(payload_obj, sort_keys=True, separators=(",", ":")).encode("utf-8")
    sig_input = b"ainish-federation-v1:sig:" + hashlib.sha3_256(payload_bytes).digest()
    signature = sig_sk.sign(sig_input)

    inner_obj = {
        "payload": payload_obj,
        "sig_alg": "ML-DSA-65",
        "sender_sig_fpr": sender_sig_fpr,
        "signature_b64": _b64e(signature),
    }
    inner_bytes = json.dumps(inner_obj, sort_keys=True, separators=(",", ":")).encode("utf-8")

    shared_secret, kem_ct = peer_kem_pk.encapsulate()
    info = f"ainish-federation-v1:aead:{machine}->{peer}:{date_str}".encode("utf-8")
    aead_key = HKDF(algorithm=hashes.SHA3_256(), length=32, salt=None, info=info).derive(shared_secret)
    nonce = os.urandom(12)
    aad = f"ainish-federation-v1:{machine}:{peer}:{date_str}:{sender_sig_fpr}:{peer_kem_fpr}".encode("utf-8")
    ciphertext = AESGCM(aead_key).encrypt(nonce, inner_bytes, aad)

    envelope = {
        "format": ENVELOPE_FORMAT,
        "date": date_str,
        "sender": machine,
        "recipient": peer,
        "kem_alg": "ML-KEM-768",
        "sig_alg": "ML-DSA-65",
        "aead_alg": "AES-256-GCM",
        "kdf_alg": "HKDF-SHA3-256",
        "sender_sig_fpr": sender_sig_fpr,
        "recipient_kem_fpr": peer_kem_fpr,
        "kem_ct_b64": _b64e(kem_ct),
        "nonce_b64": _b64e(nonce),
        "ciphertext_b64": _b64e(ciphertext),
    }
    _write_private_bytes(out_file, (json.dumps(envelope, indent=2, sort_keys=True) + "\n").encode("utf-8"))
    return {"entries": len(entries), "sender_sig_fpr": sender_sig_fpr, "recipient_kem_fpr": peer_kem_fpr}


def open_envelope(
    machine: str,
    expected_sender: str,
    in_file: Path,
    dest_file: Path,
    keys_root: Path,
    template_path: Optional[Path] = None,
) -> Dict[str, Any]:
    """ML-KEM-768 decapsulate, AES-256-GCM decrypt, ML-DSA-65 verify, scrub, union-merge, and lock read-only."""
    _, mldsa, AESGCM, HKDF, hashes = _require_pqc()
    machine = _validate_machine(machine)
    expected_sender = _validate_machine(expected_sender)

    env = json.loads(in_file.read_text(encoding="utf-8"))
    if env.get("format") != ENVELOPE_FORMAT:
        raise ValueError(f"unsupported envelope format: {env.get('format')!r}")
    if env.get("sender") != expected_sender or env.get("recipient") != machine:
        raise PermissionError(
            f"envelope routing mismatch: got {env.get('sender')}->{env.get('recipient')}, "
            f"expected {expected_sender}->{machine}"
        )
    date_str = _validate_date(str(env.get("date", "")))

    kem_sk, _ = _load_private_keys(machine, keys_root)
    my_kem_fpr = _sha3_fpr(kem_sk.public_key().public_bytes_raw())
    if env.get("recipient_kem_fpr") != my_kem_fpr:
        raise PermissionError(
            f"recipient ML-KEM-768 fingerprint mismatch: envelope={env.get('recipient_kem_fpr')} local={my_kem_fpr}"
        )

    _, sender_sig_raw, _, pinned_sender_sig_fpr = _load_trusted_peer(machine, expected_sender, keys_root)
    if env.get("sender_sig_fpr") != pinned_sender_sig_fpr:
        raise PermissionError(
            f"sender ML-DSA-65 fingerprint mismatch for '{expected_sender}': "
            f"envelope={env.get('sender_sig_fpr')} pinned={pinned_sender_sig_fpr}"
        )

    kem_ct = _b64d(str(env["kem_ct_b64"]))
    nonce = _b64d(str(env["nonce_b64"]))
    ciphertext = _b64d(str(env["ciphertext_b64"]))

    shared_secret = kem_sk.decapsulate(kem_ct)
    info = f"ainish-federation-v1:aead:{expected_sender}->{machine}:{date_str}".encode("utf-8")
    aead_key = HKDF(algorithm=hashes.SHA3_256(), length=32, salt=None, info=info).derive(shared_secret)
    aad = (
        f"ainish-federation-v1:{expected_sender}:{machine}:{date_str}:"
        f"{pinned_sender_sig_fpr}:{my_kem_fpr}"
    ).encode("utf-8")
    inner_bytes = AESGCM(aead_key).decrypt(nonce, ciphertext, aad)
    inner = json.loads(inner_bytes.decode("utf-8"))

    payload_obj = inner.get("payload")
    if not isinstance(payload_obj, dict):
        raise ValueError("malformed inner payload")
    if payload_obj.get("sender") != expected_sender or payload_obj.get("recipient") != machine or payload_obj.get("date") != date_str:
        raise PermissionError("inner payload metadata disagrees with authenticated envelope header")

    payload_bytes = json.dumps(payload_obj, sort_keys=True, separators=(",", ":")).encode("utf-8")
    sig_input = b"ainish-federation-v1:sig:" + hashlib.sha3_256(payload_bytes).digest()
    signature = _b64d(str(inner["signature_b64"]))
    sender_sig_pk = mldsa.MLDSA65PublicKey.from_public_bytes(sender_sig_raw)
    sender_sig_pk.verify(signature, sig_input)

    # Defense-in-depth: re-scrub every entry after verification and stamp verified sender fingerprint.
    raw_entries = payload_obj.get("entries") or []
    verified_entries: List[str] = []
    for raw_blk in raw_entries:
        if not isinstance(raw_blk, str):
            continue
        cleaned = scrub_entry_block(raw_blk)
        if cleaned:
            verified_entries.append(cleaned)

    fallback_hdr = ""
    if template_path and template_path.is_file():
        fallback_hdr = template_path.read_text(encoding="utf-8", errors="replace").replace("{DATE}", date_str)
    else:
        fallback_hdr = f"# FEDERATION CoD — {date_str}\n\n---"

    changed = merge_federation_entries(dest_file, verified_entries, fallback_header=fallback_hdr, date_str=date_str)
    return {
        "verified": True,
        "sender": expected_sender,
        "sender_sig_fpr": pinned_sender_sig_fpr,
        "entries": len(verified_entries),
        "changed": changed,
    }


def _git(repo: Path, *args: str) -> str:
    try:
        res = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, timeout=5)
        return res.stdout.strip() if res.returncode == 0 else ""
    except Exception:
        return ""


def deterministic_snapshot(
    repo: Path,
    machine: str,
    date_str: str,
    template_path: Optional[Path] = None,
    pr_ref: str = "none",
) -> Dict[str, Any]:
    """Generate a deterministic, scrubbed CoD entry strictly from git metadata and lock the ledger read-only."""
    machine = _validate_machine(machine)
    date_str = _validate_date(date_str)
    branch = scrub_text(_git(repo, "rev-parse", "--abbrev-ref", "HEAD") or "detached", max_len=60)
    tip = scrub_text(_git(repo, "rev-parse", "--short=7", "HEAD") or "0000000", max_len=12)
    porcelain = _git(repo, "status", "--porcelain")
    dirty_lines = [ln for ln in porcelain.splitlines() if ln.strip()]

    # Collect relative paths only (never file contents, never sensitive/secret filenames).
    paths: List[str] = []
    for ln in dirty_lines:
        rel = ln[3:].strip().split(" -> ")[-1].strip('"')
        if not rel:
            continue
        if _SENSITIVE_PATH_RE.search(rel):
            paths.append("[redacted-path]")
        else:
            paths.append(scrub_text(rel, max_len=60))
    if not paths:
        diff_names = _git(repo, "diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD")
        for rel in diff_names.splitlines()[:5]:
            rel = rel.strip()
            if not rel:
                continue
            paths.append("[redacted-path]" if _SENSITIVE_PATH_RE.search(rel) else scrub_text(rel, max_len=60))
    dedup_paths = list(dict.fromkeys(paths))
    scope = ", ".join(dedup_paths[:5]) if dedup_paths else "clean"
    if len(dedup_paths) > 5:
        scope += f" (+{len(dedup_paths) - 5} more)"

    state = "wip" if dirty_lines else ("ready" if branch not in ("main", "master", "detached") else "clean")
    last_subj = scrub_text(_git(repo, "log", "-1", "--format=%s") or "no commits", max_len=55)
    dirty_note = f"{len(dirty_lines)} dirty path(s)" if dirty_lines else "tree clean"
    cod_line = f"{last_subj} -> {dirty_note} -> sync peer refs"

    # Check if other non-main branches exist to inform integration signal.
    other_branches: List[str] = []
    for ref in _git(repo, "for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes").splitlines():
        r = ref.strip()
        if not r or r in (branch, "main", "master", "origin/main", "origin/master", "origin/HEAD") or r.endswith(("/HEAD", "/main", "/master")):
            continue
        other_branches.append(r)
    integrate = "new-pr" if branch not in ("main", "master", "detached") else "standalone"
    if other_branches and integrate == "new-pr":
        integrate = f"new-pr | check:{scrub_text(other_branches[0], max_len=40)}"

    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    pr_clean = scrub_text(pr_ref, max_len=24) or "none"
    entry = "\n".join([
        f"### [{ts}] {machine} | branch:{branch} | pr:{pr_clean} | tip:{tip} | state:{state}",
        f"- scope: {scope}",
        f"- cod: {cod_line}",
        f"- integrate: {integrate}",
    ])

    dest_file = repo / ".agents" / "federation" / f"{date_str}.md"
    fallback_hdr = ""
    if template_path and template_path.is_file():
        fallback_hdr = template_path.read_text(encoding="utf-8", errors="replace").replace("{DATE}", date_str)
    else:
        fallback_hdr = f"# FEDERATION CoD — {date_str}\n\n---"

    # Skip writing a duplicate checkpoint if the latest entry for this machine already matches tip/branch/state/scope.
    if dest_file.is_file() and not dest_file.is_symlink():
        _, existing = split_federation_doc(dest_file.read_text(encoding="utf-8", errors="replace"))
        for blk in reversed(existing):
            if f"] {machine} | branch:{branch} | " in blk and f"| tip:{tip} | state:{state}" in blk and f"- scope: {scope}" in blk:
                lock_readonly(dest_file)
                return {"dest": str(dest_file), "changed": False, "branch": branch, "tip": tip, "state": state}

    changed = merge_federation_entries(dest_file, [entry], fallback_header=fallback_hdr, date_str=date_str)
    return {"dest": str(dest_file), "changed": changed, "branch": branch, "tip": tip, "state": state}


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="PQC Agent-Read-Only Cross-Machine Federation CoD Engine")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_init = sub.add_parser("init-identity", help="Initialize or load ML-KEM-768 + ML-DSA-65 machine identity")
    p_init.add_argument("--machine", required=True)
    p_init.add_argument("--keys-dir", default=None)
    p_init.add_argument("--print-pub", action="store_true")

    p_trust = sub.add_parser("trust-peer", help="Pin or verify a peer's PQC public keys (fail-closed on change)")
    p_trust.add_argument("--machine", required=True)
    p_trust.add_argument("--peer", required=True)
    p_trust.add_argument("--pub-file", required=True)
    p_trust.add_argument("--keys-dir", default=None)
    p_trust.add_argument("--rotate-peer", action="store_true")

    p_snap = sub.add_parser("snapshot", help="Write deterministic scrubbed CoD checkpoint from git metadata and lock read-only")
    p_snap.add_argument("--repo", required=True)
    p_snap.add_argument("--machine", required=True)
    p_snap.add_argument("--date", default=datetime.now(timezone.utc).strftime("%Y-%m-%d"))
    p_snap.add_argument("--template", default=None)
    p_snap.add_argument("--pr", default="none")

    p_seal = sub.add_parser("seal", help="Scrub, ML-DSA-65 sign, and ML-KEM-768 + AES-256-GCM seal a CoD file")
    p_seal.add_argument("--machine", required=True)
    p_seal.add_argument("--peer", required=True)
    p_seal.add_argument("--in", dest="in_file", required=True)
    p_seal.add_argument("--out", dest="out_file", required=True)
    p_seal.add_argument("--date", required=True)
    p_seal.add_argument("--repo-name", default="")
    p_seal.add_argument("--keys-dir", default=None)

    p_open = sub.add_parser("open", help="Decrypt, verify ML-DSA-65, scrub, union-merge, and lock read-only")
    p_open.add_argument("--machine", required=True)
    p_open.add_argument("--peer", required=True)
    p_open.add_argument("--in", dest="in_file", required=True)
    p_open.add_argument("--dest", required=True)
    p_open.add_argument("--template", default=None)
    p_open.add_argument("--keys-dir", default=None)

    p_lock = sub.add_parser("lock", help="Apply OS read-only lock to a federation file")
    p_lock.add_argument("path")

    p_unlock = sub.add_parser("unlock", help="Clear OS read-only lock on a federation file")
    p_unlock.add_argument("path")

    args = parser.parse_args(argv)
    try:
        if args.cmd == "init-identity":
            doc = init_identity(args.machine, default_keys_root(args.keys_dir))
            if args.print_pub:
                print(json.dumps(doc, indent=2, sort_keys=True))
            else:
                print(json.dumps({"ok": True, "machine": doc["machine"], "kem_fpr": doc["kem_fpr"], "sig_fpr": doc["sig_fpr"]}))
            return 0
        if args.cmd == "trust-peer":
            res = trust_peer(args.machine, args.peer, Path(args.pub_file), default_keys_root(args.keys_dir), rotate=args.rotate_peer)
            print(json.dumps({"ok": True, **res}))
            return 0
        if args.cmd == "snapshot":
            res = deterministic_snapshot(
                Path(args.repo),
                args.machine,
                args.date,
                template_path=Path(args.template) if args.template else None,
                pr_ref=args.pr,
            )
            print(json.dumps({"ok": True, **res}))
            return 0
        if args.cmd == "seal":
            res = seal_envelope(
                args.machine,
                args.peer,
                Path(args.in_file),
                Path(args.out_file),
                args.date,
                default_keys_root(args.keys_dir),
                repo_name=args.repo_name,
            )
            print(json.dumps({"ok": True, **res}))
            return 0
        if args.cmd == "open":
            res = open_envelope(
                args.machine,
                args.peer,
                Path(args.in_file),
                Path(args.dest),
                default_keys_root(args.keys_dir),
                template_path=Path(args.template) if args.template else None,
            )
            print(json.dumps({"ok": True, **res}))
            return 0
        if args.cmd == "lock":
            lock_readonly(Path(args.path))
            return 0
        if args.cmd == "unlock":
            unlock_readonly(Path(args.path))
            return 0
    except PermissionError as exc:
        print(f"federation-pqc: {exc}", file=sys.stderr)
        return 2
    except Exception as exc:
        print(f"federation-pqc: {exc}", file=sys.stderr)
        return 1
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
