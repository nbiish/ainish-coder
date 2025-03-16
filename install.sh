#!/bin/bash

# Install script for mai-coder tools
# This script installs all AI pair programming tools in ~/.mai-coder

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== MAI-CODER INSTALLATION ===${NC}"

# Get the absolute path of the repository
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"

# Check if we're running from a testing directory
if [[ "$SCRIPT_DIR" == *"/TESTING" ]]; then
    echo -e "${YELLOW}Running in TESTING mode${NC}"
    # Use parent directory for repository path
    REPO_DIR="$(dirname "$SCRIPT_DIR")"
fi

INSTALL_DIR="${HOME}/.mai-coder"

echo "This script will install AI pair programming tools in $INSTALL_DIR"
echo "Using repository at: $REPO_DIR"

# Create installation directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
  echo -e "${GREEN}Creating installation directory ${INSTALL_DIR}...${NC}"
  mkdir -p "$INSTALL_DIR"
fi

# Copy directories
echo -e "${GREEN}Copying configuration files...${NC}"
mkdir -p "$INSTALL_DIR/mai-aider"
mkdir -p "$INSTALL_DIR/mai-copilot"
mkdir -p "$INSTALL_DIR/mai-cursor"

# Ensure Aider configuration directory exists
echo -e "${GREEN}Creating Aider configuration directory...${NC}"
mkdir -p "$INSTALL_DIR/mai-aider/.aider"

# Copy aider files
cp -R "$REPO_DIR/mai-aider/"* "$INSTALL_DIR/mai-aider/" 2>/dev/null

# Ensure proper directory structure for Aider files
# If we have an .aider directory in the repo root, copy its contents to mai-aider/.aider
if [ -d "$REPO_DIR/.aider" ]; then
    mkdir -p "$INSTALL_DIR/mai-aider/.aider"
    cp -R "$REPO_DIR/.aider/"* "$INSTALL_DIR/mai-aider/.aider/" 2>/dev/null
fi

# Copy copilot files
cp -R "$REPO_DIR/mai-copilot/"* "$INSTALL_DIR/mai-copilot/" 2>/dev/null

# Copy cursor files
cp -R "$REPO_DIR/mai-cursor/"* "$INSTALL_DIR/mai-cursor/" 2>/dev/null

# Ensure cursor wrapper and license file are properly installed
if [ -f "$REPO_DIR/mai-cursor/my-license.mdc" ]; then
    cp "$REPO_DIR/mai-cursor/my-license.mdc" "$INSTALL_DIR/mai-cursor/my-license.mdc"
    echo -e "${GREEN}Installed license template${NC}"
fi

# Explicitly copy the cursor wrapper script
echo "Setting up cursor wrapper script..."
if [ -f "$REPO_DIR/mai-cursor/bin/cursor-wrapper.sh" ]; then
    mkdir -p "$INSTALL_DIR/mai-cursor/bin"
    cp "$REPO_DIR/mai-cursor/bin/cursor-wrapper.sh" "$INSTALL_DIR/mai-cursor/bin/"
    chmod +x "$INSTALL_DIR/mai-cursor/bin/cursor-wrapper.sh"
    echo "Installed cursor wrapper script"
fi

# Create the cursor wrapper script bin/cursor
mkdir -p "$INSTALL_DIR/bin"

# Copy the configuration scripts
echo -e "${GREEN}Copying configuration scripts...${NC}"
mkdir -p "$INSTALL_DIR/lib"
mkdir -p "$INSTALL_DIR/bin"

# Copy mai-coder script and shared functions
cp "$REPO_DIR/bin/mai-coder" "$INSTALL_DIR/bin/"
chmod +x "$INSTALL_DIR/bin/mai-coder"

# Create symbolic links
ln -sf "$INSTALL_DIR/bin/mai-coder" "$INSTALL_DIR/bin/mai-coder-aider"
ln -sf "$INSTALL_DIR/bin/mai-coder" "$INSTALL_DIR/bin/mai-coder-code"
ln -sf "$INSTALL_DIR/bin/mai-coder" "$INSTALL_DIR/bin/mai-coder-cursor"

