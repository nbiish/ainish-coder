# Security Workflow

`security.yml` is the repository's enforced security workflow. It runs on pull
requests, pushes to `main`, weekly, and on demand.

## Checks

- **Secret scan:** Runs `.github/scripts/scan_secrets.sh` against repository content.
- **PQC and containment gate:** Runs `bin/security_gate.py` against supported source and configuration files.
- **Shell syntax:** Parses every shell script under `bin/`, `scripts/`, and `src/`.
- **Rust dependency audit:** Runs `cargo audit` for both locked Rust projects.

The workflow has `contents: read` permission only and does not modify branches,
comments, or files. Findings must be fixed in the pull request before merging.

## Local Verification

```bash
bash .github/scripts/scan_secrets.sh
python3 bin/security_gate.py .
find bin scripts src -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
(cd src/cmd-tracker && cargo audit)
(cd src/pqc-secrets && cargo audit)
```

The scanners intentionally exclude their own pattern definitions, generated
research trees, task history, and documentation examples where heuristic
matches are not production code. Secret scanning still covers tracked source
and configuration content outside those exclusions.
