#!/bin/bash
# MOLECULE: Deploy MCP recipes
# Deploys MCP recipe templates (like Tavily CLI usage) to the target directory

deploy_mcp_recipes() {
    local target_dir="${1:-$(pwd)}"
    
    # Check if target directory exists
    if [[ ! -d "$target_dir" ]]; then
        print_error "Target directory does not exist: $target_dir"
        return 1
    fi
    
    local recipes_dir="$target_dir/mcp_recipes"
    
    echo -e "${BRIGHT_BLUE}Deploying MCP Recipes to: $recipes_dir${RESET}"
    
    # Create directory
    if ! mkdir -p "$recipes_dir"; then
        print_error "Failed to create directory: $recipes_dir"
        return 1
    fi
    
    # Source directory (from repo root)
    local src_dir="${REPO_DIR}/mcp_recipes"
    
    if [[ ! -d "$src_dir" ]]; then
        print_error "Source mcp_recipes directory not found at: $src_dir"
        return 1
    fi
    
    # Copy all markdown files
    local count=0
    for file in "$src_dir"/*.md; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            if cp "$file" "$recipes_dir/"; then
                echo -e "${GREEN}✓ Deployed $filename${RESET}"
                ((count++))
            else
                print_error "Failed to copy $filename"
            fi
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No recipe files found to deploy${RESET}"
    else
        echo -e "${BRIGHT_GREEN}✅ MCP Recipes deployment complete ($count files)${RESET}"
    fi
}
