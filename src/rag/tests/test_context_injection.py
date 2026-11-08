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
import re
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
        ids = [step["id"] for step in rag.DriverEngine().chain_steps()]
        self.assertEqual(
            ids[:4],
            [
                "local-router/fallback-models",
                "zai-glm-5.3-flash",
                "xiaomi-mimo-mimo-v2.6-pro",
                "openrouter-deepseek-v4.1-flash-1017",
            ],
            "the operator's four router steps must lead the chain",
        )
        # Direct-provider steps exist so a dead router degrades to a real provider.
        transports = [step["transport"] for step in rag.DriverEngine().chain_steps()]
        for direct in ("nous-portal", "nebius", "openrouter", "zenmux", "zai", "xiaomi-mimo"):
            self.assertIn(direct, transports)

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


class DriverChatUrlTest(unittest.TestCase):
    """Provider bases end inconsistently; a wrong join 404s every direct provider at once."""

    def test_base_ending_in_v1_is_not_doubled(self):
        self.assertEqual(
            rag._chat_url("https://openrouter.ai/api/v1"),
            "https://openrouter.ai/api/v1/chat/completions",
        )

    def test_versioned_path_base_is_respected(self):
        # Z.AI's coding plan base is already versioned and has no /v1 segment.
        self.assertEqual(
            rag._chat_url("https://api.z.ai/api/coding/paas/v4"),
            "https://api.z.ai/api/coding/paas/v4/chat/completions",
        )

    def test_bare_host_gets_v1_appended(self):
        self.assertEqual(
            rag._chat_url("http://127.0.0.1:11434"), "http://127.0.0.1:11434/v1/chat/completions"
        )

    def test_already_complete_url_is_untouched(self):
        self.assertEqual(
            rag._chat_url("https://x/v1/chat/completions"), "https://x/v1/chat/completions"
        )

    def test_no_double_v1_anywhere_in_the_chain(self):
        for name, (_var, base) in rag.DRIVER_REMOTE_BASES.items():
            with self.subTest(transport=name):
                self.assertNotIn("/v1/v1/", rag._chat_url(base))


