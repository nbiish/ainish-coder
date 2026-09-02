# TASK: CLI Agent Chat Integration & Fallback Cascade
- Date: 2026-09-02
- Worktrees:
  - ainish-coder: `fleet-agent-chat` (branch `feat/agent-chat-orchestration`)
  - local-router: `local-router-chat` (branch `feat/agent-chat-fallback`)
  - wtf-is-going-on-mcp: `wtf-agent-chat` (branch `feat/hub-agent-chat`)
- Objectives:
  1. Pull `https://github.com/alishahryar1/free-claude-code` into `local-router/example-repos/free-claude-code` (done).
  2. Implement headless execution fallback cascade: `free-claude-code` -> `omp` -> `trae-cli`.
  3. Integrate CLI agent chat and user-facing web chat across `local-router` (/config/chat) and `wtf-is-going-on-mcp` (dashboard).
  4. Allow users to select their CLI agent and toggle the `trae-cli` / `mini` agent fleet ON/OFF.
  5. Standardize on `local-router/fallback-models` across all agents, chat, and subagents.
  6. Harmonize `AGENTS.deployed.md`, `src/templates/AGENTS.deployed.md`, `AGENTS.md`, and `trae-mini-fleet` skill.
