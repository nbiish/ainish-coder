"""Wiki knowledge graph: retrieval without an embedding endpoint.

The contract this asserts is the one an operator relies on when the machine has no embedder:
retrieval still returns labelled hits, the newest wiki pages and coordination artifacts are what
gets read, and recency is what breaks ties. If any of that stops being true, `--context` quietly
degrades into a filesystem scan that looks like retrieval but is not.
"""

import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import rag  # noqa: E402


class WikiGraphTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self._tmp.name)
        (self.repo / ".agents" / "wiki").mkdir(parents=True)
        (self.repo / ".agents" / "comms").mkdir(parents=True)
        (self.repo / ".agents" / "tasks").mkdir(parents=True)
        (self.repo / ".agents" / "llms.txt").write_text("# .agents map\nwiki and comms\n", encoding="utf-8")

        (self.repo / ".agents" / "wiki" / "01-architecture.md").write_text(
            "# Architecture\n\n## Sync engine\n"
            "The machine-sync verb snapshots the working tree into a commit on a per-machine ref. "
            "Windows has no exec bits, so the index is seeded before add -A.\n\n"
            "## Deploy rules\nUnrelated material about targets and manifests.\n",
            encoding="utf-8",
        )
        old = self.repo / ".agents" / "wiki" / "02-old.md"
        old.write_text("## Legacy\nEmbedding vectors and lancedb have nothing to do with this.\n", encoding="utf-8")
        os_time = time.time() - 86400
        import os
        os.utime(old, (os_time, os_time))

        (self.repo / ".agents" / "tasks" / "2026-01-01-old-task.md").write_text(
            "# old task\nmachine-sync snapshot ref\n", encoding="utf-8"
        )
        newest = self.repo / ".agents" / "tasks" / "2026-11-10-machine-sync-task.md"
        newest.write_text("# newest task\nmachine-sync snapshot windows index seeded\n", encoding="utf-8")

    def tearDown(self):
        self._tmp.cleanup()

    def test_graph_nodes_are_wiki_sections_not_whole_pages(self):
        graph = rag.build_wiki_graph(self.repo)
        wiki_nodes = [n for n in graph["nodes"] if n["kind"] == "wiki"]
        titles = {n["title"] for n in wiki_nodes}
        self.assertIn("Sync engine", titles)
        self.assertIn("Deploy rules", titles)
        self.assertNotIn("Architecture", titles, "a whole page should not be a single node")

    def test_graph_includes_newest_coordination_artifacts(self):
        graph = rag.build_wiki_graph(self.repo)
        paths = {n["path"] for n in graph["nodes"]}
        self.assertIn(".agents/tasks/2026-11-10-machine-sync-task.md", paths)
        self.assertIn(".agents/tasks/2026-01-01-old-task.md", paths)
        self.assertIn(".agents/llms.txt", paths)

    def test_retrieval_returns_hits_without_any_embedding(self):
        result = rag.graph_retrieve(self.repo, "how does machine-sync snapshot uncommitted work")
        self.assertTrue(result["hits"], "graph retrieval returned nothing for a term that exists")
        self.assertIn("wiki_graph", result["mode"])
        top = result["hits"][0]
        self.assertEqual(top["decision_role"], "graph")
        self.assertGreater(top["decision_score"], 0.0)
        self.assertTrue(top["content"])

    def test_newest_artifact_outranks_the_stale_one(self):
        result = rag.graph_retrieve(self.repo, "machine-sync snapshot task")
        paths = [h["path"] for h in result["hits"]]
        self.assertIn(".agents/tasks/2026-11-10-machine-sync-task.md", paths)
        newest_rank = paths.index(".agents/tasks/2026-11-10-machine-sync-task.md")
        if ".agents/tasks/2026-01-01-old-task.md" in paths:
            self.assertLess(newest_rank, paths.index(".agents/tasks/2026-01-01-old-task.md"))

    def test_unmatched_task_returns_nothing_rather_than_noise(self):
        result = rag.graph_retrieve(self.repo, "zzzznonexistenttokenzzzz")
        self.assertEqual(result["hits"], [])

    def test_cache_is_reused_and_rebuilt_on_change(self):
        first = rag.load_wiki_graph(self.repo)
        cache = self.repo / ".agents" / "rag" / "wiki-graph.json"
        self.assertTrue(cache.is_file(), "the graph should be cached under .agents/rag/")
        second = rag.load_wiki_graph(self.repo)
        self.assertEqual(first["fingerprint"], second["fingerprint"])

        (self.repo / ".agents" / "wiki" / "03-new.md").write_text(
            "## Fresh\nbrand new chapter about sync refs\n", encoding="utf-8"
        )
        third = rag.load_wiki_graph(self.repo)
        self.assertNotEqual(first["fingerprint"], third["fingerprint"], "a new source must invalidate the cache")

    def test_empty_repository_does_not_raise(self):
        empty = Path(tempfile.mkdtemp())
        try:
            result = rag.graph_retrieve(empty, "anything at all")
            self.assertEqual(result["hits"], [])
        finally:
            import shutil
            shutil.rmtree(empty, ignore_errors=True)


