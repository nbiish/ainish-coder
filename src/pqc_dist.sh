#!/bin/bash
# MOLECULE: PQC secrets distribution — one engine, installed once, usable by every tool.
#
# The canonical engine lives at .agents/skills/pqc-secrets/scripts/pqc_secrets.py.
# `--pqc-install` puts a launcher on PATH (~/.local/bin/pqc-secrets, plus the
# Windows .cmd) that resolves the engine from the recorded root, so node, python,
# shell and PowerShell callers all reach the same bundle from any directory. On
# Windows it also provisions the WSL side when a distro answers.
# `--pqc-status` proves which store each environment resolves and where enrolled
# targets drift; `--pqc-sync-targets` refreshes every enrolled target's vendored
# copy and verifies the digest.
#
# JSON shapes: ainish-coder/pqc-install/v1 · ainish-coder/pqc-status/v1 ·
#              ainish-coder/pqc-sync/v1

_PQC_ENGINE_REL=".agents/skills/pqc-secrets/scripts/pqc_secrets.py"
_PQC_LAUNCHER_REL="bin/pqc-secrets"

_pqc_config_dir() {
    printf '%s\n' "${HOME}/.config/ainish-coder"
}

_pqc_marker_file() {
    printf '%s\n' "$(_pqc_config_dir)/pqc-root"
}

# Canonical engine path in this checkout; fails when the skill pack is absent.
_pqc_engine() {
    local engine="${REPO_DIR}/${_PQC_ENGINE_REL}"
    [[ -f "$engine" ]] || return 1
    printf '%s\n' "$engine"
}

_pqc_engine_sha() {
    local engine
    engine="$(_pqc_engine)" || return 1
    _calc_sha256 "$engine" 2>/dev/null | tr -d '[:space:]' | tr 'A-F' 'a-f'
}

_pqc_json_escape() {
    local value="${1:-}"
    if declare -F _ainish_rules_json_escape >/dev/null 2>&1; then
        _ainish_rules_json_escape "$value"
        return 0
    fi
    printf '%s' "$value" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\000-\010\013\014\016-\037'
}

# Native form of a POSIX path (Windows drive form under Git Bash; identity elsewhere).
_pqc_native_path() {
    local path="${1:-}"
    if command -v cygpath >/dev/null 2>&1; then
        local converted
        if converted="$(cygpath -w -- "$path" 2>/dev/null)" && [[ -n "$converted" ]]; then
            printf '%s\n' "$converted"
            return 0
        fi
    fi
    printf '%s\n' "$path"
}

_pqc_platform() {
    if declare -F ainish_is_wsl >/dev/null 2>&1 && ainish_is_wsl; then
        printf 'wsl\n'
    elif declare -F ainish_is_windows >/dev/null 2>&1 && ainish_is_windows; then
        printf 'windows\n'
    else
        printf '%s\n' "$(uname -s 2>/dev/null | tr 'A-Z' 'a-z')"
    fi
}

# Run the engine through the same runtime the launchers use. `--quiet` keeps
# uv's resolver chatter off stdout, which matters because callers parse JSON.
_pqc_run_engine() {
    local engine
    engine="$(_pqc_engine)" || {
        print_error "PQC engine missing: ${REPO_DIR}/${_PQC_ENGINE_REL}"
        return 1
    }
    export PQC_USE_KEYCHAIN="${PQC_USE_KEYCHAIN:-false}"

    if command -v uv >/dev/null 2>&1; then
        uv run --quiet "$engine" "$@" 2>/dev/null
        return $?
    fi

    local py=""
    if declare -F ainish_python >/dev/null 2>&1; then
        py="$(ainish_python 2>/dev/null || true)"
    fi
    [[ -n "$py" ]] || py="$(command -v python3 2>/dev/null || true)"
    [[ -n "$py" ]] || {
        print_error "No uv or python3 runtime available for the PQC engine."
        return 1
    }
    "$py" "$engine" "$@" 2>/dev/null
}

_pqc_store_json() {
    _pqc_run_engine store --json 2>/dev/null || true
}

