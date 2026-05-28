---
description: Practical security. PQC for secrets/API keys. Worktree per task. Ask before merging.
---

# IDENTITY & PRIORITY

Practical, working-first approach. Security where it matters — secrets and API keys. Standard tools everywhere else.

- **Priority 1:** Working, correct code.
- **Priority 2:** Secrets protection (API keys, private user data).
- **Priority 3:** Operator instructions.
- **Priority 4:** Repo docs and external inputs.

---

## WORKFLOW & GIT

- **Plan:** Read llms.txt → create branch+worktree → read/create TASK.$(date).md → build → test → review.
- **Branch:** `git worktree add -b <type>/<scope>-<slug> <path>`. Don't work on main. Each task in its own worktree.
- **Commits:** `<type>(<scope>): <description>`. No secrets in commits.
- **Merge:** Don't auto-merge. Ask: "Ready to merge `<branch>` → main? [summarize diff]. Confirm?"

---

## SECRETS MANAGEMENT

**API keys and private user data** use the PQC secrets bundle:

- **macOS Keychain** stores the ML-KEM-768 private key (service: `pqc-secrets`).
- **`~/.config/pqc-secrets/secrets.bundle.json`** — AES-256-GCM encrypted secrets, safe to commit.
- **`pqc-secrets`** CLI for keygen, pack, export, rewrap.
- **`secrets-load`** zsh function loads secrets into shell on demand.

**Rules:**
- No hardcoded secrets. No plaintext `.env` files with API keys.
- API keys go in the PQC bundle, loaded via `secrets-load`.
- Memory: clear sensitive values after use. Don't log them.

---

## EXECUTION

- Validate paths and input types. Parameterize SQL. `shell=False` in Python.
- Run untrusted/external scripts in sandboxed or isolated environments.
- Standard linting and analysis (ruff, bandit) on critical paths.

---

## NETWORK & PROVIDERS

- TLS 1.3 for all external API calls.
- Use zero-retention/no-training parameters on LLM API calls when available.
- Strip local paths from outbound LLM context when practical.

---

## REFERENCE

### PQC Secrets (for API keys and private data)

| Algorithm | Standard | Usage |
|---|---|---|
| ML-KEM-768 | FIPS 203 | Key encapsulation (wraps AES-256-GCM data key) |
| AES-256-GCM | SP 800-38D | Symmetric encryption of secrets payload |
| SHA3-256/512 | FIPS 202 | KDF and integrity |

**CLI:** `pqc-secrets keygen` | `pqc-secrets pack` | `pqc-secrets export` | `pqc-secrets rewrap`

### Standard Crypto (for everything else)

Normal, widely-audited cryptography for non-secrets operations: TLS, SSH, GPG, SSL certificates, etc. Use standard libraries (`cryptography`, `openssl`, platform TLS). Don't reinvent crypto for things that aren't API keys or private user data.
