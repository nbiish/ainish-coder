#!/bin/bash

# AINISH-Coder Unified Setup Script
# This script provides a clean, maintainable deployment system for AINISH configurations

#########################################################################
# ARCHITECTURE
#########################################################################
# - Centralized mode configuration using associative arrays
# - Single deployment engine eliminating code duplication
# - Improved input processing for 0-9 single digits only
# - Configuration-driven approach replacing hardcoded logic
# - Clean separation of concerns and maintainable structure
# - Direct deployment from main directory files
#########################################################################

# Get the absolute path of the repository and export it
export REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="${HOME}/.zshrc"
AINISH_CODER_DIR="${HOME}/.ainish-coder"

# Configuration variables - Edit these to match your installation paths
export CURSOR_PATH="/Applications/Cursor.app/Contents/MacOS/Cursor"
export VSCODE_PATH="code"  # Assuming 'code' is in PATH
export AIDER_PATH="aider"  # Assuming 'aider' is in PATH

# ANSI color codes for cyberpunk theme
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
# MODE CONFIGURATION SYSTEM
#########################################################################
# Centralized configuration defining what each mode deploys
# This replaces the scattered boolean flag system with a clean dictionary approach

# Mode names and descriptions (compatible with bash 3.2)
get_mode_name() {
    case "$1" in
        0) echo "Reserved" ;;
        1) echo "Styling" ;;
        2) echo "Critical" ;;
        3) echo "Security" ;;
        4) echo "PRD" ;;
        5) echo "Prompting" ;;
        6) echo "Documentation" ;;
        7) echo "Informing" ;;
        8) echo "Reserved" ;;
        9) echo "Everything" ;;
        *) echo "Unknown" ;;
    esac
}

get_mode_description() {
    case "$1" in
        0) echo "Reserved for future use" ;;
        1) echo "Visual themes and aesthetic configurations" ;;
        2) echo "Essential development workflow configurations" ;;
        3) echo "Security-focused settings and policies" ;;
        4) echo "Product Requirements Document templates" ;;
        5) echo "AI prompting frameworks and templates" ;;
        6) echo "Documentation generation and standards" ;;
        7) echo "Code documentation and commenting standards" ;;
        8) echo "Reserved for future use" ;;
        9) echo "Deploy all .mdc configuration files" ;;
        *) echo "Unknown mode" ;;
    esac
}

#########################################################################
# INPUT PROCESSING AND VALIDATION
#########################################################################

# Clean and validate mode input to single digits 0-9 only
sanitize_and_validate_modes() {
    local input="$1"
    local -a valid_modes=()
    
    # Remove all non-digit characters and split into individual characters
    local clean_input=$(echo "$input" | tr -cd '0-9')
    
    # Process each character
    for (( i=0; i<${#clean_input}; i++ )); do
        local digit="${clean_input:$i:1}"
        # Add to valid modes if not already present (avoid duplicates)
        if [[ ! " ${valid_modes[@]} " =~ " ${digit} " ]]; then
            valid_modes+=("$digit")
        fi
    done
    
    # Return space-separated list
    echo "${valid_modes[@]}"
}

# Display mode selection interface
display_mode_selection() {
    echo -e "${BRIGHT_CYAN}Select deployment modes (enter digits 0-9, e.g., 135 or 1,3,5):${RESET}" >&2
    for mode in {0..9}; do
        local mode_name="$(get_mode_name $mode)"
        local mode_desc="$(get_mode_description $mode)"
        echo -e "  ${BRIGHT_BLUE}$mode)${RESET} $mode_name - $mode_desc" >&2
    done
    printf "Enter modes: " >&2
}

# Get deployment modes from user or environment
get_deployment_modes() {
    local cli_arg="${1:-}"
    local modes="${AINISH_DEPLOY_MODE:-}"
    
    # Extract from CLI argument if provided
    if [[ "$cli_arg" == --mode=* ]]; then
        modes="${cli_arg#--mode=}"
    fi
    
    # If modes provided via argument or environment, validate and use them
    if [[ -n "$modes" ]]; then
        local validated_modes
        validated_modes=$(sanitize_and_validate_modes "$modes")
        if [[ -n "$validated_modes" ]]; then
            echo "$validated_modes"
            return 0
        fi
    fi
    
    # Interactive mode selection
    display_mode_selection
    read -r user_input
    
    local validated_modes
    validated_modes=$(sanitize_and_validate_modes "$user_input")
    
    if [[ -z "$validated_modes" ]]; then
        echo "Error: No valid modes entered. Please enter digits 0-9." >&2
        return 1
    fi
    
    echo "$validated_modes"
}

#########################################################################
# FILE DEPLOYMENT CONFIGURATION
#########################################################################

# Get file source path for a given file key
get_file_source() {
    local file_key="$1"
    case "$file_key" in
        "critical.mdc") echo "${REPO_DIR}/critical.mdc" ;;
        "security.mdc") echo "${REPO_DIR}/security.mdc" ;;
        "modern-prompting.mdc") echo "${REPO_DIR}/modern-prompting.mdc" ;;
        "anishinaabe-cyberpunk-style.mdc") echo "${REPO_DIR}/anishinaabe-cyberpunk-style.mdc" ;;
        "docs-use.mdc") echo "${REPO_DIR}/docs-use.mdc" ;;
        "PRD.mdc") echo "${REPO_DIR}/PRD.mdc" ;;
        "informing.mdc") echo "${REPO_DIR}/informing.mdc" ;;
        "mdc-headers.md") echo "${REPO_DIR}/mdc-headers.md" ;;
        ".gitignore") echo "${REPO_DIR}/.gitignore" ;;
        *) echo "" ;;
    esac
}

