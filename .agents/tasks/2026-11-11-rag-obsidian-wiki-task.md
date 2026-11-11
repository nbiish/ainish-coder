# RAG wiki → Obsidian vault + plan-first gate

- **status:** done
- **branch:** `feat/rag-obsidian-wiki`
- **plan:** `.agents/plans/2026-11-11-rag-obsidian-wiki.plan.md`
- **scope:** `src/rag/src/wiki.rs`, `src/rag/rag.py`, `src/rag/src/main.rs`, `src/plan_gate.sh`,
  `bin/ainish-coder`, `src/help.sh`, `AGENTS.md`, `.gitignore`, `scripts/test-pqc-dist.sh`
- **objective:** make the generated wiki a real Obsidian vault without degrading agent retrieval,
  and make "plan before work, verify in a worktree, merge deliberately" an enforced rule instead of
  a paragraph agents skip.

## What was found

1. **The pages were not a vault.** No YAML frontmatter, no `[[wikilinks]]`, no tags, no aliases, no
   vault config — Obsidian showed six orphan files with an empty graph and no backlinks.
2. **The graph reader could not see wikilinks — this was the load-bearing find.** `build_wiki_graph`
   matched only `(path.md)` (`rag.py:5026`). Converting the pages to `[[...]]` without teaching the
   parser would have deleted every explicit edge and left retrieval on the weaker
   `shared terms >= 3` rule. The vault would have looked *better* in Obsidian while `--context`
   silently returned worse results. Verified directly: the old regex returns `[]` on a page whose only
   link is `[[03-security-and-governance]]`; the new extractor returns the target.
3. **`## Related` blocks would have become retrieval nodes.** Every `## ` heading becomes a node, so a
   cross-link section would compete with the content it links to.
4. **Decision providers are unauthorized.** Only two decisions-capable models exist
   (`openrouter/jev-1.14`, `zenmux/jev-1.14`) and both reject: OpenRouter 401 "User not found",
   ZenMux 403 payg. Chat *does* fail over correctly (asked for `zenmux-deepseek-v4.1-flash`, got
   `mimo-v2.6-pro`), so the chain works for chat and not for decisions.
5. **`ledger.sig` churned on every wiki run** — same content `sha256`, new `signed_at`, and on this
   host a different `public_key_fingerprint`. Pre-existing; exposed while verifying the ledger was
   untouched.

## What changed

- **Vault format (5.1/5.2/5.3):** every page carries frontmatter (`title`, `aliases`, `tags`, `up`,
  `generated`, `source_commit`, `decision_source`), uses `[[page|label]]` links, and ends with a
  `## Related` block. `.obsidian/` is written once and never overwritten — operator theme/graph state
  lives there.
- **Graph reader (5.0, done first):** `WIKILINK_RE` + `MDLINK_RE`, stem matching for wiki targets,
  `GRAPH_NAV_HEADINGS` skips navigation-only sections, and `_strip_code_spans` so prose that documents
  the syntax does not create a dangling edge. Both link syntaxes are parsed so old and new pages coexist.
- **Plan gate (5.8/5.9):** `--plan-check [DIR] [--json]` matches a plan to its branch via the plan's
  `branch:` key (never filename guessing) and refuses when the plan is absent or still `designing`.
  `--plan-gate-install` wires it as a pre-commit hook; `--plan-gate` is the hook-only entry point so
  the recorded bypass never masks an explicit check. `AGENTS.md` #1 now states the rule in 119 of its
  120 lines.

## Verification

- `cargo test --bin ainish-rag` → **58/58**, including the new
  `generated_vault_is_obsidian_native` (frontmatter keys, wikilinks, no dangling targets, ledger
  byte-identical, vault config not clobbered).
- `bash scripts/test-pqc-dist.sh` → **184/184**, including six plan-gate assertions covering both
  directions (refused without a plan, allowed with a ready one, wrong-branch rejected, main ungated).
- Live generation in this repo: **32 nodes, 236 edges, 0 dangling, 0 phantom `Related` nodes.**
- `ledger.md` byte-identical before/after; `ledger.sig` now stable across regeneration.
- Hook proven end-to-end on real `git commit`: refused, bypassed-with-notice, and allowed.

## Not done / deliberately deferred

- **Decision-driven salience (5.4/5.5) is not wired.** The code path is designed (advisory with a
  deterministic structural fallback, `decision_source` recorded) and every page currently reports
  `decision_source: structural`. Wiring it before the providers authorize would only produce a
  fallback that pretends to be a decision, which is the silent-downgrade failure mode this repo
  forbids. Do it once `jev-1.14` answers.
- Python parity (5.7): the Python generator still emits the old page format. `rag.py` received the
  *reader* half (wikilink parsing) because retrieval correctness depends on it; the *writer* half is
  the remaining work.
- `bin/ainish-rag-darwin` is a local 127 MB build product and is now gitignored.
