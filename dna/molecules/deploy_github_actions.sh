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
    
    # Auto-sanitize workflow (Deployed as disabled by default to avoid permission errors)
    if [[ -f "${source_workflows}/auto-sanitize.yml" ]]; then
        cp "${source_workflows}/auto-sanitize.yml" "${target_workflows}/auto-sanitize.yml.disabled" && \
        print_success "Deployed auto-sanitize.yml.disabled (Enable if you set repo permissions)"
    fi
    
    # Detect secrets workflow
    if [[ -f "${source_workflows}/detect-secrets.yml" ]]; then
        cp "${source_workflows}/detect-secrets.yml" "${target_workflows}/detect-secrets.yml" && \
        print_success "Deployed detect-secrets.yml"
    fi
    
    # Reusable Secret Scan workflow
    if [[ -f "${source_workflows}/reusable-secret-scan.yml" ]]; then
        cp "${source_workflows}/reusable-secret-scan.yml" "${target_workflows}/reusable-secret-scan.yml" && \
        print_success "Deployed reusable-secret-scan.yml"
    fi
    
    # Reusable Sanitize workflow
    if [[ -f "${source_workflows}/reusable-sanitize.yml" ]]; then
        cp "${source_workflows}/reusable-sanitize.yml" "${target_workflows}/reusable-sanitize.yml" && \
        print_success "Deployed reusable-sanitize.yml"
    fi
    
    # OWASP ZAP Scan workflow
    if [[ -f "${source_workflows}/zap-scan.yml" ]]; then
        cp "${source_workflows}/zap-scan.yml" "${target_workflows}/zap-scan.yml" && \
        print_success "Deployed zap-scan.yml"
    fi

    # PQC Audit workflow
    if [[ -f "${source_workflows}/pqc-audit.yml" ]]; then
        cp "${source_workflows}/pqc-audit.yml" "${target_workflows}/pqc-audit.yml" && \
        print_success "Deployed pqc-audit.yml"
    fi

    # CodeQL workflow
    if [[ -f "${source_workflows}/codeql.yml" ]]; then
        cp "${source_workflows}/codeql.yml" "${target_workflows}/codeql.yml" && \
        print_success "Deployed codeql.yml"
    fi
    
    # Workflow documentation
    if [[ -f "${source_workflows}/README.md" ]]; then
        cp "${source_workflows}/README.md" "${target_workflows}/README.md" && \
        print_success "Deployed workflows README.md"
    fi
    
    # Deploy support scripts
    echo -e "${BLUE}Deploying support scripts...${RESET}"
    
    # Create .github/scripts directory
    local target_scripts="${target_dir}/.github/scripts"
    mkdir -p "${target_scripts}"
    
    # Deploy sanitize.py
    if [[ -f "${ainish_root}/.github/scripts/sanitize.py" ]]; then
        cp "${ainish_root}/.github/scripts/sanitize.py" "${target_scripts}/sanitize.py" && \
        chmod +x "${target_scripts}/sanitize.py" && \
        print_success "Deployed .github/scripts/sanitize.py"
    fi
    
    # Deploy scan_secrets.sh
    if [[ -f "${ainish_root}/.github/scripts/scan_secrets.sh" ]]; then
        cp "${ainish_root}/.github/scripts/scan_secrets.sh" "${target_scripts}/scan_secrets.sh" && \
        chmod +x "${target_scripts}/scan_secrets.sh" && \
        print_success "Deployed .github/scripts/scan_secrets.sh"
    fi
    
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

    # Deploy Security Knowledge Base
    if [[ -f "${source_root}/knowledge-base/SECURITY_IMPLEMENTATION.md" ]]; then
        mkdir -p "${target_dir}/knowledge-base"
        cp "${source_root}/knowledge-base/SECURITY_IMPLEMENTATION.md" "${target_dir}/knowledge-base/SECURITY_IMPLEMENTATION.md" && \
        print_success "Deployed knowledge-base/SECURITY_IMPLEMENTATION.md"
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
        mkdir -p "${target_dir}/.configs"
        cp "${source_root}/.configs/.gitignore" "${target_dir}/.configs/.gitignore" && \
        print_success "Deployed .configs/.gitignore"
    fi
    
    # Update root .gitignore to include SECURITY_REPORT.md
    if [[ -f "${target_dir}/.gitignore" ]]; then
        if ! grep -q "SECURITY_REPORT.md" "${target_dir}/.gitignore"; then
            echo "" >> "${target_dir}/.gitignore"
            echo "# Security reports" >> "${target_dir}/.gitignore"
            echo "SECURITY_REPORT.md" >> "${target_dir}/.gitignore"
            print_success "Added SECURITY_REPORT.md to .gitignore"
        fi
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

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}  Security Deployment Complete!${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "View your Security Dashboard here:"
    echo -e "${CYAN}https://github.com/${GITHUB_REPOSITORY:-<OWNER>/<REPO>}/security${RESET}"
    echo -e ""

    echo -e "${MAGENTA}🤖 AI Agent Instructions:${RESET}"
    echo -e "  I have deployed a master security guide optimized for LLMs."
    echo -e "  File: ${CYAN}knowledge-base/SECURITY_IMPLEMENTATION.md${RESET}"
    echo -e ""
    echo -e "  To activate AI Security Expert mode, tell your agent:"
    echo -e "  \"Read knowledge-base/SECURITY_IMPLEMENTATION.md and audit this repository for PQC compliance.\""
    echo -e ""
    
    # Install local git hooks for "lazy" protection
    install_local_git_hooks "$target_dir"
    
    return 0
}

