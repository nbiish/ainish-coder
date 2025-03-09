#!/bin/bash
# Test script for mai-coder

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test the mai-coder script
echo "=== Testing mai-coder --help ==="
"$SCRIPT_DIR/mai-coder" --help

echo ""
echo "=== Testing mai-coder-aider with help flag ==="
"$SCRIPT_DIR/mai-coder-aider" --help

echo ""
echo "=== Creating test project directory ==="
TEST_DIR="/tmp/mai-coder-test"
mkdir -p "$TEST_DIR"
echo "Test directory created at: $TEST_DIR"

echo ""
echo "=== Testing mai-coder for current directory ==="
# Using pwd as the explicit path to test with a valid path
"$SCRIPT_DIR/mai-coder" "$(pwd)" --help

echo ""
echo "Verification complete!"
echo "If all the above tests ran without errors, the script is working correctly." 