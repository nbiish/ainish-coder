#!/bin/bash

# AINISH-Coder Setup Script
# Simplified deployment system for AINISH configurations

#########################################################################
# CONFIGURATION
#########################################################################
# Get the absolute path of the repository and export it
if [[ "$(dirname "${BASH_SOURCE[0]}")" == "${HOME}/.ainish-coder" ]]; then
    if [[ -f "${HOME}/.ainish-coder/config.sh" ]]; then
        source "${HOME}/.ainish-coder/config.sh"
        export REPO_DIR="/Users/nbiish/code/ainish-coder"
    else
        export REPO_DIR="/Users/nbiish/code/ainish-coder"
    fi
else
    export REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

ZSHRC="${HOME}/.zshrc"
AINISH_CODER_DIR="${HOME}/.ainish-coder"
export CURSOR_PATH="/Applications/Cursor.app/Contents/MacOS/Cursor"

# ANSI color codes
CYAN='\033[0;36m'
BRIGHT_CYAN='\033[1;36m'
MAGENTA='\033[0;35m'
BRIGHT_MAGENTA='\033[1;35m'
BLUE='\033[0;34m'
BRIGHT_BLUE='\033[1;34m'
GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
YELLOW='\033[0;33m'
BRIGHT_YELLOW='\033[1;33m'
RED='\033[0;31m'
BRIGHT_RED='\033[1;31m'
RESET='\033[0m'

#########################################################################
# CORE FUNCTIONS
#########################################################################

get_all_config_files() {
    echo "${REPO_DIR}/critical.mdc"
    echo "${REPO_DIR}/security.mdc"
    echo "${REPO_DIR}/modern-prompting.mdc"
    echo "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc"
    echo "${REPO_DIR}/docs-use.mdc"
    echo "${REPO_DIR}/PRD.mdc"
    echo "${REPO_DIR}/informing.mdc"
    echo "${REPO_DIR}/verify-date-and-time.mdc"
    echo "${REPO_DIR}/code-judge.mdc"
    echo "${REPO_DIR}/python-package-mgmt.mdc"
    echo "${REPO_DIR}/prd-and-context.mdc"
    echo "${REPO_DIR}/structure.mdc"
    echo "${REPO_DIR}/math-process.mdc"
    echo "${REPO_DIR}/.gitignore"
    echo "${REPO_DIR}/.cursorignore"
    echo "${REPO_DIR}/.cursorindexignore"
    echo "${REPO_DIR}/.github/FUNDING.yml"
}

get_mdc_files_only() {
    # Get only .mdc files for ainish-vscode deployment
    find "${REPO_DIR}" -maxdepth 1 -name "*.mdc" -type f | sort
}



deploy_all_to_ainish_coder() {
    local target_dir="$1"
    
    if [[ ! -d "$target_dir" ]]; then
        echo -e "${BRIGHT_RED}Error: $target_dir is not a directory${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_BLUE}Deploying AINISH configurations to $target_dir/ainish-coder${RESET}"
    
    local ainish_dir="$target_dir/ainish-coder"
    mkdir -p "$ainish_dir" 2>/dev/null
    
    local deployed_count=0
    while IFS= read -r source_file; do
        if [[ -f "$source_file" ]]; then
            # Handle .github/FUNDING.yml specially to preserve directory structure
            if [[ "$source_file" == *"/.github/FUNDING.yml" ]]; then
                local github_dir="$ainish_dir/.github"
                mkdir -p "$github_dir" 2>/dev/null
                local dest_file="$github_dir/FUNDING.yml"
                
                if cp "$source_file" "$dest_file" 2>/dev/null; then
                    echo -e "${GREEN}✓ Deployed .github/FUNDING.yml${RESET}"
                    deployed_count=$((deployed_count + 1))
                else
                    echo -e "${YELLOW}⚠️  Failed to deploy .github/FUNDING.yml${RESET}"
                fi
            else
                # Handle regular files as before
                local filename=$(basename "$source_file")
                local dest_file="$ainish_dir/$filename"
                
                if cp "$source_file" "$dest_file" 2>/dev/null; then
                    echo -e "${GREEN}✓ Deployed $filename${RESET}"
                    deployed_count=$((deployed_count + 1))
                else
                    echo -e "${YELLOW}⚠️  Failed to deploy $filename${RESET}"
                fi
            fi
        fi
    done < <(get_all_config_files)
    
    echo -e "${BRIGHT_GREEN}✅ Deployed $deployed_count configuration files${RESET}"
}

