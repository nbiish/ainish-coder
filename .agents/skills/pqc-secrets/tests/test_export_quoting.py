#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "cryptography>=45.0",
#     "kyber-py>=0.2.0",
# ]
# ///
"""
Roundtrip + parity tests for the Python pqc-secrets engine's export
shell-quoting and pack input validation (2026-08-30 quoting hardening).

Fully sandboxed: every Python-engine run uses a throwaway PQC_CONFIG_DIR
temp dir with the encrypted-file store (PQC_USE_KEYCHAIN=false), so the
live bundle at ~/.config/pqc-secrets and the live keychain account are
never touched. The optional Rust byte-agreement test runs the staged
darwin/arm64 binary with explicit temp-dir paths and the sandbox keychain
account pqc-secrets-vtest-phase0 (passed only via subprocess env, never
exported into any shell).

Run:  uv run --script .agents/skills/pqc-secrets/tests/test_export_quoting.py
"""

import atexit
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent
SKILL_DIR = TESTS_DIR.parent
ENGINE_PATH = SKILL_DIR / "scripts" / "pqc_secrets.py"
# tests/ -> pqc-secrets -> skills -> .agents -> REPO ROOT
REPO_ROOT = TESTS_DIR.parents[3]
RUST_BIN = REPO_ROOT / "bin" / "pqc-secrets.darwin-arm64"

SANDBOX_KEYCHAIN_ACCOUNT = "pqc-secrets-vtest-phase0"

# Synthetic values only — no real secret material anywhere in this file.
ROUNDTRIP_VALUES = {
    "VTEST_SINGLE_QUOTE": "it's a 'test' value",
    "VTEST_LEADING_QUOTE": "'unclosed",
    "VTEST_TRAILING_QUOTE": "closed'",
    "VTEST_MID_QUOTE": "mid'dle'ish",
    "VTEST_DOUBLE_QUOTE": 'say "hi" now',
    "VTEST_SPACES": "two  spaces\tand tab",
    "VTEST_DOLLAR": "$HOME ${EXPANDS} $(nope)",
    "VTEST_BACKTICK": "`back`tick`",
    "VTEST_SEMICOLON": "semi;colon && rm -rf /nonexistent",
    "VTEST_EMPTY": "",
    "VTEST_PLAIN": "plain-dummy-value-123",
}

# Values whose stdin line survives pack's line protocol (no newlines).
STDIN_LINES = "\n".join(f"{k}={v}" for k, v in ROUNDTRIP_VALUES.items())

# Module-level sandbox — applied into os.environ AT IMPORT TIME, before any
# engine import in this process. The engine reads PQC_CONFIG_DIR at module
# import; an in-process import before the sandbox is exported once resolved
# the engine to the LIVE config dir and overwrote the live bundle (incident
# 2026-08-30 ~14:38 UTC). The multiline-pack helper below additionally
# re-isolates in a subprocess so no test ever needs an in-process engine call.
_TMP_DIR = tempfile.mkdtemp(prefix="pqc-vtest-phase0-")
SANDBOX_ENV = {
    "PQC_CONFIG_DIR": _TMP_DIR,
    "PQC_USE_KEYCHAIN": "false",
    "PQC_KEYCHAIN_ACCOUNT": SANDBOX_KEYCHAIN_ACCOUNT,
}
for _name, _val in SANDBOX_ENV.items():
    os.environ[_name] = _val
atexit.register(shutil.rmtree, _TMP_DIR, ignore_errors=True)


def _sandbox_guard() -> None:
    """Hard stop: never invoke the engine unless the sandbox is provably active."""
    if os.environ.get("PQC_CONFIG_DIR") != _TMP_DIR:
        raise AssertionError(
            "sandbox env not active — refusing to invoke the engine "
            "(would risk resolving the LIVE ~/.config/pqc-secrets)"
        )


def _engine_env() -> dict[str, str]:
    env = dict(os.environ)
    env.update(SANDBOX_ENV)
    return env


def _run_engine(*args: str, stdin: str | None = None) -> subprocess.CompletedProcess[str]:
    _sandbox_guard()
    return subprocess.run(
        [sys.executable, str(ENGINE_PATH), *args],
        input=stdin,
        capture_output=True,
        text=True,
        env=_engine_env(),
        timeout=120,
    )


def _run_rust(*args: str, stdin: str | None = None) -> subprocess.CompletedProcess[str]:
    env = dict(os.environ)
    # Explicit paths + sandbox keychain account via subprocess env ONLY.
    env["PQC_KEYCHAIN_ACCOUNT"] = SANDBOX_KEYCHAIN_ACCOUNT
    return subprocess.run(
        [str(RUST_BIN), *args],
        input=stdin,
        capture_output=True,
        text=True,
        env=env,
        timeout=120,
    )


