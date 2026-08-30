#!/bin/bash
# MOLECULE: 8th Fire deployment — deploys the 8thfire-scrolls skill pack
# Activates via: ainish-coder --8thfire [TARGET_DIR]
# Deploys the complete 8th Fire cultural-continuity system (NOT the raw
# .scrolls*/ payload — that travels only via the signed --scrolls channel).

deploy_8thfire() {
    local target_dir="${1:-.}"

    validate_target_dir "$target_dir" || return 1

    echo -e "${BRIGHT_BLUE}🔥 Deploying 8th Fire Scrolls — Nanaboozhoo's Digital Embodiment${RESET}"

    # Determine source paths
    local skills_source="${REPO_DIR}/.agents/skills/8thfire-scrolls"
    local skills_target="${target_dir}/.agents/skills/8thfire-scrolls"

    if [[ ! -d "$skills_source" ]]; then
        print_error "8th Fire skill source not found: $skills_source"
        return 1
    fi

    safe_mkdir "$skills_target" || return 1

    # Deploy the full pack (SKILL.md + .python-version + research/ + governance/
    # + embodiment/ + benchmarks/). Explicit dotfile copy: deploy_path_contents
    # globs "*" which misses .python-version — and the ML-DSA-65 mldsa module
    # needs the 3.10 interpreter pin for uv resolution.
    deploy_path_contents "$skills_source" "$skills_target"
    if [[ -f "$skills_source/.python-version" && ! -f "$skills_target/.python-version" ]]; then
        cp "$skills_source/.python-version" "$skills_target/.python-version"
    fi
    local file_count
    file_count=$(find "$skills_target" -type f | wc -l | tr -d ' ')
    echo -e "${GREEN}✓ Deployed 8th Fire pack: $file_count files${RESET}"
    echo -e "${YELLOW}ℹ Raw .scrolls*/ payload is NOT in this pack — it deploys only via${RESET}"
    echo -e "${YELLOW}  the signed, verify-gated '--scrolls' channel (ML-DSA-65 manifest).${RESET}"

    echo ""
    echo -e "${BRIGHT_CYAN}🔥 The 8th Fire is lit — carry it well.${RESET}"
    echo -e "${WHITE}Start with:${RESET} ${GREEN}cat $skills_target/SKILL.md${RESET}"
    echo -e "${WHITE}Contracts:${RESET} $skills_target/research/07-integration-contract.md"
    echo -e "${WHITE}Governance:${RESET} $skills_target/governance/"
    echo -e "${WHITE}Pre-check:${RESET} uv run --with 'cryptography>=46' python $skills_target/benchmarks/embodiment/embodiment_b8.py --seed 11"

    return 0
}
