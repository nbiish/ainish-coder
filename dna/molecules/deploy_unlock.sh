#!/bin/bash
# MOLECULE: Unlock deployment — deploys pliny research collection
# Activates via: ainish-coder --unlock [TARGET_DIR]
# Deploys the complete pliny-research skill pack with AI transparency research

deploy_unlock() {
    local target_dir="${1:-.}"

    validate_target_dir "$target_dir" || return 1

    echo -e "${BRIGHT_BLUE}🔓 Deploying Pliny Research — AI Transparency & Observability${RESET}"

    # Determine source paths
    local skills_source="${REPO_DIR}/.agents/skills/pliny-research"
    local research_source="${REPO_DIR}/pliny-research"
    local skills_target="${target_dir}/.agents/skills/pliny-research"

    if [[ ! -d "$skills_source" ]]; then
        print_error "Pliny research skill source not found: $skills_source"
        return 1
    fi

    # Create target skills directory
    safe_mkdir "$skills_target" || return 1

    # Deploy the SKILL.md
    if [[ -f "$skills_source/SKILL.md" ]]; then
        cp "$skills_source/SKILL.md" "$skills_target/SKILL.md" 2>/dev/null || true
        echo -e "${GREEN}✓ Deployed: .agents/skills/pliny-research/SKILL.md${RESET}"
    fi

    # Deploy the full pliny-research collection if available
    if [[ -d "$research_source" ]]; then
        local research_target="$skills_target/research"
        safe_mkdir "$research_target" || return 1

        # Copy all research collections (CL4R1T4S, L1B3RT4S, G0DM0D3, OBLITERATUS)
        local collection_count=0
        for collection in "$research_source"/*/; do
            if [[ -d "$collection" ]]; then
                local coll_name=$(basename "$collection")
                local coll_target="$research_target/$coll_name"

                safe_mkdir "$coll_target" || return 1
                cp -r "$collection"* "$coll_target/" 2>/dev/null || true

                ((collection_count++))
                echo -e "${GREEN}✓ Deployed research collection: $coll_name${RESET}"
            fi
        done

        if [[ $collection_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✓ Deployed $collection_count research collection(s)${RESET}"
        fi
    else
        echo -e "${YELLOW}⚠ Full pliny-research collection not found at $research_source${RESET}"
        echo -e "${YELLOW}  Only SKILL.md was deployed. Clone the full repo for complete research.${RESET}"
    fi

    echo ""
    echo -e "${BRIGHT_CYAN}🔓 Pliny Research Unlocked!${RESET}"
    echo -e "${WHITE}Explore:${RESET} ${GREEN}$skills_target${RESET}"
    echo -e "${WHITE}Start with:${RESET} cat $skills_target/SKILL.md"
    echo -e "${WHITE}Collections:${RESET} $skills_target/research/"

    return 0
}
