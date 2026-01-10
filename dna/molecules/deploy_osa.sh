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

    echo -e "${BRIGHT_BLUE}Deploying OSA 4.0 (Memori-Driven) Orchestration Framework${RESET}"

    local files=("OSA.md" "OSAVARS.toon" "llms.txt" "TODO.md")
    local success=0

    for file in "${files[@]}"; do
        if [[ -f "$source_dir/$file" ]]; then
            cp "$source_dir/$file" "$target_dir/$file"
            echo -e "${GREEN}✓ Deployed: $file${RESET}"
            ((success++))
        else
            echo -e "${YELLOW}⚠ Warning: $file not found in source${RESET}"
        fi
    done

    if [[ $success -eq ${#files[@]} ]]; then
        echo -e "${BRIGHT_GREEN}✅ OSA Framework (v4.0) fully deployed${RESET}"
    else
        echo -e "${YELLOW}⚠ OSA Framework partially deployed ($success/${#files[@]} files)${RESET}"
    fi

    # Check for Memori CLI
    if ! command -v memori &> /dev/null; then
        echo -e "${YELLOW}⚠ Warning: 'memori' CLI not found.${RESET}"
        echo -e "${CYAN}  Please install it: npm install -g @memorilabs/memori${RESET}"
    else
        echo -e "${GREEN}✓ 'memori' CLI detected${RESET}"
    fi

    echo -e "${CYAN}Next steps:${RESET}"
    echo -e "${CYAN}  1. Initialize collective memory: memori init${RESET}"
    echo -e "${CYAN}  2. Start Trunk: claude -p \"/ralph-loop 'Initiate framework...'\"${RESET}"
    echo -e "${CYAN}  3. Ralph (Claude) will use Memori to coordinate Gemini and Qwen branches${RESET}"
    return 0
}
