#!/usr/bin/env python3
"""
Zero-Trust & PQC Security Gate Verifier.
Run this script to analyze your code and configuration for compliance with the 
post-quantum cryptography (PQC) and containment mandates.
"""

import os
import sys
import re

# Banned patterns that indicate classical cryptographic defaults or missing validations
BANNED_PATTERNS = {
    "RSA Signatures": (r"(?i)algorithms\s*=\s*\[\s*['\"]RS256['\"]\s*\]", "Use ML-DSA-65 or hybrid equivalent."),
    "ECDSA Signatures": (r"(?i)algorithms\s*=\s*\[\s*['\"]ES256['\"]\s*\]", "Use ML-DSA-65 or hybrid equivalent."),
    "Unsanitized Path Usage": (r"(?<!safe_path\()open\s*\(\s*[^,\)]*path(?!\s*,\s*['\"][rwa]['\"])(?!\s*,\s*encoding=)", "File path opened without safe_path verification."),
    "Hardcoded Secret Pattern": (r"(?i)(api_key|client_secret|password)\s*=\s*['\"][a-zA-Z0-9_\-]{16,}['\"]", "Hardcoded credential detected. Load from secure environment/vault.")
}

# Directories to exclude from automated compliance scanning
EXCLUDED_DIRECTORIES = {
    ".git", ".venv", "__pycache__", "node_modules", "pliny-research", 
    ".signals-creepersweeper", "scrolls-lab", ".agents", ".signals", ".github"
}

def verify_compliance(directory: str = "."):
    print("Checking repository for Zero-Trust and PQC compliance...")
    failed = False
    
    for root, dirs, files in os.walk(directory):
        # Prune excluded directories dynamically
        dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRECTORIES]
        if any(exc in root.split(os.sep) for exc in EXCLUDED_DIRECTORIES):
            continue
            
        for file in files:
            if not file.endswith((".py", ".ts", ".js")):
                continue
                
            path = os.path.join(root, file)
            # Skip the gate script itself during checking
            if os.path.basename(path) == "security_gate.py":
                continue
                
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
                
    if not failed:
        print("[\033[92mPASS\033[0m] No banned classical signatures or unverified open paths detected.")
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    verify_compliance()
