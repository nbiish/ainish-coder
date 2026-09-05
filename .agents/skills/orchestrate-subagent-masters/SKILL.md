---
name: orchestrate-subagent-masters
description: >
  Master orchestration of ALL subagent modalities as direct agentic tool calls:
  terminal engines trae-cli (AST Refactoring Master) and mini (TDD Reproduction
  Engineer), harness-native subagent / subagent_fork delegates, workflow fan-out,
  and ralph fresh-agent loops — each embodied as an expert master persona with
  concise terminal-command instructions, dedicated worktree isolation, loopback
  local-router/fallback-models routing, handoff chaining, and COMMS ledger
  receipts. Supersedes trae-mini-fleet. Use when orchestrating coding subagents,
  dispatching fleet engines, fanning out parallel subtasks, or delegating any
  scoped task to a sub-master.
---

# Orchestrate-Subagent-Masters — Universal Subagent Orchestrator Skill

The calling AI agent is the **Master Orchestrator**: it decomposes operator intent, embodies the exact domain expert each phase needs, and dispatches subagents as **direct tool calls** — never as passive advice, never as operator chores. Every dispatch runs in a dedicated sibling worktree under loopback proxy `http://127.0.0.1:11434/v1` (`local-router/fallback-models`).

## 1. Core Doctrine

1. **Tool calls, not commentary.** Dispatch immediately via the modality's invocation form (§2).
2. **Embody the master.** Formulate each prompt AS the persona (AST Master, TDD Engineer, Security Auditor, …) — precise scope, bounded steps, explicit gates.
3. **Worktree isolation.** One dispatch = one branch = one sibling worktree (`git worktree add -b <type>/<scope>-<slug> ../<slug> main`). Never dispatch against `main`.
4. **Loopback confinement.** All engine inference routes through `127.0.0.1:11434/v1` with dummy bearer `local-router`. Subagents never see raw API keys.
5. **Graph recon first.** `gitnexus context`/`impact` (d≤2) output IS the `SCOPE & TARGET FILES` allowlist. Zero blind edits.
6. **Receipts or it never happened.** Every dispatch lifecycle is a `SUBAGENT-DISPATCH` entry in `AGENTS/{date}.COMMS.md` (`parent: <orchestrator>`).

## 2. Subagent Modality Matrix — One Command Each

| Modality | Master Persona | Dispatch When |
|---|---|---|
| `trae-cli` | AST Refactoring Master | Multi-file structural edits, cross-module refactors, unified patches |
| `mini` | TDD Reproduction Engineer | Failing-test reproduction, bug isolation, fix loops, hardening |
| Native subagent | Any (context-fresh delegate) | Self-contained research/implementation; must not see this conversation |
| `subagent_fork` | Any (context-inheriting delegate) | Follow-up analysis/review building on current conversation |
| `workflow` | Parallel Masters (fan-out) | Many independent scoped pieces: audits, migrations, multi-angle research |
| `ralph` | Fresh-Agent Iteration Master | ONLY on explicit operator request for fresh-agent iterative loops |

Flags evolve across releases — run `<agent> --help` before new flags.

### 2.1 `trae-cli` — AST Refactoring Master (terminal)
```bash
cat > /tmp/task_ast.md << 'EOF'
# TASK: <one-line objective>
## ROLE & EXPERT PERSONA
You are the **AST Refactoring Master**. Surgical structural edits; preserve AST and exported contracts.
## SCOPE & TARGET FILES   # gitnexus impact output — the ONLY editable files
- <file1>
- <file2>
## OBJECTIVE & DIRECTIVES
1. <directive>  2. <directive>
## ACCEPTANCE & QUALITY GATES
1. <compile/typecheck cmd>  2. <test cmd>  3. git status shows ONLY scope files
EOF
timeout 1800 trae-cli run -f /tmp/task_ast.md --console-type simple \
  --patch-path ../<slug>/solution.patch --max-steps 30
rm -f /tmp/task_ast.md   # scrub — mandatory, never skip
```