# Define deployment rules for each mode
get_mode_deployment_rules() {
    local mode="$1"
    local target_type="${2:-all}"  # all, cursor, vscode, aider
    
    case "$mode" in
        0) # All Ignore Files
            case "$target_type" in
                cursor) echo "cursor_ignore_files" ;;
                vscode) echo "vscode_ignore_files" ;;
                aider) echo "aider_ignore_files" ;;
                *) echo "all_ignore_files" ;;
            esac
            ;;
        1) # Styling
            echo "deploy_styling_files"
            ;;
        2) # Critical
            echo "deploy_critical_files"
            ;;
        3) # Security
            echo "deploy_security_files"
            ;;
        4) # PRD
            echo "deploy_prd_files"
            ;;
        5) # Prompting
            echo "deploy_prompting_files"
            ;;
        6) # Documentation
            echo "deploy_documentation_files"
            ;;
        7) # Informing
            echo "deploy_informing_files"
            ;;
        8) # Core Files
            echo "deploy_core_files"
            ;;
        9) # Everything
            echo "deploy_everything"
            ;;
        *)
            echo "Error: Invalid mode $mode" >&2
            return 1
            ;;
    esac
}

#########################################################################
# CENTRALIZED DEPLOYMENT ENGINE
#########################################################################

# Deploy a specific file to target locations
deploy_file() {
    local file_key="$1"
    local target_dir="$2"
    local dest_subdir="${3:-}"  # Optional subdirectory (e.g., ".cursor/rules")
    local link_mode="${4:-copy}"  # copy or symlink
    
    local source="$(get_file_source "$file_key")"
    local dest_dir="$target_dir"
    
    if [[ -n "$dest_subdir" ]]; then
        dest_dir="$target_dir/$dest_subdir"
        mkdir -p "$dest_dir" 2>/dev/null
    fi
    
    local dest_file="$dest_dir/$(basename "$file_key")"
    
    if [[ -f "$source" ]]; then
        case "$link_mode" in
            symlink)
                rm -f "$dest_file" 2>/dev/null
                if ln -sf "$source" "$dest_file" 2>/dev/null; then
                    echo -e "${GREEN}✓ Symlinked $file_key to $dest_subdir${RESET}"
                else
                    cp "$source" "$dest_file" 2>/dev/null
                    echo -e "${GREEN}✓ Copied $file_key to $dest_subdir${RESET}"
                fi
                ;;
            *)
                cp "$source" "$dest_file" 2>/dev/null
                echo -e "${GREEN}✓ Deployed $file_key to $dest_subdir${RESET}"
                ;;
        esac
        return 0
    else
        echo -e "${YELLOW}⚠️ Warning: Source file not found: $source${RESET}"
        return 1
    fi
}

# Removed ignore file functions - user will handle tool-specific files manually

