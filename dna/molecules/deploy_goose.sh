#!/bin/bash
# MOLECULE: Goose deployment
# Comprehensive Goose configuration deployment:
# - AGENTS.md and MAIRULES.md to .goose/
# - Recipes from .configs/.goose/recipes/
# Requires AGENTS.md to exist first

deploy_goose() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    require_agents_md "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Full Goose Configuration${RESET}"
    
    # Create directory structure
    local goose_dir="$target_dir/.goose"
    local goose_recipes_dir="$goose_dir/recipes"
    safe_mkdir "$goose_dir" || return 1
    safe_mkdir "$goose_recipes_dir" || return 1
    
    # Deploy rules to .goose
    if cp "$target_dir/AGENTS.md" "$goose_dir/AGENTS.md"; then
        echo -e "${GREEN}✓ Copied: AGENTS.md → .goose/AGENTS.md${RESET}"
    else
        echo -e "${BRIGHT_RED}Error: Failed to copy AGENTS.md${RESET}"
        return 1
    fi
    
    if [[ -f "$target_dir/MAIRULES.md" ]]; then
        cp "$target_dir/MAIRULES.md" "$goose_dir/MAIRULES.md"
        echo -e "${GREEN}✓ Copied: MAIRULES.md → .goose/MAIRULES.md${RESET}"
    fi
    
    # Deploy recipes from .configs
    if [[ -d "$source_dir/.configs/.goose/recipes" ]]; then
        local recipe_count=0
        for recipe_file in "$source_dir/.configs/.goose/recipes"/*.yaml; do
            if [[ -f "$recipe_file" ]]; then
                local filename=$(basename "$recipe_file")
                cp "$recipe_file" "$goose_recipes_dir/$filename"
                ((recipe_count++))
                echo -e "${GREEN}✓ Deployed: .goose/recipes/$filename${RESET}"
            fi
        done
        # Also copy README if it exists
        if [[ -f "$source_dir/.configs/.goose/recipes/README.md" ]]; then
            cp "$source_dir/.configs/.goose/recipes/README.md" "$goose_recipes_dir/README.md"
            echo -e "${GREEN}✓ Deployed: .goose/recipes/README.md${RESET}"
        fi
        if [[ $recipe_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $recipe_count Goose recipe(s)${RESET}"
        fi
    fi
    
    echo -e "${BRIGHT_GREEN}✅ Goose fully configured${RESET}"
    echo -e "${BLUE}💡 Recipes available via 'goose run --recipe' or Goose Desktop${RESET}"
    return 0
}
