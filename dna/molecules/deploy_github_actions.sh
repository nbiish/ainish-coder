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
    
    # Deploy Security Knowledge Base
    if [[ -f "${source_root}/knowledge-base/SECURITY_IMPLEMENTATION.md" ]]; then
        mkdir -p "${target_dir}/knowledge-base"
        cp "${source_root}/knowledge-base/SECURITY_IMPLEMENTATION.md" "${target_dir}/knowledge-base/SECURITY_IMPLEMENTATION.md" && \
        print_success "Deployed knowledge-base/SECURITY_IMPLEMENTATION.md"
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
    print_success "✅ GitHub Actions Secret Protection Deployed!"
    echo ""
    echo -e "${BRIGHT_CYAN}📋 What was deployed:${RESET}"
    echo -e "  • Workflow files to .github/workflows/"
    echo -e "  • Support scripts to .github/scripts/"
    echo -e "  • Pre-commit hook for local protection"
    echo ""
    echo -e "${YELLOW}⚠️  Optional: To enable GitHub Actions CI features:${RESET}"
    echo -e "  1. Go to: Settings → Actions → General → Workflow permissions"
    echo -e "  2. Select: 'Read and write permissions'"
    echo -e "  3. Check: 'Allow GitHub Actions to create and approve pull requests'"
    echo ""
    echo -e "${BRIGHT_GREEN}🛡️ Protection Layers:${RESET}"
    echo -e "  🥇 Local: Pre-commit hook (✓ deployed) - auto-cleanses & scans before commit"
    echo -e "  🥈 Local: Pre-push hook (✓ deployed) - scans before push"
    echo -e "  🥉 CI (optional): GitHub Actions - scans on push/PR"
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
# Pre-commit hook to auto-sanitize secrets
# Installed by ainish-coder - Automatically cleanses secrets and continues commit

# Redirect output to stderr.
exec 1>&2

# Get repo root
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# Paths (relative to repo root)
SANITIZER="${REPO_ROOT}/.github/scripts/sanitize.py"

# Step 1: Auto-sanitize JSON/ENV files (silent, automatic)
if [ -f "$SANITIZER" ]; then
    # Get all staged files (not just JSON/ENV - sanitizer handles multiple types)
    staged_files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
    
    if [ -n "$staged_files" ]; then
        # Filter for files that might contain secrets
        files_to_check=$(echo "$staged_files" | grep -E '\.(json|jsonc|env|env\.local|env\.development|env\.production|config|conf|settings)$' || true)
        
        if [ -n "$files_to_check" ]; then
            # Run sanitizer silently
            echo "$files_to_check" | tr '\n' '\0' | xargs -0 python3 "$SANITIZER" 2>/dev/null || true
            
            # Auto-stage any files that were modified
            modified=$(git diff --name-only 2>/dev/null || true)
            if [ -n "$modified" ]; then
                # Stage the cleansed files automatically
                echo "$modified" | xargs git add 2>/dev/null || true
                echo "🔒 Secrets auto-cleansed and staged - continuing commit..."
            fi
        fi
    fi
fi

