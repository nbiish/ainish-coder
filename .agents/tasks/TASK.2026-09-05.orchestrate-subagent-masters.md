# TASK.2026-09-05 — Enhance trae-mini-fleet into orchestrate-subagent-masters

- date: 2026-09-05
- agent: dsh-orchestrator
- branch: feat/fleet-orchestrate-subagent-masters
- worktree: /mnt/d/Code/orchestrate-subagent-masters
- status: verifying

## Objective

Full-replacement evolution of the `trae-mini-fleet` skill pack into
`orchestrate-subagent-masters`: one universal subagent orchestration contract
covering ALL modalities (trae-cli, mini, native subagent, subagent_fork,
workflow, ralph) under master personas, expressed as concise terminal-command /
tool-call instructions — no Python tooling scripts.

## Operator Decisions

1. Architecture: **Full replacement** (rename/absorb; update every AGENTS.md reference).
2. Tooling: **No Python scripts** — strict concise terminal command instructions per agent.

## Changes

- `+ .agents/skills/orchestrate-subagent-masters/SKILL.md` — new universal contract:
  doctrine, 6-modality matrix (one command each), 4 canonical templates,
  terminal-native Dispatch Protocol v3 (preflight one-liner, timeout, scope
  check, scrub), exit taxonomy, handoff chains, COMMS receipts, guardrails.
- `+ .agents/skills/orchestrate-subagent-masters/MASTER-REFLECTIONS.txt` — reflections
  ledger migrated from `trae-mini-fleet/FLEET-SKILL-REFLECTIONS.txt`, header
  updated to all modalities; history preserved.
- `- .agents/skills/trae-mini-fleet/` — removed (SKILL.md absorbed; scripts
  `fleet_dispatch.py`, `fleet_doctor.py`, `scrub_task.py` retired per operator).
- `AGENTS.md` — `<FLEET>` rewritten: Subagent Master Fleet (Tier 3 + native
  modalities), terminal-native Dispatch Protocol v3 (no wrapper/doctor/receipt
  scripts; COMMS ledger = the receipt), taxonomy minus script-only code 70,
  templates pointer repathed; `<DOCUMENT_MODEL>`, frontmatter, `<AUDIT>` #7 updated.
- `llms.txt` — tooling wiring mention + Dispatch Protocol v3.
- `README.md` — skills table row + specification pointer.
- `src/help.sh` — skills list blurb.
- `.agents/skills/gstack-coder/SKILL.md` — 3 pairing references repathed.

## Gates

- [x] Zero stale `trae-mini-fleet` / `fleet_dispatch` / `fleet_doctor` / `scrub_task`
      references in live files (historical ledgers/tasks/TTS log intentionally untouched).
- [x] `bash -n src/help.sh` clean.
- [x] Skill pack count remains 23 (1 removed, 1 added).
- [x] No Python in new pack; no secrets/banned crypto introduced (markdown-only change).
- [x] Graph recon: docs + leaf-script removal; standalone CLIs with zero repo callers
      (grep-verified) — docs-only exemption per `<GRAPH>`, noted in COMMS.
- [ ] Operator merge confirmation (pending).

## Round 2 (2026-09-05, branch feat/fleet-dsh-acp-swap)

- Operator directive: fleet agents swap to DeepSeek Harness (`dsh` headless/ACP).
- Live validation: `dsh --profile headless` pong probe — exit 0, ~8s, clean stdout/stderr;
  works without the broken local-router (profile-owned provider config).
- SKILL.md rewritten: dsh modality matrix, workspace-root cwd rule, TPL_*_V3 persona-renamed
  templates, pong preflight, taxonomy 60 covers boot/config failure; trae-cli/mini retired to
  legacy-only.
- AGENTS.md FLEET fully swapped: intro, Tier 3, directives 3/5/7/8/9, engine matrix,
  handoff chains, templates block, Dispatch Protocol v3 preflight/dispatch/taxonomy.
- Cross-refs: README row, help.sh blurb, gstack-coder pairing lines.
- Gates: stale-engine-ref sweep clean (only intentional legacy notes), bash -n on help.sh +
  preflight snippet, TPL ids consistent across AGENTS.md and SKILL.md.

## Round 3 (2026-09-05, branch chore/fleet-dsh-only-scrub)

- Operator directives: scrub ALL trae/mini verbiage from AGENTS.md/llms.txt/skills;
  dsh-headless-only doctrine; wtf MCP orchestration focus; modal bad key is INTENTIONAL
  (fallback verification); operator is actively working the local-router — fleet hands off;
  use the USER-CONFIGURED dsh from the dash web (no profile overrides).
- Corrections applied: reverted my zai/glm-5.3-flash profile patch (backup restored —
  user config is deepseek-official/deepseek-v4-flash); doctrine now mandates operator-owned
  config, `--dump-config` + pong verification, never override.
- Verification: pong green on user config (exit 0); first real dsh coding dispatch GREEN
  (tests/dsh_dispatch.test.mjs, exit 0, ~103s, scope clean, independent gate green, artifact
  scrubbed post-verification); router fallback verified working-as-designed earlier (bad-key
  target skipped, healthy zai target served HTTP 200) — no further router probes per operator.
- Scrub: SKILL.md zero legacy verbiage + user-config doctrine + §9 wtf MCP Orchestration;
  MASTER-REFLECTIONS header rewritten + historical engine names redacted (peer skills-sync
  had regressed the header); graph-intelligence §5 bridge → dsh; wtf-agent-hub roster/cascade/
  catalog → dsh (model claim stripped — operator-owned config); wtf-observability catalog → dsh;
  advisory-council rotation mini → dsh. AGENTS.md + llms.txt verified already at zero.
- Scoping decisions (flagged): gstack-coder keeps its own mini-live tooling docs (separate
  tool, not fleet doctrine); skyvern keeps "mini agents" (its own product feature term).
