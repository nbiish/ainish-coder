#!/usr/bin/env python3
"""Decide a cargo-audit result, and never let "the tool broke" pass as "the code is safe".

This exists because the first version of this check lived as an indented heredoc inside
`.github/workflows/security.yml`. A YAML `run:` block indents every line of its script, so the Python
heredoc arrived with a leading indent, raised `IndentationError` on line 1, printed nothing, and the
surrounding shell read that empty output as "unparseable" — which the workflow treated as a benign
tool error and **exited 0**. Meanwhile `cargo audit` was reporting a genuine vulnerability
(RUSTSEC-2026-0385, `ctutils` 0.4.2, non-constant-time mask generation). A fail-open gate on a
cryptography crate is the worst possible place to be wrong.

Two lessons are encoded here:
  1. A check that cannot read its input must FAIL, not warn-and-pass. "Tool error" is a third state
     and it must be non-zero, because nobody investigates a warning.
  2. Output that cannot be parsed is a BUG IN THIS SCRIPT, not a property of the repository. It is
     reported as such instead of being blamed on upstream.

Usage:  python3 check_cargo_audit.py <audit-json-path>
Exit:   0 clean, 1 vulnerable, 2 could-not-determine (fail closed)
"""

from __future__ import annotations

import json
import sys


def _load(path):
    """Parse the audit JSON, tolerating a non-JSON preamble.

    `cargo audit --json` writes pure JSON to stdout, but a caller may merge stderr into the same
    stream. Rather than trusting the caller, find the first `{` and parse from there — a leading
    warning line must not be able to masquerade as "no data".
    """
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            raw = fh.read()
    except OSError as exc:
        return None, "could not read %s: %s" % (path, exc)
    raw = raw.strip()
    if not raw:
        return None, "audit output is empty"
    start = raw.find("{")
    if start < 0:
        return None, "audit output contains no JSON object"
    try:
        return json.loads(raw[start:]), ""
    except ValueError as exc:
        return None, "audit output is not valid JSON: %s" % exc


def main(argv):
    if len(argv) != 2:
        print("usage: check_cargo_audit.py <audit-json-path>", file=sys.stderr)
        return 2

    doc, err = _load(argv[1])
    if doc is None:
        print(
            "::error::could not determine audit status — %s. Failing closed: an audit result that "
            "cannot be read is not a passing result." % err,
            file=sys.stderr,
        )
        return 2

    # A database complaint inside otherwise-valid JSON still means the tool could not do its job.
    dbg = doc.get("database")
    if isinstance(dbg, dict) and dbg.get("error"):
        print(
            "::error::cargo-audit could not load its advisory database: %s. Failing closed — a "
            "broken database must not read as a clean dependency tree." % dbg["error"],
            file=sys.stderr,
        )
        return 2

    vulns = doc.get("vulnerabilities") or {}
    found = vulns.get("found")
    count = vulns.get("count")
    if isinstance(count, int) and not isinstance(count, bool):
        n = count
    elif isinstance(found, bool):
        n = len(vulns.get("list") or []) if found else 0
        if found and n == 0:
            n = 1
    else:
        print(
            "::error::cargo-audit output has no recognizable `vulnerabilities` shape; failing "
            "closed rather than guessing that it is clean.",
            file=sys.stderr,
        )
        return 2

    if n > 0:
        ids = []
        for item in vulns.get("list") or []:
            adv = (item or {}).get("advisory") or {}
            pkg = (item or {}).get("package") or {}
            name = pkg.get("name") if isinstance(pkg, dict) else None
            ver = pkg.get("version") if isinstance(pkg, dict) else None
            label = adv.get("id") or "advisory"
            if name:
                ids.append("%s (%s %s)" % (label, name, ver or "?"))
            else:
                ids.append(label)
        detail = ", ".join(ids) if ids else "%d advisory/ies" % n
        print("::error::cargo-audit reports %d vulnerable dependency/ies: %s" % (n, detail), file=sys.stderr)
        return 1

    lock = doc.get("lockfile") or {}
    print("OK: no known vulnerabilities (%s dependencies checked)" % lock.get("dependency-count", "?"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
