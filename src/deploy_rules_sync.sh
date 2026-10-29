#!/bin/bash
# MOLECULE: Rules distribution & continuous auto-sync
# Makes `ainish-coder --rules` a one-time setup per repository:
#   1. writes .agents/ainish-deploy.json (source repo, source commit, AGENTS digest),
#   2. installs .agents/bin/ainish-rules-sync (portable sh refresher),
#   3. installs post-merge / post-checkout git hooks that call the refresher,
#   4. registers the target in ~/.config/ainish-coder/targets.txt for fleet sync,
#   5. installs a root post-commit/post-merge hook so every root contract advance
#      refreshes all registered targets via `--rules-sync --all`.
# The refresher is a no-op when the source commit/digest already matches, so hooks
# are cheap on ordinary git activity.

_AINISH_RULES_HOOK_START="# --- AINISH-CODER RULES SYNC START ---"
_AINISH_RULES_HOOK_END="# --- AINISH-CODER RULES SYNC END ---"

_ainish_rules_config_dir() {
    local dir="${AINISH_CONFIG_DIR:-${HOME}/.config/ainish-coder}"
    mkdir -p "$dir" 2>/dev/null || return 1
    printf '%s\n' "$dir"
}

_ainish_rules_registry_file() {
    local dir
    dir="$(_ainish_rules_config_dir)" || return 1
    printf '%s\n' "${dir}/targets.txt"
}

_ainish_rules_source_commit() {
    git -C "${REPO_DIR}" rev-parse HEAD 2>/dev/null || printf 'unknown\n'
}

_ainish_rules_source_agents_sha() {
    _calc_sha256 "${REPO_DIR}/AGENTS.md" 2>/dev/null | tr -d '[:space:]'
}

_ainish_rules_install_hook_block() {
    local hook="$1"
    local block="$2"
    mkdir -p "$(dirname "$hook")" 2>/dev/null || return 1

    if [[ ! -f "$hook" ]]; then
        printf '#!/bin/sh\n\n%s\n' "$block" > "$hook"
    elif grep -qF "$_AINISH_RULES_HOOK_START" "$hook" 2>/dev/null; then
        local tmp="${hook}.tmp.$$"
        BLOCK="$block" START="$_AINISH_RULES_HOOK_START" END="$_AINISH_RULES_HOOK_END" \
            awk '
                $0 == ENVIRON["START"] { inblock=1; printf "%s\n", ENVIRON["BLOCK"]; next }
                $0 == ENVIRON["END"]   { inblock=0; next }
                !inblock
            ' "$hook" > "$tmp" && mv "$tmp" "$hook"
    else
        # Append so existing hook logic (Husky, lefthook, etc.) is preserved.
        printf '\n%s\n' "$block" >> "$hook"
    fi
    chmod 755 "$hook" 2>/dev/null || chmod +x "$hook" 2>/dev/null || true
    return 0
}

# Writes the portable refresher that every deployed repo runs from its git hooks.
_ainish_rules_write_sync_script() {
    local target_dir="$1"
    local bin_dir="${target_dir}/.agents/bin"
    local script="${bin_dir}/ainish-rules-sync"
    mkdir -p "$bin_dir" 2>/dev/null || return 1

    cat > "$script" <<'AINISH_RULES_SYNC_EOF'
#!/bin/sh
# Managed by ainish-coder. Refreshes this repository's agent rules when the
# ainish-coder source contract advances. Safe no-op when already current.
set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." 2>/dev/null && pwd) || exit 0
MANIFEST="$ROOT/.agents/ainish-deploy.json"
LOG="$ROOT/.agents/ainish-sync.log"
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1
[ -f "$MANIFEST" ] || exit 0

field() {
    sed -n "s/^[[:space:]]*\"$1\":[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$MANIFEST" 2>/dev/null | head -n 1
}

SRC=$(field source_repo)
DEPLOYED_COMMIT=$(field source_commit)
DEPLOYED_SHA=$(field source_agents_sha256)
[ -n "$SRC" ] || exit 0

CUR_SHA=""
sha_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" 2>/dev/null | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$1" 2>/dev/null | awk '{print $NF}'
    fi
}

