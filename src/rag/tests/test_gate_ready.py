#!/usr/bin/env python3
"""Parity tests for the cached `gate_ready` verdict used by `orient --inject`.

Mirrors the Rust `sync_rules_if_stale` gating contract: `gate_ready` must be true only
when the cached gate verdict records `overall_pass` AND the commit it was produced for
matches the current HEAD. A stale or corrupt cache must never masquerade as fresh.

Run with:  py -m unittest discover -s src/rag/tests -p "test_*.py"
"""

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

RAG_PATH = Path(__file__).resolve().parents[1] / "rag.py"
_SPEC = importlib.util.spec_from_file_location("ainish_rag", RAG_PATH)
rag = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(rag)


class GateReadyParityTest(unittest.TestCase):
    def _cache(self, tmp: Path, payload) -> Path:
        cache = tmp / ".agents" / "rag" / "gate-status.json"
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(json.dumps(payload), encoding="utf-8")
        return cache

    def test_green_cache_matching_commit_is_ready(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = self._cache(Path(tmp), {"overall_pass": True, "commit": "abc1234"})
            status, ready = rag.read_gate_status(cache, "abc1234")
            self.assertTrue(ready)
            self.assertTrue(status["overall_pass"])

    def test_stale_commit_turns_gate_ready_false(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = self._cache(Path(tmp), {"overall_pass": True, "commit": "oldhead0"})
            status, ready = rag.read_gate_status(cache, "newhead9")
            self.assertFalse(ready, "a cache produced for a different commit must not be gate_ready")
            self.assertTrue(status["overall_pass"])

    def test_red_verdict_turns_gate_ready_false(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = self._cache(Path(tmp), {"overall_pass": False, "commit": "abc1234"})
            _, ready = rag.read_gate_status(cache, "abc1234")
            self.assertFalse(ready)

    def test_missing_cache_is_not_ready(self):
        with tempfile.TemporaryDirectory() as tmp:
            _, ready = rag.read_gate_status(Path(tmp) / "nope.json", "abc1234")
            self.assertFalse(ready)

    def test_corrupt_cache_is_not_ready(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp) / ".agents" / "rag" / "gate-status.json"
            cache.parent.mkdir(parents=True, exist_ok=True)
            cache.write_text("{not json", encoding="utf-8")
            status, ready = rag.read_gate_status(cache, "abc1234")
            self.assertFalse(ready)
            self.assertIsNone(status)

    def test_sync_rules_gated_by_gate_ready(self):
        # gate_ready=True -> the refresher must never run.
        self.assertEqual(rag.sync_rules_if_stale(Path("/nonexistent/for/sure"), True), (False, False))
        # gate_ready=False but no deployed refresher -> attempted, unsuccessful.
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(rag.sync_rules_if_stale(Path(tmp), False), (True, False))


class MasterSurfaceLensesTest(unittest.TestCase):
    """Parity with the Rust `assess_master_surfaces` checks."""

    def test_contract_surfaces_need_a_declaration(self):
        diff = "--- a/AGENTS.md\n+++ b/AGENTS.md\n+rule\n--- a/src/rag/src/main.rs\n+++ b/src/rag/src/main.rs\n+        #[arg(long)]\n"
        labels = rag.contract_surfaces_touched(diff)
        self.assertIn("contract", labels)
        self.assertIn("cli", labels)
        with tempfile.TemporaryDirectory() as tmp:
            report = rag.assess_master_surfaces(Path(tmp), diff)
            self.assertTrue(report["compatibility"]["touched"])
            self.assertFalse(report["compatibility"]["declared"])
            self.assertFalse(rag.master_surfaces_pass(report, strict=False))
            tasks = Path(tmp) / ".agents" / "tasks"
            tasks.mkdir(parents=True)
            (tasks / f"{rag._today_utc()}-task.md").write_text(
                "- compat: v1 deploy window\n- budget: 120k tokens\n", encoding="utf-8"
            )
            declared = rag.assess_master_surfaces(Path(tmp), diff)
            self.assertTrue(declared["compatibility"]["declared"])
            self.assertTrue(rag.master_surfaces_pass(declared, strict=True))

    def test_shared_state_is_append_only(self):
        append_only = "--- a/.agents/comms/2026-10-31-team.txt\n+++ b/.agents/comms/2026-10-31-team.txt\n+new\n"
        self.assertEqual(rag.shared_state_removals(append_only), [])
        rewritten = "--- a/.agents/comms/2026-10-31-team.txt\n+++ b/.agents/comms/2026-10-31-team.txt\n-old\n+new\n"
        self.assertEqual(len(rag.shared_state_removals(rewritten)), 1)
        task_rewrite = "--- a/.agents/tasks/2026-10-31-task.md\n+++ b/.agents/tasks/2026-10-31-task.md\n-old\n+new\n"
        self.assertEqual(rag.shared_state_removals(task_rewrite), [])

    def test_dependency_manifest_is_a_compatibility_surface(self):
        diff = "--- a/Cargo.toml\n+++ b/Cargo.toml\n+serde = \"1\"\n"
        self.assertIn("dependency", rag.contract_surfaces_touched(diff))
        with tempfile.TemporaryDirectory() as tmp:
            report = rag.assess_master_surfaces(Path(tmp), diff)
            self.assertTrue(report["compatibility"]["touched"])
            self.assertFalse(report["compatibility"]["declared"])

    def test_shared_rules_file_is_loaded_and_strip_ansi(self):
        with tempfile.TemporaryDirectory() as tmp:
            rules_dir = Path(tmp) / "src" / "rag"
            rules_dir.mkdir(parents=True)
            (rules_dir / "master-surfaces.json").write_text(
                json.dumps({"dependency_manifests": ["poetry.lock"]}), encoding="utf-8"
            )
            rules = rag.load_master_surface_rules(Path(tmp))
            self.assertEqual(rules["dependency_manifests"], ["poetry.lock"])
            # Unspecified keys keep their defaults.
            self.assertIn("src/rag/", rules["spend_prefixes"])
        self.assertEqual(rag.strip_ansi("\x1b[32mPASS\x1b[0m (contract)"), "PASS (contract)")

    def test_missing_budget_only_blocks_under_strict(self):
        with tempfile.TemporaryDirectory() as tmp:
            report = rag.assess_master_surfaces(Path(tmp), "--- a/src/rag/rag.py\n+++ b/src/rag/rag.py\n+x = 1\n")
            self.assertTrue(report["economics"]["touched"])
            self.assertFalse(report["economics"]["declared"])
            self.assertTrue(rag.master_surfaces_pass(report, strict=False))
            self.assertFalse(rag.master_surfaces_pass(report, strict=True))
            self.assertEqual(rag.context_budget_for("multi_hop_expand"), 3600)
            self.assertEqual(rag.context_budget_for("skip_retrieval"), 0)
            self.assertTrue(rag.next_action_for("symbol_anchored"))


if __name__ == "__main__":
    unittest.main()