install_local_git_hooks() {
    local target_dir="$1"
    local hooks_dir="${target_dir}/.git/hooks"
    
    echo -e "${BLUE}Installing local git hooks...${RESET}"
    
    if [[ ! -d "${target_dir}/.git" ]]; then
        echo -e "${YELLOW}Not a git repository (no .git directory). Skipping hook installation.${RESET}"
        return 0
    fi
    
    mkdir -p "$hooks_dir"
    
    # Create pre-commit hook
    cat > "${hooks_dir}/pre-commit" << 'EOF'
#!/bin/sh
# Pre-commit hook to auto-sanitize secrets
# Installed by ainish-coder

# Redirect output to stderr.
exec 1>&2

# Paths (relative to repo root)
SANITIZER=".github/scripts/sanitize.py"
SCANNER=".github/scripts/scan_secrets.sh"

# Get repo root
REPO_ROOT=$(git rev-parse --show-toplevel)
SANITIZER_PATH="${REPO_ROOT}/${SANITIZER}"
SCANNER_PATH="${REPO_ROOT}/${SCANNER}"

# Check for scripts
if [ ! -f "$SANITIZER_PATH" ]; then
    echo "⚠️  Sanitizer script not found at $SANITIZER. Skipping sanitization."
fi

if [ ! -f "$SCANNER_PATH" ]; then
    echo "⚠️  Scanner script not found at $SCANNER. Skipping scan."
fi

# Get list of staged files that are JSON or ENV
# We use --diff-filter=ACM to only check Added, Copied, Modified files (not Deleted)
files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(json|env.*)$')

# Step 1: Auto-sanitize (if files match and script exists)
if [ -n "$files" ] && [ -f "$SANITIZER_PATH" ]; then
    echo "🧹 Running auto-sanitizer on staged files..."
    cd "$REPO_ROOT"
    echo "$files" | tr '\n' '\0' | xargs -0 python3 "$SANITIZER"
    
    # Check if files were modified
    diffs=$(git diff --name-only $files)
    if [ -n "$diffs" ]; then
        echo ""
        echo "✨ Secrets were detected and removed by auto-sanitizer!"
        echo "   Files modified:"
        echo "$diffs"
        echo ""
        echo "⚠️  Please run 'git add' on these files and commit again."
        exit 1
    fi
fi

# Step 2: Security Scan (Full scan or staged scan)
# User requested "content output locally for the working LLM to intake"
# We run the scanner script which generates SECURITY_REPORT.md
if [ -f "$SCANNER_PATH" ]; then
    echo "🔍 Running security scan..."
    cd "$REPO_ROOT"
    
    # Run scanner. It returns 1 if secrets found.
    # We capture output to avoid noise, but the script generates SECURITY_REPORT.md
    if ! bash "$SCANNER"; then
        echo ""
        echo "❌ Security Issues Detected!"
        echo "   A report has been generated at: SECURITY_REPORT.md"
        echo ""
        echo "👉 Please ask your LLM agent to: 'Read SECURITY_REPORT.md and fix the issues'"
        echo "   Or review the file manually."
        exit 1
    fi
fi

exit 0
EOF

    chmod +x "${hooks_dir}/pre-commit"
    print_success "Installed local pre-commit hook (auto-sanitizes on commit)"
}
