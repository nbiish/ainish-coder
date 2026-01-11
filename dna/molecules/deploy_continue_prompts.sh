#!/bin/bash
# MOLECULE: Continue.dev prompts deployment
# Provides instructions for adding invokable prompts to config.yaml
# Based on research: Continue uses prompts in config.yaml with invokable: true
# Reference: https://docs.continue.dev/customize/deep-dives/prompts

deploy_continue_prompts() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Deploying Continue.dev prompts${RESET}"
    
    local continue_dir="$target_dir/.continue"
    local prompts_dir="$continue_dir/prompts"
    
    safe_mkdir "$prompts_dir" || return 1
    
    # Copy prompt files to .continue/prompts for reference
    if [[ -d "$source_dir/.github/prompts" ]]; then
        local prompt_count=0
        
        for prompt_file in "$source_dir/.github/prompts"/*.prompt.md; do
            if [[ -f "$prompt_file" ]]; then
                local filename=$(basename "$prompt_file")
                local target_file="$prompts_dir/$filename"
                
                # Copy with frontmatter - Continue needs it for metadata
                cp "$prompt_file" "$target_file"
                
                ((prompt_count++))
                echo -e "${GREEN}✓ Copied: ${filename}${RESET}"
            fi
        done
        
        # Create configuration guide
        cat > "$prompts_dir/SETUP_GUIDE.md" << 'EOF'
# Continue.dev Slash Commands Setup

Continue.dev uses **prompts in config.yaml** for slash commands, NOT file-based commands.

## How to Add Slash Commands

### Option 1: Continue Hub (Easiest)

1. Visit https://hub.continue.dev
2. Browse prompts
3. Click "Use Rule" to add to your config

### Option 2: Local config.yaml

Add prompts to `~/.continue/config.yaml`:

```yaml
prompts:
  - name: Code Judge
    description: Apply critical thinking framework to code review
    invokable: true
    content: |
      # Code Judge Constitution
      
      Apply this framework to analyze code:
      1. Find the facts → Gather verified information
      2. Look for the issue → Identify core problems
      3. Identify knowledge sources → Document references
      4. Locate rules/standards → Follow specifications
      5. Apply critical thinking → Examine reasoning
      
      Now analyze the selected code for:
      - Logic errors
      - Security vulnerabilities
      - Performance issues
      - Code quality concerns

  - name: Secure Code
    description: Security-focused code review
    invokable: true
    content: |
      # Security Code Review
      
      Analyze for these security concerns:
      - Input validation and sanitization
      - Authentication and authorization
      - SQL injection prevention
      - XSS (Cross-Site Scripting) prevention
      - CSRF protection
      - Secure dependency versions
      - Error handling without information leakage
```

## Usage

After adding prompts to config.yaml:

1. Open Chat, Agent, or Plan mode
2. Type `/` to see available commands
3. Select your custom prompt

## Converting Our Prompts

Our prompts in `.continue/prompts/` can be converted to config.yaml format:

1. Extract content from each `.prompt.md` file
2. Add to `prompts:` section in config.yaml
3. Set `invokable: true`
4. Add name and description

## References

- Continue Docs: https://docs.continue.dev/customize/deep-dives/prompts
- Continue Hub: https://hub.continue.dev
EOF
        
        if [[ $prompt_count -gt 0 ]]; then
            echo -e "${BRIGHT_GREEN}✅ Copied $prompt_count prompt(s) to .continue/prompts/${RESET}"
            echo -e "${YELLOW}⚠️  Continue requires config.yaml setup - NOT file-based commands${RESET}"
            echo -e "${BLUE}📖 See .continue/prompts/SETUP_GUIDE.md for instructions${RESET}"
            echo -e "${BLUE}💡 Add prompts to ~/.continue/config.yaml with invokable: true${RESET}"
        else
            echo -e "${YELLOW}⚠ No prompt files found to deploy${RESET}"
        fi
    else
        echo -e "${YELLOW}⚠ Source prompts directory not found: $source_dir/.github/prompts${RESET}"
        return 1
    fi
    
    return 0
}
