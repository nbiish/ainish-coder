2026-11-21-14-airpc-followups
# Follow-ups from the aiRPC skill work

1. **Project the manifest from `ainish-coder` itself.** Today the agent assembles the block
   manifest by hand (SKILL.md §4). A `ainish-coder --project <session>` (or a skill helper script)
   could walk the allowlisted record surface, split sections at headings, and emit the manifest
   with ids and digests already computed — removing the one step where a hand-rolled digest would
   silently diverge from the protocol. Settled when the operator asks for automation of projection.

2. **Build the canvas against a real scaffold once.** `references/canvas-app.tsx` is
   syntax-checked only (no tldraw scaffold on the host). The first agent to run
   `npm create tldraw@latest` and drop it in should fix any `ShapeUtil` API drift (the
   `getGeometry` placeholder is the most likely spot) and record the working scaffold version in
   the skill header.

3. **Distribution is deliberately untouched.** aiRPC ships only this repo's `.agents/skills/`.
   When the operator wants it in consumer repos, add it to `skills-to-distribute/skills/` — and
   decide then whether the bridge rides along as a reference file or becomes a shipped binary.