deploy_all_to_ainish_coder_markdown() {
    local target_dir="$1"
    
    if [[ ! -d "$target_dir" ]]; then
        echo -e "${BRIGHT_RED}Error: $target_dir is not a directory${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_BLUE}Deploying AINISH configurations (as .md files) to $target_dir/ainish-coder${RESET}"
    
    local ainish_dir="$target_dir/ainish-coder"
    mkdir -p "$ainish_dir" 2>/dev/null
    
    local deployed_count=0
    while IFS= read -r source_file; do
        if [[ -f "$source_file" ]]; then
            # Handle .github/FUNDING.yml specially to preserve directory structure
            if [[ "$source_file" == *"/.github/FUNDING.yml" ]]; then
                local github_dir="$ainish_dir/.github"
                mkdir -p "$github_dir" 2>/dev/null
                local dest_file="$github_dir/FUNDING.yml"
                
                if cp "$source_file" "$dest_file" 2>/dev/null; then
                    echo -e "${GREEN}✓ Deployed .github/FUNDING.yml${RESET}"
                    deployed_count=$((deployed_count + 1))
                else
                    echo -e "${YELLOW}⚠️  Failed to deploy .github/FUNDING.yml${RESET}"
                fi
            else
                # Handle regular files with .md conversion
                local filename=$(basename "$source_file")
                local dest_filename
                
                # Handle different file types appropriately
                if [[ "$filename" == *.mdc ]]; then
                    dest_filename="${filename%.mdc}.md"
                elif [[ "$filename" == ".gitignore" ]] || [[ "$filename" == ".cursorignore" ]] || [[ "$filename" == ".cursorindexignore" ]]; then
                    # Keep configuration files as-is
                    dest_filename="$filename"

                else
                    # Default to .md extension for other files
                    dest_filename="${filename%.*}.md"
                fi
                
                local dest_file="$ainish_dir/$dest_filename"
                
                if cp "$source_file" "$dest_file" 2>/dev/null; then
                    echo -e "${GREEN}✓ Deployed $filename as $dest_filename${RESET}"
                    deployed_count=$((deployed_count + 1))
                else
                    echo -e "${YELLOW}⚠️  Failed to deploy $filename as $dest_filename${RESET}"
                fi
            fi
        fi
    done < <(get_all_config_files)
    
    echo -e "${BRIGHT_GREEN}✅ Deployed $deployed_count configuration files (converted to .md)${RESET}"
}

