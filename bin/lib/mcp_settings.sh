#!/usr/bin/env bash
# MCP Settings library for ainish-coder sub-agent wrappers
#
# Reads MCP server definitions from:
#   1. ~/.agents/mcp-settings.json   (global — user-level defaults)
#   2. $(pwd)/.agents/mcp-settings.json  (project — overrides global)
#
# Project settings merge on top of global. Server definitions with the same
# name in project replace the global one entirely (not deep-merged).
#
# Usage:
#   source mcp_settings.sh
#   mcp_parse_flags "$@"        # strips --mcp*, sets MCP_ENABLED, MCP_SERVERS
#   mcp_load                     # loads merged settings into MCP_JSON
#   mcp_get_server "name"        # outputs JSON object for one server
#   mcp_list_servers             # outputs server names, one per line
#   mcp_generate_env             # outputs export KEY=VALUE for all enabled servers
#   mcp_generate_pi_extension    # writes a pi extension file, returns path
set -euo pipefail

MCP_GLOBAL="${HOME}/.agents/mcp-settings.json"
MCP_PROJECT="$(pwd)/.agents/mcp-settings.json"

# Merger result cached here after mcp_load
MCP_MERGED_JSON=""

# --mcp parsing results
MCP_ENABLED="false"
MCP_SERVERS=""       # comma-separated list from --mcp flag
MCP_ALL="false"       # --mcp-all

# ── Flag parsing ──────────────────────────────────────────────────────────────
# Call this FIRST, before any other argument parsing. It strips --mcp* flags
# from $@ and writes MCP state to the file at $MCP_STATE_FILE.
# Outputs remaining args, one per line on stdout.
#
# After calling, source $MCP_STATE_FILE to load MCP_ENABLED / MCP_SERVERS / MCP_ALL.

mcp_parse_flags() {
  local remaining=()
  local enabled="false"
  local servers=""
  local all="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-mcp)
        enabled="false"
        servers=""
        all="false"
        shift
        ;;
      --mcp-all)
        enabled="true"
        all="true"
        servers=""
        shift
        ;;
      --mcp)
        enabled="true"
        if [[ -n "${2:-}" && "$2" != -* ]]; then
          servers="$2"
          shift 2
        else
          echo "error: --mcp requires a comma-separated list of server names" >&2
          exit 1
        fi
        ;;
      *)
        remaining+=("$1")
        shift
        ;;
    esac
  done

  if [[ "$all" == "true" ]]; then
    enabled="true"
  fi
  if [[ -n "$servers" ]]; then
    enabled="true"
  fi

  # Write state to the designated file for parent to source
  cat > "${MCP_STATE_FILE}" <<STATE
