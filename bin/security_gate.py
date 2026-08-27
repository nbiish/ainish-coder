#!/usr/bin/env python3
"""
Zero-Trust & PQC Security Gate Verifier.
Run this script to analyze your code and configuration for compliance with the 
post-quantum cryptography (PQC) and containment mandates.
"""

import os
import re
import sys

# Banned patterns that indicate classical cryptographic defaults or missing validations.
# Source of truth for allowed/forbidden sets: .agents/skills/pqc-secrets/SKILL.md §3
# (verified 2026-08-08). A `# nosec` or `# no-gate` inline comment on the flagged
# line suppresses a finding — that is the audit/migration escape hatch.
BANNED_PATTERNS = {
    # -- Classical asymmetric signatures in JWT / token configs -------------
    "RSA Signatures": (r"(?i)algorithms\s*=\s*\[\s*['\"]RS(?:256|384|512)['\"]\s*\]",
        "RS* JWT algs are deprecated (NIST IR 8547: risk-acceptance after 2030, disallowed after 2035). Use ML-DSA-65 (FIPS 204) or an approved hybrid."),
    "RSA-PSS Signatures": (r"(?i)algorithms\s*=\s*\[\s*['\"]PS(?:256|384|512)['\"]\s*\]",
        "PS* (RSA-PSS) JWT algs are deprecated. Use ML-DSA-65 (FIPS 204) or an approved hybrid."),
    "ECDSA Signatures": (r"(?i)algorithms\s*=\s*\[\s*['\"]ES(?:256|384|512)['\"]\s*\]",
        "ES* (ECDSA) JWT algs are deprecated. Use ML-DSA-65 (FIPS 204) or an approved hybrid; ES256 (P-256, 112-bit) enters risk-acceptance-only after 2030."),
    "EdDSA Signatures": (r"(?i)algorithms\s*=\s*\[\s*['\"]EdDSA['\"]\s*\]",
        "EdDSA (Ed25519) is quantum-vulnerable; NIST IR 8547 disallows after 2035. Use ML-DSA-65 (FIPS 204)."),

    # -- Classical signing / hash primitives in code ------------------------
    "Ed25519 Keypair Generation": (r"(?i)(ed25519|Ed25519)(?:PrivateKey|SigningKey|Keypair)?\.?(?:generate|new|from_seed)\s*\(",
        "Ed25519 key generation detected in a signing path. Secrets/signing ops require ML-DSA-65. Transport-only uses (SSH/TLS) are fine — mark with '# nosec' if so."),
    "MD5 Usage": (r"(?i)(hashlib\.md5|md5\.new|createHash\(\s*['\"]md5)",
        "MD5 is collision-broken and forbidden everywhere. Use SHA3-256."),
    "SHA-1 Signing": (r"(?i)(hashlib\.sha1|createHash\(\s*['\"]sha1|sha1WithRSA|withRSAEncryption.*sha1)",
        "SHA-1 is collision-broken and forbidden everywhere (allowed only for parsing legacy artifacts — mark '# nosec'). Use SHA3-256/512."),
    "AES-CBC Mode": (r"(?i)(AES\.new\([^)]*AES\.MODE_CBC|AES/CBC/PKCS5[Pp]adding|Cipher\.getInstance\(\s*['\"]AES/CBC)",
        "AES-CBC is unauthenticated and forbidden for at-rest encryption. Use AES-256-GCM (SP 800-38D)."),
    "AES-ECB Mode": (r"(?i)(AES\.MODE_ECB|AES/ECB/)",
        "AES-ECB leaks plaintext structure and is forbidden. Use AES-256-GCM."),
    "RSA Key Generation": (r"(?i)(RSA\.generate|generate_private_key\(\s*public_exponent\s*=|te?lsa.*genrsa|rsa\.generate_private_key)",
        "RSA keygen in a signing/secrets path is forbidden (transport-only x509 excepted — mark '# nosec'). Use ML-DSA-65 for signing; ML-KEM-768 for key establishment."),
    "P-256 ECDH Key Agreement": (r"(?i)(ec\.generate_private_key\(\s*ec\.SECP256R1|ECDH\s*\(\s*ec\.SECP256R1)",
        "Classical-only P-256 key agreement is quantum-vulnerable (112-bit; deprecated after 2030, disallowed after 2035 per NIST IR 8547). Use ML-KEM-768, or an X25519+ML-KEM-768 hybrid with an SP 800-227-approved combiner."),

    # -- Structural / secrets hygiene ---------------------------------------
    "Unsanitized Path Usage": (r"(?<!safe_path\()open\s*\(\s*[^,\)]*path(?!\s*,\s*['\"][rwa]['\"])(?!\s*,\s*encoding=)",
        "File path opened without safe_path verification."),
    "Hardcoded Secret Pattern": (r"(?i)(api_key|client_secret|password)\s*=\s*['\"][a-zA-Z0-9_\-]{16,}['\"]",
        "Hardcoded credential detected. Load from secure environment/vault."),
}

# Directories to exclude from automated compliance scanning
EXCLUDED_DIRECTORIES = {
    ".git", ".venv", "__pycache__", "node_modules", "pliny-research",
    ".signals-creepersweeper", "scrolls-lab", ".scrolls-ceremony", ".agents", ".signals", "docs"
}
SCANNED_SUFFIXES = (".py", ".ts", ".js", ".toml", ".yml", ".yaml", ".json")
EXCLUDED_FILES = {"security_gate.py", "scan_secrets.sh", "security_scan.sh", "sanitize.py", "sanitize-settings.sh"}

def verify_compliance(directory: str = "."):
    print("Checking repository for Zero-Trust and PQC compliance...")
    failed = False
    
    for root, dirs, files in os.walk(directory):
        # Prune excluded directories dynamically
        dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRECTORIES]
        if any(exc in root.split(os.sep) for exc in EXCLUDED_DIRECTORIES):
            continue
            
        for file in files:
            if file in EXCLUDED_FILES or not file.endswith(SCANNED_SUFFIXES):
                continue
                
            path = os.path.join(root, file)
            # Skip the gate script itself during checking
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read()
                    
                lines = content.splitlines()
                for name, (pattern, guidance) in BANNED_PATTERNS.items():
                    compiled_re = re.compile(pattern)
                    for line_no, line in enumerate(lines, 1):
                        if "# nosec" in line or "# no-gate" in line:
                            continue
                        if compiled_re.search(line):
                            print(f"[\033[91mFAIL\033[0m] {path}:{line_no} - {name} detected.")
                            print(f"       Guidance: {guidance}")
                            failed = True
            except Exception as e:
                print(f"Error reading {path}: {e}")
                failed = True
                
    if not failed:
        print("[\033[92mPASS\033[0m] No banned classical signatures or unverified open paths detected.")
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    verify_compliance()