# Main deployment function - replaces all the duplicated deployment functions
deploy_configurations() {
    local target_dir="$1"
    local modes="$2"
    local target_type="${3:-all}"  # all, cursor, vscode, aider
    
    # Validate target directory
    if [[ ! -d "$target_dir" ]]; then
        echo -e "${BRIGHT_RED}Error: $target_dir is not a directory${RESET}"
        return 1
    fi
    
    echo -e "${BRIGHT_BLUE}Deploying AINISH configurations to $target_dir (modes: $modes, type: $target_type)${RESET}"
    
    # Create ainish-coder directory
    mkdir -p "$target_dir/ainish-coder" 2>/dev/null
    
    # Process each mode
    for mode in $modes; do
        case "$mode" in
            0) # Reserved for future use
                echo -e "${YELLOW}ℹ️  Mode 0 reserved for future use${RESET}"
                ;;
            1) # Styling
                deploy_file "anishinaabe-cyberpunk-style.mdc" "$target_dir" "ainish-coder"
                ;;
            2) # Critical
                deploy_file "critical.mdc" "$target_dir" "ainish-coder"
                ;;
            3) # Security
                deploy_file "security.mdc" "$target_dir" "ainish-coder"
                ;;
            4) # PRD
                deploy_file "PRD.mdc" "$target_dir" "ainish-coder"
                ;;
            5) # Prompting
                deploy_file "modern-prompting.mdc" "$target_dir" "ainish-coder"
                ;;
            6) # Documentation
                deploy_file "docs-use.mdc" "$target_dir" "ainish-coder"
                ;;
            7) # Informing
                deploy_file "informing.mdc" "$target_dir" "ainish-coder"
                ;;
            8) # Reserved for future use
                echo -e "${YELLOW}ℹ️  Mode 8 reserved for future use${RESET}"
                ;;
            9) # Everything
                # Deploy all .mdc files (modes 1-7)
                for sub_mode in {1..7}; do
                    deploy_configurations "$target_dir" "$sub_mode" "$target_type"
                done
                # Additional everything-specific files
                deploy_file ".gitignore" "$target_dir" "ainish-coder"
                ;;
        esac
    done
    
    echo -e "${BRIGHT_GREEN}✅ AINISH configurations deployed to $target_dir${RESET}"
}

# Helper function for direct file deployment
deploy_file_direct() {
    local source="$1"
    local dest="$2"
    local link_mode="${3:-copy}"
    
    case "$link_mode" in
        symlink)
            rm -f "$dest" 2>/dev/null
            if ln -sf "$source" "$dest" 2>/dev/null; then
                echo -e "${GREEN}✓ Symlinked $(basename "$source")${RESET}"
            else
                cp "$source" "$dest" 2>/dev/null
                echo -e "${GREEN}✓ Copied $(basename "$source")${RESET}"
            fi
            ;;
        *)
            cp "$source" "$dest" 2>/dev/null
            echo -e "${GREEN}✓ Deployed $(basename "$source")${RESET}"
            ;;
    esac
}

#########################################################################
# SPECIALIZED DEPLOYMENT FUNCTIONS (Now Configuration-Driven)
#########################################################################

# Function to create and populate ~/.ainish-coder directory
setup_ainish_coder_dir() {
    echo -e "${BRIGHT_CYAN}🔧 Setting up ~/.ainish-coder directory...${RESET}"
    
    # Create the main directory
    mkdir -p "${AINISH_CODER_DIR}" 2>/dev/null
    
    # Simplified setup - no tool-specific directories needed
    
    # Symlink .cursorrules if it exists
    if [[ -f "${REPO_DIR}/.cursorrules" ]]; then
        ln -sf "${REPO_DIR}/.cursorrules" "${AINISH_CODER_DIR}/.cursorrules" 2>/dev/null
        echo -e "${GREEN}✓ Symlinked .cursorrules${RESET}"
    fi
    
    # Create symlinks for all configuration files
    local config_files=(
        "critical.mdc"
        "anishinaabe-cyberpunk-style.mdc"
        "docs-use.mdc"
        "PRD.mdc"
        "modern-prompting.mdc"
        "security.mdc"
        "informing.mdc"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "${REPO_DIR}/$file" ]]; then
            ln -sf "${REPO_DIR}/$file" "${AINISH_CODER_DIR}/$file" 2>/dev/null
        fi
    done
    
    # Copy the setup script itself (this should be a copy, not a symlink)
    cp "${REPO_DIR}/ainish-setup.sh" "${AINISH_CODER_DIR}/ainish-setup.sh" 2>/dev/null
    chmod +x "${AINISH_CODER_DIR}/ainish-setup.sh" 2>/dev/null
    
    # Create a config file with the repository path
    cat > "${AINISH_CODER_DIR}/config.sh" << EOF
