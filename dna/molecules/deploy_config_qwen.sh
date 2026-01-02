#!/bin/bash
# MOLECULE: deploy_config_qwen
# Deploys qwen configuration

deploy_config_qwen() {
    echo "Deploying qwen configuration..."
    
    local source_file="${REPO_DIR}/.configs/.qwen/setting.json"
    local dest_dir="$HOME/.qwen"
    local dest_file="$dest_dir/settings.json"
    
    if [[ ! -f "$source_file" ]]; then
        echo -e "${BRIGHT_RED}Error: Source configuration file not found at $source_file${RESET}"
        return 1
    fi
    
    if [[ ! -d "$dest_dir" ]]; then
        echo "Creating directory $dest_dir"
        mkdir -p "$dest_dir"
    fi
    
    cp "$source_file" "$dest_file"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Successfully deployed qwen configuration to $dest_file${RESET}"
    else
        echo -e "${BRIGHT_RED}Failed to deploy qwen configuration.${RESET}"
        return 1
    fi
    
    return 0
}