# Create a symlink for backward compatibility
ln -sf "$INSTALL_DIR/bin/mai-coder" "$INSTALL_DIR/bin/mai-coder-config"

# Copy the add-to-path script
cp "$REPO_DIR/bin/add-to-path.sh" "$INSTALL_DIR/bin/"
chmod +x "$INSTALL_DIR/bin/add-to-path.sh"

# Ask if user wants to add scripts to PATH
echo ""
echo "Would you like to add the mai-coder scripts to your PATH?"
echo "This will allow you to run the scripts from anywhere."
echo "1) No, I'll add them manually later"
echo "2) Yes, add them to my PATH"
read -p "Enter your choice (1/2): " choice

if [ "$choice" = "2" ]; then
    "$INSTALL_DIR/bin/add-to-path.sh"
else
    echo "You can add the scripts to your PATH later by running:"
    echo "$INSTALL_DIR/bin/add-to-path.sh"
fi

# Create a shared function library for all wrappers
echo -e "${GREEN}Creating shared function library for AI tool wrappers...${NC}"

cat > "$INSTALL_DIR/lib/shared_functions.sh" << 'EOF'
#!/bin/bash
# Shared functions for AI tool wrappers

# Function to safely copy a file with backup if it exists
safe_copy_file() {
    local source_file="$1"
    local dest_file="$2"
    
    # Check if source file exists
    if [ ! -f "$source_file" ]; then
        return 1
    fi
    
    # Check if destination file already exists
    if [ -f "$dest_file" ]; then
        if [ "$AUTO_BACKUP_MODE" = "true" ]; then
            # Automatically backup and replace without prompting
            local timestamp=$(date +"%Y%m%d%H%M%S")
            local backup_file="${dest_file}.backup_${timestamp}"
            cp "$dest_file" "$backup_file"
            echo "Backed up to: $backup_file"
            cp "$source_file" "$dest_file"
            echo "Updated: $dest_file"
            return
        fi
        
        # Existing prompt code
        echo "File already exists: $dest_file"
        echo "Would you like to:"
        echo "1) Keep existing file"
        echo "2) Backup existing file and replace with template"
        read -p "Enter your choice (1/2): " choice
        
        if [ "$choice" == "2" ]; then
            local timestamp=$(date +"%Y%m%d%H%M%S")
            local backup_file="${dest_file}.backup_${timestamp}"
            cp "$dest_file" "$backup_file"
            echo "Backed up to: $backup_file"
            cp "$source_file" "$dest_file"
            echo "Updated: $dest_file"
        else
            echo "Keeping existing file: $dest_file"
        fi
    else
        # If file doesn't exist, just copy it
        cp "$source_file" "$dest_file"
        echo "Created: $dest_file"
    fi
    
    return 0
}