MCP_ENABLED="${enabled}"
MCP_SERVERS="${servers}"
MCP_ALL="${all}"
STATE

  # Output remaining args one per line
  if [[ ${#remaining[@]} -gt 0 ]]; then
    printf '%s\n' "${remaining[@]}"
  fi
}

# ── Loading ──────────────────────────────────────────────────────────────────

mcp_load() {
  local global_json="{}"
  local project_json="{}"

  if [[ -f "$MCP_GLOBAL" ]]; then
    global_json="$(python3 -c "
import json, sys
with open('${MCP_GLOBAL}') as f:
    data = json.load(f)
print(json.dumps(data))
" 2>/dev/null || echo '{}')"
  fi

  if [[ -f "$MCP_PROJECT" ]]; then
    project_json="$(python3 -c "
import json, sys
with open('${MCP_PROJECT}') as f:
    data = json.load(f)
print(json.dumps(data))
" 2>/dev/null || echo '{}')"
  fi

  # Merge: project overrides global at the server level
  MCP_MERGED_JSON="$(python3 -c "
import json, sys

global_data = json.loads('''${global_json}''')
project_data = json.loads('''${project_json}''')

global_servers = global_data.get('mcpServers', {})
project_servers = project_data.get('mcpServers', {})

# Merge servers: project overwrites global for same key
merged_servers = {}
merged_servers.update(global_servers)
merged_servers.update(project_servers)

# Merge defaults: project overrides global
global_defaults = global_data.get('defaults', {})
project_defaults = global_data.get('defaults', {})
merged_defaults = {}
merged_defaults.update(global_defaults)
merged_defaults.update(project_defaults)

merged = {
    'mcpServers': merged_servers,
    'defaults': merged_defaults
}
print(json.dumps(merged))
")"
}

# ── Query helpers ─────────────────────────────────────────────────────────────

# Get a single server's JSON object
mcp_get_server() {
  local name="${1:?server name required}"
  python3 -c "
import json, sys
data = json.loads('''${MCP_MERGED_JSON}''')
server = data.get('mcpServers', {}).get('${name}', {})
if server:
    print(json.dumps(server))
"
}

# List all server names
mcp_list_servers() {
  python3 -c "
import json
data = json.loads('''${MCP_MERGED_JSON}''')
for name in sorted(data.get('mcpServers', {}).keys()):
    print(name)
"
}

# List default servers for a given tool
mcp_defaults_for() {
  local tool="${1:?tool name required}"
  python3 -c "
import json
data = json.loads('''${MCP_MERGED_JSON}''')
defaults = data.get('defaults', {}).get('${tool}', [])
for s in defaults:
    print(s)
"
}

# Resolve which servers should be active: --mcp flag takes priority, else defaults, else none
# Outputs one server name per line
mcp_resolve_servers() {
  local tool="${1:?tool name required}"

  if [[ "$MCP_ENABLED" != "true" ]]; then
    # No --mcp* flag at all: use defaults for this tool
    mcp_defaults_for "$tool"
    return
  fi

  if [[ "$MCP_ALL" == "true" ]]; then
    mcp_list_servers
    return
  fi

  if [[ -n "$MCP_SERVERS" ]]; then
    printf '%s\n' "${MCP_SERVERS//,/$'\n'}"
    return
  fi

  # --mcp with empty list = none
}

# ── Per-tool output generators ────────────────────────────────────────────────

# Export environment variables for all enabled MCP servers
# Usage: eval "$(mcp_generate_env pi)"
mcp_generate_env() {
  local tool="${1:?tool name required}"

  mcp_load

  local servers
  servers="$(mcp_resolve_servers "$tool")"

  if [[ -z "$servers" ]]; then
    return 0
  fi

  local count=0
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    local server_json
    server_json="$(mcp_get_server "$name")"
    if [[ -z "$server_json" || "$server_json" == "{}" ]]; then
      continue
    fi

    # Export server env vars
    python3 -c "
import json, sys
server = json.loads('''${server_json}''')
env = server.get('env', {})
for k, v in env.items():
    print(f'export MCP_ENV_{k}=\"{v}\"')
"
    # Export the server command as an env var for tool integration
    local cmd
    cmd="$(python3 -c "
import json
server = json.loads('''${server_json}''')
print(server.get('command', ''))
")"
    local args_json
    args_json="$(python3 -c "
import json
server = json.loads('''${server_json}''')
print(json.dumps(server.get('args', [])))
")"
    echo "export AINISH_MCP_${count}_NAME=\"${name}\""
    echo "export AINISH_MCP_${count}_COMMAND=\"${cmd}\""
    echo "export AINISH_MCP_${count}_ARGS='${args_json}'"
    count=$((count + 1))
  done <<< "$servers"

  echo "export AINISH_MCP_COUNT=${count}"
  echo "export AINISH_MCP_ENABLED=1"
}

# Generate a pi extension file that bridges MCP servers as pi tools.
# Returns the path to the generated extension file.
mcp_generate_pi_extension() {
  local tool="${1:?tool name required}"

  mcp_load

  local servers
  servers="$(mcp_resolve_servers "$tool")"

  if [[ -z "$servers" ]]; then
    return 0
  fi

  local ext_dir="${HOME}/.cache/ainish-coder/mcp-extensions"
  mkdir -p "$ext_dir"

  local ext_file="${ext_dir}/mcp_bridge_$$.ts"

  # Collect all server configs into JSON
  local servers_json="["
  local first=true
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    local sjson
    sjson="$(mcp_get_server "$name")"
    if [[ -z "$sjson" || "$sjson" == "{}" ]]; then
      continue
    fi
    if [[ "$first" != "true" ]]; then
      servers_json+=","
    fi
    first=false
    servers_json+="{\"name\":\"${name}\",\"config\":${sjson}}"
  done <<< "$servers"
  servers_json+="]"

  # Write the extension
  cat > "$ext_file" << EXTEOF
// MCP Bridge Extension — auto-generated by ainish-coder
// Bridges MCP servers as pi tools via stdio JSON-RPC
//
// Servers: ${servers_json}

import { spawn } from "node:child_process";
import { Readable, Writable } from "node:stream";

interface McpServerConfig {
  command: string;
  args: string[];
  env?: Record<string, string>;
}

interface McpServerEntry {
  name: string;
  config: McpServerConfig;
}

const SERVERS: McpServerEntry[] = JSON.parse(\`${servers_json}\`);

interface McpToolDef {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
}

interface McpProcess {
  proc: ReturnType<typeof spawn>;
  tools: McpToolDef[];
  requestId: number;
  pending: Map<number, { resolve: (v: unknown) => void; reject: (e: Error) => void }>;
  buffer: string;
}

class McpClient {
  private proc: McpProcess;

  constructor(server: McpServerEntry) {
    const env = { ...process.env, ...(server.config.env || {}) };
    const child = spawn(server.config.command, server.config.args, {
      stdio: ["pipe", "pipe", "pipe"],
      env,
    });

    this.proc = {
      proc: child,
      tools: [],
      requestId: 0,
      pending: new Map(),
      buffer: "",
    };

    child.stdout!.on("data", (chunk: Buffer) => this.onData(chunk.toString()));
    child.stderr!.on("data", (chunk: Buffer) => {
      // MCP servers log to stderr; silence in normal operation
    });
    child.on("exit", (code: number | null) => {
      if (code !== 0 && code !== null) {
        console.error(\`[mcp-bridge] \${server.name} exited with code \${code}\`);
      }
    });
  }

  private onData(data: string) {
    this.proc.buffer += data;
    const lines = this.proc.buffer.split("\n");
    this.proc.buffer = lines.pop() || "";
    for (const line of lines) {
      if (!line.trim()) continue;
      try {
        const msg = JSON.parse(line);
        this.handleMessage(msg);
      } catch {
        // skip non-JSON lines
      }
    }
  }

  private handleMessage(msg: any) {
    if (msg.id && this.proc.pending.has(msg.id)) {
      const { resolve, reject } = this.proc.pending.get(msg.id)!;
      this.proc.pending.delete(msg.id);
      if (msg.error) {
        reject(new Error(msg.error.message || "MCP error"));
      } else {
        resolve(msg.result);
      }
    }
  }

  private send(method: string, params?: unknown): Promise<unknown> {
    const id = ++this.proc.requestId;
    const msg = { jsonrpc: "2.0", id, method, params };
    return new Promise((resolve, reject) => {
      this.proc.pending.set(id, { resolve, reject });
      this.proc.proc.stdin!.write(JSON.stringify(msg) + "\n");
    });
  }

  async initialize(): Promise<void> {
    const result = (await this.send("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "ainish-coder-mcp-bridge", version: "1.0.0" },
    })) as any;
    console.error(\`[mcp-bridge] Initialized, server: \${result?.serverInfo?.name || "unknown"}\`);
    await this.send("notifications/initialized", {});
  }

  async listTools(): Promise<McpToolDef[]> {
    const result = (await this.send("tools/list", {})) as any;
    return result?.tools || [];
  }

  async callTool(name: string, args: Record<string, unknown>): Promise<unknown> {
    return this.send("tools/call", { name, arguments: args });
  }

  async close(): Promise<void> {
    this.proc.proc.kill();
  }
}

// ── Pi Extension Export ─────────────────────────────────────────────────────

const clients: Map<string, McpClient> = new Map();
let initialized = false;

async function ensureInit() {
  if (initialized) return;
  for (const server of SERVERS) {
    try {
      const client = new McpClient(server);
      await client.initialize();
      const tools = await client.listTools();
      client["_tools"] = tools;
      clients.set(server.name, client);
      console.error(\`[mcp-bridge] Loaded \${tools.length} tools from \${server.name}\`);
    } catch (e: any) {
      console.error(\`[mcp-bridge] Failed to init \${server.name}: \${e.message}\`);
    }
  }
  initialized = true;
}

export async function getTools(): Promise<any[]> {
  await ensureInit();
  const tools: any[] = [];
  for (const [serverName, client] of clients) {
    const rawTools = (client as any)["_tools"] || [];
    for (const tool of rawTools) {
      tools.push({
        name: \`mcp_\${serverName}_\${tool.name}\`,
        description: \`[\${serverName}] \${tool.description}\`,
        parameters: tool.inputSchema || { type: "object", properties: {} },
        execute: async (params: Record<string, unknown>) => {
          const result = await client.callTool(tool.name, params);
          return JSON.stringify(result);
        },
      });
    }
  }
  return tools;
}

export async function cleanup() {
  for (const [, client] of clients) {
    await client.close();
  }
}
EXTEOF

  echo "$ext_file"
}

# Generate mini-swe-agent MCP environment config.
# mini doesn't support extensions natively, so we expose MCP servers as
# environment variables that custom mini configs can reference.
mcp_generate_mini_env() {
  mcp_generate_env "$1"
}
