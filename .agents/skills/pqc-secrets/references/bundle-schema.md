---
name: bundle-schema
description: JSON schema for the PQC secrets bundle file at ~/.config/pqc-secrets/secrets.bundle.json. Field reference with verified names from the live bundle.
---

# Bundle JSON Schema

The bundle file at `~/.config/pqc-secrets/secrets.bundle.json` is the
canonical encrypted store. **Safe to commit** — every value is
AES-256-GCM ciphertext wrapped by ML-KEM-768.

## Top-level structure

```json
{
  "version": 1,
  "alg": "ML-KEM-768+AES-256-GCM",
  "engine": "pqc-secrets@0.4.2",
  "created_utc": "2026-06-07T14:47:12Z",
  "recipient": { ... },
  "kem": { ... },
  "keywrap": { ... },
  "data": { ... }
}
```

## Field reference

| Field | Type | Required | Meaning |
|---|---|---|---|
| `version` | integer | yes | Bundle format version. Currently `1`. |
| `alg` | string | yes | Algorithm descriptor. `ML-KEM-768+AES-256-GCM` for v1. |
| `engine` | string | yes | Engine version, e.g. `pqc-secrets@0.4.2`. |
| `created_utc` | string | yes | ISO 8601 UTC timestamp. |
| `recipient` | object | yes | Public key metadata. |
| `kem` | object | yes | ML-KEM-768 encapsulation. |
| `keywrap` | object | yes | Wrapping of the data key (reserved for future AAD). |
| `data` | object | yes | AES-256-GCM ciphertext + IV + tag. |

**Field name conventions** (verified against the live bundle):

- `alg`, NOT `algorithm`
- `created_utc`, NOT `createdAt` or `created_at_pretty`
- `recipient`, `kem`, `keywrap`, `data` — all lowercase, no separators

## `recipient` object

```json
{
  "public_key": "BASE64...",
  "fingerprint": "sha256:9f86d081..."
}
```

| Field | Type | Meaning |
|---|---|---|
| `public_key` | string | Base64-encoded ML-KEM-768 public key (1184 B encoded). |
| `fingerprint` | string | `sha256:<hex>` of the public key bytes (not the base64). |

## `kem` object

```json
{
  "ciphertext": "BASE64...",
  "algorithm": "ML-KEM-768"
}
```

| Field | Type | Meaning |
|---|---|---|
| `ciphertext` | string | Base64-encoded ML-KEM-768 KEM ciphertext (1088 B encoded). |
| `algorithm` | string | `ML-KEM-768` (for clarity; the `alg` top-level field also names it). |

## `keywrap` object

```json
{
  "wrapped_key": "BASE64...",
  "aad": ""
}
```

| Field | Type | Meaning |
|---|---|
| `wrapped_key` | string | Base64-encoded wrapped data key (32 B encoded). Currently the same as `kem.ciphertext` in v1. |
| `aad` | string | Additional authenticated data; empty string in v1. Reserved for future AAD chains. |

## `data` object

```json
{
  "ciphertext": "BASE64...",
  "iv": "BASE64...",
  "tag": "BASE64...",
  "algorithm": "AES-256-GCM",
  "aad": "pqc-secrets-v1"
}
```

| Field | Type | Meaning |
|---|---|---|
| `ciphertext` | string | Base64-encoded encrypted plaintext (length varies with bundle contents). |
| `iv` | string | Base64-encoded 96-bit IV (12 B encoded). |
| `tag` | string | Base64-encoded 128-bit GCM tag (16 B encoded). |
| `algorithm` | string | `AES-256-GCM`. |
| `aad` | string | Additional authenticated data; `pqc-secrets-v1` for v1. |

## Size reference (approximate)

| Field | Encoded size (B) | Raw size (B) |
|---|---|---|
| `recipient.public_key` | ~1580 | 1184 |
| `kem.ciphertext` | ~1452 | 1088 |
| `keywrap.wrapped_key` | ~44 | 32 |
| `data.iv` | ~16 | 12 |
| `data.tag` | ~24 | 16 |

A bundle with 12 keys typically weighs 4 KB on disk.

## Versioning

`version: 1` is the only supported version as of 2026-06. Future
versions will be additive (new optional fields) and the verifier
will accept any v1.x bundle.

## Validation

```bash
$ python3 .agents/skills/pqc-secrets/scripts/verify-bundle.py
OK: bundle validates, 1 recipient, 0 plaintext leaks
$ echo $?
0
```

The verifier checks: required fields, KEM ciphertext length (≥ 1000 B),
AES-GCM tag length (≥ 16 B), and scans for plaintext secret patterns
(`sk-live`, `sk-test`, `whsec_`, `AKIA`, `ghp_`).

## Anti-patterns in code that parses bundles

- DO NOT use generic JSON parsers without validating field names.
  A bundle with `algorithm` instead of `alg` is invalid.
- DO NOT trust the `version` field blindly — always re-check field
  presence for the version you support.
- DO NOT modify the bundle by hand. Use `pqc-secrets pack` /
  `rotate` / `export | grep | pack` flows.
- DO NOT commit a bundle whose `data.ciphertext` is empty (zero-key
  bundle is OK, but a bundle with no data field is corrupt).

## See also

- `references/pqc-secrets-cli.md` — CLI reference
- `references/audit-log.md` — audit log format
