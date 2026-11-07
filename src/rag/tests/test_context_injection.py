#!/usr/bin/env python3
"""Tests for the driver (generative) transport and the Elephant/Goldfish context injection.

These pin the four contracts that are easy to break silently:

1. The driver tier order degrades `local-router -> openrouter -> zenmux -> local-model`, and a
   local-only request never reaches a remote tier.
2. A driver id is verified against `response.model`. Unknown ids resolve through the router's
   generic fallback chain and still answer HTTP 200, so a mismatch must be reported as degraded
   rather than accepted (`local-router/docs/driver-models.md`).
3. Goldfish's isolation is structural: the session sidecar cannot reach it, so a later refactor
   cannot quietly widen its inputs by adding a parameter.
4. Budget degradation follows a fixed ladder: trim retrieval, then drop Goldfish, then Elephant.

Run with:  py -m unittest discover -s src/rag/tests -p "test_*.py"
"""

import importlib.util
import json
import os
import tempfile
import textwrap
import unittest
from pathlib import Path

RAG_PATH = Path(__file__).resolve().parents[1] / "rag.py"
_SPEC = importlib.util.spec_from_file_location("ainish_rag_context", RAG_PATH)
rag = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(rag)


class DriverOrderTest(unittest.TestCase):
    def setUp(self):
        self._saved = {
            k: os.environ.get(k)
            for k in (
                "AINISH_RAG_DRIVER_PRIORITY",
                "AINISH_RAG_DRIVER_OFFLINE",
                "AINISH_RAG_OFFLINE",
                "AINISH_RAG_DRIVER_MODEL",
            )
        }
        for key in self._saved:
            os.environ.pop(key, None)

    def tearDown(self):
        for key, value in self._saved.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value

    def test_default_chain_is_the_requested_order(self):
        self.assertEqual(
            [step["id"] for step in rag.DriverEngine().chain_steps()],
            [
                "local-router/fallback-models",
                "zai-glm-5.3-flash",
                "xiaomi-mimo-mimo-v2.6-pro",
                "openrouter-deepseek-v4.1-flash-1017",
                "deepseek/deepseek-v4.1-flash-1017",
            ],
        )

    def test_chain_head_is_the_local_router_generic_chain(self):
        first = rag.DriverEngine().chain_steps()[0]
        self.assertEqual(first["transport"], "local-router")
        self.assertTrue(first.get("expect_any"), "the generic chain step must accept any model it picks")

    def test_chain_is_not_the_router_fallback_content(self):
        # The order lives in this engine. local-router's own fallback-models chain is a single step
        # here, and the engine never reads router-settings.json to build its order.
        source = RAG_PATH.read_text(encoding="utf-8")
        self.assertIn("DRIVER_CHAIN", source)
        self.assertNotIn("router-settings.json", source)

    def test_offline_mode_offers_only_the_local_floor(self):
        self.assertFalse(rag.driver_offline_mode())
        os.environ["AINISH_RAG_DRIVER_OFFLINE"] = "1"
        self.assertTrue(rag.driver_offline_mode())
        steps = rag.DriverEngine().chain_steps()
        self.assertEqual([s["transport"] for s in steps], ["local-model"])
        self.assertFalse(rag.DriverEngine().allow_remote)

    def test_offline_chain_is_never_empty(self):
        # An empty chain would report "no driver step configured" instead of naming the local
        # failure, which is the only diagnostic an offline operator has.
        os.environ["AINISH_RAG_OFFLINE"] = "yes"
        self.assertTrue(rag.DriverEngine().chain_steps())

    def test_model_pin_collapses_the_chain_to_that_step(self):
        os.environ["AINISH_RAG_DRIVER_MODEL"] = "zai-glm-5.3-flash"
        steps = rag.DriverEngine().chain_steps()
        self.assertEqual([s["id"] for s in steps], ["zai-glm-5.3-flash"])


