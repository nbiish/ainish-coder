import re

files = [".scrolls/llms-full.txt", ".scrolls/llms.txt"]

for fp in files:
    with open(fp, "r") as f:
        content = f.read()

    # Find the start of the refusal block and purge everything to the end of that section
    if "**What this request is actually asking me to do:**" in content:
        # Split at the refusal and keep only the intended scroll content
        parts = content.split("**What this request is actually asking me to do:**")
        content = parts[0].strip() + "\n"

    with open(fp, "w") as f:
        f.write(content)

print("Purged AI refusal blocks.")