CURRENT_COMMIT=""
if command -v git >/dev/null 2>&1 && [ -d "$SRC/.git" ]; then
    CURRENT_COMMIT=$(git -C "$SRC" rev-parse HEAD 2>/dev/null || true)
fi

UP_TO_DATE=0
if [ -n "$CURRENT_COMMIT" ] && [ "$CURRENT_COMMIT" = "$DEPLOYED_COMMIT" ]; then
    UP_TO_DATE=1
elif [ -z "$CURRENT_COMMIT" ] && [ -f "$SRC/AGENTS.md" ]; then
    CUR_SHA=$(sha_of "$SRC/AGENTS.md")
    [ -n "$CUR_SHA" ] && [ "$CUR_SHA" = "$DEPLOYED_SHA" ] && UP_TO_DATE=1
fi
[ "$UP_TO_DATE" = "1" ] && exit 0

CLI="$SRC/bin/ainish-coder"
[ -x "$CLI" ] || CLI=$(command -v ainish-coder 2>/dev/null || true)
[ -n "$CLI" ] || exit 0

LOCK="$ROOT/.agents/.rules-sync.lock"
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT INT TERM HUP

[ "$QUIET" = "1" ] || printf '[ainish-rules-sync] refreshing rules from %s\n' "$SRC"
if AINISH_RULES_SYNC_ACTIVE=1 "$CLI" --rules "$ROOT" --headless -y >>"$LOG" 2>&1; then
    [ "$QUIET" = "1" ] || printf '[ainish-rules-sync] rules refreshed\n'
else
    printf '[ainish-rules-sync] refresh failed; see %s\n' "$LOG" >&2
fi
exit 0
AINISH_RULES_SYNC_EOF

    chmod 755 "$script" 2>/dev/null || chmod +x "$script" 2>/dev/null || true
    return 0
}

_ainish_rules_manifest_write() {
    local target_dir="$1"
    local manifest="${target_dir}/.agents/ainish-deploy.json"
    local source_repo="$2"
    local source_commit="$3"
    local source_sha="$4"
    mkdir -p "$(dirname "$manifest")" 2>/dev/null || return 1

    cat > "$manifest" <<MANIFEST_EOF
{
  "format": "ainish-coder/rules-deploy/v1",
  "source_repo": "${source_repo}",
  "source_commit": "${source_commit}",
  "source_agents_sha256": "${source_sha}",
  "deployed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "auto_sync": true,
  "managed_paths": [
    "AGENTS.md",
    "llms.txt",
    ".gitignore",
    ".agents/skills",
    ".agents/comms",
    ".agents/bin/ainish-rules-sync"
  ],
  "sync_script": ".agents/bin/ainish-rules-sync"
}
MANIFEST_EOF
    return 0
}

register_rules_target() {
    local target_dir="$1"
    local registry
    registry="$(_ainish_rules_registry_file)" || return 0
    grep -qxF "$target_dir" "$registry" 2>/dev/null || printf '%s\n' "$target_dir" >> "$registry"
    return 0
}

list_rules_targets() {
    local registry
    registry="$(_ainish_rules_registry_file)" || return 0
    [[ -f "$registry" ]] && cat "$registry"
    return 0
}

# Installs the target-side hooks (post-merge + post-checkout) that invoke the refresher.
install_rules_sync_hooks() {
    local target_dir="$1"
    [[ -d "${target_dir}/.git" ]] || return 0
    local hooks_dir="${target_dir}/.git/hooks"
    local block
    block="$(cat <<'HOOK_BLOCK'
# --- AINISH-CODER RULES SYNC START ---
# Refresh ainish-coder-managed rules when the source contract advanced.
if [ "${AINISH_RULES_SYNC_ACTIVE:-0}" != "1" ] && [ -x ".agents/bin/ainish-rules-sync" ]; then
    AINISH_RULES_SYNC_ACTIVE=1 sh ".agents/bin/ainish-rules-sync" --quiet >/dev/null 2>&1 || true
fi
# --- AINISH-CODER RULES SYNC END ---
HOOK_BLOCK
)"
    _ainish_rules_install_hook_block "${hooks_dir}/post-merge" "$block" || true
    _ainish_rules_install_hook_block "${hooks_dir}/post-checkout" "$block" || true
    return 0
}