REPO_DIR="${REPO_DIR}"
# This file was automatically generated by ainish-setup.sh
# It contains paths to the original repository and is used by the ainish-update function
EOF
    chmod +x "${AINISH_CODER_DIR}/config.sh" 2>/dev/null
    
    echo -e "${BRIGHT_GREEN}✅ ~/.ainish-coder directory setup complete with symlinks to repo${RESET}"
    echo -e "${GREEN}✓ Changes to repo files will be immediately available to tools${RESET}"
}

# Verify the tool paths exist (for those that are files)
verify_tool_paths() {
    local errors=0
    
    if [[ "$CURSOR_PATH" == /* && ! -f "$CURSOR_PATH" ]]; then
        echo -e "${BRIGHT_YELLOW}⚠️  Warning: Cursor not found at $CURSOR_PATH${RESET}"
        echo -e "${YELLOW}Please edit the CURSOR_PATH variable in ainish-setup.sh${RESET}"
        errors=$((errors+1))
    fi
    
    # For commands in PATH, just check if they're available
    if ! command -v "$VSCODE_PATH" &> /dev/null; then
        echo -e "${BRIGHT_YELLOW}⚠️  Warning: VS Code command '$VSCODE_PATH' not found in PATH${RESET}"
        echo -e "${YELLOW}Please edit the VSCODE_PATH variable in ainish-setup.sh${RESET}"
        errors=$((errors+1))
    fi
    
    if ! command -v "$AIDER_PATH" &> /dev/null; then
        echo -e "${BRIGHT_YELLOW}⚠️  Warning: Aider command '$AIDER_PATH' not found in PATH${RESET}"
        echo -e "${YELLOW}Please edit the AIDER_PATH variable in ainish-setup.sh${RESET}"
        errors=$((errors+1))
    fi
    
    if [[ $errors -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Clean up old ainish-coder files from home directory
cleanup_old_files() {
    echo -e "${BRIGHT_CYAN}🧹 Cleaning up old ainish-coder files from home directory...${RESET}"
    
    # Remove old setup scripts
    rm -f "${HOME}/setup.sh" "${HOME}/install.sh" "${HOME}/vscode-setup.sh" 2>/dev/null
    
    # Remove old configuration directories (but not ~/.ainish-coder)
    rm -rf "${HOME}/.ainish-cursor" "${HOME}/.ainish-aider" "${HOME}/.ainish-copilot" 2>/dev/null
    
    # Remove old configuration files
    rm -f "${HOME}/.ainish-config" "${HOME}/.ainish-settings" 2>/dev/null
    
    echo -e "${BRIGHT_GREEN}✅ Cleanup complete${RESET}"
}

# Function to update .gitignore
update_gitignore() {
    local TARGET="$1"
    local GITIGNORE="$TARGET/.gitignore"
    
    # Config entries to add to .gitignore
    local ENTRIES=(
        "# Cursor files"
        ".cursor/"
        ".cursorignore"
        ".cursorindexingignore"
        ".cursorrules"
        ""
        "# Aider files"
        ".aider-instructions.md"
        ".aider.conf.yml"
        ".aiderignore"
        ".env.example"
        ""
        "# Copilot files"
        ".copilot/"
        ".copilotignore"
        ".rooignore"
        ".github/copilot-instructions.md"
    )
    
    if [[ -f "$GITIGNORE" ]]; then
        # Check if entries already exist
        if ! grep -q ".cursorignore\|.copilotignore" "$GITIGNORE"; then
            echo "" >> "$GITIGNORE"
            for entry in "${ENTRIES[@]}"; do
                echo "$entry" >> "$GITIGNORE"
            done
            echo -e "${BLUE}Updated .gitignore with AINISH config entries${RESET}"
        else
            echo -e "${BLUE}.gitignore already contains AINISH entries${RESET}"
        fi
    else
        # Create new .gitignore
        for entry in "${ENTRIES[@]}"; do
            echo "$entry" >> "$GITIGNORE"
        done
        echo -e "${BLUE}Created .gitignore with AINISH config entries${RESET}"
    fi

    # Verify .gitignore was created/updated successfully
    if [[ -f "$GITIGNORE" ]]; then
        echo -e "${GREEN}✓ Verified .gitignore exists${RESET}"
    else
        echo -e "${YELLOW}⚠️ Warning: Failed to create .gitignore${RESET}"
    fi
}



# Setup wrapper functions in .zshrc
setup_wrapper_functions() {
    if [[ ! -f "$ZSHRC" ]]; then
        echo -e "${YELLOW}⚠️  Warning: ~/.zshrc not found. Please manually add the wrapper functions.${RESET}"
        return
    fi
    
    echo -e "${BRIGHT_BLUE}🔧 Updating .zshrc with wrapper functions...${RESET}"
    
    # Remove existing wrapper sections if they exist
    sed -i '' '/### AINISH CODER WRAPPERS ###/,/### END AINISH CODER WRAPPERS ###/d' "$ZSHRC" 2>/dev/null
    
    # Add the new streamlined wrapper functions
    cat >> "$ZSHRC" << 'EOF'
### AINISH CODER WRAPPERS ###
# Export AINISH-Coder paths
export AINISH_CODER_DIR="/Users/nbiish/.ainish-coder"
export CURSOR_PATH="/Applications/Cursor.app/Contents/MacOS/Cursor"
export VSCODE_PATH="code"
export AIDER_PATH="aider"
export REPO_DIR="/Users/nbiish/code/ainish-coder"

# Simplified mode processing for 0-9 single digits only
__ainish_process_modes() {
    local input="$1"
    # Extract only digits 0-9, remove duplicates, return space-separated
    echo "$input" | tr -cd '0-9' | fold -w1 | sort -u | tr '\n' ' ' | sed 's/ $//'
}

# Get deployment modes with improved validation
__ainish_get_modes() {
    local cli_arg="${1:-}"
    local modes="${AINISH_DEPLOY_MODE:-}"
    
    # Extract from CLI if provided
    if [[ "$cli_arg" == --mode=* ]]; then
        modes="${cli_arg#--mode=}"
    fi
    
    # If modes provided, process and validate
    if [[ -n "$modes" ]]; then
        local processed_modes
        processed_modes=$(__ainish_process_modes "$modes")
        if [[ -n "$processed_modes" ]]; then
            echo "$processed_modes"
            return 0
        fi
    fi
    
    # Interactive selection
    echo -e "\\033[1;36mSelect deployment modes (digits 0-9, e.g., 135 or 1,3,5):\\033[0m" >&2
    echo "0) All Ignore Files  1) Styling       2) Critical     3) Security    4) PRD" >&2
    echo "5) Prompting         6) Documentation 7) Informing    8) Core Files  9) Everything" >&2
    printf "Enter modes: " >&2
    read -r user_input
    
    local processed_modes
    processed_modes=$(__ainish_process_modes "$user_input")
    
    if [[ -z "$processed_modes" ]]; then
        echo "Error: No valid modes entered. Please enter digits 0-9." >&2
        return 1
    fi
    
    echo "$processed_modes"
}

# Unified deployment wrapper
__ainish_deploy() {
    local tool_type="$1"
    local current_dir="$(pwd)"
    shift
    
    local no_deploy=0
    local passthrough_args=()
    local mode_cli_arg=""
    
    for arg in "$@"; do
        case "$arg" in
            --mode=*) mode_cli_arg="$arg" ;;
            --no-deploy) no_deploy=1 ;;
            *) passthrough_args+=("$arg") ;;
        esac
    done
    
    if [[ $no_deploy -eq 0 ]]; then
        local modes
        modes=$(__ainish_get_modes "$mode_cli_arg") || return 1
        
        case "$tool_type" in
            cursor)
                "$AINISH_CODER_DIR/ainish-setup.sh" deploy_cursor_configs "$current_dir" "$modes"
                ;;
            vscode)
                "$AINISH_CODER_DIR/ainish-setup.sh" deploy_vscode_configs "$current_dir" "$modes"
                ;;
            aider)
                "$AINISH_CODER_DIR/ainish-setup.sh" deploy_aider_configs "$current_dir" "$modes"
                ;;
            all)
                "$AINISH_CODER_DIR/ainish-setup.sh" deploy "$current_dir" "$modes"
                ;;
        esac
        echo "🔄 Configuration deployed with modes: $modes"
    else
        echo "Skipping deployment..."
    fi
    
    # Launch tool if executable specified
    case "$tool_type" in
        cursor) "$CURSOR_PATH" "${passthrough_args[@]}" ;;
        vscode) "$VSCODE_PATH" "${passthrough_args[@]}" ;;
        aider) # Aider doesn't need launching, just deployment ;;
        all) echo "✨ AINISH-Coder configurations deployed" ;;
    esac
}

# Main wrapper functions
function ainish-coder { __ainish_deploy "all" "$@"; }
function ainish-cursor { __ainish_deploy "cursor" "$@"; }
function ainish-copilot { __ainish_deploy "vscode" "$@"; }
function ainish-aider { __ainish_deploy "aider" "$@"; }

### END AINISH CODER WRAPPERS ###
EOF
    
    echo -e "${BRIGHT_GREEN}✅ Wrapper functions added to .zshrc${RESET}"
}

#########################################################################
# REFACTORED DEPLOYMENT FUNCTIONS (Using Centralized Engine)
#########################################################################

# Deploy all configurations using centralized engine
deploy_ainish_configs() {
    local target="$1"
    local modes="${2:-9}"  # Default to everything
    deploy_configurations "$target" "$modes" "all"
}

# Deploy only VS Code configurations using centralized engine
deploy_vscode_configs() {
    local target="$1"
    local modes="${2:-9}"  # Default to everything
    deploy_configurations "$target" "$modes" "vscode"
}

# Deploy only Cursor configurations using centralized engine
deploy_cursor_configs() {
    local target="$1"
    local modes="${2:-9}"  # Default to everything
    deploy_configurations "$target" "$modes" "cursor"
}

# Deploy only Aider configurations using centralized engine
deploy_aider_configs() {
    local target="$1"
    local modes="${2:-9}"  # Default to everything
    deploy_configurations "$target" "$modes" "aider"
}

#########################################################################
# MAIN EXECUTION
#########################################################################

# Main execution function
main() {
    # Check for command argument
    if [[ "$1" == "deploy" ]]; then
        # Deploy configurations to the specified directory
        local modes
        modes=$(sanitize_and_validate_modes "${3:-9}")
        deploy_ainish_configs "$2" "$modes"
    elif [[ "$1" == "deploy_vscode_configs" ]]; then
        # Deploy VS Code configurations to the specified directory
        local modes
        modes=$(sanitize_and_validate_modes "${3:-9}")
        deploy_vscode_configs "$2" "$modes"
    elif [[ "$1" == "deploy_cursor_configs" ]]; then
        # Deploy Cursor configurations to the specified directory
        local modes
        modes=$(sanitize_and_validate_modes "${3:-9}")
        deploy_cursor_configs "$2" "$modes"
    elif [[ "$1" == "deploy_aider_configs" ]]; then
        # Deploy Aider configurations to the specified directory
        local modes
        modes=$(sanitize_and_validate_modes "${3:-9}")
        deploy_aider_configs "$2" "$modes"
    elif [[ "$1" == "update_anishinaabe_cyberpunk_style" ]]; then
        # Update anishinaabe-cyberpunk-style.mdc in all ainish-* directories
        local style_src="${REPO_DIR}/anishinaabe-cyberpunk-style.mdc"
        if [[ -f "$style_src" ]]; then
            # Define destination directories
            local aider_dir="${REPO_DIR}/ainish-aider"
            local copilot_github_dir="${REPO_DIR}/ainish-copilot/.github"
            local cursor_rules_dir="${REPO_DIR}/ainish-cursor/.cursor/rules"
            local root_cursor_rules_dir="${REPO_DIR}/.cursor/rules"

            # Ensure directories exist
            mkdir -p "$aider_dir" 2>/dev/null
            mkdir -p "$copilot_github_dir" 2>/dev/null
            mkdir -p "$cursor_rules_dir" 2>/dev/null
            mkdir -p "$root_cursor_rules_dir" 2>/dev/null

            # Copy file to all destinations
            local destinations=("$aider_dir" "$copilot_github_dir" "$cursor_rules_dir" "$root_cursor_rules_dir")
            for dest in "${destinations[@]}"; do
                if cp "$style_src" "$dest/" 2>/dev/null; then
                    echo -e "${GREEN}✓ Updated anishinaabe-cyberpunk-style.mdc in $dest${RESET}"
                else
                    echo -e "${YELLOW}⚠️ Failed to update anishinaabe-cyberpunk-style.mdc in $dest${RESET}"
                fi
            done
            
            echo -e "${BRIGHT_GREEN}✅ anishinaabe-cyberpunk-style.mdc updated in all directories${RESET}"
        else
            echo -e "${RED}Error: anishinaabe-cyberpunk-style.mdc not found at $style_src${RESET}"
            exit 1
        fi
    else
        # Default: Run full initial setup
        # Print cyberpunk-style header
        echo -e "${BRIGHT_MAGENTA}╔══════════════════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BRIGHT_MAGENTA}║${RESET}               ${BRIGHT_CYAN}A I N I S H - C O D E R${RESET}                ${BRIGHT_MAGENTA}║${RESET}"
        echo -e "${BRIGHT_MAGENTA}║${RESET}                    ${CYAN}REFACTORED VERSION${RESET}                     ${BRIGHT_MAGENTA}║${RESET}"
        echo -e "${BRIGHT_MAGENTA}╚══════════════════════════════════════════════════════════════════════════╝${RESET}"
        echo ""

        echo -e "${BRIGHT_CYAN}🔧 [INIT] Setting up AINISH-Coder tooling configurations...${RESET}"
        echo ""

        # Clean up old files
        cleanup_old_files

        # Setup ~/.ainish-coder directory
        setup_ainish_coder_dir

        # Verify tool paths
        if ! verify_tool_paths; then
            echo -e "${BRIGHT_YELLOW}⚠️  [WARN] Setup will continue but some tools may not work correctly.${RESET}"
            echo -e "${YELLOW}Please edit the path variables in $AINISH_CODER_DIR/ainish-setup.sh to fix this.${RESET}"
            echo ""
        fi

        # Make script executable
        chmod +x "$AINISH_CODER_DIR/ainish-setup.sh"

        # Set up wrapper functions
        setup_wrapper_functions
        
        echo -e "${BRIGHT_MAGENTA}╔══════════════════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BRIGHT_MAGENTA}║${RESET}               ${BRIGHT_GREEN}A I N I S H - C O D E R${RESET}            ${BRIGHT_MAGENTA}║${RESET}"
        echo -e "${BRIGHT_MAGENTA}║${RESET}                    ${GREEN}SETUP COMPLETE${RESET}                        ${BRIGHT_MAGENTA}║${RESET}"
        echo -e "${BRIGHT_MAGENTA}╚══════════════════════════════════════════════════════════════════════════╝${RESET}"
        echo ""
        echo -e "${BRIGHT_CYAN}🔄 To activate all changes, run: ${BRIGHT_BLUE}source ~/.zshrc${RESET}"
        echo ""
        echo -e "${BRIGHT_MAGENTA}✨ AVAILABLE COMMANDS:${RESET}"
        echo -e "${BRIGHT_BLUE}   ▶ ainish-coder${RESET}: ${CYAN}Install all configurations to current directory${RESET}"
        echo -e "${BRIGHT_BLUE}   ▶ ainish-cursor${RESET}: ${CYAN}Install Cursor configurations to current directory${RESET}"
        echo -e "${BRIGHT_BLUE}   ▶ ainish-aider${RESET}: ${CYAN}Install Aider configurations to current directory${RESET}"
        echo -e "${BRIGHT_BLUE}   ▶ ainish-copilot${RESET}: ${CYAN}Install VS Code configurations to current directory${RESET}"
        echo ""
        echo -e "${BRIGHT_GREEN}🔗 IMPROVED FEATURES:${RESET}"
        echo -e "${GREEN}   • Single-digit mode selection (0-9) with automatic validation${RESET}"
        echo -e "${GREEN}   • Eliminated code duplication with centralized deployment engine${RESET}"
        echo -e "${GREEN}   • Improved input processing removing spaces and commas automatically${RESET}"
        echo -e "${GREEN}   • Configuration-driven approach for easier maintenance${RESET}"
        echo ""
    fi
}

# Execute main function
main "$@"
