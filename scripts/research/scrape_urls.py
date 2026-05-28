import urllib.request
import urllib.error
import json
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

urls = [
    "https://github.com/0xdeadbeefnetwork/Copy_Fail2-Electric_Boogaloo",
    "https://windowsnews.ai/article/cve-2026-7957-patch-chromium-media-oob-write-in-chrome-edge-may-2026.417033",
    "https://www.cve.org/CVERecord?id=CVE-2026-45321",
    "https://blog.cloudlinux.com/fragnesia-mitigation-and-kernel-update",
    "https://almalinux.org/blog/2026-05-07-dirty-frag/",
    "https://xint.io/blog/copy-fail-linux-distributions"
]

req_headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
}

for url in urls:
    print(f"\n--- Scraping {url} ---")
    try:
        req = urllib.request.Request(url, headers=req_headers)
        with urllib.request.urlopen(req, context=ctx, timeout=10) as response:
            html = response.read().decode('utf-8', errors='ignore')
            # very naive extraction just to see content
            import re
            text = re.sub(r'<style.*?>.*?</style>', '', html, flags=re.DOTALL)
            text = re.sub(r'<script.*?>.*?</script>', '', text, flags=re.DOTALL)
            text = re.sub(r'<[^>]+>', ' ', text)
            text = re.sub(r'\s+', ' ', text).strip()
            print(text[:1500]) # First 1500 chars to avoid flooding
    except Exception as e:
        print(f"Error fetching {url}: {e}")
