#!/bin/bash
# MOLECULE: Cline workflows deployment
# Deploys prompt files as Cline workflows
# Based on research: Cline uses workflows (markdown files) invoked as /workflow-name.md
# Reference: https://docs.cline.bot/features/slash-commands/workflows

deploy_cline_prompts() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Cline workflows${RESET}"
    
    # Cline workflows live alongside rules
    # Default location is in the .clinerules directory
    local workflows_dir="$target_dir/.clinerules/workflows"
    
    safe_mkdir "$target_dir/.clinerules" || return 1
    safe_mkdir "$workflows_dir" || return 1
    
    # Deploy prompt files from .github/prompts as workflows
    if [[ -d "$source_dir/.github/prompts" ]]; then
        local workflow_count=0
        
        for prompt_file in "$source_dir/.github/prompts"/*.prompt.md; do
            if [[ -f "$prompt_file" ]]; then
                local filename=$(basename "$prompt_file" .prompt.md)
                local target_file="$workflows_dir/${filename}.md"
                
                # Cline workflows can have YAML frontmatter - keep it
                cp "$prompt_file" "$target_file"
                
                ((workflow_count++))
                echo -e "${GREEN}✓ Deployed: /${filename}.md${RESET}"
            fi
        done
        
        # Create a workflow usage guide
        cat > "$workflows_dir/README.md" << 'EOF'
# Cline Workflows

Workflows guide Cline through repetitive tasks using structured markdown files.

## Available Workflows

- **code-judge.md** - Apply critical thinking framework to code reviews
- **secure-code.md** - Comprehensive security vulnerability analysis
- **secure-prompts.md** - LLM security and prompt injection defense

## Usage

Type `/` in Cline chat, then type the workflow name:

```
/code-judge.md
/secure-code.md
/secure-prompts.md
```

Workflows can leverage Cline's built-in tools:
- `read_file` - Read file contents
- `search_files` - Search codebase
- `ask_followup_question` - Interactive prompts
- `new_task` - Spawn sub-tasks

## Creating Custom Workflows

1. Create markdown file in `.clinerules/workflows/`
2. Add clear step-by-step instructions
3. Include tool usage where needed
4. Invoke with `/[filename].md`

See: https://docs.cline.bot/features/slash-commands/workflows
EOF
        
        if [[ $workflow_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Deployed $workflow_count Cline workflow(s)${RESET}"
            echo -e "${BLUE}💡 Type / in Cline to see available workflows${RESET}"
            echo -e "${BLUE}📁 Workflows stored in .clinerules/workflows/${RESET}"
            echo -e "${BLUE}📖 Example: /code-judge.md${RESET}"
        else
            echo -e "${YELLOW}⚠ No prompt files found to deploy${RESET}"
        fi
    else
        echo -e "${YELLOW}⚠ Source prompts directory not found: $source_dir/.github/prompts${RESET}"
        return 1
    fi
    
    return 0
}
    
    return 0
}
