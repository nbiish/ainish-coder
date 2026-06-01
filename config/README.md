# mini-swe-agent configs

## Live-SWE-agent

[`livesweagent.yaml`](livesweagent.yaml) is vendored from [OpenAutoCoder/live-swe-agent](https://github.com/OpenAutoCoder/live-swe-agent) (upstream `config/livesweagent.yaml`).

**Preferred:** use the `mini-live` shell wrapper (loads `~/.config/mini-swe-agent/live-swe-agent.yaml`):

```bash
secrets-load
mini-live --task "your task" --yolo
```

**Explicit form** (same behavior):

```bash
mini --config ~/.config/mini-swe-agent/live-swe-agent.yaml --task "your task" --yolo
```

**From this repo** (when cwd is the repository root):

```bash
mini --config config/livesweagent.yaml --task "your task" --yolo
```

**Refresh global config** after upstream changes:

```bash
curl -fsSL "https://raw.githubusercontent.com/OpenAutoCoder/live-swe-agent/main/config/livesweagent.yaml" \
  -o ~/.config/mini-swe-agent/live-swe-agent.yaml
```

Create one parked file per provider: `~/.config/mini-swe-agent/.env-openrouter`, etc.
Active provider name is stored in `~/.cache/ainish-coder/mini-env-active-provider` (not inferred from URLs).

Bootstrap (first time): `prepend --set-active zenmux` if `.env` is already zenmux.
