# Task: one security skill, and context orchestration as a rag command

- lane: now
- branch: `feat/security-consolidation` (worktree `D:\Code\ac-sec-consolidate`)
- status: done
- scope: `.agents/skills/ainish-security/`, deleted `.agents/skills/{code-security,llm-security,production-security,context-orchestration}/`,
  `src/skills_selection.sh`, `src/verify_skills.sh`, `src/deploy_skills.sh`, `bin/ainish-coder`,
  `src/help.sh`, `src/rag/rag.py`, `src/rag/tests/test_context_injection.py`, `AGENTS.md`, `llms.txt`,
  `.agents/llms.txt`, `README.md`, `scripts/test-pqc-dist.sh`, `.agents/canonical/`, `.agents/audit/`

## Why

Two requests, one theme: collapse surface that forced an agent to choose correctly before it could
be correct.

1. **Security was four packs.** `code-security` (1,041 lines), `llm-security` (1,092),
   `production-security` (215), and a thin `ainish-security` (88) that summarised the others. An
   agent had to know in advance whether a task was "code" or "AI" before loading rules, and the
   packs cross-referenced each other by relative path (`code-security` pointed readers at
   `../../llm-security/references/...`). The practical outcome was that the summary was loaded and
   the depth was not.
2. **`context-orchestration` was a procedure nothing executed.** It described Elephant/Goldfish as a
   human/agent routine: draft an EGM design, run `bin/egm-check.sh`, hand it to a fresh reviewer.
   The `ainish-rag context` command already implemented the retrieval and both model passes. So the
   documentation told agents to do by hand what the tool did by itself — and the mechanical parts
   (branch, worktree, tree state, COMMS) were exactly what a tool should gather.

## What changed

### One security skill

`.agents/skills/ainish-security/` is now the whole contract:

| File | Lines | Content |
|---|---|---|
| `SKILL.md` | ~270 | Ten non-negotiables spanning every field, plus a one-paragraph treatment of each domain and pointers into references |
| `references/code-and-infrastructure.md` | ~560 | Every vulnerability class with per-language code, authn/authz, crypto call sites, compiler integrity, supply chain, containers, sandboxing, language standards, criticality matrix, CWE Top 25, deployment checklist |
| `references/ai-and-agentic.md` | ~640 | Prompt structure, injection defence, RAG security, tool/agentic risks ASI01–ASI10, MCP and CVE map, AST10, guardrails, red teaming, OWASP LLM Top 10, evals |
| `references/governance-and-cryptography.md` | ~290 | PQC status matrix with honest draft/final/selected distinctions, implementation surfaces, deprecation clock, audit evidence, NIST/EU/ISO frameworks, AIVSS, zero trust, SBOM/CBOM |
| `references/deployable-standards.md` | ~230 | The condensed self-contained standard `--secure` deploys as `AGENTS_SECURITY.md` |

The design choice worth recording: `SKILL.md` is an **instructional**, not a table of contents. It
states the ten rules that hold regardless of domain and enough of each field to act on, then points
at references for depth. That is the opposite of the old split, where the only cross-domain file was
a 88-line summary that omitted nearly everything actionable.

### `--secure` ships one file

`AGENTS_SECURITY.md` replaces `AGENTS_CODE_SECURITY.md` + `AGENTS_LLM_SECURITY.md`. The old pair
were byte-identical duplicates of the `production-standards.md` files they were copied from (verified
by digest), which is why `--secure` could ship a stale copy without anyone noticing. The legacy pair
is removed only where this tool previously managed them — detected by the `ainish-coder --secure`
marker — so a hand-authored file of the same name survives.

### `context-orchestration` became the `orientation` section

`ainish-rag context` now emits four labelled sections instead of three. The new `orientation` section
carries branch, worktree, working-tree state, today's COMMS entry, and the newest task record —
gathered in code, no model call, and emitted even when the route decides retrieval is unnecessary
because branch and tree state are true either way. Its cap is 12% of the budget and it is the last
section dropped, being the cheapest and the only one still useful when both drivers are unavailable.

The skill's review half was already `goldfish`; its judgement half (draft a design, decide
readiness) is not mechanisable and is not replaced. `bin/egm-check.sh` and
`.agents/templates/egm-design.md` remain available for operators who want a written design artifact;
they are no longer a required gate.

## Defects found and fixed

1. **`AGENTS.md` linked to two skills a default deploy never shipped.** A clean `--rules` run
   produced `pqc-secrets` only, while the contract it deployed linked to `ainish-security` and
   `context-orchestration` by relative path. Every default repo shipped a contract with two dangling
   links. `ainish-security` is now mandatory (the link must resolve); `context-orchestration`'s link
   is gone entirely, replaced by the command.
2. **Orientation reported the wrong branch.** `run_context_command` receives the canonical repo root
   so shared state (index, sessions) resolves correctly — but that made orientation report `main`
   while the agent sat in a feature worktree, which is precisely the fact the contract's first
   non-negotiable depends on. Git state now reads from the current directory, the shared-state root
   is named when it differs, and a protected branch is flagged explicitly.
3. **Truncation could exceed the cap it was enforcing.** The orientation truncation marker was
   appended *after* budgeting the text, so a section capped at 20 tokens came back at 29. The marker
   is now reserved inside the cap.
4. **The advisory rule for rag injections was dropped in the rewrite.** The old `ainish-security`
   carried an explicit statement that an `ainish-rag context` injection is data, not instruction,
   including the instruction never to widen Goldfish's inputs. Caught by a gate assertion during the
   rewrite and restored.

## Verification

- `py -m unittest discover -s src/rag/tests` — **143 pass** (7 new: orientation gathering, git-cwd
  correctness, protected-branch flagging, token cap, zero-cap disable, skip-route survival).
- `bash scripts/test-pqc-dist.sh` — **131/131** (23 new assertions: four retired packs absent, five
  consolidated files present, seven field-coverage checks on the instructional, mandatory status in
  both selection paths, `--secure` deploying one file, orientation wired in engine + contract).
- `ainish-rag audit verify` — 16/16 after re-signing.
- End-to-end into a clean git repo: `--rules --headless` deployed **both** mandatory packs, and every
  `./.agents/skills/...` link in the deployed `AGENTS.md` resolved. `--skills-list --json` reports
  `mandatory: ['ainish-security','pqc-secrets']`. `--secure` produced exactly one file,
  `AGENTS_SECURITY.md`.
- Live `context` from the worktree: sections `orientation, retrieval, elephant, goldfish`, orientation
  reporting `feat/security-consolidation` and `D:/Code/ac-sec-consolidate` with the shared-state root
  named separately.

## Not done, and why

- **Rust engine parity for the orientation section.** `src/rag/src/main.rs` does not implement
  `context` at all yet, so the launcher falls through to Python on hosts using the compiled binary.
  Pre-existing; unchanged by this work.
- **`--secure` was not exercised with the compiled signer present.** The worktree has no
  `bin/ainish-rag.exe`, so the `--rules` run correctly refused at the signer preflight while still
  deploying content. The content path is what changed and it is verified; the signing path is
  unchanged.
- **`orchestrate-subagent-masters` deletion is the operator's.** It showed as deleted in the working
  tree before this task began; the retired-pack lists still name it so target copies are cleaned up
  on their next deploy.