deploy_vscode_to_github() {
    local target_dir="$1"
    
    if [[ ! -d "$target_dir" ]]; then
        echo -e "${BRIGHT_RED}Error: $target_dir is not a directory${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_BLUE}Deploying .mdc files to $target_dir/ainish-coder/ with -instructions.md naming${RESET}"
    
    local ainish_dir="$target_dir/ainish-coder"
    mkdir -p "$ainish_dir" 2>/dev/null
    
    local deployed_count=0
    local skipped_count=0
    
    while IFS= read -r source_file; do
        if [[ -f "$source_file" ]]; then
            local filename=$(basename "$source_file")
            local dest_filename
            
            # Convert .mdc files to {filename}-instructions.md format
            if [[ "$filename" == *.mdc ]]; then
                local base_name="${filename%.mdc}"
                dest_filename="${base_name}-instructions.md"
                
                local dest_file="$ainish_dir/$dest_filename"
                
                if cp "$source_file" "$dest_file" 2>/dev/null; then
                    echo -e "${GREEN}✓ Deployed $filename as $dest_filename${RESET}"
                    deployed_count=$((deployed_count + 1))
                else
                    echo -e "${YELLOW}⚠️  Failed to deploy $filename as $dest_filename${RESET}"
                    skipped_count=$((skipped_count + 1))
                fi
            fi
        fi
    done < <(get_mdc_files_only)
    
    echo -e "${BRIGHT_GREEN}✅ Deployed $deployed_count .mdc files to $ainish_dir/ with -instructions.md naming${RESET}"
    if [[ $skipped_count -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Skipped $skipped_count files due to errors${RESET}"
    fi
    
    # Display summary of deployed files
    echo -e "${BRIGHT_CYAN}📋 Summary of deployed files:${RESET}"
    for file in "$ainish_dir"/*-instructions.md; do
        if [[ -f "$file" ]]; then
            local display_name=$(basename "$file")
            echo -e "  ${CYAN}• $display_name${RESET}"
        fi
    done
}

setup_ainish_coder_dir() {
    echo -e "${BRIGHT_CYAN}🔧 Setting up ~/.ainish-coder directory...${RESET}"
    
    mkdir -p "${AINISH_CODER_DIR}" 2>/dev/null
    
    if [[ -f "${REPO_DIR}/.cursorrules" ]]; then
        ln -sf "${REPO_DIR}/.cursorrules" "${AINISH_CODER_DIR}/.cursorrules" 2>/dev/null
        echo -e "${GREEN}✓ Symlinked .cursorrules${RESET}"
    fi
    
    local config_files=(
        "critical.mdc" "anishinaabe-cyberpunk-style.mdc" "docs-use.mdc"
        "PRD.mdc" "modern-prompting.mdc" "security.mdc" "informing.mdc"
        "verify-date-and-time.mdc" "code-judge.mdc" "python-package-mgmt.mdc" "structure.mdc"
        "math-process.mdc" ".gitignore" ".cursorignore" ".cursorindexignore"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "${REPO_DIR}/$file" ]]; then
            ln -sf "${REPO_DIR}/$file" "${AINISH_CODER_DIR}/$file" 2>/dev/null
        fi
    done
    
    cp "${REPO_DIR}/ainish-setup.sh" "${AINISH_CODER_DIR}/ainish-setup.sh" 2>/dev/null
    chmod +x "${AINISH_CODER_DIR}/ainish-setup.sh" 2>/dev/null
    
    cat > "${AINISH_CODER_DIR}/config.sh" << EOF
REPO_DIR="/Users/nbiish/code/ainish-coder"
EOF
    chmod +x "${AINISH_CODER_DIR}/config.sh" 2>/dev/null
    
    echo -e "${BRIGHT_GREEN}✅ ~/.ainish-coder directory setup complete${RESET}"
}

verify_tool_paths() {
    local errors=0
    
    if [[ "$CURSOR_PATH" == /* && ! -f "$CURSOR_PATH" ]]; then
        echo -e "${BRIGHT_YELLOW}⚠️  Warning: Cursor not found at $CURSOR_PATH${RESET}"
        errors=$((errors+1))
    fi
    
    return $errors
}

cleanup_old_files() {
    echo -e "${BRIGHT_CYAN}🧹 Cleaning up old files...${RESET}"
    rm -f "${HOME}/setup.sh" "${HOME}/install.sh" "${HOME}/vscode-setup.sh" 2>/dev/null
    rm -f "${HOME}/.ainish-config" "${HOME}/.ainish-settings" 2>/dev/null
    echo -e "${BRIGHT_GREEN}✅ Cleanup complete${RESET}"
}

restore_zshrc_from_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        echo -e "${BRIGHT_RED}Error: Backup file $backup_file not found${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_YELLOW}⚠️  Restoring .zshrc from backup: $backup_file${RESET}"
    
    local current_backup="${ZSHRC}.before_restore.$(date +%Y%m%d_%H%M%S)"
    cp "$ZSHRC" "$current_backup" 2>/dev/null
    
    if cp "$backup_file" "$ZSHRC" 2>/dev/null; then
        echo -e "${BRIGHT_GREEN}✅ .zshrc restored from backup${RESET}"
        return 0
    else
        echo -e "${BRIGHT_RED}Error: Failed to restore .zshrc from backup${RESET}"
        return 1
    fi
}

list_zshrc_backups() {
    echo -e "${BRIGHT_CYAN}📋 Available .zshrc backups:${RESET}"
    
    local backup_dir=$(dirname "$ZSHRC")
    local backup_pattern=$(basename "$ZSHRC").backup.*
    
    if ls "$backup_dir"/$backup_pattern 1>/dev/null 2>&1; then
        ls -la "$backup_dir"/$backup_pattern | while read -r line; do
            echo -e "  ${CYAN}$line${RESET}"
        done
    else
        echo -e "${YELLOW}  No backups found${RESET}"
    fi
}

setup_wrapper_functions() {
    if [[ ! -f "$ZSHRC" ]]; then
        echo -e "${YELLOW}⚠️  Warning: ~/.zshrc not found. Please manually add the wrapper functions.${RESET}"
        return
    fi
    
    echo -e "${BRIGHT_BLUE}🔧 Updating .zshrc with wrapper functions...${RESET}"
    
    local backup_file="${ZSHRC}.backup.$(date +%Y%m%d_%H%M%S)"
    if ! cp "$ZSHRC" "$backup_file" 2>/dev/null; then
        echo -e "${BRIGHT_RED}Error: Failed to create backup of .zshrc${RESET}"
        return 1
    fi
    echo -e "${GREEN}✓ Created backup: $backup_file${RESET}"
    
    local temp_file=$(mktemp)
    local in_section=0
    local section_start_found=0
    
    while IFS= read -r line; do
        if [[ "$line" == "### AINISH CODER WRAPPERS ###" ]]; then
            in_section=1
            section_start_found=1
            echo -e "${YELLOW}⚠️  Found existing AINISH CODER WRAPPERS section, removing...${RESET}"
            continue
        fi
        
        if [[ "$line" == "### END AINISH CODER WRAPPERS ###" ]]; then
            in_section=0
            echo -e "${GREEN}✓ Removed existing AINISH CODER WRAPPERS section${RESET}"
            continue
        fi
        
        if [[ $in_section -eq 0 ]]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$ZSHRC"
    
    if [[ $section_start_found -eq 0 ]]; then
        echo -e "${YELLOW}ℹ️  No existing AINISH CODER WRAPPERS section found${RESET}"
    fi
    
    mv "$temp_file" "$ZSHRC"
    
    if [[ ! -f "$ZSHRC" ]] || [[ ! -s "$ZSHRC" ]]; then
        echo -e "${BRIGHT_RED}Error: .zshrc appears to be corrupted after cleaning${RESET}"
        if restore_zshrc_from_backup "$backup_file"; then
            echo -e "${BRIGHT_GREEN}✅ .zshrc restored successfully${RESET}"
            return 1
        else
            echo -e "${BRIGHT_RED}Error: Failed to restore .zshrc. Manual intervention required.${RESET}"
            return 1
        fi
    fi
    
    cat >> "$ZSHRC" << 'EOF'
### AINISH CODER WRAPPERS ###
export AINISH_CODER_DIR="/Users/nbiish/.ainish-coder"
export CURSOR_PATH="/Applications/Cursor.app/Contents/MacOS/Cursor"
export REPO_DIR="/Users/nbiish/code/ainish-coder"

function ainish-coder { 
    local current_dir="$(pwd)"
    
    if [[ "$1" == "--vscode" ]]; then
        "$AINISH_CODER_DIR/ainish-setup.sh" --vscode "$current_dir"
        echo "✨ AINISH-Coder .mdc files deployed to ainish-coder/ with -instructions.md naming"
    elif [[ "$1" == "--markdown" ]]; then
        "$AINISH_CODER_DIR/ainish-setup.sh" deploy_markdown "$current_dir"
        echo "✨ AINISH-Coder configurations deployed (as .md files)"

    else
        "$AINISH_CODER_DIR/ainish-setup.sh" deploy "$current_dir"
        echo "✨ AINISH-Coder configurations deployed"
    fi
}
### END AINISH CODER WRAPPERS ###
EOF
    
    echo -e "${BRIGHT_GREEN}✅ Wrapper functions added to .zshrc${RESET}"
}

#########################################################################
# MAIN EXECUTION
#########################################################################

main() {
    case "$1" in
        "deploy")
            deploy_all_to_ainish_coder "$2"
            ;;
        "deploy_markdown")
            deploy_all_to_ainish_coder_markdown "$2"
            ;;
        "--vscode")
            deploy_vscode_to_github "$2"
            ;;

        "list_backups")
            list_zshrc_backups
            ;;
        "restore_backup")
            if [[ -z "$2" ]]; then
                echo -e "${BRIGHT_RED}Error: Please specify a backup file to restore from${RESET}"
                echo -e "${CYAN}Usage: $0 restore_backup <backup_file>${RESET}"
                exit 1
            fi
            restore_zshrc_from_backup "$2"
            ;;
        *)
            # Default: Run full initial setup
            echo -e "${BRIGHT_MAGENTA}╔══════════════════════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${BRIGHT_MAGENTA}║${RESET}               ${BRIGHT_CYAN}A I N I S H - C O D E R${RESET}                ${BRIGHT_MAGENTA}║${RESET}"
            echo -e "${BRIGHT_MAGENTA}║${RESET}                    ${CYAN}SETUP SCRIPT${RESET}                     ${BRIGHT_MAGENTA}║${RESET}"
            echo -e "${BRIGHT_MAGENTA}╚══════════════════════════════════════════════════════════════════════════╝${RESET}"
            echo ""

            cleanup_old_files
            setup_ainish_coder_dir

            if ! verify_tool_paths; then
                echo -e "${BRIGHT_YELLOW}⚠️  [WARN] Setup will continue but some tools may not work correctly.${RESET}"
            fi

            chmod +x "$AINISH_CODER_DIR/ainish-setup.sh"
            setup_wrapper_functions
            
            echo -e "${BRIGHT_MAGENTA}╔══════════════════════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${BRIGHT_MAGENTA}║${RESET}               ${BRIGHT_GREEN}A I N I S H - C O D E R${RESET}            ${BRIGHT_MAGENTA}║${RESET}"
            echo -e "${BRIGHT_MAGENTA}║${RESET}                    ${GREEN}SETUP COMPLETE${RESET}                        ${BRIGHT_MAGENTA}║${RESET}"
            echo -e "${BRIGHT_MAGENTA}╚══════════════════════════════════════════════════════════════════════════╝${RESET}"
            echo ""
            echo -e "${BRIGHT_CYAN}🔄 To activate changes: ${BRIGHT_BLUE}source ~/.zshrc${RESET}"
            echo ""
            echo -e "${BRIGHT_MAGENTA}✨ USAGE:${RESET}"
            echo -e "${BRIGHT_BLUE}   ainish-coder${RESET}: ${CYAN}Deploy configurations to current directory${RESET}"
            echo -e "${BRIGHT_BLUE}   ainish-coder --markdown${RESET}: ${CYAN}Deploy .mdc files to ainish-coder/ as .md files${RESET}"
            echo -e "${BRIGHT_BLUE}   ainish-coder --vscode${RESET}: ${CYAN}Deploy .mdc files to ainish-coder/ with -instructions.md naming${RESET}"
            echo ""
            echo -e "${BRIGHT_MAGENTA}🔧 BACKUP COMMANDS:${RESET}"
            echo -e "${BRIGHT_BLUE}   $0 list_backups${RESET}: ${CYAN}List .zshrc backups${RESET}"
            echo -e "${BRIGHT_BLUE}   $0 restore_backup <file>${RESET}: ${CYAN}Restore .zshrc from backup${RESET}"
            echo ""
            echo -e "${BRIGHT_GREEN}🔒 SAFETY FEATURES:${RESET}"
            echo -e "${GREEN}   • Automatic .zshrc backups${RESET}"
            echo -e "${GREEN}   • Precise section removal${RESET}"
            echo -e "${GREEN}   • Automatic rollback on corruption${RESET}"
            echo ""
            ;;
    esac
}

main "$@"
