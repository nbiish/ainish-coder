---
title: Codebase Connections & Symbols
aliases: ["connections", "symbols", "calls"]
tags: [ainish/wiki/connections, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-28T15:35:00+00:00
source_commit: e0ff062
decision_source: hermes-reviewed
---
# 02. Codebase Connections & Symbols — ainish-coder

## 1. Component Linkage & CLI Dispatch
`ainish-coder` separates thin CLI dispatch (`bin/`), POSIX shell deployment modules (`src/*.sh`), and the stdlib-only Python context/federation engines (`src/context/engine.py`, `src/federation_pqc.py`):

- **CLI entrypoints (`bin/`):**
  - `bin/ainish-coder` (+ `.cmd`) — routes `--rules*`, `--skills*`, `--select-skills`, `--llms-txt`, `--context*`, `--pqc-*`, and `--machine-*`.
  - `bin/ainish-context` (+ `.cmd`) — invokes `src/context/engine.py` across `context`, `context-digest`, `context-consolidate`, `context-wiki-review`, `context-setup`, `context-seed|status|learn|rollback|promote|skill`, `wiki`, `route`, `decide`, `eval`, `orient`, `gate`, `audit`, `secrets`.
  - `bin/pqc-secrets` (+ `.cmd`) — dispatches FIPS 203/204 secrets operations to the canonical Python engine or darwin/arm64 fast-path.
- **Rules & Skills shell layer (`src/`):**
  - Core utilities: `runtime.sh` (native Windows/POSIX path + Python shims), `paths.sh` (`AINISH_SKILLS_SOURCE_REL` / `AINISH_SKILLS_TARGET_REL`), `config.sh`, `help.sh`, `colors.sh`, `file_operations.sh`, `file_utils.sh`, `backup.sh`, `agents_protection.sh`.
  - Rules deployment & fleet sync: `deploy_agents.sh`, `deploy_rules_sync.sh`, `deploy_agents_comms.sh`, `deploy_agents_federation.sh`, `deploy_llms_txt.sh`, `deploy_gitignore.sh`, `deploy_license.sh`, `deploy_github_actions.sh`, `deploy_local_security.sh`, `deploy_commands.sh`, `deploy_mcp.sh`, `deploy_mcp_recipes.sh`, `clear_all_rules.sh`.
  - Skills selection & verification: `deploy_skills.sh`, `skills_selection.sh` (`_skill_mandatory` single source of truth), `verify_skills.sh`; distributable payload lives in `skills-to-distribute/skills/`.
  - Federation & PQC distribution: `machine_sync.sh`, `machine_watch.sh`, `pqc_dist.sh`, `src/federation_pqc.py`.

## 2. Context Engine (`src/context/engine.py`) Key Symbols
- **Prime assembly:** `run_context_command`, `DecisionEngine.route`, `retrieve_context`, `graph_retrieve`, `render_orientation_section`, `render_retrieval_section`, `elephant_synthesize`, `goldfish_review`, `assemble_injection`, `render_injection_text`.
- **Consolidation & digest curation:** `folder_census`, `run_context_consolidate`, `spawn_consolidate`, `run_context_digest` (`--review`/`--check`/`--uncheck`/`--prune`), `_parse_digest_items`, `_update_digest_frontmatter`.
- **Living wiki & graph:** `generate_wiki`, `run_wiki_review`, `_wiki_evidence_bundle`, `_validate_wiki_page_draft`, `build_wiki_graph`, `load_wiki_graph`.
- **Context harness (`src/context/context_harness.py`):** `seed`, `status`, `settings_for`, `load_profile`, `acquire_lock`, `release_lock`.

## 3. Cross-Cutting Concerns
- **Rules & Skills Fleet Sync:** `--rules` writes `.agents/ainish-deploy.json` (ML-DSA-65 signed), installs `.agents/bin/ainish-rules-sync` + post-merge/post-checkout hooks, and registers targets in `~/.config/ainish-coder/targets.txt`; `--rules-sync --all` propagates root contract updates automatically.
- **Skills Payload Split:** `skills-to-distribute/skills/` holds the distributable catalog (`--rules` / `--skills-sync` source); this repo's own `.agents/skills/` carries only the curated packs needed locally (`ainish-security`, `pqc-secrets`, `question-me`).
- **Consolidation & Digest Loop:** background `--context` sweeps compact aged `.agents/{comms,memories,plans,suggestions,tasks}` files into `consolidates.{naming}.md` while protecting the 3 newest originals; `--context-digest` lets operators review, check off (`- [x]`), and fail-closed prune digest entries.

## Related
[[01-architecture]], [[03-security-and-governance]], [[04-improvements-and-debt]], [[05-research-and-intelligence]], [[06-marketing-and-positioning]]
