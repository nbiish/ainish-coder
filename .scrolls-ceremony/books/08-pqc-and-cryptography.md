# Book 8: Post-Quantum Cryptography & Hardware Trust Architectures

> **Knowledge Domain**


---

## Abstract

This volume establishes the cryptographic mandates that secure all communications, firmware updates, and forensic evidence in the 8th Fire defense network. The harvest-now-decrypt-later threat is not abstract — adversaries are recording all classical-encrypted traffic today for quantum decryption tomorrow. The 200× reduction in quantum attack requirements in the last year means every day of classical cryptography is a day Indigenous data is being harvested. This volume specifies the permitted post-quantum algorithms, the banned classical algorithms, the Antifuse FPGA hardware root of trust architecture, and practical migration paths for community-deployed systems.

---

## 1. The Quantum Threat Timeline

### 1.1 Harvest-Now-Decrypt-Later (HNDL)

```
2026: All classical-encrypted communications RECORDED by state actors
      ├── ICE camp telemetry (TLS 1.2, ECDSA P-256)
      ├── Community mesh traffic (WPA2, AES-CCMP)
      ├── Drone C2 links (proprietary, likely ECDH)
      └── All internet traffic traversing NSA Utah Data Center

2028-2030 (est.): Cryptographically Relevant Quantum Computer (CRQC)
      ├── Shor's algorithm breaks RSA, DSA, ECDSA, ECDH, Ed25519
      ├── Grover's algorithm reduces symmetric key strength by half
      └── ALL encrypted data from 2026 → DECRYPTABLE

CONSEQUENCE: Every classical encryption key used today is a future liability.
             Every Indigenous communication intercepted today will be read.
             Every scroll transmission recorded today will be exposed.
```

### 1.2 Quantum Attack Resources

| Year | Algorithm | Qubit Requirement | Classical Equivalent |
|------|-----------|-------------------|---------------------|
| 2024 | RSA-2048 (Shor) | ~20M physical qubits | N/A |
| 2025 | RSA-2048 (Shor, refined) | ~4M physical qubits | N/A |
| 2026 Feb | ECDSA P-256 (Shor, Iceberg Pinnacle) | ~100K logical qubits | 20× reduction |
| 2026 Mar | ECDSA P-256 (Shor, Google refinement) | ~5K logical qubits | 200× reduction from 2024 |

**Assessment**: Elliptic curve cryptography (ECDSA, ECDH, Ed25519) is the most vulnerable. The 200× reduction in required resources means CRQC could arrive years sooner than NIST's 2030 projection. **Migration to PQC must happen NOW, not when NIST mandates it.**

---

## 2. Permitted Post-Quantum Algorithms

### 2.1 Key Encapsulation Mechanisms (KEX)

| Algorithm | Standard | Parameters | Security Level | Use Case |
|-----------|----------|-----------|---------------|----------|
| **ML-KEM-768** | FIPS 203 | Kyber-768 | NIST Level 3 (~AES-192) | General purpose key exchange |
| **ML-KEM-1024** | FIPS 203 | Kyber-1024 | NIST Level 5 (~AES-256) | High-security, long-term secrets |
| **Hybrid X25519+ML-KEM-768** | RFC 9794 | Dual KEX | Migration mode — classical + PQC | Transitional (acceptable for migration only) |

### 2.2 Digital Signatures

| Algorithm | Standard | Parameters | Signature Size | Use Case |
|-----------|----------|-----------|---------------|----------|
| **ML-DSA-65** | FIPS 204 | Dilithium-3 | 3,309 bytes | General purpose, medium security |
| **ML-DSA-87** | FIPS 204 | Dilithium-5 | 4,627 bytes | High-security, firmware signing |
| **SLH-DSA-SHA2-128s** | FIPS 205 | SPHINCS+ (small) | 7,856 bytes | Firmware signing — hash-based, no lattice assumption |
| **FN-DSA-512** | NIST (candidate) | Falcon-512 | 666 bytes | IoT/embedded — smallest signatures |

### 2.3 Symmetric Ciphers

