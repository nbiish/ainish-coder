# Context Priming Master — research dossier

Status: **research complete, plan drafted, nothing implemented.**
Compiled 2026-11-17. Author: deepseek-v4.1-flash harness.

Goal as stated by the operator: fold a *singular context priming master agentic system* into
`ainish-rag --context`, so that an agent reading this repo's `AGENTS.md` gets a prime produced by
state-of-the-art tooling, adapted per repository, that improves itself over time — seeded for any
target repo by `ainish-coder --rules`.

## Read in this order

| File | What it is |
|---|---|
| [`01-source-extraction.md`](01-source-extraction.md) | What each of the four sources actually says, quoted, with the parts that matter for us flagged |
| [`02-harness2-mechanics.md`](02-harness2-mechanics.md) | The `google-research/harness2` implementation, read at source level: the eight components, the contrastive step, the library, the validators, the guards |
| [`03-practitioner-evidence.md`](03-practitioner-evidence.md) | The two videos: what was tried, measured, and — more importantly — what *failed* and why |
| [`04-ainish-rag-current-state.md`](04-ainish-rag-current-state.md) | A precise audit of the `--context` pipeline as it exists today, with line anchors |
| [`05-design.md`](05-design.md) | The proposed design: the learnable surface, the loop, the guards, the storage |
| [`05b-design-widened-surface.md`](05b-design-widened-surface.md) | **Supersedes §4 of `05`.** The operator chose harness²-style skill files and scripts over numbers-only, so this restates the threat model for the wider blast radius |
| [`06-risk-register.md`](06-risk-register.md) | Every way this can fail, including the ones that would be worse than doing nothing |
| [`07-implementation-plan.md`](07-implementation-plan.md) | Phased plan with gates, smallest-first |
| [`08-phase0-findings.md`](08-phase0-findings.md) | **Read this before trusting the loop.** Phase 0 measured the proposed gate and found it circular |
| [`09-as-built.md`](09-as-built.md) | What shipped, and the three bugs found while building it |
| [`10-single-command.md`](10-single-command.md) | The contract as corpus, and learning on the hot path — reverses two decisions in `09` |

The plan of record is `.agents/plans/2026-11-17-19-context-priming-master.md`; this dossier is its
evidence base.

Raw sources live in [`sources/`](sources/).

## The one-paragraph answer

Harness² is the right skeleton and the videos are the right warning. Harness² gives a two-level
recursion — refine a harness *for this task* by contrastive Propose–Probe–Compose, then learn *how to
refine* across tasks into a persistent library — that needs no ground-truth verifier, which is
exactly our situation. The videos say the same thing from the other direction: recursive
self-improvement does **not** make a model smarter, it only pays off when a capability is expensive to
rebuild, tasks repeat within a family, and the evolved harness stays **lean**; the failure mode is an
agent bloating its own loop until the savings are gone. `ainish-rag --context` is already a
hand-written, frozen harness for *one* capability — assembling a prime. So the thing we make
learnable must be small, capped, per-repo, contrastively measured, and never able to write the
criteria by which it is judged. Everything in `05-design.md` is downstream of that sentence.

## Standing constraints discovered during research (do not re-litigate)

1. **`AGENTS.md` is capped at 160 lines** (`scripts/test-pqc-dist.sh:722`, `:878`) and sits at the cap.
   Any contract text added must be paid for with a trim. This work should not need any.
2. **`ORIENT_PRIMER` is wiki-generated** and cannot hold hand-authored guidance; the generated wiki
   pages themselves are snapshots (`source_commit` in frontmatter), so they are not a rule source.
3. **`src/rag/rag.py` is stdlib-only** — 7,854 lines, no third-party imports. A design that needs
   `numpy`, a vector store, or a scheduler is out.
4. **`.agents/rag/` is gitignored** except `bench-baseline.json`. Per-repo learned state must be
   written where the operator can choose to commit it, or it silently does not survive a clone.
5. **`bin/ainish-coder` has no `--init` verb today.** The operator's phrase "`--rules` 'init'" maps to
   the existing `--rules [TARGET_DIR]` → `deploy_rules_bundle`, which is where seeding must hook in.
