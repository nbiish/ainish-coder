import urllib.request
import re
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

urls = [
    "https://www.everythingrf.com/community/what-is-digital-radio-frequency-memory",
    "https://www.ibm.com/think/topics/field-programmable-gate-arrays",
]

headers = {"User-Agent": "Mozilla/5.0"}

for url in urls:
    print(f"\n{'='*80}")
    print(f"SCRAPING: {url}")
    print('='*80)
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, context=ctx, timeout=20) as resp:
            html = resp.read().decode("utf-8", errors="ignore")
            text = re.sub(r"<style.*?>.*?</style>", "", html, flags=re.DOTALL | re.IGNORECASE)
            text = re.sub(r"<script.*?>.*?</script>", "", text, flags=re.DOTALL | re.IGNORECASE)
            text = re.sub(r"<[^>]+>", " ", text)
            text = re.sub(r"\s+", " ", text).strip()
            # Print full content
            print(text[:8000])
            if len(text) > 8000:
                print(f"\n... [TRUNCATED - total {len(text)} chars]")
    except Exception as e:
        print(f"Error: {e}")
