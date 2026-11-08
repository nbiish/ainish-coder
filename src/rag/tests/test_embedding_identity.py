#!/usr/bin/env python3
"""Tests for embedding-space identity: the provider is not the space.

The store fingerprint's job is to answer one question: "were these vectors produced by the same
model as the one now in use?" Encoding the transport into that answer broke it in both directions:

* a harmless provider failover (zenmux -> openrouter, both serving text-embedding-3-small at cosine
  1.000000) looked like index corruption and demanded a rebuild;
* pointing retrieval at the router's stable route id (local-router/fallback-embedding) looked like a
  third, unrelated space even though it resolves to the same model.

So identity is derived from the MODEL, and a route id is resolved through a declared alias table
rather than guessed.

Run with:  py -m unittest discover -s src/rag/tests -p "test_*.py"
"""

import importlib.util
import unittest
from pathlib import Path

RAG_PATH = Path(__file__).resolve().parents[1] / "rag.py"
_SPEC = importlib.util.spec_from_file_location("ainish_rag", RAG_PATH)
rag = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(rag)


class TestModelSpace(unittest.TestCase):
    def test_bare_model_is_its_own_space(self):
        self.assertEqual(
            rag.embedding_model_space("openai/text-embedding-3-small"),
            "openai/text-embedding-3-small",
        )

    def test_provider_prefix_is_stripped(self):
        for prefixed in (
            "openrouter/openai/text-embedding-3-small",
            "zenmux/openai/text-embedding-3-small",
            "nous-portal/openai/text-embedding-3-small",
        ):
            self.assertEqual(
                rag.embedding_model_space(prefixed),
                "openai/text-embedding-3-small",
                f"{prefixed} names a transport, not a space",
            )

    def test_all_three_providers_share_one_identity(self):
        # This is the whole point: a fallback step must be invisible to the fingerprint.
        identities = {
            rag.embedding_model_space(f"{p}/openai/text-embedding-3-small")
            for p in ("openrouter", "zenmux", "nous-portal")
        }
        self.assertEqual(len(identities), 1)

    def test_route_id_resolves_to_the_model_it_serves(self):
        self.assertEqual(
            rag.embedding_model_space("local-router/fallback-embedding"),
            "openai/text-embedding-3-small",
        )

    def test_different_models_stay_different_spaces(self):
        small = rag.embedding_model_space("openrouter/openai/text-embedding-3-small")
        large = rag.embedding_model_space("openrouter/openai/text-embedding-3-large")
        qwen = rag.embedding_model_space("nous-portal/qwen/qwen3-embedding-8b")
        self.assertNotEqual(small, large)
        self.assertNotEqual(small, qwen)
        self.assertNotEqual(large, qwen)

    def test_local_gemma_is_a_distinct_space_from_openai(self):
        # A local GGUF is a different model: swapping to it must be visible, never silent.
        remote = rag.embedding_model_space("openai/text-embedding-3-small")
        local = rag.embedding_identity_from_cfg({"provider": "local"})
        self.assertNotEqual(f"model:{remote}", local)

    def test_empty_model_is_unknown_not_blank(self):
        self.assertEqual(rag.embedding_model_space(""), "unknown-model")
        self.assertEqual(rag.embedding_model_space(None), "unknown-model")


class TestIdentityFromCfg(unittest.TestCase):
    def test_route_configured_cfg_matches_upstream_provider_cfg(self):
        # The migration this unblocks: switch the embed provider to the router's route id and the
        # existing index must still be recognised as the same space.
        via_router = rag.embedding_identity_from_cfg(
            {"provider": "api", "provider_id": "local-router", "model": "local-router/fallback-embedding"}
        )
        via_openrouter = rag.embedding_identity_from_cfg(
            {"provider": "api", "provider_id": "openrouter", "model": "openai/text-embedding-3-small"}
        )
        self.assertEqual(via_router, via_openrouter)

    def test_local_provider_identity_is_stable(self):
        self.assertEqual(rag.embedding_identity_from_cfg({"provider": "local"}), "local:embeddinggemma-2")

    def test_identity_does_not_leak_api_key(self):
        cfg = {
            "provider": "api",
            "provider_id": "openrouter",
            "model": "openai/text-embedding-3-small",
            "api_key": "sk-secret-value-that-must-not-appear",
        }
        identity = rag.embedding_identity_from_cfg(cfg)
        self.assertNotIn("sk-secret", identity)
        self.assertNotIn(cfg["api_key"], identity)


class TestAliasTableIsDeclared(unittest.TestCase):
    def test_known_route_is_declared(self):
        self.assertIn("local-router/fallback-embedding", rag.EMBED_ROUTE_MODEL_ALIASES)

    def test_alias_targets_are_bare_model_ids(self):
        # An alias value must be a model, not another route, or resolution could loop.
        for route, model in rag.EMBED_ROUTE_MODEL_ALIASES.items():
            self.assertNotEqual(route, model)
            self.assertNotIn(model, rag.EMBED_ROUTE_MODEL_ALIASES)


class TestFingerprintMigration(unittest.TestCase):
    """A v1 fingerprint must not be mistaken for a different vector space."""

    def test_legacy_api_identity_normalizes_to_model_space(self):
        self.assertEqual(
            rag.normalize_identity("api:openrouter:openai/text-embedding-3-small"),
            "model:openai/text-embedding-3-small",
        )

    def test_legacy_and_current_forms_compare_equal(self):
        legacy = rag.normalize_identity("api:openrouter:openai/text-embedding-3-small")
        current = rag.normalize_identity("model:openai/text-embedding-3-small")
        self.assertEqual(legacy, current)

    def test_legacy_provider_change_is_not_a_mismatch(self):
        # The exact migration: store built via openrouter, now served via the router route.
        self.assertEqual(
            rag.normalize_identity("api:openrouter:openai/text-embedding-3-small"),
            rag.normalize_identity(
                rag.embedding_identity_from_cfg(
                    {"provider": "api", "provider_id": "local-router",
                     "model": "local-router/fallback-embedding"}
                )
            ),
        )

    def test_legacy_different_model_is_still_a_mismatch(self):
        self.assertNotEqual(
            rag.normalize_identity("api:openrouter:openai/text-embedding-3-small"),
            rag.normalize_identity(
                rag.embedding_identity_from_cfg(
                    {"provider": "api", "provider_id": "openrouter",
                     "model": "openai/text-embedding-3-large"}
                )
            ),
        )

    def test_local_identity_is_preserved(self):
        self.assertEqual(rag.normalize_identity("local:embeddinggemma-2"), "local:embeddinggemma-2")

    def test_empty_normalizes_to_empty(self):
        self.assertEqual(rag.normalize_identity(None), "")
        self.assertEqual(rag.normalize_identity(""), "")


if __name__ == "__main__":
    unittest.main()
