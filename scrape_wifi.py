import urllib.request
import re
import ssl
import json

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

repos = [
    "https://github.com/davidakpele/wifi-densepose",
    "https://github.com/yangsuzhou/wifi-densepose",
    "https://github.com/superstar1225/DensePose_from_WiFi",
    "https://github.com/ruvnet/RuView",
]

headers = {"User-Agent": "Mozilla/5.0"}

for repo_url in repos:
    print(f"\n{'='*80}")
    print(f"REPO: {repo_url}")
    print('='*80)
    
    # Try raw README
    parts = repo_url.rstrip('/').split('/')
    owner = parts[-2]
    repo = parts[-1]
    
    for branch in ['main', 'master']:
        raw_url = f"https://raw.githubusercontent.com/{owner}/{repo}/{branch}/README.md"
        try:
            req = urllib.request.Request(raw_url, headers=headers)
            with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
                content = resp.read().decode('utf-8', errors='ignore')
                print(f"README ({branch}):\n")
                print(content[:6000])
                if len(content) > 6000:
                    print(f"\n... [TRUNCATED - total {len(content)} chars]")
                break
        except Exception:
            continue
    else:
        print("Could not fetch raw README, trying API...")
        api_url = f"https://api.github.com/repos/{owner}/{repo}/readme"
        try:
            req = urllib.request.Request(api_url, headers=headers)
            with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
                data = json.loads(resp.read())
                import base64
                content = base64.b64decode(data['content']).decode('utf-8', errors='ignore')
                print(f"README (API):\n")
                print(content[:6000])
        except Exception as e:
            print(f"API fallback failed: {e}")

print("\n\nDONE")
