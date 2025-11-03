#!/bin/bash
# Deploy GitHub Actions secret protection workflows
# This molecule deploys complete GitHub Actions setup for automatic secret sanitization

deploy_github_actions() {
    local target_dir="$1"
    
    # Validation
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${CYAN}  GitHub Actions Secret Protection${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    
        # Define source paths - Use absolute path from script location
    local ainish_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    local source_workflows="${ainish_root}/.github/workflows"
    local source_root="${ainish_root}"
    
    # Create target directories
    local target_workflows="${target_dir}/.github/workflows"
    mkdir -p "${target_workflows}"
    
    # Deploy workflow files
    echo -e "${BLUE}Deploying workflow files...${RESET}"
    
    # Auto-sanitize workflow
    if [[ -f "${source_workflows}/auto-sanitize.yml" ]]; then
        cp "${source_workflows}/auto-sanitize.yml" "${target_workflows}/auto-sanitize.yml" && \
        print_success "Deployed auto-sanitize.yml"
    fi
    
    # Detect secrets workflow
    if [[ -f "${source_workflows}/detect-secrets.yml" ]]; then
        cp "${source_workflows}/detect-secrets.yml" "${target_workflows}/detect-secrets.yml" && \
        print_success "Deployed detect-secrets.yml"
    fi
    
    # Secret scan workflow (legacy)
    if [[ -f "${source_workflows}/secret-scan.yml" ]]; then
        cp "${source_workflows}/secret-scan.yml" "${target_workflows}/secret-scan.yml" && \
        print_success "Deployed secret-scan.yml"
    fi
    
    # Workflow documentation
    if [[ -f "${source_workflows}/README.md" ]]; then
        cp "${source_workflows}/README.md" "${target_workflows}/README.md" && \
        print_success "Deployed workflows README.md"
    fi
    
    # Deploy support scripts
    echo -e "${BLUE}Deploying support scripts...${RESET}"
    
    local scripts=(
        "sanitize-settings.sh"
        ".git-secrets-setup.sh"
        "setup-secret-protection.sh"
        "secret-protection-help.sh"
        "github-settings-guide.sh"
        "test-github-actions.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "${source_root}/${script}" ]]; then
            cp "${source_root}/${script}" "${target_dir}/${script}" && \
            chmod +x "${target_dir}/${script}" && \
            print_success "Deployed ${script}"
        fi
    done
    
    # Deploy documentation
    echo -e "${BLUE}Deploying documentation...${RESET}"
    
    if [[ -f "${source_root}/GITHUB_ACTIONS_SETUP.md" ]]; then
        cp "${source_root}/GITHUB_ACTIONS_SETUP.md" "${target_dir}/GITHUB_ACTIONS_SETUP.md" && \
        print_success "Deployed GITHUB_ACTIONS_SETUP.md"
    fi
    
    if [[ -f "${source_root}/CHECKLIST.md" ]]; then
        cp "${source_root}/CHECKLIST.md" "${target_dir}/CHECKLIST.md" && \
        print_success "Deployed CHECKLIST.md"
    fi
    
    # Deploy .configs template and docs
    echo -e "${BLUE}Deploying configuration templates...${RESET}"
    
    mkdir -p "${target_dir}/.configs/MCP"
    
    if [[ -f "${source_root}/.configs/MCP/settings.json.template" ]]; then
        cp "${source_root}/.configs/MCP/settings.json.template" \
           "${target_dir}/.configs/MCP/settings.json.template" && \
        print_success "Deployed settings.json.template"
    fi
    
    if [[ -f "${source_root}/.configs/MCP/README.md" ]]; then
        cp "${source_root}/.configs/MCP/README.md" \
           "${target_dir}/.configs/MCP/README.md" && \
        print_success "Deployed .configs/MCP/README.md"
    fi
    
    if [[ -f "${source_root}/.configs/.gitignore" ]]; then
        cp "${source_root}/.configs/.gitignore" \
           "${target_dir}/.configs/.gitignore" && \
        print_success "Deployed .configs/.gitignore"
    fi
    
    # Deploy to KNOWLEDGE_BASE if it exists
    if [[ -d "${target_dir}/KNOWLEDGE_BASE" ]]; then
        echo -e "${BLUE}Deploying to KNOWLEDGE_BASE...${RESET}"
        if [[ -f "${source_root}/KNOWLEDGE_BASE/SECRET_PROTECTION_SETUP.md" ]]; then
            cp "${source_root}/KNOWLEDGE_BASE/SECRET_PROTECTION_SETUP.md" \
               "${target_dir}/KNOWLEDGE_BASE/SECRET_PROTECTION_SETUP.md" && \
            print_success "Deployed SECRET_PROTECTION_SETUP.md"
        fi
    fi
    
    # Deploy pre-commit hook
    echo -e "${BLUE}Setting up git pre-commit hook...${RESET}"
    
    if [[ -d "${target_dir}/.git" ]]; then
        mkdir -p "${target_dir}/.git/hooks"
        if [[ -f "${source_root}/.git/hooks/pre-commit" ]]; then
            cp "${source_root}/.git/hooks/pre-commit" \
               "${target_dir}/.git/hooks/pre-commit" && \
            chmod +x "${target_dir}/.git/hooks/pre-commit" && \
            print_success "Deployed pre-commit hook"
        fi
    else
        print_warning "Not a git repository, skipping pre-commit hook"
    fi
    
    # Summary
    echo ""
    print_success "✅ GitHub Actions Secret Protection Deployed!"
    echo ""
    echo -e "${BRIGHT_CYAN}📋 Next Steps:${RESET}"
    echo -e "  1. Enable workflow permissions on GitHub:"
    echo -e "     ${YELLOW}Settings → Actions → General → Workflow permissions${RESET}"
    echo -e "     ${YELLOW}Select: 'Read and write permissions'${RESET}"
    echo -e "     ${YELLOW}Check: 'Allow GitHub Actions to create and approve pull requests'${RESET}"
    echo ""
    echo -e "  2. Review setup guide:"
    echo -e "     ${CYAN}cat ${target_dir}/GITHUB_ACTIONS_SETUP.md${RESET}"
    echo ""
    echo -e "  3. Run help for quick reference:"
    echo -e "     ${CYAN}${target_dir}/secret-protection-help.sh${RESET}"
    echo ""
    echo -e "  4. Optional - Setup local protection:"
    echo -e "     ${CYAN}${target_dir}/setup-secret-protection.sh${RESET}"
    echo ""
    echo -e "${BRIGHT_GREEN}🛡️ Three Layers of Protection:${RESET}"
    echo -e "  🥇 Local: git-secrets (optional - run setup script)"
    echo -e "  🥈 Local: Pre-commit hook (✓ deployed)"
    echo -e "  🥉 Cloud: GitHub Actions (✓ deployed)"
    echo ""
    
    return 0
}
