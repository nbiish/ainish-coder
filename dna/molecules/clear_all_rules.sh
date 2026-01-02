#!/bin/bash
# MOLECULE: Clear all deployed rules
# Removes all AINISH-Coder rule files from all AI tool locations

clear_all_rules() {
    local target_dir="$1"
    
    validate_target_dir "$target_dir" || return 1
    
    echo -e "${BRIGHT_BLUE}Clearing all AINISH-Coder rule deployments from $target_dir${RESET}"
    
    local files_removed=0
    local dirs_removed=0
    
    # Remove GitHub Copilot rules
    if [[ -f "$target_dir/.github/copilot-instructions.md" ]]; then
        rm -f "$target_dir/.github/copilot-instructions.md"
        echo -e "${YELLOW}✓ Removed .github/copilot-instructions.md${RESET}"
        ((files_removed++))
    fi
    
    # Remove .github directory if empty
    if [[ -d "$target_dir/.github" ]] && [[ -z "$(ls -A "$target_dir/.github" 2>/dev/null)" ]]; then
        rmdir "$target_dir/.github"
        echo -e "${YELLOW}✓ Removed empty .github/ directory${RESET}"
        ((dirs_removed++))
    fi
    
    # Remove Continue Dev rules
    if [[ -f "$target_dir/.continue/rules/MAIRULES.md" ]]; then
        rm -f "$target_dir/.continue/rules/MAIRULES.md"
        echo -e "${YELLOW}✓ Removed .continue/rules/MAIRULES.md${RESET}"
        ((files_removed++))
    fi
    
    # Remove .continue/rules directory if empty
    if [[ -d "$target_dir/.continue/rules" ]] && [[ -z "$(ls -A "$target_dir/.continue/rules" 2>/dev/null)" ]]; then
        rmdir "$target_dir/.continue/rules"
        echo -e "${YELLOW}✓ Removed empty .continue/rules/ directory${RESET}"
        ((dirs_removed++))
    fi
    
    # Remove .continue directory if empty
    if [[ -d "$target_dir/.continue" ]] && [[ -z "$(ls -A "$target_dir/.continue" 2>/dev/null)" ]]; then
        rmdir "$target_dir/.continue"
        echo -e "${YELLOW}✓ Removed empty .continue/ directory${RESET}"
        ((dirs_removed++))
    fi
    
    # Remove Qwen rules
    if [[ -f "$target_dir/QWEN.md" ]]; then
        rm -f "$target_dir/QWEN.md"
        echo -e "${YELLOW}✓ Removed QWEN.md${RESET}"
        ((files_removed++))
    fi
    
    # Remove Gemini rules
    if [[ -f "$target_dir/GEMINI.md" ]]; then
        rm -f "$target_dir/GEMINI.md"
        echo -e "${YELLOW}✓ Removed GEMINI.md${RESET}"
        ((files_removed++))
    fi
    
    # Remove MAIRULES.md (direct deployment)
    if [[ -f "$target_dir/MAIRULES.md" ]]; then
        rm -f "$target_dir/MAIRULES.md"
        echo -e "${YELLOW}✓ Removed MAIRULES.md${RESET}"
        ((files_removed++))
    fi
    
    # Remove .mai-rules directory and all contents
    if [[ -d "$target_dir/.mai-rules" ]]; then
        local rule_count=$(find "$target_dir/.mai-rules" -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        rm -rf "$target_dir/.mai-rules"
        echo -e "${YELLOW}✓ Removed .mai-rules/ directory with $rule_count rule files${RESET}"
        ((dirs_removed++))
        files_removed=$((files_removed + rule_count))
    fi
    
    # Remove global Gemini settings
    if [[ -d "$HOME/.gemini" ]]; then
        local gemini_file_count=$(find "$HOME/.gemini" -type f 2>/dev/null | wc -l | tr -d ' ')
        rm -rf "$HOME/.gemini"
        echo -e "${YELLOW}✓ Removed ~/.gemini/ directory with $gemini_file_count file(s)${RESET}"
        ((dirs_removed++))
        files_removed=$((files_removed + gemini_file_count))
    fi
    
    # Remove global Qwen settings
    if [[ -d "$HOME/.qwen" ]]; then
        local qwen_file_count=$(find "$HOME/.qwen" -type f 2>/dev/null | wc -l | tr -d ' ')
        rm -rf "$HOME/.qwen"
        echo -e "${YELLOW}✓ Removed ~/.qwen/ directory with $qwen_file_count file(s)${RESET}"
        ((dirs_removed++))
        files_removed=$((files_removed + qwen_file_count))
    fi
    
    # Summary
    echo ""
    if [[ $files_removed -eq 0 ]] && [[ $dirs_removed -eq 0 ]]; then
        echo -e "${GREEN}No AINISH-Coder rules found to remove${RESET}"
    else
        echo -e "${BRIGHT_GREEN}✅ Cleared all AINISH-Coder rules${RESET}"
        echo -e "${BRIGHT_BLUE}📋 Summary: Removed $files_removed files and $dirs_removed directories${RESET}"
    fi
}
