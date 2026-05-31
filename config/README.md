# mini-swe-agent configs

## Live-SWE-agent

[`livesweagent.yaml`](livesweagent.yaml) is vendored from [OpenAutoCoder/live-swe-agent](https://github.com/OpenAutoCoder/live-swe-agent) (upstream `config/livesweagent.yaml`). Run from the repo root:

```bash
# 1. Swap provider (rename only)
prepend zenmux          # .env → .env-<previous>, .env-zenmux → .env

# 2. Run mini with normal CLI flags
mini --config config/livesweagent.yaml --task "your task" --yolo
```

Create one parked file per provider: `~/.config/mini-swe-agent/.env-openrouter`, etc.
Active provider name is stored in `~/.cache/ainish-coder/mini-env-active-provider` (not inferred from URLs).

Bootstrap (first time): `prepend --set-active zenmux` if `.env` is already zenmux.
