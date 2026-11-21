2026-11-21-14-airpc-followups
# Follow-ups from the aiRPC skill work

1. **Project the manifest from `ainish-coder` itself.** Today the agent assembles the block
   manifest by hand (SKILL.md §4). A `ainish-coder --project <session>` (or a skill helper script)
   could walk the allowlisted record surface, split sections at headings, and emit the manifest
   with ids and digests already computed — removing the one step where a hand-rolled digest would
   silently diverge from the protocol. Settled when the operator asks for automation of projection.

2. **Build the canvas against a real scaffold once.** ~~`references/canvas-app.tsx` is
   syntax-checked only (no tldraw scaffold on the host).~~ **Resolved 2026-11-21** — built and
   browser-verified against tldraw 5.6.2: the v5 `ShapeUtil` contract had replaced `indicator()`
   with `getIndicatorPath(): Path2D`, which the operator's console caught as
   `getIndicatorPath is not a function`; fixed against the installed package's `.d.ts`, and the
   version is now pinned in the skill and the module header.

3. **Distribution is deliberately untouched.** aiRPC ships only this repo's `.agents/skills/`.
   When the operator wants it in consumer repos, add it to `skills-to-distribute/skills/` — and
   decide then whether the bridge rides along as a reference file or becomes a shipped binary.
