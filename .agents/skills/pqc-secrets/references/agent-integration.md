---
name: agent-integration
description: How to wire pqc-secrets into Claude Code, Hermes MCP, VS Code, Cursor, and shell wrappers. With the right and wrong ways to inject secrets.
---

# Agent Integration

How to wire PQC secrets into the agent tools and IDEs you use every
day. **The pattern is always the same:** the agent's config file
references the env var by name but does NOT contain the value; the
value is injected at process start from the encrypted bundle.

## §1 Hermes MCP (betterbrowsermcp)

The `@nbiish/betterbrowsermcp` MCP server exposes 9 PQC tools directly
to any Hermes agent. No shell wrapper required.

### Setup

`~/.hermes/config.yaml`:

```yaml
mcp_servers:
  betterbrowsermcp:
    command: node
    args:
      - /path/to/betterbrowsermcp/dist/index.js
    env:
      BROWSER_MCP_AGENT_ID: hermes
      BROWSER_MCP_PORT: '9109'
```

Add `betterbrowsermcp` to `platform_toolsets.cli` in the same file
(or to `telegram` if you also use the Telegram channel). Then in
Hermes: `/reload-mcp` (in the TUI input box — NOT a terminal) to
restart the MCP children.

### Tool surface

| Tool | Purpose |
|---|---|
| `browser_secrets_status` | Check keychain + bundle health. Returns JSON. |
| `browser_secrets_list` | List secret **names** (no values). |
| `browser_secrets_get` | Read one secret value. Optional `mode: 'plain'\|'redact'`. |
| `browser_secrets_load` | Bulk-export bundle into the agent's process env. |
| `browser_secrets_add` | Add a new secret. Optional `dry_run: true`. |
| `browser_secrets_add_from_clipboard` | Pull a value from the page's clipboard write. |
| `browser_secrets_unlock_agent` | Cache one secret value in agent memory for fast reads. |
| `browser_secrets_lock_agent` | Clear a cached secret (or wipe all). |
| `browser_secrets_copy_to_page` | Paste a secret into a focused form field. |

### Usage example

```
LLM: "Check if the bundle is healthy."
→ browser_secrets_status
← {"keychainOk":true,"pubKeyFp":"sha256:9f86...","nKeys":12,"createdUtc":"..."}

LLM: "What API keys do I have?"
→ browser_secrets_list
← {"keys":["STRIPE_SECRET","GH_TOKEN","OPENAI_API_KEY","ANTHROPIC_API_KEY"]}

LLM: "Show me the Stripe secret."
→ browser_secrets_get(name="STRIPE_SECRET", mode="plain")
← "sk-live-AbCd..."
```

### Audit trail

Every call is recorded in `~/.config/pqc-secrets/audit.log` (see
`references/audit-log.md`). The user can verify "did my agent read
X at Y time?" by `grep`-ing the log.

## §2 Claude Code

Claude Code reads `~/.claude/settings.json` and per-project
`~/.claude/projects/*/settings.json`. These files are JSON, often
committed to dotfiles repos. **They must not contain secret values.**

### WRONG — PQC violation

```json
{
  "env": {
    "ANTHROPIC_API_KEY": "sk-ant-api03-AbCd1234...",
    "OPENAI_API_KEY": "sk-proj-EfGh5678..."
  }
}
```

The keys are in plaintext on disk. They will sync to cloud backup,
get committed to a public dotfiles repo, be readable by any process
with file permissions, and persist forever in shell history.

### RIGHT — empty in settings, keychain-injected

`~/.claude/settings.json`:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://zenmux.ai/api/anthropic",
    "ANTHROPIC_API_KEY": "",
    "OPENAI_API_KEY": ""
  }
}
```

`~/.zshrc` (sourced before `claude` is launched):

```bash
secrets-load() {
  eval "$(pqc-secrets export)"
}
```

Launch Claude Code after `secrets-load`:

```bash
$ secrets-load
$ claude
```

The values are in process memory (volatile), not in any file. The
settings file has empty strings; the real values live in the
encrypted bundle and the keychain.

### Per-project overrides

If you need a different key for a specific project (e.g., a sandbox
OpenAI key), use a project-level wrapper:

```bash
# In the project directory, a Makefile target:
.PHONY: launch-claude
launch-claude:
	secrets-load && \
	OPENAI_API_KEY=$$OPENAI_API_KEY_SANDBOX claude
