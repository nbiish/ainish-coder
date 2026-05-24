# Code Security — Production-Grade Engineering Standards

> Deploy with: `ainish-coder --secure <target-dir>`  
> Deeper dive: `.agents/skills/code-security/SKILL.md`  
> Governance: `.agents/skills/production-security/SKILL.md`

---

## Determinism & Containment

The code that runs the agent must be absolutely reliable. It is the cage that contains the AI.

- **No reflection, metaprogramming, or dynamic dispatch in critical paths.**
- **Pure functions** for core logic. I/O at edges only.
- **Time and randomness injected as dependencies**, never accessed directly.
- **Cyclomatic complexity ≤ 10 per function.**

---

## Input Validation (Non-Negotiable)

Every input is hostile until proven otherwise.

### Path Traversal (CWE-22)

```
Blocked: open(user_path)                          — no containment check
Blocked: os.path.join(base, user_path)             — join alone does not prevent traversal
Use:     safe_path(user_path, allowed_root)         — resolves + checks is_relative_to
```

```python
from pathlib import Path

def safe_path(filename: str, root: Path = Path("/workspace").resolve()) -> Path:
    target = (root / filename).resolve()
    if not target.is_relative_to(root):
        raise ValueError(f"Path traversal blocked: {filename}")
    return target
```

### SQL Injection (CWE-89)

```
Blocked: f"SELECT * FROM t WHERE id = {user_input}"     — string interpolation
Blocked: cursor.execute("SELECT * FROM t WHERE id = %s" % user_input)
Use:     session.execute(text("... WHERE id = :id"), {"id": user_input})
```

### Command Injection (CWE-78)

```
Blocked: subprocess.run(f"cat {filename}", shell=True)   — shell=True + user data
Blocked: os.system(user_input)                           — always unsafe
Use:     subprocess.run(["cat", filename], shell=False, check=True)
```

### Cross-Site Scripting (CWE-79)

```
Blocked: innerHTML = user_content                        — raw HTML injection
Blocked: document.write(user_content)
Use:     textContent = user_content                      — browser handles escaping
Use:     DOMPurify.sanitize(user_content)                — allow safe HTML subset
```

### SSRF (CWE-918) & URL Validation

```
Blocked: requests.get(user_url)                          — no validation
Use:     validate_url() → allowlist check → then fetch
```

```python
from urllib.parse import urlparse
from ipaddress import ip_address

BLOCKED_PREFIXES = ("127.", "10.", "192.168.", "172.16.", "0.", "169.254.")
ALLOWED_SCHEMES = ("https",)

def validate_url(url: str) -> bool:
    parsed = urlparse(url)
    if parsed.scheme not in ALLOWED_SCHEMES:
        return False
    host = parsed.hostname
    if host is None:
        return False
    if host in ("localhost", "0.0.0.0", "[::1]"):
        return False
    try:
        ip = ip_address(host)
        if ip.is_private or ip.is_loopback or ip.is_link_local:
            return False
    except ValueError:
        pass
    return True
```

---

## Secrets Management

```
Blocked: API_KEY = "sk-abc123..."                     — hardcoded in source
Blocked: config.json with apiKey: "..."                — plaintext in repo
Use:     os.getenv("API_KEY")                          — vault / env injection
Use:     external secrets manager (Vault, AWS SM, Doppler)
```

- Secrets loaded at runtime only. Never in config files, never in git.
- `.env` files must be in `.gitignore`. Use `.env.example` for templates.
- Rotate keys on compromise. Minimum: 90-day rotation policy.
- Use least-privilege API keys scoped to specific functions.

---

## Cryptography

### Never Use (Classical — Banned for New Systems)

RSA, DSA, ECDSA, ECDH, Ed25519 standalone, MD5, SHA-1, DES, 3DES, Blowfish, AES-CBC

### Always Use (Post-Quantum)

| When You Need | Use | Standard |
|---------------|-----|----------|
| Key exchange | ML-KEM-768 | FIPS 203 |
| Signing | ML-DSA-65 | FIPS 204 |
| Symmetric | AES-256-GCM / ChaCha20-Poly1305 | — |
| Password hashing | Argon2id (t=3, m=65536, p=4, len=32) | — |
| Migration (TLS) | X25519 + ML-KEM-768 | RFC 9794 |

---

## Dependencies & Supply Chain

- Pin dependencies by hash (not version range).
- Generate SBOMs (CycloneDX or SPDX).
- Audit: `pip-audit`, `npm audit`, `cargo audit` on every build.
- Sign artifacts (Sigstore / cosign).
- Verify SLSA provenance before deployment.

---

## Container & Runtime Security

- Run as non-root user (`USER 1000:1000`).
- Read-only root filesystem when possible (`--read-only`).
- No new privileges (`--security-opt=no-new-privileges`).
- Drop all capabilities, add back only what's needed.
- Resource limits (CPU, memory) on every container.
- Scan images before deploy (`trivy`, `grype`, `snyk`).

---

## Logging & Observability

- Structured logging (JSON). Include: timestamp, level, correlation_id, action, result.
- Never log secrets, PII, or full request bodies.
- Redact credentials before log emission (see AGENTS.md `redact_stream`).
- Audit trail must be append-only and immutable.

---

## Pre-Commit Gates

```bash
detect-secrets scan --all-files
gitleaks detect --source . --uncommitted
```

Mark exceptions with `# nosec` or `# no-gate` plus a justification comment.

---

*Derived from `.agents/skills/code-security/SKILL.md` and `.agents/skills/production-security/SKILL.md`. These docs are versioned and improve with every iteration. Load the skills for full context, procedural checklists, and language-specific implementations.*