class WikiVaultPreservationTest(unittest.TestCase):
    """The reachable engine must never silently downgrade an Obsidian vault.

    The vault renderer lives only in the Rust crate (`wiki.rs`). `rag.py` writes plain
    markdown, so an unguarded `ainish-rag wiki` here replaces frontmatter, aliases, tags and
    every `[[wikilink]]` with plain pages — deleting the Obsidian graph and the explicit
    retrieval edges built from it, while still reporting success. A downgrade that looks like
    a successful run is the failure mode the contract forbids, so generation must refuse.
    """

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self._tmp.name)
        self.wiki = self.repo / ".agents" / "wiki"
        self.wiki.mkdir(parents=True)

    def tearDown(self):
        self._tmp.cleanup()

    def _vault_page(self, name="01-architecture.md"):
        self.wiki.joinpath(name).write_text(
            "---\n"
            "title: System Architecture\n"
            "aliases: [\"architecture\"]\n"
            "tags: [ainish/wiki/architecture, ainish/wiki/generated]\n"
            "up: \"[[README]]\"\n"
            "---\n\n"
            "# 01. System Architecture\n\n## Sync\nbody\n\n## Related\n- [[README|Vault index]]\n",
            encoding="utf-8",
        )

    def test_vault_pages_are_detected(self):
        self._vault_page()
        self.wiki.joinpath("README.md").write_text(
            "---\ntags: [ainish/wiki/index]\n---\n\n# index\n", encoding="utf-8")
        detected = rag._vault_pages(self.wiki)
        self.assertEqual(len(detected), 2, "both tagged pages must be recognised as vault pages")

    def test_plain_pages_are_not_vault_pages(self):
        self.wiki.joinpath("legacy.md").write_text("# plain\n\nbody\n", encoding="utf-8")
        self.assertEqual(rag._vault_pages(self.wiki), [],
                         "pages without the tag are legacy output and may be regenerated")

    def test_generation_refuses_to_clobber_a_vault(self):
        self._vault_page()
        before = {p.name: p.read_text(encoding="utf-8") for p in self.wiki.glob("*.md")}
        with self.assertRaises(SystemExit) as ctx:
            rag.generate_wiki(self.repo)
        message = str(ctx.exception)
        self.assertIn("refusing to overwrite an Obsidian vault", message)
        self.assertIn("ainish/wiki", message, "the refusal must name the tag it detected")
        self.assertIn("native engine", message, "the refusal must name what CAN do it")
        after = {p.name: p.read_text(encoding="utf-8") for p in self.wiki.glob("*.md")}
        self.assertEqual(before, after, "a refused run must leave every page byte-identical")

    def test_generation_still_works_without_a_vault(self):
        pages = rag.generate_wiki(self.repo)
        self.assertTrue(pages, "a non-vault repo must still generate")
        self.assertTrue(self.wiki.joinpath("README.md").is_file())

    def test_wikilinks_survive_a_refused_run(self):
        self._vault_page("README.md")
        links_before = rag._vault_pages(self.wiki)[0].read_text(encoding="utf-8").count("[[")
        self.assertGreater(links_before, 0)
        with self.assertRaises(SystemExit):
            rag.generate_wiki(self.repo)
        links_after = self.wiki.joinpath("README.md").read_text(encoding="utf-8").count("[[")
        self.assertEqual(links_before, links_after,
                         "the Obsidian graph edges are what this guard exists to protect")


if __name__ == "__main__":
    unittest.main()
