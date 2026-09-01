# TASK.2026-09-01.audit-critical-rerun

**Branch:** `chore/audit-critical-rerun` (worktree `../critical-rerun`, from `main` @ `43a72ac`)

## Operator contract
1. Re-run `critical.md` specifications for the `ainish-coder` repository following upstream updates to `license-for-all-works`.
2. Sync core documentation: `LICENSE` (from `working-LICENSE`), `CONTRIBUTING.md`, `Terms-of-Service.md`, `Privacy-Policy.md`, and `critical.md`.
3. Verify citation, support/donation section, `.github/FUNDING.yml`, and copyright notices against `critical.md` v2.0.0.
4. Run all security and lint checks, audit for secrets or banned crypto.
5. Record comms and prepare for operator merge confirmation.

## Actions Executed
- Refreshed `critical.md` from canonical source `https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/critical.md` (updated to Version 2.0.0).
- Refreshed `LICENSE` from canonical active text `https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/working-LICENSE`.
- Refreshed `CONTRIBUTING.md` from canonical source `https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/CONTRIBUTING.md`.
- Refreshed `Terms-of-Service.md` from canonical source `https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/Terms-of-Service.md` (updated to Version 3.1.0).
- Refreshed `Privacy-Policy.md` from canonical source `https://raw.githubusercontent.com/nbiish/license-for-all-works/refs/heads/main/Privacy-Policy.md` (no drift).
- Verified `assets/qr-stripe-donation.png` and `assets/buy-me-a-coffee.svg` match canonical assets.
- Audited `README.md` BibTeX citation (§ 2), donation HTML block (§ 3), and copyright notice (§ 5).
- Audited `.github/FUNDING.yml` (§ 4).
- Executed `bin/security_gate.py` (Zero-Trust and PQC compliance check passed).

## Verification
- `git diff --stat`: 5 files synced cleanly.
- Zero-Trust / PQC gate: PASS (`[PASS] No banned classical signatures or unverified open paths detected.`).
