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

    for workflow_to_disable in codeql.yml zap-scan.yml pqc-audit.yml; do
        if [[ -f "${target_workflows}/${workflow_to_disable}" && ! -f "${target_workflows}/${workflow_to_disable}.disabled" ]]; then
            mv "${target_workflows}/${workflow_to_disable}" "${target_workflows}/${workflow_to_disable}.disabled" 2>/dev/null || true
            print_success "Disabled existing ${workflow_to_disable} (renamed to .disabled)"
        fi
    done
    
    # Auto-sanitize workflow (enabled)
    if [[ -f "${source_workflows}/auto-sanitize.yml.disabled" ]]; then
        cp "${source_workflows}/auto-sanitize.yml.disabled" "${target_workflows}/auto-sanitize.yml" && \
        print_success "Deployed auto-sanitize.yml"
    elif [[ -f "${source_workflows}/auto-sanitize.yml" ]]; then
        cp "${source_workflows}/auto-sanitize.yml" "${target_workflows}/auto-sanitize.yml" && \
        print_success "Deployed auto-sanitize.yml"
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
    
    # OWASP ZAP Scan workflow (disabled by default)
    if [[ -f "${source_workflows}/zap-scan.yml" ]]; then
        cp "${source_workflows}/zap-scan.yml" "${target_workflows}/zap-scan.yml.disabled" && \
        print_success "Deployed zap-scan.yml.disabled"
    fi

    # PQC Audit workflow (disabled by default)
    if [[ -f "${source_workflows}/pqc-audit.yml" ]]; then
        cp "${source_workflows}/pqc-audit.yml" "${target_workflows}/pqc-audit.yml.disabled" && \
        print_success "Deployed pqc-audit.yml.disabled"
    fi

    # CodeQL workflow (disabled by default)
    if [[ -f "${source_workflows}/codeql.yml" ]]; then
        cp "${source_workflows}/codeql.yml" "${target_workflows}/codeql.yml.disabled" && \
        print_success "Deployed codeql.yml.disabled"
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
    
    # Deploy Security Knowledge Base
    if [[ -f "${source_root}/knowledge-base/SECURITY_IMPLEMENTATION.md" ]]; then
        mkdir -p "${target_dir}/knowledge-base"
        cp "${source_root}/knowledge-base/SECURITY_IMPLEMENTATION.md" "${target_dir}/knowledge-base/SECURITY_IMPLEMENTATION.md" && \
        print_success "Deployed knowledge-base/SECURITY_IMPLEMENTATION.md"
    fi
    
    # Update root .gitignore to include SECURITY_REPORT.md
    if [[ ! -f "${target_dir}/.gitignore" ]]; then
        touch "${target_dir}/.gitignore"
    fi

    if ! grep -q "SECURITY_REPORT.md" "${target_dir}/.gitignore"; then
        echo "" >> "${target_dir}/.gitignore"
        echo "# Security reports" >> "${target_dir}/.gitignore"
        echo "SECURITY_REPORT.md" >> "${target_dir}/.gitignore"
        print_success "Added SECURITY_REPORT.md to .gitignore"
    fi
    
    # Deploy pre-commit hook
    echo -e "${BLUE}Setting up git pre-commit hook...${RESET}"
    
    if [[ -d "${target_dir}/.git" ]]; then
        mkdir -p "${target_dir}/.git/hooks"
        install_local_git_hooks "$target_dir"
    else
        print_warning "Not a git repository, skipping pre-commit hook"
    fi
    
    # Summary
    echo ""
    print_success "✅ GitHub Actions CI/CD Deployed!"
    echo ""
    echo -e "${BRIGHT_CYAN}📋 What was deployed:${RESET}"
    echo -e "  • Workflow files to .github/workflows/"
    echo -e "  • CI scripts to .github/scripts/"
    echo -e "  • Pre-commit & pre-push hooks (local protection layer)"
    echo ""
    echo -e "${YELLOW}⚠️  Note: Requires GitHub repository permissions to run workflows.${RESET}"
    echo -e "  Settings → Actions → General → Workflow permissions → Read and write"
    echo ""
    echo -e "${BRIGHT_GREEN}🛡️ Protection Layers:${RESET}"
    echo -e "  🥇 Local: Git hooks (✓ deployed) - auto-sanitizes before commit/push"
    echo -e "  🥈 CI: GitHub Actions (✓ deployed) - scans on push/PR"
    echo ""

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}  Deployment Complete!${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    
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
# ainish-coder local security pre-commit hook

exec 1>&2

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# Check both possible locations for sanitizer
if [ -f "${REPO_ROOT}/.ainish/scripts/sanitize.py" ]; then
    SANITIZER="${REPO_ROOT}/.ainish/scripts/sanitize.py"
elif [ -f "${REPO_ROOT}/.github/scripts/sanitize.py" ]; then
    SANITIZER="${REPO_ROOT}/.github/scripts/sanitize.py"
else
    exit 0
fi

staged_files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

if [ -n "$staged_files" ]; then
    echo "🧹 Running local security sanitizer on staged files..."
    echo "$staged_files" | while IFS= read -r file || [ -n "$file" ]; do
        [ -z "$file" ] && continue
        case "$file" in
            .git/*|node_modules/*|venv/*|.venv/*|target/*|dist/*|build/*|__pycache__/*|.github/scripts/*|.ainish/scripts/*) continue ;;
            SECURITY_REPORT.md|*.bak) continue ;;
        esac
        [ -f "$file" ] || continue
        [ -L "$file" ] && continue
        
        # Run sanitizer and check for changes
        if python3 "$SANITIZER" "$file" >/dev/null 2>&1; then
            # If file was modified, git add it again
            git add "$file" 2>/dev/null || true
        fi
    done
fi

rm -f "${REPO_ROOT}/SECURITY_REPORT.md" 2>/dev/null || true
exit 0
EOF

    chmod +x "${hooks_dir}/pre-commit"
    print_success "Installed pre-commit hook"
    
    # Create pre-push hook
    cat > "${hooks_dir}/pre-push" << 'EOF'
#!/bin/sh
# ainish-coder local security pre-push hook

exec 1>&2

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

if [ -f "${REPO_ROOT}/.ainish/scripts/sanitize.py" ]; then
    SANITIZER="${REPO_ROOT}/.ainish/scripts/sanitize.py"
elif [ -f "${REPO_ROOT}/.github/scripts/sanitize.py" ]; then
    SANITIZER="${REPO_ROOT}/.github/scripts/sanitize.py"
else
    exit 0
fi

echo "🔒 Verifying repository security before push..."

if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)
    changed_files=$(git diff --name-only "$upstream...HEAD" 2>/dev/null || true)
else
    changed_files=$(git diff --name-only HEAD~1..HEAD 2>/dev/null || git ls-files)
fi

if [ -n "$changed_files" ]; then
    echo "$changed_files" | while IFS= read -r file || [ -n "$file" ]; do
        [ -z "$file" ] && continue
        case "$file" in
            .git/*|node_modules/*|venv/*|.venv/*|target/*|dist/*|build/*|__pycache__/*|.github/scripts/*|.ainish/scripts/*) continue ;;
            SECURITY_REPORT.md|*.bak) continue ;;
        esac
        [ -f "$file" ] || continue
        [ -L "$file" ] && continue
        
        # Check if sanitizer WOULD modify the file
        python3 "$SANITIZER" "$file" >/dev/null 2>&1 || true
    done
    
    # Check if any tracked files are now modified
    if ! git diff --quiet; then
        echo "❌ SECURITY BLOCK: Secrets detected in files to be pushed!"
        echo "   Local files have been automatically sanitized."
        echo "   Please amend your commit to include these fixes:"
        echo "   > git add . && git commit --amend --no-edit"
        echo "   > git push"
        exit 1
    fi
fi

rm -f "${REPO_ROOT}/SECURITY_REPORT.md" 2>/dev/null || true
exit 0
EOF

    chmod +x "${hooks_dir}/pre-push"
    print_success "Installed pre-push hook"
}
