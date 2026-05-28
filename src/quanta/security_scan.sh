#!/bin/bash
# Comprehensive security scan and auto-cleansing
# Scans entire codebase, auto-cleanses secrets, generates safe reports
# Usage: security_scan.sh [--cleanse] [--report-only] [TARGET_DIR]

set -euo pipefail

# Load colors
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/colors.sh" ]]; then
    source "${SCRIPT_DIR}/colors.sh"
fi

# Default options
CLEANSE_MODE=false
REPORT_ONLY=false
TARGET_DIR="${1:-$(pwd)}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cleanse)
            CLEANSE_MODE=true
            shift
            ;;
        --report-only)
            REPORT_ONLY=true
            shift
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# Define secret patterns (sync with other security scripts)
declare -A PATTERNS=(
    ["BSA"]="BSA[a-zA-Z0-9]{27}"
    ["Tavily"]="tvly-[a-zA-Z0-9-]{30,}"
    ["TavilyQuery"]="tavilyApiKey=[^&\"\\s]{10,}"
    ["LocalPath"]="/Volumes/1tb-sandisk/"
    ["BraveKey"]="BRAVE_API_KEY.*[\"'][^\"']{10,}[\"']"
)

# Placeholders for replacement
declare -A PLACEHOLDERS=(
    ["BSA"]="YOUR_BRAVE_API_KEY_HERE"
    ["Tavily"]="YOUR_TAVILY_API_KEY_HERE"
    ["TavilyQuery"]="tavilyApiKey=YOUR_TAVILY_API_KEY_HERE"
    ["LocalPath"]="/path/to/your/mcp/servers"
    ["BraveKey"]="BRAVE_API_KEY=\"YOUR_BRAVE_API_KEY_HERE\""
)

# Files/directories to exclude
EXCLUDE_DIRS=".git|node_modules|venv|.venv|target|dist|build|__pycache__|.pytest_cache"
EXCLUDE_FILES="SECURITY_REPORT.md|scan_secrets.sh|detect-secrets.yml|.git-secrets-setup.sh|sanitize-settings.sh|secret-protection-help.sh|sanitize.py|security_scan.sh|*.md|*.log|*.bak|.env|.env.*|*.env"

# Report file
REPORT_FILE="${TARGET_DIR}/SECURITY_REPORT.md"
FOUND_SECRETS=0
CLEANSED_FILES=()

# Function to cleanse a file
cleanse_file() {
    local file_path="$1"
    local pattern_name="$2"
    local pattern="$3"
    local placeholder="${PLACEHOLDERS[$pattern_name]}"
    
    # Skip if already in cleansed list
    for cleaned in "${CLEANSED_FILES[@]}"; do
        [[ "$cleaned" == "$file_path" ]] && return 0
    done
    
    # Create backup
    if [[ ! -f "${file_path}.bak" ]]; then
        cp "$file_path" "${file_path}.bak"
    fi
    
    # Use sed to replace patterns
    # For JSON files, we need to be more careful
    if [[ "$file_path" =~ \.(json|jsonc)$ ]]; then
        # For JSON, replace the value part
        if [[ "$pattern_name" == "BSA" ]]; then
            sed -i.tmp "s/\"BSA[a-zA-Z0-9]\{27\}\"/\"${placeholder}\"/g" "$file_path" 2>/dev/null || true
        elif [[ "$pattern_name" == "Tavily" ]]; then
            sed -i.tmp "s/tvly-[a-zA-Z0-9-]\{30,\}/${placeholder}/g" "$file_path" 2>/dev/null || true
        elif [[ "$pattern_name" == "TavilyQuery" ]]; then
            sed -i.tmp "s/tavilyApiKey=[^&\"\\s]\{10,\}/${placeholder}/g" "$file_path" 2>/dev/null || true
        elif [[ "$pattern_name" == "LocalPath" ]]; then
            sed -i.tmp "s|/Volumes/1tb-sandisk/[^\"]*|${placeholder}|g" "$file_path" 2>/dev/null || true
        fi
        rm -f "${file_path}.tmp"
    else
        # For other files, use pattern replacement
        sed -i.tmp "s|${pattern}|${placeholder}|g" "$file_path" 2>/dev/null || true
        rm -f "${file_path}.tmp"
    fi
    
    # Track cleansed file
    CLEANSED_FILES+=("$file_path")
}