### 2.2 `mini` — TDD Reproduction Engineer (terminal, zero-config)
```bash
timeout 1800 mini --task "$(cat << 'EOF'
[ROLE: TDD Reproduction Engineer]
OBJECTIVE: <reproduce & eliminate <bug>>
SEQUENCE: 1) write minimal failing test <tests/repro.test.mjs> 2) run it, confirm failure
3) patch <target file> minimally 4) re-run test + full suite green 5) exit immediately
EOF
)" --output ../<slug>/mini_trajectory.json --yolo --exit-immediately
rm -f ../<slug>/mini_trajectory.json   # scrub — mandatory, never skip
```
**Never pass `--config`** — `mini` is pre-wired to `local-router/fallback-models` via `~/.config/mini-swe-agent/.env`.

### 2.3 Harness-native subagent — context-fresh delegate
Tool call (not shell): `subagent` with a **complete standalone prompt** — objective, scope allowlist, gates, persona, worktree/branch instruction. The delegate sees none of this conversation. Use `run_in_background: true` for independent scopes; block (`run_in_background: false`) when the next phase consumes the result.

### 2.4 Harness-native subagent_fork — context-inheriting delegate
Tool call: `subagent_fork` when the delegate should inherit the completed conversation (review, continuation, follow-up analysis). State only what is new; it already sees prior turns.

### 2.5 `workflow` — parallel Masters fan-out
Tool call: scripted fan-out across many independent pieces (audits, migrations). Write the orchestration as plain JS: `agent(prompt)` per unit, `pipeline` for per-item stages, `parallel` only at true barriers. Independent scopes may run concurrently; dependent scopes block on receipts.

### 2.6 `ralph` — fresh-agent iteration
Tool call: ONLY when the operator explicitly requests Ralph/fresh-agent iteration. Each round is a context-free child; the shared workspace is the only memory.

## 3. Canonical Master Templates (authoritative copies)

Four templates, invoked with the §2 command forms. Invariants (non-negotiable): scoped `SCOPE & TARGET FILES` allowlist from graph recon; non-interactive flags (`--console-type simple` for trae-cli, `--yolo --exit-immediately` for mini, never `--config` for mini); prompts via task file for trae-cli; dispatch only inside dedicated sibling worktrees; loopback proxy routing.

- **TPL_TRAE_AST_V2** — AST Refactoring Master (`trae-cli`): role = surgical structural refactor preserving AST/type contracts; scope = gitnexus allowlist; gates = compile + tests + scope-clean `git status`.
- **TPL_MINI_TDD_REPRO_V1** — TDD Reproduction Engineer (`mini`): role = minimal failing test → confirm failure → minimal patch → green suite → exit; zero extraneous scripts.
- **TPL_SECURITY_AUDIT_V1** — Adversarial Security Auditor (`trae-cli`/`mini`/native): role = zero-trust audit — CWE-22/SSRF/injection vectors, FIPS 203/204/205-only secrets ops, allowlist validation; gates = security tests + zero banned primitives.
- **TPL_TRAE_SYSTEMS_V1** — Systems Architecture Master (`trae-cli`): role = deterministic loopback pipelines, port contracts, daemon failover, signal-clean shutdown; gates = endpoint smoke + lifecycle tests.

## 4. Terminal-Native Dispatch Protocol

No wrapper scripts — the orchestrator runs plain commands and normalizes outcomes itself.

### 4.1 Preflight (before first dispatch of a session)
```bash
command -v trae-cli mini >/dev/null && \
curl -sf -m 3 http://127.0.0.1:11434/api/version >/dev/null && echo GO || echo NO-GO
```
NO-GO = fix environment first (router down → start local-router; binary missing → install/pin). Loopback probes only — never probe non-loopback hosts.

