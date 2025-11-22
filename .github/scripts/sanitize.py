#!/usr/bin/env python3
import os
import re
import sys

# Define target keys to sanitize (exact match on key name)
TARGET_KEYS = {
    # AI & LLM Providers
    "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY",
    "MISTRAL_API_KEY", "COHERE_API_KEY",
    "HUGGINGFACE_TOKEN", "HUGGINGFACEHUB_API_TOKEN", "HUGGINGFACE_API_KEY", "HF_TOKEN",
    "REPLICATE_API_TOKEN", "GROQ_API_KEY", "OPENROUTER_API_KEY", "TOGETHER_API_KEY",
    "DEEPSEEK_API_KEY", "PERPLEXITY_API_KEY", "ZENMUX_API_KEY", "QWEN_API_KEY",
    "NOVITA_API_KEY", "FIREWORKS_API_KEY", "AI21_API_KEY", "ALEPHALPHA_API_KEY",
    "MINIMAX_API_KEY", "AZURE_OPENAI_API_KEY", "AZURE_API_KEY",
    "ELEVENLABS_API_KEY", "ELEVEN_API_KEY",
    "NEBIUS_API_KEY", "NEBIUS_TOKEN",
    "MODAL_API_KEY", "BLAXEL_API_KEY",
    "SAMBANOVA_API_KEY", "SAMBANOVA_TOKEN",
    "GITHUB_TOKEN", "GH_TOKEN", "GITHUB_PAT",
    
    # Cloud & Database
    "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN",
    "SUPABASE_KEY", "SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_ANON_KEY",
    "FIREBASE_API_KEY", "FIREBASE_AUTH_DOMAIN",
    "MONGODB_URI", "MONGO_INITDB_ROOT_PASSWORD", "MONGO_INITDB_ROOT_USERNAME",
    "PINECONE_API_KEY", "PINECONE_ENV", "WEAVIATE_API_KEY", "WEAVIATE_URL",
    "QDRANT_API_KEY", "QDRANT_URL", "REDIS_PASSWORD", "REDIS_URL",
    "DATABASE_URL", "POSTGRES_PASSWORD", "POSTGRES_USER", "POSTGRES_DB",
    "MYSQL_PASSWORD", "MYSQL_ROOT_PASSWORD",
    "ALGOLIA_API_KEY", "ALGOLIA_APP_ID",
    "STRIPE_SECRET_KEY", "STRIPE_PUBLISHABLE_KEY", "STRIPE_WEBHOOK_SECRET",
    "VERCEL_TOKEN", "NETLIFY_AUTH_TOKEN"
}

# Define global value patterns to scrub regardless of key name
GLOBAL_PATTERNS = [
    (r"(sk-[a-zA-Z0-9]{20,})", "YOUR_OPENAI_API_KEY_HERE"),
    (r"(AIza[0-9A-Za-z-_]{35})", "YOUR_GOOGLE_API_KEY_HERE"),
    (r"(hf_[A-Za-z0-9]{20,})", "YOUR_HUGGINGFACE_TOKEN_HERE"),
    (r"(BSA[a-zA-Z0-9]{27})", "YOUR_BRAVE_API_KEY_HERE"),
    (r"(tvly-[a-zA-Z0-9-]{30,})", "YOUR_TAVILY_API_KEY_HERE"),
]

def sanitize_content(content: str) -> str:
    """Sanitize content using regex substitution."""
    original_content = content

    # 1. Sanitize by Key Name (Assignments)
    # Matches: KEY = "VAL", KEY="VAL", KEY: "VAL", KEY: VAL, export KEY=VAL
    # Captures: 1=Pre, 2=Key, 3=Separator, 4=Quote, 5=Value, 6=Quote
    assignment_regex = re.compile(
        r'(\b(?:export\s+|const\s+|let\s+|var\s+)?)([A-Z_0-9]+(?:_API_KEY|_TOKEN|_SECRET|_PASSWORD))(\s*[:=]\s*)(["\']?)([^"\';\n]+)(["\']?)',
        re.IGNORECASE
    )

    def replace_assignment(match):
        pre, key, sep, q1, val, q2 = match.groups()
        
        # Check if key is target or generic pattern
        key_upper = key.upper()
        if key_upper in TARGET_KEYS or any(x in key_upper for x in ["API_KEY", "TOKEN", "SECRET", "PASSWORD"]):
            # Don't replace placeholders or empty strings
            if "YOUR_" in val and "_HERE" in val:
                return match.group(0)
            if not val.strip():
                return match.group(0)
                
            return f'{pre}{key}{sep}{q1}YOUR_{key_upper}_HERE{q2}'
        
        return match.group(0)

    content = assignment_regex.sub(replace_assignment, content)

    # 2. Sanitize Global Patterns (Values)
    for pattern, replacement in GLOBAL_PATTERNS:
        content = re.sub(pattern, replacement, content)

    # 3. Sanitize Local Paths
    # /Volumes/... or /Users/... -> /path/to/...
    content = re.sub(r'([\'"])/Volumes/[^"\']+([\'"])', r'\1/path/to/external/drive\2', content)
    content = re.sub(r'([\'"])/Users/[^"\']+([\'"])', r'\1/path/to/user/home\2', content)

    return content

def process_file(file_path: str) -> bool:
    """Process a single file."""
    try:
        # Skip binary files check (basic)
        if file_path.endswith(('.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf', '.zip', '.gz')):
            return False
            
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        sanitized_content = sanitize_content(content)
        
        if content == sanitized_content:
            return False
            
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(sanitized_content)
            
        return True
    except Exception as e:
        print(f"Error processing {file_path}: {e}", file=sys.stderr)
        return False

def main():
    if len(sys.argv) < 2:
        print("No files provided to sanitize.")
        sys.exit(0)

    files = sys.argv[1:]
    changed_files = []

    for file_path in files:
        if process_file(file_path):
            changed_files.append(file_path)
            print(f"Sanitized: {file_path}")

    if changed_files:
        print(f"Modified {len(changed_files)} files.")
    else:
        print("No files needed sanitization.")

if __name__ == "__main__":
    main()
