#!/bin/bash
# MOLECULE: Windsurf workflows deployment
# Deploys prompt files as Windsurf workflows
# Based on research: Windsurf uses workflows (markdown with title, description, steps) in .windsurf/workflows/
# Reference: https://docs.windsurf.com/windsurf/cascade/workflows

deploy_windsurf_prompts() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Windsurf workflows${RESET}"
    
    local windsurf_dir="$target_dir/.windsurf"
    local workflows_dir="$windsurf_dir/workflows"
    
    safe_mkdir "$workflows_dir" || return 1
    
    # Deploy prompt files from .github/prompts as workflows
    if [[ -d "$source_dir/.github/prompts" ]]; then
        local workflow_count=0
        
        for prompt_file in "$source_dir/.github/prompts"/*.prompt.md; do
            if [[ -f "$prompt_file" ]]; then
                local filename=$(basename "$prompt_file" .prompt.md)
                local target_file="$workflows_dir/${filename}.md"
                
                # Strip YAML frontmatter for Windsurf workflows
                # Windsurf expects plain markdown with title, description, and steps
                if command -v sed &> /dev/null; then
                    sed '/^---$/,/^---$/d' "$prompt_file" > "$target_file"
                else
                    cp "$prompt_file" "$target_file"
                fi
                
                ((workflow_count++))
                echo -e "${GREEN}✓ Deployed: /${filename}${RESET}"
            fi
        done
        
        # Create a workflow usage guide
        cat > "$workflows_dir/README.md" << 'EOF'
# Windsurf Workflows

Workflows provide structured sequences of steps to guide Cascade through tasks.

## Available Workflows

- **code-judge** - Apply critical thinking framework to code reviews
- **secure-code** - Comprehensive security vulnerability analysis
- **secure-prompts** - LLM security and prompt injection defense

## Usage

Type `/` in Windsurf Cascade, then select the workflow:

```
/code-judge
/secure-code
/secure-prompts
```

Workflows are invoked using the format `/[workflow-name]`.

## Workflow Discovery

Windsurf automatically discovers workflows from:
- `.windsurf/workflows/` in current workspace
- `.windsurf/workflows/` in sub-directories
- Parent directories up to git root (for git repos)

## Creating Custom Workflows

1. Create markdown file in `.windsurf/workflows/`
2. Include title, description, and step-by-step instructions
3. Workflows limited to 12000 characters each
4. Invoke with `/[filename-without-extension]`

See: https://docs.windsurf.com/windsurf/cascade/workflows
EOF
        
        if [[ $workflow_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $workflow_count Windsurf workflow(s)${RESET}"
            echo -e "${BLUE}💡 Type / in Cascade to see available workflows${RESET}"
            echo -e "${BLUE}📁 Workflows stored in .windsurf/workflows/${RESET}"
            echo -e "${BLUE}📖 Example: /code-judge${RESET}"
        else
            echo -e "${YELLOW}⚠ No prompt files found to deploy${RESET}"
        fi
    else
        echo -e "${YELLOW}⚠ Source prompts directory not found: $source_dir/.github/prompts${RESET}"
        return 1
    fi
    
    return 0
}