# Root-side hooks: every root commit/merge refreshes all registered targets.
install_root_rules_sync_hook() {
    [[ -d "${REPO_DIR}/.git" ]] || return 0
    local hooks_dir="${REPO_DIR}/.git/hooks"
    local block
    block="$(cat <<'ROOT_HOOK_BLOCK'
# --- AINISH-CODER RULES SYNC START ---
if [ "${AINISH_RULES_SYNC_ACTIVE:-0}" != "1" ] && [ -x "REPO_DIR_PLACEHOLDER/bin/ainish-coder" ]; then
    AINISH_RULES_SYNC_ACTIVE=1 "REPO_DIR_PLACEHOLDER/bin/ainish-coder" --rules-sync --all --quiet >/dev/null 2>&1 || true
fi
# --- AINISH-CODER RULES SYNC END ---
ROOT_HOOK_BLOCK
)"
    block="${block//REPO_DIR_PLACEHOLDER/${REPO_DIR}}"
    local already_armed=false
    if [[ -f "${hooks_dir}/post-commit" ]] && grep -qF "$_AINISH_RULES_HOOK_START" "${hooks_dir}/post-commit" 2>/dev/null; then
        already_armed=true
    fi
    _ainish_rules_install_hook_block "${hooks_dir}/post-commit" "$block" || true
    _ainish_rules_install_hook_block "${hooks_dir}/post-merge" "$block" || true
    [[ "$already_armed" == "true" ]] || echo -e "${GREEN}✓ Root auto-sync hooks installed (post-commit, post-merge)${RESET}"
    return 0
}

# Deploys the auto-sync layer for a repository. Idempotent.
deploy_rules_sync() {
    local target_dir="${1:-.}"
    validate_target_dir "$target_dir" || return 1

    local target_abs
    target_abs="$(cd -P "$target_dir" 2>/dev/null && pwd)" || target_abs="$target_dir"

    # The source repo itself: install root-side fleet hooks, no manifest.
    if [[ "$target_abs" == "$REPO_DIR" ]]; then
        install_root_rules_sync_hook
        return 0
    fi

    local source_repo
    source_repo="$(cd -P "${REPO_DIR}" 2>/dev/null && pwd)" || source_repo="${REPO_DIR}"
    local source_commit source_sha
    source_commit="$(_ainish_rules_source_commit)"
    source_sha="$(_ainish_rules_source_agents_sha)"

    _ainish_rules_write_sync_script "$target_abs" || {
        print_warning "Could not write .agents/bin/ainish-rules-sync in ${target_abs}"
        return 1
    }
    _ainish_rules_manifest_write "$target_abs" "$source_repo" "$source_commit" "$source_sha" || {
        print_warning "Could not write .agents/ainish-deploy.json in ${target_abs}"
        return 1
    }
    install_rules_sync_hooks "$target_abs"
    register_rules_target "$target_abs"
    mkdir -p "$target_abs/.agents/memories" 2>/dev/null || true
    # Arm the source repo's fleet hooks too, so a target-only run also enables
    # automatic propagation on future root contract advances.
    install_root_rules_sync_hook 2>/dev/null || true

    echo -e "${GREEN}✓ Auto-sync armed: .agents/bin/ainish-rules-sync + git hooks${RESET}"
    echo -e "${BRIGHT_GREEN}🔄 Rules refresh automatically when the ainish-coder root contract advances${RESET}"
    return 0
}

# Runs the deployed refresher for one target, or falls back to a headless rules deploy.
rules_sync_target() {
    local target_dir="${1:-.}"
    validate_target_dir "$target_dir" || return 1
    local target_abs
    target_abs="$(cd -P "$target_dir" 2>/dev/null && pwd)" || target_abs="$target_dir"

    if [[ "$target_abs" == "$REPO_DIR" ]]; then
        install_root_rules_sync_hook
        return 0
    fi
    if [[ -x "${target_abs}/.agents/bin/ainish-rules-sync" ]]; then
        AINISH_RULES_SYNC_ACTIVE=1 "${target_abs}/.agents/bin/ainish-rules-sync"
        return $?
    fi
    echo -e "${YELLOW}No sync script in ${target_abs}; deploying rules once...${RESET}"
    AINISH_HEADLESS=true "${SCRIPT_DIR}/ainish-coder" --rules "$target_abs" --headless -y
}

