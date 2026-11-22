#!/usr/bin/env python3
"""Phase 0 — do the contrast signals separate anything?

This is a THROWAWAY experiment, not production code. It exists to answer one question before
~800 lines of learning loop are written:

    Can five mechanical signals distinguish a wide prime from a narrow one from the base?

If they cannot, the loop proposed in .agents/plans/2026-11-17-19-context-priming-master.md must not
be built, because its acceptance gate would be choosing between indistinguishable options and calling
the result improvement. Harness^2 Figure 7 (refining without a reference regresses, 73.4 -> 63.2) and
the practitioner video's round 1 (an elegant recursive harness MATCHED a frozen one exactly) are both
warnings that this question is usually answered "no".

Fidelity note: the signals are computed on the REAL output of `graph_retrieve` in src/context/engine.py,
with the module constants monkeypatched per profile. The scoring loop is not reimplemented, so a
result here is a result about production behaviour rather than about a copy of it.

Run:  python3 research/context-priming-master/phase0.py [--json] [--tasks N]
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "src" / "context"))


def load_rag():
    """Import src/context/engine.py by path, so this runs without installing anything."""
    spec = importlib.util.spec_from_file_location("ainish_rag", REPO / "src" / "context" / "engine.py")
    if spec is None or spec.loader is None:
        raise SystemExit(f"cannot load {REPO / 'src' / 'rag' / 'rag.py'}")
    module = importlib.util.module_from_spec(spec)
    sys.modules["ainish_rag"] = module
    spec.loader.exec_module(module)
    return module


# ── profiles ────────────────────────────────────────────────────────────────
# base    the shipped hand-tuned constants
# wide    much more corpus, much larger chapters, weaker recency preference
# narrow  much less corpus, small chapters, stronger recency preference
PROFILES: Dict[str, Dict[str, Any]] = {
    "base":   {"max_wiki_pages": 8, "max_artifacts": 2, "chapter_chars": 1400, "hop_bonus": 0.35},
    "wide":   {"max_wiki_pages": 16, "max_artifacts": 6, "chapter_chars": 2400, "hop_bonus": 0.60},
    "narrow": {"max_wiki_pages": 3, "max_artifacts": 1, "chapter_chars": 600, "hop_bonus": 0.15},
}


def collect_tasks(limit: int) -> List[Tuple[str, str]]:
    """Real task text from this repo's own coordination record.

    Task records carry `- objective:`; plans carry `## 1. Problem`. Both are the operator's own
    words about real work, which is a far better probe set than invented strings.
    """
    out: List[Tuple[str, str]] = []

    tasks_dir = REPO / ".agents" / "tasks"
    if tasks_dir.is_dir():
        # Newest first: recent work is what the prime is expected to serve.
        files = sorted(tasks_dir.glob("*.md"), key=lambda p: p.stat().st_mtime, reverse=True)
        for path in files:
            try:
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            m = re.search(r"^- objective:\s*(.+?)(?=^## |\Z)", text, re.S | re.M)
            if not m:
                continue
            body = " ".join(m.group(1).split())
            if len(body) < 60:
                continue
            out.append((f"task:{path.stem}", body[:600]))

    plans_dir = REPO / ".agents" / "plans"
    if plans_dir.is_dir():
        files = sorted(plans_dir.glob("*.md"), key=lambda p: p.stat().st_mtime, reverse=True)
        for path in files:
            try:
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            m = re.search(r"^## 1\. Problem\s*\n(.+?)(?=^## )", text, re.S | re.M)
            if not m:
                continue
            body = " ".join(m.group(1).split())
            if len(body) < 60:
                continue
            out.append((f"plan:{path.stem}", body[:600]))

    # De-duplicate on the text itself: plans and task records often restate one another.
    seen, uniq = set(), []
    for name, body in out:
        key = body[:120]
        if key in seen:
            continue
        seen.add(key)
        uniq.append((name, body))
    return uniq[:limit]


# ── the five signals ────────────────────────────────────────────────────────
def sig_coverage(rag, task: str, hits: List[Dict[str, Any]], graph: Dict[str, Any]) -> float:
    """Fraction of the task's RAREST terms that appear anywhere in the retrieved set.

    Rare terms are the ones that actually identify the answer; a common word appearing in a hit
    proves nothing. Rarity is document frequency across the corpus, the same idea graph_retrieve
    already uses for its own weighting.
    """
    task_terms = rag._graph_terms(task)
    if not task_terms:
        return 0.0
    df: Dict[str, int] = {}
    for node in graph.get("nodes") or []:
        for term in node.get("terms") or []:
            df[term] = df.get(term, 0) + 1
    # The 8 rarest task terms carry the identifying signal.
    ranked = sorted(task_terms, key=lambda t: df.get(t, 0))
    probe = ranked[:8]
    if not probe:
        return 0.0
    blob = " ".join(str(h.get("content") or "") for h in hits).lower()
    found = sum(1 for t in probe if t in blob)
    return found / len(probe)


def sig_concentration(rag, task: str, hits: List[Dict[str, Any]], graph: Dict[str, Any]) -> float:
    """Share of the retrieval budget spent on hits scoring at least half the top hit.

    decision_score is normalised so the top hit is 1.0; 0.5 is the same threshold the production
    code uses for its `noul_band` yes/partial split, so this measures the same thing the engine
    already believes is meaningful.
    """
    if not hits:
        return 0.0
    total = sum(rag.estimate_tokens(str(h.get("content") or "")) for h in hits) or 1
    strong = sum(
        rag.estimate_tokens(str(h.get("content") or ""))
        for h in hits
        if float(h.get("decision_score") or 0.0) >= 0.5
    )
    return strong / total


def sig_freshness(rag, task: str, hits: List[Dict[str, Any]], graph: Dict[str, Any]) -> float:
    """1.0 if any hit is among the newest fifth of the corpus, else 0.0.

    A prime that never surfaces recent work is answering from an archive; that is a failure mode
    the recency weighting exists to prevent, so it is worth measuring separately from coverage.
    """
    nodes = graph.get("nodes") or []
    if not nodes or not hits:
        return 0.0
    mtimes = sorted((float(n.get("mtime") or 0.0) for n in nodes), reverse=True)
    cutoff = mtimes[max(0, len(mtimes) // 5 - 1)] if len(mtimes) >= 5 else mtimes[-1]
    hit_paths = {str(h.get("path") or "") for h in hits}
    newest = [n for n in nodes if float(n.get("mtime") or 0.0) >= cutoff]
    return 1.0 if any(str(n.get("path")) in hit_paths for n in newest) else 0.0


def sig_redundancy(rag, task: str, hits: List[Dict[str, Any]], graph: Dict[str, Any]) -> float:
    """Mean pairwise line-Jaccard across hit bodies. Lower is better.

    This is harness2's `diversity()` inverted, as noted in the design: paying budget twice for the
    same lines is the concrete form of "the prime is bloated".
    """
    sets = []
    for hit in hits:
        lines = {ln.strip() for ln in str(hit.get("content") or "").splitlines() if ln.strip()}
        if lines:
            sets.append(lines)
    if len(sets) < 2:
        return 0.0
    sims = []
    for i, a in enumerate(sets):
        for b in sets[i + 1:]:
            union = a | b
            sims.append(len(a & b) / len(union) if union else 1.0)
    return sum(sims) / len(sims) if sims else 0.0


def sig_cost(rag, task: str, hits: List[Dict[str, Any]], graph: Dict[str, Any]) -> int:
    """Tokens the rendered retrieval section would spend. Lower is better, all else equal."""
    return sum(rag.estimate_tokens(str(h.get("content") or "")) for h in hits)


SIGNALS = (
    ("coverage", sig_coverage, "higher"),
    ("concentration", sig_concentration, "higher"),
    ("freshness", sig_freshness, "higher"),
    ("redundancy", sig_redundancy, "lower"),
    ("cost", sig_cost, "lower"),
)


def measure(rag, task: str, profile: Dict[str, Any]) -> Dict[str, Any]:
    """Run production retrieval under one profile and score the result."""
    # Monkeypatch, so `graph_retrieve` itself is unmodified production code.
    rag.GRAPH_MAX_WIKI_PAGES = profile["max_wiki_pages"]
    rag.GRAPH_MAX_ARTIFACTS = profile["max_artifacts"]
    rag.GRAPH_CHAPTER_CHARS = profile["chapter_chars"]
    rag.GRAPH_HOP_BONUS = profile["hop_bonus"]
    # Bypass the on-disk cache: it is keyed on source mtimes, not on these limits, so a cached
    # graph would silently answer for the previous profile.
    rag.load_wiki_graph = lambda root: rag.build_wiki_graph(root)

    graph = rag.build_wiki_graph(REPO)
    got = rag.graph_retrieve(REPO, task, want=8)
    hits = got.get("hits") or []
    row: Dict[str, Any] = {"hits": len(hits), "mode": got.get("mode")}
    for name, fn, _ in SIGNALS:
        row[name] = fn(rag, task, hits, graph)
    return row


def summarise(rows: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Per-profile means, and — more importantly — the PAIRED comparison.

    Comparing means across a task set conflates task difficulty with profile quality: a hard task
    covers less under every profile, which inflates the "within" spread and can make a real signal
    look like noise. A harness2 contrast is always paired — the same task under two harnesses — so
    the statistic that decides usefulness is the paired win rate: on how many tasks does the
    profile that SHOULD win actually win?
    """
    per: Dict[str, Dict[str, float]] = {}
    for name, _, _ in SIGNALS:
        per[name] = {}
        for profile in PROFILES:
            vals = [r[profile][name] for r in rows]
            per[name][profile] = round(sum(vals) / len(vals), 4) if vals else 0.0

    within = {}
    for name, _, _ in SIGNALS:
        spreads = []
        for profile in PROFILES:
            vals = [r[profile][name] for r in rows]
            spreads.append(max(vals) - min(vals) if vals else 0.0)
        within[name] = round(sum(spreads) / len(spreads), 4) if spreads else 0.0

    # Paired win rates. wide should beat narrow on quality signals; narrow should beat wide on cost.
    paired: Dict[str, Dict[str, Any]] = {}
    for name, _, direction in SIGNALS:
        wide_wins = narrow_wins = ties = 0
        for r in rows:
            w, n = r["wide"].get(name), r["narrow"].get(name)
            if w is None or n is None:
                continue
            if abs(float(w) - float(n)) < 1e-9:
                ties += 1
            elif (float(w) > float(n)) == (direction == "higher"):
                wide_wins += 1
            else:
                narrow_wins += 1
        decided = wide_wins + narrow_wins
        paired[name] = {
            "wide_wins": wide_wins,
            "narrow_wins": narrow_wins,
            "ties": ties,
            "win_rate": round(wide_wins / decided, 3) if decided else 0.0,
        }

    discriminating = {
        name: bool(paired[name]["win_rate"] >= 0.875 or paired[name]["win_rate"] <= 0.125)
        for name, _, _ in SIGNALS
    }
    return {
        "mean_by_profile": per,
        "within_profile_spread": within,
        "paired": paired,
        "discriminating": discriminating,
        "n_discriminating": sum(1 for v in discriminating.values() if v),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Phase 0 contrast-signal experiment")
    ap.add_argument("--json", action="store_true", help="emit the raw table as JSON")
    ap.add_argument("--tasks", type=int, default=8, help="how many real tasks to probe (default 8)")
    args = ap.parse_args()

    rag = load_rag()
    tasks = collect_tasks(args.tasks)
    if not tasks:
        raise SystemExit("no tasks found under .agents/{tasks,plans}")

    rows: List[Dict[str, Any]] = []
    for name, body in tasks:
        row = {"task": name, "probe": body[:90] + ("..." if len(body) > 90 else "")}
        for profile, values in PROFILES.items():
            try:
                row[profile] = measure(rag, body, values)
            except Exception as exc:  # a profile that crashes is itself a finding
                row[profile] = {n: None for n, _, _ in SIGNALS}
                row[profile]["error"] = f"{type(exc).__name__}: {exc}"[:160]
        rows.append(row)

    summary = summarise(rows)

    if args.json:
        print(json.dumps({"profiles": PROFILES, "rows": rows, "summary": summary}, indent=2))
        return 0

    print(f"Phase 0 — contrast signals over {len(tasks)} real tasks in {REPO.name}\n")
    print("1. PAIRED COMPARISON (the statistic that decides whether a signal can gate an edit)")
    h2 = f"{'signal':<15}{'wide wins':>11}{'narrow wins':>13}{'ties':>7}{'win rate':>11}{'verdict':>15}"
    print(h2)
    print("-" * len(h2))
    for name, _, direction in SIGNALS:
        p = summary["paired"][name]
        verdict = "DISCRIMINATES" if summary["discriminating"][name] else "noisy"
        print(
            f"{name:<15}{p['wide_wins']:>11}{p['narrow_wins']:>13}{p['ties']:>7}"
            f"{p['win_rate']:>11.3f}{verdict:>15}  ({direction} is better)"
        )

    print("\n2. MEANS BY PROFILE (context only — do not gate on these)")
    header = f"{'signal':<15}{'base':>10}{'wide':>10}{'narrow':>10}{'within':>10}"
    print(header)
    print("-" * len(header))
    for name, _, _ in SIGNALS:
        vals = summary["mean_by_profile"][name]
        print(
            f"{name:<15}{vals['base']:>10.4f}{vals['wide']:>10.4f}{vals['narrow']:>10.4f}"
            f"{summary['within_profile_spread'][name]:>10.4f}"
        )

    print(f"\ndiscriminating signals: {summary['n_discriminating']}/{len(SIGNALS)}")
    errors = [(r["task"], p, r[p].get("error")) for r in rows for p in PROFILES if r[p].get("error")]
    for task, profile, err in errors:
        print(f"  ERROR {task} / {profile}: {err}")

    print(
        "\nReading this: a signal DISCRIMINATES when the profile that should win does so on >=7 of 8\n"
        "paired tasks. 'wide' wins quality signals (coverage, concentration) because it sees more\n"
        "corpus; 'narrow' wins cost because it spends less. A signal near 0.5 is a coin flip and\n"
        "cannot gate an edit. Zero discriminating signals means the learning loop must not be built."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
