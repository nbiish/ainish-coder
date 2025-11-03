#!/bin/bash
# MOLECULE: deploy_mcp
# Deploys MCP configuration files

deploy_mcp() {
    local tier_num=$1
    local target_dir="${2:-$(pwd)}"
    
    if [[ -z "$tier_num" ]]; then
        echo -e "${BRIGHT_RED}Error: MCP tier number not specified.${RESET}"
        return 1
    fi
    
    local tier_dir_name="TIER_${tier_num}"
    local source_dir="${REPO_DIR}/.configs/MCP/${tier_dir_name}"
    
    if [[ ! -d "$source_dir" ]]; then
        echo -e "${BRIGHT_RED}Error: Source directory not found at $source_dir${RESET}"
        return 1
    fi
    
    echo "Deploying MCP TIER $tier_num configurations to $target_dir"
    
    find "$source_dir" -type f -name "*.json" -print0 | while IFS= read -r -d $'\0' source_file; do
        local filename=$(basename "$source_file")
        local dest_file="$target_dir/$filename"
        
        if cp "$source_file" "$dest_file"; then
            echo -e "${GREEN}✓ Deployed $filename to $target_dir${RESET}"
        else
            echo -e "${BRIGHT_RED}Failed to deploy $filename.${RESET}"
        fi
    done
    
    echo -e "${BRIGHT_GREEN}✅ MCP TIER $tier_num deployment complete.${RESET}"
    return 0
}
