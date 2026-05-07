---
name: "pi"
description: "Knowledge for configuring and extending the Pi Coding Agent (by mariozechner). Invoke when creating Pi extensions, themes, or multi-agent orchestrations."
---

# Pi Coding Agent Skill

## Overview
Pi Coding Agent is a CLI-based AI coding assistant. This skill provides domain knowledge on how to extend and configure Pi, including its extensions system, theming, and multi-agent orchestration capabilities.

## Architecture & Configuration
Pi uses a `.pi/` configuration directory for workspace-level settings.
- `settings.json` — Core configuration (models, API keys, TUI settings).
- `themes/*.json` — Custom TUI themes (e.g., catppuccin, dracula, cyberpunk).
- `agents/` — Agent definitions (e.g., `planner.md`, `reviewer.md`, `teams.yaml`).
- `extensions/*.ts` — TypeScript extensions executed via `pi -e <path>`.

## Extensions
Extensions are written in TypeScript and loaded via Pi's runtime (jiti).
- **Imports**: Available imports include `@mariozechner/pi-coding-agent`, `@mariozechner/pi-tui`, `@mariozechner/pi-ai`, `@sinclair/typebox`.
- **Execution**: Run via `pi -e extensions/your-extension.ts`.
- **Best Practices**:
  - Register tools at the top level of the extension function.
  - Use `isToolCallEventType()` for type-safe `tool_call` event narrowing.
  - Utilize `bun` as the primary package manager.

## Theming
Pi supports rich terminal UIs (TUI). Themes map UI elements to hex colors and can be dynamically swapped.
- Place themes in `.pi/themes/`.
- Use a `ThemeMap` or theme-cycler extension to adjust terminal aesthetics.

## Multi-Agent Orchestration
Pi can be orchestrated into teams (e.g., Planner -> Developer -> Reviewer).
- Define agents using markdown files containing their system prompts.
- Use `teams.yaml` or `agent-chain.yaml` to specify the execution order and handoffs.
- Extensions like `agent-team.ts` and `cross-agent.ts` handle the delegation logic.
