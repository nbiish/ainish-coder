#!/bin/bash
# MOLECULE: License & legal framework deployment
# Copies LICENSE and companion legal instruments from repo root to project root

deploy_license() {
    local target_dir="${1:-.}"  # Default to current directory if not provided
    
    # Ensure target directory exists
    if [[ ! -d "$target_dir" ]]; then
        print_error "Target directory does not exist: $target_dir"
        return 1
    fi
    
    echo -e "${BRIGHT_BLUE}Deploying LICENSE & Legal Framework${RESET}"
    
    local source="${REPO_DIR}/LICENSE"
    local dest="$target_dir/LICENSE"
    
    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: LICENSE not found at $source${RESET}"
        return 1
    fi
    
    # In non-overwrite mode, skip if destination already exists
    if [[ "${AINISH_NO_OVERWRITE:-false}" == "true" ]]; then
        if [[ -f "$dest" || -L "$dest" ]]; then
            echo -e "${YELLOW}⏭️  Skipping LICENSE (already exists at $target_dir)${RESET}"
        else
            if deploy_path "$source" "$dest"; then
                echo -e "${GREEN}✓ Deployed: LICENSE${RESET}"
            fi
        fi
    else
        # Backup existing file if it exists
        if [[ -f "$dest" ]]; then
            mv "$dest" "$dest.backup"
            echo -e "${YELLOW}Backed up existing LICENSE${RESET}"
        fi
        
        # Deploy (symlink with --link, copy otherwise)
        if deploy_path "$source" "$dest"; then
            echo -e "${GREEN}✓ Deployed: LICENSE${RESET}"
        else
            echo -e "${BRIGHT_RED}Error: Failed to deploy LICENSE${RESET}"
            return 1
        fi
    fi

    # Deploy companion legal framework instruments per critical.md § 1.3
    for legal_doc in CONTRIBUTING.md Terms-of-Service.md Privacy-Policy.md Tribal-Consulting-Agreement.md; do
        local doc_src="${REPO_DIR}/$legal_doc"
        local doc_dest="$target_dir/$legal_doc"
        if [[ -f "$doc_src" ]]; then
            if [[ "${AINISH_NO_OVERWRITE:-false}" == "true" ]]; then
                if [[ -f "$doc_dest" || -L "$doc_dest" ]]; then
                    echo -e "${YELLOW}⏭️  Skipping $legal_doc (already exists)${RESET}"
                    continue
                fi
            else
                if [[ -f "$doc_dest" ]]; then
                    mv "$doc_dest" "$doc_dest.backup"
                fi
            fi
            if deploy_path "$doc_src" "$doc_dest"; then
                echo -e "${GREEN}✓ Deployed: $legal_doc${RESET}"
            fi
        fi
    done
    
    echo -e "${BRIGHT_GREEN}✅ LICENSE and legal framework deployed${RESET}"
    return 0
}
