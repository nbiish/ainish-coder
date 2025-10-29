#!/bin/bash
# Wrapper script to execute the main setup script

# Get the directory of this wrapper script
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to the main script
MAIN_SCRIPT="${ROOT_DIR}/lib/physical-entity/ainish-setup.sh"

# Execute the main script, passing all arguments
if [[ -f "$MAIN_SCRIPT" ]]; then
    bash "$MAIN_SCRIPT" "$@"
else
    echo "Error: Main setup script not found at $MAIN_SCRIPT"
    exit 1
fi
