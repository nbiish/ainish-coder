# TASK.2026-09-04 — fleet orchestration protocol

Operator approved trae-mini-fleet + AGENTS.md pairing rework.
Worktree feat/fleet-orchestration-protocol from main (0adf18a).
New: fleet_doctor.py preflight (binaries, proxy 11434, backend, scrub, worktree).
New: fleet_dispatch.py wrapper — receipts, exit taxonomy, scope gate.
Also: fail-closed scrub, plugin gates, auto-handoff codes 0/20/30/40/50/60/70/124.
SSRF guards: loopback-only probes (doctor), per-hop redirect checks prior art.
Mock-engine suite: all six exit paths verified + receipt fields asserted.
Doctor live run: GO (real trae-cli, mini, proxy 200, backend 200).
SKILL.md: §6 gates expanded; new §7 Dispatch Protocol v2.
AGENTS.md: templates de-duplicated to skill (single source of truth).
AGENTS.md: Dispatch Protocol v2 binding; wait rules; receipts in audit.
DOX pass: no contract/structure/index change; content-only.

####
Ship v2 dispatch protocol; merge to main; operator push confirmed.
