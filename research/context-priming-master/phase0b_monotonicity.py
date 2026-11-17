#!/usr/bin/env python3
"""Phase 0b — are the signals measuring quality, or just the knob?

Phase 0's paired test said 4 of 5 signals "discriminate" between wide and narrow profiles. That
result is suspicious for a reason worth testing before anyone trusts it: the wide profile sets *four*
knobs larger at once, and a larger window mechanically yields more coverage and more cost. If a
signal is monotone in its own knob, then it is not a quality signal at all — it is the knob wearing a
lab coat, and a gate built on it would approve "more" (or "less") forever without ever noticing
whether the prime got better.

This sweep varies ONE knob at a time and reports each signal's Spearman correlation with that knob
across the tasks. |rho| near 1.0 means the signal is a restatement of the knob.

Run:  python3 research/context-priming-master/phase0b_monotonicity.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from phase0 import PROFILES, REPO, SIGNALS, collect_tasks, load_rag, measure  # noqa: E402

# One knob at a time, holding the base profile's other three values fixed.
SWEEPS = {
    "max_wiki_pages": [2, 4, 8, 12, 16],
    "max_artifacts": [1, 2, 3, 4, 6],
    "chapter_chars": [400, 800, 1400, 2000, 2400],
    "hop_bonus": [0.0, 0.15, 0.35, 0.6, 0.9],
}


def spearman(xs: list[float], ys: list[float]) -> float:
    """Rank correlation, computed by hand: the engine is stdlib-only and so is this."""
    n = len(xs)
    if n < 3:
        return 0.0

    def ranks(vals: list[float]) -> list[float]:
        order = sorted(range(n), key=lambda i: vals[i])
        out = [0.0] * n
        i = 0
        while i < n:
            j = i
            while j + 1 < n and vals[order[j + 1]] == vals[order[i]]:
                j += 1
            avg = (i + j) / 2 + 1
            for k in range(i, j + 1):
                out[order[k]] = avg
            i = j + 1
        return out

    rx, ry = ranks(xs), ranks(ys)
    mx, my = sum(rx) / n, sum(ry) / n
    num = sum((a - mx) * (b - my) for a, b in zip(rx, ry))
    dx = sum((a - mx) ** 2 for a in rx) ** 0.5
    dy = sum((b - my) ** 2 for b in ry) ** 0.5
    return round(num / (dx * dy), 3) if dx and dy else 0.0


def main() -> int:
    rag = load_rag()
    tasks = collect_tasks(8)
    if not tasks:
        raise SystemExit("no tasks found")

    print(f"Phase 0b — is each signal just its knob? ({len(tasks)} tasks, {REPO.name})\n")
    print("Spearman rho between the knob's value and the signal, holding the other knobs at base.")
    print("|rho| >= 0.9 => the signal restates the knob; it cannot measure quality.\n")

    header = f"{'knob':<16}" + "".join(f"{n:>13}" for n, _, _ in SIGNALS)
    print(header)
    print("-" * len(header))

    tautological: dict[str, list[str]] = {}
    for knob, values in SWEEPS.items():
        row = f"{knob:<16}"
        for name, _, _ in SIGNALS:
            xs, ys = [], []
            for v in values:
                profile = dict(PROFILES["base"])
                profile[knob] = v
                vals = []
                for _, body in tasks:
                    try:
                        vals.append(float(measure(rag, body, profile).get(name) or 0.0))
                    except Exception:
                        continue
                if vals:
                    xs.append(float(v))
                    ys.append(sum(vals) / len(vals))
            rho = spearman(xs, ys)
            row += f"{rho:>13.3f}"
            if abs(rho) >= 0.9:
                tautological.setdefault(f"{knob} -> {name}", []).append(str(rho))
        print(row)

    print()
    if tautological:
        print(f"MONOTONE PAIRS ({len(tautological)}) — these signals are the knob, not quality:")
        for pair, rhos in sorted(tautological.items()):
            print(f"  {pair}   rho={rhos[0]}")
        print(
            "\nVerdict: the gate as designed is CIRCULAR. A signal that rises whenever the window\n"
            "widens will approve every widening and reject every narrowing, regardless of whether\n"
            "the prime became more useful. Do not build the learning loop on these signals."
        )
    else:
        print("No signal was monotone in any knob: they are measuring something other than the setting.")
        print("Phase 0's separation result therefore carries real information. Proceed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
