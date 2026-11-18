#!/usr/bin/env python3
"""Does the widened corpus help an agent answer, or only fill the budget?

The earlier probe asked "is the top hit the kind I expected", which turned out to be a bad metric: a
question about worktrees can be answered from a comms line describing a worktree merge, and calling that
a miss measures my label, not the retrieval.

What matters is whether the retrieved text CONTAINS what the question needs. So each probe below names a
fact — a literal string that must appear in the retrieved evidence for the question to be answerable
without opening a file. That is a checkable property, and it is the same standard the context system
holds itself to ("verify by reading back, never by exit code").

Run: python3 research/context-priming-master/probe_answer.py
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


# (question, a literal that must be retrievable to answer it without opening a file, note)
#
# These needles are deliberately literal text that a correct retrieval must surface. Two earlier
# candidates were DROPPED rather than tuned until green, because tuning a probe to pass is measuring
# the probe:
#   * "monotone" — the right page WAS retrieved, but under its `circular` heading; a needle pinned to one
#     section of a correctly-retrieved page tests the needle, not the retrieval.
#   * "log(1.0 + total / max(1, df.get" — that formula lives in `rag.py`, which is source CODE and not
#     corpus. No corpus widening can retrieve it, so asserting it here would demand a capability the
#     design explicitly does not have (code indexing) and call its absence a retrieval failure.
PROBES = [
    ("what does the contract require before cutting a branch",
     "Plan first", "AGENTS.md non-negotiable 1"),
    ("which command primes an agent",
     "ainish-rag --context", "the contract's Start here"),
    ("what did harness2 call the three-part improvement step",
     "Propose", "the paper's method"),
    ("what happened when a recursive harness bloated its before_done checklist",
     "before_done", "the practitioner video's failure mode"),
    ("was the proposed acceptance gate circular",
     "circular", "phase 0 findings, whose heading is the answer"),
    ("where do learned skills get staged",
     "context-harness/skills", "the design doc"),
    ("what is the 160 line gate on",
     "AGENTS.md", "the test gate"),
    ("what did the practitioner video conclude about when recursion pays off",
     "expensive to rebuild", "the video's actual conclusion"),
]


def run(rag, settings, *, extra) -> tuple[int, list]:
    saved = rag.GRAPH_EXTRA_SOURCES
    rag.GRAPH_EXTRA_SOURCES = extra
    hits = 0
    detail = []
    try:
        for question, needle, note in PROBES:
            res = rag.graph_retrieve(REPO, question, want=10, settings=settings)
            blob = "\n".join(str(h.get("content") or "") for h in res.get("hits") or [])
            found = needle.lower() in blob.lower()
            hits += found
            first = (res.get("hits") or [{}])[0]
            detail.append((question, needle, found,
                           str(first.get("kind") or "-"),
                           str(first.get("path") or "-")))
    finally:
        rag.GRAPH_EXTRA_SOURCES = saved
    return hits, detail


def main() -> int:
    rag = load_rag()
    narrow = {"max_wiki_pages": 8, "max_artifacts": 2, "chapter_chars": 1400, "hop_bonus": 0.35,
              "recency_floor": 0.55, "shared_term_threshold": 3, "weights": {},
              "section_caps": {}, "domain_prior": {}}
    wide = dict(narrow, max_wiki_pages=0, max_artifacts=0)

    n_hits, n_detail = run(rag, narrow, extra=())
    w_hits, w_detail = run(rag, wide, extra=rag.GRAPH_EXTRA_SOURCES)

    print(f"{'question':<56}{'needle':<20} narrow  wide")
    print("-" * 96)
    for (q, needle, _, _, _), (_, _, wf, wk, wp) in zip(n_detail, w_detail):
        nf = next(d[2] for d in n_detail if d[1] == needle)
        print(f"{q[:54]:<56}{needle[:18]:<20} {'yes' if nf else 'no ':>6}  "
              f"{'yes' if wf else 'no '}   [{wk}]")
    print("-" * 96)
    print(f"answerable without opening a file:  narrow {n_hits}/{len(PROBES)}   "
          f"wide {w_hits}/{len(PROBES)}")
    if w_hits < n_hits:
        print("\nREGRESSION: widening the corpus made fewer questions answerable.")
        return 1
    delta = w_hits - n_hits
    print(f"\nnet {delta:+d} question(s) made answerable by the wider corpus.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
