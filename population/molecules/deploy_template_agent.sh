#!/bin/bash
# MOLECULE: Template Agent deployment
# Deploys template-agent.md for custom agent system prompt crafting
# Requires AGENTS.md to exist first

deploy_template_agent() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Template Agent System${RESET}"
    
    # Deploy to .mai-rules directory
    local rules_dir="$target_dir/.mai-rules"
    safe_mkdir "$rules_dir" || return 1
    
    local template_agent="$rules_dir/template-agent.md"
    local source_template="$source_dir/.mai-rules/template-agent.md"
    
    if [[ -f "$source_template" ]]; then
        cp "$source_template" "$template_agent"
        echo -e "${GREEN}✓ Deployed: template-agent.md${RESET}"
        echo -e "${CYAN}  └─ Location: $template_agent${RESET}"
        echo -e "${YELLOW}  └─ Edit this file to craft your agent's constitution${RESET}"
    else
        echo -e "${YELLOW}⚠ Warning: template-agent.md not found in source${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Template Agent System deployed${RESET}"
    echo -e "${CYAN}Next steps:${RESET}"
    echo -e "${CYAN}  1. Open: $template_agent${RESET}"
    echo -e "${CYAN}  2. Fill in the [FILL_IN] sections${RESET}"
    echo -e "${CYAN}  3. Iterate based on agent behavior${RESET}"
    return 0
}