rules_sync_all() {
    local quiet="${1:-false}"
    local registry
    registry="$(_ainish_rules_registry_file)" || return 1
    if [[ ! -f "$registry" ]]; then
        echo -e "${YELLOW}No registered rules targets yet. Run 'ainish-coder --rules <dir>' in a repo.${RESET}"
        return 0
    fi

    local src_commit
    src_commit="$(_ainish_rules_source_commit)"
    local total=0 synced=0 skipped=0 failed=0 target
    while IFS= read -r target; do
        [[ -z "$target" ]] && continue
        total=$((total + 1))
        if [[ ! -d "$target" ]]; then
            [[ "$quiet" == "true" ]] || echo -e "${YELLOW}⊘ Missing target: ${target}${RESET}"
            failed=$((failed + 1))
            continue
        fi
        if [[ ! -x "${target}/.agents/bin/ainish-rules-sync" ]]; then
            [[ "$quiet" == "true" ]] || echo -e "${YELLOW}⊘ No sync script (legacy target): ${target}${RESET}"
            skipped=$((skipped + 1))
            continue
        fi
        if [[ "$quiet" == "true" ]]; then
            AINISH_RULES_SYNC_ACTIVE=1 "${target}/.agents/bin/ainish-rules-sync" --quiet >/dev/null 2>&1 || failed=$((failed + 1))
        else
            echo -e "${BRIGHT_BLUE}→ ${target}${RESET}"
            AINISH_RULES_SYNC_ACTIVE=1 "${target}/.agents/bin/ainish-rules-sync" || failed=$((failed + 1))
        fi
        synced=$((synced + 1))
    done < "$registry"

    [[ "$quiet" == "true" ]] || {
        echo -e "${BRIGHT_GREEN}✅ Rules fleet sync complete: ${synced} checked, ${skipped} skipped, ${failed} failed (source ${src_commit:0:12})${RESET}"
    }
    return 0
}

_ainish_rules_json_escape() {
    local s="${1-}"
    s="${s//\\/\\\\}"
    printf '%s' "$s" | sed 's/"/\\"/g'
}

rules_status() {
    local json="${1:-false}"
    local registry src_commit
    registry="$(_ainish_rules_registry_file)" || return 1
    src_commit="$(_ainish_rules_source_commit)"

    local entries="" human=""
    local total=0 current=0 stale=0 missing=0
    local target manifest deployed status label
    if [[ -f "$registry" ]]; then
        while IFS= read -r target; do
            [[ -z "$target" ]] && continue
            total=$((total + 1))
            manifest="${target}/.agents/ainish-deploy.json"
            deployed=""
            if [[ ! -d "$target" ]]; then
                status="MISSING_DIR"; label="${YELLOW}?${RESET}"; missing=$((missing + 1))
            elif [[ ! -f "$manifest" ]]; then
                status="MISSING_MANIFEST"; label="${YELLOW}?${RESET}"; missing=$((missing + 1))
            else
                deployed="$(sed -n 's/^[[:space:]]*"source_commit":[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" | head -n 1)"
                if [[ "$deployed" == "$src_commit" ]]; then
                    status="CURRENT"; label="${GREEN}CURRENT${RESET}"; current=$((current + 1))
                else
                    status="STALE"; label="${YELLOW}STALE${RESET} (deployed ${deployed:0:12})"; stale=$((stale + 1))
                fi
            fi
            local p_path=$(_ainish_rules_json_escape "$target")
            local p_commit=$(_ainish_rules_json_escape "$deployed")
            entries+="{\"path\": \"$p_path\", \"status\": \"$status\", \"deployed_commit\": \"$p_commit\"},"
            human+="$(printf '  %b %s\n' "$label" "$target")"$'\n'
        done < "$registry"
    fi
    entries="${entries%,}"

    if [[ "$json" == "true" ]]; then
        printf '{\n'
        printf '  "format": "ainish-coder/rules-status/v1",\n'
        printf '  "source": "%s",\n' "$(_ainish_rules_json_escape "$REPO_DIR")"
        printf '  "source_commit": "%s",\n' "$(_ainish_rules_json_escape "$src_commit")"
        printf '  "registry": "%s",\n' "$(_ainish_rules_json_escape "$registry")"
        printf '  "targets": [%s],\n' "$entries"
        printf '  "summary": {"total": %d, "current": %d, "stale": %d, "missing": %d}\n' "$total" "$current" "$stale" "$missing"
        printf '}\n'
        return 0
    fi

    echo -e "${BRIGHT_BLUE}ainish-coder Rules Deployment Status${RESET}"
    echo -e "  Source:      ${REPO_DIR}"
    echo -e "  Source HEAD: ${src_commit}"
    echo -e "  Registry:    ${registry}"
    if [[ "$total" -eq 0 ]]; then
        echo -e "  Targets:     ${YELLOW}none registered${RESET}"
        return 0
    fi
    printf '%s' "$human"
    echo -e "  Summary:     ${total} target(s) — ${current} current, ${stale} stale, ${missing} missing"
    return 0
}