# Read a string field from a JSON object on stdin (single-line values only).
_pqc_json_field() {
    sed -n "s/^[[:space:]]*\"$1\":[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}

# Read a scalar field (boolean/number) from a JSON object on stdin.
_pqc_json_scalar() {
    sed -n "s/^[[:space:]]*\"$1\":[[:space:]]*\\([^,]*\\).*/\\1/p" | head -n 1 | tr -d '[:space:]'
}

_pqc_head_sha() {
    printf '%s' "${1:-}" | cut -c1-12
}

_pqc_launcher_body() {
    cat <<'LAUNCHER'
#!/bin/sh
# pqc-secrets — FIPS 203 secrets CLI installed by `ainish-coder --pqc-install`.
# Resolves the canonical engine from AINISH_PQC_ENGINE, AINISH_PQC_ROOT, or the
# recorded root marker, so any tool can call it from any directory.
set -u
root="${AINISH_PQC_ROOT:-}"
if [ -z "$root" ] && [ -f "$HOME/.config/ainish-coder/pqc-root" ]; then
    root="$(sed -n '1p' "$HOME/.config/ainish-coder/pqc-root" | tr -d '\r')"
fi
if [ -n "$root" ] && command -v cygpath >/dev/null 2>&1; then
    root="$(cygpath -u "$root" 2>/dev/null || printf '%s' "$root")"
fi
engine="${AINISH_PQC_ENGINE:-${root}/.agents/skills/pqc-secrets/scripts/pqc_secrets.py}"
if [ ! -f "$engine" ]; then
    printf 'pqc-secrets: engine not found at %s\n' "$engine" >&2
    printf 'hint: re-run "ainish-coder --pqc-install" or set AINISH_PQC_ROOT\n' >&2
    exit 1
fi
export PQC_USE_KEYCHAIN="${PQC_USE_KEYCHAIN:-false}"
if command -v uv >/dev/null 2>&1; then
    exec uv run --quiet "$engine" "$@"
fi
exec python3 "$engine" "$@"
LAUNCHER
}

_pqc_launcher_cmd_body() {
    cat <<'CMD'
@echo off
setlocal
set "ENGINE=%AINISH_PQC_ENGINE%"
set "ROOT=%AINISH_PQC_ROOT%"
if not defined ROOT if exist "%USERPROFILE%\.config\ainish-coder\pqc-root" for /f "usebackq delims=" %%r in ("%USERPROFILE%\.config\ainish-coder\pqc-root") do set "ROOT=%%r"
if not defined ENGINE if defined ROOT set "ENGINE=%ROOT%\.agents\skills\pqc-secrets\scripts\pqc_secrets.py"
if not exist "%ENGINE%" (
    echo pqc-secrets: engine not found - run "ainish-coder --pqc-install" 1>&2
    exit /b 1
)
uv run --quiet "%ENGINE%" %*
exit /b %ERRORLEVEL%
CMD
}

# Install the launcher + marker. Echoes the launcher path; returns nonzero when
# the write failed. Never touches an existing launcher's contents blindly — it is
# rewritten because it is a generated artifact with a stable marker line.
_pqc_install_launcher() {
    local bin_dir="${HOME}/.local/bin"
    local launcher="${bin_dir}/pqc-secrets"
    safe_mkdir "$bin_dir" || return 1

    _pqc_launcher_body > "$launcher" || return 1
    chmod 0755 "$launcher" 2>/dev/null || true

    if declare -F ainish_is_windows >/dev/null 2>&1 && ainish_is_windows; then
        _pqc_launcher_cmd_body > "${bin_dir}/pqc-secrets.cmd" || return 1
    fi

    local native_root
    native_root="$(_pqc_native_path "$REPO_DIR")"
    safe_mkdir "$(_pqc_config_dir)" || return 1
    printf '%s\n' "$native_root" > "$(_pqc_marker_file)" || return 1

    printf '%s\n' "$launcher"
}

_pqc_on_path() {
    case ":${PATH}:" in
        *":${HOME}/.local/bin:"*) printf 'true' ;;
        *) printf 'false' ;;
    esac
}

