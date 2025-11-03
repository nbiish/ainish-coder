#!/usr/bin/env bash
# deploy_trae.sh - Deploy TRAE configuration, ignore rules, and MCP template
# Adds .traeignore, .trae-rules.md, and .trae/mcp.json to target project

set -euo pipefail

# Load atoms if available (colors, file ops)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POPULATION_DIR="${SCRIPT_DIR}/.."
if [[ -f "${POPULATION_DIR}/atoms/colors.sh" ]]; then
    # shellcheck source=/dev/null
    source "${POPULATION_DIR}/atoms/colors.sh" || true
fi
if [[ -f "${POPULATION_DIR}/atoms/file_operations.sh" ]]; then
    # shellcheck source=/dev/null
    source "${POPULATION_DIR}/atoms/file_operations.sh" || true
fi

echo_info() { printf "\e[36m%s\e[0m\n" "[TRAe] $*"; }
echo_warning() { printf "\e[33m%s\e[0m\n" "[TRAE] $*"; }
echo_error() { printf "\e[31m%s\e[0m\n" "[TRAE] $*"; }
echo_success() { printf "\e[32m%s\e[0m\n" "[TRAE] $*"; }

audit_trae_deployment() {
    local target_dir="$1"
    local sensitive_patterns=(
        ".env"
        "*.key"
        "*.pem"
        "*secret*"
        "*password*"
        "config/production*"
    )

    for pattern in "${sensitive_patterns[@]}"; do
        if find "$target_dir" -name "$pattern" 2>/dev/null | grep -q .; then
            echo_error "Sensitive files detected matching: $pattern"
            return 1
        fi
    done
    return 0
}

deploy_trae() {
    # deploy_trae [TARGET_DIR]
    local target_dir="${1:-$(pwd)}"

    echo_info "Deploying TRAE rules (copy AGENTS.md) to: $target_dir"

    if [[ ! -d "$target_dir" ]]; then
        echo_error "Target directory does not exist: $target_dir"
        return 1
    fi

    # Locate repository root and AGENTS.md
    local repo_root
    repo_root="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    local agents_src="$repo_root/AGENTS.md"

    if [[ ! -f "$agents_src" ]]; then
        echo_error "AGENTS.md not found in repository root: $agents_src"
        return 1
    fi

    # Destination path inside target project for TRAE rules
    local dest_dir="$target_dir/.trae/rules"
    mkdir -p "$dest_dir"

    cp "$agents_src" "$dest_dir/AGENTS.md"
    echo_success "Copied AGENTS.md → $dest_dir/AGENTS.md"

    echo_info "TRAE will automatically load rules from .trae/rules/ directory."
    echo_info "Invoke rules in chat using: #AGENTS"
    echo_success "TRAE rules deployment complete for: $target_dir"
}

# If script executed directly, run deploy_trae with args
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    deploy_trae "$@"
fi