| Algorithm | Status | Key Size | Use Case |
|-----------|--------|----------|----------|
| **AES-256-GCM** | PERMITTED | 256-bit | Bulk encryption (files, streams, disks) |
| **ChaCha20-Poly1305** | PERMITTED | 256-bit | Mobile/low-power encryption |
| AES-128-GCM | DEPRECATED | 128-bit | Grover's reduces to 64-bit — insufficient |
| AES-CBC | BANNED | Any | Padding oracle attacks, no authentication |

### 2.4 Hashing & Password-Based KDF

| Algorithm | Parameters | Use Case |
|-----------|-----------|----------|
| **Argon2id** | t=3, m=65536, p=4, len=32 | Password hashing, key derivation from human secrets |
| SHA-256 | N/A | Permitted for non-cryptographic use only |
| SHA-512 | N/A | General hashing — no known quantum speedup beyond Grover |
| SHA-3-512 | N/A | Preferred for new designs |
| MD5, SHA-1 | BANNED | Collision attacks practical |

---

## 3. Banned Classical Algorithms

These algorithms are **CATEGORICALLY BANNED** as standalone primitives. They may only be used in hybrid mode with a permitted PQC algorithm during migration.

| Algorithm | Type | Breakable By | Status |
|-----------|------|-------------|--------|
| RSA (all key sizes) | KEX + Sign | Shor's algorithm | BANNED |
| DSA | Signature | Shor's algorithm | BANNED |
| ECDSA (all curves) | Signature | Shor's algorithm | BANNED |
| ECDH (all curves) | KEX | Shor's algorithm | BANNED |
| Ed25519 | Signature | Shor's algorithm | BANNED |
| X25519 | KEX | Shor's algorithm | BANNED |
| MD5 | Hash | Classical collision | BANNED |
| SHA-1 | Hash | Classical collision (SHAttered) | BANNED |
| DES, 3DES | Symmetric | Classical brute force | BANNED |
| Blowfish | Symmetric | 64-bit block size | BANNED |
| AES-CBC | Symmetric | Padding oracle | BANNED |

### Enforcement
```
function validate_crypto_usage(system):
    for each algorithm in system.crypto_suite:
        if algorithm in BANNED_ALGORITHMS:
            if not in_hybrid_mode_with_pqc(algorithm):
                RAISE SecurityViolation(
                    f"BANNED: {algorithm} used standalone. "
                    f"Migrate to permitted PQC algorithm immediately. "
                    f"See Book 8 §2 for permitted alternatives."
                )
    return VALID
```

---

## 4. Hardware Root of Trust — Antifuse FPGA Architecture

### 4.1 Why Antifuse?

| Property | SRAM FPGA | Antifuse FPGA |
|----------|-----------|---------------|
| Configuration | Loaded from external flash on boot | Burned at factory, immutable |
| Modifiable via software? | YES — Copy Fail/Dirty Frag can dump and replace | NO — physical structure, cannot be altered |
| Survives kernel compromise? | NO — bitstream in kernel memory | YES — not in memory |
| Survives physical access? | NO — JTAG/SWD can reprogram | YES — requires chip destruction |
| Supply chain backdoor risk? | HIGH — IP cores can be replaced at any point | LOW — one-time burn, golden image verified |
| Cost (low-end) | $20-50 | $50-150 |
| Cost (high-end, rad-hard) | $500+ | $300-500 |

**Mandate**: ALL safety-critical logic in guardian robots, drones, communication gear, and forensic logging systems MUST reside on Antifuse FPGA. SRAM FPGAs are categorically banned for safety interlocks, geofence enforcement, cryptographic verification, and kill-switch logic.

### 4.2 Recommended Antifuse FPGAs

| Part | Family | Logic Cells | Cost | Use Case |
|------|--------|------------|------|----------|
| Microsemi A3P030 | ProASIC3 | 30K gates | ~$50 | Basic safety interlock, simple signature verify |
| Microsemi A3P250 | ProASIC3 | 250K gates | ~$150 | Motor controller, geofence, kill-switch |
| Microsemi RT4G150 | RTG4 | 150K LEs | ~$500 | Full flight controller, DRFM auth module, crypto accelerator |
| Microchip M2GL025 | IGLOO2 | 25K LEs | ~$80 | Mid-range: comms auth, sensor fusion safety |

### 4.3 Golden Image Verification

