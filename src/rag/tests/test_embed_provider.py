#!/usr/bin/env python3
"""Tests for the remote API embedding provider and the memory-budget ctx/batch sizing.

* `EmbedClient.with_api_provider` must POST to `{api_base}/embeddings` with a Bearer key,
  skip the loopback DNS-rebinding guard, and parse the OpenAI-compatible response shape.
* `derive_ctx_batch` must scale llama's context/batch down with the `--max-mem` budget
  instead of the old hardcoded 8192/8192 that drove ~9.6 GB resident memory.

Run with:  py -m unittest discover -s src/rag/tests -p "test_*.py"
"""

import importlib.util
import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

RAG_PATH = Path(__file__).resolve().parents[1] / "rag.py"
_SPEC = importlib.util.spec_from_file_location("ainish_rag", RAG_PATH)
rag = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(rag)

DIM = 8


class _MockEmbeddings(BaseHTTPRequestHandler):
    """Minimal OpenAI-compatible /embeddings endpoint that records the last request."""

    seen = {}

    def do_POST(self):  # noqa: N802 (http.server API)
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length) or b"{}")
        _MockEmbeddings.seen = {
            "path": self.path,
            "auth": self.headers.get("Authorization"),
            "model": body.get("model"),
            "inputs": body.get("input"),
        }
        data = [
            {"index": i, "embedding": [float(i + 1)] * DIM}
            for i in range(len(body.get("input") or []))
        ]
        payload = json.dumps({"data": data, "model": body.get("model")}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args):  # silence test output
        pass


class ApiEmbeddingProviderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = HTTPServer(("127.0.0.1", 0), _MockEmbeddings)
        cls.port = cls.server.server_address[1]
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def test_api_provider_routes_and_parses(self):
        base = f"http://127.0.0.1:{self.port}/v1"
        client = rag.EmbedClient("http://127.0.0.1:1")
        client.with_api_provider(base, "text-embedding-3-small", "sk-test-key")

        self.assertTrue(client.uses_api_provider())
        vecs = client.embed_batch(["alpha", "beta"])

        self.assertEqual(len(vecs), 2)
        self.assertEqual(len(vecs[0]), DIM)
        # It hit the OpenAI-compatible path with the configured model + bearer key.
        self.assertEqual(_MockEmbeddings.seen["path"], "/v1/embeddings")
        self.assertEqual(_MockEmbeddings.seen["model"], "text-embedding-3-small")
        self.assertEqual(_MockEmbeddings.seen["auth"], "Bearer sk-test-key")
        self.assertEqual(_MockEmbeddings.seen["inputs"], ["alpha", "beta"])

    def test_local_provider_does_not_use_api(self):
        client = rag.EmbedClient("http://127.0.0.1:1")
        self.assertFalse(client.uses_api_provider())


class DeriveCtxBatchTest(unittest.TestCase):
    def test_default_budget_keeps_buffers_small(self):
        # No --max-mem: the 2048 MB default must not yield the old 8192/8192 pair.
        ctx, batch = rag.derive_ctx_batch(None)
        self.assertEqual(ctx, 2048)
        self.assertLessEqual(batch, 512)

    def test_budget_scales_both_directions(self):
        big_ctx, big_batch = rag.derive_ctx_batch(32000)
        self.assertEqual(big_ctx, 8192)
        self.assertLessEqual(big_batch, big_ctx)

        small_ctx, small_batch = rag.derive_ctx_batch(1024)
        self.assertLessEqual(small_ctx, 1024)
        self.assertLessEqual(small_batch, 256)

    def test_env_override_wins(self):
        import os

        old_ctx = os.environ.get("AINISH_RAG_CTX")
        old_batch = os.environ.get("AINISH_RAG_BATCH")
        try:
            os.environ["AINISH_RAG_CTX"] = "4096"
            os.environ["AINISH_RAG_BATCH"] = "1024"
            ctx, batch = rag.derive_ctx_batch(512)
            self.assertEqual((ctx, batch), (4096, 1024))
        finally:
            if old_ctx is None:
                os.environ.pop("AINISH_RAG_CTX", None)
            else:
                os.environ["AINISH_RAG_CTX"] = old_ctx
            if old_batch is None:
                os.environ.pop("AINISH_RAG_BATCH", None)
            else:
                os.environ["AINISH_RAG_BATCH"] = old_batch


if __name__ == "__main__":
    unittest.main()