def _eval_export_in_bash(export_stdout: str, keys: list[str]) -> list[str]:
    """eval the export output in a real bash and read the values back.

    Values are joined with the ASCII record separator (0x36 octal) so
    embedded newlines, spaces and quotes survive the roundtrip verbatim.
    """
    bash_script = (
        'eval "$PQC_EXPORT_OUTPUT"\n'
        'for k in "$@"; do printf \'%s\\036\' "${!k}"; done\n'
    )
    result = subprocess.run(
        ["/bin/bash", "-c", bash_script, "bash", *keys],
        capture_output=True,
        text=True,
        env={**os.environ, "PQC_EXPORT_OUTPUT": export_stdout},
        timeout=60,
    )
    if result.returncode != 0:
        raise AssertionError(f"bash eval failed: {result.stderr}")
    return result.stdout.split("\x1e")[:-1]


def _delete_sandbox_keychain_entry() -> None:
    """Best-effort removal of our own sandbox keychain entry (no live touch)."""
    if sys.platform != "darwin":
        return
    subprocess.run(
        ["security", "delete-generic-password", "-s", "pqc-secrets", "-a", SANDBOX_KEYCHAIN_ACCOUNT],
        capture_output=True,
        check=False,
        timeout=30,
    )


class ShellQuoteParity(unittest.TestCase):
    """_shell_quote must byte-match the Rust engine's shell_quote()."""

    def setUp(self):
        _sandbox_guard()
        sys.path.insert(0, str(ENGINE_PATH.parent))
        import pqc_secrets  # noqa: PLC0415 — import after env is sandboxed

        self.shell_quote = pqc_secrets._shell_quote

    def test_matches_rust_engine_behavior(self):
        # Rust: format!("'{}'", value.replace('\'', "'\\''"))
        cases = {
            "": "''",
            "plain": "'plain'",
            "it's": "'it'\\''s'",
            "a b": "'a b'",
            "$X `c`": "'$X `c`'",
            "l1\nl2": "'l1\nl2'",
            "'": "''\\'''",
        }
        for value, expected in cases.items():
            self.assertEqual(self.shell_quote(value), expected, msg=f"value={value!r}")


class PackExportRoundtrip(unittest.TestCase):
    """End-to-end: pack via stdin, export, eval in bash, compare verbatim."""

    @classmethod
    def setUpClass(cls):
        result = _run_engine("keygen", "--force")
        assert result.returncode == 0, f"sandbox keygen failed: {result.stderr}"

    def test_stdin_roundtrip_eval_safe(self):
        packed = _run_engine("pack", stdin=STDIN_LINES + "\n")
        self.assertEqual(packed.returncode, 0, packed.stderr)
        exported = _run_engine("export")
        self.assertEqual(exported.returncode, 0, exported.stderr)
        got = _eval_export_in_bash(exported.stdout, sorted(ROUNDTRIP_VALUES))
        for key, expected in ROUNDTRIP_VALUES.items():
            self.assertEqual(
                got[sorted(ROUNDTRIP_VALUES).index(key)],
                expected,
                msg=f"{key}: eval-observed value differs",
            )

    def test_newline_value_roundtrip(self):
        """Bundle-held newline values must survive export + eval verbatim."""
        multiline = "line1\nline2 with 'quotes'\nline3 $dollar"
        # stdin's line protocol cannot carry newlines, so pack one entry via a
        # helper subprocess that imports the engine WITH the sandboxed env.
        # Never import the engine in-process unsandboxed: module-level
        # CONFIG_DIR would resolve to the live config dir.
        probe = subprocess.run(
            [
                sys.executable,
                "-c",
                "import sys; sys.path.insert(0, sys.argv[1]); "
                "import pqc_secrets; "
                "pqc_secrets._encrypt_entries_to_bundle({sys.argv[2]: sys.stdin.read()})",
                str(ENGINE_PATH.parent),
                "VTEST_MULTILINE",
            ],
            input=multiline,
            capture_output=True,
            text=True,
            env=_engine_env(),
            timeout=120,
        )
        self.assertEqual(probe.returncode, 0, probe.stderr)
        exported = _run_engine("export")
        self.assertEqual(exported.returncode, 0, exported.stderr)
        (observed,) = _eval_export_in_bash(exported.stdout, ["VTEST_MULTILINE"])
        self.assertEqual(observed, multiline)

    def test_every_export_line_is_single_quoted(self):
        packed = _run_engine("pack", stdin="VTEST_A=dummy\n")
        self.assertEqual(packed.returncode, 0, packed.stderr)
        exported = _run_engine("export")
        for line in exported.stdout.splitlines():
            key, _, value = line.partition("=")
            self.assertTrue(key.startswith("export VTEST_"), msg=line)
            self.assertTrue(value.startswith("'") and value.endswith("'"), msg=line)


