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
