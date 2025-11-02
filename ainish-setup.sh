#!/bin/bash
# Wrapper script to execute the main ainish-coder command

# Get the directory of this wrapper script
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to the main script
MAIN_SCRIPT="${ROOT_DIR}/bin/ainish-coder"

# Execute the main script, passing all arguments
if [[ -f "$MAIN_SCRIPT" ]]; then
    bash "$MAIN_SCRIPT" "$@"
else
    echo "Error: Main script not found at $MAIN_SCRIPT"
    exit 1
fi
