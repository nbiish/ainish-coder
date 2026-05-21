# Test: verify hello.py says hi (not hello)
import subprocess
import sys

result = subprocess.run([sys.executable, "hello.py"], capture_output=True, text=True)
output = result.stdout.strip()

assert output == "hi", f"FAIL: expected 'hi', got '{output}'"
print("PASS: says hi correctly")
