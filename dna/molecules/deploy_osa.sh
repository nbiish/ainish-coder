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

    local osa_dir="$target_dir/.osa"
    echo -e "${BRIGHT_BLUE}Deploying OSA Framework to: $osa_dir${RESET}"

    # Create .osa directory
    if ! mkdir -p "$osa_dir"; then
        print_error "Failed to create directory: $osa_dir"
        return 1
    fi
    
    local files=("OSA.toon" "llms.txt")
    local success=0

    for file in "${files[@]}"; do
        local src_file="$source_dir/.osa/$file"
        local dest_file="$osa_dir/$file"
        
        if [[ -f "$src_file" ]]; then
            cp "$src_file" "$dest_file"
            echo -e "${GREEN}✓ Deployed: $file${RESET}"
            ((success++))
        else
            echo -e "${YELLOW}⚠ Warning: $file not found in source ($src_file)${RESET}"
        fi
    done

    if [[ $success -gt 0 ]]; then
        echo -e "${BRIGHT_GREEN}✅ OSA Framework deployed to $osa_dir${RESET}"
    else
        echo -e "${YELLOW}⚠ OSA Framework partially deployed or empty${RESET}"
    fi

    return 0
}
