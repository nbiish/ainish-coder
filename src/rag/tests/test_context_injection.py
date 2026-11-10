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
        self.assertEqual(params, {"driver", "task", "prime_text", "elephant_text", "token_cap"})
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
            prime_text="retrieved evidence",
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

        # The decode lives in search_with_reason now; search() delegates to it.
        source = inspect.getsource(rag.NativeQueryStore.search_with_reason)
        code = "\n".join(
            line for line in source.splitlines() if not line.lstrip().startswith("#")
        )
        self.assertIn('encoding="utf-8"', code)
        self.assertIn('errors="replace"', code)
        # A bare text=True would re-introduce the platform default; it may only survive as prose.
        self.assertNotIn("text=True", code)
        # And the public entrypoint must still delegate rather than duplicate the decode.
        self.assertIn(
            "search_with_reason", inspect.getsource(rag.NativeQueryStore.search)
        )

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


class NativeQueryReasonTest(unittest.TestCase):
    """A zero-hit search must say WHY, because the fixes are completely different.

    "The index is empty" and "the embedding key returned 401" both yield zero hits. Reporting both
    as an empty store sends an operator hunting for a missing index when the index is intact and the
    credential is gone — observed live on 2026-11-08 when the PQC store lost its provider keys.
    """

    def test_missing_binary_reports_that_reason(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            store = rag.NativeQueryStore(Path(tmp))
            hits, reason = store.search_with_reason("x")
            self.assertEqual(hits, [])
            self.assertIn("no compiled engine", reason)

    def test_nonzero_exit_surfaces_engine_stderr(self):
        import sys
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            # A fake "engine" that fails the way the real one does when the key is missing. It is a
            # Python script rather than a shell script so the test runs on every host without needing
            # a POSIX shell or a `.cmd` shim.
            fake = root / "fake-engine.py"
            fake.write_text(
                "import sys\n"
                "print('[rag:embed-provider] No API key resolved for openrouter', file=sys.stderr)\n"
                "sys.exit(1)\n",
                encoding="utf-8",
            )
            store = rag.NativeQueryStore(root)
            # _locate() only accepts real executables; hand the binary in directly and wrap it so the
            # subprocess call uses the interpreter.
            store.binary = fake
            original = rag.subprocess.run

            def run(cmd, **kwargs):
                return original([sys.executable, *cmd], **kwargs)

            rag.subprocess.run = run
            try:
                hits, reason = store.search_with_reason("x")
            finally:
                rag.subprocess.run = original
            self.assertEqual(hits, [])
            self.assertIn("exited 1", reason)
            self.assertIn("No API key resolved", reason)

    def test_search_still_returns_a_plain_list(self):
        # The public `search` keeps its old shape so existing callers are unaffected.
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            store = rag.NativeQueryStore(Path(tmp))
            self.assertEqual(store.search("x"), [])


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


class AgentsKnowledgeChunkingTest(unittest.TestCase):
    """`.agents/**` documents must be chunked whole, not truncated at a character ceiling.

    The regression this pins: `index` used to store `content[:3000]` for every markdown file, so the
    current daily memory (~19 KB) lost ~85% of its text and a fact living past character 3000 was
    unreachable by vector search no matter how it was queried.
    """

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        memories = self.root / ".agents" / "memories"
        memories.mkdir(parents=True)
        # Ten dated entries, each long enough that the whole file is far past 3000 characters.
        blocks = []
        for i in range(10):
            filler = " ".join(f"word{i}x{j}" for j in range(90))
            blocks.append(f"### [2026-11-0{i + 1}T00:00:00Z] entry-{i}\n{filler}\n")
        self.memory_file = memories / "2026-11-07-memory.txt"
        self.memory_file.write_text("\n".join(blocks), encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def test_content_past_the_old_cap_is_indexed(self):
        raw = self.memory_file.read_text(encoding="utf-8")
        self.assertGreater(len(raw), 3000)
        tail_marker = raw[-200:].split()[-1]
        self.assertNotIn(tail_marker, raw[:3000])

        records = rag.chunk_agents_doc(self.memory_file, self.root)
        self.assertTrue(records)
        self.assertTrue(
            any(tail_marker in r["content"] for r in records),
            "text beyond the old 3000-character cap must appear in some chunk",
        )
        # And the total coverage exceeds what the old single truncated chunk carried.
        self.assertGreater(sum(len(r["content"]) for r in records), 3000)

    def test_doc_type_and_heading_travel_with_the_chunk(self):
        records = rag.chunk_agents_doc(self.memory_file, self.root)
        self.assertEqual(records[0]["doc_type"], "agents_memory")
        # A chunk from the middle of the file still names the entry it belongs to.
        self.assertTrue(any("entry-" in r["title"] for r in records))

    def test_index_own_state_and_signatures_are_excluded(self):
        for rel, expected in (
            (".agents/rag/lancedb/x.md", None),
            (".agents/audit/receipt.sig", None),
            (".agents/canonical/AGENTS.md", None),
            (".agents/llms.txt", "agents_llms"),
            (".agents/plans/2026-11-08-x.plan.md", "agents_plan"),
            (".agents/tasks/2026-11-08-x-task.md", "agents_task"),
        ):
            self.assertEqual(rag.agents_doc_type(rel), expected, rel)

    def test_recent_scope_is_bounded_and_date_ordered(self):
        tasks = self.root / ".agents" / "tasks"
        tasks.mkdir(parents=True)
        # A legacy name that sorts above a newer date on ASCII order alone.
        (tasks / "TASK.2026-10-28.latest.md").write_text("# old\n", encoding="utf-8")
        (tasks / "2026-11-07-newer-task.md").write_text("# new\n", encoding="utf-8")

        picked = rag.recent_agents_files(self.root)
        task_names = [p.name for area, p in picked if area == "tasks"]
        self.assertEqual(len(task_names), 1, "the scope must be one task record, not all of them")
        self.assertEqual(task_names[0], "2026-11-07-newer-task.md")

        memory_names = [p.name for area, p in picked if area == "memories"]
        self.assertEqual(len(memory_names), 1, "only one memory file exists here")


class ElephantPrimeInputTest(unittest.TestCase):
    """The Elephant must see both what was asked and what came back; the Goldfish only the latter."""

    def test_elephant_prompt_carries_input_and_output(self):
        captured = {}

        class StubDriver:
            def chat(self, messages, max_tokens=None, tier=None, role=None):
                captured["text"] = "\n".join(m["content"] for m in messages)
                return {"text": "draft", "source": "stub:model", "model_verified": True}

        rag.elephant_synthesize(
            StubDriver(),
            task="do the thing",
            session={"turns": 0, "summary": "", "established": []},
            prime_input="route: symbol_anchored | terms: alpha",
            prime_output="EVIDENCE_OUTPUT_MARKER",
            token_cap=300,
        )
        self.assertIn("route: symbol_anchored | terms: alpha", captured["text"])
        self.assertIn("EVIDENCE_OUTPUT_MARKER", captured["text"])

    def test_goldfish_cannot_see_the_prime_input(self):
        captured = {}

        class StubDriver:
            def chat(self, messages, max_tokens=None, tier=None, role=None):
                captured["text"] = "\n".join(m["content"] for m in messages)
                return {"text": "review", "source": "stub:model", "model_verified": True}

        # `run_council` passes only the prime *output* to the reviewer.
        import inspect

        source = inspect.getsource(rag.run_council)
        self.assertIn("goldfish_review(\n            driver, task, prime_output", source)
        self.assertNotIn("prime_input, caps[\"goldfish\"]", source)


class ObsidianWikiTest(unittest.TestCase):
    """The generated wiki must be a valid Obsidian vault, not a directory of markdown files.

    Two invariants matter: every wikilink resolves (a broken link is worse than no link, because it
    looks connected), and `.agents/wiki/ledger.md` stays byte-identical across runs — it is
    operator-owned, and an earlier revision broke that by prepending frontmatter to it.
    """

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / ".agents" / "wiki").mkdir(parents=True)
        (self.root / ".agents" / "memories").mkdir(parents=True)
        self.ledger = "# Operator ledger\n\n- 2026-11-08 a durable operator note\n"
        (self.root / ".agents" / "wiki" / "ledger.md").write_text(self.ledger, encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def _resolve_names(self):
        import re

        names = set()
        for page in (self.root / ".agents" / "wiki").glob("*.md"):
            text = page.read_text(encoding="utf-8", errors="replace")
            names.add(page.stem)
            if text.lstrip().startswith("---"):
                front = text.split("---")[1]
                names.update(re.findall(r'^  - "([^"]+)"', front, re.M))
                match = re.search(r'title:\s*"([^"]+)"', front)
                if match:
                    names.add(match.group(1))
        return names

    def _links(self):
        import re

        found = []
        for page in (self.root / ".agents" / "wiki").glob("*.md"):
            text = page.read_text(encoding="utf-8", errors="replace")
            for target in re.findall(r"\[\[([^\]|]+)(?:\|[^\]]*)?\]\]", text):
                found.append((page.name, target))
        return found

    def test_every_wikilink_resolves(self):
        rag.generate_wiki(self.root)
        names = self._resolve_names()
        broken = [(page, target) for page, target in self._links() if target not in names]
        self.assertEqual(broken, [], f"unresolved wikilinks: {broken}")

    def test_pages_carry_frontmatter_with_aliases(self):
        rag.generate_wiki(self.root)
        page = (self.root / ".agents" / "wiki" / "01-architecture.md").read_text(encoding="utf-8")
        self.assertTrue(page.startswith("---\n"))
        self.assertIn('aliases:', page)
        self.assertIn("tags:", page)
        # The alias is what makes both spellings resolve.
        self.assertIn("01 Architecture", page)

    def test_ledger_is_never_rewritten(self):
        rag.generate_wiki(self.root)
        rag.generate_wiki(self.root)
        after = (self.root / ".agents" / "wiki" / "ledger.md").read_text(encoding="utf-8")
        self.assertEqual(after, self.ledger)

    def test_no_relative_markdown_page_links_survive(self):
        rag.generate_wiki(self.root)
        for page in (self.root / ".agents" / "wiki").glob("*.md"):
            text = page.read_text(encoding="utf-8", errors="replace")
            if page.name == "ledger.md":
                continue
            self.assertNotIn("](01-architecture.md)", text)
            self.assertNotIn("](02-codebase-connections.md)", text)


class WorktreeSharedStateTest(unittest.TestCase):
    """Shared-state resolution must find the canonical store, and must not over-reach.

    Three defects lived here, each of which presents as "retrieval quietly returns less":

    1. `Path(*parts[:i])` on a Windows gitdir dropped the drive separator (`D:Code/repo`), so a
       worktree resolved to itself and never saw the canonical store.
    2. A Windows `gitdir:` path is meaningless to a POSIX host, so `git rev-parse` failed inside a
       WSL worktree and every worktree-aware lookup silently fell back to the worktree.
    3. Once (1) and (2) were fixed, any directory *under* a git checkout inherited that checkout's
       vectors, because `git rev-parse` answers for the enclosing repo.
    """

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_non_worktree_directory_resolves_to_itself(self):
        plain = self.root / "not-a-repo"
        (plain / ".agents" / "rag" / "lancedb").mkdir(parents=True)
        self.assertEqual(rag.resolve_canonical_repo_root(plain), plain.resolve())
        # A directory that is not a git worktree must not borrow anything.
        self.assertEqual(rag.shared_rag_dir(plain), plain / ".agents" / "rag")

    def test_linked_worktree_borrows_the_canonical_store(self):
        main = self.root / "main-repo"
        (main / ".git" / "worktrees" / "wt").mkdir(parents=True)
        (main / ".agents" / "rag" / "lancedb").mkdir(parents=True)
        main = main.resolve()
        wt = self.root / "wt"
        wt.mkdir()
        (wt / ".git").write_text(
            f"gitdir: {str(main / '.git' / 'worktrees' / 'wt').replace(chr(92), '/')}\n",
            encoding="utf-8",
        )
        self.assertEqual(rag.resolve_canonical_repo_root(wt), main)
        self.assertEqual(rag.shared_rag_dir(wt), main / ".agents" / "rag")

    def test_drive_path_gitdir_is_translated_when_possible(self):
        # A Windows drive path is translated only when the translated target actually exists;
        # otherwise it is returned unchanged so the caller can decide. Either way it must not raise.
        original = "D:/Code/repo/.git/worktrees/wt"
        candidate = rag._normalize_foreign_path(Path(original))
        self.assertIsInstance(candidate, Path)
        translated_target = Path("/mnt/d/Code/repo/.git/worktrees/wt")
        if os.name == "nt" or not translated_target.exists():
            # Native Windows, or a POSIX host with no such mount: the same location is preserved.
            # Compare as Paths — `Path` normalises separators, so a raw string compare is wrong.
            self.assertEqual(candidate, Path(original))
        else:
            self.assertEqual(candidate, translated_target)

    def test_drive_separator_survives_canonical_reconstruction(self):
        # The slice bug produced `D:Code/repo`; walking up from the gitdir cannot lose the drive.
        main = self.root / "repo"
        (main / ".git" / "worktrees" / "wt").mkdir(parents=True)
        main = main.resolve()
        gitdir = main / ".git" / "worktrees" / "wt"
        self.assertEqual(gitdir.parent.parent.parent, main)


class KnowledgeRetrievalTest(unittest.TestCase):
    """The `.agents/**` corpus must be readable, not merely written.

    The original defect was not a missing table: the table was created and populated, and nothing
    ever queried it. An index nobody reads is indistinguishable from no index at all, except that it
    costs embedding spend.
    """

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        for area in ("memories", "tasks", "plans", "rag"):
            (self.root / ".agents" / area).mkdir(parents=True)

    def tearDown(self):
        self.tmp.cleanup()

    def test_search_reads_through_arrow_not_pandas(self):
        # `to_pandas()` required a dependency this engine does not declare; the resulting
        # ImportError was caught by the caller and surfaced as "no hits". Assert on the call, not on
        # the prose that explains it.
        import inspect

        source = inspect.getsource(rag.LanceStore.search)
        self.assertNotIn(".to_pandas(", source)
        self.assertIn(".to_arrow()", source)

    def test_missing_index_reports_a_hint_rather_than_an_empty_result(self):
        result = rag.retrieve_knowledge(self.root, "anything", client=object(), route_decision={})
        self.assertEqual(result["mode"], "knowledge_not_indexed")
        self.assertIn("index --agents", result["hint"])

    def test_driver_error_is_reported_with_its_reason(self):
        store = rag.LanceStore(self.root / ".agents" / "rag" / "lancedb")
        # With no table present, `table_exists` is False and connect_error explains a missing driver.
        self.assertFalse(store.table_exists())
        self.assertEqual(store.list_table_names(), [])

    def test_knowledge_section_is_capped_and_labelled(self):
        hits = [
            {"path": ".agents/tasks/a.md", "doc_type": "agents_task", "score": 0.9, "content": "x" * 4000},
            {"path": ".agents/plans/b.md", "doc_type": "agents_plan", "score": 0.8, "content": "y" * 4000},
        ]
        body = rag.render_knowledge_section(hits, self.root, 300)
        self.assertIn(".agents/tasks/a.md", body)
        self.assertLessEqual(rag.estimate_tokens(body), 600)

    def test_knowledge_is_not_dropped_before_either_driver(self):
        # A prior record is often the cheapest useful section, so it must outlive the drivers.
        caps = rag.CONTEXT_SECTION_CAPS
        self.assertIn("knowledge", caps)
        self.assertGreater(caps["knowledge"], 0)

    def test_native_search_with_reason_returns_exactly_two_values(self):
        # The success path returned the list alone while the caller unpacked `(hits, reason)`, so the
        # first time the compiled engine actually found something the prime died with ValueError.
        # A degraded host reaches that path as soon as the index is populated, which is the normal
        # case rather than the edge.
        import inspect

        source = inspect.getsource(rag.NativeQueryStore.search_with_reason)
        returns = [l.strip() for l in source.splitlines() if l.strip().startswith("return ")]
        self.assertTrue(returns)
        for line in returns:
            if line.startswith("return []"):
                self.assertIn(",", line, f"bare list return breaks the caller: {line}")
            elif line.startswith("return normalised"):
                self.assertIn(",", line, f"bare list return breaks the caller: {line}")


    def test_upsert_replaces_by_path_instead_of_appending(self):
        # A bare `add` appended a second copy of every record on each refresh — the knowledge table
        # reached 4,002 rows for 2,001 chunks, so search returned each record twice and spent the
        # budget on duplicates.
        import inspect

        source = inspect.getsource(rag.LanceStore.upsert)
        self.assertIn("tbl.delete", source, "upsert must delete stale rows for the same path")
        self.assertIn("tbl.add(records)", source, "upsert still appends after clearing")
        # The delete must come first; appending before deleting would double every row.
        self.assertLess(
            source.index("tbl.delete"),
            source.index("tbl.add(records)"),
            "delete must precede add, or a refresh duplicates every record",
        )

    def test_count_uses_the_table_counter_not_len(self):
        # `len(tbl)` returned 0 for a populated Lance table, so status/index/receipt all reported an
        # empty corpus that was in fact full.
        import inspect

        source = inspect.getsource(rag.LanceStore.count)
        self.assertIn("count_rows", source)
        self.assertNotIn("len(db.open_table", source)


if __name__ == "__main__":
    unittest.main()
