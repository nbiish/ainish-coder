#!/usr/bin/env python3
"""Tests for the Phase 0 benchmark harness: nDCG, token accounting, and baseline comparison.

The benchmark is the floor every later retrieval change is measured against, so its arithmetic is
pinned here rather than validated by eyeballing a printed table.

* `ndcg_at_k` must score a perfect ranking 1.0 and a reversed one below it, with exponential gain.
* `graded_relevance` must distinguish a labelled domain hit (2) from a passing mention (1), because
  binary recall cannot, which is how a saturated baseline hid ranking changes.
* `estimate_tokens` must never return 0 for non-empty text.
* `compare_to_baseline` must refuse to compare across embedding identities instead of reporting a
  false regression, and must fire on a real drop.

Run with:  py -m unittest discover -s src/rag/tests -p "test_*.py"
"""

import importlib.util
import unittest
from pathlib import Path

RAG_PATH = Path(__file__).resolve().parents[1] / "rag.py"
_SPEC = importlib.util.spec_from_file_location("ainish_rag", RAG_PATH)
rag = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(rag)


def hit(path, content="", score=0.9):
    return {"path": path, "content": content, "score": score}


class TestNdcg(unittest.TestCase):
    def test_perfect_ranking_scores_one(self):
        self.assertAlmostEqual(rag.ndcg_at_k([2, 1, 0], [2, 1, 0], 3), 1.0, places=6)

    def test_worse_ranking_scores_lower(self):
        perfect = rag.ndcg_at_k([2, 1, 0], [2, 1, 0], 3)
        worse = rag.ndcg_at_k([1, 0, 2], [2, 1, 0], 3)
        self.assertLess(worse, perfect)
        self.assertGreater(worse, 0.0)

    def test_empty_ideal_returns_zero(self):
        # A query with no gradeable document must not inflate the corpus average.
        self.assertEqual(rag.ndcg_at_k([0, 0, 0], [], 3), 0.0)
        self.assertEqual(rag.ndcg_at_k([], [0], 3), 0.0)

    def test_gain_is_exponential_so_top_slot_dominates(self):
        top = rag.ndcg_at_k([2, 0, 0], [2], 3)
        low = rag.ndcg_at_k([0, 0, 2], [2], 3)
        self.assertGreater(top, low)

    def test_result_is_always_within_unit_interval(self):
        # Regression: normalizing a multi-hit DCG against a single ideal hit produced nDCG 2.131.
        for grades in ([2, 2, 2], [2, 1, 0], [1, 1, 1], [2, 2, 1], [0, 0, 0], [1], []):
            value = rag.ndcg_at_k(grades, sorted(grades, reverse=True), 3)
            self.assertGreaterEqual(value, 0.0)
            self.assertLessEqual(value, 1.0, f"nDCG out of range for {grades}: {value}")


class TestGradedRelevance(unittest.TestCase):
    def test_labelled_domain_grades_two(self):
        self.assertEqual(rag.graded_relevance(".agents/wiki/03-security.md", "text", "security"), 1)
        self.assertEqual(rag.graded_relevance("src/security/gate.py", "text", "security"), 2)

    def test_mention_grades_one(self):
        self.assertEqual(rag.graded_relevance("docs/notes.md", "we discuss security here", "security"), 1)

    def test_unrelated_grades_zero(self):
        self.assertEqual(rag.graded_relevance("src/math.py", "arithmetic", "security"), 0)

    def test_empty_inputs_grade_zero(self):
        self.assertEqual(rag.graded_relevance("", "", "security"), 0)
        self.assertEqual(rag.graded_relevance("src/security/x.py", "y", ""), 0)


class TestTokenAccounting(unittest.TestCase):
    def test_nonempty_never_reports_zero(self):
        self.assertEqual(rag.estimate_tokens(""), 0)
        self.assertGreaterEqual(rag.estimate_tokens("x"), 1)

    def test_scales_with_length(self):
        self.assertGreater(rag.estimate_tokens("a" * 400), rag.estimate_tokens("a" * 40))

    def test_sums_over_hits(self):
        hits = [hit("a.py", "x" * 400), hit("b.py", "y" * 400)]
        self.assertGreater(rag.chunk_retrieval_tokens(hits), rag.chunk_retrieval_tokens(hits[:1]))


