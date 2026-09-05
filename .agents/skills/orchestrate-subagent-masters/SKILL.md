---
name: orchestrate-subagent-masters
description: >
  Master orchestration of ALL subagent modalities as direct agentic tool calls:
  DeepSeek Harness engines (dsh --profile headless one-shot dispatches and
  dsh --profile acp persistent automation surface) carrying the AST Refactoring
  Master and TDD Reproduction Engineer personas, harness-native subagent /
  subagent_fork delegates, workflow fan-out, and ralph fresh-agent loops — each
  embodied as an expert master persona with concise terminal-command
  instructions, dedicated worktree isolation, handoff chaining, and COMMS
  ledger receipts — with the wtf MCP hub as the live cross-machine
  observability plane. The dsh configuration is the operator's own (set from
  the DSH web dashboard): never override profile or provider config in
  dispatches. Use when orchestrating coding subagents, dispatching fleet
  engines, fanning out parallel subtasks, or delegating any scoped task to a
  sub-master.
---

# Orchestrate-Subagent-Masters — Universal Subagent Orchestrator Skill

The calling AI agent is the **Master Orchestrator**: it decomposes operator intent, embodies the exact domain expert each phase needs, and dispatches subagents as **direct tool calls** — never as passive advice, never as operator chores. Every dispatch runs in a dedicated sibling worktree; the engine is the **DeepSeek Harness CLI (`dsh`)** — headless one-shot dispatches, the ACP persistent surface, and `sdk[-minimal]` programmatic dispatch via `deepseek-harness-sdk` (profiles, never separate bins) — running the operator's own configuration as set from the DSH web dashboard. The wtf MCP hub is the live cross-machine observability plane (§9). The invoking directory is the workspace root, so always `cd` into the worktree first.

## 1. Core Doctrine

1. **Tool calls, not commentary.** Dispatch immediately via the modality's invocation form (§2).
2. **Embody the master.** Formulate each prompt AS the persona (AST Master, TDD Engineer, Security Auditor, …) — precise scope, bounded steps, explicit gates.
3. **Worktree isolation.** One dispatch = one branch = one sibling worktree (`git worktree add -b <type>/<scope>-<slug> ../<slug> main`). Never dispatch against `main`.
4. **Operator-owned config.** dsh runs the configuration the operator set from the DSH web dashboard — never override profile, provider, or model config in a dispatch (no `--patch` overlays, no profile edits). Verify what will boot with `dsh --profile headless --dump-config` and the §4.1 pong; never pass raw API keys in dispatch args or task text.
5. **Graph recon first.** `gitnexus context`/`impact` (d≤2) output IS the `SCOPE & TARGET FILES` allowlist. Zero blind edits.
6. **Receipts or it never happened.** Every dispatch lifecycle is a `SUBAGENT-DISPATCH` entry in the latest `.agents/comms/{date}-{time}-team.txt` (`parent: <orchestrator>`).

## 2. Subagent Modality Matrix — One Command Each

| Modality | Master Persona | Dispatch When |
|---|---|---|
| `dsh --profile headless` | AST Refactoring Master / TDD Reproduction Engineer (one-shot) | Multi-file structural edits, patches, failing-test reproduction, fix loops — answer, print, exit |
| `dsh --profile acp` | Persistent harness surface | A long-lived automation client (editor, orchestrator) driving multi-turn sessions over stdio |
| `dsh --profile sdk[-minimal]` via `deepseek-harness-sdk` | Any (programmatic one-shot) | Orchestrator scripts: `DeepSeekHarness(workspace=, dsh_home=, profile=).run(task, session_id=)` — explicit isolated workspace+home, fresh session id per task; `sdk-minimal` pins `danger-full-access` → disposable checkout/container only |
| Native subagent | Any (context-fresh delegate) | Self-contained research/implementation; must not see this conversation |
| `subagent_fork` | Any (context-inheriting delegate) | Follow-up analysis/review building on current conversation |
| `workflow` | Parallel Masters (fan-out) | Many independent scoped pieces: audits, migrations, multi-angle research |
| `ralph` | Fresh-Agent Iteration Master | ONLY on explicit operator request for fresh-agent iterative loops |