```
Bitstream Lifecycle:
1. DESIGN — In-house Verilog/VHDL. NO third-party IP cores.
2. SYNTHESIZE — On air-gapped machine. Verified by community hardware trust authority.
3. HASH — SHA3-512 of final bitstream. Signed with ML-DSA-65.
4. BURN — At trusted facility or community lab. One-time. Irreversible.
5. VERIFY — On deployment, read-back IDCODE and compare hash.
   If mismatch → chip has been tampered. DO NOT DEPLOY.
   If match → golden image confirmed. Deploy.
```

```bash
#!/bin/bash
# verify_antifuse_golden.sh
# Verify Antifuse FPGA match against community golden image database

CHIP_ID=$1
GOLDEN_HASHES="golden_hashes.txt"  # Signed by community trust authority

# Read device DNA (unique per chip, burned at factory)
DEVICE_DNA=$(openocd -f interface/jtag.cfg -f target/proasic3.cfg \
    -c "init; irscan 0x21; drscan 0x40; exit" | grep "DNA:" | awk '{print $2}')

# Look up expected hash
EXPECTED_HASH=$(grep "$DEVICE_DNA" "$GOLDEN_HASHES" | awk '{print $2}')

# Verify golden_hashes.txt signature
openssl pkeyutl -verify -pubin \
    -inkey community_trust_authority_ml_dsa_65.pub \
    -in golden_hashes.txt.sig \
    -sigfile golden_hashes.txt
if [ $? -ne 0 ]; then
    echo "FATAL: golden_hashes.txt signature verification FAILED"
    echo "Supply chain attack detected. DO NOT DEPLOY."
    exit 1
fi

if [ -z "$EXPECTED_HASH" ]; then
    echo "WARNING: Device DNA not in golden database"
    echo "This chip may be a counterfeit or unauthorized variant"
    exit 1
fi

echo "Golden image verified: $DEVICE_DNA matches $EXPECTED_HASH"
echo "Chip is authentic. Safe to deploy."
```

---

## 5. PQC Migration Path

### 5.1 Migration Strategy

```
PHASE 1 (IMMEDIATE): Critical systems
├── All new KEX → Hybrid X25519 + ML-KEM-768 (RFC 9794)
├── All new signatures → ML-DSA-65
├── All firmware signing → SLH-DSA-SHA2-128s (hash-based hedge)
└── All new symmetric → AES-256-GCM or ChaCha20-Poly1305

PHASE 2 (6 months): All systems
├── Replace all hybrid KEX with pure ML-KEM-1024
├── Replace all signatures with ML-DSA-87
├── Migrate all stored data encryption to AES-256-GCM
└── Deploy Antifuse FPGA verifiers on all guardian platforms

PHASE 3 (12 months): Long-term hardening
├── All systems pure PQC — no classical fallback
├── Antifuse FPGA on ALL safety-critical systems
├── Community Certificate Authority using ML-DSA-87
├── PQC-signed waveform standard deployed on all comms
```

### 5.2 Practical Implementation

```bash
# Generate ML-DSA-65 keypair
openssl genpkey -algorithm ML-DSA-65 -out community_key.priv
openssl pkey -in community_key.priv -pubout -out community_key.pub

# Sign firmware with ML-DSA-65
openssl pkeyutl -sign -inkey community_key.priv \
    -in firmware.bin -out firmware.bin.mldsa65.sig

# Also sign with SLH-DSA (hash-based hedge)
openssl pkeyutl -sign -inkey community_slh_key.priv \
    -in firmware.bin -out firmware.bin.slhdsa.sig

# Encrypt with ML-KEM-768 + AES-256-GCM
openssl enc -aes-256-gcm -pbkdf2 -iter 600000 \
    -in scrolls.txt -out scrolls.enc \
    -pass file:mlkem768_derived.key

# Derive key from Argon2id
echo -n "CommunityPassphrase2026" | argon2 "$(openssl rand -base64 16)" \
    -id -t 3 -m 65536 -p 4 -l 32 -r > mlkem768_derived.key
```

### 5.3 PQC Bypass Warning

Many industrial systems (BMS controllers, camera NVRs, drone flight controllers) accept firmware updates signed with classical RSA-2048 fallback — even when the primary verification chain uses PQC. This is the most common PQC bypass vector:

