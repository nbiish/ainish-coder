#!/usr/bin/env python3
"""Tests for the TypeSafe Jev decision integration (typed questions + calibrated parsing).

The Decisions API rejects noul/choice/score questions without `criteria`, and returns typed
answers under `answers` (`noul` float, `choice` string, `score` continuous). These tests pin both
halves of that contract, plus the key names the PQC store actually carries.

Run with:  py -m unittest discover -s src/rag/tests -p "test_*.py"
"""

import importlib.util
import json
import os
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

RAG_PATH = Path(__file__).resolve().parents[1] / "rag.py"
_SPEC = importlib.util.spec_from_file_location("ainish_rag_jev", RAG_PATH)
rag = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(rag)


class JevQuestionContractTest(unittest.TestCase):
    def test_noul_carries_true_and_false_criteria(self):
        q = rag.DecisionEngine.noul_question("Does the file use LanceDB?", "it connects to LanceDB", "it does not")
        self.assertEqual(q["type"], "noul")
        self.assertEqual(q["criteria"], {"true": "it connects to LanceDB", "false": "it does not"})

    def test_choice_carries_option_criteria(self):
        q = rag.DecisionEngine.choice_question(
            "Which component?", [("store", "vector storage"), ("api", "http surface")]
        )
        self.assertEqual(q["options"], ["store", "api"])
        self.assertEqual(q["criteria"], {"store": "vector storage", "api": "http surface"})

    def test_score_carries_levels_and_per_level_criteria(self):
        q = rag.DecisionEngine.score_question("How useful?", ["unrelated", "related", "canonical"])
        self.assertEqual(q["levels"], [1, 2, 3])
        self.assertEqual(len(q["criteria"]), 3)


class JevAnswerParsingTest(unittest.TestCase):
    def test_current_typed_shape(self):
        body = {
            "model": "typesafe/jev-1.14-20261014",
            "answers": {
                "needs_retrieval": {"type": "noul", "noul": 0.91},
                "domain": {"type": "choice", "choice": "architectural_wiki", "confidence": 0.82},
                "utility": {"type": "score", "score": 3.61, "legend": {"0": "unrelated"}},
            },
        }
        answers = rag.DecisionEngine.parse_answers(body)
        self.assertAlmostEqual(answers["needs_retrieval"]["noul"], 0.91)
        self.assertEqual(answers["domain"]["choice"], "architectural_wiki")
        self.assertAlmostEqual(answers["domain"]["confidence"], 0.82)
        self.assertAlmostEqual(answers["utility"]["score"], 3.61)

    def test_legacy_shape_is_tolerated(self):
        body = {
            "decisions": {
                "needs_retrieval": {"value": True, "probability": 0.93},
                "domain": {"value": "security_governance", "probability": 0.71},
            }
        }
        answers = rag.DecisionEngine.parse_answers(body)
        self.assertEqual(rag.noul_band(answers["needs_retrieval"]["noul"]), "yes")
        self.assertEqual(answers["domain"]["choice"], "security_governance")

    def test_bands(self):
        self.assertEqual(rag.noul_band(0.95), "yes")
        self.assertEqual(rag.noul_band(0.70), "yes")
        self.assertEqual(rag.noul_band(0.50), "unsettled")
        self.assertEqual(rag.noul_band(0.30), "no")
        self.assertEqual(rag.noul_band(0.02), "no")


