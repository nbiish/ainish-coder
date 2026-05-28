#!/usr/bin/env bash
# Set up firecrawl-mcp in ~/.deepseek/mcp.json for CodeWhale
set -euo pipefail

MCP_FILE="$HOME/.deepseek/mcp.json"

mkdir -p "$HOME/.deepseek"

if [[ -f "$MCP_FILE" ]]; then
    echo "Existing mcp.json found. Adding/updating firecrawl-mcp..."
    python3 -c "
import json, sys

path = '$MCP_FILE'
with open(path) as f:
    config = json.load(f)

# Normalize to 'servers' key
servers = config.get('servers') or config.get('mcpServers') or {}
config['servers'] = servers
config.pop('mcpServers', None)

servers['firecrawl-mcp'] = {
    'command': 'npx',
    'args': ['-y', 'firecrawl-mcp'],
    'env': {
        'FIRECRAWL_API_KEY': 'fc-afe800184a1e4af3bffc4b56f590b085'
    }
}

with open(path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')

print('✓ firecrawl-mcp added to existing mcp.json')
"
else
    echo "Creating new mcp.json..."
    cat > "$MCP_FILE" << 'EOF'
{
  "servers": {
    "firecrawl-mcp": {
      "command": "npx",
      "args": ["-y", "firecrawl-mcp"],
      "env": {
        "FIRECRAWL_API_KEY": "fc-afe800184a1e4af3bffc4b56f590b085"
      }
    }
  }
}
EOF
    echo "✓ Created ~/.deepseek/mcp.json with firecrawl-mcp"
fi

echo ""
echo "Verify with:"
echo "  codewhale-tui mcp list"
echo "  codewhale-tui mcp validate"
echo ""
echo "Restart codewhale to load the new tools."
