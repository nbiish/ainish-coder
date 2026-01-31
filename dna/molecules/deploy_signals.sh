#!/bin/bash
# MOLECULE: Signals Detection Reference deployment
# Deploys signals.md to .signals directory

deploy_signals() {
    local target_dir="${1:-.}"
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
    
    if [[ -f "$src_file" ]]; then
        cp "$src_file" "$dest_file"
        echo -e "${GREEN}✓ Deployed: signals.md${RESET}"
        echo -e "${BRIGHT_GREEN}✅ Signals Detection Reference deployed to $signals_dir${RESET}"
    else
        print_error "signals.md not found in source ($src_file)"
        return 1
    fi

    return 0
}