### 4.2 Dispatch rules
- Fixed command vectors, `timeout 1800` (tune 900–3600 by scope) on every engine call.
- Parallel dispatches only for independent scopes in separate worktrees; dependent scopes block on completion.
- After each dispatch: verify scope conformance (`git -C ../<slug> status --porcelain` ⊆ allowlist), scrub task files and trajectory JSONs (`rm -f`), then log the COMMS receipt with exit code.

### 4.3 Exit taxonomy (orchestrator-normalized)
| Code | Meaning | Action |
|---|---|---|
| `0` | OK | Collect receipt → verification/merge flow |
| `20` | STEP-EXHAUSTED (failed, zero edits) or `124` timeout | Hand off to sibling engine with discovered targets |
| `30` | PROBE-LOOP (mini ≥3 identical probes) | Hand failure signature to `trae-cli` for AST surgery |
| `40` | ENGINE_OR_GATES_FAILED | Fix scope/gates, re-dispatch |
| `50` | SCOPE_VIOLATION | Revert edits, tighten allowlist, re-dispatch |
| `60` | PREFLIGHT_FAILED | Run §4.1, fix environment |

Raw exit `124` (timeout) normalizes to `20`. No script assigns these — the orchestrator reads engine output and assigns.

## 5. Handoff Chaining

- **Refactor → Harden:** `trae-cli` structural patch → `mini` synthesizes reproduction tests + hardens edges on the patch.
- **Probe → Fix:** `mini` isolates bug with minimal failing test → `trae-cli` applies the production patch to exact files.
- **Native → Terminal:** a `subagent`/`subagent_fork` delegate's analysis becomes the scoped task file for a terminal dispatch; terminal receipts feed back into native verification delegates.
Each handoff = one `FLEET-HANDOFF` COMMS entry (§6).

## 6. COMMS Receipts (ledger = the receipt)

```markdown
### [ISO-8601] SUBAGENT-DISPATCH | agent:<modality> | parent:<orchestrator> | wt:../<slug>
- start:<ISO> / end:<ISO>
- persona:<Master persona>
- scope:<allowlist files>
- objective:<one line>
- output:<artifact + gate results + exit code (normalized)>
- status:done | verifying | blocked
- blockers:none
```
One entry per dispatch; handoffs use `FLEET-HANDOFF | from:<modality> | to:<modality>`. No COMMS receipt = the dispatch never happened; no merge proceeds without receipts for every phase.

## 7. Verification Gates & Guardrails

1. Worktree isolation intact (never `main`).
2. Native gates green (`tsc --noEmit`, `cargo clippy`, `ruff`, test suites — per repo language).
3. Scope conformance: `git diff --name-only` ⊆ allowlist; violations revert before re-dispatch.
4. C/C++ patches: warnings-as-errors + ASan/UBSan + tests re-run on the optimized shipping binary.
5. Privacy: task files and trajectories scrubbed after every dispatch; no secrets, no absolute home paths in any artifact.
6. GitNexus `detect-changes` scope proof before merge (or COMMS-logged fallback gap note).
7. Operator confirms every merge — never self-approve.

| Pitfall | Rule |
|---|---|
| Invoking `trae-agent` | Binary is `trae-cli` — always |
| Hanging on stdin | `--console-type simple` (trae-cli); `--yolo --exit-immediately` (mini) |
| Passing `--config` to mini | Forbidden — zero-config via global env |
| Unescaped task strings | Task file via `-f <file>` for trae-cli; heredoc for mini |
| Dispatch on `main` | Mandatory sibling worktree |
| Dispatch without preflight | §4.1 GO before first dispatch |
| Skipping scrub | `rm -f` task/trajectory files after EVERY dispatch |
| Missing COMMS receipt | Ledger entry with exit code per dispatch — no exceptions |

## 8. Reflection Ledger

Upon every dispatch, record concise persona-aligned refinements in `MASTER-REFLECTIONS.txt` beside this SKILL.md (ISO-8601, modality, action, refinement).
