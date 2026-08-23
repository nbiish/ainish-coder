# TASK.2026-08-23 — pqc-secrets key naming convention

- read llms.txt; DOX chain root-only
- goal: tool-relative key prefixes everywhere
- examples: LOCALROUTER_*_API_KEY, AINISHCODER_*_API_KEY
- wrapper usage() gains Naming block
- wrapper setup hint generalized
- python usage strings gain same hint
- SKILL.md gains naming convention section
- root llms.txt PQC section gains bullet
- existing §5.4 text already aligned; unchanged
- plain names reserved: machine-shared keys
- no secrets; no crypto code touched
- docs + help-text only change

####

Deliverables:
1. bin/pqc-secrets — usage() Naming block + setup hint
2. pqc_secrets.py — usage/naming constants, main() prints
3. .agents/skills/pqc-secrets/SKILL.md — §4 naming convention
4. llms.txt — Secrets & Cryptography bullet
5. this task file
