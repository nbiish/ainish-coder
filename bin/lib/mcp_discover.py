#!/usr/bin/env python3
"""
Discover MCP server definitions from host AI tool configs (pi/omp parity).

Outputs JSON: { "mcpServers": { name: { command, args, env, description, _discoveredFrom } } }

Merge priority (handled by mcp_settings.sh): discovered < ~/.agents global < project .agents
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

HOME = Path.home()
CWD = Path(os.environ.get("AINISH_MCP_DISCOVER_CWD", os.getcwd()))


def _read_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return None


def _normalize_server(name: str, raw: dict[str, Any], source: str) -> dict[str, Any] | None:
    if not isinstance(raw, dict):
        return None
    out: dict[str, Any] = {
        "description": f"Discovered from {source}",
        "_discoveredFrom": source,
    }
    if raw.get("command"):
        out["command"] = raw["command"]
        out["args"] = raw.get("args") or []
    elif raw.get("url"):
        out["command"] = "npx"
        out["args"] = ["-y", "mcp-remote", str(raw["url"])]
    else:
        return None
    env = raw.get("env")
    if isinstance(env, dict):
        out["env"] = {str(k): str(v) for k, v in env.items()}
    else:
        out["env"] = {}
    transport = raw.get("type") or raw.get("transport")
    if transport in ("sse", "http", "stdio"):
        out["type"] = transport
    return out


def _merge_json_mcp_servers(
    servers: dict[str, dict[str, Any]],
    data: dict[str, Any],
    source: str,
) -> None:
    block = data.get("mcpServers")
    if not isinstance(block, dict):
        return
    for name, cfg in block.items():
        if name in servers:
            continue
        norm = _normalize_server(name, cfg if isinstance(cfg, dict) else {}, source)
        if norm:
            servers[name] = norm


def _discover_json_paths(paths: list[tuple[Path, str]], servers: dict[str, dict[str, Any]]) -> None:
    for path, label in paths:
        if not path.is_file():
            continue
        text = _read_text(path)
        if not text:
            continue
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            continue
        if not isinstance(data, dict):
            continue
        _merge_json_mcp_servers(servers, data, f"{label} ({path})")


def _discover_codex_toml(path: Path, label: str, servers: dict[str, dict[str, Any]]) -> None:
    if not path.is_file():
        return
    text = _read_text(path)
    if not text:
        return
    try:
        import tomllib
    except ImportError:
        try:
            import tomli as tomllib  # type: ignore
        except ImportError:
            return
    try:
        doc = tomllib.loads(text)
    except Exception:
        return
    mcp_servers = doc.get("mcp_servers")
    if not isinstance(mcp_servers, dict):
        return
    for name, cfg in mcp_servers.items():
        if name in servers or not isinstance(cfg, dict):
            continue
        raw: dict[str, Any] = {
            "command": cfg.get("command"),
            "args": cfg.get("args") or [],
            "env": cfg.get("env") or {},
            "url": cfg.get("url"),
            "type": "stdio",
        }
        norm = _normalize_server(name, raw, f"{label} ({path})")
        if norm:
            servers[name] = norm


def discover_all() -> dict[str, dict[str, Any]]:
    servers: dict[str, dict[str, Any]] = {}

    # Claude Code — memory plugin, hooks, MCP
    _discover_json_paths(
        [
            (HOME / ".claude.json", "claude"),
            (HOME / ".claude" / "mcp.json", "claude"),
            (CWD / ".claude" / ".mcp.json", "claude"),
            (CWD / ".claude" / "mcp.json", "claude"),
        ],
        servers,
    )

    # Cursor
    _discover_json_paths(
        [
            (HOME / ".cursor" / "mcp.json", "cursor"),
            (CWD / ".cursor" / "mcp.json", "cursor"),
        ],
        servers,
    )

    # VS Code (Copilot MCP)
    _discover_json_paths(
        [
            (HOME / ".vscode" / "mcp.json", "vscode"),
            (CWD / ".vscode" / "mcp.json", "vscode"),
        ],
        servers,
    )

    # OpenAI Codex — config.toml [mcp_servers], node REPL tooling
    _discover_codex_toml(HOME / ".codex" / "config.toml", "codex", servers)
    _discover_codex_toml(CWD / ".codex" / "config.toml", "codex", servers)

    # Windsurf (Codeium)
    _discover_json_paths(
        [
            (HOME / ".codeium" / "windsurf" / "mcp_config.json", "windsurf"),
            (CWD / ".windsurf" / "mcp_config.json", "windsurf"),
        ],
        servers,
    )

    # Gemini CLI (+ Antigravity shares ~/.gemini settings in pi ecosystem)
    _discover_json_paths(
        [
            (HOME / ".gemini" / "settings.json", "gemini"),
            (CWD / ".gemini" / "settings.json", "gemini"),
        ],
        servers,
    )

    # Standalone project MCP (fallback)
    _discover_json_paths(
        [
            (CWD / "mcp.json", "mcp.json"),
            (CWD / ".mcp.json", "mcp.json"),
        ],
        servers,
    )

    return servers


def main() -> int:
    servers = discover_all()
    print(json.dumps({"mcpServers": servers}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
