# Task: PQC store host-interop and the distribution gate across Windows, WSL, Linux, macOS

- lane: now
- branch: `main` (small, targeted fix set)
- status: done
- scope: `.agents/skills/pqc-secrets/scripts/pqc_secrets.py`, `scripts/test-pqc-dist.sh`
- related: `.agents/tasks/2026-11-06-rag-phase0-baseline-task.md`

## Why

The fleet spans Windows PowerShell, WSL, Linux, and macOS. Two things were believed broken and one
worse thing was found while checking.

## What was actually wrong

### 1. Windows could not see the PQC store at all (real defect, fixed)

`_windows_wsl_store()` shells out to `wsl.exe -l -q` and decoded the output **unconditionally as
UTF-16-LE**. On this Windows build `wsl.exe` emits **UTF-8**, so the decode produced mojibake:

```
raw:      b'Ubuntu\r\ndocker-desktop\r\n'
decoded:  '払湵畴\u0a0d潤正牥搭獥瑫灯\u0a0d'
probe:    \\wsl.localhost\払湵畴...\home  -> WinError 67
```

Every distro name was garbage, so the `\\wsl.localhost\<distro>\home` probe could never match and
resolve_store() fell back to `~/.config` — a Windows store with a keypair but **0 packed secrets**.
Meanwhile the secrets sat in the WSL store, 13 keys deep. This is why the embedding key resolved
only under WSL and why a Windows baseline was impossible.

Fixed by `_decode_wsl_list()`, which detects the encoding from the byte shape (UTF-16-LE ASCII is
NUL-padded; UTF-8 is not) instead of assuming one, strips any BOM/NUL residue, and tries **both**
`\\wsl.localhost` and the legacy `\\wsl$` share.

Verified: Windows now reports `bundleExists: true`, `keyCount: 13`, and
`resolve_embed_provider -> key_source: pqc:LOCALROUTER_OPENROUTER_API_KEY`.

### 2. The gate was not hermetic on Windows (real defect, fixed)

`run_cli` isolated with `HOME="$HOME_DIR"` only. Python on Windows reads `USERPROFILE`, and
`pathlib.Path.home()` ignores `HOME` entirely:

```
HOME=C:\...\Temp\fakehome-x   ->   Path.home() = C:\Users\kenwa
```

So the "hermetic" test reached the operator's **real** keypair, `keygen` refused to overwrite, and
the assertion reported `present` where a clean install must report `generated`. Both a false failure
and a genuine safety hole: a test could touch live key material.

Fixed by pinning the engine's own documented override `PQC_SECRETS_DIR` (authoritative on every
host) plus `USERPROFILE`, so the sandbox is real regardless of platform.

### 3. The stamp assertion hardcoded WSL (test defect, fixed)

The fixture built the opposite-host stamp as `printf '/d%s' "${REPO#/mnt/d}"`. Under Git Bash the
strip is a no-op, so the fixture became `/d/d/Code/ainish-coder` and a **correct** translator was
reported as broken. It also had no native-POSIX branch, so macOS/Linux could never pass it.

Fixed by deriving the counterpart from `_ainish_stamp_alternative` itself, and treating a native
POSIX path (no counterpart exists) as N/A.

### 4. The whole gate silently no-opped without `uv` (found, fixed)

```
if ! command -v uv; then echo "SKIP: uv is required..."; exit 0; fi
```

All 73 assertions were skipped and the script exited **0**, which in CI reads as PASSED. A
distribution gate's worst failure mode is reporting success without running. Now it fails closed with
install guidance, and skipping requires an explicit `AINISH_ALLOW_GATE_SKIP=1`.

## Verification

| Host | Result |
|---|---|
| Windows Git Bash | **73/73** (was 71/73) |
| WSL (Ubuntu) | **73/73** (no regression) |
| Linux (ubuntu:24.04 in Docker, real `uv`) | **73/73** |
| Linux without `uv` | exits **1** with actionable message (was 0/SKIP) |
| Native-POSIX stamp behaviour (alpine) | `/Users/dev/code/x` left untouched; both Windows forms translate correctly |
| `py -3 -m unittest discover -s src/rag/tests` | 71 pass |

macOS itself was **not** executed: no macOS host is reachable here. The OS-specific surfaces are
covered indirectly — the stamp translator is pure shell logic and was exercised on a native POSIX
container, and the PQC interop code path is `os.name == "nt"`-gated, so macOS takes the plain
`~/.config` branch that all three tested hosts already exercise.

## Note on local-router keys

The router was reporting `key_configured: true` while the Windows PQC CLI reported 0 keys, because
the router has its **own** store-discovery (`getPqcConfigDirCandidates`) which scans both
`~/config` and `~/.config` and, under WSL, also Windows user dirs. So the two tools disagreed about
"is a key configured". With fix 1 they now agree on Windows.

**No key entry is required from the operator.** The 13 keys already in the WSL store are now
discovered by both hosts; nothing needs re-packing. If a *new* provider key is ever added, it belongs
in whichever store the fleet treats as canonical — currently the WSL store, reached over interop.
