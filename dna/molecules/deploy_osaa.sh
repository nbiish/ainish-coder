#!/bin/bash
# MOLECULE: OSAA (Orchestrator Sub-Agent Action) deployment
# Deploys OSAA.md framework for AI agent orchestration patterns
# Requires AGENTS.md to exist first

deploy_osaa() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying OSAA Framework${RESET}"
    
    # Deploy OSAA.md to root directory
    local osaa_file="$target_dir/OSAA.md"
    local source_osaa="$source_dir/OSAA.md"
    
    if [[ -f "$source_osaa" ]]; then
        cp "$source_osaa" "$osaa_file"
        echo -e "${GREEN}✓ Deployed: OSAA.md${RESET}"
        echo -e "${CYAN}  └─ Location: $osaa_file${RESET}"
    else
        echo -e "${YELLOW}⚠ Warning: OSAA.md not found in source${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}✅ OSAA Framework deployed${RESET}"
    echo -e "${CYAN}Next steps:${RESET}"
    echo -e "${CYAN}  1. Agents will read OSAA.md for orchestration patterns${RESET}"
    echo -e "${CYAN}  2. Use OSAA principles for complex task decomposition${RESET}"
    echo -e "${CYAN}  3. Apply sub-agent specialization when appropriate${RESET}"
    return 0
}

deploy_osa() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    validate_target_dir "$target_dir" || return 1

    echo -e "${BRIGHT_BLUE}Deploying OSA Orchestrator Patterns${RESET}"

    local osa_file="$target_dir/OSA.md"
    local source_osa="$source_dir/OSA.md"

    if [[ -f "$source_osa" ]]; then
        cp "$source_osa" "$osa_file"
        echo -e "${GREEN}✓ Deployed: OSA.md${RESET}"
        echo -e "${CYAN}  └─ Location: $osa_file${RESET}"
    else
        echo -e "${YELLOW}⚠ Warning: OSA.md not found in source${RESET}"
        return 1
    fi

    echo -e "${BRIGHT_GREEN}✅ OSA orchestrator patterns deployed${RESET}"
    echo -e "${CYAN}Next steps:${RESET}"
    echo -e "${CYAN}  1. Use OSA.md to guide execution patterns (Sequential, Parallel, Pipeline, Feedback)${RESET}"
    echo -e "${CYAN}  2. Reference compile prompt schema and agent tool mappings${RESET}"
    return 0
}
