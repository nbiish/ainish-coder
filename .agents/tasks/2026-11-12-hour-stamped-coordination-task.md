# Hour-stamped coordination records

- **status:** done
- **branch:** `fix/hour-stamped-coordination`
- **plan:** `.agents/plans/2026-11-12-hour-stamped-coordination.plan.md`
- **worktree:** `/Users/nbiish/code/ainish-coder-hourcoord`
- **operator ask:** "Review the latest plan and let's proceed to get that implemented."
- **scope:** `AGENTS.md`, `.agents/{plans,llms.txt,templates,memories}/llms.txt`, `.agents/templates/plan.md`,
  `.agents/skills/question-me/SKILL.md` + `skills-to-distribute/skills/question-me/SKILL.md`,
  `llms.txt`, `README.md`, `src/README.md`, `src/templates/AGENTS.COMMS.md`, `.gitignore`,
  `src/plan_gate.sh`, `src/deploy_agents_comms.sh`, `src/scroll_integrity.sh`, `src/help.sh`,
  `bin/ainish-coder`, `bin/git-context.sh`, `bin/security_gate.py`, `bin/context-packet.sh`,
  `src/rag/rag.py`, `src/rag/src/{wiki.rs,main.rs}`, `src/rag/tests/*.py`,
  `scripts/test-pqc-dist.sh`

## What was found in review (2026-11-12)

1. **The plan edited the engine that is not running.** It scoped §3 to the Rust crate
   (`src/rag/src/`). `bin/ainish-rag:69` hard-codes `PY_ONLY_SUBCOMMANDS=" context secrets "`, and
   no native binary exists in `bin/`, so `rag.py` is the engine that serves every `context` call.
   The context call opening this task proved it: its warning strings exist only in `rag.py`.
   Operator chose "amend the plan first" over implementing the Rust-only version.
2. **"Newest wins" was name-sorted, not mtime-sorted** at `rag.py:5564`, `rag.py:5870`,
   `main.rs:3637-3640`. Under grandfathering both schemes coexist for a UTC day, and
   `…-09-memory.md` collates before `…-memory.txt`, so the grandfather file wins. The plan's
   central invariant would have been false on exactly the days it matters.
3. **Dropping the `.plan.md` suffix blinded plan discovery** in three places
   (`rag.py:5897`, `plan_gate.sh:63`, `context-packet.sh:70`). The plan-gate would have refused
   every commit on every new-scheme branch with "no plan of record".
4. **Eight unlisted surfaces** hard-matched `-team.txt` / `-task.md` / `.plan.md`:
   `bin/git-context.sh`, `bin/security_gate.py`, `bin/context-packet.sh`,
   `src/templates/AGENTS.COMMS.md`, `.agents/memories/llms.txt`, `.agents/templates/llms.txt`,
   `src/rag/tests/*.py`, `.gitignore`.
5. **`_read_today_task_record` (`rag.py:7257`) is already dead** — it looks for
   `{date}-task.md`, a name the old scheme never produced. Repaired as part of this task.
6. **Pre-existing `--rules` failure** at the deploy-time signing gate (signer `69e7233d…` vs
   committed anchor `d98405ea…`), recorded in
   `.agents/suggestions/2026-11-12-rules-signing-anchor-mismatch.txt`. Verification records a
   baseline so this task's delta is measurable.

## Correction (operator clarification, 2026-11-12)

The operator stated the project no longer uses the embedding model and has switched entirely to an
LLM-based wiki/retrieval system over a local DB plus the Obsidian vault and `.agents/` context
folders. Verified against the code, that is **half true**, and the half that isn't is a bug:

- **Retrieval already matches the description.** `graph_retrieve` returns `wiki_graph_empty` unless
  `AINISH_RAG_VECTOR_FALLBACK=1`; the vector path is opt-in and the graph over the vault +
  `.agents/{comms,memories,plans,suggestions,tasks}` is the engine. No embedding model in the
  default path.
- **The wiki generator did not match it, and was actively destructive.** The Obsidian renderer lives
  only in `src/rag/src/wiki.rs` (`WIKI_TAGS_ROOT = "ainish/wiki"`, frontmatter template, wikilink
  emission). `src/rag/rag.py` has **zero** `ainish/wiki` occurrences — it writes plain markdown. Both
  answer `ainish-rag`, and the launcher routes plain invocations to Python, so the reachable `wiki`
  command replaced a vault with non-vault pages: frontmatter, aliases, tags and every `[[wikilink]]`
  gone, while reporting success. Measured: committed `README.md` had 11 wikilinks, after
  `ainish-rag wiki --no-index` it had 0, and page 01 lost its frontmatter entirely.
- **Indexing was also unavoidable.** Rust declared `#[arg(long, default_value_t = true)] index: bool`,
  which in clap 4 is a flag that can only ever be true — `--index false` / `--index=false` both fail —
  so every wiki run hard-required the missing EmbeddingGemma GGUF. Python had the inverse:
  `--no-index` with indexing on by default.

Fixed in this task: `generate_wiki` now detects `ainish/wiki`-tagged pages and **refuses** rather
than downgrading them (5 tests, all failing against `main`); `--index` is opt-in in both engines;
the vault title now names the project via `origin` instead of the worktree directory (it was baking
`ainish-coder-hourcoord` into tracked pages); the generator's "automatically indexed into LanceDB"
prose and the PRD's embedding claims are corrected. The vault regenerates cleanly on this host now —
content-only diffs, 11 wikilinks intact, operator ledger preserved on page 04.