class JevDecisionFlowTest(unittest.TestCase):
    """Exercises routing/reranking/faithfulness against a stubbed transport (no network)."""

    def setUp(self):
        self._saved = {k: os.environ.get(k) for k in ("OPENROUTER_API_KEY", "LOCALROUTER_OPENROUTER_API_KEY", "JEV_DECISION_MODEL")}
        os.environ["OPENROUTER_API_KEY"] = "sk-or-test"
        rag._PQC_SECRETS_CACHE = {}
        self.engine = rag.DecisionEngine()

    def tearDown(self):
        for key, value in self._saved.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        rag._PQC_SECRETS_CACHE = None

    def test_route_maps_typed_answers(self):
        def fake_ask(state, questions):
            self.assertIn("needs_retrieval", questions)
            self.assertIn("criteria", questions["needs_retrieval"])
            return "typesafe/jev-1.14-20261014", rag.DecisionEngine.parse_answers({
                "answers": {
                    "needs_retrieval": {"type": "noul", "noul": 0.93},
                    "domain_target": {"type": "choice", "choice": "codebase_symbols", "confidence": 0.88},
                    "context_freshness": {"type": "noul", "noul": 0.21},
                }
            }), {}, "openrouter"

        self.engine._ask = fake_ask
        route = self.engine.route("where is the embedding provider resolved")
        self.assertTrue(route["needs_retrieval"])
        self.assertEqual(route["target_domain"], "codebase_symbols")
        self.assertAlmostEqual(route["context_freshness"], 0.21)
        self.assertTrue(route["source"].startswith("openrouter:typesafe/jev-1.14"))

    def test_rerank_uses_direct_symbols_utility_and_role(self):
        def fake_ask(state, questions):
            self.assertIn("answers_directly_0", questions)
            self.assertIn("chunk_role_0", questions)
            return "typesafe/jev-1.14-20261014", rag.DecisionEngine.parse_answers({
                "answers": {
                    "answers_directly_0": {"type": "noul", "noul": 0.95},
                    "names_query_symbols_0": {"type": "noul", "noul": 0.90},
                    "utility_0": {"type": "score", "score": 4.0},
                    "chunk_role_0": {"type": "choice", "choice": "implementation"},
                    "answers_directly_1": {"type": "noul", "noul": 0.10},
                    "names_query_symbols_1": {"type": "noul", "noul": 0.10},
                    "utility_1": {"type": "score", "score": 1.0},
                    "chunk_role_1": {"type": "choice", "choice": "generated"},
                }
            }), {}, "openrouter"

        self.engine._ask = fake_ask
        candidates = [
            {"path": "src/provider.rs", "title": "provider", "content": "fn resolve()", "score": 0.4},
            {"path": "vendor/lib.rs", "title": "vendored", "content": "generated", "score": 0.4},
        ]
        reranked = self.engine.rerank("where is resolve", candidates, min_relevance=0.2)
        self.assertEqual(len(reranked), 1)
        self.assertEqual(reranked[0]["path"], "src/provider.rs")
        self.assertEqual(reranked[0]["decision_role"], "implementation")
        self.assertTrue(reranked[0]["decision_relevance"])

    def test_faithfulness_combines_noul_and_score(self):
        def fake_ask(state, questions):
            return "typesafe/jev-1.14-20261014", rag.DecisionEngine.parse_answers({
                "answers": {
                    "is_faithful": {"type": "noul", "noul": 0.8},
                    "faithfulness_score": {"type": "score", "score": 4.0},
                }
            }), {}, "openrouter"

        self.engine._ask = fake_ask
        eval_result = self.engine.evaluate_faithfulness("ctx", "out")
        self.assertTrue(eval_result["is_faithful"])
        self.assertAlmostEqual(eval_result["faithfulness_score"], 0.88)


class OpenRouterKeyNamesTest(unittest.TestCase):
    def setUp(self):
        self._saved = {k: os.environ.get(k) for k in rag.OPENROUTER_KEY_NAMES}
        for key in rag.OPENROUTER_KEY_NAMES:
            os.environ.pop(key, None)
        rag._PQC_SECRETS_CACHE = {}

    def tearDown(self):
        for key, value in self._saved.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        rag._PQC_SECRETS_CACHE = None

    def test_consumer_prefixed_env_name_is_accepted(self):
        os.environ["LOCALROUTER_OPENROUTER_API_KEY"] = "sk-or-prefixed"
        self.assertEqual(rag.resolve_api_key(), "sk-or-prefixed")

    def test_pqc_store_consumer_prefixed_name_is_accepted(self):
        rag._PQC_SECRETS_CACHE = {"LOCALROUTER_OPENROUTER_API_KEY": "sk-or-vault"}
        self.assertEqual(rag.resolve_api_key(), "sk-or-vault")