# WSL view of this checkout (/d/Code/x -> /mnt/d/Code/x). Used to provision the
# other OS with the same command instead of asking the operator to repeat it.
_pqc_wsl_repo_root() {
    local posix
    posix="$(ainish_posix_path "$REPO_DIR" 2>/dev/null || printf '%s' "$REPO_DIR")"
    case "$posix" in
        /mnt/*) printf '%s\n' "$posix" ;;
        /[A-Za-z]/*)
            printf '/mnt/%s%s\n' \
                "$(printf '%s' "${posix:1:1}" | tr 'A-Z' 'a-z')" \
                "${posix:2}"
            ;;
        *) printf '%s\n' "$posix" ;;
    esac
}

_pqc_first_wsl_distro() {
    command -v wsl.exe >/dev/null 2>&1 || return 1
    local distro
    while IFS= read -r distro; do
        distro="$(printf '%s' "$distro" | tr -d '\000\r[:space:]')"
        [[ -n "$distro" ]] || continue
        case "$distro" in docker-desktop*) continue ;; esac
        printf '%s\n' "$distro"
        return 0
    done < <(wsl.exe -l -q 2>/dev/null)
    return 1
}

# Provision the WSL side by re-running this command there. Returns a one-line
# detail on stdout; nonzero when WSL is absent or the call failed. An existing
# working launcher is never overwritten — the WSL checkout may legitimately be a
# different clone, and silently repointing it would be a store surprise.
_pqc_wsl_install() {
    declare -F ainish_is_windows >/dev/null 2>&1 && ainish_is_windows || return 1
    local distro root
    distro="$(_pqc_first_wsl_distro)" || return 1

    local probe
    probe="$(wsl.exe -d "$distro" -e bash -lc 'command -v pqc-secrets >/dev/null 2>&1 && pqc-secrets store --json' 2>/dev/null || true)"
    if [[ "$probe" == *'"bundle"'* ]]; then
        local present_store
        present_store="$(printf '%s' "$probe" | _pqc_json_field store)"
        printf 'present in %s (%s)\n' "$distro" "${present_store:-unknown}"
        return 0
    fi

    root="$(_pqc_wsl_repo_root)"
    local output
    output="$(wsl.exe -d "$distro" -e bash -lc "cd '${root}' && ./bin/ainish-coder --pqc-install --json --no-wsl" 2>/dev/null || true)"
    if [[ "$output" == *'"ok": true'* || "$output" == *'"ok":true'* ]]; then
        printf 'installed in %s (%s)\n' "$distro" "$root"
        return 0
    fi
    printf 'not provisioned in %s (run: wsl -d %s -- bash -lc "cd %s && ./bin/ainish-coder --pqc-install")\n' "$distro" "$distro" "$root"
    return 1
}

# ── --pqc-install ────────────────────────────────────────────────────────────
pqc_install() {
    local json="false" wsl="true" arg
    for arg in "$@"; do
        case "$arg" in
            --json) json="true" ;;
            --no-wsl) wsl="false" ;;
            --wsl) wsl="true" ;;
        esac
    done

    local engine sha launcher="" launcher_state="installed" on_path="false"
    engine="$(_pqc_engine)" || {
        print_error "Cannot install: engine missing at ${REPO_DIR}/${_PQC_ENGINE_REL}"
        return 1
    }
    sha="$(_pqc_engine_sha)"

    if ! launcher="$(_pqc_install_launcher)"; then
        launcher_state="failed"
    fi
    on_path="$(_pqc_on_path)"

    # Generate the machine identity only when no bundle resolves. `store --json`
    # reports bundleExists without decrypting anything.
    local store_json exists key_count store_path store_source keygen="skipped"
    store_json="$(_pqc_store_json)"
    exists="$(printf '%s' "$store_json" | _pqc_json_scalar bundleExists)"
    if [[ -z "$exists" ]]; then
        print_error "Cannot read the PQC store (engine probe failed)."
        return 1
    fi
    if [[ "$exists" != "true" ]]; then
        if _pqc_run_engine keygen >/dev/null 2>&1; then
            keygen="generated"
            store_json="$(_pqc_store_json)"
            exists="$(printf '%s' "$store_json" | _pqc_json_scalar bundleExists)"
        else
            keygen="failed"
        fi
    fi
    key_count="$(printf '%s' "$store_json" | _pqc_json_scalar keyCount)"
    store_path="$(printf '%s' "$store_json" | _pqc_json_field store)"
    store_source="$(printf '%s' "$store_json" | _pqc_json_field source)"

    local wsl_ok="false" wsl_detail="skipped"
    if [[ "$wsl" == "true" ]]; then
        wsl_detail="$(_pqc_wsl_install 2>/dev/null || printf 'not provisioned')"
        [[ "$wsl_detail" == installed* ]] && wsl_ok="true"
    fi

    local ok="true"
    [[ "$launcher_state" == "installed" && "$exists" == "true" && "$keygen" != "failed" ]] || ok="false"

    if [[ "$json" == "true" ]]; then
        printf '{\n'
        printf '  "format": "ainish-coder/pqc-install/v1",\n'
        printf '  "ok": %s,\n' "$ok"
        printf '  "root": "%s",\n' "$(_pqc_json_escape "$REPO_DIR")"
        printf '  "engine": {"path": "%s", "sha256": "%s"},\n' "$(_pqc_json_escape "$engine")" "$sha"
        printf '  "launcher": {"path": "%s", "state": "%s", "onPath": %s},\n' "$(_pqc_json_escape "$launcher")" "$launcher_state" "$on_path"
        printf '  "store": %s,\n' "${store_json:-null}"
        printf '  "keygen": "%s",\n' "$keygen"
        printf '  "wsl": {"attempted": %s, "ok": %s, "detail": "%s"}\n' "$wsl" "$wsl_ok" "$(_pqc_json_escape "$wsl_detail")"
        printf '}\n'
    else
        print_header "🔐 PQC secrets — installed for every tool"
        echo "  engine:    ${engine}"
        echo "  sha256:    $(_pqc_head_sha "$sha")…"
        echo "  launcher:  ${launcher:-<failed>} (on PATH: ${on_path})"
        echo "  store:     ${store_path:-unknown} (${store_source:-?})"
        echo "  bundle:    ${exists} · ${key_count:-0} key(s) · keygen ${keygen}"
        if [[ "$wsl" == "true" ]]; then
            echo "  wsl:       ${wsl_detail}"
        fi
        if [[ "$on_path" != "true" ]]; then
            print_warning "~/.local/bin is not on PATH — add it so every tool finds 'pqc-secrets'."
        fi
        if [[ "$ok" != "true" ]]; then
            print_error "PQC install is incomplete — see the fields above."
        else
            print_success "Done. Any tool can now run: pqc-secrets list|export|set|store"
        fi
    fi

    [[ "$ok" == "true" ]]
}

# ── --pqc-status ─────────────────────────────────────────────────────────────
_pqc_target_line() {
    local target="$1"
    local engine="${target}/${_PQC_ENGINE_REL}"
    local state="missing" selection="unknown" sha=""

    if declare -F skills_selection_state >/dev/null 2>&1 && [[ -d "$target" ]]; then
        selection="$(skills_selection_state "$target" pqc-secrets 2>/dev/null || printf 'unknown')"
    fi

    if [[ ! -d "$target" ]]; then
        state="unreachable"
    elif [[ ! -f "$engine" ]]; then
        state="missing"
    else
        sha="$(_calc_sha256 "$engine" 2>/dev/null | tr -d '[:space:]' | tr 'A-F' 'a-f')"
        if [[ "$sha" == "$(_pqc_engine_sha)" ]]; then
            state="current"
        else
            state="stale"
        fi
    fi

    printf '%s\t%s\t%s\n' "$state" "$selection" "$sha"
}

pqc_status() {
    local json="false" wsl="true" arg
    for arg in "$@"; do
        case "$arg" in
            --json) json="true" ;;
            --no-wsl) wsl="false" ;;
            --wsl) wsl="true" ;;
        esac
    done

    local engine sha build launcher on_path native_store wsl_store="" wsl_detail="skipped"
    engine="$(_pqc_engine)" || {
        print_error "PQC engine missing: ${REPO_DIR}/${_PQC_ENGINE_REL}"
        return 1
    }
    sha="$(_pqc_engine_sha)"
    build="$(_pqc_run_engine version 2>/dev/null | sed -n 's/^build date:[[:space:]]*//p' | head -n 1)"
    launcher="${HOME}/.local/bin/pqc-secrets"
    [[ -f "$launcher" ]] || launcher=""
    on_path="$(_pqc_on_path)"
    native_store="$(_pqc_store_json)"

    if [[ "$wsl" == "true" ]] && declare -F ainish_is_windows >/dev/null 2>&1 && ainish_is_windows; then
        local distro root
        if distro="$(_pqc_first_wsl_distro)" && root="$(_pqc_wsl_repo_root)"; then
            wsl_store="$(wsl.exe -d "$distro" -e bash -lc "cd '${root}' && uv run --quiet '${root}/${_PQC_ENGINE_REL}' store --json" 2>/dev/null || true)"
            if [[ "$wsl_store" == *'"bundle"'* ]]; then
                wsl_detail="ok (${distro})"
            else
                wsl_detail="unreachable (${distro})"
                wsl_store=""
            fi
        else
            wsl_detail="no distro"
        fi
    fi

    local registry targets_json="" total=0 current=0 stale=0 missing=0 missing_required=0 deselected=0 unreachable=0
    registry="$(_pqc_config_dir)/targets.txt"
    if [[ -f "$registry" ]]; then
        while IFS= read -r target; do
            target="$(printf '%s' "$target" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
            [[ -n "$target" ]] || continue
            target="$(ainish_posix_path "$target" 2>/dev/null || printf '%s' "$target")"
            local line state selection tsha
            line="$(_pqc_target_line "$target")"
            state="$(printf '%s' "$line" | cut -f1)"
            selection="$(printf '%s' "$line" | cut -f2)"
            tsha="$(printf '%s' "$line" | cut -f3)"

            total=$((total + 1))
            case "$state" in
                current) current=$((current + 1)) ;;
                stale) stale=$((stale + 1)) ;;
                missing) missing=$((missing + 1)); [[ "$selection" != "off" ]] && missing_required=$((missing_required + 1)) ;;
                unreachable) unreachable=$((unreachable + 1)) ;;
            esac
            [[ "$selection" == "off" ]] && deselected=$((deselected + 1))

            [[ -n "$targets_json" ]] && targets_json="${targets_json},"
            targets_json="${targets_json}{\"dir\": \"$(_pqc_json_escape "$target")\", \"state\": \"${state}\", \"selection\": \"${selection}\", \"engineSha256\": \"${tsha}\"}"
        done < "$registry"
    fi

    if [[ "$json" == "true" ]]; then
        printf '{\n'
        printf '  "format": "ainish-coder/pqc-status/v1",\n'
        printf '  "root": "%s",\n' "$(_pqc_json_escape "$REPO_DIR")"
        printf '  "platform": "%s",\n' "$(_pqc_platform)"
        printf '  "engine": {"path": "%s", "sha256": "%s", "build": "%s"},\n' "$(_pqc_json_escape "$engine")" "$sha" "$(_pqc_json_escape "$build")"
        printf '  "launcher": {"path": "%s", "installed": %s, "onPath": %s},\n' "$(_pqc_json_escape "$launcher")" "$([[ -n "$launcher" ]] && printf true || printf false)" "$on_path"
        printf '  "native": %s,\n' "${native_store:-null}"
        printf '  "wsl": {"attempted": %s, "detail": "%s", "store": %s},\n' "$wsl" "$(_pqc_json_escape "$wsl_detail")" "${wsl_store:-null}"
        printf '  "targets": [%s],\n' "$targets_json"
        printf '  "summary": {"total": %s, "current": %s, "stale": %s, "missing": %s, "missingRequired": %s, "deselected": %s, "unreachable": %s}\n' \
            "$total" "$current" "$stale" "$missing" "$missing_required" "$deselected" "$unreachable"
        printf '}\n'
    else
        print_header "🔐 PQC secrets — store & distribution status"
        echo "  platform:  $(_pqc_platform)"
        echo "  engine:    $(_pqc_head_sha "$sha")… ${build:+(${build})}"
        echo "  launcher:  ${launcher:-<not installed>} (on PATH: ${on_path})"
        echo "  native:    $(printf '%s' "$native_store" | _pqc_json_field store) [$(printf '%s' "$native_store" | _pqc_json_field source)] bundle=$(printf '%s' "$native_store" | _pqc_json_scalar bundleExists) keys=$(printf '%s' "$native_store" | _pqc_json_scalar keyCount)"
        if [[ "$wsl" == "true" ]]; then
            echo "  wsl:       ${wsl_detail}"
            [[ -n "$wsl_store" ]] && echo "             $(printf '%s' "$wsl_store" | _pqc_json_field store) [$(printf '%s' "$wsl_store" | _pqc_json_field source)] keys=$(printf '%s' "$wsl_store" | _pqc_json_scalar keyCount)"
        fi
        echo "  targets:   ${total} enrolled · ${current} current · ${stale} stale · ${missing} missing · ${deselected} deselected"
        if [[ -f "$registry" ]]; then
            while IFS= read -r target; do
                target="$(printf '%s' "$target" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
                [[ -n "$target" ]] || continue
                target="$(ainish_posix_path "$target" 2>/dev/null || printf '%s' "$target")"
                local line state selection
                line="$(_pqc_target_line "$target")"
                state="$(printf '%s' "$line" | cut -f1)"
                selection="$(printf '%s' "$line" | cut -f2)"
                case "$state" in
                    current) printf '             %s✓%s %s (selection %s)\n' "$GREEN" "$RESET" "$target" "$selection" ;;
                    stale) printf '             %s!%s %s — stale engine (run --pqc-sync-targets)\n' "$YELLOW" "$RESET" "$target" ;;
                    missing) printf '             %s-%s %s — no vendored engine\n' "$YELLOW" "$RESET" "$target" ;;
                    *) printf '             %s?%s %s — %s\n' "$RED" "$RESET" "$target" "$state" ;;
                esac
            done < "$registry"
        fi
    fi

    [[ "$stale" -eq 0 && "$missing_required" -eq 0 ]] || return 1
    return 0
}