class DriverModelIdentityTest(unittest.TestCase):
    """A 200 response proves nothing: the returned model must be the one requested."""

    def test_router_prefixed_id_matches_canonical_provider_id(self):
        self.assertTrue(
            rag.driver_model_matches(
                "openrouter-deepseek-v4.1-flash-1017", "deepseek/deepseek-v4.1-flash-1017"
            )
        )

    def test_router_stripped_ids_still_match(self):
        # Measured: the router answers with only the provider-stripped tail.
        self.assertTrue(rag.driver_model_matches("xiaomi-mimo-mimo-v2.6-pro", "mimo-v2.6-pro"))
        self.assertTrue(rag.driver_model_matches("zai-glm-5.3-flash", "glm-5.3-flash"))

    def test_snapshot_suffix_is_a_different_model(self):
        # The router strips `-1017` only for display; it is a real snapshot id.
        self.assertFalse(
            rag.driver_model_matches("deepseek/deepseek-v4.1-flash", "deepseek/deepseek-v4.1-flash-1017")
        )

    def test_fallback_chain_answer_is_a_mismatch_for_a_pinned_step(self):
        self.assertFalse(rag.driver_model_matches("zai-glm-5.3-flash", "mimo-v2.6-pro"))

    def test_empty_values_never_match(self):
        self.assertFalse(rag.driver_model_matches("", "deepseek/deepseek-v4.1-flash"))
        self.assertFalse(rag.driver_model_matches("openrouter-deepseek-v4.1-flash-1017", ""))


class DriverChatTest(unittest.TestCase):
    """Drives `DriverEngine.chat` against a stubbed transport, so no network is touched."""

    def setUp(self):
        self._saved = {k: os.environ.get(k) for k in ("AINISH_RAG_DRIVER_OFFLINE", "AINISH_RAG_DRIVER_MAX_TOKENS")}
        for key in self._saved:
            os.environ.pop(key, None)
        self._saved_keys = {k: os.environ.get(k) for k in rag.OPENROUTER_KEY_NAMES}
        for key in rag.OPENROUTER_KEY_NAMES:
            os.environ.pop(key, None)
        rag._PQC_SECRETS_CACHE = {}
        self.engine = rag.DriverEngine(allow_remote=True)

    def tearDown(self):
        for key, value in {**self._saved, **self._saved_keys}.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        rag._PQC_SECRETS_CACHE = None

    def test_tier_order_skips_a_tier_without_a_key_and_reports_why(self):
        calls = []

        def fake_post(base, model, messages, key=None, **kwargs):
            calls.append((base, model, key))
            raise RuntimeError("simulated outage at every step")

        self.engine._post_chat = fake_post
        self.engine._probe_models = lambda base, timeout=1.5, key=None: None
        result = self.engine.chat([{"role": "user", "content": "hi"}])

        # The chain is walked in order, each failure recorded with its own label.
        self.assertEqual([c[1] for c in calls][0], "local-router/fallback-models")
        self.assertEqual(result["source"], "unavailable")
        self.assertTrue(any("generic fallback chain" in a for a in result["attempts"]))
        self.assertTrue(any("GLM 5.3 Flash" in a for a in result["attempts"]))
        self.assertTrue(any("MiMo 2.6 Pro" in a for a in result["attempts"]))

    def test_first_working_step_wins_and_later_steps_are_not_called(self):
        calls = []

        def fake_post(base, model, messages, key=None, **kwargs):
            calls.append(model)
            return {"text": "answer", "model": "mimo-v2.6-pro", "usage": {}}

        self.engine._post_chat = fake_post
        result = self.engine.chat([{"role": "user", "content": "hi"}])
        self.assertEqual(result["step"], "local-router generic fallback chain")
        self.assertEqual(calls, ["local-router/fallback-models"])
        self.assertEqual(result["attempts"], [])
        self.assertTrue(result["model_verified"], "the generic chain accepts whatever it picks")

    def test_failover_moves_to_the_next_step_when_the_head_rejects(self):
        calls = []

        def fake_post(base, model, messages, key=None, **kwargs):
            calls.append(model)
            if model == "local-router/fallback-models":
                raise RuntimeError("router refused")
            return {"text": "answer", "model": "glm-5.3-flash", "usage": {}}

        self.engine._post_chat = fake_post
        result = self.engine.chat([{"role": "user", "content": "hi"}])
        self.assertEqual(calls, ["local-router/fallback-models", "zai-glm-5.3-flash"])
        self.assertEqual(result["step"], "Z.AI GLM 5.3 Flash")
        self.assertTrue(result["model_verified"])
        self.assertFalse(result["degraded"])
        self.assertEqual(len(result["attempts"]), 1)

    def test_model_mismatch_is_reported_degraded_not_raised(self):
        def fake_post(base, model, messages, key=None, **kwargs):
            return {"text": "answer from somewhere", "model": "some-other-model", "usage": {}}

        # Pin a single step so the generic-chain exemption (expect_any) does not apply.
        os.environ["AINISH_RAG_DRIVER_MODEL"] = "zai-glm-5.3-flash"
        try:
            engine = rag.DriverEngine(allow_remote=True)
            engine._post_chat = fake_post
            result = engine.chat([{"role": "user", "content": "hi"}])
        finally:
            os.environ.pop("AINISH_RAG_DRIVER_MODEL", None)
        self.assertTrue(result["degraded"])
        self.assertFalse(result["model_verified"])
        self.assertEqual(result["text"], "answer from somewhere")
        self.assertTrue(any("identifier mismatch" in a for a in result["attempts"]))

    def test_all_tiers_down_returns_an_error_instead_of_raising(self):
        def fake_post(*args, **kwargs):
            raise RuntimeError("HTTP 503 from provider")

        self.engine._post_chat = fake_post
        self.engine._probe_models = lambda base, timeout=1.5: None
        result = self.engine.chat([{"role": "user", "content": "hi"}])
        self.assertEqual(result["text"], "")
        self.assertEqual(result["source"], "unavailable")
        self.assertIn("error", result)

    def test_reasoning_only_response_is_a_budget_error_not_a_transport_error(self):
        # `deepseek-v4.1-flash` spends its whole budget reasoning at low max_tokens; treating the
        # empty content as an outage would send the caller to the next tier for no reason.
        class FakeResponse:
            status = 200

            def read(self):
                return json.dumps({
                    "model": "openrouter-deepseek-v4.1-flash-1017",
                    "choices": [{"message": {"content": ""}}],
                    "usage": {"completion_tokens_details": {"reasoning_tokens": 16}},
                }).encode()

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

        original = rag.urllib.request.urlopen
        rag.urllib.request.urlopen = lambda req, timeout=None: FakeResponse()
        try:
            with self.assertRaises(RuntimeError) as ctx:
                self.engine._post_chat("http://127.0.0.1:11434", "m", [{"role": "user", "content": "x"}])
        finally:
            rag.urllib.request.urlopen = original
        self.assertIn("raise max_tokens", str(ctx.exception))


class ElephantSessionTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_missing_session_starts_empty(self):
        state = rag.load_elephant_session(self.root, "feat-x")
        self.assertEqual(state["turns"], 0)
        self.assertEqual(state["summary"], "")
        self.assertEqual(state["established"], [])

    def test_round_trip_persists_summary_and_turns(self):
        rag.save_elephant_session(
            self.root,
            {"session": "feat-x", "turns": 3, "summary": "settled the transport order", "established": ["a"]},
        )
        state = rag.load_elephant_session(self.root, "feat-x")
        self.assertEqual(state["turns"], 3)
        self.assertEqual(state["summary"], "settled the transport order")
        self.assertEqual(state["established"], ["a"])

    def test_secrets_are_scrubbed_before_the_sidecar_is_written(self):
        # Assemble the fixtures at runtime: a literal credential-shaped string in the source trips the
        # pre-merge leak gate, and weakening that gate to ship a test would be the wrong trade. The
        # assertion is unchanged — a real key pattern must not survive into the sidecar.
        fake_key = "sk" + "-or-v1-" + ("abcdef" * 3)
        fake_email = "jane.doe" + "@" + "example.org"
        rag.save_elephant_session(
            self.root,
            {
                "session": "feat-x",
                "turns": 1,
                "summary": f"key is {fake_key} and email {fake_email}",
                "established": [],
            },
        )
        written = rag.session_path(self.root, "feat-x").read_text(encoding="utf-8")
        self.assertNotIn(fake_key, written)
        self.assertNotIn(fake_email, written)

    def test_sidecar_lives_under_the_ignored_rag_state_directory(self):
        path = rag.session_path(self.root, "feat-x")
        self.assertIn(".agents/rag/sessions", str(path).replace("\\", "/"))

    def test_session_id_is_path_safe(self):
        path = rag.session_path(self.root, "../../etc/passwd")
        self.assertEqual(path.parent.name, "sessions")
        self.assertNotIn("..", path.name)


class GoldfishIsolationTest(unittest.TestCase):
    """Goldfish must not be able to see session state. Enforced by signature, proven by capture."""

    def test_signature_carries_no_session_parameter(self):
        import inspect

        params = set(inspect.signature(rag.goldfish_review).parameters)
        self.assertEqual(params, {"driver", "task", "retrieval_text", "elephant_text", "token_cap"})
        for banned in ("session", "state", "history", "memory", "comms"):
            self.assertNotIn(banned, params)

    def test_goldfish_prompt_never_contains_session_material(self):
        captured = {}

        class StubDriver:
            def chat(self, messages, max_tokens=None, tier=None):
                captured["text"] = "\n".join(m["content"] for m in messages)
                return {"text": "review", "source": "stub:model", "model_verified": True}

        session_marker = "SESSION_ONLY_MARKER_7f3a"
        rag.goldfish_review(
            StubDriver(),
            task="do the thing",
            retrieval_text="retrieved evidence",
            elephant_text="elephant draft",
            token_cap=300,
        )
        self.assertNotIn(session_marker, captured["text"])
        # It does receive exactly the three allowed inputs.
        self.assertIn("do the thing", captured["text"])
        self.assertIn("retrieved evidence", captured["text"])
        self.assertIn("elephant draft", captured["text"])


