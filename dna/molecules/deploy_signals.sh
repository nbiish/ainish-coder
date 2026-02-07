#!/bin/bash
# MOLECULE: Signals Detection Reference deployment
# Deploys signals.md to .signals directory

deploy_signals() {
    local target_dir="${1:-.}"
    local deploy_examples="${2:-false}"
    local source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    validate_target_dir "$target_dir" || return 1

    local signals_dir="$target_dir/.signals"
    echo -e "${BRIGHT_BLUE}Deploying Signals Detection Reference to: $signals_dir${RESET}"

    # Create .signals directory
    if ! mkdir -p "$signals_dir"; then
        print_error "Failed to create directory: $signals_dir"
        return 1
    fi
    
    local src_file="$source_dir/signals.md"
    local dest_file="$signals_dir/signals.md"
    local src_signals_dir="$source_dir/.signals"
    
    if [[ -f "$src_file" ]]; then
        cp "$src_file" "$dest_file"
        echo -e "${GREEN}✓ Deployed: signals.md${RESET}"
    else
        print_error "signals.md not found in source ($src_file)"
        return 1
    fi

    # Copy additional signal files from .signals directory
    if [[ -d "$src_signals_dir" ]]; then
        for file in "$src_signals_dir"/*.md; do
            if [[ -f "$file" ]]; then
                local filename=$(basename "$file")
                cp "$file" "$signals_dir/$filename"
                echo -e "${GREEN}✓ Deployed: $filename${RESET}"
            fi
        done
    fi

    # Deploy examples if requested
    if [[ "$deploy_examples" == "true" ]]; then
        local src_examples_dir="$src_signals_dir/examples"
        local dest_examples_dir="$signals_dir/examples"
        
        if [[ -d "$src_examples_dir" ]]; then
            echo -e "${BRIGHT_BLUE}Deploying Signal Examples...${RESET}"
            if ! mkdir -p "$dest_examples_dir"; then
                print_error "Failed to create directory: $dest_examples_dir"
            else
                cp "$src_examples_dir"/* "$dest_examples_dir/"
                echo -e "${GREEN}✓ Deployed examples to $dest_examples_dir${RESET}"
            fi
        else
            echo -e "${YELLOW}Warning: Examples directory not found at $src_examples_dir${RESET}"
        fi
    fi

    echo -e "${BRIGHT_GREEN}✅ Signals Detection Reference deployed to $signals_dir${RESET}"
    return 0
}
