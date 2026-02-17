#!/bin/bash
# MOLECULE: OSA (YOLO Mode) Framework deployment
# Deploys OSA.md, llms.txt, and mini-swe-agent configs to .osa directory

deploy_osa() {
    local target_dir="${1:-.}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    validate_target_dir "$target_dir" || return 1

    local osa_dir="$target_dir/.osa"
    echo -e "${BRIGHT_BLUE}Deploying OSA Framework to: $osa_dir${RESET}"

    # Create .osa directory
    if ! mkdir -p "$osa_dir"; then
        print_error "Failed to create directory: $osa_dir"
        return 1
    fi
    
    # Deploy main OSA files
    local files=("OSA.md" "llms.txt" "IMPLEMENTATION.md")
    local success=0

    for file in "${files[@]}"; do
        local src_file="$source_dir/.osa/$file"
        local dest_file="$osa_dir/$file"
        
        if [[ -f "$src_file" ]]; then
            cp "$src_file" "$dest_file"
            echo -e "${GREEN}✓ Deployed: $file${RESET}"
            ((success++))
        else
            echo -e "${YELLOW}⚠ Warning: $file not found in source ($src_file)${RESET}"
        fi
    done

    # Deploy mini-swe-agent configuration
    deploy_mini_config "$target_dir" "$source_dir"

    if [[ $success -gt 0 ]]; then
        echo -e "${BRIGHT_GREEN}✅ OSA Framework deployed to $osa_dir${RESET}"
    else
        echo -e "${YELLOW}⚠ OSA Framework partially deployed or empty${RESET}"
    fi

    return 0
}

deploy_mini_config() {
    local target_dir="${1:-.}"
    local source_dir="${2:-.}"
    
    local osa_dir="$target_dir/.osa"
    local mini_dir="$osa_dir/mini"
    local mini_config_dir="$mini_dir/config"
    
    echo -e "${BRIGHT_BLUE}Deploying mini-swe-agent configuration...${RESET}"
    
    # Create mini directories
    mkdir -p "$mini_config_dir"
    
    # Deploy mini README
    local mini_readme="$source_dir/.osa/mini/README.md"
    if [[ -f "$mini_readme" ]]; then
        cp "$mini_readme" "$mini_dir/README.md"
        echo -e "${GREEN}✓ Deployed: mini/README.md${RESET}"
    fi
    
    # Deploy mini config files
    local config_files=(
        "osa_default.yaml"
        "osa_orchestrator.yaml"
        "osa_coder.yaml"
        "osa_security.yaml"
        "osa_qa.yaml"
    )
    
    for config in "${config_files[@]}"; do
        local src_config="$source_dir/.osa/mini/config/$config"
        local dest_config="$mini_config_dir/$config"
        
        if [[ -f "$src_config" ]]; then
            cp "$src_config" "$dest_config"
            echo -e "${GREEN}✓ Deployed: mini/config/$config${RESET}"
        else
            echo -e "${YELLOW}⚠ Warning: mini/config/$config not found${RESET}"
        fi
    done
    
    echo -e "${GREEN}✅ mini-swe-agent configuration deployed${RESET}"
}