import subprocess
import sys

def ping_host(host):
    # Vulnerable to command injection
    command = f"ping -c 1 {host}"
    subprocess.call(command, shell=True)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        ping_host(sys.argv[1])