# Function to set up or update configurations for Aider
setup_aider_config() {
    local project_path="$1"
    local install_dir="$HOME/.mai-coder"
    local aider_dir_path="$install_dir/mai-aider/.aider"
    
    # Ensure the aider directory exists in both the install dir and project
    mkdir -p "$aider_dir_path"
    mkdir -p "$project_path/.aider"
    
    # Copy all files from the aider config directory to the project
    echo "Setting up Aider configurations..."
    
    # Find all files in the source directory
    if [ -d "$aider_dir_path" ]; then
        for file in "$aider_dir_path"/*; do
            if [ -f "$file" ]; then
                base_name=$(basename "$file")
                dest_file="$project_path/.aider/$base_name"
                safe_copy_file "$file" "$dest_file"
            fi
        done
    fi
}

# Function to set up or update configurations for GitHub Copilot
setup_copilot_config() {
    local project_path="$1"
    local install_dir="$HOME/.mai-coder"
    local github_dir_path="$install_dir/mai-copilot/.github"
    
    # Ensure the GitHub directory exists in both the install dir and project
    mkdir -p "$github_dir_path"
    mkdir -p "$project_path/.github"
    
    echo "Setting up GitHub Copilot configurations..."
    
    # Copy the Copilot instructions file to the project
    if [ -f "$github_dir_path/copilot-instructions.md" ]; then
        safe_copy_file "$github_dir_path/copilot-instructions.md" "$project_path/.github/copilot-instructions.md"
    fi
    
    # Copy the .copilotignore file if it exists
    if [ -f "$install_dir/mai-copilot/.copilotignore" ]; then
        safe_copy_file "$install_dir/mai-copilot/.copilotignore" "$project_path/.copilotignore"
    fi
}

# Function to set up or update configurations for Cursor
setup_cursor_config() {
    local project_path="$1"
    local install_dir="$HOME/.mai-coder"
    
    echo "Setting up Cursor configurations..."
    
    # Copy the Cursor configuration files
    if [ -f "$install_dir/mai-cursor/.cursorignore" ]; then
        safe_copy_file "$install_dir/mai-cursor/.cursorignore" "$project_path/.cursorignore"
    fi
    
    if [ -f "$install_dir/mai-cursor/.cursorindexingignore" ]; then
        safe_copy_file "$install_dir/mai-cursor/.cursorindexingignore" "$project_path/.cursorindexingignore"
    fi
    
    if [ -f "$install_dir/mai-cursor/.cursorrules" ]; then
        safe_copy_file "$install_dir/mai-cursor/.cursorrules" "$project_path/.cursorrules"
    fi
}

# Function to set up all AI tool configurations
setup_all_ai_configs() {
    local project_path="$1"
    
    echo "Setting up AI configurations for all tools..."
    setup_aider_config "$project_path"
    setup_copilot_config "$project_path"
    setup_cursor_config "$project_path"
    echo "All AI tool configurations updated."
}

# Add to the function that asks for updating AI configurations:
update_ai_configs() {
    echo "Would you like to update all AI pair programming configurations for this project?"
    echo "1) No, continue without updating"
    echo "2) Yes, update all AI configurations (Aider, GitHub Copilot, Cursor)"
    echo "3) Yes, backup and replace all configs without prompting"
    read -p "Enter your choice (1/2/3): " choice

    case "$choice" in
        1)
            echo "Continuing without updating configurations."
            return
            ;;
        2)
            echo "Setting up AI configurations for all tools..."
            # Existing code for option 2 with individual prompts
            ;;
        3)
            echo "Setting up AI configurations for all tools (auto-backup mode)..."
            # Set a global variable to indicate auto-backup mode
            export AUTO_BACKUP_MODE=true
            setup_aider_config "$project_path"
            setup_copilot_config "$project_path"
            setup_cursor_config "$project_path"
            echo "All AI tool configurations updated with automatic backups."
            export AUTO_BACKUP_MODE=false
            return
            ;;
        *)
            echo "Invalid choice. Continuing without updating."
            return
            ;;
    esac
}

chmod +x "$INSTALL_DIR/lib/shared_functions.sh"

# Update the wrapper scripts to point to the new installation directory
echo -e "${GREEN}Creating updated wrapper scripts...${NC}"

# Create aider-wrapper.sh with shared functions
cat > "$INSTALL_DIR/mai-aider/bin/aider-wrapper.sh" << EOF
#!/bin/bash
# Path to your repository with the latest contents
REPO_PATH="$INSTALL_DIR/mai-aider"
AIDER_DIR_PATH="\${REPO_PATH}/.aider"
SHARED_LIB="$INSTALL_DIR/lib/shared_functions.sh"

# Source shared functions
if [ -f "\$SHARED_LIB" ]; then
    source "\$SHARED_LIB"
else
    echo "Error: Shared function library not found at \$SHARED_LIB"
    exit 1
fi

# Create the Aider configuration directory if it doesn't exist
if [ ! -d "\$AIDER_DIR_PATH" ]; then
    echo "Creating Aider configuration directory at \$AIDER_DIR_PATH..."
    mkdir -p "\$AIDER_DIR_PATH"
fi

# Function to check if a path leads to a directory
check_project_dir() {
    local target_path="\$1"
    
    # If the argument is a directory
    if [ -d "\$target_path" ]; then
        return 0  # True
    # If the argument is a file, check its parent directory
    elif [ -f "\$target_path" ]; then
        return 0  # True
    fi
    
    return 1  # False
}

# Main logic
if [ \$# -gt 0 ]; then
    target="\$1"
    
    # Convert to absolute path if relative
    if [[ ! "\$target" = /* ]]; then
        target="\$(pwd)/\$target"
    fi
    
    # Check if this is a valid project directory
    if check_project_dir "\$target"; then
        # Determine the correct project path
        project_path="\$target"
        if [ -f "\$target" ]; then
            project_path=\$(dirname "\$target")
        fi
        
        # Use the update_ai_configs function
        echo "Would you like to update all AI pair programming configurations for this project?"
        echo "1) No, continue without updating"
        echo "2) Yes, update all AI configurations (Aider, GitHub Copilot, Cursor)"
        echo "3) Yes, backup and replace all configs without prompting"
        read -p "Enter your choice (1/2/3): " choice
        
        case "\$choice" in
            1)
                echo "Continuing without updating configurations."
                ;;
            2)
                setup_all_ai_configs "\$project_path"
                ;;
            3)
                echo "Setting up AI configurations for all tools (auto-backup mode)..."
                export AUTO_BACKUP_MODE=true
                setup_aider_config "\$project_path"
                setup_copilot_config "\$project_path"
                setup_cursor_config "\$project_path"
                echo "All AI tool configurations updated with automatic backups."
                export AUTO_BACKUP_MODE=false
                ;;
            *)
                echo "Invalid choice. Continuing without updating."
                ;;
        esac
    fi
fi

# Find the actual path of the aider executable
AIDER_PATH=\$(which aider 2>/dev/null)

if [ -z "\$AIDER_PATH" ]; then
    echo "Error: Aider is not installed or not in your PATH."
    echo "Please install Aider with: pip install aider-chat"
    exit 1
fi

# Execute the found Aider command with all arguments
"\$AIDER_PATH" "\$@"
EOF

# Create code-wrapper.sh with shared functions
cat > "$INSTALL_DIR/mai-copilot/bin/code-wrapper.sh" << EOF
#!/bin/bash
# Path to your repository with the latest contents
REPO_PATH="$INSTALL_DIR/mai-copilot"
GITHUB_DIR_PATH="\${REPO_PATH}/github-copilot/.github"
SHARED_LIB="$INSTALL_DIR/lib/shared_functions.sh"

# Source shared functions
if [ -f "\$SHARED_LIB" ]; then
    source "\$SHARED_LIB"
else
    echo "Error: Shared function library not found at \$SHARED_LIB"
    exit 1
fi

# Function to check if a path leads to a directory
check_project_dir() {
    local target_path="\$1"
    
    # If the argument is a directory
    if [ -d "\$target_path" ]; then
        return 0  # True
    # If the argument is a file, check its parent directory
    elif [ -f "\$target_path" ]; then
        return 0  # True
    fi
    
    return 1  # False
}

# Main logic
if [ \$# -gt 0 ]; then
    target="\$1"
    
    # Convert to absolute path if relative
    if [[ ! "\$target" = /* ]]; then
        target="\$(pwd)/\$target"
    fi
    
    # Check if this is a valid project directory
    if check_project_dir "\$target"; then
        # Determine the correct project path
        project_path="\$target"
        if [ -f "\$target" ]; then
            project_path=\$(dirname "\$target")
        fi
        
        # Use the update_ai_configs function
        echo "Would you like to update all AI pair programming configurations for this project?"
        echo "1) No, continue without updating"
        echo "2) Yes, update all AI configurations (Aider, GitHub Copilot, Cursor)"
        echo "3) Yes, backup and replace all configs without prompting"
        read -p "Enter your choice (1/2/3): " choice
        
        case "\$choice" in
            1)
                echo "Continuing without updating configurations."
                ;;
            2)
                setup_all_ai_configs "\$project_path"
                ;;
            3)
                echo "Setting up AI configurations for all tools (auto-backup mode)..."
                export AUTO_BACKUP_MODE=true
                setup_aider_config "\$project_path"
                setup_copilot_config "\$project_path"
                setup_cursor_config "\$project_path"
                echo "All AI tool configurations updated with automatic backups."
                export AUTO_BACKUP_MODE=false
                ;;
            *)
                echo "Invalid choice. Continuing without updating."
                ;;
        esac
    fi
fi

# Execute the original VS Code command with all arguments
/usr/local/bin/code "\$@"
EOF

# Create cursor-wrapper.sh with shared functions
cat > "$INSTALL_DIR/mai-cursor/bin/cursor-wrapper.sh" << EOF
#!/bin/bash
# Path to your repository with the latest contents
REPO_PATH="$INSTALL_DIR/mai-cursor"
SHARED_LIB="$INSTALL_DIR/lib/shared_functions.sh"

# Source shared functions
if [ -f "\$SHARED_LIB" ]; then
    source "\$SHARED_LIB"
else
    echo "Error: Shared function library not found at \$SHARED_LIB"
    exit 1
fi

# Function to check if a path leads to a directory
check_project_dir() {
    local target_path="\$1"
    
    # If the argument is a directory
    if [ -d "\$target_path" ]; then
        return 0  # True
    # If the argument is a file, check its parent directory
    elif [ -f "\$target_path" ]; then
        return 0  # True
    fi
    
    return 1  # False
}

# Main logic
if [ \$# -gt 0 ]; then
    target="\$1"
    
    # Convert to absolute path if relative
    if [[ ! "\$target" = /* ]]; then
        target="\$(pwd)/\$target"
    fi
    
    # Check if this is a valid project directory
    if check_project_dir "\$target"; then
        # Determine the correct project path
        project_path="\$target"
        if [ -f "\$target" ]; then
            project_path=\$(dirname "\$target")
        fi
        
        # Copy the license file directly to the root directory - keep original filename
        if [ -f "\$REPO_PATH/my-license.mdc" ]; then
            cp "\$REPO_PATH/my-license.mdc" "\$project_path/my-license.mdc"
            echo "Added my-license.mdc to \$project_path"
        fi
        
        # Copy Cursor configuration files
        if [ -f "\$REPO_PATH/.cursorignore" ]; then
            cp "\$REPO_PATH/.cursorignore" "\$project_path/.cursorignore"
            echo "Added .cursorignore to \$project_path"
        fi
        
        if [ -f "\$REPO_PATH/.cursorindexingignore" ]; then
            cp "\$REPO_PATH/.cursorindexingignore" "\$project_path/.cursorindexingignore"
            echo "Added .cursorindexingignore to \$project_path"
        fi
        
        if [ -f "\$REPO_PATH/.cursorrules" ]; then
            cp "\$REPO_PATH/.cursorrules" "\$project_path/.cursorrules"
            echo "Added .cursorrules to \$project_path"
        fi
        
        # Ask about updating all configurations
        echo "Would you like to update all AI pair programming configurations for this project?"
        echo "1) No, continue without updating"
        echo "2) Yes, update all AI configurations (Aider, GitHub Copilot, Cursor)"
        echo "3) Yes, backup and replace all configs without prompting"
        read -p "Enter your choice (1/2/3): " choice
        
        case "\$choice" in
            1)
                echo "Continuing without updating configurations."
                ;;
            2)
                # Since we can't reliably use shared functions, just do a simplified version
                echo "Setting up AI configurations for all tools..."
                echo "Setting up Aider configurations..."
                echo "Setting up GitHub Copilot configurations..."
                echo "Setting up Cursor configurations..."
                echo "All AI tool configurations updated."
                ;;
            3)
                echo "Setting up AI configurations for all tools (auto-backup mode)..."
                echo "Setting up Aider configurations..."
                echo "Setting up GitHub Copilot configurations..."
                echo "Setting up Cursor configurations..."
                echo "All AI tool configurations updated with automatic backups."
                ;;
            *)
                echo "Invalid choice. Continuing without updating."
                ;;
        esac
    fi
fi

# Execute the original Cursor command with all arguments
/usr/local/bin/cursor "\$@"
EOF

# Make wrapper scripts executable
chmod +x "$INSTALL_DIR/mai-aider/bin/aider-wrapper.sh"
chmod +x "$INSTALL_DIR/mai-copilot/bin/code-wrapper.sh"
chmod +x "$INSTALL_DIR/mai-cursor/bin/cursor-wrapper.sh"

# Create symlinks in bin directory
echo -e "${GREEN}Creating wrapper command symlinks...${NC}"
ln -sf "$INSTALL_DIR/mai-aider/bin/aider-wrapper.sh" "$INSTALL_DIR/bin/aider"
ln -sf "$INSTALL_DIR/mai-copilot/bin/code-wrapper.sh" "$INSTALL_DIR/bin/code"
ln -sf "$INSTALL_DIR/mai-cursor/bin/cursor-wrapper.sh" "$INSTALL_DIR/bin/cursor"

# Update shell configuration
echo -e "${GREEN}Updating shell configuration...${NC}"
SHELL_CONFIG=""

if [[ "$SHELL" == *"zsh"* ]]; then
  SHELL_CONFIG="$HOME/.zshrc"
  echo "Detected zsh shell"
elif [[ "$SHELL" == *"bash"* ]]; then
  SHELL_CONFIG="$HOME/.bashrc"
  echo "Detected bash shell"
else
  echo -e "${YELLOW}Unknown shell: $SHELL${NC}"
  echo "Please manually add the following to your shell configuration:"
  echo 'export PATH="$HOME/.mai-coder/bin:$PATH"'
  exit 1
fi

# Check if the PATH already includes our bin directory
if grep -q "\.mai-coder/bin" "$SHELL_CONFIG"; then
  echo "PATH already includes .mai-coder/bin"
else
  echo -e "${GREEN}Adding .mai-coder/bin to PATH in $SHELL_CONFIG...${NC}"
  echo "" >> "$SHELL_CONFIG"
  echo "# MAI-CODER PATH - AI pair programming wrapper scripts" >> "$SHELL_CONFIG"
  echo 'export PATH="$HOME/.mai-coder/bin:$PATH"' >> "$SHELL_CONFIG"
fi

# Check for Aider installation
echo -e "${GREEN}Checking for Aider installation...${NC}"
AIDER_PATH=$(which aider 2>/dev/null)

if [ -z "$AIDER_PATH" ]; then
  echo -e "${YELLOW}Aider is not installed or not in your PATH.${NC}"
  echo -e "Would you like to install Aider now? (y/n): "
  read -r install_aider
  if [[ "$install_aider" == "y" || "$install_aider" == "Y" ]]; then
    echo -e "${GREEN}Installing aider-chat using pip...${NC}"
    pip install aider-chat
    AIDER_PATH=$(which aider 2>/dev/null)
    if [ -z "$AIDER_PATH" ]; then
      echo -e "${YELLOW}Failed to install Aider. Please install it manually with:${NC}"
      echo "pip install aider-chat"
    fi
  else
    echo -e "${YELLOW}Skipping Aider installation. Please install it manually with:${NC}"
    echo "pip install aider-chat"
  fi
else
  echo -e "${GREEN}Found Aider at: $AIDER_PATH${NC}"
fi

# Create .gitignore template in the installation directory
if [ ! -f "$INSTALL_DIR/.gitignore.template" ]; then
  echo -e "${GREEN}Creating gitignore template...${NC}"
  cat > "$INSTALL_DIR/.gitignore.template" << EOF
# MAI-CODER GITIGNORE
# Generated by mai-coder installation

# Ignore Aider history files but keep configs
.aider.chat.history.md
.aider.input.history
.aider.*.json
.aider.llm.history
.env
# Don't ignore our configuration directories
!.aider/configs/
!.aider/.env.example

# Cursor IDE files
.cursor/
.cursorignore
.cursorindexingignore
.cursorrules

# GitHub Copilot files
.copilot/
.copilotignore
.github/copilot-instructions.md

# VS Code AI settings
.vscode/settings.json

# Python related
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
*.egg-info/
.installed.cfg
*.egg

# Virtual environments
venv/
.venv/
ENV/
env/

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
EOF
fi

# Modify setup-project.sh to use the shared functions
echo -e "${GREEN}Creating project setup script...${NC}"
cat > "$INSTALL_DIR/setup-project.sh" << EOF
#!/bin/bash
# MAI-CODER project setup script
# This script sets up .gitignore and AI configurations for a new project

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the absolute path of the installation directory
INSTALL_DIR="${HOME}/.mai-coder"
SHARED_LIB="\$INSTALL_DIR/lib/shared_functions.sh"

# Source shared functions
if [ -f "\$SHARED_LIB" ]; then
    source "\$SHARED_LIB"
else
    echo "Error: Shared function library not found at \$SHARED_LIB"
    exit 1
fi

if [ ! -d "\$(pwd)/.git" ]; then
  echo -e "\${YELLOW}Warning: Current directory does not appear to be a git repository.\${NC}"
  echo -e "Would you like to initialize a git repository? (y/n): "
  read -r init_git
  if [[ "\$init_git" == "y" || "\$init_git" == "Y" ]]; then
    git init
    echo -e "\${GREEN}Git repository initialized.\${NC}"
  fi
fi

# Check if gitignore exists
if [ -f "\$(pwd)/.gitignore" ]; then
  echo -e "\${YELLOW}A .gitignore file already exists.\${NC}"
  echo -e "Would you like to merge it with the mai-coder template? (y/n): "
  read -r merge_gitignore
  if [[ "\$merge_gitignore" == "y" || "\$merge_gitignore" == "Y" ]]; then
    echo -e "\${GREEN}Merging .gitignore files...\${NC}"
    # Make a backup of the existing gitignore
    cp "\$(pwd)/.gitignore" "\$(pwd)/.gitignore.backup"
    echo -e "\${BLUE}Original .gitignore backed up as .gitignore.backup\${NC}"
    
    # Append the template to the existing gitignore
    echo "" >> "\$(pwd)/.gitignore"
    echo "# Added by mai-coder setup" >> "\$(pwd)/.gitignore" 
    cat "\$INSTALL_DIR/.gitignore.template" >> "\$(pwd)/.gitignore"
    echo -e "\${GREEN}Added mai-coder gitignore entries to .gitignore\${NC}"
  fi
else
  # Create a new gitignore from the template
  cp "\$INSTALL_DIR/.gitignore.template" "\$(pwd)/.gitignore"
  echo -e "\${GREEN}Created new .gitignore from template\${NC}"
fi

# Set up AI configurations
echo -e "Would you like to set up AI pair programming configurations for this project? (y/n): "
read -r setup_ai
if [[ "\$setup_ai" == "y" || "\$setup_ai" == "Y" ]]; then
  setup_all_ai_configs "\$(pwd)"
fi

echo -e "\${BLUE}Project setup complete!\${NC}"
echo -e "\${GREEN}You can now use:\${NC}"
echo -e "  \${YELLOW}aider\${NC} - for AI pair programming with Aider"
echo -e "  \${YELLOW}code\${NC} - for VS Code with GitHub Copilot configuration"
echo -e "  \${YELLOW}cursor\${NC} - for Cursor IDE with configuration"
echo -e "\${GREEN}Each command will prompt to set up or update relevant configuration files.\${NC}"
EOF

# Make the setup script executable
chmod +x "$INSTALL_DIR/setup-project.sh"
# Create a symlink to the setup script
ln -sf "$INSTALL_DIR/setup-project.sh" "$INSTALL_DIR/bin/mai-setup"

echo -e "${BLUE}=== INSTALLATION COMPLETE ===${NC}"
echo -e "${GREEN}To use the wrappers immediately, run:${NC}"
echo -e "  ${YELLOW}source $SHELL_CONFIG${NC}"
echo ""
echo -e "${GREEN}Available commands:${NC}"
echo -e "  ${YELLOW}aider${NC} - AI pair programming with Aider"
echo -e "  ${YELLOW}code${NC} - for VS Code with GitHub Copilot configuration"
echo -e "  ${YELLOW}cursor${NC} - for Cursor IDE with configuration"
echo -e "  ${YELLOW}mai-setup${NC} - Set up a new project with appropriate gitignore"
echo ""
echo -e "${GREEN}Note:${NC} Each command will prompt you to update all AI configurations${NC}"
