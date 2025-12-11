#!/bin/bash
# Local secret scanner
# Generates SECURITY_REPORT.md for LLM consumption

OUTPUT_FILE="SECURITY_REPORT.md"

# Define patterns (sync with detect-secrets.yml)
PATTERNS=(
    "BSA[a-zA-Z0-9]{27}"
    "tvly-[a-zA-Z0-9-]{30,}"
    "/Volumes/1tb-sandisk/"
    "BRAVE_API_KEY.*[\"'][^\"']{10,}[\"']"
    "tavilyApiKey=[^&\"\\s]{10,}"
)

# Start report
echo "# Security Scan Report" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "## Summary" >> "$OUTPUT_FILE"
echo "The following potential secrets were detected in your codebase." >> "$OUTPUT_FILE"
echo "Please review and remediate them before committing." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

FOUND=0

echo "🔍 Scanning for secrets..."
for pattern in "${PATTERNS[@]}"; do
    # Grep recursively, exclude .git, exclude the report itself, exclude ignored dirs
    # Use -n for line numbers, -I to ignore binary files
    matches=$(grep -rInE --exclude-dir={.git,node_modules,venv,.venv,target,dist,build} --exclude="$OUTPUT_FILE" "$pattern" . 2>/dev/null)
    
    if [ -n "$matches" ]; then
        FOUND=1
        echo "### ⚠️ Pattern Match: \`$pattern\`" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "\`\`\`" >> "$OUTPUT_FILE"
        echo "$matches" >> "$OUTPUT_FILE"
        echo "\`\`\`" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "Found match for: $pattern"
    fi
done

if [ $FOUND -eq 1 ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "## Recommended Actions" >> "$OUTPUT_FILE"
    echo "1. Run \`python3 .github/scripts/sanitize.py <file>\` to auto-sanitize known keys." >> "$OUTPUT_FILE"
    echo "2. Manually replace the secret with a placeholder (e.g., \`YOUR_API_KEY_HERE\`)." >> "$OUTPUT_FILE"
    echo "3. Add the file to \`.gitignore\` if it should not be committed." >> "$OUTPUT_FILE"
    
    echo "❌ Secrets detected! Report generated at: $OUTPUT_FILE"
    exit 1
else
    echo "✅ No secrets detected."
    # Clean up report if no secrets found (optional, but good for hygiene)
    rm -f "$OUTPUT_FILE"
    exit 0
fi
