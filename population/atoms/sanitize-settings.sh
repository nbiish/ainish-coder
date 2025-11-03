#!/bin/bash
# Sanitize settings.json files by removing API keys and local paths
# Usage: bash population/atoms/sanitize-settings.sh [path/to/configurations]

set -e

# Get script directory and root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source colors for pretty output
if [ -f "$SCRIPT_DIR/colors.sh" ]; then
    source "$SCRIPT_DIR/colors.sh"
else
    # Fallback colors
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

echo -e "${BLUE}🧹 Sanitizing settings.json files...${NC}"

# Use provided path or default to CONFIGURATIONS in root
CONFIG_PATH="${1:-$ROOT_DIR/CONFIGURATIONS}"

# Find all settings.json files in CONFIGURATIONS
find "$CONFIG_PATH" -name "settings.json" -type f | while read -r file; do
    echo -e "${YELLOW}Processing: ${file}${NC}"
    
    # Create backup
    cp "$file" "$file.bak"
    
    # Sanitize using jq (preserves JSON structure)
    if command -v jq &> /dev/null; then
        jq 'walk(
            if type == "object" then
                # Remove API keys
                if has("BRAVE_API_KEY") then .BRAVE_API_KEY = "YOUR_BRAVE_API_KEY_HERE" else . end |
                if has("TAVILY_API_KEY") then .TAVILY_API_KEY = "YOUR_TAVILY_API_KEY_HERE" else . end |
                # Replace absolute paths
                if has("cwd") and (.cwd | startswith("/Volumes/")) then .cwd = "/path/to/your/mcp/servers" else . end |
                if has("MEMORY_FILE_PATH") and (.MEMORY_FILE_PATH | startswith("/Volumes/")) then .MEMORY_FILE_PATH = "/path/to/your/memory/memories.jsonl" else . end
            else . end
        ) | walk(
            if type == "array" then
                map(if type == "string" and contains("tavilyApiKey=") then
                    sub("tavilyApiKey=[^&\"\\s]+"; "tavilyApiKey=YOUR_TAVILY_API_KEY_HERE")
                else . end)
            else . end
        )' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        
        echo -e "${GREEN}✓ Sanitized: ${file}${NC}"
    else
        # Fallback to sed if jq not available
        sed -i.tmp \
            -e 's/"BRAVE_API_KEY": "[^"]*"/"BRAVE_API_KEY": "YOUR_BRAVE_API_KEY_HERE"/g' \
            -e 's/tavilyApiKey=[^"&]*/tavilyApiKey=YOUR_TAVILY_API_KEY_HERE/g' \
            -e 's|"cwd": "/Volumes/[^"]*"|"cwd": "/path/to/your/mcp/servers"|g' \
            -e 's|"MEMORY_FILE_PATH": "/Volumes/[^"]*"|"MEMORY_FILE_PATH": "/path/to/your/memory/memories.jsonl"|g' \
            "$file"
        rm -f "$file.tmp"
        echo -e "${GREEN}✓ Sanitized (sed): ${file}${NC}"
    fi
done

echo ""
echo -e "${GREEN}✅ All settings.json files sanitized!${NC}"
echo -e "${YELLOW}💡 Backup files created with .bak extension${NC}"
echo -e "${YELLOW}💡 Review changes before committing${NC}"
