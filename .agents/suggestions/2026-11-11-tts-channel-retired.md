# Spoken-suggestion channel retired; its content moved into `.agents/`

**Decision (operator, 2026-11-11).** The end-of-turn spoken-suggestion step is retired. TTS now has
exactly two uses: **distributing the pack**, and **configuring an agent harness** (Hermes and peers) to
use its own in-tool TTS for the operator's current coding preferences. Nothing calls a TTS binary as part
of ordinary work, and no turn ends with a synthesised suggestion.

**The content survived the tool.** The old master suggestions that lived inside the pack are now ordinary
`.agents/` context — `memories/`, `suggestions/`, `tasks/`, `templates/` — which `ainish-rag --context`
already reads as its newest-artifact corpus. A strict improvement: the same guidance now reaches an agent
through the retrieval path, in text, with no synthesis step, playback dependency, or transcript in the
repository root.

**Removed:** the 564-line transcript from the repository root; the pack entry in `src/help.sh`; the TTS
row and tree entry in `README.md`; the pack name in `llms.txt`'s `--skills-sync` example; every pack-name
reference outside the distribution folder.

**Kept:** the pack itself, under `skills-to-distribute/`. That folder is the only place the name belongs —
it is a thing that gets deployed to a machine, not a thing this repository runs.

**Forward rule:** anything worth carrying to the next session is a dated file under
`.agents/suggestions/` (gaps, decisions, next steps), or a task record once acted on. Do not reintroduce
a generated transcript.