The launcher parses only its own flags; everything after them belongs to the booted profile (`dsh --profile <name> --help` for the app's flags). Invalid commands, foreign options, config errors, and boot failures exit nonzero.

### 2.1 `dsh --profile headless` — AST Refactoring Master (one-shot)
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
cd ../<slug>   # invoking directory = workspace root — never main
timeout 1800 dsh --profile headless "$(cat /tmp/task_ast.md)"
rm -f /tmp/task_ast.md   # scrub task file — mandatory, never skip; the worktree edits are the deliverable
```
Headless streams reasoning to stderr, prints the final assistant message to stdout, and exits — inherently non-interactive.

### 2.2 `dsh --profile headless` — TDD Reproduction Engineer (one-shot)
```bash
cd ../<slug>
timeout 1800 dsh --profile headless "$(cat << 'EOF'
[ROLE: TDD Reproduction Engineer]
OBJECTIVE: <reproduce & eliminate <bug>>
SEQUENCE: 1) write minimal failing test <tests/repro.test.mjs> 2) run it, confirm failure
3) patch <target file> minimally 4) re-run test + full suite green 5) stop and report
## SCOPE & TARGET FILES: <allowlist>
EOF
)"
```
No session flag exists or is needed — each headless run is one fresh persisted session (sessions persist under `$DSH_HOME/sessions/<workspace-slug>/session-<id>/session.jsonl.zstd`; cite the session id from stderr in the COMMS receipt when one is printed).

### 2.3 `dsh --profile acp` — persistent automation surface
```bash
dsh --profile acp   # serves ACP over stdio until disconnect
```
For clients that drive multi-turn agent sessions (editors, orchestrator processes). Boot it deliberately as a managed background process with a bounded lifetime — never inside a one-shot dispatch. One-shot orchestration uses §2.1/§2.2, not ACP.

### 2.3b `dsh --profile sdk[-minimal]` — programmatic one-shot via Python SDK
```python
from pathlib import Path
from deepseek_harness import DeepSeekHarness   # pip install deepseek-harness-sdk

with DeepSeekHarness(profile="sdk-minimal", cwd=str(workspace), dsh_home=str(dsh_home)) as harness:
    result = harness.run("<scoped task, same SCOPE/gates contract>", session_id="<fresh-id>")