class DriverTierCoverageTest(unittest.TestCase):
    """Every transport named in the chain must have a probe target and key resolution."""

    def test_every_chain_transport_is_addressable(self):
        for step in rag.DRIVER_CHAIN:
            transport = step["transport"]
            if transport == "local-model":
                continue
            with self.subTest(transport=transport):
                self.assertIn(transport, rag.DRIVER_REMOTE_BASES, "no base URL configured")
                if transport != "local-router":
                    self.assertIn(transport, rag.DRIVER_KEY_NAMES, "no key names configured")

    def test_every_remote_transport_has_a_model_id(self):
        for step in rag.DRIVER_CHAIN:
            if step["transport"] == "local-model":
                continue
            with self.subTest(step=step["label"]):
                self.assertTrue(step.get("id"), "chain step needs an id")

    def test_direct_steps_come_after_the_router_steps(self):
        transports = [s["transport"] for s in rag.DRIVER_CHAIN]
        last_router = max(i for i, t in enumerate(transports) if t == "local-router")
        first_direct = min((i for i, t in enumerate(transports) if t not in ("local-router", "local-model")), default=len(transports))
        self.assertLess(last_router, first_direct, "router order must be tried before direct providers")


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

    def test_truncated_response_is_an_error_not_a_short_answer(self):
        # local-router began passing reasoning tokens through on 2026-11-07, so they now consume the
        # same budget as the answer and `finish_reason: length` is far more likely. Half a sentence
        # concatenated into an injection reads as a complete thought, which is worse than a failure.
        class FakeResponse:
            status = 200

            def read(self):
                return json.dumps({
                    "model": "mimo-v2.6-pro",
                    "choices": [{"finish_reason": "length",
                                 "message": {"content": "Thorough testing is essential"}}],
                    "usage": {"completion_tokens": 16,
                              "completion_tokens_details": {"reasoning_tokens": 8}},
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
        self.assertIn("truncated", str(ctx.exception))
        self.assertIn("finish_reason=length", str(ctx.exception))

    def test_finish_reason_is_surfaced_on_success(self):
        class FakeResponse:
            status = 200

            def read(self):
                return json.dumps({
                    "model": "mimo-v2.6-pro",
                    "choices": [{"finish_reason": "stop",
                                 "message": {"content": "a complete sentence."}}],
                    "usage": {"completion_tokens": 5},
                }).encode()

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

        original = rag.urllib.request.urlopen
        rag.urllib.request.urlopen = lambda req, timeout=None: FakeResponse()
        try:
            r = self.engine._post_chat("http://127.0.0.1:11434", "m", [{"role": "user", "content": "x"}])
        finally:
            rag.urllib.request.urlopen = original
        self.assertEqual(r["finish_reason"], "stop")
        self.assertEqual(r["text"], "a complete sentence.")


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
            def chat(self, messages, max_tokens=None, tier=None, role=None):
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
        sources = [s["source"] for s in inv["sections"]]
        # Orientation is code-only (git + ledger reads) and runs regardless; the assertion that
        # matters is that no model-generated section appears.
        self.assertIn("retrieval", sources)
        self.assertNotIn("elephant", sources)
        self.assertNotIn("goldfish", sources)

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
        sources = [s["source"] for s in inv["sections"]]
        self.assertNotIn("retrieval", sources, "a skip route must not fabricate a retrieval section")
        self.assertNotIn("elephant", sources)
        self.assertNotIn("goldfish", sources)
        self.assertTrue(any("skipped by route" in note for note in inv["degrade_notes"]))
        self.assertEqual(inv["provenance"]["drivers"], {})

    def test_orientation_survives_a_skip_route(self):
        # Branch, tree state, and the last ledger entry are true whatever the route decided about
        # retrieval, so orientation is the one section a skip must not remove.
        self._stub_route("skip_retrieval")
        inv = rag.run_context_command(self.root, "hello there", budget=1200, json_out=True)
        sources = [s["source"] for s in inv["sections"]]
        self.assertIn("orientation", sources)

    def test_default_budget_is_route_derived(self):
        self._stub_route("symbol_anchored")
        inv = rag.run_context_command(self.root, "task text", json_out=True, retrieval_only=True)
        self.assertEqual(inv["budget"]["cap"], 2000)


class OrientationSectionTest(unittest.TestCase):
    """Orientation is the mechanical half of the old context-orchestration procedure, in code."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / ".agents" / "comms").mkdir(parents=True)
        (self.root / ".agents" / "tasks").mkdir(parents=True)
        today = __import__("datetime").datetime.now(
            __import__("datetime").timezone.utc).strftime("%Y-%m-%d")
        (self.root / ".agents" / "comms" / f"{today}-team.txt").write_text(
            "### [2026-01-01T00:00:00Z] feat | branch:main | wt:/x\n"
            "- objective: wire the orientation section\n- status:in-progress\n",
            encoding="utf-8",
        )
        (self.root / ".agents" / "tasks" / f"{today}-task.md").write_text(
            "# Task\n- status: in-progress\n- scope: rag.py\n- objective: test it\n",
            encoding="utf-8",
        )

    def tearDown(self):
        self.tmp.cleanup()

    def test_gathers_branch_tree_and_ledger_state(self):
        body = rag.render_orientation_section(self.root, 400)
        self.assertIn("branch:", body)
        self.assertIn("working tree:", body)
        self.assertIn("today's COMMS", body)
        self.assertIn("wire the orientation section", body)
        self.assertIn("newest task record", body)

    def test_git_state_comes_from_the_current_directory_not_the_canonical_root(self):
        # `repo_root` is the canonical checkout (for shared index/session state); the branch an agent
        # is on is the one in cwd. Reporting the canonical branch would say "main" from a worktree,
        # which is the one thing the contract forbids.
        import subprocess
        worktree = self.root / "wt"
        worktree.mkdir()
        subprocess.run(["git", "init", "-q", str(worktree)], capture_output=True)
        subprocess.run(["git", "-C", str(worktree), "checkout", "-q", "-b", "feat/probe"],
                       capture_output=True)
        saved = os.getcwd()
        os.chdir(worktree)
        try:
            body = rag.render_orientation_section(self.root, 400)
        finally:
            os.chdir(saved)
        self.assertIn("feat/probe", body)
        self.assertNotIn("warning: on a protected branch", body)

    def test_protected_branch_is_flagged(self):
        import subprocess
        repo = self.root / "mainrepo"
        repo.mkdir()
        subprocess.run(["git", "init", "-q", "-b", "main", str(repo)], capture_output=True)
        subprocess.run(["git", "-C", str(repo), "config", "user.email", "t@example.com"])
        subprocess.run(["git", "-C", str(repo), "config", "user.name", "t"])
        (repo / "f.txt").write_text("x", encoding="utf-8")
        subprocess.run(["git", "-C", str(repo), "add", "."], capture_output=True)
        subprocess.run(["git", "-C", str(repo), "commit", "-qm", "init"], capture_output=True)
        saved = os.getcwd()
        os.chdir(repo)
        try:
            body = rag.render_orientation_section(repo, 400)
        finally:
            os.chdir(saved)
        self.assertIn("branch: `main`", body)
        self.assertIn("warning: on a protected branch", body)

    def test_no_git_repo_does_not_raise(self):
        # A temp dir is not a git repo; orientation must degrade, not explode.
        body = rag.render_orientation_section(self.root, 400)
        self.assertIn("branch:", body)

    def test_respects_the_token_cap(self):
        body = rag.render_orientation_section(self.root, 20)
        self.assertLessEqual(rag.estimate_tokens(body), 20)

    def test_zero_cap_disables_the_section(self):
        self.assertEqual(rag.render_orientation_section(self.root, 0), "")


class NativeQueryStoreEncodingTest(unittest.TestCase):
    """The native engine writes UTF-8; decoding it with the platform default killed `context`.

    `subprocess.run(..., text=True)` uses cp1252 on Windows, and the native engine's log lines
    contain em-dashes (U+2014). The decode raised UnicodeDecodeError inside reader-thread cleanup,
    so the whole command died with a traceback rather than degrading to file fallback — the user saw
    a crash instead of an injection. This pins the explicit encoding so it cannot regress silently.
    """

    def test_search_decodes_utf8_explicitly(self):
        import inspect

        source = inspect.getsource(rag.NativeQueryStore.search)
        code = "\n".join(
            line for line in source.splitlines() if not line.lstrip().startswith("#")
        )
        self.assertIn('encoding="utf-8"', code)
        self.assertIn('errors="replace"', code)
        # A bare text=True would re-introduce the platform default; it may only survive as prose.
        self.assertNotIn("text=True", code)

    def test_utf8_payload_with_unmapped_byte_parses(self):
        # Reproduces the exact failure: the native engine emits a character whose UTF-8 encoding
        # ends in 0x90 (U+2010 HYPHEN), which cp1252 leaves undefined — that is byte 0x90 at
        # position 48799 in the real traceback. Any non-ASCII byte here would decode as mojibake,
        # so the trigger has to be one cp1252 genuinely rejects, or the test proves nothing.
        unmapped = "\u2010"  # U+2010 HYPHEN -> e2 80 90
        payload = (
            "  \x1b[36m[rag:embed-provider]\x1b[0m Using remote API embeddings " + unmapped +
            " local llama server skipped\n"
            '[{"path": "a.py", "content": "x", "score": 0.5, "start_line": 1, "end_line": 2}]'
        )
        raw = payload.encode("utf-8")
        # The old behaviour: platform-default decode raises, killing the whole command.
        with self.assertRaises(UnicodeDecodeError):
            raw.decode("cp1252")
        # The fixed behaviour: explicit utf-8, then the same parse the store performs.
        text = rag.strip_ansi(raw.decode("utf-8", errors="replace"))
        start = next(m.start() for m in re.finditer(r"^\[", text, re.MULTILINE))
        parsed = json.loads(text[start:])
        self.assertEqual(parsed[0]["path"], "a.py")
        self.assertIn(unmapped, text)


class RoleModelSeparationTest(unittest.TestCase):
    """Elephant and Goldfish are two API calls with two model choices, not one choice made twice.

    The pair is only worth having if the reviewer is a different model from the drafter. A reviewer
    running the drafter's own model shares its blind spots and tends to agree with it, which turns a
    second opinion into a confirmation. These pin that separation without requiring a live provider.
    """

    def setUp(self):
        self._saved = {
            k: os.environ.get(k)
            for k in (
                "AINISH_RAG_ELEPHANT_MODEL", "AINISH_RAG_GOLDFISH_MODEL",
                "AINISH_RAG_ELEPHANT_DRIVER_MODEL", "AINISH_RAG_GOLDFISH_DRIVER_MODEL",
                "AINISH_RAG_DRIVER_MODEL", "AINISH_RAG_DRIVER_OFFLINE",
                "AINISH_RAG_DISTINCT_REVIEWER",
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

    def test_goldfish_defaults_to_the_same_route_as_elephant(self):
        # The documented pair: both roles call local-router/fallback-models. Two separate calls buy a
        # fresh-context review; requiring a different model would be imposing a cost decision.
        engine = rag.DriverEngine(allow_remote=True)
        elephant = engine.chain_steps("elephant")
        goldfish = engine.chain_steps("goldfish")
        self.assertEqual(elephant[0]["id"], "local-router/fallback-models")
        self.assertEqual(goldfish[0]["id"], "local-router/fallback-models")

    def test_distinct_reviewer_moves_goldfish_to_another_transport(self):
        # Opt-in stronger version: prefers another transport, because the head is a route whose model
        # is unknown until it replies and a positional skip cannot guarantee a different one.
        os.environ["AINISH_RAG_DISTINCT_REVIEWER"] = "1"
        engine = rag.DriverEngine(allow_remote=True)
        elephant = engine.chain_steps("elephant")
        goldfish = engine.chain_steps("goldfish")
        self.assertNotEqual(elephant[0]["transport"], goldfish[0]["transport"])
        self.assertNotEqual(elephant[0]["id"], goldfish[0]["id"])

    def test_rotation_never_shortens_the_chain(self):
        # A rotated chain must still reach every model: a failing first step cannot strand the role.
        engine = rag.DriverEngine(allow_remote=True)
        base = [s["id"] for s in engine.chain_steps(None)]
        rotated = [s["id"] for s in engine.chain_steps("goldfish")]
        self.assertEqual(sorted(base), sorted(rotated))
        self.assertEqual(len(base), len(rotated))

    def test_elephant_is_not_rotated(self):
        engine = rag.DriverEngine(allow_remote=True)
        self.assertEqual(
            [s["id"] for s in engine.chain_steps("elephant")],
            [s["id"] for s in engine.chain_steps(None)],
        )

    def test_per_role_pins_win_over_the_chain_start(self):
        os.environ["AINISH_RAG_ELEPHANT_MODEL"] = "zai-glm-5.3-flash"
        os.environ["AINISH_RAG_GOLDFISH_MODEL"] = "xiaomi-mimo-mimo-v2.6-pro"
        engine = rag.DriverEngine(allow_remote=True)
        self.assertEqual(engine.chain_steps("elephant")[0]["id"], "zai-glm-5.3-flash")
        self.assertEqual(engine.chain_steps("goldfish")[0]["id"], "xiaomi-mimo-mimo-v2.6-pro")

    def test_role_pin_keeps_the_chain_transports(self):
        # Pinning a model must not discard the router: if the router serves that id, ask the router.
        os.environ["AINISH_RAG_ELEPHANT_MODEL"] = "zai-glm-5.3-flash"
        steps = rag.DriverEngine(allow_remote=True).chain_steps("elephant")
        self.assertEqual(steps[0]["transport"], rag.DRIVER_CHAIN[0]["transport"])
        self.assertGreater(len(steps), 1, "the rest of the chain must remain as fallback")

    def test_role_pin_resolver_accepts_both_naming_forms(self):
        os.environ["AINISH_RAG_ELEPHANT_DRIVER_MODEL"] = "glm-5.3-flash"
        self.assertEqual(rag.role_pinned_model("elephant"), "glm-5.3-flash")
        os.environ.pop("AINISH_RAG_ELEPHANT_DRIVER_MODEL")
        self.assertIsNone(rag.role_pinned_model("elephant"))

    def test_unknown_role_has_no_pin_and_no_rotation(self):
        self.assertIsNone(rag.role_pinned_model("not-a-role"))
        engine = rag.DriverEngine(allow_remote=True)
        self.assertEqual(
            [s["id"] for s in engine.chain_steps("not-a-role")],
            [s["id"] for s in engine.chain_steps(None)],
        )

    def test_offline_mode_keeps_one_local_step_for_both_roles(self):
        os.environ["AINISH_RAG_DRIVER_OFFLINE"] = "1"
        for role in rag.DRIVER_ROLES:
            steps = rag.DriverEngine().chain_steps(role)
            self.assertEqual([s["transport"] for s in steps], ["local-model"], role)

    def test_chat_reports_the_role_it_served(self):
        engine = rag.DriverEngine(allow_remote=True)

        def fake_post(base, model, messages, key=None, **kwargs):
            return {"text": "answer", "model": model, "usage": {}, "finish_reason": "stop"}

        engine._post_chat = fake_post
        result = engine.chat([{"role": "user", "content": "x"}], role="goldfish")
        self.assertEqual(result["role"], "goldfish")

    def test_the_two_roles_request_the_same_model_by_default(self):
        # Two calls, same model: the default. Asserting the request ids are equal proves the calls are
        # independent without pretending the models differ.
        requested = []

        def fake_post(base, model, messages, key=None, **kwargs):
            requested.append(model)
            return {"text": "answer", "model": model, "usage": {}, "finish_reason": "stop"}

        engine = rag.DriverEngine(allow_remote=True)
        engine._post_chat = fake_post
        engine.chat([{"role": "user", "content": "x"}], role="elephant")
        engine.chat([{"role": "user", "content": "x"}], role="goldfish")
        self.assertEqual(len(requested), 2, "both roles must make their own call")
        self.assertEqual(requested[0], requested[1])

    def test_distinct_reviewer_makes_the_two_roles_request_different_models(self):
        # The rotation is a chain property, so assert it on the chain rather than on live credentials.
        # An earlier version of this test drove chat() and read the *answered* model, which silently
        # asserted on ambient PQC keys: with no provider keys present, every direct step fails over to
        # the router and both roles legitimately land on the same model, so the test failed for an
        # environment reason instead of a code one. Chain selection is what the rotation owns.
        os.environ["AINISH_RAG_DISTINCT_REVIEWER"] = "1"
        engine = rag.DriverEngine(allow_remote=True)
        self.assertNotEqual(
            engine.chain_steps("elephant")[0]["id"],
            engine.chain_steps("goldfish")[0]["id"],
        )


class ContextFlagAliasTest(unittest.TestCase):
    """`ainish-rag --context` is how the contract and muscle memory reach for the command."""

    def test_leading_flag_becomes_the_subcommand(self):
        self.assertEqual(
            rag.normalize_argv(["--context", "--task", "x"]), ["context", "--task", "x"]
        )

    def test_subcommand_form_is_untouched(self):
        self.assertEqual(
            rag.normalize_argv(["context", "--task", "x"]), ["context", "--task", "x"]
        )

    def test_flag_alone_becomes_the_bare_subcommand(self):
        self.assertEqual(rag.normalize_argv(["--context"]), ["context"])

    def test_non_leading_flag_is_not_rewritten(self):
        # A `--context` where a subcommand is not expected must not be silently rewritten: it will
        # fail as an unknown option, which is the correct outcome.
        self.assertEqual(rag.normalize_argv(["query", "--context"]), ["query", "--context"])
        self.assertEqual(rag.normalize_argv(["--task", "--context"]), ["--task", "--context"])

    def test_other_leading_flags_are_preserved(self):
        self.assertEqual(
            rag.normalize_argv(["--max-mem", "2048", "--context"]), ["--max-mem", "2048", "--context"]
        )


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
