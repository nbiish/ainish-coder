#!/bin/bash
# Deploy commands configuration

deploy_commands() {
    local target_arg="$1"
    
    # Validate input
    if [[ -z "$target_arg" ]]; then
        print_error "commands: Missing target argument"
        echo "Usage: ainish-coder --commands TARGET_ARG" >&2
        return 1
    fi
    
    # Construct target path: {arg}/commands
    local target_dir="${target_arg}/commands"
    
    print_info "Deploying commands configuration to: $target_dir"
    
    # Ensure target directory exists
    if ! ensure_dir "$target_dir"; then
        print_error "commands: Failed to create directory: $target_dir"
        return 1
    fi
    
    # Get project root for source files
    local project_root
    project_root=$(get_project_root)
    
    local success_count=0
    local total_count=0
    
    # Deploy files from CONFIGURATIONS/commands/
    local commands_dir="${project_root}/CONFIGURATIONS/commands"
    
    if [[ -d "$commands_dir" ]]; then
        # Find all files in commands directory
        while IFS= read -r -d '' src_file; do
            total_count=$((total_count + 1))
            
            # Get relative path from commands directory
            local rel_path="${src_file#$commands_dir/}"
            local dest_file="${target_dir}/${rel_path}"
            
            # Ensure destination directory exists
            local dest_dir
            dest_dir=$(dirname "$dest_file")
            if ! ensure_dir "$dest_dir"; then
                print_error "commands: Failed to create directory: $dest_dir"
                continue
            fi
            
            # Copy file
            if copy_with_backup "$src_file" "$dest_file"; then
                print_success "commands: Deployed $rel_path"
                success_count=$((success_count + 1))
            else
                print_error "commands: Failed to deploy $rel_path"
            fi
        done < <(find "$commands_dir" -type f -print0)
    fi
    
    # If no files were found in CONFIGURATIONS/commands/, create a placeholder
    if [[ $total_count -eq 0 ]]; then
        local placeholder_file="${target_dir}/.ainish-commands"
        cat > "$placeholder_file" << 'EOL'
# ainish-coder commands configuration
# This file marks that commands have been deployed to this location
# Add your command configurations here

# Example command configuration:
# export PATH="$PATH:/custom/bin"
# alias ll='ls -la'

deployed_at="$(date)"
deployed_by="ainish-coder --commands"
EOL
        
        if [[ -f "$placeholder_file" ]]; then
            print_success "commands: Created placeholder configuration file"
            success_count=1
            total_count=1
        else
            print_error "commands: Failed to create placeholder file"
        fi
    fi
    
    print_info "commands: Deployment complete ($success_count/$total_count files)"
    return 0
}
