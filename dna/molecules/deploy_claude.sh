#!/bin/bash
# MOLECULE: Claude Code deployment
# Comprehensive Claude Code configuration deployment:
# - AGENTS.md and MAIRULES.md to .claude/rules/
# - Commands from .configs/.claude/commands/
# Requires AGENTS.md to exist first

deploy_claude() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Full Claude Code Configuration${RESET}"
    
    # Create directory structure
    local claude_rules_dir="$target_dir/.claude/rules"
    local claude_commands_dir="$target_dir/.claude/commands"
    safe_mkdir "$claude_rules_dir" || return 1
    safe_mkdir "$claude_commands_dir" || return 1
    
    # Deploy rules
    if cp "$target_dir/AGENTS.md" "$claude_rules_dir/AGENTS.md"; then
        echo -e "${GREEN}✓ Copied: AGENTS.md → .claude/rules/AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy AGENTS.md${RESET}"
        return 1
    fi
    
    # Deploy commands from .configs
    if [[ -d "$source_dir/.configs/.claude/commands" ]]; then
        local cmd_count=0
        for cmd_file in "$source_dir/.configs/.claude/commands"/*.md; do
            if [[ -f "$cmd_file" ]]; then
                local filename=$(basename "$cmd_file")
                cp "$cmd_file" "$claude_commands_dir/$filename"
                ((cmd_count++))
                echo -e "${GREEN}✓ Deployed: .claude/commands/$filename${RESET}"
            fi
        done
        if [[ $cmd_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $cmd_count Claude Code command(s)${RESET}"
        fi
    fi

    # Deploy skills
    deploy_claude_skills "$target_dir"
    
    echo -e "${BRIGHT_GREEN}✅ Claude Code fully configured${RESET}"
    echo -e "${BLUE}💡 Commands available via / in Claude Code${RESET}"
    return 0
}

deploy_claude_skills() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    echo -e "${BRIGHT_BLUE}Deploying Claude Code Skills${RESET}"
    
    local claude_skills_dir="$target_dir/.claude/skills"
    
    if [[ -d "$source_dir/.configs/.claude/skills" ]]; then
        safe_mkdir "$claude_skills_dir" || return 1
        local skill_count=0
        
        # Deploy each skill directory
        for skill_dir in "$source_dir/.configs/.claude/skills"/*; do
            if [[ -d "$skill_dir" ]]; then
                local skill_name=$(basename "$skill_dir")
                local target_skill_dir="$claude_skills_dir/$skill_name"
                
                # Create target skill directory
                safe_mkdir "$target_skill_dir" || return 1
                
                # Copy skill files
                cp -r "$skill_dir"/* "$target_skill_dir/" 2>/dev/null || true
                
                ((skill_count++))
                echo -e "${GREEN}✓ Deployed: .claude/skills/$skill_name${RESET}"
            fi
        done
        
        if [[ $skill_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $skill_count skill(s)${RESET}"
        else
            echo -e "${YELLOW}⚠ No skills found to deploy${RESET}"
        fi
    else
        echo -e "${YELLOW}⚠ Skills source directory not found${RESET}"
    fi
}
