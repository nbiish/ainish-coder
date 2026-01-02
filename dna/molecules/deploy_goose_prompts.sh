#!/bin/bash
# MOLECULE: Goose recipes deployment
# Creates Goose recipes from security and quality prompts
# Based on research: Goose uses recipes (YAML/JSON) for reusable workflows
# Reference: https://block.github.io/goose/docs/guides/recipes

deploy_goose_prompts() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Goose recipes${RESET}"
    
    local goose_dir="$target_dir/.goose"
    local recipes_dir="$goose_dir/recipes"
    
    safe_mkdir "$recipes_dir" || return 1
    
    # Deploy prompt files from .github/prompts as Goose recipes
    if [[ -d "$source_dir/.github/prompts" ]]; then
        local recipe_count=0
        
        for prompt_file in "$source_dir/.github/prompts"/*.prompt.md; do
            if [[ -f "$prompt_file" ]]; then
                local filename=$(basename "$prompt_file" .prompt.md)
                local target_file="$recipes_dir/${filename}.yaml"
                
                # Extract YAML frontmatter for metadata
                local description=""
                if command -v sed &> /dev/null && command -v awk &> /dev/null; then
                    description=$(sed -n '/^---$/,/^---$/p' "$prompt_file" | grep "^description:" | sed 's/^description: *//' | tr -d '"')
                fi
                
                # Use filename as title if no description (capitalize first letter with sed)
                local title="${filename//-/ }"
                # Capitalize first letter using sed instead of bash 4.0+ syntax
                title=$(echo "$title" | sed 's/\b\(.\)/\u\1/g')
                
                # Extract prompt content (without YAML frontmatter)
                local instructions=""
                if command -v sed &> /dev/null; then
                    instructions=$(sed '/^---$/,/^---$/d' "$prompt_file")
                else
                    instructions=$(cat "$prompt_file")
                fi
                
                # Create Goose recipe in YAML format (CLI format)
                cat > "$target_file" << EOF
version: "1.0.0"
title: "${title}"
description: "${description:-${title} for code analysis}"
instructions: |
${instructions}
prompt: "Apply the ${title} framework to analyze the code in this project"
extensions: []
EOF
                
                ((recipe_count++))
                echo -e "${GREEN}✓ Created recipe: ${filename}.yaml${RESET}"
            fi
        done
        
        # Create a README explaining Goose recipes
        cat > "$recipes_dir/README.md" << 'EOF'
# Goose Recipes

Recipes are reusable Goose configurations that package extensions, prompts, and settings together.

## Available Recipes

- **code-judge.yaml** - Apply critical thinking framework to code analysis
- **secure-code.yaml** - Comprehensive security vulnerability analysis
- **secure-prompts.yaml** - LLM security and prompt injection defense

## Usage

### From CLI:

```bash
# Run a recipe
goose run --recipe .goose/recipes/code-judge.yaml

# Create recipe from current session
goose session recipe create
```

### From Desktop:

1. Click the menu button (☰) in top-left
2. Click "Recipes"
3. Click "Import Recipe"
4. Select a recipe file from `.goose/recipes/`

Or use the Recipe Generator: https://block.github.io/goose/recipe-generator

## Recipe Format

Recipes use YAML or JSON format with these key fields:

- `version`: Recipe format version (e.g., "1.0.0")
- `title`: Short title describing the recipe
- `description`: Detailed description of what the recipe does
- `instructions`: Instructions for Goose to follow
- `prompt`: Initial prompt to start the session
- `extensions`: List of MCP servers or extensions to load
- `parameters`: Dynamic values users can provide (optional)
- `activities`: Clickable buttons in Desktop (optional)

## Creating Custom Recipes

You can create recipes:

1. **From a session**: While using Goose, click the plus button and select "Create a recipe from this session"
2. **Manually**: Create a YAML file following the recipe format
3. **Recipe Generator**: Use https://block.github.io/goose/recipe-generator

## Sharing Recipes

Share recipes with your team:

- **Desktop**: Copy recipe link from Recipe Library
- **CLI/Desktop**: Share the YAML/JSON file directly

Recipients get their own private session - no data is shared between users.

## References

- Recipe Reference: https://block.github.io/goose/docs/guides/recipes/recipe-reference
- Recipe Tutorial: https://block.github.io/goose/docs/tutorials/recipes-tutorial
- Saving Recipes: https://block.github.io/goose/docs/guides/recipes/storing-recipes
EOF
        
        if [[ $recipe_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $recipe_count Goose recipe(s)${RESET}"
            echo -e "${BLUE}💡 Run with: goose run --recipe .goose/recipes/<recipe>.yaml${RESET}"
            echo -e "${BLUE}📖 Or import in Goose Desktop Recipe Library${RESET}"
            echo -e "${BLUE}📁 Recipes stored in .goose/recipes/${RESET}"
        else
            echo -e "${YELLOW}⚠ No prompt files found to deploy${RESET}"
        fi
    else
        echo -e "${YELLOW}⚠ Source prompts directory not found: $source_dir/.github/prompts${RESET}"
        return 1
    fi
    
    return 0
}
