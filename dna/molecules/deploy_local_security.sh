#!/bin/bash
# Deploy Local Security Orchestration (Git hooks + Sanitizer)
# This molecule deploys local secret protection without GitHub Actions workflows

deploy_local_security() {
    local target_dir="$1"
    
    # Validation
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${CYAN}  Local Security Orchestration (No CI)${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    
    # Define source paths
    local ainish_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    # Create target directories
    local target_scripts="${target_dir}/.ainish/scripts"
    mkdir -p "${target_scripts}"
    
    # Deploy support scripts
    echo -e "${BLUE}Deploying local security scripts...${RESET}"
    
    # Deploy sanitize.py
    if [[ -f "${ainish_root}/.github/scripts/sanitize.py" ]]; then
        cp "${ainish_root}/.github/scripts/sanitize.py" "${target_scripts}/sanitize.py" && \
        chmod +x "${target_scripts}/sanitize.py" && \
        print_success "Deployed .ainish/scripts/sanitize.py"
    fi
    
    # Deploy scan_secrets.sh
    if [[ -f "${ainish_root}/.github/scripts/scan_secrets.sh" ]]; then
        # Create a local-aware version of scan_secrets.sh that points to .ainish/scripts
        sed "s|\.github/scripts/|.ainish/scripts/|g" "${ainish_root}/.github/scripts/scan_secrets.sh" > "${target_scripts}/scan_secrets.sh" && \
        chmod +x "${target_scripts}/scan_secrets.sh" && \
        print_success "Deployed .ainish/scripts/scan_secrets.sh"
    fi
    
    # Update root .gitignore to include .ainish/ and SECURITY_REPORT.md
    if [[ ! -f "${target_dir}/.gitignore" ]]; then
        touch "${target_dir}/.gitignore"
    fi

    if ! grep -q "SECURITY_REPORT.md" "${target_dir}/.gitignore"; then
        echo "" >> "${target_dir}/.gitignore"
        echo "# Security reports and local tooling" >> "${target_dir}/.gitignore"
        echo "SECURITY_REPORT.md" >> "${target_dir}/.gitignore"
        echo ".ainish/" >> "${target_dir}/.gitignore"
        print_success "Updated .gitignore with security patterns"
    fi
    
    # Deploy git hooks
    echo -e "${BLUE}Setting up local git hooks...${RESET}"
    
    if [[ -d "${target_dir}/.git" ]]; then
        install_ainish_git_hooks "$target_dir"
    else
        print_warning "Not a git repository, skipping hook installation"
    fi
    
    # Summary
    echo ""
    print_success "✅ Local Security Orchestration Deployed!"
    echo ""
    echo -e "${BRIGHT_CYAN}📋 What was deployed:${RESET}"
    echo -e "  • Local scripts to .ainish/scripts/"
    echo -e "  • Pre-commit hook (auto-sanitizes on commit)"
    echo -e "  • Pre-push hook (scans before push)"
    echo -e "  • .gitignore updates"
    echo ""
    echo -e "${BRIGHT_GREEN}🛡️  Your codebase is now secured locally!${RESET}"
    echo -e "  No GitHub Actions or remote settings required."
    echo -e "  Compliant with OWASP Agentic Security Top 10 (2026)."
    echo ""

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}  Deployment Complete!${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    
    return 0
}

install_ainish_git_hooks() {
    local target_dir="$1"
    local hooks_dir="${target_dir}/.git/hooks"
    
    mkdir -p "$hooks_dir"
    
    # Create pre-commit hook
    cat > "${hooks_dir}/pre-commit" << 'EOF'
#!/bin/sh
# ainish-coder local security pre-commit hook

exec 1>&2

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# Check both possible locations for transition
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
    # For new branches, check against HEAD~1 or just scan all tracked files if it's the first commit
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

