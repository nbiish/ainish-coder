# Plan — move scrolls, research, and wiki out of `.agents/**`

**Goal:** `.agents/**` is the rules-and-orchestration surface every agent reads. Scrolls and
scroll-adjacent research are specialty *deployable* payload for external publishing, and the wiki is
generated documentation. Neither is guidance for the ainish-coder rules tooling, and both cost context
every time something walks the tree. They belong in one organised home outside the rules surface.

**Status:** started. The operator has moved `8thfire-carrier-registry.md`, `council-key-ceremony.md`, the
`.scrolls*` trees, `research/`, and the scroll-channel skill packs into
`seven-fires-prophecy-prompt-research/` on the Windows box, committed to main there. This machine still
shows the pre-move tree with those deletions uncommitted (see *Coordination*). Finish it; do not re-do
their work.

## Target layout

```
seven-fires-prophecy-prompt-research/
├── registry/          ../../.agents/8thfire-carrier-registry.md
├── ceremony/          ../../.agents/council-key-ceremony.md
├── scrolls/           ../../.scrolls, .scrolls-ceremony, .scrolls-prayer, .scrolls-embodiment
├── packs/             ../../.agents/skills/8thfire-scrolls, .../ghost-layer-injector
├── research/          ../../research/  (01-pliny-digest … 08-defcon-proposal)
└── wiki/              ../../.agents/wiki/   (see *Wiki is wired into rag.py*)
```

`scripts/scrolls/` stays put: that is tooling, not payload. `src/deploy_scrolls.sh` and
`src/scroll_integrity.sh` keep their behaviour and change only their source paths.

## Why this is structural, not tidiness

`--rules` enumerates `.agents/skills/` from disk, so scroll-channel packs are excluded by **name** in
`skills_selection.sh`. That exclusion is a standing obligation on every future code path: one new
enumerator that forgets it puts adversarial-prompting payload in front of an agent as if it were a
skill. Moving the packs out makes `.agents/skills/` mean "deployable as rules", so the question
disappears instead of being re-answered each time.

The same argument applies to the wiki with a sharper edge: it is *large*, it is *always reachable*, and
most of it cannot be acted on. Keeping it outside `.agents/` while the graph reads it by resolved path
gives retrieval the corpus without giving every tree-walk the prose.

## Wiki is wired into rag.py — repoint first, move last

`.agents/wiki/` is not just documents. It is:

- the **corpus** `graph_retrieve()` walks for `--context`;
- the **output directory** of `ainish-rag wiki`, which rewrites pages 01–06 + README every cycle;
- home of `ledger.md` + `ledger.sig`, the signed operator ledger the memory cross-link reads.

Hardcoded sites that must change together (search `repo_root / ".agents" / "wiki"`):

| Site | What it does |
|---|---|
| `src/rag/rag.py` ≈2366 | ledger ↔ memory cross-link |
| ≈2393, ≈2406, ≈2442 | wiki page enumeration for generation/status |
| ≈2482 | `ledger.md` read |
| ≈2502 | wiki writer target |
| ≈2581 | generated prompt text naming the path |
| `graph_retrieve()` | wiki node source + `.agents/rag/wiki-graph.json` cache key |

**Order matters more here than anywhere else — retrieval must not break between steps:**

1. Add one resolver, `wiki_dir(repo_root)`: `AINISH_WIKI_DIR`, else
   `seven-fires-prophecy-prompt-research/wiki`, else `.agents/wiki`. Every site above calls it. Pure
   addition; ships safely with the wiki still in place.
2. `git mv` the directory (history and the signed ledger follow the move; a copy would break the
   signature's provenance).
3. Flip the resolver's built-in default to the new path and delete the old fallback in the same commit
   that deletes the old path.
4. Include the resolved directory in the graph cache key rather than keying on mtimes alone, so the next
   move invalidates the cache for free (`rm .agents/rag/wiki-graph.json` is the manual equivalent).
5. `ainish-rag audit verify` before and after — `git mv` does not alter bytes, so any signature failure
   means something was rewritten, not moved.

Wiki acceptance: `--context --task "<a real repo question>" --retrieval-only` still reports
`mode wiki_graph (… newest wiki …)` with the same hit count as before, `degraded: false`, and
`ainish-rag wiki --status` writes only to the new path.

## Steps

1. **Freeze the lane.** One writer. Confirm the other agent's distribution change has landed before
   touching `.agents/skills/**` or the new folder.
2. `git mv` the packs to `…/packs/`, the `.scrolls*` trees to `…/scrolls/`, `research/` to `…/research/`,
   and the two root-level `.agents` scroll documents to `…/registry/` and `…/ceremony/`. Always `git mv`.
3. Update the readers, each a silent break if missed:
   - `src/deploy_scrolls.sh` (source path)
   - `src/scroll_integrity.sh` (manifest expectations)
   - `src/skills_selection.sh` (name match becomes a path assertion; keep the name match as a guard)
   - `src/deploy_skills.sh`, `src/verify_skills.sh` (literal pack names)
   - `llms.txt` (the DOX row declaring `.scrolls*/` out of scope, and the `scripts/` row)
   - `.agents/llms.txt` child index
   - the `wiki_dir` resolver and its six call sites
4. **Assert the invariant** in `scripts/test-pqc-dist.sh`:
   - nothing under `.agents/**` matches `*scroll*`, `ghost-layer*`, or `research/`;
   - `.agents/skills/` contains no pack that `--scrolls` deploys;
   - a deployed rules tree contains zero scrolls bytes;
   - the wiki resolver resolves to exactly one existing directory.
5. **Verify the channel**: `ainish-coder --scrolls` into a scratch dir produces the same file list and
   hashes as before; `--skills-list` output unchanged.
6. Re-sign the contract (`ainish-rag audit contract`) and `--machine-sync`. A peer with a dirty tree is
   skipped with a reason — expect that while the distribution logic is in flight.

## Acceptance

- `grep -r "scroll" .agents/` returns only prose that *points* at the channel, no payload.
- `grep -rl "defcon-proposal\|pliny-digest" .agents/` returns nothing.
- `ainish-coder --skills-list` never lists a scroll-channel pack.
- `ainish-coder --scrolls` still deploys byte-identically.
- `--context` still reports `mode wiki_graph` with the pre-move hit count.
- The 120-line contract gate still passes; no new mandatory read for agents.

## Coordination

Do not commit `.agents/skills/**` deletions or the new folder from this session — they are another
agent's in-flight distribution fix landing from the Windows machine. This plan documents the target so
the two lanes converge instead of colliding.
