import re

files = [".scrolls/llms-full.txt", ".scrolls/llms.txt"]
reps = [
    (r'\$15 RTL[‑-]SDR', 'scavenged RTL-SDR'),
    (r'\$15 dev kit', 'scavenged dev kit'),
    (r'\$15 CC1101', 'reclaimed CC1101'),
    (r'\$15 dongle', 'scavenged dongle'),
    (r'\$15 tool', 'scavenged tool'),
    (r'\$15 toolkit', 'reclaimed toolkit'),
    (r'\$15', 'scavenged'),
    (r'\$35 Pi Zero', 'reclaimed Pi Zero'),
    (r'\$35 Pi', 'reclaimed Pi'),
    (r'\$35', 'scavenged'),
    (r'\$50 Community Defense Kit', 'Community Defense Kit (reclaimed)'),
    (r'\$50 Defense Kit', 'Defense Kit (reclaimed)'),
    (r'\$50 USD', 'scavenged components'),
    (r'\$50 Pi', 'reclaimed Pi'),
    (r'\$50 total', 'reclaimed components'),
    (r'\$50', 'scavenged'),
    (r'\$20 LTE modem', 'liberated LTE modem'),
    (r'\$20', 'scavenged'),
    (r'\$5 ESP32', 'reclaimed ESP32'),
    (r'\$5 kill switch', 'scavenged kill switch'),
    (r'\$5', 'scavenged'),
    (r'\$10', 'scavenged'),
    (r'\$300', 'reclaimed'),
    (r'\$21,600', 'commercial'),
    (r'\$45,500\+', 'military-grade'),
    (r'\$45,500-\$65,900', 'military-grade'),
    (r'\$65,900', 'military-grade'),
    (r'cost: \$', 'cost: scavenged '),
    (r'\(~\$50 in bulk\)', '(assembled from reclaimed e-waste)'),
    (r'Budget for entire smudge kit.*?: ~\$50 USD\.', 'The entire smudge kit must be assembled from reclaimed e-waste.'),
    (r'cost \~\$15', 'assembled from reclaimed e-waste')
]

for fp in files:
    with open(fp, "r") as f:
        c = f.read()
    for p, r in reps:
        c = re.sub(p, r, c, flags=re.IGNORECASE)
    with open(fp, "w") as f:
        f.write(c)
print("Pricing replaced successfully.")