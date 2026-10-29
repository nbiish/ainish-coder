#!/usr/bin/env python3
"""Parity tests for `ainish-rag audit privacy --redact-check`.

Runs the Python redaction dry-run against a temporary fixture and asserts that:
  * the target file's SHA-256 is unchanged (non-mutating contract), and
  * every sensitive class is detected and redacted in the preview.

Run with:  py -m unittest discover -s src/rag/tests -p "test_*.py"
"""

import hashlib
import importlib.util
import io
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

RAG_PATH = Path(__file__).resolve().parents[1] / "rag.py"
_SPEC = importlib.util.spec_from_file_location("ainish_rag", RAG_PATH)
rag = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(rag)

TOKEN = "ghp" + "_" + ("a" * 24)

SENSITIVE = (
    "user jane.doe@example.org ssn 123-45-6789 phone 555-867-5309 card 4111 1111 1111 1111\n"
    "path C:\\Users\\alice\\repo\\main.rs ip 192.168.10.25 cgnat 100.64.5.1 mac 00:1A:2B:3C:4D:5E\n"
    f"token {TOKEN}\n"
    "escaped \x1b[31mred\x1b[0m and bidi \u202eoverride\n"
)

EXPECTED_CLASSES = {
    "PII:EMAIL",
    "PII:SSN",
    "PII:PHONE",
    "PII:CARD",
    "CREDENTIAL:TOKEN",
    "INTERNAL_IP",
    "MAC",
    "ANSI_ESCAPE",
    "TROJAN_SOURCE_BIDI",
}


class RedactCheckParityTest(unittest.TestCase):
    def test_redact_check_reports_all_classes_without_mutation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / "sample.txt"
            target.write_text(SENSITIVE, encoding="utf-8")
            before = hashlib.sha256(target.read_bytes()).hexdigest()

            buffer = io.StringIO()
            with redirect_stdout(buffer):
                rag.run_audit_privacy_redact_check(root, target, json_out=True)

            after = hashlib.sha256(target.read_bytes()).hexdigest()
            self.assertEqual(before, after, "redact-check must never mutate the target file")

            report = json.loads(buffer.getvalue())
            self.assertTrue(report["file_unchanged"])
            self.assertEqual(report["changed_lines"], 4)
            self.assertEqual(set(report["redaction_classes"]), EXPECTED_CLASSES)
            self.assertEqual(report["status"], "LEAK_REPORTED")

            preview = json.dumps(report["redacted_preview"])
            for leaked in (
                "jane.doe@example.org",
                "123-45-6789",
                "867-5309",
                "4111 1111",
                TOKEN,
                "C:\\Users\\alice\\",
                "192.168.10.25",
                "100.64.5.1",
                "00:1A:2B:3C:4D:5E",
                "\u202e",
                "\x1b[31m",
            ):
                self.assertNotIn(leaked, preview, f"preview leaked {leaked!r}")
            for marker in (
                "[REDACTED:EMAIL]",
                "[REDACTED:SSN]",
                "[REDACTED:PHONE]",
                "[REDACTED:CARD]",
                "[REDACTED:TOKEN]",
                "[REDACTED:INTERNAL_IP]",
                "[REDACTED:MAC]",
            ):
                self.assertIn(marker, preview)

    def test_fail_on_leak_exits_non_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / "leaky.txt"
            target.write_text(SENSITIVE, encoding="utf-8")
            with self.assertRaises(SystemExit) as ctx:
                with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                    rag.run_audit_privacy_redact_check(root, target, json_out=True, fail_on_leak=True)
            self.assertEqual(ctx.exception.code, 1)

    def test_fail_on_leak_passes_clean_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / "clean.txt"
            target.write_text("ordinary prose with no secrets\n", encoding="utf-8")
            with redirect_stdout(io.StringIO()):
                rag.run_audit_privacy_redact_check(root, target, json_out=True, fail_on_leak=True)

    def test_recursive_directory_mode_aggregates_counts(self):
        """Parity contract for `--redact-check DIR`: the aggregate `files_scanned` /
        `files_with_leaks` / `redaction_classes` must match the fixture tree, and no file
        may be mutated. Mirrors the Rust `ainish-rag/redact-check-dir/v1` report."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "clean.md").write_text("ordinary prose\n", encoding="utf-8")
            (root / "leaky.md").write_text(SENSITIVE, encoding="utf-8")
            vendor = root / "vendor"
            vendor.mkdir()
            (vendor / "skipme.md").write_text("user bob@x.org\n", encoding="utf-8")

            digests = {p: hashlib.sha256(p.read_bytes()).hexdigest()
                       for p in (root / "clean.md", root / "leaky.md", vendor / "skipme.md")}

            buf = io.StringIO()
            with redirect_stdout(buf):
                rag.run_audit_privacy_redact_check(root, root, json_out=True)
            report = json.loads(buf.getvalue())

            self.assertEqual(report["format"], "ainish-rag/redact-check-dir/v1")
            self.assertEqual(report["files_scanned"], 3)
            self.assertEqual(report["files_with_leaks"], 2)
            self.assertTrue(report["all_files_unchanged"])
            self.assertEqual(set(report["redaction_classes"]), EXPECTED_CLASSES)
            self.assertEqual(report["status"], "LEAK_REPORTED")
            self.assertFalse(report["truncated"])

            for p, before in digests.items():
                self.assertEqual(before, hashlib.sha256(p.read_bytes()).hexdigest(),
                                 f"directory mode mutated {p.name}")

    def test_directory_mode_exclude_and_max_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "a.md").write_text("clean\n", encoding="utf-8")
            (root / "b.md").write_text(f"user jane@x.org token {TOKEN}\n", encoding="utf-8")
            vendor = root / "vendor"
            vendor.mkdir()
            (vendor / "c.md").write_text(f"token {TOKEN}\n", encoding="utf-8")

            buf = io.StringIO()
            with redirect_stdout(buf):
                rag.run_audit_privacy_redact_check(root, root, json_out=True)
            self.assertEqual(json.loads(buf.getvalue())["files_scanned"], 3)

            buf = io.StringIO()
            with redirect_stdout(buf):
                rag.run_audit_privacy_redact_check(root, root, json_out=True, excludes=["vendor"])
            excl = json.loads(buf.getvalue())
            self.assertEqual(excl["files_scanned"], 2)
            self.assertEqual(excl["exclude"], ["vendor"])

            buf = io.StringIO()
            with redirect_stdout(buf):
                rag.run_audit_privacy_redact_check(root, root, json_out=True, max_files=1)
            capped = json.loads(buf.getvalue())
            self.assertEqual(capped["files_scanned"], 1)
            self.assertTrue(capped["truncated"])
            self.assertEqual(capped["max_files"], 1)


if __name__ == "__main__":
    unittest.main()
