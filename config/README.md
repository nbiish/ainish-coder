# mini-swe-agent configs

## Live-SWE-agent

[`livesweagent.yaml`](livesweagent.yaml) is vendored from [OpenAutoCoder/live-swe-agent](https://github.com/OpenAutoCoder/live-swe-agent) (upstream `config/livesweagent.yaml`).

To run `mini-swe-agent` directly using this custom configuration, pass it via the `--config` flag:

```bash
mini-swe-agent --config config/livesweagent.yaml --task "your task"
```

Alternatively, you can configure it by setting the environment variable `MSWEA_MINI_CONFIG_PATH` in your shell configuration (e.g., `.zshrc`) to point to the file:

```bash
export MSWEA_MINI_CONFIG_PATH="$HOME/code/ainish-coder/config/livesweagent.yaml"
```
