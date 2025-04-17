#!/bin/bash

# ancopy.sh - Automated file copy script for ainish project
# Handles copying of critical.mdc, PRD.mdc, and prompt.md to specified locations

# Set up logging
LOG_FILE="ancopy.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Timestamp function for logging
timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Log function
log() {
    echo "$(timestamp) - $1"
}

# Error handling function
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Backup function
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.bak"
        cp "$file" "$backup" || handle_error "Failed to create backup of $file"
        log "Created backup: $backup"
    fi
}

# Function to copy file with error handling
copy_file() {
    local src="$1"
    local dst="$2"
    
    # Check if source exists
    if [ ! -f "$src" ]; then
        handle_error "Source file not found: $src"
    fi
    
    # Create destination directory if it doesn't exist
    local dst_dir=$(dirname "$dst")
    mkdir -p "$dst_dir" || handle_error "Failed to create directory: $dst_dir"
    
    # Backup existing file
    backup_file "$dst"
    
    # Perform copy
    cp "$src" "$dst" || handle_error "Failed to copy $src to $dst"
    log "Successfully copied $src to $dst"
}

log "Starting file copy operations"

# Ensure all source files exist in root
log "Checking source files in root directory..."

# Check if PRD.mdc exists in root, copy from .cursor/rules if needed
if [ ! -f "PRD.mdc" ]; then
    log "PRD.mdc not found in root directory, copying from .cursor/rules/"
    if [ -f ".cursor/rules/PRD.mdc" ]; then
        backup_file "PRD.mdc"
        cp ".cursor/rules/PRD.mdc" "PRD.mdc" || handle_error "Failed to copy PRD.mdc to root"
        log "Successfully copied PRD.mdc to root directory"
    elif [ -f "ainish-cursor/.cursor/rules/PRD.mdc" ]; then
        backup_file "PRD.mdc"
        cp "ainish-cursor/.cursor/rules/PRD.mdc" "PRD.mdc" || handle_error "Failed to copy PRD.mdc to root"
        log "Successfully copied PRD.mdc to root directory"
    elif [ -f "ainish-aider/PRD.mdc" ]; then
        backup_file "PRD.mdc"
        cp "ainish-aider/PRD.mdc" "PRD.mdc" || handle_error "Failed to copy PRD.mdc to root"
        log "Successfully copied PRD.mdc to root directory"
    else
        handle_error "Could not find PRD.mdc in any location to copy to root"
    fi
fi

# Copy critical.mdc from root to destinations
log "Copying critical.mdc from root..."
copy_file "critical.mdc" "ainish-aider/critical.mdc"
copy_file "critical.mdc" "ainish-copilot/.github/critical.mdc"
copy_file "critical.mdc" "ainish-cursor/.cursor/rules/critical.mdc"
copy_file "critical.mdc" ".cursor/rules/critical.mdc"

# Copy PRD.mdc from root to destinations
log "Copying PRD.mdc from root..."
copy_file "PRD.mdc" "ainish-aider/PRD.mdc"
copy_file "PRD.mdc" "ainish-copilot/.github/PRD.mdc"
copy_file "PRD.mdc" "ainish-cursor/.cursor/rules/PRD.mdc"
copy_file "PRD.mdc" ".cursor/rules/PRD.mdc"

# Copy prompt.md from root to destinations with special names
log "Copying prompt.md from root..."
copy_file "prompt.md" "ainish-copilot/.github/copilot-instructions.md"
copy_file "prompt.md" "ainish-aider/.aider-instructions.md"

log "All copy operations completed successfully"
exit 0 