#!/usr/bin/env python3
"""Scroll v2 integrity engine — ML-DSA-65 signed manifests (FIPS 204).

Pipeline per research/07-integration-contract.md C2/C3 and
research/10-build-spec-integrity.md:

    manifest -> sign -> verify -> (operator confirm) -> deploy -> COMMS ledger

The signed object is the SHA3-256 digest of manifest.json BYTES. Verify
recomputes everything from disk at check time; a stored digest is never
trusted. Signing seeds arrive via environment variables only:

    AINISHCODER_SCROLL_SIGN_SEED    (required for sign; hex 64 = 32 bytes)
    AINISHCODER_SCROLL_COUNCIL_SEED (required for --council; hex 64 = 32 bytes)

Seeds are never echoed, never written to disk, never logged.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import subprocess  # nosec B404 - only ever runs `git rev-parse HEAD`, no user input
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

MANIFEST_NAME = "manifest.json"
SIG_NAME = "manifest.sig"
SIG2_NAME = "manifest.sig2"
PUB_NAME = "manifest.pub"
PUB2_NAME = "manifest.pub2"

SCHEMA_VERSION = "v2.0"
BOUNDARY = "public-teachings-only"

SIGN_SEED_ENV = "AINISHCODER_SCROLL_SIGN_SEED"
COUNCIL_SEED_ENV = "AINISHCODER_SCROLL_COUNCIL_SEED"

# What the walker hashes: regular files under <dir> (recursive). Payload
# artifact names and any symlinked/dead files are excluded below.


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _sha3_256(data: bytes) -> bytes:
    return hashlib.sha3_256(data).digest()


def _walk_files(root: Path, exclude: set[str]) -> list[Path]:
    """Deterministic recursive listing of regular files under root."""
    found: list[Path] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        rel = path.relative_to(root).as_posix()
        if rel in exclude or rel.startswith(".git/"):
            continue
        found.append(path)
    return found


def _source_commit(repo_hint: Path) -> str:
    """git rev-parse HEAD of the directory's repo; '' when not a repo."""
    try:
        result = subprocess.run(  # nosec B603 - fixed argv, no user input
            ["git", "-C", str(repo_hint), "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def _load_public_key(raw_b64: str) -> Any:
    from cryptography.hazmat.primitives.asymmetric import mldsa

    pub = mldsa.MLDSA65PublicKey.from_public_bytes(base64.b64decode(raw_b64))
    return pub


def _seed_from_env(env_name: str, purpose: str) -> bytes:
    value = os.environ.get(env_name, "")
    if not value:
        print(
            f"error: {env_name} is not set; load the {purpose} key from the PQC "
            f"bundle first, e.g.:\n  pqc-secrets export {env_name}\n"
            "Keys are never generated silently and never stored on disk in plaintext.",
            file=sys.stderr,
        )
        raise SystemExit(2)
    try:
        seed = bytes.fromhex(value)
    except ValueError:
        raise SystemExit(f"error: {env_name} is not valid hex") from None
    if len(seed) != 32:
        raise SystemExit(f"error: {env_name} must decode to 32 bytes (64 hex chars)")
    return seed


def _require_mldsa() -> None:
    try:
        from cryptography.hazmat.primitives.asymmetric import mldsa  # noqa: F401
    except ImportError:
        raise SystemExit(
            "error: this cryptography build has no ML-DSA support (mldsa module, "
            "added in cryptography 47.0.0). Re-run with a resolved version that "
            "provides it, e.g.:\n"
            "  uv run --with 'cryptography>=46' python scripts/scrolls/scroll_manifest.py ...\n"
            "from a directory whose Python matches the repository pin (.python-version 3.10)."
        ) from None


def _sign_digest(seed: bytes, digest: bytes) -> bytes:
    from cryptography.hazmat.primitives.asymmetric import mldsa

    return mldsa.MLDSA65PrivateKey.from_seed_bytes(seed).sign(digest)


def _public_key_bytes(seed: bytes) -> bytes:
    from cryptography.hazmat.primitives.asymmetric import mldsa

    return mldsa.MLDSA65PrivateKey.from_seed_bytes(seed).public_key().public_bytes_raw()


def build_manifest(target: Path, author: str, out_name: str) -> dict[str, Any]:
    """Walk target and produce the manifest dict (not yet written)."""
    files = []
    for path in _walk_files(target, exclude={out_name}):
        data = path.read_bytes()
        files.append(
            {
                "path": path.relative_to(target).as_posix(),
                "sha3_256": _sha3_256(data).hex(),
                "bytes": len(data),
            }
        )
    files.sort(key=lambda entry: entry["path"])
    return {
        "version": SCHEMA_VERSION,
        "author": author,
        "timestamp": _now_iso(),
        "source_commit": _source_commit(target),
        "files": files,
        "carriers": [],
        "boundary": BOUNDARY,
    }


def cmd_manifest(args: argparse.Namespace) -> int:
    target = Path(args.dir).resolve()
    if not target.is_dir():
        raise SystemExit(f"error: not a directory: {target}")
    author = (
        args.author or os.environ.get("USER") or os.environ.get("USERNAME") or "unknown"
    )
    out_name = Path(args.out).name if args.out else MANIFEST_NAME
    manifest = build_manifest(target, author, out_name)
    payload = (json.dumps(manifest, sort_keys=True, indent=2) + "\n").encode()
    out_path = target / (args.out or MANIFEST_NAME)
    out_path.write_bytes(payload)
    print(f"manifest: {out_path} ({len(manifest['files'])} files)")
    print(f"manifest sha3_256: {_sha3_256(payload).hex()}")
    return 0


def cmd_sign(args: argparse.Namespace) -> int:
    target = Path(args.dir).resolve()
    if not target.is_dir():
        raise SystemExit(f"error: not a directory: {target}")
    _require_mldsa()
    manifest_path = target / MANIFEST_NAME
    if not manifest_path.is_file():
        # Compute manifest first (author from env/USER), then sign.
        author = (
            os.environ.get("AINISHCODER_SCROLL_AUTHOR")
            or os.environ.get("USER")
            or "unknown"
        )
        manifest = build_manifest(target, author, MANIFEST_NAME)
        manifest_path.write_bytes(
            (json.dumps(manifest, sort_keys=True, indent=2) + "\n").encode()
        )
        print(f"manifest generated: {manifest_path}")

    payload = manifest_path.read_bytes()
    digest = _sha3_256(payload)

    seed = _seed_from_env(SIGN_SEED_ENV, "scroll signing")
    signature = _sign_digest(seed, digest)
    (target / SIG_NAME).write_bytes(base64.b64encode(signature) + b"\n")
    (target / PUB_NAME).write_bytes(base64.b64encode(_public_key_bytes(seed)) + b"\n")
    print(f"signed: {target / SIG_NAME}")
    print(f"public key: {target / PUB_NAME}")
    print(f"manifest sha3_256: {digest.hex()}")
    if args.council:
        council_seed = _seed_from_env(COUNCIL_SEED_ENV, "council cosigning")
        council_sig = _sign_digest(council_seed, digest)
        (target / SIG2_NAME).write_bytes(base64.b64encode(council_sig) + b"\n")
        (target / PUB2_NAME).write_bytes(
            base64.b64encode(_public_key_bytes(council_seed)) + b"\n"
        )
        print(f"council signed: {target / SIG2_NAME}")
    return 0


def _verify_one_sig(pub_b64: str, sig_path: Path, digest: bytes) -> str | None:
    """Return None on success, else a failure reason line."""
    from cryptography.exceptions import InvalidSignature

    if not sig_path.is_file():
        return f"missing signature: {sig_path}"
    try:
        sig = base64.b64decode(sig_path.read_bytes().strip(), validate=True)
    except (ValueError, TypeError):
        return f"invalid base64 signature: {sig_path}"
    try:
        pub = _load_public_key(pub_b64)
    except (ValueError, TypeError):
        return f"invalid public key: {sig_path.parent / PUB_NAME}"
    try:
        pub.verify(sig, digest)
    except InvalidSignature:
        return f"signature mismatch: {sig_path}"
    return None


def cmd_verify(args: argparse.Namespace) -> int:
    target = Path(args.dir).resolve()
    _require_mldsa()
    failures: list[str] = []

    manifest_path = target / MANIFEST_NAME
    sig_path = target / SIG_NAME
    pub_path = target / PUB_NAME
    if not manifest_path.is_file():
        print(f"FAIL verify {target}: missing {manifest_path}")
        return 1
    if not pub_path.is_file():
        print(f"FAIL verify {target}: missing {pub_path}")
        return 1

    try:
        manifest = json.loads(manifest_path.read_text())
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        print(f"FAIL verify {target}: manifest.json is not valid JSON: {exc}")
        return 1

    # 1. Per-file integrity: recompute SHA3-256 from disk bytes.
    for entry in manifest.get("files", []):
        rel = entry.get("path", "")
        fpath = target / rel
        if not fpath.is_file():
            failures.append(f"file missing: {rel}")
            continue
        data = fpath.read_bytes()
        actual = _sha3_256(data).hex()
        if actual != entry.get("sha3_256"):
            failures.append(f"file hash mismatch: {rel}")
        elif len(data) != entry.get("bytes"):
            failures.append(f"byte size mismatch: {rel}")

    # 2. Signature over the manifest digest, recomputed from DISK bytes.
    digest = _sha3_256(manifest_path.read_bytes())
    pub_b64 = pub_path.read_text().strip()
    reason = _verify_one_sig(pub_b64, sig_path, digest)
    if reason:
        failures.append(reason)

    sig2_path = target / SIG2_NAME
    pub2_path = target / PUB2_NAME
    want_council = args.council or sig2_path.is_file()
    if want_council:
        if not pub2_path.is_file():
            failures.append(f"council public key missing: {pub2_path}")
        else:
            pub2_b64 = pub2_path.read_text().strip()
            reason2 = _verify_one_sig(pub2_b64, sig2_path, digest)
            if reason2:
                failures.append(f"council {reason2}")

    if failures:
        print(f"FAIL verify {target}")
        for line in failures:
            print(f"  - {line}")
        return 1
    print(
        f"PASS verify {target} ({len(manifest.get('files', []))} files, "
        f"{'2' if want_council else '1'} signature(s) valid)"
    )
    return 0


def _selftest() -> int:
    """Hermetic sign→verify→tamper→restore→sig-tamper→council cycle in /tmp."""
    import secrets as pysecrets

    scratch = Path(tempfile.mkdtemp(prefix="scroll-selftest-"))
    sign_seed = pysecrets.token_bytes(32)
    council_seed = pysecrets.token_bytes(32)

    env = dict(os.environ)
    env[SIGN_SEED_ENV] = sign_seed.hex()
    env[COUNCIL_SEED_ENV] = council_seed.hex()

    try:
        print(f"selftest scratch: {scratch}")
        (scratch / "llms.txt").write_bytes(b"scroll payload v2\n")
        (scratch / "model-cards").mkdir()
        (scratch / "model-cards" / "card.md").write_bytes(b"carrier card\n")

        engine = Path(__file__).resolve()

        def run(cli_args: list[str]) -> subprocess.CompletedProcess[str]:
            return subprocess.run(
                [sys.executable, str(engine), *cli_args],
                capture_output=True,
                text=True,
                env=env,
                timeout=120,
                check=False,
            )

        # 1. sign (auto-manifest) + verify -> pass
        r = run(["sign", str(scratch)])
        assert r.returncode == 0, f"sign failed: {r.stderr}"
        r = run(["verify", str(scratch)])
        assert r.returncode == 0, f"verify failed: {r.stdout} {r.stderr}"
        print("  sign -> verify: PASS")

        # 2. tamper payload file -> verify fails naming the file
        payload = scratch / "llms.txt"
        original = payload.read_bytes()
        payload.write_bytes(b"scroll payload TAMPERED\n")
        r = run(["verify", str(scratch)])
        assert r.returncode == 1, f"tampered verify should fail, got rc={r.returncode}"
        assert "llms.txt" in r.stdout, f"failure must name the file: {r.stdout}"
        print(
            f"  tamper file -> verify FAIL naming file: PASS ({r.stdout.strip().splitlines()[0]})"
        )

        # 3. restore -> pass
        payload.write_bytes(original)
        r = run(["verify", str(scratch)])
        assert r.returncode == 0, f"restored verify failed: {r.stdout} {r.stderr}"
        print("  restore -> verify: PASS")

        # 4. tamper manifest.json -> signature mismatch
        manifest = scratch / MANIFEST_NAME
        manifest_bytes = manifest.read_bytes()
        manifest.write_bytes(manifest_bytes.replace(b"v2.0", b"v9.9"))
        r = run(["verify", str(scratch)])
        assert r.returncode == 1, "tampered manifest verify should fail"
        assert "signature mismatch" in r.stdout, f"expected sig mismatch: {r.stdout}"
        print("  tamper manifest -> signature mismatch: PASS")

        # 5. council dual-signature path
        manifest.write_bytes(manifest_bytes)
        r = run(["sign", str(scratch), "--council"])
        assert r.returncode == 0, f"council sign failed: {r.stderr}"
        assert (scratch / SIG2_NAME).is_file(), "manifest.sig2 missing"
        r = run(["verify", str(scratch), "--council"])
        assert r.returncode == 0, f"council verify failed: {r.stdout} {r.stderr}"
        r = run(["verify", str(scratch)])
        assert r.returncode == 0, "dual-sig dir must verify with 1-sig check too"
        print("  council dual-signature path: PASS")

        print(f"SELFTEST PASS ({scratch})")
        return 0
    except AssertionError as exc:
        print(f"SELFTEST FAIL: {exc}", file=sys.stderr)
        return 1
    finally:
        # Seeds lived only in the subprocess env; scratch dies with it.
        import shutil

        shutil.rmtree(scratch, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="scroll_manifest.py",
        description="ML-DSA-65 signed manifest engine for scrolls v2 payload trees.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_manifest = sub.add_parser("manifest", help="emit manifest.json for a payload dir")
    p_manifest.add_argument("dir", nargs="?", default=".")
    p_manifest.add_argument(
        "--out", default=None, help="output filename (default manifest.json)"
    )
    p_manifest.add_argument(
        "--author", default=None, help="operator handle (default $USER)"
    )
    p_manifest.set_defaults(func=cmd_manifest)

    p_sign = sub.add_parser("sign", help="sign manifest digest with ML-DSA-65")
    p_sign.add_argument("dir", nargs="?", default=".")
    p_sign.add_argument(
        "--council", action="store_true", help="also cosign with council key"
    )
    p_sign.set_defaults(func=cmd_sign)

    p_verify = sub.add_parser(
        "verify", help="verify files + signatures against manifest"
    )
    p_verify.add_argument("dir", nargs="?", default=".")
    p_verify.add_argument(
        "--council", action="store_true", help="require the council signature"
    )
    p_verify.set_defaults(func=cmd_verify)
    p_selftest = sub.add_parser(
        "selftest", help="hermetic end-to-end self test in a temp dir"
    )
    p_selftest.add_argument("dir", nargs="?", default=None, help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.command == "selftest":
        return _selftest()
    return int(args.func(args) or 0)


if __name__ == "__main__":
    sys.exit(main())