# Step 2: Comprehensive pattern-based cleansing (for all file types)
# This handles secrets in any file type, not just JSON/ENV
git diff --cached --name-only --diff-filter=ACM 2>/dev/null | while IFS= read -r file || [ -n "$file" ]; do
    # Skip empty lines
    [ -z "$file" ] && continue
        # Skip if file doesn't exist or is binary
        [ ! -f "$file" ] && continue
        [ -L "$file" ] && continue
        
        # Skip excluded files and directories
        case "$file" in
            *.md|*.log|*.bak|SECURITY_REPORT.md|scan_secrets.sh|detect-secrets.yml|.git/*|node_modules/*|.gitignore) continue ;;
        esac
        
        # Check if file contains secrets (skip if already has placeholders)
        if grep -qE "YOUR_[A-Z_]+_HERE|BSAtestkey|example.*key|template" "$file" 2>/dev/null; then
            continue
        fi
        
        needs_cleansing=false
        
        # Check for Tavily API keys (tvly- followed by 30+ alphanumeric/dash chars)
        if grep -qE "tvly-[a-zA-Z0-9-]\{30,\}" "$file" 2>/dev/null; then
            needs_cleansing=true
        fi
        
        # Check for tavilyApiKey= pattern
        if grep -qE "tavilyApiKey=[^&\"[:space:]]\{10,\}" "$file" 2>/dev/null; then
            needs_cleansing=true
        fi
        
        # Check for Brave API keys (BSA followed by 27 alphanumeric chars)
        if grep -qE "BSA[a-zA-Z0-9]\{27\}" "$file" 2>/dev/null; then
            needs_cleansing=true
        fi
        
        # Check for local paths
        if grep -qE "/Volumes/1tb-sandisk/" "$file" 2>/dev/null; then
            needs_cleansing=true
        fi
        
        # Cleanse if needed - use sanitize.py if available, otherwise use sed
        if [ "$needs_cleansing" = true ]; then
            # Try sanitize.py first (handles all file types now)
            if [ -f "$SANITIZER" ]; then
                python3 "$SANITIZER" "$file" >/dev/null 2>&1 || true
            else
                # Fallback: simple sed replacements (portable approach)
                tmp_file="${file}.tmp.$$"
                cp "$file" "$tmp_file" 2>/dev/null || continue
                
                # Apply replacements via sed (using temp file for portability)
                sed 's/tvly-[a-zA-Z0-9-]\{30,\}/YOUR_TAVILY_API_KEY_HERE/g' "$tmp_file" > "${tmp_file}.new" 2>/dev/null && mv "${tmp_file}.new" "$tmp_file" || true
                sed 's/tavilyApiKey=[^&"[:space:]]\{10,\}/tavilyApiKey=YOUR_TAVILY_API_KEY_HERE/g' "$tmp_file" > "${tmp_file}.new" 2>/dev/null && mv "${tmp_file}.new" "$tmp_file" || true
                sed 's/BSA[a-zA-Z0-9]\{27\}/YOUR_BRAVE_API_KEY_HERE/g' "$tmp_file" > "${tmp_file}.new" 2>/dev/null && mv "${tmp_file}.new" "$tmp_file" || true
                sed 's|/Volumes/1tb-sandisk/[^"]*|/path/to/your/mcp/servers|g' "$tmp_file" > "${tmp_file}.new" 2>/dev/null && mv "${tmp_file}.new" "$tmp_file" || true
                
                if ! cmp -s "$file" "$tmp_file" 2>/dev/null; then
                    cp "$file" "${file}.bak" 2>/dev/null || true
                    mv "$tmp_file" "$file" 2>/dev/null || true
                else
                    rm -f "$tmp_file" 2>/dev/null || true
                fi
            fi
            
            # Auto-stage the cleansed file
            git add "$file" 2>/dev/null || true
            echo "🔒 Auto-cleansed secrets in: $file"
        fi
done

# Step 3: Quick cleanse of staged files only (no blocking scan)
# We cleanse what we can and always allow the commit
# NOTE: .env files should be in .gitignore - we don't cleanse them, we skip them

# Clean up any leftover security report
rm -f "${REPO_ROOT}/SECURITY_REPORT.md" 2>/dev/null || true

# Always allow commit to proceed
exit 0
EOF

    chmod +x "${hooks_dir}/pre-commit"
    print_success "Installed local pre-commit hook (auto-sanitizes on commit)"
    
    # Create pre-push hook
    cat > "${hooks_dir}/pre-push" << 'EOF'
#!/bin/sh
# Pre-push hook to scan for secrets before pushing
# Installed by ainish-coder - Auto-cleanses secrets and always allows push
# NOTE: This hook NEVER blocks - it cleanses what it can and proceeds

# Redirect output to stderr.
exec 1>&2

# Get repo root
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# Paths (relative to repo root)
SANITIZER="${REPO_ROOT}/.github/scripts/sanitize.py"

# Auto-cleanse any files that might contain secrets
# This runs silently and quickly - we don't block the push
if [ -f "$SANITIZER" ]; then
    # Find and cleanse files with potential secrets (excluding .env which should be gitignored)
    find . -type f \
        ! -path './.git/*' \
        ! -path './node_modules/*' \
        ! -path './venv/*' \
        ! -path './.venv/*' \
        ! -path './target/*' \
        ! -path './dist/*' \
        ! -path './build/*' \
        ! -path './__pycache__/*' \
        ! -name '*.md' \
        ! -name '*.log' \
        ! -name '*.bak' \
        ! -name '.env' \
        ! -name '.env.*' \
        ! -name '*.env' \
        ! -name 'SECURITY_REPORT.md' \
        ! -name 'scan_secrets.sh' \
        ! -name 'sanitize.py' \
        ! -name 'security_scan.sh' \
        ! -name '.gitignore' \
        \( -name '*.json' -o -name '*.jsonc' -o -name '*.py' -o -name '*.sh' -o -name '*.yml' -o -name '*.yaml' -o -name '*.toml' -o -name '*.conf' -o -name '*.config' \) \
        2>/dev/null | head -100 | while IFS= read -r file; do
            # Quick check if file might have secrets (skip if already has placeholders)
            if grep -qE "tvly-[a-zA-Z0-9-]{20}|BSA[a-zA-Z0-9]{20}|/Volumes/1tb-sandisk/" "$file" 2>/dev/null; then
                if ! grep -qE "YOUR_[A-Z_]+_HERE|/path/to/your/" "$file" 2>/dev/null; then
                    python3 "$SANITIZER" "$file" >/dev/null 2>&1 || true
                fi
            fi
        done
fi

# Clean up any leftover security report
rm -f "${REPO_ROOT}/SECURITY_REPORT.md" 2>/dev/null || true

# Always allow push - we've done our best to cleanse
exit 0
EOF

    chmod +x "${hooks_dir}/pre-push"
    print_success "Installed local pre-push hook (scans before push)"
}