print(result.final_response)
```
SDK and ACP are profiles, not separate bins. ALWAYS pass explicit isolated `workspace` + `dsh_home` (never silently reads `~/.dsh`); fresh `session_id` per independent task — reuse harness+home+id only to continue one conversation. `sdk-minimal` pins `danger-full-access`: disposable checkout/container only. Missing server rows / unresolved plugins fail at startup — no silent fallback.

### 2.4 Harness-native subagent — context-fresh delegate
Tool call (not shell): `subagent` with a **complete standalone prompt** — objective, scope allowlist, gates, persona, worktree/branch instruction. The delegate sees none of this conversation. Use `run_in_background: true` for independent scopes; block (`run_in_background: false`) when the next phase consumes the result.

### 2.5 Harness-native subagent_fork — context-inheriting delegate
Tool call: `subagent_fork` when the delegate should inherit the completed conversation (review, continuation, follow-up analysis). State only what is new; it already sees prior turns.

### 2.6 `workflow` — parallel Masters fan-out
Tool call: scripted fan-out across many independent pieces (audits, migrations). Write the orchestration as plain JS: `agent(prompt)` per unit, `pipeline` for per-item stages, `parallel` only at true barriers. Independent scopes may run concurrently; dependent scopes block on receipts.

### 2.7 `ralph` — fresh-agent iteration
Tool call: ONLY when the operator explicitly requests Ralph/fresh-agent iteration. Each round is a context-free child; the shared workspace is the only memory.

## 3. Canonical Master Templates (authoritative copies)

Four templates, invoked with the §2 command forms. Invariants (non-negotiable): scoped `SCOPE & TARGET FILES` allowlist from graph recon; one-shot engines only inside dispatches (never boot `web`/`tui`/`acp` profiles in a dispatch — headless answers and exits); task prompts via task file fed with `"$(cat <file>)"`; dispatch only inside dedicated sibling worktrees (invoking directory = workspace root).

- **TPL_AST_REFACTOR_V3** — AST Refactoring Master (dsh headless): role = surgical structural refactor preserving AST/type contracts; scope = gitnexus allowlist; gates = compile + tests + scope-clean `git status`.
- **TPL_TDD_REPRO_V3** — TDD Reproduction Engineer (dsh headless): role = minimal failing test → confirm failure → minimal patch → green suite → report; zero extraneous scripts.
- **TPL_SECURITY_AUDIT_V3** — Adversarial Security Auditor (dsh headless/native): role = zero-trust audit — CWE-22/SSRF/injection vectors, FIPS 203/204/205-only secrets ops, allowlist validation; gates = security tests + zero banned primitives.
- **TPL_SYSTEMS_ARCH_V3** — Systems Architecture Master (dsh headless): role = deterministic loopback pipelines, port contracts, daemon failover, signal-clean shutdown; gates = endpoint smoke + lifecycle tests.

## 4. Terminal-Native Dispatch Protocol

No wrapper scripts — the orchestrator runs plain commands and normalizes outcomes itself.

### 4.1 Preflight (before first dispatch of a session)
```bash
command -v dsh >/dev/null && dsh --version >/dev/null && \
timeout 120 dsh --profile headless "Reply with the single word: pong. Do not run any commands or modify any files." | grep -q pong && echo GO || echo NO-GO
```
NO-GO = fix environment first (binary missing → install/pin `dsh`; pong fails → profile provider config broken — fix credentials/config before ANY dispatch). **Liveness is not health:** the pong probe is a real inference round-trip — it proves the profile's provider can actually complete a completion (live-fire 2026-09-05: a router liveness check passed while every upstream target 401'd, and the dispatch died at step 1). The pong consumes one cheap call — first dispatch of a session only. When a profile routes through the local-router loopback, additionally run the `/v1/chat/completions` round-trip probe from the hardening round; loopback probes only — never probe non-loopback hosts.

**Model verification (which model will serve):** `dsh --dump-config` shows only the static bundle defaults and does NOT reflect runtime settings — never use it to confirm the model. The runtime authority is the operator's `$DSH_HOME/settings.yaml` (`agent-default-model: provider/model`, set from the DSH web dashboard), corroborated by the dispatched session's log under `$DSH_HOME/sessions/` which records the actual `provider` and `model` served. Verified 2026-09-05: headless masters serve `zai/glm-5.3-flash` from the zai code plan while dump-config displayed `deepseek-official/deepseek-v4-flash`.

### 4.2 Dispatch rules
- Fixed command vectors, `timeout 1800` (tune 900–3600 by scope) on every engine call.
- `cd` into the dispatch worktree first — the invoking directory is the workspace root.
- Parallel dispatches only for independent scopes in separate worktrees; dependent scopes block on completion.
- After each dispatch: verify scope conformance (`git -C ../<slug> status --porcelain` ⊆ allowlist), scrub task files (`rm -f`), then log the COMMS receipt with exit code.

### 4.3 Exit taxonomy (orchestrator-normalized)
| Code | Meaning | Action |
|---|---|---|
| `0` | OK | Collect receipt → verification/merge flow |
| `20` | STEP-EXHAUSTED (failed, zero edits) or `124` timeout | Hand off to sibling modality with discovered targets |
| `30` | PROBE-LOOP (≥3 identical probes in engine output) | Hand failure signature to a fresh scoped dispatch for AST surgery |
| `40` | ENGINE_OR_GATES_FAILED | Fix scope/gates, re-dispatch |
| `50` | SCOPE_VIOLATION | Revert edits, tighten allowlist, re-dispatch |
| `60` | ENVIRONMENT (preflight failed; dsh boot/config/foreign-option failure; auth/upstream-error signature) | Fix profile/provider credentials, re-run §4.1 pong. **Never hand off to a sibling engine on 60 — all engines share the environment** |

Raw exit `124` (timeout) normalizes to `20`. No script assigns these — the orchestrator reads engine output and assigns.

## 5. Handoff Chaining

- **Refactor → Harden:** one `dsh headless` dispatch (AST Master) applies structural edits → a second `dsh headless` dispatch (TDD Engineer) synthesizes reproduction tests + hardens edges on the result.
- **Probe → Fix:** a `dsh headless` dispatch (TDD Engineer) isolates the bug with a minimal failing test → a fresh scoped dispatch (AST Master) applies the production patch to exact files.
- **Native ↔ Terminal:** a `subagent`/`subagent_fork` delegate's analysis becomes the scoped task file for a `dsh` dispatch; terminal receipts feed back into native verification delegates.
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
5. Privacy: task files and intermediate artifacts scrubbed after every dispatch; no secrets, no absolute home paths in any artifact (headless sessions persist under `$DSH_HOME` — treat session logs as artifacts too).
6. GitNexus `detect-changes` scope proof before merge (or COMMS-logged fallback gap note).
7. Operator confirms every merge — never self-approve.

| Pitfall | Rule |
|---|---|
| Booting `web`/`tui`/`acp` inside a dispatch | One-shot engines only — headless answers and exits |
| Mixing launcher and app flags | Launcher parses `--profile`/`--patch`/`--dump-*` only; the rest belong to the profile (`--help` per profile) |
| Dispatching from `main` | Invoking directory = workspace root — `cd` into the sibling worktree first |
| Unescaped task strings | Task file + `"$(cat <file>)"` |
| Raw keys in dispatch args | Never — profiles carry their own provider config |
| Dispatch on `main` | Mandatory sibling worktree |
| Dispatch without preflight | §4.1 GO before first dispatch |
| Skipping scrub | `rm -f` task files after EVERY dispatch |
| Missing COMMS receipt | Ledger entry with exit code per dispatch — no exceptions |

## 8. Reflection Ledger

Upon every dispatch, record concise persona-aligned refinements in `MASTER-REFLECTIONS.txt` beside this SKILL.md (ISO-8601, modality, action, refinement).

## 9. wtf MCP Orchestration

The wtf hub is the live cross-machine observability and coordination plane, complementary to the git-carried COMMS ledger:

1. **Discover:** `wtf_is_going_on` before starting work — see what peers are doing machine-wide.
2. **Report:** `check_in` working/blocked/done at task boundaries; `log_event` for milestones and receipts.
3. **Dispatch:** the hub's `chat_run` / session-lifecycle tools execute headless tasks through its agent catalog — any hub-dispatched task still owes a COMMS receipt.
4. **Coordinate:** COMMS-ledger channels (`comms_post`/`comms_read`) for live distributed sync; encrypted sealed sessions for confidential coordination.
5. **Degrade gracefully:** hub unavailable → the COMMS ledger carries coordination with a gap note; never block fleet dispatches on hub availability.
