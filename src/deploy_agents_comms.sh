#!/bin/bash
# MOLECULE: Agent Communication System deployment
# Deploys .agents/comms/{date}-{time}-team.txt — the concurrent-agent coordination ledger —
# to a target repository. Merge-safe by design:
#   - Fresh target:            writes the full protocol template.
#   - Existing ledger:         merges — refreshes ONLY the template-managed
#                              protocol header, preserves every agent-authored
#                              entry block verbatim (never overwrite context).
#   - No PROTOCOL block found: legacy/foreign file — leaves untouched unless
#                              the operator explicitly confirms overwrite.
# The live board (.agents/comms/{date}-team.live.txt) is never deployed: it is a
# gitignored, per-repo working surface, created empty on demand by agents.

deploy_agents_comms() {
    local target_dir="${1:-.}"

    validate_target_dir "$target_dir" || return 1

    local today
    today="$(date +%F)"
    local comms_dir="$target_dir/.agents/comms"
    # Active ledger = today's latest rotation; absent one, stamp a fresh time.
    local dest
    dest="$(ls -1 "$comms_dir/${today}"*-team.txt 2>/dev/null | sort | tail -1)"
    [[ -z "$dest" ]] && dest="$comms_dir/${today}-$(date +%H%M)-team.txt"
    local source="${REPO_DIR}/src/templates/AGENTS.COMMS.md"

    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: AGENTS.COMMS.md template not found at $source${RESET}"
        return 1
    fi

    # Fresh deployment: no ledger for today (or no AGENTS/ dir at all).
    if [[ ! -f "$dest" ]]; then
        echo -e "${BRIGHT_BLUE}Deploying Agent Communication System to: $dest${RESET}"
        mkdir -p "$comms_dir"
        local temp_file
        temp_file="$(mktemp)"
        # Render {DATE} placeholder in the template title line.
        sed "s/{DATE}/$today/" "$source" > "$temp_file"
        mv "$temp_file" "$dest"
        chmod 644 "$dest"
        echo -e "${GREEN}✓ Created ${dest##*/} (protocol + entry format ready)${RESET}"
        echo -e "${BRIGHT_GREEN}✅ Agent Communication System ready — agents check in to ${dest}${RESET}"
        return 0
    fi

    # Existing ledger for today — merge, never overwrite agent context.
    echo -e "${YELLOW}⚠️  Existing ledger ${dest##*/} found — merging (agent entries preserved)${RESET}"

    # Locate the template-managed region: the <PROTOCOL> ... </PROTOCOL> block.
    local proto_start proto_end
    proto_start="$(grep -n '^<PROTOCOL>$' "$dest" 2>/dev/null | head -1 | cut -d: -f1)"
    proto_end="$(grep -n '^</PROTOCOL>$' "$dest" 2>/dev/null | head -1 | cut -d: -f1)"

    # Extract protocol body (between markers) from the template.
    local tmpl_start tmpl_end
    tmpl_start="$(grep -n '^<PROTOCOL>$' "$source" 2>/dev/null | head -1 | cut -d: -f1)"
    tmpl_end="$(grep -n '^</PROTOCOL>$' "$source" 2>/dev/null | head -1 | cut -d: -f1)"

    # No PROTOCOL block in destination → legacy or foreign ledger. Refuse to
    # touch it without explicit confirmation (interactive); skip under -y.
    if [[ -z "$proto_start" || -z "$proto_end" || -z "$tmpl_start" || -z "$tmpl_end" ]]; then
        if [[ -z "$proto_start" || -z "$proto_end" ]]; then
            echo -e "${YELLOW}⚠ No <PROTOCOL> block in existing ledger ${dest##*/}${RESET}"
            if confirm_action "Overwrite $dest with the standard protocol (existing content lost)?" "n"; then
                local temp_file
                temp_file="$(mktemp)"
                sed "s/{DATE}/$today/" "$source" > "$temp_file"
                mv "$temp_file" "$dest"
                echo -e "${GREEN}✓ Replaced with standard protocol template${RESET}"
                return 0
            fi
            echo -e "${YELLOW}⏭️  Left existing ledger ${dest##*/} untouched${RESET}"
            return 0
        fi
        echo -e "${BRIGHT_RED}Error: template missing <PROTOCOL> markers — cannot merge safely${RESET}"
        return 1
    fi

    # Merge: everything before <PROTOCOL> + fresh protocol + everything after
    # </PROTOCOL>. Agent entry blocks live after </PROTOCOL> and pass through
    # byte-for-byte.
    local temp_file
    temp_file="$(mktemp)"
    {
        sed -n "1,$((proto_start - 1))p" "$dest"
        sed -n "${tmpl_start},${tmpl_end}p" "$source"
        sed -n "$((proto_end + 1)),\$p" "$dest"
    } > "$temp_file"

    # Sanity: merged file must still contain every pre-existing entry header.
    local missing=0
    while IFS= read -r entry_line; do
        [[ -z "$entry_line" ]] && continue
        if ! grep -qF -- "$entry_line" "$temp_file"; then
            echo -e "${BRIGHT_RED}Error: merge would drop ledger entry: $entry_line${RESET}"
            missing=1
        fi
    done < <(grep '^### \[' "$dest" 2>/dev/null || true)

    if [[ "$missing" -ne 0 ]]; then
        rm -f "$temp_file"
        echo -e "${BRIGHT_RED}Error: merge aborted — agent entries would be lost. File untouched.${RESET}"
        return 1
    fi

    mv "$temp_file" "$dest"
    chmod 644 "$dest"
    echo -e "${GREEN}✓ Protocol refreshed; all agent entries preserved in ${dest##*/}${RESET}"
    echo -e "${BRIGHT_GREEN}✅ Agent Communication System merge complete${RESET}"
    return 0
}
