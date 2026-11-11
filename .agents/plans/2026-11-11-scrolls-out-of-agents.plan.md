# Plan — move scrolls content out of `.agents/**`

**Goal:** `.agents/**` is the rules-and-orchestration surface that every agent reads. Scrolls are
specialty *deployable* payload for external publishing, not guidance for the ainish-coder rules tooling.
Nothing an agent reads to decide how to work should carry them; nothing that ships them should be
discoverable as context.

**Status:** proposed. Another agent is mid-move in the same tree (see *Coordination*).

## Why now

`--rules` deploys `.agents/skills/` packs and the selector enumerates them from disk. Scroll-channel
packs (`8thfire-scrolls`, `ghost-layer-injector`) are hard-excluded in `src/skills_selection.sh`, but
they still **exist on disk inside the directory that is enumerated**, so every selector run, every
`--skills-list`, and every index walk has to know about them to skip them. That exclusion is a
maintenance obligation, and it is the kind of exception that rots: one new code path that forgets to
exclude them puts adversarial-prompting payload in front of an agent as if it were a skill.

Moving them out makes the exclusion structural: `.agents/skills/` contains only things that may be
deployed as rules, so "is this scrolls?" stops being a question anyone has to ask.

## Target layout

| Today | After |
|---|---|
| `.agents/skills/8thfire-scrolls/` | `skills-to-distribute/scrolls/8thfire-scrolls/` |
| `.agents/skills/ghost-layer-injector/` | `skills-to-distribute/scrolls/ghost-layer-injector/` |
| `.scrolls/`, `.scrolls-ceremony/`, `.scrolls-prayer/`, `.scrolls-embodiment/` (repo root) | unchanged — already outside `.agents/` |
| `scripts/scrolls/` (tooling) | `scripts/scrolls/` — unchanged, it is tooling, not payload |
| `src/deploy_scrolls.sh`, `src/scroll_integrity.sh` | unchanged behavior, new source path |

Rationale for `skills-to-distribute/scrolls/`: the operator is already using `skills-to-distribute/`
for packs that deploy elsewhere, and one scrolls subtree there keeps "deployable but never context"
in one place.

## Steps

1. **Freeze the move.** One writer. Confirm the other agent's lane before touching
   `.agents/skills/**` — the working tree currently carries deletions there and
   `skills-to-distribute/skills/` is appearing; committing over that would bury their work.
2. `git mv .agents/skills/8thfire-scrolls skills-to-distribute/scrolls/8thfire-scrolls`
   and the same for `ghost-layer-injector`. `git mv` keeps history; a copy loses it.
3. Update the readers, each of which is a source of a silent break:
   - `src/deploy_scrolls.sh` — source path for the packs (it already reads `.scrolls` from repo root).
   - `src/scroll_integrity.sh` — its manifest expectations.
   - `src/skills_selection.sh` — the hard exclusion can become a path assertion, not a name match;
     keep the name match as a belt-and-braces guard.
   - `src/deploy_skills.sh`, `src/verify_skills.sh` — any literal pack names.
   - `llms.txt` line ~337 and the `.agents/llms.txt` child index — say where scrolls live now.
4. **Assert the invariant** in `scripts/test-pqc-dist.sh`:
   - nothing under `.agents/**` matches `*scroll*` or `ghost-layer*`;
   - `.agents/skills/` has no pack that `--scrolls` deploys;
   - a deployed rules tree contains zero scrolls bytes.
5. **Verify the channel still works**: `ainish-coder --scrolls` into a scratch dir produces the same
   files it did before the move (compare file lists and hashes), and `--skills-list` output is
   unchanged.
6. Re-sign the contract if `AGENTS.md`/`llms.txt` wording changes (`ainish-rag audit contract`), then
   `--machine-sync` so every machine carries the new layout.

## Acceptance

- `grep -r "scroll" .agents/` returns only prose that *points* at the channel, no payload.
- `ainish-coder --skills-list` never lists a scroll-channel pack, and the code path that would have
  needed an exclusion no longer runs.
- `ainish-coder --scrolls` still deploys byte-identically.
- The 120-line contract gate still passes; no new mandatory read for agents.

## Coordination

Do not commit `.agents/skills/**` deletions from this session — they are another agent's in-flight
distribution fix. Land the move as its own commit, after their logic change, or as one reviewed
change with them.
