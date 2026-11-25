"""Unit tests for PQC agent-read-only cross-machine federation CoD engine (`src/federation_pqc.py`)."""

import importlib.util
import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FED_PATH = ROOT / "src" / "federation_pqc.py"
SPEC = importlib.util.spec_from_file_location("federation_pqc", FED_PATH)
fed = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(fed)


class FederationPQCTest(unittest.TestCase):
    def setUp(self):
        self._old_no_imm = os.environ.get("AINISH_FEDERATION_NO_IMMUTABLE")
        # Keep temp dir cleanup simple in Python tests while still testing POSIX 0444 read-only lock.
        os.environ["AINISH_FEDERATION_NO_IMMUTABLE"] = "1"
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.keys = self.root / "keys"

    def tearDown(self):
        for p in self.root.rglob("*"):
            if p.is_file() and not p.is_symlink():
                try:
                    os.chmod(p, 0o644)
                except OSError:
                    pass
        self.tmp.cleanup()
        if self._old_no_imm is None:
            os.environ.pop("AINISH_FEDERATION_NO_IMMUTABLE", None)
        else:
            os.environ["AINISH_FEDERATION_NO_IMMUTABLE"] = self._old_no_imm

    def _pair_identities(self):
        pub_a = fed.init_identity("mac-18gb", self.keys)
        pub_b = fed.init_identity("windows-128gb", self.keys)
        pub_a_path = self.keys / "mac-18gb" / "identity.pub.json"
        pub_b_path = self.keys / "windows-128gb" / "identity.pub.json"
        fed.trust_peer("mac-18gb", "windows-128gb", pub_b_path, self.keys)
        fed.trust_peer("windows-128gb", "mac-18gb", pub_a_path, self.keys)
        return pub_a, pub_b

    def test_pqc_roundtrip_union_merge_and_readonly_lock(self):
        self._pair_identities()
        src_a = self.root / "a-2026-11-25.md"
        dst_b = self.root / "b" / ".agents" / "federation" / "2026-11-25.md"
        env_path = self.root / "env.pqc.json"

        src_a.write_text(
            "# FEDERATION CoD — 2026-11-25\n\n---\n\n"
            "### [2026-11-25T13:00:00Z] mac-18gb | branch:feat/a | pr:#16 | tip:1111111 | state:pr-open\n"
            "- scope: src/a.py\n"
            "- cod: built a -> verified -> open PR\n"
            "- integrate: new-pr\n",
            encoding="utf-8",
        )
        dst_b.parent.mkdir(parents=True, exist_ok=True)
        dst_b.write_text(
            "# FEDERATION CoD — 2026-11-25\n\n---\n\n"
            "### [2026-11-25T13:05:00Z] windows-128gb | branch:feat/b | pr:none | tip:2222222 | state:wip\n"
            "- scope: src/b.py\n"
            "- cod: built b -> testing -> sync\n"
            "- integrate: standalone\n",
            encoding="utf-8",
        )

        fed.seal_envelope("mac-18gb", "windows-128gb", src_a, env_path, "2026-11-25", self.keys, repo_name="demo")
        raw_env = env_path.read_text(encoding="utf-8")
        # Plaintext CoD body must NOT appear in ciphertext envelope.
        self.assertNotIn("built a", raw_env)
        self.assertIn("ML-KEM-768", raw_env)
        self.assertIn("ML-DSA-65", raw_env)

        res = fed.open_envelope("windows-128gb", "mac-18gb", env_path, dst_b, self.keys)
        self.assertTrue(res["verified"])
        self.assertTrue(res["changed"])

        merged = dst_b.read_text(encoding="utf-8")
        self.assertIn("mac-18gb | branch:feat/a", merged)
        self.assertIn("windows-128gb | branch:feat/b", merged)
        # File must be locked read-only (no write bits).
        mode = stat.S_IMODE(dst_b.stat().st_mode)
        self.assertEqual(mode & 0o222, 0)

    def test_tampered_ciphertext_and_fingerprint_change_fail_closed(self):
        self._pair_identities()
        src_a = self.root / "a.md"
        dst_b = self.root / "b.md"
        env_path = self.root / "env.pqc.json"
        src_a.write_text(
            "### [2026-11-25T13:00:00Z] mac-18gb | branch:feat/a | pr:none | tip:1111111 | state:wip\n"
            "- cod: step1 -> step2\n",
            encoding="utf-8",
        )
        fed.seal_envelope("mac-18gb", "windows-128gb", src_a, env_path, "2026-11-25", self.keys)

        # Tamper with ciphertext -> AES-256-GCM fails closed.
        env_doc = json.loads(env_path.read_text(encoding="utf-8"))
        ct = bytearray(fed._b64d(env_doc["ciphertext_b64"]))
        ct[0] ^= 0xFF
        env_doc["ciphertext_b64"] = fed._b64e(bytes(ct))
        tampered = self.root / "tampered.pqc.json"
        tampered.write_text(json.dumps(env_doc), encoding="utf-8")
        with self.assertRaises(Exception):
            fed.open_envelope("windows-128gb", "mac-18gb", tampered, dst_b, self.keys)

        # Unexpected peer key rotation -> trust_peer fails closed.
        rogue_keys = self.root / "rogue-keys"
        fed.init_identity("mac-18gb", rogue_keys)
        rogue_pub = rogue_keys / "mac-18gb" / "identity.pub.json"
        with self.assertRaises(PermissionError):
            fed.trust_peer("windows-128gb", "mac-18gb", rogue_pub, self.keys)

    def test_secret_pii_bidi_scrubber_and_deterministic_snapshot(self):
        repo = self.root / "repo"
        repo.mkdir()
        subprocess.run(["git", "init", "-q", "-b", "feat/demo", str(repo)], check=True)
        subprocess.run(["git", "-C", str(repo), "config", "user.email", "t@example.com"], check=True)
        subprocess.run(["git", "-C", str(repo), "config", "user.name", "t"], check=True)
        (repo / "app.py").write_text("x = 1\n", encoding="utf-8")
        subprocess.run(["git", "-C", str(repo), "add", "app.py"], check=True)
        subprocess.run(
            ["git", "-C", str(repo), "commit", "-qm", "feat: test sk-live-1234567890abcdef /Users/alice/x \u202e"],
            check=True,
        )
        # Sensitive untracked file name must be redacted in scope.
        (repo / ".env.local").write_text("SECRET=abc\n", encoding="utf-8")

        res = fed.deterministic_snapshot(repo, "mac-18gb", "2026-11-25")
        dest = Path(res["dest"])
        text = dest.read_text(encoding="utf-8")
        self.assertNotIn("sk-live-1234567890abcdef", text)
        self.assertNotIn("/Users/alice", text)
        self.assertNotIn("\u202e", text)
        self.assertNotIn(".env.local", text)
        self.assertIn("[REDACTED-TOKEN]", text)
        self.assertIn("[redacted-path]", text)
        self.assertEqual(stat.S_IMODE(dest.stat().st_mode) & 0o222, 0)


if __name__ == "__main__":
    unittest.main()
