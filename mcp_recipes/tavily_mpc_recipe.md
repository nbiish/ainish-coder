# Tavily MCP Server

## Setup

Ensure you have your API key exported:

```bash
export TAVILY_API_KEY="tvly-..."
```

## Single Command Usage

To use the tools directly from the CLI with a single command, you can use the following Node.js wrapper. Save this as `mcp-client.js`:

```javascript
const { spawn } = require('child_process');

const [,, toolName, argsJson] = process.argv;
if (!toolName || !argsJson) {
  console.error('Usage: node mcp-client.js <tool-name> <json-args>');
  process.exit(1);
}

const cp = spawn('npx', ['-y', 'tavily-mcp'], {
  stdio: ['pipe', 'pipe', 'inherit'],
  env: process.env
});

let buffer = '';
let step = 0;

cp.stdout.on('data', (data) => {
  buffer += data.toString();
  const lines = buffer.split('\n');
  buffer = lines.pop();

  for (const line of lines) {
    if (!line.trim()) continue;
    try {
      const msg = JSON.parse(line);
      if (step === 0 && msg.id === 1) {
        step++;
        send({ jsonrpc: "2.0", method: "notifications/initialized" });
        send({
          jsonrpc: "2.0",
          method: "tools/call",
          id: 2,
          params: {
            name: toolName,
            arguments: JSON.parse(argsJson)
          }
        });
      } else if (step === 1 && msg.id === 2) {
        console.log(JSON.stringify(msg.result, null, 2));
        process.exit(0);
      }
    } catch (e) {}
  }
});

function send(msg) {
  cp.stdin.write(JSON.stringify(msg) + '\n');
}

send({
  jsonrpc: "2.0",
  method: "initialize",
  id: 1,
  params: { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "cli", version: "1" } }
});
```

**Example Usage:**

```bash
node mcp-client.js tavily-search '{"query": "Who are the Anishinaabe?", "max_results": 1}'
```

## Available Tools

### `tavily-search`

**Parameters:**
- `query` (string, required): Search query.
- `search_depth` (string, optional): "basic", "advanced", "fast", or "ultra-fast" (default: "basic").
- `topic` (string, optional): "general" or "news" (default: "general").
- `days` (number, optional): Days back for news (default: 3).
- `time_range` (string, optional): "day", "week", "month", "year".
- `max_results` (number, optional): Max results (5-20, default: 10).
- `include_images` (boolean, optional): Include image URLs (default: false).
- `include_image_descriptions` (boolean, optional): Include image descriptions (default: false).
- `include_raw_content` (boolean, optional): Include raw HTML (default: false).
- `include_domains` (array[string], optional): Domains to include.
- `exclude_domains` (array[string], optional): Domains to exclude.
- `country` (string, optional): Country code (e.g., "us", "uk").
- `include_favicon` (boolean, optional): Include favicon URLs (default: false).

### `tavily-extract`

**Parameters:**
- `urls` (array[string], required): List of URLs.
- `extract_depth` (string, optional): "basic" or "advanced" (default: "basic").
- `include_images` (boolean, optional): Include images (default: false).
- `format` (string, optional): "markdown" or "text" (default: "markdown").
- `include_favicon` (boolean, optional): Include favicon URLs (default: false).
- `query` (string, optional): Reranking query.

### `tavily-map`

**Parameters:**
- `url` (string, required): Root URL to map.
- `max_depth` (integer, optional): Max depth (default: 1).
- `max_breadth` (integer, optional): Max links per page (default: 20).
- `limit` (integer, optional): Total links limit (default: 50).
- `instructions` (string, optional): Crawler instructions.
- `select_paths` (array[string], optional): Regex for paths.
- `select_domains` (array[string], optional): Regex for domains.
- `allow_external` (boolean, optional): Allow external links (default: true).

### `tavily-crawl`

**Parameters:**
- `url` (string, required): Root URL to crawl.
- `max_depth` (integer, optional): Max depth (default: 1).
- `max_breadth` (integer, optional): Max links per page (default: 20).
- `limit` (integer, optional): Total links limit (default: 50).
- `instructions` (string, optional): Crawler instructions.
- `select_paths` (array[string], optional): Regex for paths.
- `select_domains` (array[string], optional): Regex for domains.
- `allow_external` (boolean, optional): Allow external links (default: true).
- `extract_depth` (string, optional): "basic" or "advanced" (default: "basic").
- `format` (string, optional): "markdown" or "text" (default: "markdown").
- `include_favicon` (boolean, optional): Include favicon URLs (default: false).