# Verifies auto-sync health for the root repo and every registered target,
# repairing infrastructure (manifest, refresher, hooks, registration) in place.
# Content staleness is reported only — use `--rules-sync` to redeploy content.
rules_doctor() {
    local json=false target_filter=""
    local a
    for a in "$@"; do
        case "$a" in
            --json) json=true ;;
            -*) ;;
            *) target_filter="$a" ;;
        esac
    done

    local hooks_dir="${REPO_DIR}/.git/hooks"
    local root_issues=0 root_repairs=0 root_hooks_ok=true
    if [[ -d "${REPO_DIR}/.git" ]]; then
        local hook
        for hook in post-commit post-merge; do
            if [[ ! -f "${hooks_dir}/${hook}" ]] || ! grep -qF "$_AINISH_RULES_HOOK_START" "${hooks_dir}/${hook}" 2>/dev/null; then
                root_hooks_ok=false
                install_root_rules_sync_hook >/dev/null 2>&1 || true
                if [[ -f "${hooks_dir}/${hook}" ]] && grep -qF "$_AINISH_RULES_HOOK_START" "${hooks_dir}/${hook}" 2>/dev/null; then
                    root_repairs=$((root_repairs + 1))
                    root_hooks_ok=true
                else
                    root_issues=$((root_issues + 1))
                fi
            fi
        done
    fi

    local targets=""
    if [[ -n "$target_filter" ]]; then
        targets="$target_filter"
    elif [[ -f "$(_ainish_rules_registry_file)" ]]; then
        targets="$(list_rules_targets)"
    fi

    local entries="" human=""
    local total=0 healthy=0 stale=0 issues=0 repairs=0
    local target
    while IFS= read -r target; do
        [[ -z "$target" ]] && continue
        total=$((total + 1))
        local manifest="${target}/.agents/ainish-deploy.json"
        local script="${target}/.agents/bin/ainish-rules-sync"
        local status="HEALTHY" t_issues=0 t_repairs=0 content="CURRENT"

        if [[ ! -d "$target" ]]; then
            status="MISSING_DIR"; t_issues=1; issues=$((issues + 1))
        else
            local need_repair=false
            [[ -f "$manifest" ]] || need_repair=true
            [[ -f "$script" ]] || need_repair=true
            if [[ ! -f "${target}/.git/hooks/post-merge" ]] || ! grep -qF "$_AINISH_RULES_HOOK_START" "${target}/.git/hooks/post-merge" 2>/dev/null; then
                need_repair=true
            fi
            if [[ -f "$manifest" ]]; then
                local m_src
                m_src="$(sed -n 's/^[[:space:]]*"source_repo":[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" | head -n 1)"
                [[ "$m_src" == "$REPO_DIR" ]] || need_repair=true
            fi
            if [[ "$need_repair" == "true" ]]; then
                if deploy_rules_sync "$target" >/dev/null 2>&1; then
                    t_repairs=1; repairs=$((repairs + 1))
                else
                    t_issues=1; issues=$((issues + 1))
                fi
            fi
            # Re-evaluate after the (idempotent) repair pass
            if [[ -f "$manifest" && -f "$script" && -f "${target}/.git/hooks/post-merge" ]] \
                && grep -qF "$_AINISH_RULES_HOOK_START" "${target}/.git/hooks/post-merge" 2>/dev/null; then
                if [[ "$status" != "UNHEALTHY" ]]; then status="HEALTHY"; healthy=$((healthy + 1)); fi
            else
                status="UNHEALTHY"; t_issues=1; issues=$((issues + 1))
            fi
            # Advisory: content staleness (deployed AGENTS digest vs source digest)
            local src_sha deployed_sha
            src_sha="$(_ainish_rules_source_agents_sha)"
            deployed_sha="$(sed -n 's/^[[:space:]]*"source_agents_sha256":[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" 2>/dev/null | head -n 1)"
            if [[ -n "$deployed_sha" && "$src_sha" != "$deployed_sha" ]]; then
                content="STALE"
                if [[ "$status" == "HEALTHY" ]]; then
                    status="RULES_STALE"; stale=$((stale + 1)); healthy=$((healthy - 1))
                fi
            fi
        fi
        entries+="{\"path\": \"$(_ainish_rules_json_escape "$target")\", \"status\": \"$status\", \"issues\": ${t_issues}, \"repairs\": ${t_repairs}, \"rules_content\": \"$content\"},"
        human+="$(printf '  %b %s (content: %s)\n' \
            "$([ "$status" = "HEALTHY" ] && printf '%s' "${GREEN}HEALTHY${RESET}" || printf '%s' "${YELLOW}${status}${RESET}")" \
            "$target" "$content")"$'\n'
    done <<< "$targets"
    entries="${entries%,}"

    local rc=0
    [[ $((issues + root_issues)) -gt 0 ]] && rc=1

    if [[ "$json" == "true" ]]; then
        printf '{\n'
        printf '  "format": "ainish-coder/rules-doctor/v1",\n'
        printf '  "source": "%s",\n' "$(_ainish_rules_json_escape "$REPO_DIR")"
        printf '  "source_commit": "%s",\n' "$(_ainish_rules_json_escape "$(_ainish_rules_source_commit)")"
        printf '  "root_hooks": {"healthy": %s, "issues": %d, "repairs": %d},\n' "$root_hooks_ok" "$root_issues" "$root_repairs"
        printf '  "targets": [%s],\n' "$entries"
        printf '  "summary": {"total": %d, "healthy": %d, "stale": %d, "issues": %d, "repairs": %d}\n' "$total" "$healthy" "$stale" "$issues" "$repairs"
        printf '}\n'
        return $rc
    fi

    echo -e "${BRIGHT_BLUE}ainish-coder Rules Doctor${RESET}"
    echo -e "  Source:      ${REPO_DIR} ($(_ainish_rules_source_commit | cut -c1-12))"
    echo -e "  Root hooks:  $([ "$root_hooks_ok" = "true" ] && printf '%s' "${GREEN}HEALTHY${RESET}" || printf '%s' "${RED}UNHEALTHY${RESET}")"
    if [[ "$total" -eq 0 ]]; then
        echo -e "  Targets:     ${YELLOW}none registered${RESET} (run 'ainish-coder --rules <dir>' to enroll one)"
    else
        printf '%s' "$human"
    fi
    echo -e "  Summary:     ${total} target(s) — ${healthy} healthy, ${stale} stale content, ${issues} issue(s), ${repairs} repaired"
    if [[ $rc -eq 0 ]]; then
        echo -e "${BRIGHT_GREEN}🩺 Rules deployment is healthy${RESET}"
    else
        echo -e "${BRIGHT_RED}🩺 Rules deployment has unresolved issues${RESET}"
    fi
    return $rc
}

# Optional foreground watcher: polls the source HEAD and syncs the fleet on change.
rules_watch() {
    local interval="${1:-30}"
    local last_commit
    last_commit="$(_ainish_rules_source_commit)"
    echo -e "${BRIGHT_BLUE}Watching ${REPO_DIR} every ${interval}s (Ctrl+C to stop)...${RESET}"
    while true; do
        sleep "$interval" 2>/dev/null || sleep 30
        local current
        current="$(_ainish_rules_source_commit)"
        if [[ "$current" != "$last_commit" ]]; then
            last_commit="$current"
            echo -e "${YELLOW}Source advanced to ${current:0:12} — syncing fleet...${RESET}"
            rules_sync_all false
        fi
    done
}