# ── --pqc-sync-targets ───────────────────────────────────────────────────────
pqc_sync_targets() {
    local json="false" dry_run="false" all="false" only=""
    local args=() arg
    for arg in "$@"; do
        case "$arg" in
            --json) json="true" ;;
            --dry-run) dry_run="true" ;;
            --all) all="true" ;;
            --*) ;;
            *) args+=("$arg") ;;
        esac
    done
    if (( ${#args[@]} > 0 )); then
        only="${args[0]}"
        all="false"
    elif [[ "$all" != "true" ]]; then
        all="true"
    fi

    local registry targets=()
    registry="$(_pqc_config_dir)/targets.txt"
    if [[ -n "$only" ]]; then
        targets+=("$(ainish_posix_path "$only" 2>/dev/null || printf '%s' "$only")")
    elif [[ -f "$registry" ]]; then
        while IFS= read -r line; do
            line="$(printf '%s' "$line" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
            [[ -n "$line" ]] || continue
            targets+=("$(ainish_posix_path "$line" 2>/dev/null || printf '%s' "$line")")
        done < "$registry"
    fi

    if (( ${#targets[@]} == 0 )); then
        if [[ "$json" == "true" ]]; then
            printf '{"format": "ainish-coder/pqc-sync/v1", "source": "%s", "dryRun": %s, "targets": [], "summary": {"total": 0, "synced": 0, "current": 0, "deselected": 0, "failed": 0, "missing": 0}}\n' \
                "$(_pqc_json_escape "$REPO_DIR")" "$dry_run"
        else
            print_info "No enrolled targets. Run 'ainish-coder --rules <dir>' in a repo first."
        fi
        return 0
    fi

    local source_sha targets_json="" total=0 synced=0 current=0 deselected=0 failed=0 missing_n=0
    source_sha="$(_pqc_engine_sha)"

    for target in "${targets[@]}"; do
        local state="pending" note=""
        total=$((total + 1))

        if [[ ! -d "$target" ]]; then
            state="missing"
            missing_n=$((missing_n + 1))
        elif [[ "$target" == "$REPO_DIR" ]]; then
            state="source"
            note="source checkout"
        elif [[ "$(skills_selection_state "$target" pqc-secrets 2>/dev/null || printf 'on')" != "on" ]]; then
            state="deselected"
            deselected=$((deselected + 1))
            note="pqc-secrets is off for this repo"
        else
            local target_engine="${target}/${_PQC_ENGINE_REL}"
            local target_sha=""
            [[ -f "$target_engine" ]] && target_sha="$(_calc_sha256 "$target_engine" 2>/dev/null | tr -d '[:space:]' | tr 'A-F' 'a-f')"

            if [[ "$target_sha" == "$source_sha" ]]; then
                state="current"
                current=$((current + 1))
            elif [[ "$dry_run" == "true" ]]; then
                state="would-sync"
            else
                local skill_src="${REPO_DIR}/.agents/skills/pqc-secrets"
                local skill_dst="${target}/.agents/skills/pqc-secrets"
                if safe_mkdir "${target}/.agents/skills" \
                    && rm -rf "$skill_dst" \
                    && cp -a "$skill_src" "$skill_dst" 2>/dev/null; then
                    # Keep the repo-relative launchers in step when the target
                    # ships a bin/ directory (that is how tools invoke them).
                    if [[ -d "${target}/bin" ]]; then
                        cp -a "${REPO_DIR}/${_PQC_LAUNCHER_REL}" "${target}/${_PQC_LAUNCHER_REL}" 2>/dev/null || true
                        if [[ -f "${REPO_DIR}/${_PQC_LAUNCHER_REL}.cmd" ]]; then
                            cp -a "${REPO_DIR}/${_PQC_LAUNCHER_REL}.cmd" "${target}/${_PQC_LAUNCHER_REL}.cmd" 2>/dev/null || true
                        fi
                    fi
                    local after_sha
                    after_sha="$(_calc_sha256 "$target_engine" 2>/dev/null | tr -d '[:space:]' | tr 'A-F' 'a-f')"
                    if [[ "$after_sha" == "$source_sha" ]]; then
                        state="synced"
                        synced=$((synced + 1))
                    else
                        state="failed"
                        failed=$((failed + 1))
                        note="digest mismatch after copy"
                    fi
                else
                    state="failed"
                    failed=$((failed + 1))
                    note="copy failed"
                fi
            fi
        fi

        [[ -n "$targets_json" ]] && targets_json="${targets_json},"
        targets_json="${targets_json}{\"dir\": \"$(_pqc_json_escape "$target")\", \"state\": \"${state}\", \"note\": \"$(_pqc_json_escape "$note")\"}"

        if [[ "$json" != "true" ]]; then
            case "$state" in
                synced) printf '  %s✓%s synced   %s\n' "$GREEN" "$RESET" "$target" ;;
                current) printf '  %s=%s current  %s\n' "$GREEN" "$RESET" "$target" ;;
                "would-sync") printf '  %s→%s would sync %s\n' "$YELLOW" "$RESET" "$target" ;;
                source) printf '  %s·%s source   %s\n' "$BLUE" "$RESET" "$target" ;;
                deselected) printf '  %s⊘%s skipped  %s (%s)\n' "$YELLOW" "$RESET" "$target" "$note" ;;
                missing) printf '  %s!%s missing  %s\n' "$RED" "$RESET" "$target" ;;
                *) printf '  %s✗%s %s   %s (%s)\n' "$RED" "$RESET" "$state" "$target" "$note" ;;
            esac
        fi
    done

    if [[ "$json" == "true" ]]; then
        printf '{\n'
        printf '  "format": "ainish-coder/pqc-sync/v1",\n'
        printf '  "source": "%s",\n' "$(_pqc_json_escape "$REPO_DIR")"
        printf '  "sourceSha256": "%s",\n' "$source_sha"
        printf '  "dryRun": %s,\n' "$dry_run"
        printf '  "targets": [%s],\n' "$targets_json"
        printf '  "summary": {"total": %s, "synced": %s, "current": %s, "deselected": %s, "failed": %s, "missing": %s}\n' \
            "$total" "$synced" "$current" "$deselected" "$failed" "$missing_n"
        printf '}\n'
    else
        echo ""
        echo "  ${total} target(s) · ${synced} synced · ${current} current · ${deselected} deselected · ${failed} failed"
    fi

    [[ "$failed" -eq 0 ]]
}
