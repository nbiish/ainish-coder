# TASK 2026-05-28

- **Objective:** Reorganize the repository structure to match the MAQ hierarchy and clean up loose/deprecated files.
- **Status:** Completed
- **PQC Flag:** Enforced (FIPS 203/204/205 secrets ops only, zero plaintext on disk)

## Draft Steps
1. Reorganize directory structure (src/quanta/, src/atoms/, src/molecules/, docs/, assets/, scripts/). [x]
2. Clean up temporary files, empty directories, and extract scrolls-lab to its own private repo. [x]
3. Update source paths in CLI entry point and deploy helper scripts. [x]
4. Verify CLI runs correctly and no broken references remain. [x]
5. Commit and request user approval to merge. [x]
