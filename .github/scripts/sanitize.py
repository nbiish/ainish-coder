#!/usr/bin/env python3
import json
import os
import re
import sys
from typing import Any, Dict, List, Union

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
            
    # Sanitize specific patterns in values
    # Brave API Key pattern
    if re.search(r"BSA[a-zA-Z0-9]{27}", value):
        return "YOUR_BRAVE_API_KEY_HERE"
    
    # Tavily API Key pattern
    if re.search(r"tvly-[a-zA-Z0-9-]{30,}", value):
        return "YOUR_TAVILY_API_KEY_HERE"

    return value

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
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        original_content = content
        changed = False
        
        # Pattern-based replacements (works for any file type)
        patterns = [
            (r'tvly-[a-zA-Z0-9-]{30,}', 'YOUR_TAVILY_API_KEY_HERE'),
            (r'tavilyApiKey=[^&"\s]{10,}', 'tavilyApiKey=YOUR_TAVILY_API_KEY_HERE'),
            (r'BSA[a-zA-Z0-9]{27}', 'YOUR_BRAVE_API_KEY_HERE'),
            (r'/Volumes/1tb-sandisk/[^\s"\'`]*', '/path/to/your/mcp/servers'),
        ]
        
        for pattern, replacement in patterns:
            # Skip if already contains placeholder
            if 'YOUR_' in content and 'HERE' in content:
                continue
            new_content = re.sub(pattern, replacement, content)
            if new_content != content:
                content = new_content
                changed = True
        
        if not changed:
            return False
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        return True
    except Exception as e:
        # If text processing fails, try JSON as fallback
        if file_path.endswith('.json') or file_path.endswith('.jsonc'):
            return process_json_file(file_path)
        return False

def process_file(file_path: str) -> bool:
    """Process a single file based on extension."""
    if file_path.endswith('.json') or file_path.endswith('.jsonc'):
        # Try JSON first, fallback to text processing
        try:
            return process_json_file(file_path)
        except:
            return process_text_file(file_path)
    elif file_path.endswith('.env') or file_path.endswith('.env.local') or file_path.endswith('.env.development') or file_path.endswith('.env.production'):
        return process_env_file(file_path)
    else:
        # For all other file types, use pattern-based text processing
        return process_text_file(file_path)

def process_json_file(file_path: str) -> bool:
    """Process a single JSON file."""
    try:
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
    except Exception as e:
        print(f"Error processing {file_path}: {e}", file=sys.stderr)
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: sanitize.py <file1> [file2 ...]")
        sys.exit(1)

    files = sys.argv[1:]
    changed_files = []

    for file_path in files:
        try:
            if process_file(file_path):
                changed_files.append(file_path)
                # Don't print to stdout (silent mode for hooks)
                # print(f"Sanitized: {file_path}", file=sys.stderr)
        except Exception as e:
            # Silently skip files that can't be processed
            pass

    # Silent mode - don't print unless explicitly needed
    # if changed_files:
    #     print(f"Modified {len(changed_files)} files.")
    # else:
    #     print("No files needed sanitization.")

if __name__ == "__main__":
    main()
