# TASK.2026-09-05.sync-critical-deployment

**Branch:** `chore/deploy-sync-critical` (worktree `../ainish-coder-sync-critical`, from `main` @ `3a0c340`)

## Operator contract
1. Pull down the latest `critical.md` and related governing legal framework directly from raw GitHub user content (`nbiish/license-for-all-works`).
2. Run the latest version standards through the repository:
   - Refreshed `critical.md` (v2.0.0, 11,765 bytes from canonical source `https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/critical.md`).
   - Refreshed `LICENSE` (470,219 bytes from canonical active text `https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/working-LICENSE`).
   - Refreshed `CONTRIBUTING.md` (82,917 bytes from canonical source `https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/CONTRIBUTING.md`).
   - Refreshed `Terms-of-Service.md` (74,121 bytes from canonical source `https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/Terms-of-Service.md`).
   - Refreshed `Privacy-Policy.md` (96,723 bytes from canonical source `https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/Privacy-Policy.md`).
   - Pulled down companion legal instrument `Tribal-Consulting-Agreement.md` (47,844 bytes from canonical source).
   - Verified and synchronized donation assets `assets/qr-stripe-donation.png` (57,622 bytes) and `assets/buy-me-a-coffee.svg` (29,497 bytes), plus `assets/sanitized_LICENSE-qr-code.svg` (81,669 bytes).
   - Verified `.github/FUNDING.yml` (§ 4).
   - Audited `README.md` BibTeX citation (§ 2), donation HTML block (§ 3), and copyright notice (§ 5).
3. Hardened deployment modules for downstream repository deployments:
   - `src/deploy_critical.sh`: Updated to deploy `critical.md` along with companion donation assets (`assets/`) and `.github/FUNDING.yml`.
   - `src/deploy_license.sh`: Updated to deploy `LICENSE` along with all companion legal framework instruments (`CONTRIBUTING.md`, `Terms-of-Service.md`, `Privacy-Policy.md`, `Tribal-Consulting-Agreement.md`).
   - `bin/ainish-coder`: Updated confirmation prompts for `--critical` and `--license` to reflect full standards deployment.
   - `src/help.sh`: Updated utility command help descriptions.
   - `scripts/sync-critical.sh`: Created canonical refresh script for automated synchronization from raw GitHub.
4. Updated `llms.txt` Child DOX Index to track `scripts/sync-critical.sh`.
5. Updated `bin/security_gate.py` to exclude local `.gitnexus` and `.claude` artifacts.
6. Verification passed:
   - `bin/security_gate.py`: PASS (Zero-Trust and PQC compliance check passed).
   - `gitnexus detect-changes --repo ainish-coder`: PASS (No unintended symbol changes).
   - Tested deployment with `ainish-coder -y --critical` and `ainish-coder -y --license`: PASS.
   - Tested `scripts/sync-critical.sh`: PASS (all 9 canonical resources fetched successfully).
