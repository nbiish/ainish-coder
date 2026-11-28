# Task: Refactor `.agents/wiki/` to Focus Solely on `ainish-coder` Tooling

- status: done
- scope: `.agents/wiki/{README,01..06}.md`, `src/context/engine.py`, `llms.txt`, `src/context/tests/test_context_injection.py`
- objective: Refactor `.agents/wiki/` to focus strictly on `ainish-coder` `--rules`/`--skills`/`--context`/`--context-digest`/`--machine-sync`/`pqc-secrets` tooling, remove all scrolls/easter-egg mentions, and add fail-closed scrolls exclusion to wiki review/evidence generation.
- branch: `refactor/wiki-tooling-focus`
- worktree: `/Users/nbiish/code/ainish-coder-wiki-focus`
- plan: `.agents/plans/2026-11-28-15-wiki-tooling-focus.md`
- verification:
  - `grep -rn -i "scroll\|syllabic\|8thfire\|ghost.layer\|cultural/philosophical" .agents/wiki/` -> 0 matches (`ZERO_SCROLLS_IN_WIKI`)
  - `.agents/wiki/ledger.md` and `.agents/wiki/ledger.sig` untouched (0 diff)
  - `python3 -m unittest src/context/tests/test_context_injection.py src/context/tests/test_wiki_graph.py src/context/tests/test_federation_pqc.py src/context/tests/test_jev_decisions.py src/context/tests/test_redact_check.py`: 171/171 OK
  - `./bin/ainish-coder --context --retrieval-only "how do --rules, --skills-sync, and --context-digest work together"`: exit 0, `790/1200 tok | degraded=false`, top 6/8 retrieval hits from refactored `.agents/wiki/` pages
- rebuild_verdict: no-rebuild-needed
