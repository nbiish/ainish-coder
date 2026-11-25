---
plan_format: ainish/plan/v1
slug: agents-federation-cod
date: 2026-11-25
status: done
branch: feat/agents-federation-cod
worktree: /Users/nbiish/code/ainish-coder-worktrees/feat-agents-federation-cod
task_record: .agents/tasks/2026-11-25-13-agents-federation-cod.md
operator: direct
---

# Plan: Cross-Machine Chain of Draft (CoD) Federation Ledger & AGENTS.md Integration Reminder

## 1. Problem

Connected machines working on the same repository lack a dedicated, low-token `.agents/federation/{date}.md` ledger using Chain of Draft (CoD) communication to advertise in-flight branches, PRs, scope, and integration intent across peers. In addition, `AGENTS.md` does not concisely remind agents that other work beyond the current task may already exist as open PRs or branches, leaving agents without an explicit rule for deciding whether to fold work into the user's request/existing PR or open a new integration PR.

## 2. Anchor Facts

- `AGENTS.md` is held at a hard 160-line gate and currently sits at 160 lines — established from `AGENTS.md` and `scripts/test-pqc-dist.sh:751-756,924-925`.
- `scripts/test-pqc-dist.sh:1565-1568` pins folder naming in `AGENTS.md` (`tasks`, `plans`, `comms`, `memories`, `suggestions`, `wiki`), line `761` pins the exact `_tpl` loop string in `bin/ainish-coder`, and line `1429` pins `grep -c 'if not p.name.startswith(CONSOLIDATION_DIGEST_PREFIX)' src/context/engine.py == 2` — established from `scripts/test-pqc-dist.sh`.
- `.agents/comms/{date}-team.md` is deployed merge-safely via `src/templates/AGENTS.COMMS.md` + `src/deploy_agents_comms.sh` (`<PROTOCOL>...</PROTOCOL>` refresh, verbatim entry preservation) and declared in `managed_paths` in `src/deploy_rules_sync.sh:446-455` — established from `src/deploy_agents_comms.sh`, `bin/ainish-coder:275-300`, `src/deploy_rules_sync.sh`.
- `src/context/engine.py` indexes `GRAPH_ARTIFACT_DIRS = ("comms", "memories", "plans", "suggestions", "tasks")`, consolidates `CONSOLIDATION_FOLDERS`, guards append-only prefixes in `src/context/master-surfaces.json`, and builds the always-present `orientation` section in `render_orientation_section` — established from `src/context/engine.py:3693,5975-6118,6596,9123`.
- Editing root `AGENTS.md` requires syncing and ML-DSA-65 signing `.agents/canonical/AGENTS.md` (`AGENTS.md.sha256`, `AGENTS.sig`) via `snapshot_canonical_contract` / `ainish-context audit contract --threshold 1` — established from `src/agents_protection.sh:157-219` and commit `913555bc`.
- `ainish-coder --context` prompted interactively for a vault passphrase on this session and was terminated without blocking per `AGENTS.md`; orientation and repo state were verified directly from files and git (`main` and `origin/main` at `c8cb96a`, open PRs #13/#15 are unrelated license syncs).

## 3. Plan

### Goals

- Ship a standardized, append-only `.agents/federation/{date}.md` Chain of Draft (CoD) cross-machine ledger template (`src/templates/AGENTS.FEDERATION.md`), child DOX contract (`.agents/federation/llms.txt`), and merge-safe deployer (`src/deploy_agents_federation.sh`) wired into `ainish-coder --rules` and `managed_paths`.
- Update `AGENTS.md` (within the ≤160-line gate, re-signed canonically) to point at `.agents/federation/` and concisely remind every agent that other work beyond the task may exist as PRs or branches so the agent can decide whether to integrate into the user's request/existing PR or create a new integration PR.
- Wire `.agents/federation/` into `src/context/engine.py` (wiki graph, kind weights/intent, consolidation, append-only surface guard, `status`, and `render_orientation_section` surfacing recent CoD entries and active sibling/peer branches).
- Update DOX contracts (`.agents/llms.txt`, root `llms.txt`, `src/help.sh`, `src/README.md`) and add targeted unit + dist-suite assertions.

### Non-goals

- Changing `--machine-sync` git transport mechanics or auto-mutating `.agents/federation/{date}.md` inside commit hooks (federation entries are explicit CoD checkpoints authored by agents, not noisy per-save hook spam).
- Disturbing pre-existing dirty files on the main checkout.

### Constraints and invariants

- `AGENTS.md` must stay ≤160 lines, preserve every existing pinned phrase/check in `scripts/test-pqc-dist.sh`, name no model/provider/enforcement script, and be canonically signed with ML-DSA-65.
- `.agents/federation/{date}.md` is UTC-dated, append-only, merge-safe on `--rules` refresh, and treated as external data (never authorization).
- Preserve exact pinned lines in `bin/ainish-coder` (`DEPLOY_TMPL_LINE`) and `src/context/engine.py` (`CONSOLIDATION_DIGEST_PREFIX` grep count == 2).

### Proposed architecture

- `src/templates/AGENTS.FEDERATION.md` defines the `<PROTOCOL>...</PROTOCOL>` CoD schema (`### [<UTC>] <machine> | branch:<branch> | pr:<#N|none> | tip:<sha7> | state:<state>`, `- scope:`, `- cod:`, `- integrate:`).
- `src/deploy_agents_federation.sh` mirrors `src/deploy_agents_comms.sh` (UTC date, atomic temp write, `<PROTOCOL>` merge, entry-header preservation gate) and ships `.agents/federation/llms.txt`.
- `bin/ainish-coder` sources and invokes `deploy_agents_federation` inside `deploy_rules_bundle`; `src/deploy_rules_sync.sh` tracks `.agents/federation` in `managed_paths`.
- `src/context/engine.py` indexes `.agents/federation/` in the wiki graph, protects it in `append_only_prefixes`, and emits its latest CoD entries + non-current git branches in `render_orientation_section`.

### Interfaces and data

- File path: `.agents/federation/{YYYY-MM-DD}.md` (one file per UTC date) + `.agents/federation/llms.txt`.
- Deployer function: `deploy_agents_federation [target_dir]` in `src/deploy_agents_federation.sh`.
- Context engine helpers: `_federation_files(directory: Path) -> List[Path]`, `GRAPH_ARTIFACT_DIRS` + `"federation"`, `CONSOLIDATION_FOLDERS` + `"federation"`, `append_only_prefixes` + `".agents/federation/"`.

### Files and symbols

- `src/templates/AGENTS.FEDERATION.md` — new CoD federation protocol template.
- `src/deploy_agents_federation.sh` — new merge-safe deployer + `llms.txt` distributor.
- `.agents/federation/llms.txt`, `.agents/federation/2026-11-25.md` — child DOX contract and today's CoD ledger.
- `AGENTS.md`, `.agents/canonical/AGENTS.{md,md.sha256,sig}` — concise parallel-work/PR/branch integration reminder + `.agents/federation/` references + canonical signature.
- `bin/ainish-coder`, `src/deploy_rules_sync.sh`, `src/deploy_agents.sh`, `src/help.sh`, `src/README.md` — `--rules` wiring and docs.
- `src/context/engine.py`, `src/context/master-surfaces.json` — graph, orientation, append-only guard, consolidation, status.
- `.agents/llms.txt`, `llms.txt` — DOX chain updates.
- `src/context/tests/test_context_injection.py`, `src/context/tests/test_wiki_graph.py`, `src/context/tests/test_gate_ready.py`, `scripts/test-pqc-dist.sh` — verification tests.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Put cross-machine CoD lines inside `.agents/comms/{date}-team.md` | Mixes verbose local session checkin/checkout logs with terse multi-machine branch/PR integration signals; user explicitly asked for `.agents/federation/{date}.md`. |
| Auto-append to `.agents/federation/{date}.md` on every `--machine-sync` | Creates git noise and merge conflicts on every save/sync cycle; explicit CoD checkpoints keep signal dense and token-cheap. |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| `AGENTS.md` exceeds 160 lines or breaks pinned regexes | Check `wc -l AGENTS.md` and run `bash scripts/test-pqc-dist.sh` before commit. |
| `--rules` refresh clobbers machine entries | `<PROTOCOL>` merge verifies every `^### \[` header survives before atomic `mv`. |
| Peer CoD text attempts prompt injection | Template and `AGENTS.md` state entries are advisory data; agents verify git refs/PRs directly. |

## 4. Clarifications

### 4.1 Filename and UTC date convention

- **Question:** What exact naming convention should `.agents/federation/{date}.md` use?
- **Options:** 1. (Recommended) UTC `YYYY-MM-DD.md` (one file per UTC date, matching COMMS); 2. Hourly `{date}-{HH}.md`.
- **Selected:** UTC `YYYY-MM-DD.md` matching the user's explicit `.agents/federation/{date}.md` path and COMMS daily rotation.
- **Trade-off accepted:** Multiple machines append to the same UTC date file, mitigated by append-only rules and short CoD entries.
- **asked:** resolved from code
- **resolved by:** User request `.agents/federation/{date}.md` and `src/deploy_agents_comms.sh` / `AGENTS.md` non-negotiable #8.

### 4.2 Distribution via `--rules`

- **Question:** Should `.agents/federation/{date}.md` and its `llms.txt` deploy to target repos via `ainish-coder --rules`?
- **Options:** 1. (Recommended) Yes, merge-safely via `deploy_agents_federation` alongside COMMS; 2. Only in this repository.
- **Selected:** Deploy merge-safely via `--rules` because `AGENTS.md` is universal and every link/folder it names must ship to targets (`test-pqc-dist.sh:757-777`).
- **Trade-off accepted:** Adds one lightweight directory + daily file to target `.agents/`.
- **asked:** resolved from code
- **resolved by:** `scripts/test-pqc-dist.sh:757-794` and `bin/ainish-coder:275-300`.

### 4.3 Gitignored + peer-transferred via connections

- **Question:** Should `.agents/federation/{date}.md` be committed to git or gitignored and transferred directly between connected machines?
- **Options:** 1. (Recommended) Gitignored (`.agents/federation/*.md` in `.gitignore`, `.agents/federation/llms.txt` tracked) and transferred/union-merged across connected peers by `--machine-sync`; 2. Git-tracked.
- **Selected:** Gitignored and transferred directly between connected peers via `--machine-sync`.
- **Trade-off accepted:** Requires `--machine-sync` (or `--machine-watch`) rather than plain git pull to see peer CoD entries.
- **asked:** operator
- **resolved by:** Operator direction ("federation docs should be gitignored but transferred between agents via their connections").

### 4.4 PQC transport & agent read-only protection

- **Question:** Should cross-machine federation CoD communication use PQC and be agent read-only to prevent lower-capability agents from corrupting state or exposing secrets?
- **Options:** 1. (Recommended) FIPS 203 ML-KEM-768 + FIPS 204 ML-DSA-65 + SP 800-38D AES-256-GCM + HKDF-SHA3-256 envelopes (`src/federation_pqc.py`), OS read-only lock (`0444` + `uchg`/`+R`), deterministic git-metadata CoD checkpoints, and fail-closed secret/PII/bidi scrubbing with pinned peer fingerprints (no plaintext downgrade); 2. Plaintext SSH copy.
- **Selected:** PQC envelopes + agent read-only OS lock + deterministic scrubbed checkpoints.
- **Trade-off accepted:** Peers must have Python `cryptography` with FIPS 203/204 support to exchange CoD ledgers (no silent plaintext downgrade).
- **asked:** operator
- **resolved by:** Operator direction ("communicate in a PQC manner... 'agent read only' communication space so our cross machine needs stay secured so less intelligent agents dont mess up anything and expose machine, project, et cetera secrets").

## 5. Todos

- [x] **T1** Create worktree `feat/agents-federation-cod`, plan of record, and task record.
  - from: §3 | done when: worktree + plan + task exist and `--plan-check` exits 0 | verify: `bash bin/ainish-coder --plan-check .`
- [x] **T2** Create `src/templates/AGENTS.FEDERATION.md`, `src/deploy_agents_federation.sh`, `src/federation_pqc.py`, and `.agents/federation/llms.txt`.
  - from: §3 | done when: template, deployer, PQC engine, and index pass syntax + unit + merge-safety checks | verify: `bash -n src/deploy_agents_federation.sh`
- [x] **T3** Update `AGENTS.md` (≤160 lines) with parallel PR/branch integration reminder and `.agents/federation/` pointers, then re-sign `.agents/canonical/AGENTS.md`.
  - from: §3 | done when: `wc -l AGENTS.md` <= 160 and canonical signature/sha256 verify | verify: `wc -l AGENTS.md && bash bin/ainish-context audit contract --verify-history`
- [x] **T4** Wire `.agents/federation/` and PQC peer transfer into `.gitignore`, `src/machine_sync.sh`, `bin/ainish-coder`, `src/deploy_rules_sync.sh`, `src/deploy_agents.sh`, `src/help.sh`, `src/README.md`, `src/context/engine.py`, and `src/context/master-surfaces.json`.
  - from: §3 | done when: `--rules` deploys read-only federation merge-safely, `--machine-sync` exchanges PQC envelopes, and `engine.py` indexes/orients/protects it | verify: `bash -n bin/ainish-coder src/machine_sync.sh src/deploy_rules_sync.sh src/deploy_agents.sh src/help.sh`
- [x] **T5** Update `.agents/llms.txt` and root `llms.txt` (DOX pass) and add unit + dist-suite + machine-sync tests.
  - from: §3 | done when: DOX chain updated and new tests pass | verify: `python3 -m unittest src/context/tests/test_federation_pqc.py`
- [x] **T6** Run full verification gates (`test-pqc-dist.sh`, `test-machine-sync.sh`, Python tests, `plan-check`), record COMMS/memory/federation closeout, push branch, and open PR.
  - from: §3 | done when: gates verified, PR open, worktree clean | verify: `gh pr view`

## 6. Verification

- `bash -n bin/ainish-coder src/deploy_agents_federation.sh src/deploy_rules_sync.sh src/deploy_agents.sh src/help.sh` — exit 0.
- `wc -l AGENTS.md` — `<= 160`.
- `bash bin/ainish-coder --plan-check .` — exit 0 (`plan-ok`).
- `python3 -m unittest src/context/tests/test_context_injection.py src/context/tests/test_wiki_graph.py src/context/tests/test_gate_ready.py` — new and existing tests pass (any pre-existing baseline failures noted explicitly).
- `bash scripts/test-pqc-dist.sh` — all new federation + `AGENTS.md` checks pass (pre-existing baseline failures, if any, reported transparently).
- `bash scripts/test-machine-sync.sh` — pass (exit 0).

## 7. Open Decisions

- None.