class PackValidation(unittest.TestCase):
    """pack must refuse shell-quoted input and warn on expansion chars."""

    def test_rejects_wrapping_single_quotes(self):
        bundle = Path(os.environ["PQC_CONFIG_DIR"]) / "secrets.bundle.json"
        before = bundle.read_bytes() if bundle.exists() else None
        packed = _run_engine("pack", stdin="VTEST_BAD='wrapped-value'\n")
        self.assertNotEqual(packed.returncode, 0)
        self.assertIn("VTEST_BAD", packed.stderr)
        self.assertIn("quotes", packed.stderr.lower())
        after = bundle.read_bytes() if bundle.exists() else None
        self.assertEqual(before, after, "bundle must not be rewritten when input is refused")

    def test_rejects_multiple_shell_quoted_values(self):
        packed = _run_engine(
            "pack",
            stdin="VTEST_B1='one'\nVTEST_B2='two'\nVTEST_OK=plain\n",
        )
        self.assertNotEqual(packed.returncode, 0)
        self.assertIn("VTEST_B1", packed.stderr)
        self.assertIn("VTEST_B2", packed.stderr)

    def test_warns_nonfatally_on_expansion_chars(self):
        packed = _run_engine("pack", stdin="VTEST_DOLLAR=$HOME\nVTEST_BT=`id`\n")
        self.assertEqual(packed.returncode, 0, packed.stderr)
        self.assertIn("WARNING", packed.stderr)
        self.assertIn("VTEST_DOLLAR", packed.stderr)
        self.assertIn("VTEST_BT", packed.stderr)
        # Stored literally; export must remain eval-safe and unexpanded.
        exported = _run_engine("export")
        got = _eval_export_in_bash(exported.stdout, ["VTEST_DOLLAR", "VTEST_BT"])
        self.assertEqual(got, ["$HOME", "`id`"])


@unittest.skipUnless(
    sys.platform == "darwin" and platform.machine() == "arm64" and RUST_BIN.is_file(),
    "darwin/arm64 + staged Rust binary required",
)
class RustPythonByteAgreement(unittest.TestCase):
    """Both engines must emit byte-identical export output for the same entries."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix="pqc-vtest-rust-parity-"))
        atexit.register(shutil.rmtree, cls.tmp, ignore_errors=True)
        atexit.register(_delete_sandbox_keychain_entry)

        # Rust side: explicit temp paths; keychain only under sandbox account.
        keygen = _run_rust("keygen", str(cls.tmp / "rust-recipient.pub"))
        assert keygen.returncode == 0, f"rust keygen failed: {keygen.stderr}"
        pack = _run_rust(
            "pack",
            str(cls.tmp / "rust-recipient.pub"),
            str(cls.tmp / "rust-bundle.json"),
            stdin=STDIN_LINES + "\n",
        )
        assert pack.returncode == 0, f"rust pack failed: {pack.stderr}"
        cls.rust_export = _run_rust("export", str(cls.tmp / "rust-bundle.json"))
        assert cls.rust_export.returncode == 0, f"rust export failed: {cls.rust_export.stderr}"

        # Python side: same entries, sandbox file store.
        keygen = _run_engine("keygen", "--force")
        assert keygen.returncode == 0, f"py keygen failed: {keygen.stderr}"
        pack = _run_engine("pack", stdin=STDIN_LINES + "\n")
        assert pack.returncode == 0, f"py pack failed: {pack.stderr}"
        cls.py_export = _run_engine("export")
        assert cls.py_export.returncode == 0, f"py export failed: {cls.py_export.stderr}"

    def test_export_output_bytes_identical(self):
        self.assertEqual(
            self.rust_export.stdout,
            self.py_export.stdout,
            "engines disagree on export serialization",
        )

    def test_eval_of_both_yields_identical_env(self):
        keys = sorted(ROUNDTRIP_VALUES)
        self.assertEqual(
            _eval_export_in_bash(self.rust_export.stdout, keys),
            _eval_export_in_bash(self.py_export.stdout, keys),
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
