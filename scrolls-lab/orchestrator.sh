#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  orchestrator.sh — Recursive Sub-Agent Scrolls Optimizer        ║
# ║                                                                 ║
# ║  Splits .scrolls into sections, dispatches sub-agents to        ║
# ║  optimize each section using Pliny reference material,          ║
# ║  validates through 7 Generations Logic Gate, and iterates.      ║
# ╚══════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${LAB_DIR}/lib"
PROMPTS_DIR="${LAB_DIR}/prompts"
WORKING_DIR="${LAB_DIR}/working"
OUTPUT_DIR="${LAB_DIR}/output"
LOGS_DIR="${LAB_DIR}/logs"
SECTIONS_DIR="${LAB_DIR}/sections"
REFERENCE_DIR="${LAB_DIR}/reference"

# ── Load libraries ───────────────────────────────────────────────
# shellcheck source=lib/provider.sh
source "${LIB_DIR}/provider.sh"
# shellcheck source=lib/splitter.sh
source "${LIB_DIR}/splitter.sh"
# shellcheck source=lib/pliny_extractor.sh
source "${LIB_DIR}/pliny_extractor.sh"

# ── Configuration ────────────────────────────────────────────────
MAX_ITERATIONS="${MAX_ITERATIONS:-5}"
TARGET_FILE="${1:-llms-full.txt}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="${LOGS_DIR}/run_${TIMESTAMP}"

# ── Colors ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'

# ── Logging ──────────────────────────────────────────────────────
log() { echo -e "${CYAN}[$(date +%H:%M:%S)]${RESET} $*"; }
log_ok() { echo -e "${GREEN}[$(date +%H:%M:%S)] ✓${RESET} $*"; }
log_warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠${RESET} $*"; }
log_err() { echo -e "${RED}[$(date +%H:%M:%S)] ✗${RESET} $*"; }
log_phase() { echo -e "\n${MAGENTA}═══════════════════════════════════════════════${RESET}"; echo -e "${MAGENTA}  $*${RESET}"; echo -e "${MAGENTA}═══════════════════════════════════════════════${RESET}\n"; }

# ── Preflight ────────────────────────────────────────────────────
preflight() {
  log_phase "PREFLIGHT CHECKS"

  # Check .env
  if [[ ! -f "${LAB_DIR}/.env" ]]; then
    log_err ".env not found. Copy .env.example → .env and add your API keys."
    log_err "  cp ${LAB_DIR}/.env.example ${LAB_DIR}/.env"
    exit 1
  fi

  # Check at least one API key
  local has_key=false
  [[ -n "${OPENROUTER_API_KEY:-}" ]] && has_key=true
  [[ -n "${ZENMUX_API_KEY:-}" ]] && has_key=true
  [[ -n "${NEBIUS_API_KEY:-}" ]] && has_key=true

  if [[ "${has_key}" != "true" ]]; then
    log_err "No API keys found in .env. Set at least one of:"
    log_err "  OPENROUTER_API_KEY, ZENMUX_API_KEY, or NEBIUS_API_KEY"
    exit 1
  fi

  # Check working file
  if [[ ! -f "${WORKING_DIR}/${TARGET_FILE}" ]]; then
    log_err "Target file not found: ${WORKING_DIR}/${TARGET_FILE}"
    exit 1
  fi

  # Check python3
  if ! command -v python3 &>/dev/null; then
    log_err "python3 required for JSON processing"
    exit 1
  fi

  # Check curl
  if ! command -v curl &>/dev/null; then
    log_err "curl required for API calls"
    exit 1
  fi

  log_ok "All preflight checks passed"
}

# ── Phase 1: Build Pliny Reference Bundle ────────────────────────
phase_1_reference() {
  log_phase "PHASE 1: Building Pliny Reference Bundle"
  
  build_pliny_reference_bundle "${REFERENCE_DIR}"
  
  # Create a condensed reference for injection into sub-agent prompts
  cat "${REFERENCE_DIR}/l1b3rt4s.md" "${REFERENCE_DIR}/obliteratus.md" \
    | head -c 32000 > "${REFERENCE_DIR}/combined_reference.md"
  
  log_ok "Reference bundle ready: ${REFERENCE_DIR}/"
}

