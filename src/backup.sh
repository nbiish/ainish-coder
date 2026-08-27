#!/bin/bash
# Backup utilities

# Create backup of file if it exists
create_backup() {
    local file="$1"
    if [[ -e "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup" || return 1
        echo "Created backup: $backup"
    fi
    return 0
}

# Restore from backup
restore_backup() {
    local file="$1"
    local backup="${file}.backup"
    
    if [[ -f "$backup" ]]; then
        mv "$backup" "$file" || return 1
        echo "Restored from backup: $backup"
        return 0
    else
        echo "No backup found for: $file" >&2
        return 1
    fi
}

# Clean old backups (keep only the most recent)
clean_old_backups() {
    local file="$1"
    local backup_pattern="${file}.backup.*"
    
    # List backups sorted by modification time, keep the newest
    local backups=($(ls -t $backup_pattern 2>/dev/null))
    
    if [[ ${#backups[@]} -gt 1 ]]; then
        # Remove all but the first (newest) backup
        for ((i=1; i<${#backups[@]}; i++)); do
            rm -f "${backups[$i]}"
        done
    fi
}