Still open and recorded, not fixed: the vault *writer* remains native-only, so the reachable engine
cannot generate a vault it doesn't already have (`.agents/suggestions/2026-11-12-rag-engine-authority-unstated.md`),
and seven other flags share the clap `default_value_t = true` defect
(`.agents/suggestions/2026-11-12-clap-bool-default-true-flags.md`).

Also fixed while verifying: `.gitignore` matched only `*-team.live.*`, so `.live` boards with a
different prefix (`{date}-identity-guard.live.txt`) were committable — one already is on `main`.
Now `*.live.{txt,md}`.

## What changed

1. **Naming contract** — `AGENTS.md` NN1/NN8/Close state the `{date}-{HH}-{slug}.md` convention and
   that pre-2026-11-12 names stay valid (159 lines, under the 160 gate). `.agents/plans/llms.txt`
   gained the two-scheme table and the mtime rule; the plan template, `question-me` (both copies,
   byte-identical), `.agents/{llms,templates/llms,memories/llms}.txt`, root `llms.txt`, `README.md`,
   `src/README.md`, `src/templates/AGENTS.COMMS.md`, and `typesafe-jev`'s record step follow.
   `.gitignore` ignores the live board in both schemes.
2. **Engine** — `src/rag/rag.py` gained one shared resolver (`_coordination_files` plus
   `_memory_files` / `_task_files` / `_plan_files` / `_comms_files`) that matches both schemes and
   orders by mtime. Rewired: memory discovery, memory creation, memory cross-link, task discovery
   (×2), plan discovery, today's COMMS, COMMS discipline check. `_read_today_task_record` was dead
   (it looked for `{date}-task.md`, a name the scheme never produced) and now reads today's newest
   real record. `src/rag/src/{main.rs,wiki.rs}` mirror the same predicates and mtime ordering.
3. **Shell tooling** — `plan_gate.sh` matches any `.md` except `llms.txt` instead of `*.plan.md`;
   `deploy_agents_comms.sh` writes `-team.md` and adopts a legacy `-team.txt`; `scroll_integrity.sh`
   does the same and uses a `.live.md` board; `git-context.sh`, `context-packet.sh` (plan *and*
   memory discovery) and `security_gate.py` accept both suffixes; `bin/ainish-coder` and `src/help.sh`
   prose updated.
4. **Tests** — `scripts/test-pqc-dist.sh` pins updated; new assertions cover the plan gate on
   new-scheme plans (accept ready, refuse designing, ignore the index), comms deploy writing `.md`
   with legacy adoption, and the engine predicates. `src/rag/tests/test_context_injection.py` gained
   5 tests; 4 of them fail against `main`'s engine, so they are real regressions and not decoration.

## Verification

| Gate | Baseline | After |
|---|---|---|
| `scripts/test-pqc-dist.sh` | 239 PASS | **258 PASS** |
| `src/rag` pytest | 179 passed | **189 passed** |
| `cargo test --release` | 58 passed | **59 passed** |
| plan gate on this branch (dogfood) | — | passes on its own grandfathered `.plan.md` |
| plan gate, new-scheme-only probe repo | — | passes (`2026-11-13-00-probe.md`) |
| `ainish-rag --context`, mixed-naming probe | — | resolves new-scheme plan, task, COMMS `.md` |
| memory newness, same probe tree | old engine → stale grandfather bullet | new engine → fresh hour-stamped bullet |
| `--rules` into a fresh target | `2026-11-12-team.txt` | `2026-11-12-team.md` |
| `ainish-rag wiki` on a vault repo | stripped frontmatter + all 11 wikilinks | refuses; vault byte-identical |
| `ainish-rag wiki` (native, no embedder) | hard-failed on missing GGUF | generates the vault, 11 wikilinks intact |
| vault title in a worktree | `ainish-coder-hourcoord` | `ainish-coder` (from `origin`)

`bash -n` on every touched script; `python3 -c ast.parse` on `rag.py` and `security_gate.py`.

## Not verified, and why

- **`--rules` still exits 1** at the deploy-time signing gate (local signer `69e7233d…` vs committed
  anchor `d98405ea…`) — reproduced on `main`, recorded in
  `.agents/suggestions/2026-11-12-rules-signing-anchor-mismatch.txt`. Not this task's delta.
- **`.agents/canonical/` not re-signed.** It already lagged `AGENTS.md` at HEAD (pristine HEAD tree
  fails `security_gate.py` too). The `--rules` run re-signed it with the non-anchor signer; that was
  reverted. Re-signing needs the anchor rotation, an operator decision.
- **Wiki regenerated with the NATIVE engine, not `rag.py`.** `rag.py` still cannot write a vault
  (it now refuses instead of destroying one), so the committed pages came from
  `src/rag/target/release/ainish-rag wiki`. That is the honest current split; see the suggestion.

## Expected first failure if this is wrong

A reader that filters on one suffix matches nothing and reports "no plan of record" / "none" rather
than erroring — that is the silent-failure shape of this change. The guards are the new-scheme plan
probe, the `.md`-only probe repo, and the four Python tests that fail on `main`.