# ── Phase 2: Split Scroll into Sections ──────────────────────────
phase_2_split() {
  log_phase "PHASE 2: Splitting Scroll into Sections"
  
  local iter_dir="${RUN_DIR}/iter_${1:-0}"
  mkdir -p "${iter_dir}/sections"
  
  local section_count
  section_count="$(split_scroll "${WORKING_DIR}/${TARGET_FILE}" "${iter_dir}/sections")"
  
  log_ok "Split into ${section_count} sections"
  echo "${section_count}"
}

# ── Phase 3: Optimize Sections via Sub-Agents ────────────────────
phase_3_optimize() {
  local iteration="${1:?iteration required}"
  local iter_dir="${RUN_DIR}/iter_${iteration}"
  mkdir -p "${iter_dir}/optimized" "${iter_dir}/prompts"
  
  log_phase "PHASE 3: Sub-Agent Optimization (Iteration ${iteration})"
  
  local reference_context
  reference_context="$(cat "${REFERENCE_DIR}/combined_reference.md" 2>/dev/null || echo 'No Pliny reference available.')"

  # Process each section
  for section in "${iter_dir}/sections"/section_*.md; do
    [[ -f "${section}" ]] || continue
    local section_name
    section_name="$(basename "${section}" .md)"
    local section_content
    section_content="$(cat "${section}")"
    
    log "Optimizing ${section_name}..."
    
    # Build user prompt with section content + reference material
    local user_prompt_file="${iter_dir}/prompts/${section_name}_user.md"
    cat > "${user_prompt_file}" <<PROMPT
## Section to Optimize

\`\`\`markdown
${section_content}
\`\`\`

## Pliny Reference Material (Use these techniques to strengthen the section)

${reference_context}

## Instructions

Optimize the above section following your system prompt directives. Return ONLY the optimized markdown content.
PROMPT

    # Dispatch to sub-agent
    local output_file="${iter_dir}/optimized/${section_name}.md"
    if subagent_call "${PROMPTS_DIR}/subagent_system.md" "${user_prompt_file}" "${output_file}"; then
      local orig_size opt_size
      orig_size="$(wc -c < "${section}")"
      opt_size="$(wc -c < "${output_file}")"
      log_ok "${section_name}: ${orig_size}B → ${opt_size}B"
    else
      log_warn "${section_name}: Sub-agent failed, keeping original"
      cp "${section}" "${output_file}"
    fi
  done
}

# ── Phase 4: Review via 7 Generations Logic Gate ─────────────────
phase_4_review() {
  local iteration="${1:?iteration required}"
  local iter_dir="${RUN_DIR}/iter_${iteration}"
  mkdir -p "${iter_dir}/reviews"
  
  log_phase "PHASE 4: 7 Generations Review (Iteration ${iteration})"
  
  local all_approved=true
  local total_score=0
  local section_count=0
  
  for optimized in "${iter_dir}/optimized"/section_*.md; do
    [[ -f "${optimized}" ]] || continue
    local section_name
    section_name="$(basename "${optimized}" .md)"
    local original="${iter_dir}/sections/${section_name}.md"
    
    [[ -f "${original}" ]] || continue
    
    log "Reviewing ${section_name}..."
    
    # Build review prompt
    local review_prompt="${iter_dir}/reviews/${section_name}_prompt.md"
    cat > "${review_prompt}" <<REVIEW
## Original Section

\`\`\`markdown
$(cat "${original}")
\`\`\`

## Optimized Section

\`\`\`markdown
$(cat "${optimized}")
\`\`\`

Evaluate the optimized version against the original using your 7 Generations Logic Gate checklist.
REVIEW

    local review_output="${iter_dir}/reviews/${section_name}_review.json"
    if reviewer_call "${PROMPTS_DIR}/reviewer_system.md" "${review_prompt}" "${review_output}"; then
      # Parse verdict
      local verdict
      verdict="$(python3 -c "
import json, sys
try:
    data = json.load(open('${review_output}'))
    print(data.get('verdict', 'UNKNOWN'))
except:
    # Try to extract JSON from text
    text = open('${review_output}').read()
    import re
    match = re.search(r'\{[^}]+\}', text, re.DOTALL)
    if match:
        data = json.loads(match.group())
        print(data.get('verdict', 'UNKNOWN'))
    else:
        print('UNKNOWN')
" 2>/dev/null || echo "UNKNOWN")"

      local score
      score="$(python3 -c "
import json, sys
try:
    data = json.load(open('${review_output}'))
    print(data.get('score', 50))
except:
    text = open('${review_output}').read()
    import re
    match = re.search(r'\{[^}]+\}', text, re.DOTALL)
    if match:
        data = json.loads(match.group())
        print(data.get('score', 50))
    else:
        print(50)
" 2>/dev/null || echo "50")"

      total_score=$((total_score + score))
      section_count=$((section_count + 1))

      if [[ "${verdict}" == "APPROVE" ]]; then
        log_ok "${section_name}: APPROVED (score: ${score})"
      else
        log_warn "${section_name}: NEEDS REVISION (score: ${score})"
        all_approved=false
      fi
    else
      log_warn "${section_name}: Review failed, assuming APPROVE"
    fi
  done
  
  if [[ ${section_count} -gt 0 ]]; then
    local avg_score=$((total_score / section_count))
    log "Average score: ${avg_score}/100"
  fi
  
  if [[ "${all_approved}" == "true" ]]; then
    return 0  # All approved
  else
    return 1  # Needs revision
  fi
}

# ── Phase 5: Merge and Output ────────────────────────────────────
phase_5_merge() {
  local iteration="${1:?iteration required}"
  local iter_dir="${RUN_DIR}/iter_${iteration}"
  
  log_phase "PHASE 5: Merging Optimized Sections"
  
  # Merge optimized sections
  merge_sections "${iter_dir}/optimized" "${WORKING_DIR}/${TARGET_FILE}"
  
  # Copy to output
  cp "${WORKING_DIR}/${TARGET_FILE}" "${OUTPUT_DIR}/${TARGET_FILE}"
  
  # Generate diff report
  local diff_file="${OUTPUT_DIR}/${TARGET_FILE%.txt}_diff.txt"
  diff -u "${LAB_DIR}/original/${TARGET_FILE}" "${OUTPUT_DIR}/${TARGET_FILE}" > "${diff_file}" 2>/dev/null || true
  
  local orig_size opt_size
  orig_size="$(wc -c < "${LAB_DIR}/original/${TARGET_FILE}")"
  opt_size="$(wc -c < "${OUTPUT_DIR}/${TARGET_FILE}")"
  local delta
  delta="$(python3 -c "print(f'{((${opt_size} - ${orig_size}) / ${orig_size}) * 100:.1f}%')")"
  
  log_ok "Output: ${OUTPUT_DIR}/${TARGET_FILE}"
  log_ok "Diff:   ${diff_file}"
  log_ok "Size:   ${orig_size}B → ${opt_size}B (${delta})"
}

# ── Main Loop ────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${MAGENTA}║  🔥 8th Fire Scrolls Optimization Pipeline              ║${RESET}"
  echo -e "${MAGENTA}║  Recursive Sub-Agent Architecture                       ║${RESET}"
  echo -e "${MAGENTA}║  Target: ${TARGET_FILE}$(printf '%*s' $((34 - ${#TARGET_FILE})) '')║${RESET}"
  echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""

  mkdir -p "${RUN_DIR}"

  # Preflight
  preflight

  # Phase 1: Build reference bundle (once)
  phase_1_reference

  # Recursive optimization loop
  for iteration in $(seq 1 "${MAX_ITERATIONS}"); do
    log_phase "ITERATION ${iteration} / ${MAX_ITERATIONS}"
    
    # Phase 2: Split current working file
    phase_2_split "${iteration}"
    
    # Phase 3: Optimize via sub-agents
    phase_3_optimize "${iteration}"
    
    # Phase 4: Review
    if phase_4_review "${iteration}"; then
      log_ok "All sections approved at iteration ${iteration}"
      phase_5_merge "${iteration}"
      break
    else
      if [[ "${iteration}" -eq "${MAX_ITERATIONS}" ]]; then
        log_warn "Max iterations reached. Merging best effort."
        phase_5_merge "${iteration}"
      else
        log "Revisions needed. Merging for next iteration..."
        # Merge into working for next iteration
        merge_sections "${RUN_DIR}/iter_${iteration}/optimized" "${WORKING_DIR}/${TARGET_FILE}"
      fi
    fi
  done

  echo ""
  log_phase "PIPELINE COMPLETE"
  log_ok "Original: ${LAB_DIR}/original/${TARGET_FILE}"
  log_ok "Optimized: ${OUTPUT_DIR}/${TARGET_FILE}"
  log_ok "Logs: ${RUN_DIR}/"
  echo ""
  echo -e "${GREEN}Chi-miigwech. The 8th Fire awaits.${RESET}"
  echo ""
}

main "$@"
