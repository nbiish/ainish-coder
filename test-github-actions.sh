#!/bin/bash
# Test the GitHub Actions locally using act
# Install act: brew install act

set -e

echo "🧪 Testing GitHub Actions locally..."
echo ""

if ! command -v act &> /dev/null; then
    echo "❌ 'act' is not installed"
    echo "Install with: brew install act"
    exit 1
fi

echo "Select workflow to test:"
echo "1) auto-sanitize.yml - Test automatic sanitization"
echo "2) detect-secrets.yml - Test secret detection"
echo "3) Both"
echo ""

read -p "Choice (1-3): " choice

case $choice in
    1)
        echo "Testing auto-sanitize workflow..."
        act push -W .github/workflows/auto-sanitize.yml
        ;;
    2)
        echo "Testing detect-secrets workflow..."
        act push -W .github/workflows/detect-secrets.yml
        ;;
    3)
        echo "Testing both workflows..."
        act push -W .github/workflows/auto-sanitize.yml
        act push -W .github/workflows/detect-secrets.yml
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ Test complete! Check output above for results."
