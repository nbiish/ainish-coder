#!/usr/bin/env bash
# deploy_mcp.sh - Deploys the mcp.json file to the .trae directory

set -euo pipefail

# Load atoms if available (colors, file ops)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DNA_DIR="${SCRIPT_DIR}/.."
if [[ -f "${DNA_DIR}/atoms/colors.sh" ]]; then
    # shellcheck source=/dev/null
    source "${DNA_DIR}/atoms/colors.sh" || true
fi
if [[ -f "${DNA_DIR}/atoms/file_operations.sh" ]]; then
    # shellcheck source=/dev/null
    source "${DNA_DIR}/atoms/file_operations.sh" || true
fi

echo_info() { printf "\e[36m%s\e[0m\n" "[MCP] $*"; }
echo_error() { printf "\e[31m%s\e[0m\n" "[MCP] $*"; }
echo_success() { printf "\e[32m%s\e[0m\n" "[MCP] $*"; }

deploy_mcp() {
    # deploy_mcp [TARGET_DIR]
    local target_dir="${1:-$(pwd)}"

    echo_info "Deploying MCP configuration to: $target_dir"

    if [[ ! -d "$target_dir" ]]; then
        echo_error "Target directory does not exist: $target_dir"
        return 1
    fi

    # Locate repository root and mcp.json
    local repo_root
    repo_root="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    local mcp_src="$repo_root/.configs/MCP/mcp.json"

    if [[ ! -f "$mcp_src" ]]; then
        echo_error "mcp.json not found in repository root: $mcp_src"
        return 1
    fi

    # Destination path inside target project for MCP configuration
    local dest_dir="$target_dir/.trae"
    mkdir -p "$dest_dir"

    cp "$mcp_src" "$dest_dir/mcp.json"
    echo_success "Copied mcp.json → $dest_dir/mcp.json"

    echo_success "MCP configuration deployment complete for: $target_dir"
}

# If script executed directly, run deploy_mcp with args
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    deploy_mcp "$@"
fi