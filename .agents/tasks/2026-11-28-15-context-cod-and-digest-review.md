# Task: CoD Context Output Concision & Consolidates Digest Review/Prune

- status: done
- scope: `src/context/engine.py`, `bin/ainish-coder`, `src/context/tests/test_context_injection.py`, `.agents/jobs/consolidate-record.md`, `llms.txt`
- objective: Make `ainish-coder --context` output concise and Chain-of-Draft-like (fixing orientation truncation, retrieval starvation, goldfish token_cap enforcement, envelope chrome bloat, and non-interactive PQC TTY hang) and add `context-digest` tooling to review, check off, and safely prune `consolidates.*.md` digests.
- branch: `feat/context-cod-and-digest-review`
- worktree: `/Users/nbiish/code/ainish-coder-cod-context`
- plan: `.agents/plans/2026-11-28-15-context-cod-and-digest-review.md`
- verification:
  - `bash -n bin/ainish-coder`: exit 0
  - `python3 -m unittest src/context/tests/test_context_injection.py src/context/tests/test_wiki_graph.py src/context/tests/test_federation_pqc.py src/context/tests/test_jev_decisions.py src/context/tests/test_redact_check.py`: 170/170 OK (without `AINISH_RAG_NO_PQC=1`)
  - Pre-existing baseline failure noted: `test_gate_ready.MasterSurfaceLensesTest.test_shared_rules_file_is_loaded_and_strip_ansi` fails identically on `main` (`38343fdf`)
  - Live `./bin/ainish-coder --context "how can we review, check off, and remove content from the consolidates.{date}.md docs in the .agents/{context folders}/ content"`: exit 0, `974/1200 tok | degraded=false`, zero TTY hang, full CoD orientation + 8-file retrieval pointers + CoD elephant + bounded CoD goldfish
  - Live `./bin/ainish-coder --context-digest --review --folder plans`: exit 0, listed 36 open items with stable `plans:<n>` IDs
- rebuild_verdict: no-rebuild-needed
