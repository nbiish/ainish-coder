#!/usr/bin/env python3
"""
ainish-coder Secret Sanitizer
Automatically detects and replaces secrets/credentials in files.
Compliant with OWASP Agentic Security ASI04 (Information Disclosure).
"""
import argparse
import json
import os
import re
import sys
from typing import Any, Dict, List, Tuple, Union

def sanitize_value(key: str, value: Any) -> Any:
    """Sanitize a single value based on key name or value pattern."""
    if not isinstance(value, str):
        return value

    # Sanitize API keys based on key name
    if "API_KEY" in key.upper() or "TOKEN" in key.upper() or "SECRET" in key.upper():
        return f"YOUR_{key.upper()}_HERE"
    
    # Sanitize specific keys from original script
    if key == "tavilyApiKey":
        return "YOUR_TAVILY_API_KEY_HERE"

    # Sanitize local paths
    if key in ["cwd", "MEMORY_FILE_PATH"] and (value.startswith("/Volumes/") or value.startswith("/Users/")):
        if key == "cwd":
            return "/path/to/your/mcp/servers"
        if key == "MEMORY_FILE_PATH":
            return "/path/to/your/memory/memories.jsonl"
            
    value = sanitize_text(value)

    return value


def sanitize_text(text: str) -> str:
    if not text:
        return text

    patterns: List[Tuple[str, str, int]] = [
        # OWASP ASI04: Information Disclosure (Secrets)
        # --- AI/LLM Providers ---
        (r"tvly-[a-zA-Z0-9-]{30,}", "YOUR_TAVILY_API_KEY_HERE", 0),
        (r"tavilyApiKey=[^&\"\s]{10,}", "tavilyApiKey=YOUR_TAVILY_API_KEY_HERE", 0),
        (r"\bsk-ant-[a-zA-Z0-9_-]{20,}\b", "YOUR_ANTHROPIC_API_KEY_HERE", 0),
        (r"\bsk-[a-zA-Z0-9]{20,}\b", "YOUR_OPENAI_API_KEY_HERE", 0),
        (r"\bAIza[0-9A-Za-z-_]{35}\b", "YOUR_GOOGLE_API_KEY_HERE", 0),
        (r"\bhf_[a-zA-Z0-9]{34}\b", "YOUR_HUGGINGFACE_TOKEN_HERE", 0),
        (r"\bpplx-[a-zA-Z0-9]{48}\b", "YOUR_PERPLEXITY_API_KEY_HERE", 0),
        (r"\bco-[a-zA-Z0-9]{40}\b", "YOUR_COHERE_API_KEY_HERE", 0),
        # --- NEW: Additional AI Providers (2026) ---
        (r"\bsk-or-[a-zA-Z0-9-]{48,}\b", "YOUR_OPENROUTER_API_KEY_HERE", 0),
        (r"\bgsk_[a-zA-Z0-9]{52}\b", "YOUR_GROQ_API_KEY_HERE", 0),
        (r"\br8_[a-zA-Z0-9]{40}\b", "YOUR_REPLICATE_TOKEN_HERE", 0),
        (r"\bsk-[a-f0-9]{54}\b", "YOUR_DEEPSEEK_API_KEY_HERE", 0),
        (r"\bgoog-[a-zA-Z0-9-]{32,}\b", "YOUR_GEMINI_API_KEY_HERE", 0),
        (r"\bxai-[a-zA-Z0-9]{48,}\b", "YOUR_XAI_API_KEY_HERE", 0),
        # --- Search/Data Providers ---
        (r"BSA[a-zA-Z0-9]{27}", "YOUR_BRAVE_API_KEY_HERE", 0),
        (r"\bSG\.[a-zA-Z0-9_-]{22}\.[a-zA-Z0-9_-]{43}\b", "YOUR_SENDGRID_API_KEY_HERE", 0),
        # --- Version Control ---
        (r"\bghp_[A-Za-z0-9]{36}\b", "YOUR_GITHUB_TOKEN_HERE", 0),
        (r"\bgho_[A-Za-z0-9]{36}\b", "YOUR_GITHUB_TOKEN_HERE", 0),
        (r"\bghu_[A-Za-z0-9]{36}\b", "YOUR_GITHUB_TOKEN_HERE", 0),
        (r"\bghs_[A-Za-z0-9]{36}\b", "YOUR_GITHUB_TOKEN_HERE", 0),
        (r"\bghr_[A-Za-z0-9]{36}\b", "YOUR_GITHUB_TOKEN_HERE", 0),
        (r"\bgithub_pat_[A-Za-z0-9_]{50,}\b", "YOUR_GITHUB_TOKEN_HERE", 0),
        (r"\bglpat-[0-9a-zA-Z-]{20}\b", "YOUR_GITLAB_TOKEN_HERE", 0),
        # --- Cloud Providers ---
        (r"\bAKIA[0-9A-Z]{16}\b", "YOUR_AWS_ACCESS_KEY_ID_HERE", 0),
        (r"\b[A-Za-z0-9+/]{40}\b(?=.*aws)", "YOUR_AWS_SECRET_KEY_HERE", re.IGNORECASE),
        (r"\b[a-zA-Z0-9+/]{86}==\b", "YOUR_AZURE_STORAGE_KEY_HERE", 0),
        # --- NEW: Cloud Platforms (2026) ---
        (r"\bCF_API_KEY.*[a-f0-9]{37}\b", "YOUR_CLOUDFLARE_API_KEY_HERE", 0),
        (r"\brailway_[a-zA-Z0-9]{24,}\b", "YOUR_RAILWAY_TOKEN_HERE", 0),
        (r"\brnd_[a-zA-Z0-9]{40,}\b", "YOUR_RENDER_TOKEN_HERE", 0),
        (r"\bsbp_[a-zA-Z0-9]{40,}\b", "YOUR_SUPABASE_KEY_HERE", 0),
        (r"\bfly_[a-zA-Z0-9]{43}\b", "YOUR_FLY_TOKEN_HERE", 0),
        (r"\bdopt_[a-zA-Z0-9]{30,}\b", "YOUR_DENO_DEPLOY_TOKEN_HERE", 0),
        # --- Payment/SaaS ---
        (r"\bsk_live_[0-9a-zA-Z]{24}\b", "YOUR_STRIPE_SECRET_KEY_HERE", 0),
        (r"\bsk_test_[0-9a-zA-Z]{24}\b", "YOUR_STRIPE_TEST_KEY_HERE", 0),
        (r"\brk_live_[0-9a-zA-Z]{24}\b", "YOUR_STRIPE_RESTRICTED_KEY_HERE", 0),
        (r"\bSK[a-f0-9]{32}\b", "YOUR_TWILIO_API_KEY_HERE", 0),
        (r"\bkey-[0-9a-zA-Z]{32}\b", "YOUR_MAILGUN_API_KEY_HERE", 0),
        # --- Communication ---
        (r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b", "YOUR_SLACK_TOKEN_HERE", 0),
        (r"[MN][A-Za-z\d]{23,}\.[\w-]{6}\.[\w-]{27}", "YOUR_DISCORD_TOKEN_HERE", 0),
        # --- Dev Tools/Platforms ---
        (r"\blin_api_[a-zA-Z0-9]{40}\b", "YOUR_LINEAR_API_KEY_HERE", 0),
        (r"\bsecret_[a-zA-Z0-9]{43}\b", "YOUR_NOTION_API_KEY_HERE", 0),
        (r"\bnpx_[a-zA-Z0-9]{36}\b", "YOUR_NPM_TOKEN_HERE", 0),
        (r"\bpypi-[a-zA-Z0-9_-]{50,}\b", "YOUR_PYPI_TOKEN_HERE", 0),
        (r"\bvercel_[a-zA-Z0-9]{24}\b", "YOUR_VERCEL_TOKEN_HERE", 0),
        (r"\bnlfy_[a-zA-Z0-9_-]{40,}\b", "YOUR_NETLIFY_TOKEN_HERE", 0),
        # --- Auth/JWT ---
        (r"eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*", "YOUR_JWT_TOKEN_HERE", 0),
        # --- Database Connection Strings ---
        (r"(postgres|postgresql)://[^@\s]+@[^\s]+", "YOUR_POSTGRES_URL_HERE", 0),
        (r"mysql://[^@\s]+@[^\s]+", "YOUR_MYSQL_URL_HERE", 0),
        (r"mongodb(\+srv)?://[^@\s]+@[^\s]+", "YOUR_MONGODB_URL_HERE", 0),
        (r"redis://[^@\s]+@[^\s]+", "YOUR_REDIS_URL_HERE", 0),
        # --- Private Keys ---
        (r"(?s)-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----", "YOUR_PRIVATE_KEY_HERE", re.DOTALL),
        (r"(?s)-----BEGIN RSA PRIVATE KEY-----.*?-----END RSA PRIVATE KEY-----", "YOUR_RSA_PRIVATE_KEY_HERE", re.DOTALL),
        (r"(?s)-----BEGIN EC PRIVATE KEY-----.*?-----END EC PRIVATE KEY-----", "YOUR_EC_PRIVATE_KEY_HERE", re.DOTALL),
        (r"(?s)-----BEGIN OPENSSH PRIVATE KEY-----.*?-----END OPENSSH PRIVATE KEY-----", "YOUR_SSH_PRIVATE_KEY_HERE", re.DOTALL),
        # --- Local paths (ASI04) ---
        (r"/Volumes/[A-Za-z0-9._-]+/[^\s\"'`]*", "/path/to/your/volume", 0),
        (r"/Users/[A-Za-z0-9._-]+/[^\s\"'`]*", "/path/to/your/home", 0),
        (r"C:\\Users\\[A-Za-z0-9._-]+\\[^\s\"'`]*", "C:\\path\\to\\your\\home", 0),
        (r"/home/[A-Za-z0-9._-]+/[^\s\"'`]*", "/path/to/your/home", 0),
    ]

    out = text
    for pattern, replacement, flags in patterns:
        out = re.sub(pattern, replacement, out, flags=flags)
    return out


def is_binary_file(file_path: str) -> bool:
    try:
        with open(file_path, "rb") as f:
            chunk = f.read(8192)
        return b"\x00" in chunk
    except Exception:
        return True

def sanitize_structure(data: Any, key_context: str = "") -> Any:
    """Recursively sanitize a JSON structure."""
    if isinstance(data, dict):
        return {k: sanitize_structure(v, k) for k, v in data.items()}
    elif isinstance(data, list):
        return [sanitize_structure(item, key_context) for item in data]
    else:
        return sanitize_value(key_context, data)

def process_env_file(file_path: str) -> bool:
    """Process a single .env file."""
    try:
        if is_binary_file(file_path):
            return False

        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        new_lines = []
        changed = False
        
        for line in lines:
            line = line.strip()
            if not line or line.startswith('#'):
                new_lines.append(line)
                continue
                
            if '=' in line:
                key, value = line.split('=', 1)
                sanitized_value = sanitize_value(key, value)
                if sanitized_value != value:
                    new_lines.append(f"{key}={sanitized_value}")
                    changed = True
                else:
                    new_lines.append(line)
            else:
                new_lines.append(line)
                
        if not changed:
            return False
            
        with open(file_path, 'w') as f:
            f.write('\n'.join(new_lines))
            f.write('\n')
            
        return True
    except Exception as e:
        print(f"Error processing {file_path}: {e}", file=sys.stderr)
        return False

def process_text_file(file_path: str) -> bool:
    """Process any text file using pattern-based replacement."""
    try:
        if is_binary_file(file_path):
            return False

        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        sanitized = sanitize_text(content)

        if sanitized == content:
            return False
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(sanitized)
        
        return True
    except Exception as e:
        # If text processing fails, try JSON as fallback
        if file_path.endswith('.json') or file_path.endswith('.jsonc'):
            return process_json_file(file_path)
        return False

def process_file(file_path: str) -> bool:
    """Process a single file based on extension."""
    if file_path.endswith('.json') or file_path.endswith('.jsonc'):
        # Try JSON first
        result = process_json_file(file_path)
        if result:
            return True
        # If JSON processing didn't change anything (or failed), fallback to text
        return process_text_file(file_path)
    elif file_path.endswith('.env') or file_path.endswith('.env.local') or file_path.endswith('.env.development') or file_path.endswith('.env.production'):
        return process_env_file(file_path)
    else:
        # For all other file types, use pattern-based text processing
        return process_text_file(file_path)

def process_json_file(file_path: str) -> bool:
    """Process a single JSON file."""
    try:
        if is_binary_file(file_path):
            return False

        with open(file_path, 'r') as f:
            data = json.load(f)
        
        sanitized_data = sanitize_structure(data)
        
        # Check if changed
        if data == sanitized_data:
            return False
            
        with open(file_path, 'w') as f:
            json.dump(sanitized_data, f, indent=2)
            # Add newline at end of file
            f.write('\n')
            
        return True
    except Exception:
        # Return False to trigger fallback or indicate no change
        return False

def preview_changes(file_path: str) -> List[Tuple[str, str, str]]:
    """Preview what changes would be made without modifying the file.
    Returns list of (original_snippet, replacement, pattern_name) tuples.
    """
    changes = []
    try:
        if is_binary_file(file_path):
            return changes

        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()

        # Check each pattern for matches
        patterns: List[Tuple[str, str, int]] = [
            # AI/LLM Providers
            (r"\bsk-ant-[a-zA-Z0-9_-]{20,}\b", "ANTHROPIC_API_KEY", 0),
            (r"\bsk-[a-zA-Z0-9]{20,}\b", "OPENAI_API_KEY", 0),
            (r"\bsk-or-[a-zA-Z0-9-]{48,}\b", "OPENROUTER_API_KEY", 0),
            (r"\bgsk_[a-zA-Z0-9]{52}\b", "GROQ_API_KEY", 0),
            (r"\bhf_[a-zA-Z0-9]{34}\b", "HUGGINGFACE_TOKEN", 0),
            (r"tvly-[a-zA-Z0-9-]{30,}", "TAVILY_API_KEY", 0),
            (r"\bpplx-[a-zA-Z0-9]{48}\b", "PERPLEXITY_API_KEY", 0),
            # Cloud/DevOps
            (r"\bghp_[A-Za-z0-9]{36}\b", "GITHUB_TOKEN", 0),
            (r"\bAKIA[0-9A-Z]{16}\b", "AWS_ACCESS_KEY", 0),
            (r"BSA[a-zA-Z0-9]{27}", "BRAVE_API_KEY", 0),
            # Private Keys
            (r"-----BEGIN [A-Z ]*PRIVATE KEY-----", "PRIVATE_KEY", 0),
            # Local paths
            (r"/Users/[A-Za-z0-9._-]+/", "LOCAL_PATH", 0),
            (r"/Volumes/[A-Za-z0-9._-]+/", "VOLUME_PATH", 0),
        ]

        for pattern, name, flags in patterns:
            matches = re.findall(pattern, content, flags=flags)
            for match in matches:
                # Truncate long matches for display
                display = match if len(match) < 50 else match[:47] + "..."
                changes.append((display, f"YOUR_{name}_HERE", name))

        return changes
    except Exception:
        return changes


def main():
    parser = argparse.ArgumentParser(
        description='Sanitize secrets and sensitive data from files.',
        epilog='Examples:\n'
               '  sanitize.py config.json              # Sanitize file\n'
               '  sanitize.py --dry-run *.py           # Preview changes\n'
               '  sanitize.py -v src/ tests/           # Verbose output',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('files', nargs='+', help='Files to sanitize')
    parser.add_argument('--dry-run', '-n', action='store_true',
                        help='Preview changes without modifying files')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='Show detailed output')
    args = parser.parse_args()

    changed_files = []
    total_changes = 0

    for file_path in args.files:
        if not os.path.isfile(file_path):
            if args.verbose:
                print(f"Skipping (not a file): {file_path}", file=sys.stderr)
            continue

        try:
            if args.dry_run:
                changes = preview_changes(file_path)
                if changes:
                    print(f"\n📋 {file_path}:")
                    for original, replacement, pattern_type in changes:
                        print(f"   ├─ {pattern_type}: '{original}' → '{replacement}'")
                    total_changes += len(changes)
            else:
                if process_file(file_path):
                    changed_files.append(file_path)
                    if args.verbose:
                        print(f"✓ Sanitized: {file_path}", file=sys.stderr)
        except Exception as e:
            if args.verbose:
                print(f"Error processing {file_path}: {e}", file=sys.stderr)

    if args.dry_run:
        if total_changes > 0:
            print(f"\n🔍 Found {total_changes} potential secret(s) in {len(args.files)} file(s)")
            print("   Run without --dry-run to sanitize.")
        else:
            print("✅ No secrets detected.")
    elif args.verbose:
        if changed_files:
            print(f"Modified {len(changed_files)} file(s).", file=sys.stderr)
        else:
            print("No files needed sanitization.", file=sys.stderr)


if __name__ == "__main__":
    main()

