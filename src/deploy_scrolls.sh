#!/bin/bash
# MOLECULE: Deploy Scrolls — THE single explicit distribution channel for
# everything scrolls-adjacent: raw .scrolls/ payload PLUS the 8thfire-scrolls
# and ghost-layer-injector skill packs. Never invoked by --rules, --skills,
# or --skills-sync; only the operator's --scrolls command reaches this file.

deploy_scrolls() {
    local target_dir="${1:-$(pwd)}"
    
    # Check if target directory exists
    if [[ ! -d "$target_dir" ]]; then
        print_error "Target directory does not exist: $target_dir"
        return 1
    fi
    
    local scrolls_dir="$target_dir/.scrolls"
    
    echo -e "${BRIGHT_BLUE}Deploying Scrolls to: $scrolls_dir${RESET}"
    
    # Create directory
    if ! mkdir -p "$scrolls_dir"; then
        print_error "Failed to create directory: $scrolls_dir"
        return 1
    fi
    
    # Source directory (from repo root)
    local src_dir="${REPO_DIR}/.scrolls"
    
    if [[ ! -d "$src_dir" ]]; then
        print_error "Source .scrolls directory not found at: $src_dir"
        return 1
    fi
    
    # Copy all files
    local count=0
    # Enable nullglob to handle case where no files match
    shopt -s nullglob
    for file in "$src_dir"/*; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            if deploy_path "$file" "$scrolls_dir/$filename"; then
                echo -e "${GREEN}✓ Deployed $filename${RESET}"
                ((count++))
            else
                print_error "Failed to copy $filename"
            fi
        fi
    done
    shopt -u nullglob
    
    if [[ $count -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No scroll files found to deploy${RESET}"
    else
        echo -e "${BRIGHT_GREEN}✅ Scrolls deployment complete ($count files)${RESET}"
    fi

    # Scroll-channel skill packs ride with the payload — this is their ONLY
    # distribution surface (operator-invoked, verify-gated --scrolls).
    local skills_source="${REPO_DIR}/.agents/skills"
    local skills_target="$target_dir/.agents/skills"
    local pack pack_count=0
    for pack in 8thfire-scrolls ghost-layer-injector; do
        if [[ ! -d "$skills_source/$pack" ]]; then
            print_error "Scroll pack missing: $skills_source/$pack"
            return 1
        fi
        safe_mkdir "$skills_target" || return 1
        if deploy_path "$skills_source/$pack" "$skills_target/$pack"; then
            echo -e "${GREEN}✓ Deployed .agents/skills/$pack${RESET}"
            ((pack_count++))
        else
            print_error "Failed to deploy .agents/skills/$pack"
            return 1
        fi
    done
    # Provenance stamp so --skills-verify / --skills-sync resolve this repo
    # (both packs are sync-excluded, so the stamp never republishes them).
    printf '%s\n' "$REPO_DIR" > "$skills_target/.ainish-source"
    echo -e "${BRIGHT_GREEN}✅ Scroll packs deployed: $pack_count${RESET}"
}
