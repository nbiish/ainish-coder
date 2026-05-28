import subprocess
import json

urls = [
    "https://xint.io/blog/copy-fail-linux-distributions",
    "https://almalinux.org/blog/2026-05-07-dirty-frag/",
    "https://blog.cloudlinux.com/fragnesia-mitigation-and-kernel-update",
    "https://tanstack.com/blog/npm-supply-chain-compromise-postmortem"
]

import urllib.request
import time

for url in urls:
    try:
        req = urllib.request.Request("https://r.jina.ai/" + url)
        req.add_header('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
        req.add_header('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8')
        with urllib.request.urlopen(req) as response:
            content = response.read().decode('utf-8')
            
        filename = "scrolls-lab/omni_output/" + url.split("/")[-1].replace(".","-").replace("/","") + "_analysis.md"
        if url.endswith("/"):
             filename = "scrolls-lab/omni_output/" + url.split("/")[-2].replace(".","-").replace("/","") + "_analysis.md"
             
        with open(filename, "w") as f:
            f.write("# " + url + "\n\n")
            f.write(content)
        print(f"Scraped {url} to {filename}")
    except Exception as e:
        print(f"Failed to scrape {url}: {e}")
    time.sleep(2)