# Function to scan and optionally cleanse
scan_codebase() {
    local found_any=false
    
    echo "🔍 Scanning codebase for secrets..."
    echo ""
    
    # Initialize report
    cat > "$REPORT_FILE" << EOF
# Security Scan Report
**Date:** $(date)
**Mode:** ${CLEANSE_MODE:+Auto-Cleanse}${REPORT_ONLY:+Report Only}${CLEANSE_MODE:+${REPORT_ONLY:+ }Report Only}

## Summary
This report shows **file locations and line numbers only** - no actual secrets are displayed for security.

EOF
    
    # Scan for each pattern
    for pattern_name in "${!PATTERNS[@]}"; do
        local pattern="${PATTERNS[$pattern_name]}"
        local matches_found=false
        
        # Use grep to find matches (excluding binary files and ignored paths)
        while IFS= read -r match_line; do
            [[ -z "$match_line" ]] && continue
            
            # Extract file path and line number (grep -n format: file:line:content)
            local file_path=$(echo "$match_line" | cut -d: -f1)
            local line_num=$(echo "$match_line" | cut -d: -f2)
            local content=$(echo "$match_line" | cut -d: -f3-)
            
            # Skip if matches exclusion patterns
            if echo "$content" | grep -qE "YOUR_[A-Z_]+_HERE|BSAtestkey|example|template|your-key-here|\$\{BRAVE_API_KEY\}"; then
                continue
            fi
            
            # Skip if file is excluded
            if echo "$file_path" | grep -qE "$EXCLUDE_FILES"; then
                continue
            fi
            
            if [[ "$matches_found" == false ]]; then
                matches_found=true
                found_any=true
                FOUND_SECRETS=1
                echo "### ⚠️ Pattern: \`${pattern_name}\`" >> "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"
                echo "**Pattern:** \`${pattern}\`" >> "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"
                echo "| File | Line | Status |" >> "$REPORT_FILE"
                echo "|------|------|--------|" >> "$REPORT_FILE"
            fi
            
            # Cleanse if requested
            local status="⚠️ Detected"
            if [[ "$CLEANSE_MODE" == true ]]; then
                cleanse_file "$file_path" "$pattern_name" "$pattern"
                status="✅ Cleansed"
            fi
            
            # Add to report (SAFE - no actual secrets, just location)
            echo "| \`${file_path}\` | ${line_num} | ${status} |" >> "$REPORT_FILE"
            
        done < <(grep -rInE \
            --exclude-dir=".git" \
            --exclude-dir="node_modules" \
            --exclude-dir="venv" \
            --exclude-dir=".venv" \
            --exclude-dir="target" \
            --exclude-dir="dist" \
            --exclude-dir="build" \
            --exclude-dir="__pycache__" \
            --exclude-dir=".pytest_cache" \
            --exclude="SECURITY_REPORT.md" \
            --exclude="scan_secrets.sh" \
            --exclude="detect-secrets.yml" \
            --exclude=".git-secrets-setup.sh" \
            --exclude="sanitize-settings.sh" \
            --exclude="secret-protection-help.sh" \
            --exclude="*.md" \
            --exclude="*.log" \
            --exclude="*.bak" \
            -I \
            "$pattern" "$TARGET_DIR" 2>/dev/null | grep -vE "YOUR_[A-Z_]+_HERE|BSAtestkey|example|template|your-key-here|\$\{BRAVE_API_KEY\}" || true)
        
        if [[ "$matches_found" == true ]]; then
            echo "" >> "$REPORT_FILE"
            echo "Found matches for pattern: ${pattern_name}"
        fi
    done
    
    # Add recommendations
    if [[ "$found_any" == true ]]; then
        cat >> "$REPORT_FILE" << EOF

## Recommended Actions

EOF
        if [[ "$CLEANSE_MODE" == true ]]; then
            cat >> "$REPORT_FILE" << EOF
1. ✅ **Secrets have been automatically cleansed** - Review the changes:
   \`\`\`bash
   git diff ${CLEANSED_FILES[@]}
   \`\`\`
2. Review backup files (created with .bak extension)
3. Stage the cleansed files: \`git add ${CLEANSED_FILES[@]}\`
4. Commit normally

EOF
        else
            cat >> "$REPORT_FILE" << EOF
1. Secrets will be automatically cleansed on commit via pre-commit hook
2. Or manually replace secrets with placeholders
3. Add files to \`.gitignore\` if they should not be committed

EOF
        fi
    else
        echo "✅ No secrets detected." >> "$REPORT_FILE"
        # Clean up report if no secrets found
        rm -f "$REPORT_FILE"
    fi
    
    return $FOUND_SECRETS
}

# Main execution
main() {
    cd "$TARGET_DIR" || {
        echo "Error: Cannot access directory: $TARGET_DIR" >&2
        exit 1
    }
    
    if scan_codebase; then
        if [[ "$CLEANSE_MODE" == true && ${#CLEANSED_FILES[@]} -gt 0 ]]; then
            echo ""
            echo "✨ Auto-cleansed ${#CLEANSED_FILES[@]} file(s)"
            echo "   Review changes with: git diff"
            echo "   Backup files created with .bak extension"
        fi
        if [[ -f "$REPORT_FILE" ]]; then
            echo ""
            echo "📋 Report generated: $REPORT_FILE"
            echo "   (Safe report - no actual secrets included)"
        fi
        exit 0
    else
        if [[ "$CLEANSE_MODE" == true && ${#CLEANSED_FILES[@]} -gt 0 ]]; then
            echo ""
            echo "✨ Auto-cleansed ${#CLEANSED_FILES[@]} file(s)"
            echo "   Review changes with: git diff"
        fi
        if [[ -f "$REPORT_FILE" ]]; then
            echo ""
            echo "📋 Report generated: $REPORT_FILE"
            echo "   (Safe report - no actual secrets included)"
        fi
        exit 1
    fi
}

main "$@"