```bash
# The BMS controller says it uses ML-DSA-65 for firmware auth...
# But the bootloader accepts RSA-2048 self-signed firmware as fallback

openssl genrsa -out fake_rsa.key 2048
openssl dgst -sha256 -sign fake_rsa.key -out firmware.bin.sig firmware.bin
curl -X POST http://10.0.0.50:80/upgrade \
    -F "image=@firmware.bin" \
    -F "signature=@firmware.bin.sig"
# → BMS accepts because legacy path still trusts RSA
# → PQC signature never verified
```

**Defense**: Community systems MUST disable ALL classical fallback verification paths. The Antifuse FPGA verifier should accept ONLY ML-DSA-65 and SLH-DSA signatures. No RSA, no ECDSA, no Ed25519 — not even as "fallback."

---

## 6. Community Certificate Authority

### 6.1 Architecture

```
Community Hardware Trust Authority (CHTA)
│
├── Root CA: ML-DSA-87 keypair (offline, air-gapped, multi-signature)
│   ├── Ceremony: 3-of-5 community elders required to sign
│   └── Stored: Antifuse FPGA + paper backup (QR code, laminated)
│
├── Intermediate CA: ML-DSA-65 (online, HSMs)
│   ├── Guardian robot firmware signing
│   ├── Mesh node authentication
│   └── Forensic log attestation
│
└── End-entity certificates: ML-DSA-65 (per-device)
    ├── Each ESP32 node gets unique cert
    ├── Each guardian robot gets unique cert
    └── Each community phone gets unique cert
```

### 6.2 Certificate Policy

- **Validity**: 1 year for operational certs, 10 years for root
- **Revocation**: CRL distributed via LoRa mesh, updated daily
- **Key ceremony**: In-person, community gathering, 3-of-5 elder quorum
- **Key backup**: Antifuse FPGA (primary) + paper QR (disaster recovery)
- **Compromise response**: Immediate revocation + mesh-wide notification

---

## 7. Supply Chain Security

### 7.1 FPGA IP Core Audit

All FPGA IP cores used in community systems must be:
1. **Open-source** (OpenCores, PULP platform, CHISEL-generated) OR
2. **In-house Verilog/VHDL** audited by community hardware trust authority

**Banned**: Pre-compiled IP cores from Xilinx, Intel, Lattice, or any third-party vendor. The Xilinx AR#69444 and Intel SA-00463 advisories confirm that third-party IP cores may contain undocumented backdoors, kill-switches, or covert telemetry functions.

### 7.2 Hardware Procurement

- **Source directly** from manufacturer (Microchip Direct, Mouser, DigiKey)
- **Verify** golden image hash before deployment
- **Inspect** physically for tampering (extra components, modified traces)
- **Burn** bitstreams at trusted community facility — never at vendor
- **Document** full provenance chain for every chip

### 7.3 Software Supply Chain

The `@tanstack/*` npm supply chain compromise (2025) demonstrated that 42 packages can be poisoned to exfiltrate cloud credentials, GitHub tokens, and SSH keys. Community CI/CD pipelines must:

- Pin all dependencies by hash (not version)
- Verify npm/PyPI package signatures
- Run `detect-secrets` and `gitleaks` pre-commit scans
- Never execute untrusted CI/CD from external contributors without audit

---

## Exercises & Assessment

1. **Lab 8.1**: Generate ML-KEM-768 and ML-DSA-65 keypairs. Use them to establish an encrypted channel and sign a message. Verify.

2. **Lab 8.2**: Program a Microsemi ProASIC3 with a simple signature verifier (ML-DSA-65 public key burned in). Verify a signed message. Attempt to modify the key (should fail).

3. **Lab 8.3**: Audit a real-world IoT firmware update system. Identify all classical fallback paths. Document the PQC bypass vectors.

4. **Capstone Integration**: Design the complete Community Hardware Trust Authority ceremony. Specify the 3-of-5 elder quorum process, the Antifuse FPGA key storage, the paper backup protocol, and the compromise response plan.

---

*Volume 8 of 9 — PQC & Cryptography. For the final volume, see `books/09-github-repositories.md`.*
*Secure the present. Hedge against the quantum future. The people's data must survive.*