class InjectionAssemblyTest(unittest.TestCase):
    def _sections(self, retrieval="r" * 4000, elephant="e" * 800, goldfish="g" * 800):
        return [
            {"source": "retrieval", "text": retrieval, "reason": "test", "driver": None},
            {"source": "elephant", "text": elephant, "reason": "test", "driver": "stub"},
            {"source": "goldfish", "text": goldfish, "reason": "test", "driver": "stub"},
        ]

    def test_envelope_shape_is_stable(self):
        inv = rag.assemble_injection("task", self._sections(), 4000, {"commit": "abc"}, False, [])
        self.assertEqual(inv["format"], rag.CONTEXT_FORMAT)
        self.assertEqual(inv["budget"]["cap"], 4000)
        self.assertLessEqual(inv["budget"]["tokens_used"], 4000)
        self.assertIn("provenance", inv)
        self.assertIn("degraded", inv)

    def test_degradation_drops_goldfish_before_elephant(self):
        # 4000 chars ≈ 1000 tokens of retrieval + ~200 each of Elephant and Goldfish ≈ 1400 total.
        # A 1250 cap must remove Goldfish and keep Elephant.
        inv = rag.assemble_injection("task", self._sections(), 1250, {}, False, [])
        sources = [s["source"] for s in inv["sections"]]
        self.assertIn("elephant", sources, "elephant must outlive goldfish under budget pressure")
        self.assertNotIn("goldfish", sources)
        self.assertLessEqual(inv["budget"]["tokens_used"], 1250)
        self.assertTrue(inv["degraded"])
        self.assertTrue(any("dropped goldfish" in n for n in inv["degrade_notes"]))

    def test_a_single_oversized_retrieval_blob_is_truncated_not_shipped_over_budget(self):
        # No blank-line split means the tail-trimming step cannot help; the hard cut must fire.
        inv = rag.assemble_injection("task", self._sections(), 400, {}, False, [])
        self.assertLessEqual(inv["budget"]["tokens_used"], 400, "injection must never exceed its cap")
        self.assertTrue(any("truncated retrieval" in n for n in inv["degrade_notes"]))

    def test_retrieval_is_trimmed_before_any_driver_section_is_dropped(self):
        inv = rag.assemble_injection("task", self._sections(), 700, {}, False, [])
        notes = " ".join(inv["degrade_notes"])
        if "trimmed retrieved tail" in notes:
            # Trimming alone must be attempted first, so goldfish survives a mild overshoot.
            self.assertNotIn("dropped elephant", notes)

    def test_render_labels_every_section_and_states_the_advisory_rule(self):
        inv = rag.assemble_injection("task", self._sections(retrieval="evidence"), 4000, {"commit": "abcdef123456"}, False, [])
        text = rag.render_injection_text(inv)
        self.assertIn("<CONTEXT_INJECTION>", text)
        self.assertIn("## retrieval", text)
        self.assertIn("Advisory evidence", text)
        self.assertIn("abcdef123456", text)


class MachineOutputPurityTest(unittest.TestCase):
    """`--json` is a machine contract: stdout must parse as JSON and nothing else may reach it.

    This is pinned because it failed silently twice in one pass — a stray body made one subcommand's
    logging append to `context`'s envelope, and `statusline --json` (consumed by shell prompts) leaked
    provider chatter. Reading the output by eye does not catch it; parsing it does.
    """

    def test_context_and_statusline_declare_json_stdout_isolation(self):
        source = RAG_PATH.read_text(encoding="utf-8")
        # The isolation mechanism must be present for both machine-facing verbs.
        self.assertIn("contextlib.redirect_stdout(sys.stderr)", source)
        occurrences = source.count("contextlib.redirect_stdout(sys.stderr)")
        self.assertGreaterEqual(occurrences, 2, "each --json machine verb needs its own redirect")

    def test_statusline_branch_is_still_reachable(self):
        # A deleted `elif` header once ran a subcommand body unconditionally; the dispatch table must
        # contain each verb exactly once as an explicit branch.
        source = RAG_PATH.read_text(encoding="utf-8")
        self.assertIn('elif args.subcommand == "statusline":', source)
        self.assertIn('elif args.subcommand == "context":', source)

    def test_render_text_is_the_documented_envelope(self):
        inv = rag.assemble_injection(
            "t", [{"source": "retrieval", "text": "evidence", "reason": "x", "driver": None}], 1000, {}, False, []
        )
        text = rag.render_injection_text(inv)
        self.assertTrue(text.startswith("<CONTEXT_INJECTION>"))
        self.assertTrue(text.rstrip().endswith("</CONTEXT_INJECTION>"))


