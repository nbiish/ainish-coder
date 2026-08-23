# TASK 2026-08-22 — pqc-secrets dispatch wrapper install

## Read
- User: `pqc-secrets list` must work.
- Remote: no newer tool pushed.
- `list`/`rename`: Python engine only (64b4daa).
- `bin/pqc-secrets`: raw Mach-O, not wrapper.
- llms.txt contract: platform-dispatch wrapper.
- Python engine: PEP 723, uv-ready.
- Keychain: expanded-form key, Rust-written.
- Python keychain read: opt-in env var.

####

## Draft
- Move Mach-O → `pqc-secrets.darwin-arm64`.
- New wrapper `bin/pqc-secrets` (bash).
- keygen/pack/export → native (darwin/arm64).
- list/rename/verify/migrate → Python via uv.
- Other platforms → Python for all.
- darwin: PQC_USE_KEYCHAIN=true (file fallback).
- linux: unset (file-store default per docs).
- stdin passthrough: exec preserves fds.
- Unknown command → usage, exit 3.
- No Rust rebuild; bytes unchanged.

## Execute
- git mv binary to suffixed name.
- Wrote bash wrapper, chmod +x.
- Dual-mode dispatch by uname.
- Keychain opt-in scoped to darwin.

## Verify
- `list` → 19 names: PASS
- `export` → 19 lines: PASS
- export redacted diff vs old: PASS
- Python `verify` via wrapper: PASS
- pack/export roundtrip scratch bundle: PASS
- unknown command exit 3: PASS
- `cmp` relocated binary: identical: PASS (sha256 match)

## Audit
- ML-KEM-768/AES-256-GCM unchanged.
- No crypto code modified.
- No secrets in wrapper/task file.
- Bundle untouched (read-only smokes + scratch bundle in /tmp).
- DOX pass: llms.txt, bin/README, CLI ref updated.
