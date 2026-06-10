# TASK: Restructure prometheus fallbacks + verify endpoints

**Date:** 2026-06-09
**Branch:** chore/opencode-prometheus-config

## CoD
- prometheus fallbacks: objects→strings
- match metis pattern: 3 providers  
- verify zai, xiaomi, wafer endpoints
- skip local-router verification
- keep primary model + variant + prompt_append

####

## Changes
1. **`~/.config/opencode/oh-my-openagent.jsonc`** — prometheus fallback_models converted from `[{model, variant}]` object array to flat `["provider/model"]` string array, matching metis/sisyphus/hephaestus pattern.
2. Primary model retained: `github-copilot/claude-opus-4.7` (variant: `max`)
3. `prompt_append` retained: "Leverage deep & quick agents heavily, always in parallel."

## Verification Results

| Provider | Endpoint | HTTP | Chat Test | Models |
|----------|----------|------|-----------|--------|
| **Z.AI** | `https://api.z.ai/api/coding/paas/v4` | ✅ 200 | ✅ "hello world" via `glm-5.1` | glm-4.5..5.1, code-pass variants |
| **Xiaomi-Mimo** | `https://token-plan-sgp.xiaomimimo.com/v1` | ✅ 200 | ✅ "hello world" via `mimo-v2.5` | mimo-v2.4-pro, v2.5, v2.5-pro |
| **Wafer** | `https://pass.wafer.ai/v1` | ✅ 200 | ⚠️ Keychain-auth'd (opencode handles) | deepseek-v4-flash, GLM-5.1, Kimi-K2.6, etc. |

- **Config validation**: `opencode agent list` shows Prometheus as "Plan Builder (primary)" — loaded and recognized.
- **Pattern match**: prometheus fallbacks now identical to metis → `["zai/code-pass-glm-5.1", "local-router/fallback-models", "wafer/deepseek-v4-flash"]`
- **Local-router**: skipped per user request

## No project files changed
Config file is at `~/.config/opencode/oh-my-openagent.jsonc` (external to ainish-coder).