class TestBenchMetrics(unittest.TestCase):
    def test_aggregates_over_queries(self):
        results = [
            {"expected_domain": "security", "recall_at_3": True, "latency_ms": 100},
            {"expected_domain": "rag", "recall_at_3": False, "latency_ms": 200},
        ]
        hits = [[hit("src/security/gate.py", "x")], [hit("docs/other.md", "nothing")]]
        m = rag.bench_metrics(results, hits)
        self.assertAlmostEqual(m["recall_at_k"], 0.5)
        self.assertEqual(m["total_queries"], 2)
        self.assertGreaterEqual(m["ndcg_at_k"], 0.0)
        self.assertLessEqual(m["ndcg_at_k"], 1.0)

    def test_multi_hit_query_stays_in_range(self):
        results = [{"expected_domain": "security", "recall_at_3": True, "latency_ms": 10}]
        hits = [[
            hit("src/security/a.py", "x"),
            hit("src/security/b.py", "y"),
            hit("src/security/c.py", "z"),
        ]]
        m = rag.bench_metrics(results, hits)
        self.assertLessEqual(m["ndcg_at_k"], 1.0)

    def test_empty_suite_is_safe(self):
        m = rag.bench_metrics([], [])
        self.assertEqual(m["total_queries"], 0)
        self.assertEqual(m["recall_at_k"], 0.0)

    def test_payload_pins_embedding_identity(self):
        payload = rag.bench_baseline_payload(
            [{"expected_domain": "security", "recall_at_3": True, "latency_ms": 10}],
            [[hit("src/security/x.py", "y")]],
            "api:openrouter:openai/text-embedding-3-small",
            42,
            "abc1234",
        )
        self.assertEqual(payload["format"], rag.BENCH_BASELINE_FORMAT)
        self.assertEqual(payload["embedding_identity"], "api:openrouter:openai/text-embedding-3-small")
        self.assertEqual(payload["store_records"], 42)
        self.assertEqual(payload["engine"], "abc1234")
        self.assertIn("ndcg_at_3", payload)
        self.assertIn("chunk_tokens_avg", payload)


class TestBaselineComparison(unittest.TestCase):
    def test_identical_metrics_pass(self):
        base = {"recall_at_3": 1.0, "ndcg_at_3": 0.9, "embedding_identity": "local:embeddinggemma-2"}
        self.assertEqual(rag.compare_to_baseline(dict(base), base), [])

    def test_recall_drop_past_threshold_is_reported(self):
        base = {"recall_at_3": 1.0, "ndcg_at_3": 0.9, "embedding_identity": "m"}
        cur = {"recall_at_3": 0.5, "ndcg_at_3": 0.9, "embedding_identity": "m"}
        findings = rag.compare_to_baseline(cur, base)
        self.assertTrue(any("Recall@3" in f for f in findings))

    def test_small_drop_within_threshold_passes(self):
        base = {"recall_at_3": 1.0, "ndcg_at_3": 0.90, "embedding_identity": "m"}
        cur = {"recall_at_3": 0.95, "ndcg_at_3": 0.88, "embedding_identity": "m"}
        self.assertEqual(rag.compare_to_baseline(cur, base), [])

    def test_ndcg_drop_is_reported_even_when_recall_holds(self):
        # The exact case binary recall cannot see: same hits, worse ordering.
        base = {"recall_at_3": 1.0, "ndcg_at_3": 1.0, "embedding_identity": "m"}
        cur = {"recall_at_3": 1.0, "ndcg_at_3": 0.5, "embedding_identity": "m"}
        findings = rag.compare_to_baseline(cur, base)
        self.assertTrue(any("nDCG@3" in f for f in findings))

    def test_identity_change_is_incomparable_not_a_regression(self):
        base = {"recall_at_3": 1.0, "ndcg_at_3": 1.0, "embedding_identity": "local:embeddinggemma-2"}
        cur = {"recall_at_3": 0.1, "ndcg_at_3": 0.1, "embedding_identity": "api:openrouter:other"}
        findings = rag.compare_to_baseline(cur, base)
        self.assertEqual(len(findings), 1)
        self.assertTrue(findings[0].startswith("incomparable"))

    def test_legacy_baseline_without_ndcg_does_not_crash(self):
        base = {"recall_at_3": 1.0}
        self.assertEqual(rag.compare_to_baseline({"recall_at_3": 1.0}, base), [])

    def test_zero_baseline_is_not_a_division_or_regression_trap(self):
        # A legacy baseline recorded 0.0 must not make every later run "regress".
        base = {"recall_at_3": 0.0, "ndcg_at_3": 0.0, "embedding_identity": "m"}
        self.assertEqual(rag.compare_to_baseline({"recall_at_3": 1.0, "ndcg_at_3": 1.0}, base), [])


if __name__ == "__main__":
    unittest.main()
