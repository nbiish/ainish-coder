#!/bin/bash
# MOLECULE: Pi Coding Agent deployment
# Comprehensive Pi Coding Agent configuration deployment:
# - Extensions from .configs/.pi/extensions/
# - Agent definitions from .configs/.pi/agents/
# - Skills from .configs/.pi/skills/
# - Themes from .configs/.pi/themes/
# - Settings and damage control rules

deploy_pi() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Pi Coding Agent Configuration${RESET}"
    
    # Create directory structure
    local pi_dir="$target_dir/.pi"
    local pi_extensions_dir="$pi_dir/extensions"
    local pi_agents_dir="$pi_dir/agents"
    local pi_skills_dir="$pi_dir/skills"
    local pi_themes_dir="$pi_dir/themes"
    
    safe_mkdir "$pi_dir" || return 1
    safe_mkdir "$pi_extensions_dir" || return 1
    safe_mkdir "$pi_agents_dir" || return 1
    safe_mkdir "$pi_skills_dir" || return 1
    safe_mkdir "$pi_themes_dir" || return 1
    
    # Deploy extensions
    local ext_source="${source_dir}/.configs/.pi/extensions"
    if [[ -d "$ext_source" ]]; then
        cp -r "$ext_source"/* "$pi_extensions_dir/" 2>/dev/null || true
        echo -e "${GREEN}✓ Deployed Pi extensions${RESET}"
    fi
    
    # Deploy agents
    local agent_source="${source_dir}/.configs/.pi/agents"
    if [[ -d "$agent_source" ]]; then
        cp -r "$agent_source"/* "$pi_agents_dir/" 2>/dev/null || true
        echo -e "${GREEN}✓ Deployed Pi agents${RESET}"
    fi
    
    # Deploy skills
    local skill_source="${source_dir}/.configs/.pi/skills"
    if [[ -d "$skill_source" ]]; then
        cp -r "$skill_source"/* "$pi_skills_dir/" 2>/dev/null || true
        echo -e "${GREEN}✓ Deployed Pi skills${RESET}"
    fi
    
    # Deploy themes
    local theme_source="${source_dir}/.configs/.pi/themes"
    if [[ -d "$theme_source" ]]; then
        cp -r "$theme_source"/* "$pi_themes_dir/" 2>/dev/null || true
        echo -e "${GREEN}✓ Deployed Pi themes${RESET}"
    fi
    
    # Deploy settings
    local settings_source="${source_dir}/.configs/.pi/settings.json"
    if [[ -f "$settings_source" ]]; then
        cp "$settings_source" "$pi_dir/settings.json"
        echo -e "${GREEN}✓ Copied: settings.json${RESET}"
    fi
    
    # Deploy damage control rules
    local dmgctrl_source="${source_dir}/.configs/.pi/damage-control-rules.yaml"
    if [[ -f "$dmgctrl_source" ]]; then
        cp "$dmgctrl_source" "$pi_dir/damage-control-rules.yaml"
        echo -e "${GREEN}✓ Copied: damage-control-rules.yaml${RESET}"
    fi
    
    # Deploy documentation
    local docs_source="${source_dir}/.configs/.pi"
    for doc in CLAUDE.md THEME.md TOOLS.md; do
        if [[ -f "$docs_source/$doc" ]]; then
            cp "$docs_source/$doc" "$pi_dir/$doc"
            echo -e "${GREEN}✓ Copied: $doc${RESET}"
        fi
    done
    
    # Deploy justfile
    local justfile_source="${source_dir}/.configs/.pi/justfile"
    if [[ -f "$justfile_source" ]]; then
        # Copy to .pi/justfile
        cp "$justfile_source" "$pi_dir/justfile"
        echo -e "${GREEN}✓ Copied: .pi/justfile${RESET}"
        
        # Check if justfile exists in root, if not, suggest copying or copy it
        if [[ ! -f "$target_dir/justfile" ]]; then
            # Copy to root as well for convenience
            cp "$justfile_source" "$target_dir/justfile"
            echo -e "${GREEN}✓ Copied: justfile (to root)${RESET}"
        else
            echo -e "${YELLOW}⚠ justfile already exists in root, skipping copy. (Available in .pi/justfile)${RESET}"
        fi
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Pi Coding Agent fully configured${RESET}"
    echo -e "${BLUE}💡 Run with: pi${RESET}"
    echo -e "${BLUE}💡 Extensions: pi -e .pi/extensions/<name>.ts${RESET}"
    if command -v just >/dev/null 2>&1; then
        echo -e "${BLUE}💡 Just recipes available: run 'just' to list${RESET}"
    else
        echo -e "${YELLOW}💡 Install 'just' to use recipes: brew install just${RESET}"
    fi
    return 0
}