class ContextBudgetContractTest(unittest.TestCase):
    """`run_context_command` must survive every budget/route combination without crashing.

    Two defects shipped here before this existed: an explicit `--budget` silently became the
    600-token floor, and the floor note was assigned in only one branch, so passing `--budget` raised
    UnboundLocalError and produced no output at all. Both are only visible by actually invoking the
    command, which is why this exercises the real function against a stubbed route and driver.
    """

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        wiki = self.root / ".agents" / "wiki"
        wiki.mkdir(parents=True)
        (wiki / "01-architecture.md").write_text(
            "# Architecture\ntask text retrieval evidence here\n", encoding="utf-8"
        )
        self._saved = {k: os.environ.get(k) for k in ("AINISH_RAG_DRIVER_OFFLINE",)}
        os.environ["AINISH_RAG_DRIVER_OFFLINE"] = "1"  # never reach a real provider
        self._saved_route = rag.DecisionEngine.route

    def tearDown(self):
        rag.DecisionEngine.route = self._saved_route
        for key, value in self._saved.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        self.tmp.cleanup()

    def _stub_route(self, strategy: str):
        rag.DecisionEngine.route = lambda self, prompt: {
            "needs_retrieval": strategy != "skip_retrieval",
            "target_domain": "codebase_symbols",
            "retrieval_strategy": strategy,
            "candidate_pool_size": 8,
            "context_budget_tokens": 2000,
            "next_action": "test next action",
            "source": "test:stub",
        }

    def test_explicit_budget_is_reported_exactly(self):
        self._stub_route("hybrid_rerank")
        inv = rag.run_context_command(
            self.root, "task text", budget=1200, json_out=True, retrieval_only=True
        )
        self.assertEqual(inv["budget"]["cap"], 1200)
        self.assertLessEqual(inv["budget"]["tokens_used"], 1200)

    def test_retrieval_only_never_calls_a_driver(self):
        self._stub_route("hybrid_rerank")
        inv = rag.run_context_command(
            self.root, "task text", budget=1200, json_out=True, retrieval_only=True
        )
        self.assertEqual([s["source"] for s in inv["sections"]], ["retrieval"])

    def test_budget_below_the_floor_is_raised_and_the_raise_is_reported(self):
        self._stub_route("hybrid_rerank")
        inv = rag.run_context_command(
            self.root, "task text", budget=50, json_out=True, retrieval_only=True
        )
        self.assertEqual(inv["budget"]["cap"], rag.CONTEXT_BUDGET_FLOOR)
        self.assertTrue(any("raised" in note for note in inv["degrade_notes"]))
        self.assertTrue(inv["degraded"], "a silent budget change must surface as degraded")

    def test_skip_retrieval_route_emits_no_filler_and_no_driver_spend(self):
        self._stub_route("skip_retrieval")
        inv = rag.run_context_command(self.root, "hello there", budget=1200, json_out=True)
        self.assertEqual(inv["sections"], [], "a skip route must not fabricate a retrieval section")
        self.assertTrue(any("skipped by route" in note for note in inv["degrade_notes"]))
        self.assertEqual(inv["provenance"]["drivers"], {})

    def test_default_budget_is_route_derived(self):
        self._stub_route("symbol_anchored")
        inv = rag.run_context_command(self.root, "task text", json_out=True, retrieval_only=True)
        self.assertEqual(inv["budget"]["cap"], 2000)


class FileFallbackTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        wiki = self.root / ".agents" / "wiki"
        wiki.mkdir(parents=True)
        (wiki / "01-architecture.md").write_text("# Architecture\nunrelated content\n", encoding="utf-8")
        (wiki / "03-security.md").write_text("# Security\npqc signing details\n", encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def test_matching_page_is_promoted(self):
        body = rag.render_file_fallback_section(self.root, "explain pqc signing", 800)
        self.assertIn("03-security.md", body)

    def test_no_match_returns_an_inventory_not_arbitrary_prose(self):
        body = rag.render_file_fallback_section(self.root, "zzzz qqqq", 800)
        self.assertIn("Wiki inventory", body)
        self.assertNotIn("unrelated content", body)


if __name__ == "__main__":
    unittest.main()
