#!/usr/bin/env bash
# ◈──◆──◇ sync-critical.sh ◇──◆──◈
# Canonical refresh script for critical.md and the governing legal framework
# Fetches current active versions from canonical raw GitHub sources per critical.md § 1.2 & § 1.3:
# Canonical upstream: https://github.com/nbiish/license-for-all-works

set -euo pipefail

# Resolve repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo -e "\033[0;34m◈──◆──◇ Refreshing critical.md & Legal Framework from Canonical GitHub ◇──◆──◈\033[0m"

# 1. Critical repository standards (§ 1.2)
echo -e "▸ Fetching critical.md..."
curl -fLo "${REPO_DIR}/critical.md" \
  https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/critical.md

# 2. Governing legal framework (§ 1.3)
echo -e "▸ Fetching active LICENSE (working-LICENSE)..."
curl -fLo "${REPO_DIR}/LICENSE" \
  https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/working-LICENSE

echo -e "▸ Fetching CONTRIBUTING.md..."
curl -fLo "${REPO_DIR}/CONTRIBUTING.md" \
  https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/CONTRIBUTING.md

echo -e "▸ Fetching Terms-of-Service.md..."
curl -fLo "${REPO_DIR}/Terms-of-Service.md" \
  https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/Terms-of-Service.md

echo -e "▸ Fetching Privacy-Policy.md..."
curl -fLo "${REPO_DIR}/Privacy-Policy.md" \
  https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/Privacy-Policy.md

echo -e "▸ Fetching Tribal-Consulting-Agreement.md..."
curl -fLo "${REPO_DIR}/Tribal-Consulting-Agreement.md" \
  https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/Tribal-Consulting-Agreement.md

# 3. Support and donation assets (§ 3.1)
mkdir -p "${REPO_DIR}/assets"

echo -e "▸ Fetching qr-stripe-donation.png..."
curl -fLo "${REPO_DIR}/assets/qr-stripe-donation.png" \
  https://raw.githubusercontent.com/nbiish/license-for-all-works/8e9b73b269add9161dc04bbdd79f818c40fca14e/qr-stripe-donation.png

echo -e "▸ Fetching buy-me-a-coffee.svg..."
curl -fLo "${REPO_DIR}/assets/buy-me-a-coffee.svg" \
  "https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=&slug=nbiish&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff"

echo -e "▸ Fetching sanitized_LICENSE-qr-code.svg..."
curl -fLo "${REPO_DIR}/assets/sanitized_LICENSE-qr-code.svg" \
  https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/sanitized_LICENSE-qr-code.svg

echo -e "\033[0;32m✓ All critical repository standards and legal instruments synchronized successfully.\033[0m"