```

(Where `OPENAI_API_KEY_SANDBOX` is a separate bundle key.)

## §3 VS Code / Cursor

### WRONG — `.vscode/launch.json` env block

```json
{
  "configurations": [{
    "type": "node",
    "request": "launch",
    "env": {
      "API_KEY": "sk-AbCd1234..."
    }
  }]
}
```

### RIGHT — `${env:API_KEY}` with a pre-launch task

`.vscode/launch.json`:

```json
{
  "configurations": [{
    "type": "node",
    "request": "launch",
    "preLaunchTask": "secrets-load",
    "env": {
      "API_KEY": "${env:API_KEY}"
    }
  }]
}
```

`.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [{
    "label": "secrets-load",
    "type": "shell",
    "command": "bash -c 'eval \"$(pqc-secrets export)\" && env | grep -E '^[A-Z_]+=' > /tmp/vscode-env'",
    "presentation": { "reveal": "silent" }
  }]
}
```

The env vars are in `/tmp/vscode-env` for the launch duration. Not
great, but acceptable for local dev. For higher security, use a
VS Code extension that calls `pqc-secrets export` directly and
passes the values to the debug target in memory.

## §4 Ainish-coder / generic shell wrapper

The `secrets-load` shell function (in `~/.zshrc` or `~/.bashrc`):

```bash
secrets-load() {
  local line
  while IFS= read -r line; do
    [[ "$line" =~ ^export ]] || continue
    eval "$line"
  done < <(pqc-secrets export)
}
```

Use it before launching any tool that needs secrets:

```bash
$ secrets-load
$ claude         # inherits $ANTHROPIC_API_KEY
$ cursor         # inherits $ANTHROPIC_API_KEY
$ opencode       # inherits $ANTHROPIC_API_KEY
```

The values are in process memory (volatile), not in any file. They
are gone when the shell exits.

### Wrapper for one-off commands

If you only need secrets for a single command, use a subshell:

```bash
$ (eval "$(pqc-secrets export)" && my-tool --api-key=$MY_API_KEY)
```

The secrets are loaded, the tool runs, the subshell exits, and the
secrets are gone.

## §5 GitHub Actions (CI)

GitHub Actions secrets are encrypted at rest by GitHub and injected
into the runner's env. This is **acceptable for CI** but has
limitations:

```yaml
# .github/workflows/deploy.yml
env:
  API_KEY: ${{ secrets.API_KEY }}
```

**Limitations:**
- Every developer with repo access can see and modify `secrets.API_KEY`
  in the GitHub UI.
- Secrets are visible in the Actions log if accidentally `echo`'d.

For higher-security deployments, use an external secrets manager
(HashiCorp Vault, AWS Secrets Manager) that the CI calls at runtime:

```yaml
- name: Fetch secret from Vault
  run: |
    API_KEY=$(vault kv get -field=value secret/myapp/api-key)
    echo "::add-mask::$API_KEY"
    my-tool --api-key=$API_KEY
```

`::add-mask::` prevents the secret from being printed in logs.

## §6 Docker / docker-compose

### WRONG — `env_file:`

```yaml
services:
  app:
    env_file: ./secrets.env  # plaintext on disk
```

### RIGHT — runtime injection

```bash
# Inject from pqc-secrets at runtime
docker run -e API_KEY=$(pqc-secrets export | grep API_KEY | cut -d= -f2- | tr -d '"') my-image
```

Or with docker-compose:

```bash
# In a wrapper script
docker-compose up -e API_KEY=$(eval "$(pqc-secrets export)" && echo $API_KEY)
```

For higher security, use Docker secrets (mounted volumes):

```yaml
services:
  app:
    volumes:
      - /run/secrets/api_key:/run/secrets/api_key:ro
```

```bash
# Provision the secret file from pqc-secrets
mkdir -p /run/secrets
pqc-secrets export | grep API_KEY | cut -d= -f2- | tr -d '"' > /run/secrets/api_key
chmod 600 /run/secrets/api_key
```

The file is gone when the container exits. (Or use tmpfs.)

## §7 See also

- `SKILL.md` §7 (Agent Integration Recipes) — same content, abbreviated
- `references/pqc-secrets-cli.md` — CLI reference
- `references/audit-log.md` — audit log format
- `references/rotation-procedure.md` — rotation runbook
