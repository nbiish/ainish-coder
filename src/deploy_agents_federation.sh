#!/bin/bash
# MOLECULE: Cross-Machine Federation Chain of Draft (CoD) Ledger Deployment
# Deploys `.agents/federation/{date}.md` (one file per UTC date, gitignored,
# agent read-only, PQC-transferred via `--machine-sync`) and
# `.agents/federation/llms.txt` to a target repository. Merge-safe by design:
#   - Fresh target:            writes the full CoD protocol template and locks read-only.
#   - Existing daily file:     temporarily unlocks, refreshes ONLY `<PROTOCOL>...</PROTOCOL>`,
#                              preserves every peer CoD entry verbatim, and re-locks read-only.
#   - No PROTOCOL block found: legacy/foreign file — leaves untouched unless
#                              the operator explicitly confirms overwrite.

_fed_unlock_file() {
    local f="$1"
    [[ -e "$f" && ! -L "$f" ]] || return 0
    if command -v unlock_agents_contract >/dev/null 2>&1; then
        unlock_agents_contract "$f" >/dev/null 2>&1 || true
    else
        chflags nouchg "$f" 2>/dev/null || true
        chmod 644 "$f" 2>/dev/null || true
    fi
}

_fed_lock_file() {
    local f="$1"
    [[ -e "$f" && ! -L "$f" ]] || return 0
    if [[ "${AINISH_FEDERATION_NO_IMMUTABLE:-0}" == "1" ]]; then
        chmod 444 "$f" 2>/dev/null || true
        return 0
    fi
    if command -v lock_agents_contract >/dev/null 2>&1; then
        lock_agents_contract "$f" >/dev/null 2>&1 || true
    else
        chmod 444 "$f" 2>/dev/null || true
        chflags uchg "$f" 2>/dev/null || true
    fi
}

deploy_agents_federation() {
    local target_dir="${1:-.}"

    validate_target_dir "$target_dir" || return 1

    local today
    today="$(date -u +%F)"
    local fed_dir="$target_dir/.agents/federation"
    local dest="$fed_dir/${today}.md"
    local source="${REPO_DIR}/src/templates/AGENTS.FEDERATION.md"

    if [[ ! -f "$source" ]]; then
        echo -e "${BRIGHT_RED}Error: AGENTS.FEDERATION.md template not found at $source${RESET}"
        return 1
    fi

    mkdir -p "$fed_dir" || return 1

    # Ship the `.agents/federation/llms.txt` child contract alongside the daily ledger
    # so every target repository keeps an intact DOX chain.
    local idx_src="${REPO_DIR}/.agents/federation/llms.txt"
    local idx_dst="$fed_dir/llms.txt"
    if [[ -f "$idx_src" ]]; then
        local idx_tmp
        idx_tmp="$(ainish_temp_beside "$idx_dst")" || return 1
        cp "$idx_src" "$idx_tmp" && mv "$idx_tmp" "$idx_dst" && chmod 644 "$idx_dst"
    fi

    # Fresh deployment: no federation ledger for today (UTC).
    if [[ ! -f "$dest" ]]; then
        echo -e "${BRIGHT_BLUE}Deploying Federation CoD Ledger (agent read-only, PQC-synced) to: $dest${RESET}"
        local temp_file
        temp_file="$(ainish_temp_beside "$dest")" || return 1
        sed "s/{DATE}/$today/" "$source" > "$temp_file"
        mv "$temp_file" "$dest"
        _fed_lock_file "$dest"
        echo -e "${GREEN}✓ Created ${dest##*/} (CoD protocol ready, locked read-only for agents)${RESET}"
        echo -e "${BRIGHT_GREEN}✅ Federation CoD Ledger ready — read-only at ${dest}; synced via PQC --machine-sync${RESET}"
        return 0
    fi

    # Existing daily ledger — merge, never overwrite peer CoD entries.
    echo -e "${YELLOW}⚠️  Existing federation ledger ${dest##*/} found — merging (CoD entries preserved)${RESET}"

    local proto_start proto_end
    proto_start="$({ grep -n '^<PROTOCOL>$' "$dest" 2>/dev/null || true; } | head -1 | cut -d: -f1)"
    proto_end="$({ grep -n '^</PROTOCOL>$' "$dest" 2>/dev/null || true; } | head -1 | cut -d: -f1)"

    local tmpl_start tmpl_end
    tmpl_start="$({ grep -n '^<PROTOCOL>$' "$source" 2>/dev/null || true; } | head -1 | cut -d: -f1)"
    tmpl_end="$({ grep -n '^</PROTOCOL>$' "$source" 2>/dev/null || true; } | head -1 | cut -d: -f1)"

    if [[ -z "$proto_start" || -z "$proto_end" || -z "$tmpl_start" || -z "$tmpl_end" ]]; then
        if [[ -z "$proto_start" || -z "$proto_end" ]]; then
            echo -e "${YELLOW}⚠ No <PROTOCOL> block in existing federation ledger ${dest##*/}${RESET}"
            if confirm_action "Overwrite $dest with the standard Federation CoD protocol (existing content lost)?" "n"; then
                local temp_file
                temp_file="$(ainish_temp_beside "$dest")" || return 1
                sed "s/{DATE}/$today/" "$source" > "$temp_file"
                _fed_unlock_file "$dest"
                mv "$temp_file" "$dest"
                _fed_lock_file "$dest"
                echo -e "${GREEN}✓ Replaced with standard Federation CoD template (locked read-only)${RESET}"
                return 0
            fi
            echo -e "${YELLOW}⏭️  Left existing federation ledger ${dest##*/} untouched${RESET}"
            return 0
        fi
        echo -e "${BRIGHT_RED}Error: federation template missing <PROTOCOL> markers — cannot merge safely${RESET}"
        return 1
    fi

    local temp_file
    temp_file="$(ainish_temp_beside "$dest")" || return 1
    {
        sed -n "1,$((proto_start - 1))p" "$dest"
        sed -n "${tmpl_start},${tmpl_end}p" "$source"
        sed -n "$((proto_end + 1)),\$p" "$dest"
    } > "$temp_file"

    # Fail closed: every pre-existing CoD entry header must survive the merge.
    local missing=0
    while IFS= read -r entry_line; do
        [[ -z "$entry_line" ]] && continue
        if ! grep -qF -- "$entry_line" "$temp_file"; then
            echo -e "${BRIGHT_RED}Error: merge would drop federation entry: $entry_line${RESET}"
            missing=1
        fi
    done < <(grep '^### \[' "$dest" 2>/dev/null || true)

    if [[ "$missing" -ne 0 ]]; then
        rm -f "$temp_file"
        echo -e "${BRIGHT_RED}Error: merge aborted — federation entries would be lost. File untouched.${RESET}"
        return 1
    fi

    _fed_unlock_file "$dest"
    mv "$temp_file" "$dest"
    _fed_lock_file "$dest"
    echo -e "${GREEN}✓ Federation protocol refreshed; all CoD entries preserved and locked read-only in ${dest##*/}${RESET}"
    echo -e "${BRIGHT_GREEN}✅ Federation CoD Ledger merge complete${RESET}"
    return 0
}
