#!/usr/bin/env python3
"""filter-repo --message-callback body: strip harness attribution from historical commits.

Run with:
    git filter-repo --refs <base>..HEAD --force \
        --message-callback "$(cat scripts/rewrite-msg-callback.py)"

WHY PYTHON AND NOT THE SHELL SCRIPT:
`filter-repo` calls this for every commit in one process, so a subprocess per commit would be slow,
and its `--message-callback` contract is a function body receiving `message` (bytes) and returning
bytes. The HARNESS TABLE is still the single source of truth — it is read from
`scripts/harness-attribution.txt`, the same file the commit-msg hook reads, so a harness added to the
table is stripped here too. Two lists would drift; that is exactly how a trailer survived the first
time.

It removes only lines the table recognises, and never touches `Signed-off-by:` (a DCO assertion the
operator makes) or a `Co-authored-by:` naming a person.
"""
import os
import re

# filter-repo INJECTS this file as a function body, so `__file__` does not exist here (measured: it
# raises NameError at the first commit). The table path is therefore passed in through the
# environment by the rewrite command, and falls back to the two places it can legitimately be.
_TABLE = os.environ.get("AINISH_HARNESS_TABLE") or os.path.join(
    os.getcwd(), "scripts", "harness-attribution.txt"
)


def _harness_fragments():
    frags = []
    try:
        with open(_TABLE, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split("|")
                if len(parts) >= 2 and parts[1].strip():
                    frags.append(parts[1].strip())
    except OSError:
        pass
    return frags


_FRAGS = _harness_fragments()
if _FRAGS:
    _HARNESS = "|".join(_FRAGS)
    # Attribution lines only. A prose sentence containing "cursor" is not attribution.
    _ATTR = re.compile(
        r"^[ \t]*(co-authored-by|generated-by|made-with|generated-with)[ \t]*:.*(" + _HARNESS + r")",
        re.IGNORECASE,
    )
    _FLOURISH = re.compile(
        r"^[ \t]*(🤖[ \t]*)?(generated|made)[ \t]+(with|by)[ \t]+(" + _HARNESS + r")[ \t]*$",
        re.IGNORECASE,
    )
else:
    # No table means no rewrite. Returning the message unchanged is the only honest answer: a
    # guessed pattern could strip a real collaborator.
    _ATTR = _FLOURISH = None


def _strip(message):
    if message is None:
        return b""
    if isinstance(message, str):
        message = message.encode("utf-8", "replace")
    if _ATTR is None:
        return message
    text = message.decode("utf-8", "replace")
    lines = text.split("\n")
    kept = [ln for ln in lines if not _ATTR.match(ln) and not _FLOURISH.match(ln)]
    if len(kept) == len(lines):
        return message
    # Collapse the trailing blank lines the removal leaves, but keep the subject's own spacing.
    while len(kept) > 1 and kept[-1] == "" and kept[-2] == "":
        kept.pop()
    while kept and kept[-1] == "" and len(kept) > 1:
        kept.pop()
        break
    return "\n".join(kept).encode("utf-8")


# filter-repo wraps this file as `def callback(message): <these lines>` and assigns the RESULT to
# `commit.message`, then runs its own hash-substitution over it. So the body must RETURN bytes — an
# assignment alone yields None and fails with "expected string or bytes-like object, got 'NoneType'"
# deep inside filter-repo, which reads like a filter bug rather than a missing return.
return _strip(message)  # noqa: F821
