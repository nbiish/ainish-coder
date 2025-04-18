#!/bin/bash

# ancopy.sh - Automated file copy script for ainish project
# Handles copying of critical.mdc, PRD.mdc, and prompt.md to specified locations
# Asks once for all copy operations and once for all backup operations

# Set up logging
LOG_FILE="copy.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Global confirmation flags
PERFORM_COPIES=false
CREATE_BACKUPS=false

# Timestamp function for logging
timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Log function
log() {
    echo "$(timestamp) - $1"
}

# Colored log function (uses timestamp and %b for ANSI escapes)
colored_log() {
    local color="$1"; shift
    local ts=$(timestamp)
    # Print colored message
    printf "%s - %b%s%b\n" "$ts" "$color" "$*" "$NC"
    # Also write plain message to log file
    log "$*"
}

# Error handling function
handle_error() {
    colored_log "$RED" "ERROR: $1"
    exit 1
}

# User confirmation function
confirm_action() {
    local message="$1"
    local response
    
    echo -n "$message (y/n): "
    read response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0  # User confirmed (true)
    else
        return 1  # User declined (false)
    fi
}

# Backup function 
backup_file() {
    local file="$1"
    if [ -f "$file" ] && $CREATE_BACKUPS; then
        local backup="${file}.bak"
        cp "$file" "$backup" || handle_error "Failed to create backup of $file"
        log "Created backup: $backup"
    fi
}

# Function to copy file
copy_file() {
    local src="$1"
    local dst="$2"
    
    # Check if source exists
    if [ ! -f "$src" ]; then
        handle_error "Source file not found: $src"
    fi
    
    # Only proceed if global copy flag is set
    if ! $PERFORM_COPIES; then
        log "Skipping copy of $src to $dst (copy operations disabled)"
        return
    fi
    
    # Create destination directory if it doesn't exist
    local dst_dir=$(dirname "$dst")
    mkdir -p "$dst_dir" || handle_error "Failed to create directory: $dst_dir"
    
    # Backup existing file
    if [ -f "$dst" ]; then
        backup_file "$dst"
    fi
    
    # Perform copy
    cp "$src" "$dst" || handle_error "Failed to copy $src to $dst"
    # Color based on source file name
    local bn=$(basename "$src")
    case "$bn" in
        critical.mdc) color="$RED" ;; 
        PRD.mdc)       color="$GREEN" ;; 
        prompt.md)     color="$YELLOW" ;; 
        copy-rules.mdc) color="$BLUE" ;; 
        *)             color="$NC" ;; 
    esac
    colored_log "$color" "Successfully copied $src to $dst"
}

log "Starting file copy operations"

# Ask for global copy confirmation
if confirm_action "Perform all file copy operations?"; then
    PERFORM_COPIES=true
    log "File copy operations enabled"
else
    log "File copy operations disabled"
fi

# Ask for global backup confirmation
if confirm_action "Create backups before overwriting files?"; then
    CREATE_BACKUPS=true
    log "Backup creation enabled"
else
    log "Backup creation disabled"
fi

# Ensure all source files exist in root
log "Checking source files in root directory..."

# Check if PRD.mdc exists in root, potentially copy from another location
if [ ! -f "PRD.mdc" ] && $PERFORM_COPIES; then
    log "PRD.mdc not found in root directory"
    
    if [ -f ".cursor/rules/PRD.mdc" ]; then
        cp ".cursor/rules/PRD.mdc" "PRD.mdc" || handle_error "Failed to copy PRD.mdc to root"
        log "Successfully copied PRD.mdc from .cursor/rules/ to root directory"
    elif [ -f "ainish-cursor/.cursor/rules/PRD.mdc" ]; then
        cp "ainish-cursor/.cursor/rules/PRD.mdc" "PRD.mdc" || handle_error "Failed to copy PRD.mdc to root"
        log "Successfully copied PRD.mdc from ainish-cursor/.cursor/rules/ to root directory"
    elif [ -f "ainish-aider/PRD.mdc" ]; then
        cp "ainish-aider/PRD.mdc" "PRD.mdc" || handle_error "Failed to copy PRD.mdc to root"
        log "Successfully copied PRD.mdc from ainish-aider/ to root directory"
    else
        log "Could not find PRD.mdc in any location to copy to root"
    fi
fi

# Copy critical.mdc from root to destinations
log "Processing critical.mdc distribution..."
if [ -f "critical.mdc" ]; then
    copy_file "critical.mdc" "ainish-aider/critical.mdc"
    copy_file "critical.mdc" "ainish-copilot/.github/critical.mdc"
    copy_file "critical.mdc" "ainish-cursor/.cursor/rules/critical.mdc"
    copy_file "critical.mdc" ".cursor/rules/critical.mdc"
else
    log "critical.mdc not found in root directory"
fi

# Copy PRD.mdc from root to destinations
log "Processing PRD.mdc distribution..."
if [ -f "PRD.mdc" ]; then
    copy_file "PRD.mdc" "ainish-aider/PRD.mdc"
    copy_file "PRD.mdc" "ainish-copilot/.github/PRD.mdc"
    copy_file "PRD.mdc" "ainish-cursor/.cursor/rules/PRD.mdc"
    copy_file "PRD.mdc" ".cursor/rules/PRD.mdc"
else
    log "PRD.mdc not found in root directory"
fi

# Copy prompt.md from root to destinations with special names
log "Processing prompt.md distribution..."
if [ -f "prompt.md" ]; then
    copy_file "prompt.md" "ainish-copilot/.github/copilot-instructions.md"
    copy_file "prompt.md" "ainish-aider/.aider-instructions.md"
else
    log "prompt.md not found in root directory"
fi

# Ensure copy-rules.mdc exists in root directory if missing
if [ ! -f "copy-rules.mdc" ] && $PERFORM_COPIES; then
    log "copy-rules.mdc not found in root directory"
    if [ -f ".cursor/rules/copy-rules.mdc" ]; then
        cp ".cursor/rules/copy-rules.mdc" "copy-rules.mdc" || handle_error "Failed to copy copy-rules.mdc to root"
        log "Successfully copied copy-rules.mdc from .cursor/rules/ to root directory"
    elif [ -f "ainish-cursor/.cursor/rules/copy-rules.mdc" ]; then
        cp "ainish-cursor/.cursor/rules/copy-rules.mdc" "copy-rules.mdc" || handle_error "Failed to copy copy-rules.mdc to root"
        log "Successfully copied copy-rules.mdc from ainish-cursor/.cursor/rules/ to root directory"
    elif [ -f "ainish-aider/copy-rules.mdc" ]; then
        cp "ainish-aider/copy-rules.mdc" "copy-rules.mdc" || handle_error "Failed to copy copy-rules.mdc to root"
        log "Successfully copied copy-rules.mdc from ainish-aider/ to root directory"
    else
        log "Could not find copy-rules.mdc in any location to copy to root"
    fi
fi

# Copy copy-rules.mdc from root to destinations
log "Processing copy-rules.mdc distribution..."
if [ -f "copy-rules.mdc" ]; then
    copy_file "copy-rules.mdc" "ainish-aider/copy-rules.mdc"
    copy_file "copy-rules.mdc" "ainish-copilot/.github/copy-rules.mdc"
    copy_file "copy-rules.mdc" "ainish-cursor/.cursor/rules/copy-rules.mdc"
    copy_file "copy-rules.mdc" ".cursor/rules/copy-rules.mdc"
else
    log "copy-rules.mdc not found in root directory"
fi

if $PERFORM_COPIES; then
    log "All copy operations completed successfully"
else
    log "No copy operations performed (disabled by user)"
fi

exit 0 