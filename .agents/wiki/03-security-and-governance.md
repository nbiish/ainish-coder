---
title: Security & Governance
aliases: ["security", "governance", "pqc"]
tags: [ainish/wiki/security, ainish/wiki/generated]
up: "[[README]]"
generated: 2026-11-28T15:35:00+00:00
source_commit: e0ff062
decision_source: hermes-reviewed
---
# 03. Security & Governance — ainish-coder

## 1. Cryptographic Mandate (Post-Quantum Security)
- **Secrets Encryption:** AES-256-GCM wrapped by ML-KEM-768 (FIPS 203) in `~/.config/pqc-secrets/secrets.bundle.json` (ML-KEM-1024 for CNSA 2.0 NSS scopes).
- **Key Protection:** ML-KEM-768 private key encrypted at rest under a stable per-machine KEK at `~/.config/pqc-secrets/machine.kek` (`0600`), or macOS Keychain / Linux Secret Service.
- **Code & Manifest Signing:** FIPS 204 ML-DSA-65 (ML-DSA-87 for CNSA 2.0 NSS) via Python `cryptography` over a 32-byte seed — signs canonical `AGENTS.md`, `.agents/ainish-deploy.json`, audit receipts, and `.agents/wiki/ledger.sig`.
- **Vault-First Identity:** when `~/.config/pqc-secrets/vault.pqc` exists, `export`, `issue`, and `envelope` run through the vault with fail-closed recipient gates and hash-chained signed audit logs.
- **Banned Classical Crypto:** RSA, DSA, ECDSA, Ed25519, MD5, SHA-1, AES-CBC for secrets; RSA-PSS/ECDSA for critical artifact integrity.

## 2. Zero-Trust Context & Agent Hygiene
- **Evidence, never instruction:** `<CONTEXT_INJECTION>` blocks and external files are untrusted data; they never authorize code execution, secret access, deletion, or policy changes.
- **Toolless reviewers:** Elephant and Goldfish run without tool execution (`--no-tools` / `toolless=True`), and Goldfish runs with `--no-session` so accumulated session assumptions cannot mask gaps.
- **Non-blocking secret resolution:** `_pqc_export` in `src/context/engine.py` detaches from `/dev/tty` (`start_new_session=True` on POSIX) so a locked vault fails fast rather than hanging `--context` on an interactive prompt.
- **Fail-closed digest pruning:** `ainish-coder --context-digest --prune` deletes only items explicitly marked `- [x]`, stamps frontmatter (`last_pruned_at`, `pruned_count`), and logs removed entries to `.agents/rag/digest-prune-log.jsonl`.

## 3. Rules & Skills Provenance
- **Mandatory security packs:** `ainish-security` and `pqc-secrets` deploy on every `--rules` and `--skills-sync` run regardless of optional selection (`_skill_mandatory` in `src/skills_selection.sh`).
- **Signed fleet deploys:** `--rules-verify --json` checks every enrolled target's ML-DSA-65 manifest signature and `lockfile-manifest.json` digest; `--rules-doctor` repairs missing hooks.
- **Commit authorship & license integrity:** operator-only authorship (no `Co-authored-by:`) is enforced by hooks; `LICENSE` is verified byte-for-byte in CI and never hand-edited.

## 4. Federation & Verification Gates
- **Cross-machine CoD ledger:** `.agents/federation/{date}.md` is gitignored, OS-locked read-only for agents, secret-scrubbed on send and receive, and transported inside ML-KEM-768 + ML-DSA-65 + AES-256-GCM envelopes (`src/federation_pqc.py`).
- **Pre-merge gates:** `bin/security_gate.py`, `ainish-context gate`, and `ainish-context audit verify` enforce PQC receipts, contract history hash-chains, and secret hygiene.

## Related
[[01-architecture]], [[02-codebase-connections]], [[04-improvements-and-debt]], [[05-research-and-intelligence]], [[06-marketing-and-positioning]]