class JevModelPolicyTest(unittest.TestCase):
    def setUp(self):
        self._saved = os.environ.get("JEV_DECISION_MODEL")
        os.environ.pop("JEV_DECISION_MODEL", None)

    def tearDown(self):
        if self._saved is None:
            os.environ.pop("JEV_DECISION_MODEL", None)
        else:
            os.environ["JEV_DECISION_MODEL"] = self._saved

    def test_default_is_latest(self):
        self.assertEqual(rag.resolve_jev_model(), rag.LATEST_JEV_MODEL)
        self.assertFalse(rag.is_model_pinned())

    def test_latest_aliases(self):
        for alias in ("latest", "typesafe/jev-latest"):
            os.environ["JEV_DECISION_MODEL"] = alias
            self.assertEqual(rag.resolve_jev_model(), rag.LATEST_JEV_MODEL)
            self.assertFalse(rag.is_model_pinned())

    def test_explicit_older_pin_is_reported(self):
        os.environ["JEV_DECISION_MODEL"] = "typesafe/jev-1.13"
        self.assertEqual(rag.resolve_jev_model(), "typesafe/jev-1.13")
        self.assertTrue(rag.is_model_pinned())


class LocalRouterDiscoveryTest(unittest.TestCase):
    """The local-router is an additional transport only when it speaks the decisions protocol."""

    class _RouterHandler(BaseHTTPRequestHandler):
        decisions = True

        def do_GET(self):  # noqa: N802
            if self.path == "/v1/models":
                self._send({"data": [{"id": "openrouter-jev-router"}, {"id": "zenmux-deepseek-v4.1-flash"}]})
            else:
                self._send({"error": "not found"}, status=404)

        def do_POST(self):  # noqa: N802
            if self.decisions and self.path == "/api/alpha/decisions":
                length = int(self.headers.get("Content-Length", 0))
                self.rfile.read(length)
                self._send({"model": "typesafe/jev-1.14-20261014", "answers": {"q": {"type": "noul", "noul": 0.9}}})
            else:
                self._send({"error": "not found"}, status=404)

        def _send(self, payload, status=200):
            body = json.dumps(payload).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    def setUp(self):
        self._saved = {k: os.environ.get(k) for k in ("JEV_LOCAL_ROUTER_URL", *rag.OPENROUTER_KEY_NAMES)}
        for key in rag.OPENROUTER_KEY_NAMES:
            os.environ.pop(key, None)
        rag._PQC_SECRETS_CACHE = {}
        self.server = HTTPServer(("127.0.0.1", 0), self._RouterHandler)
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        os.environ["JEV_LOCAL_ROUTER_URL"] = f"http://127.0.0.1:{self.port}"

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        for key, value in self._saved.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        rag._PQC_SECRETS_CACHE = None

    def test_decisions_capable_router_is_a_fallback_transport(self):
        engine = rag.DecisionEngine()
        model, answers, _usage, transport = engine._ask(
            "state", {"q": rag.DecisionEngine.noul_question("q", "yes", "no")}
        )
        self.assertEqual(model, "typesafe/jev-1.14-20261014")
        self.assertAlmostEqual(answers["q"]["noul"], 0.9)
        self.assertTrue(transport.startswith("local-router:"))
        self.assertTrue(transport.endswith("/api/alpha/decisions"))

    def test_chat_only_router_is_reported_not_used(self):
        self._RouterHandler.decisions = False
        try:
            engine = rag.DecisionEngine()
            with self.assertRaises(RuntimeError) as ctx:
                engine._ask("state", {"q": rag.DecisionEngine.noul_question("q", "yes", "no")})
            self.assertIn("no decisions route", str(ctx.exception))
        finally:
            self._RouterHandler.decisions = True

    def test_inspect_jev_reports_local_router(self):
        status = rag.inspect_jev()
        self.assertEqual(status["model"], rag.LATEST_JEV_MODEL)
        self.assertIsNotNone(status["local_router"])
        self.assertIn("openrouter-jev-router", status["local_router"]["jev_models"])


if __name__ == "__main__":
    unittest.main()
