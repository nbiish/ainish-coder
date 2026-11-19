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
#
# The last four exist because they were MEASURED FAILURES: a "what did we just decide / what was the
# last task" question is the most common thing an agent asks this tool, and before the corpus fix the
# answer was invisible — plans, tasks and comms were capped at 2 files each, so the newest one was
# often not the one being asked about.
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
    ("why did the single-command context change reverse the separate-verb decision",
     "plans", "the plan of record explains the reversal"),
    ("what did the comms ledger record for the single command context task",
     "comms", "the daily ledger line"),
    ("what was the objective of the wiki pseudo skills task",
     "tasks", "the task record states the objective"),
    ("what did we learn about comms block parsing delimiters",
     "plans", "the plan carries the finding"),
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

    # Three states, because "widened" and "widened but bounded" are different corpora:
    #   narrow    2 artifacts / 8 wiki pages, no extras        (the pre-2026-11-18 corpus)
    #   wide      everything, unbounded shared-vocabulary edges (what the fix shipped as)
    #   bounded   everything, <=GRAPH_MAX_EDGES_PER_NODE edges  (what is proposed)
    # graph_retrieve reads the caps from settings; the extra sources and the edge bound are
    # module-level, so each state swaps them temporarily and restores afterwards.
    saved_extra = rag.GRAPH_EXTRA_SOURCES
    saved_bound = rag.GRAPH_MAX_EDGES_PER_NODE
    states = {}
    try:
        rag.GRAPH_EXTRA_SOURCES = ()
        rag.GRAPH_MAX_EDGES_PER_NODE = saved_bound
        states["narrow"] = top_kinds(rag, narrow)
    finally:
        rag.GRAPH_EXTRA_SOURCES = saved_extra
    try:
        rag.GRAPH_MAX_EDGES_PER_NODE = 10 ** 9
        states["wide"] = top_kinds(rag, wide)
    finally:
        rag.GRAPH_MAX_EDGES_PER_NODE = saved_bound
    states["bounded"] = top_kinds(rag, wide)

    labels = ("narrow", "wide", "bounded")
    print(f"{'probe':<58}{'expect':>10}   " + " / ".join(f"{l:>9}" for l in labels))
    print("-" * 116)
    hits = {l: 0 for l in labels}
    for probe, expected, _ in PROBES:
        cells = []
        for label in labels:
            k1 = (states[label][probe]["kinds"] or [""])[0]
            hits[label] += k1 == expected
            cells.append(("OK " if k1 == expected else "   ") + (k1 or "-"))
        print(f"{probe[:56]:<58}{expected:>10}   " + " / ".join(f"{c:>9}" for c in cells))
    print("-" * 116)
    print("top-1 kind correct:  " + "   ".join(f"{l} {hits[l]}/{len(PROBES)}" for l in labels))

    # Top-1 is a harsh metric for a tool that feeds a 12-slot prime: the question that matters to a
    # reader is whether the right KIND is present at all, since the block shows several hits.
    print()
    for label in labels:
        row = []
        for depth in (1, 3, 5):
            got = 0
            for probe, expected, _ in PROBES:
                if expected in (states[label][probe]["kinds"] or [])[:depth]:
                    got += 1
            row.append(f"top-{depth} {got}/{len(PROBES)}")
        print(f"expected kind present ({label:<8}): " + "   ".join(row))

    # The verdict weighs the bounded corpus, because that is what would ship. Widening without the
    # bound is measured but not recommended: at 102 edges per node one hop reaches most of the graph.
    # Acceptance is on REACH (right kind present in the prime), not on top-1: the prime is a labelled
    # multi-hit block, and forcing one kind to rank first would mean tuning against eleven probes.
    reach_ok = 0
    reach_narrow = 0
    for probe, expected, _ in PROBES:
        if expected in (states["bounded"][probe]["kinds"] or [])[:5]:
            reach_ok += 1
        if expected in (states["narrow"][probe]["kinds"] or [])[:5]:
            reach_narrow += 1
    if reach_ok < reach_narrow:
        print("\nREGRESSION: the widened+bounded corpus loses the right kind from the top five.")
        return 1
    if reach_ok == reach_narrow:
        print("\nNo change in reach against the narrow corpus. Acceptable, but not evidence of "
              "improvement — the wider corpus must earn its cost.")
        return 0
    print(f"\nThe widened+bounded corpus surfaces the right kind more often within five hits "
          f"({reach_ok - reach_narrow} more).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
