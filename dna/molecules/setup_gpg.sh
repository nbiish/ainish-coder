#!/bin/bash
# GPG setup guide for Hugging Face and Git

setup_gpg() {
    local target_dir="${1:-$(pwd)}"
    
    print_header "GPG Setup Wizard for Hugging Face & GitHub"
    
    echo -e "${WHITE}This wizard will guide you through setting up GPG signing for your commits.${RESET}"
    echo -e "${WHITE}This is required for verified commits on Hugging Face Hub and GitHub.${RESET}"
    echo ""

    # Check GPG installation
    if ! command -v gpg &> /dev/null; then
        print_error "GPG is not installed."
        if [[ "$OSTYPE" == "darwin"* ]]; then
             echo -e "${YELLOW}Please install it using: brew install gnupg${RESET}"
        else
             echo -e "${YELLOW}Please install GPG for your OS.${RESET}"
        fi
        return 1
    fi
    print_success "GPG is installed: $(gpg --version | head -n 1)"

    echo ""
    echo -e "${CYAN}Checking existing keys...${RESET}"
    # List keys and ensure at least one exists before proceeding if they want to check
    gpg --list-secret-keys --keyid-format LONG

    echo ""
    echo -e "${BRIGHT_YELLOW}Would you like to create a NEW key or use an EXISTING one?${RESET}"
    echo -e "1) Create NEW key (Recommended for fresh start)"
    echo -e "2) Use EXISTING key"
    read -p "Select option [1/2]: " key_option

    local gpg_key_id=""
    local gpg_email=""

    if [[ "$key_option" == "1" ]]; then
        print_info "Generating new GPG key..."
        echo -e "${YELLOW}IMPORTANT: Use the SAME email address as your Hugging Face & GitHub accounts.${RESET}"
        echo -e "${YELLOW}If you are unsure, check:${RESET}"
        echo -e "  - HF: https://huggingface.co/settings/account"
        echo -e "  - GH: https://github.com/settings/emails"
        
        # Interactive generation
        gpg --full-generate-key
        
        # Get the latest key
        echo -e "${CYAN}Detecting generated key...${RESET}"
        # Extract the last 'sec' line key ID
        gpg_key_id=$(gpg --list-secret-keys --keyid-format LONG | grep "sec" | tail -n 1 | awk '{print $2}' | cut -d'/' -f2)
        
        if [[ -z "$gpg_key_id" ]]; then
            print_error "Could not detect the new key. Please run 'gpg --list-secret-keys' and try again with option 2."
            return 1
        fi
        print_success "Detected new key ID: $gpg_key_id"
        
    elif [[ "$key_option" == "2" ]]; then
        echo -e "${CYAN}Please enter the GPG Key ID you want to use (from the list above):${RESET}"
        echo -e "Example format: 3AA5C34371567BD2"
        read -p "Key ID: " gpg_key_id
        
        if [[ -z "$gpg_key_id" ]]; then
            print_error "Key ID cannot be empty."
            return 1
        fi
    else
        print_error "Invalid option selected."
        return 1
    fi

    echo ""
    print_header "Exporting Public Key"
    
    echo -e "${WHITE}Step 1: Copy the block below (including BEGIN and END lines):${RESET}"
    echo -e "${BRIGHT_BLUE}-------------------------------------------------------${RESET}"
    gpg --armor --export "$gpg_key_id"
    echo -e "${BRIGHT_BLUE}-------------------------------------------------------${RESET}"
    
    echo -e "${WHITE}Step 2: Add to Hugging Face:${RESET}"
    echo -e "  Go to ${BRIGHT_BLUE}https://huggingface.co/settings/keys${RESET}"
    echo -e "  Click 'Add GPG Key' and paste."
    echo ""
    echo -e "${WHITE}Step 3: Add to GitHub:${RESET}"
    echo -e "  Go to ${BRIGHT_BLUE}https://github.com/settings/gpg/new${RESET}"
    echo -e "  Paste key and click 'Add GPG key'."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${YELLOW}Tip: Copy to clipboard? (y/n)${RESET}"
        read -p "Copy to clipboard? " copy_clip
        if [[ "$copy_clip" == "y" ]]; then
            gpg --armor --export "$gpg_key_id" | pbcopy
            print_success "Copied to clipboard!"
        fi
    fi

    echo ""
    read -p "Press ENTER once you have added the key to BOTH platforms..." confirm

    echo ""
    print_header "Configuring Git"
    
    # Configure Git
    echo -e "${CYAN}Configuring git to use key $gpg_key_id...${RESET}"
    git config --global user.signingkey "$gpg_key_id"
    git config --global commit.gpgsign true
    
    # Ask for email to match
    if [[ "$key_option" == "1" ]]; then
         echo -e "${YELLOW}Please confirm the email address you used for the key:${RESET}"
         read -p "Email: " gpg_email
    else
         echo -e "${YELLOW}What is the email address associated with this key?${RESET}"
         read -p "Email: " gpg_email
    fi
    
    if [[ -n "$gpg_email" ]]; then
         git config --global user.email "$gpg_email"
         print_success "Git user.email set to $gpg_email"
    fi

    # GPG Program setup (important for Mac)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local gpg_path=$(which gpg)
        if [[ -n "$gpg_path" ]]; then
            git config --global gpg.program "$gpg_path"
            print_success "Git gpg.program set to $gpg_path"
        fi
        
        # Check and Install pinentry-mac (Crucial for 'Inappropriate ioctl for device' error)
        if ! brew list pinentry-mac &>/dev/null; then
            echo ""
            echo -e "${BRIGHT_YELLOW}MacOS detected: Installing pinentry-mac to fix signing errors...${RESET}"
            echo -e "${WHITE}This prevents 'Inappropriate ioctl for device' errors by using a GUI password prompt.${RESET}"
            
            if brew install pinentry-mac; then
                print_success "Installed pinentry-mac"
            else
                print_error "Failed to install pinentry-mac. Please run: brew install pinentry-mac"
            fi
        fi

        # Configure gpg-agent
        local pinentry_path="/opt/homebrew/bin/pinentry-mac"
        if [[ ! -f "$pinentry_path" ]]; then
            pinentry_path="/usr/local/bin/pinentry-mac" # Intel fallback
        fi

        if [[ -f "$pinentry_path" ]]; then
             mkdir -p ~/.gnupg
             local agent_conf=~/.gnupg/gpg-agent.conf
             
             # Backup if exists
             if [[ -f "$agent_conf" ]]; then
                 cp "$agent_conf" "${agent_conf}.bak"
             fi
             
             # Update pinentry-program
             if grep -q "pinentry-program" "$agent_conf"; then
                 # specific replacement could be complex with sed, simpler to warn or overwrite if user agrees? 
                 # Let's append/replace safely.
                 sed -i.tmp '/pinentry-program/d' "$agent_conf"
                 rm -f "${agent_conf}.tmp"
             fi
             
             echo "pinentry-program $pinentry_path" >> "$agent_conf"
             print_success "Configured gpg-agent to use $pinentry_path"
             
             # Reload agent
             gpgconf --kill gpg-agent
             print_success "Restarted gpg-agent"
        else
             print_warning "Could not find pinentry-mac binary at expected locations."
        fi
        
        # Add GPG_TTY to shell config if missing
        local shell_config=~/.zshrc
        if [[ -f "$shell_config" ]]; then
            if ! grep -q "export GPG_TTY" "$shell_config"; then
                echo "" >> "$shell_config"
                echo '# GPG Signing' >> "$shell_config"
                echo 'export GPG_TTY=$(tty)' >> "$shell_config"
                print_success "Added GPG_TTY to $shell_config"
                echo -e "${YELLOW}Note: You may need to restart your terminal for shell changes to take effect.${RESET}"
            fi
        fi
    fi

    print_success "Git configured to sign all commits by default!"
    
    echo ""
    echo -e "${BRIGHT_GREEN}Setup Complete!${RESET}"
    echo -e "Try making a commit in a repo to test it: git commit -m 'Test signed commit'"
}
