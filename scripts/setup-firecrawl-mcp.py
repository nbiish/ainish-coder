#!/usr/bin/env python3
"""
Add firecrawl-mcp server to ~/.deepseek/config.toml (codewhale MCP config).

Usage:
    python3 scripts/setup-firecrawl-mcp.py

Security note: The API key is embedded in this script for setup convenience.
Once configured, rotate the key and inject via environment variable or vault.
"""

import os
import sys
import tomllib
from pathlib import Path

CONFIG_PATH = Path.home() / ".deepseek" / "config.toml"
FIRE CRAWL_CONFIG = {
    "command": "npx",
    "args": ["-y", "firecrawl-mcp"],
}

ENV_CONFIG = {
    "FIRECRAWL_API_KEY": "fc-afe800184a1e4af3bffc4b56f590b085",
}


def main():
    if not CONFIG_PATH.exists():
        print(f"Config not found: {CONFIG_PATH}")
        print("Creating minimal config...")
        CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
        config = {}
    else:
        with open(CONFIG_PATH, "rb") as f:
            config = tomllib.load(f)
        print(f"Read existing config: {CONFIG_PATH}")

    # Add mcp_servers section
    mcp = config.setdefault("mcp_servers", {})

    if "firecrawl-mcp" in mcp:
        print("firecrawl-mcp already configured. Updating...")
    else:
        print("Adding firecrawl-mcp server...")

    mcp["firecrawl-mcp"] = FIRE CRAWL_CONFIG

    # Add env section for the API key
    env = config.setdefault("env", {})
    env["firecrawl-mcp"] = ENV_CONFIG

    # Write back
    with open(CONFIG_PATH, "w") as f:
        f.write("# codewhale (DeepSeek TUI) configuration\n")
        f.write("# Managed by scripts/setup-firecrawl-mcp.py\n\n")

        for section, values in config.items():
            if section == "mcp_servers":
                f.write("[mcp_servers]\n")
                for name, cfg in values.items():
                    f.write(f"\n[mcp_servers.{name}]\n")
                    f.write(f'command = "{cfg["command"]}"\n')
                    f.write(f'args = {cfg["args"]}\n')
                f.write("\n")

            elif section == "env":
                f.write("[env]\n")
                for name, vars_ in values.items():
                    f.write(f"\n[env.{name}]\n")
                    for k, v in vars_.items():
                        f.write(f'{k} = "{v}"\n')
                f.write("\n")

            else:
                # Write other sections as-is (simplified — preserves only what's in parsed dict)
                f.write(f"[{section}]\n")
                if isinstance(values, dict):
                    for k, v in values.items():
                        if isinstance(v, str):
                            f.write(f'{k} = "{v}"\n')
                        elif isinstance(v, bool):
                            f.write(f"{k} = {str(v).lower()}\n")
                        elif isinstance(v, (int, float)):
                            f.write(f"{k} = {v}\n")
                        else:
                            f.write(f"{k} = {v}\n")

    print("✓ firecrawl-mcp configured in ~/.deepseek/config.toml")
    print("  Restart codewhale to pick up the new MCP server.")
    print()
    print("Security reminder:")
    print("  - This API key is written to disk. Rotate it after testing.")
    print("  - For production, inject via vault or env variable instead.")
    print(f"  - Consider running: detect-secrets scan {CONFIG_PATH}")


if __name__ == "__main__":
    main()
