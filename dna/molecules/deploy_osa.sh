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

    echo -e "${BRIGHT_BLUE}Deploying OSA (Ralph-First) Orchestration Framework${RESET}"

    local files=("OSA.md" "OSAVARS.md" "llms.txt" "TODO.md")
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

    # Deploy Expert Core (Python)
    if [[ -d "$source_dir/osa_expert" ]]; then
        echo -e "${BRIGHT_BLUE}Deploying OSA Expert Core...${RESET}"
        # Use rsync if available for better directory copying, otherwise use cp
        if command -v rsync &> /dev/null; then
            rsync -a --exclude='.venv' "$source_dir/osa_expert/" "$target_dir/osa_expert/"
        else
            mkdir -p "$target_dir/osa_expert"
            cp -R "$source_dir/osa_expert/." "$target_dir/osa_expert/"
            # Remove .venv if it was copied (we want to re-sync)
            rm -rf "$target_dir/osa_expert/.venv"
        fi
        
        # Initialize uv environment if uv is available
        if command -v uv &> /dev/null; then
            echo -e "${CYAN}Syncing Expert Core environment (uv)...${RESET}"
            (cd "$target_dir/osa_expert" && uv sync)
            echo -e "${GREEN}✓ Expert Core environment synced${RESET}"
        else
            echo -e "${YELLOW}⚠ Warning: 'uv' not found. Please install uv to use the Expert Core.${RESET}"
        fi
        ((success++))
    fi

    if [[ $success -ge ${#files[@]} ]]; then
        echo -e "${BRIGHT_GREEN}✅ OSA Framework (v4.0) deployed with Expert Core${RESET}"
    else
        echo -e "${YELLOW}⚠ OSA Framework partially deployed ($success/$(( ${#files[@]} + 1 )) modules)${RESET}"
    fi

    echo -e "${CYAN}Next steps:${RESET}"
    echo -e "${CYAN}  1. Initialize Expert Core: python -m osa_expert bootstrap${RESET}"
    echo -e "${CYAN}  2. Start Trunk: claude -p \"/ralph-loop 'Initiate framework...'\"${RESET}"
    echo -e "${CYAN}  3. Use 'osa-expert query' for deep codebase intelligence${RESET}"
    return 0
}
