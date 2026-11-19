# YOUR JOB

Improve the retrieval harness of a repository's context-priming tool so that the NEXT agent working
in this repository gets a better prime than you did.

You are NOT solving the task in the message. You are editing how the tool chooses what to show.

# THE EVIDENCE IS IN THIS MESSAGE

You have no file tools. The task, the current tuning, and every retrieved item are reproduced below,
in full. Work only from what is here.

# WHAT YOU MAY CHANGE

Only two things, and both are data:

1. The `graph` numbers — `max_wiki_pages` (0-64), `max_artifacts` (0-64), `chapter_chars` (400-2400),
   `hop_bonus` (0.0-1.0), `recency_floor` (0.0-0.95), `shared_term_threshold` (2-8) — and up to 12
   short `[a-z0-9_-]` terms per key in `domain_prior`. A `domain_prior` term promotes retrieved items
   whose text contains it. It cannot add evidence that is not already in the corpus.

   **`0` MEANS "INDEX EVERYTHING", NOT "index nothing".** For `max_wiki_pages` and `max_artifacts`,
   `0` is the widest setting, not the narrowest. Do not propose `0 -> N` to "fix" it: that would cap
   a corpus that is currently read in full, and the gate refuses it. Raise a cap only to widen, and
   prefer leaving both at `0` unless the evidence names a specific crowding problem.

2. A skill, as `skills/learned-<name>/SKILL.md` (+ optional `scripts/*.py`). Skills are ON DEMAND:
   they cost nothing until invoked, which is why they are the preferred form. Frontmatter needs
   `name:` matching the directory and `description:`.
   Add one ONLY when the evidence shows a procedure that recurred, or that will obviously recur, and
   that a later task could invoke on demand. Name it `learned-<what it does>` (lowercase, digits, `_`
   or `-`). The always-on prime is never the place for it.

# WHAT YOU MAY NOT DO

- No rule that applies on every run. Always-on text is paid on every call and is the failure this
  design exists to avoid.
- No credentials, no URLs, no shelling out, no dynamic execution.
- Do not name any evaluation criterion, metric, score, threshold, or signal. You have not been told
  how this harness is judged, and you must not guess at it.

# THE HONEST OPTION

If the evidence does not argue for a change, say so. A no-op is a real, expected, and frequently
correct answer: an edit the evidence does not support costs context and buys nothing.

# OUTPUT — exactly these three blocks, and NOTHING else

    <edits>
    {"graph": {"hop_bonus": 0.42}, "domain_prior": {"codebase_symbols": ["header"]}}
    </edits>
    <skill name="learned-parser-notes">
    ---
    name: learned-parser-notes
    description: Read the sixteen-byte header before any field access.
    ---

    The header carries the magic number and version; read it first.
    </skill>
    <why>
    for each change, the specific retrieved item that motivated it, named by its path
    </why>
    <kept>no</kept>

A `<skill name="...">` body is LITERAL TEXT — no escaping, no JSON. Include at most 3 skills total
across generations. Omit the `<skill>` blocks entirely when no skill is warranted.

Reply with `<edits></edits><why></why><kept>yes</kept>` when you are keeping the harness as it is.
Do not describe what you are about to do. Do not begin with a preamble. Emit only the blocks.
