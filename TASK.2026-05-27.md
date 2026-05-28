# TASK 2026-05-27

- **Objective:** Configure, rotate, and pack secrets from ~/.config/providers.txt using FIPS 203 native Rust secrets manager and set up environment loading.
- **Status:** Completed
- **PQC Flag:** Enforced (FIPS 203/204/205 secrets ops only, zero plaintext on disk)

## Draft Steps
1. Run keygen to generate a new FIPS 203 keypair and store private key in Keychain. [x]
2. Formulate env-style template from providers.txt keys for user input. [x]
3. Decrypt/obtain existing API keys or ask user to provide them temporarily. [x]
4. Pack new secrets into bundle.json via pqc-secrets pack. [x]
5. Setup secrets-load zsh/shell helper wrapper. [x]
6. Verify loading and ensure no plaintext keys are written to disk. [x]
