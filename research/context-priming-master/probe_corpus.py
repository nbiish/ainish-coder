#!/usr/bin/env python3
"""Does the widened corpus improve retrieval, or just enlarge it?

A bigger corpus is only an improvement if the RIGHT node comes back. This measures, for a fixed set of
probes spanning every kind, what the top hit is under the old corpus (52 nodes) and the new one (389).
It is deliberately small and honest: it answers "did the right kind surface" — not "was the prime
better", which needs the outcome signal and is a different question.

Run: python3 research/context-priming-master/probe_corpus.py
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]


def load_rag():
    sys.path.insert(0, str(REPO / "src" / "rag"))
    spec = importlib.util.spec_from_file_location("ainish_rag", REPO / "src" / "rag" / "rag.py")
    m = importlib.util.module_from_spec(spec)
    sys.modules["ainish_rag"] = m
    spec.loader.exec_module(m)
    return m


# (probe, expected kind, why this is the right kind)
PROBES = [
    ("what does the contract say about worktrees and merging back",
     "contract", "the rules governing a worktree"),
    ("how does graph_retrieve score nodes with idf and recency",
     "wiki", "the architecture page describes the engine"),
    ("what did the harness2 paper propose for propose probe compose",
     "research", "the paper's own method"),
    ("what did the practitioner video find about self-bloating harnesses",
     "research", "the transcript's finding"),
    ("what was the last task about federation discoverability",
     "tasks", "a task record"),
    ("what did we decide about staging learned skills versus promoting them",
     "plans", "a plan records the decision"),
    ("what skills does this repo ship for security",
     "templates", "the skills index"),
]


def top_kinds(rag, corpus_settings: dict, want: int = 5) -> dict:
    out = {}
    for probe, expected, _ in PROBES:
        res = rag.graph_retrieve(REPO, probe, want=want, settings=corpus_settings)
        kinds = [str(h.get("kind") or "") for h in res.get("hits") or []]
        paths = [str(h.get("path") or "") for h in res.get("hits") or []]
        out[probe] = {"expected": expected, "kinds": kinds, "paths": paths}
    return out


def main() -> int:
    rag = load_rag()
    # "narrow" reproduces the pre-change corpus: newest 2 per folder, newest 8 wiki, no extras.
    narrow = {
        "max_wiki_pages": 8, "max_artifacts": 2, "chapter_chars": 1400, "hop_bonus": 0.35,
        "recency_floor": 0.55, "shared_term_threshold": 3, "weights": {},
        "section_caps": {}, "domain_prior": {},
    }
    wide = dict(narrow)
    wide.update({"max_wiki_pages": 0, "max_artifacts": 0})

    # graph_retrieve reads settings for caps; the extra sources are module-level, so simulate "narrow"
    # by temporarily disabling them and restoring afterwards.
    saved_extra = rag.GRAPH_EXTRA_SOURCES
    try:
        rag.GRAPH_EXTRA_SOURCES = ()
        narrow_res = top_kinds(rag, narrow)
    finally:
        rag.GRAPH_EXTRA_SOURCES = saved_extra
    wide_res = top_kinds(rag, wide)

    print(f"{'probe':<62}{'expect':>9}   narrow top-1 / wide top-1")
    print("-" * 108)
    hit_narrow = hit_wide = 0
    for probe, expected, _ in PROBES:
        n1 = (narrow_res[probe]["kinds"] or [""])[0]
        w1 = (wide_res[probe]["kinds"] or [""])[0]
        hit_narrow += n1 == expected
        hit_wide += w1 == expected
        mark = "OK " if w1 == expected else "   "
        print(f"{probe[:60]:<62}{expected:>9}   {n1 or '-':>10} / {mark}{w1 or '-'}")
    print("-" * 108)
    print(f"top-1 kind correct:  narrow {hit_narrow}/{len(PROBES)}   wide {hit_wide}/{len(PROBES)}")
    if hit_wide < hit_narrow:
        print("\nREGRESSION: the wider corpus put the right kind on top less often.")
        return 1
    if hit_wide == hit_narrow:
        print("\nNo change in top-1 accuracy. The wider corpus adds reach without displacing the "
              "curated layer — acceptable, but it is not evidence of improvement.")
        return 0
    print("\nThe wider corpus surfaces the right kind more often than the sample did.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
