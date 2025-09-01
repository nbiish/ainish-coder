#!/bin/bash
# Cursor wrapper script for opening files in Cursor

# If no arguments provided, open current directory
if [ $# -eq 0 ]; then
    open -a Cursor .
else
    # Open each file/directory provided as argument
    for file in "$@"; do
        open -a Cursor "$file"
    done
fi
