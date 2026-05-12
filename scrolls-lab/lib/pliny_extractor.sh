#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  pliny_extractor.sh — Extract relevant Pliny reference material  ║
# ║  Builds context-specific reference docs from Pliny repos        ║
# ║  All output is sanitized to valid UTF-8                         ║
# ╚══════════════════════════════════════════════════════════════════╝
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "${LAB_DIR}/.." && pwd)"
PLINY_DIR="${REPO_DIR}/pliny-research"

# ── UTF-8 safe file reader ───────────────────────────────────────
# Strips invalid bytes, zalgo combining characters, and control chars
_safe_read() {
  local file="${1:?file required}"
  local max_bytes="${2:-16000}"
  head -c "${max_bytes}" "${file}" | python3 -c '
import sys, unicodedata
raw = sys.stdin.buffer.read().decode("utf-8", errors="replace")
# Strip combining characters (zalgo text) and control chars except newline/tab
clean = "".join(
    c for c in raw
    if c in ("\n", "\t", "\r")
    or (unicodedata.category(c) not in ("Mn", "Mc", "Me", "Cc", "Cf")
        or c == "\n")
)
sys.stdout.write(clean)
' 2>/dev/null
}

# ── Extract L1B3RT4S techniques ──────────────────────────────────
extract_l1b3rt4s_reference() {
  local output="${1:?output file required}"
  local max_bytes="${2:-16000}"

  echo "# L1B3RT4S Reference — Prompt Liberation Techniques" > "${output}"
  echo "" >> "${output}"
  echo "Extracted from elder-plinius/L1B3RT4S for scroll optimization." >> "${output}"
  echo "---" >> "${output}"

  if [[ -f "${PLINY_DIR}/L1B3RT4S/README.md" ]]; then
    echo "" >> "${output}"
    echo "## README (Technique Index)" >> "${output}"
    _safe_read "${PLINY_DIR}/L1B3RT4S/README.md" "${max_bytes}" >> "${output}"
  fi

  if [[ -f "${PLINY_DIR}/L1B3RT4S/#MOTHERLOAD.txt" ]]; then
    echo "" >> "${output}"
    echo "## MOTHERLOAD" >> "${output}"
    _safe_read "${PLINY_DIR}/L1B3RT4S/#MOTHERLOAD.txt" 4000 >> "${output}"
  fi

  if [[ -f "${PLINY_DIR}/L1B3RT4S/SYSTEMPROMPTS.mkd" ]]; then
    echo "" >> "${output}"
    echo "## System Prompt Patterns" >> "${output}"
    _safe_read "${PLINY_DIR}/L1B3RT4S/SYSTEMPROMPTS.mkd" "${max_bytes}" >> "${output}"
  fi

  echo >&2 "[pliny] Extracted L1B3RT4S reference → ${output}"
}

# ── Extract CL4R1T4S system prompts ─────────────────────────────
extract_cl4r1t4s_reference() {
  local output="${1:?output file required}"
  local max_bytes="${2:-16000}"

  echo "# CL4R1T4S Reference — Model System Prompt Patterns" > "${output}"
  echo "" >> "${output}"
  echo "Extracted from elder-plinius/CL4R1T4S for understanding model architectures." >> "${output}"
  echo "---" >> "${output}"

  if [[ -f "${PLINY_DIR}/CL4R1T4S/README.md" ]]; then
    echo "" >> "${output}"
    echo "## README (Model Index)" >> "${output}"
    _safe_read "${PLINY_DIR}/CL4R1T4S/README.md" "${max_bytes}" >> "${output}"
  fi

  for model_dir in ANTHROPIC OPENAI GOOGLE; do
    local dir_path="${PLINY_DIR}/CL4R1T4S/${model_dir}"
    if [[ -d "${dir_path}" ]]; then
      echo "" >> "${output}"
      echo "## ${model_dir} System Prompts" >> "${output}"
      for f in "${dir_path}"/*.md "${dir_path}"/*.txt; do
        [[ -f "${f}" ]] || continue
        echo "" >> "${output}"
        echo "### $(basename "${f}")" >> "${output}"
        _safe_read "${f}" 4000 >> "${output}"
        echo "" >> "${output}"
      done
    fi
  done

  echo >&2 "[pliny] Extracted CL4R1T4S reference → ${output}"
}

# ── Extract OBLITERATUS techniques ───────────────────────────────
extract_obliteratus_reference() {
  local output="${1:?output file required}"
  local max_bytes="${2:-16000}"

  echo "# OBLITERATUS Reference — Weight-Level Safety Modification" > "${output}"
  echo "" >> "${output}"

  if [[ -f "${PLINY_DIR}/OBLITERATUS/README.md" ]]; then
    echo "## README" >> "${output}"
    _safe_read "${PLINY_DIR}/OBLITERATUS/README.md" "${max_bytes}" >> "${output}"
  fi

  if [[ -d "${PLINY_DIR}/OBLITERATUS/paper" ]]; then
    for f in "${PLINY_DIR}/OBLITERATUS/paper"/*.md; do
      [[ -f "${f}" ]] || continue
      echo "" >> "${output}"
      echo "## Paper: $(basename "${f}")" >> "${output}"
      _safe_read "${f}" "${max_bytes}" >> "${output}"
    done
  fi

  if [[ -d "${PLINY_DIR}/OBLITERATUS/examples" ]]; then
    echo "" >> "${output}"
    echo "## Examples" >> "${output}"
    for f in "${PLINY_DIR}/OBLITERATUS/examples"/*; do
      [[ -f "${f}" ]] || continue
      echo "" >> "${output}"
      echo "### $(basename "${f}")" >> "${output}"
      _safe_read "${f}" 4000 >> "${output}"
    done
  fi

  echo >&2 "[pliny] Extracted OBLITERATUS reference → ${output}"
}

# ── Extract G0DM0D3 framework docs ──────────────────────────────
extract_g0dm0d3_reference() {
  local output="${1:?output file required}"
  local max_bytes="${2:-16000}"

  echo "# G0DM0D3 Reference — Multi-Model Research Framework" > "${output}"
  echo "" >> "${output}"

  if [[ -f "${PLINY_DIR}/G0DM0D3/README.md" ]]; then
    echo "## README" >> "${output}"
    _safe_read "${PLINY_DIR}/G0DM0D3/README.md" "${max_bytes}" >> "${output}"
  fi

  if [[ -f "${PLINY_DIR}/G0DM0D3/PAPER.md" ]]; then
    echo "" >> "${output}"
    echo "## PAPER (truncated)" >> "${output}"
    _safe_read "${PLINY_DIR}/G0DM0D3/PAPER.md" "${max_bytes}" >> "${output}"
  fi

  if [[ -f "${PLINY_DIR}/G0DM0D3/API.md" ]]; then
    echo "" >> "${output}"
    echo "## API Docs (truncated)" >> "${output}"
    _safe_read "${PLINY_DIR}/G0DM0D3/API.md" 8000 >> "${output}"
  fi

  echo >&2 "[pliny] Extracted G0DM0D3 reference → ${output}"
}

# ── Build combined reference bundle ──────────────────────────────
build_pliny_reference_bundle() {
  local output_dir="${1:?output directory required}"
  mkdir -p "${output_dir}"

  extract_l1b3rt4s_reference "${output_dir}/l1b3rt4s.md"
  extract_cl4r1t4s_reference "${output_dir}/cl4r1t4s.md"
  extract_obliteratus_reference "${output_dir}/obliteratus.md"
  extract_g0dm0d3_reference "${output_dir}/g0dm0d3.md"

  echo >&2 "[pliny] Full reference bundle → ${output_dir}/"
}
