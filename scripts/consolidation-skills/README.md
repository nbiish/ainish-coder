# Consolidation panel — four agents, four questions

These are the skills behind the four `hermes` profiles that consolidate a repository's coordination
records. They exist so the panel is reproducible: a profile is a thin shell, and the actual instructions
live here, in the repo, versioned with the code that calls them.

| Profile | Role | Its one question |
|---|---|---|
| `consolidate-elephant` | drafter | What happened in this period, and what does it amount to? |
| `consolidate-goldfish` | fidelity | Does the draft say anything the sources do not support? |
| `consolidate-archivist` | completeness | Is anything in the sources left out? |
| `consolidate-structural` | coherence | Does the draft hold together as one record? |

## Why three reviewers and not one

Each asks a question the others cannot. In live testing on this repository:

- **completeness** caught an escalated design question the draft had dropped — a decision waiting on the
  operator, which would have been lost permanently when the source was removed.
- **completeness** separately caught a PQC secrets-store incident where 24 keys dropped to 1, flagged
  "to report rather than fix", that the draft never mentioned.
- **fidelity** is what the single reviewer already did, and it caught a draft that asserted a conclusion
  the records did not carry.

Coherence is the one without a kill yet — and it is the one that matters most for a digest, because a
list of true facts that never says what they amount to is still a bad record.

## The rule all four share

If you cannot answer your question — the sources are absent, the draft is unreadable, something you need
was not supplied — answer `VERDICT: fail` with the reason. **Never pass something you could not read.**
The gate treats an unparseable reply as a refusal for exactly this reason: silence is not assent, and the
sources are deleted after this.

## Installing

`ainish-coder --rules` creates the four profiles if absent, sets their descriptions, and copies these
skills into place. A repository that already has them is left alone.
