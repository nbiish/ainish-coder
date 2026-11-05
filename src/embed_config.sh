#!/bin/bash
# MOLECULE: Embedding provider configuration
# Lets an operator switch ainish-rag from the local llama server to a remote, API-based
# embedding model (any OpenAI-compatible /embeddings endpoint) — and back — without
# touching code. Writes non-secret settings to .agents/rag/embed-provider.json; the API
# key is NEVER persisted (resolved from AINISH_EMBED_API_KEY / PQC vault at runtime).
#
#   ainish-coder --embed-config --provider api --api-base URL --model NAME [--dim N] [DIR]
#   ainish-coder --embed-config --provider local [DIR]     # revert to the local llama server
#   ainish-coder --embed-config --status                   # show active + detected provider
#   ainish-coder --embed-config --detect [--json] [--write]  # env/PQC auto-detection
#   ainish-coder --embed-config --clear                    # remove persisted provider config
#
# Detection consults the environment and the PQC secrets store for OpenRouter/ZenMux embedding
# credentials (AINISH_EMBED_API_KEY, LOCALROUTER_OPENROUTER_API_KEY, ZENMUX_API_KEY, …). When a
# remote provider is active, ainish-rag skips spawning llama entirely — no multi-GB resident
# model — and stops any model left resident by an earlier run.

embed_config_file() {
    local target_dir="${1:-.}"
    printf '%s\n' "${target_dir}/.agents/rag/embed-provider.json"
}

embed_config_rag_bin() {
    local candidate="${SCRIPT_DIR:-}/ainish-rag"
    if [[ -n "${SCRIPT_DIR:-}" && -x "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
    printf '%s\n' "${here}/bin/ainish-rag"
}

_embed_config_set() {
    local f="$1" key="$2" val="$3"
    # upsert a JSON string field in-place with sed (file is machine-written, one key/line).
    if grep -q "\"${key}\"" "$f" 2>/dev/null; then
        sed -i.bak "s|\"${key}\": *\"[^\"]*\"|\"${key}\": \"${val}\"|" "$f" && rm -f "${f}.bak"
    else
        local tmp="${f}.tmp.$$"
        awk -v k="$key" -v v="$val" '
            /}/ && !done { printf "  \"%s\": \"%s\"\n", k, v; done=1 }
            { print }
        ' "$f" > "$tmp" && mv "$tmp" "$f"
    fi
}

# Runs `ainish-rag embed-provider` inside the target repo so the engine resolves the canonical
# root (and therefore the target's .agents/rag/embed-provider.json) rather than the caller's.
embed_config_delegate() {
    local target_dir="$1"; shift
    local rag_bin
    rag_bin="$(embed_config_rag_bin)"
    if [[ ! -x "$rag_bin" ]]; then
        print_warning "ainish-rag engine not found at ${rag_bin} — cannot inspect the embedding provider"
        return 1
    fi
    if command -v timeout >/dev/null 2>&1; then
        ( cd "$target_dir" && timeout 20 "$rag_bin" embed-provider "$@" )
        return $?
    fi

    local python
    python="$(ainish_python 2>/dev/null || true)"
    [[ -n "$python" ]] || {
        print_warning "A working Python 3 interpreter is required for bounded embedding-provider detection"
        return 1
    }
    (
        cd "$target_dir" || exit 1
        "$python" -c '
import subprocess
import sys
try:
    completed = subprocess.run(sys.argv[1:], timeout=20)
except subprocess.TimeoutExpired:
    raise SystemExit(124)
raise SystemExit(completed.returncode)
' "$rag_bin" embed-provider "$@"
    )
}

# Extracts a top-level string field from the engine's pretty JSON report.
_embed_config_json_field() {
    local json="$1" field="$2"
    printf '%s\n' "$json" | sed -n "s/.*\"${field}\": *\"\\([^\"]*\\)\".*/\\1/p" | head -1
}

# `ainish-coder --rules` step: detect PQC/environment embedding credentials for OpenRouter or
# ZenMux and pin the non-secret provider config. Auto-detection that finds nothing writes
# nothing, so a key added later is still picked up.
deploy_embed_provider_detect() {
    local target_dir="${1:-.}"
    mkdir -p "${target_dir}/.agents/rag" 2>/dev/null || true

    local out
    if ! out="$(embed_config_delegate "$target_dir" --write --json 2>/dev/null)"; then
        print_warning "Embedding provider detection unavailable (RAG engine missing) — local embeddings remain in use"
        return 0
    fi

    local provider provider_id model source
    provider="$(_embed_config_json_field "$out" provider)"
    provider_id="$(_embed_config_json_field "$out" provider_id)"
    model="$(_embed_config_json_field "$out" model)"
    source="$(_embed_config_json_field "$out" source)"

    if [[ "$provider" == "api" ]]; then
        echo -e "${GREEN}✓ Remote embeddings detected: ${provider_id:-custom} (${model:-model unset}), source: ${source}${RESET}"
        echo -e "  ${YELLOW}↻ Local llama is never spawned in API mode; run 'ainish-rag index --rebuild' to rebuild vectors with this model${RESET}"
        echo -e "  ${GREEN}✓ Memory: no resident embedding model is left behind after commands${RESET}"
    elif [[ "$provider" == "invalid" ]]; then
        print_warning "Embedding API intent is incomplete — run: ainish-coder --embed-config --detect"
    else
        echo -e "  ${YELLOW}No OpenRouter/ZenMux embedding key found in env or PQC store; local llama embeddings remain active${RESET}"
    fi
    return 0
}

embed_config_status() {
    local target_dir="${1:-.}"
    local f
    f="$(embed_config_file "$target_dir")"
    local provider api_base model dim
    # `|| true`: sed returns 2 for a missing file and `set -euo pipefail` would abort the
    # launcher on the bare assignment.
    provider="$(sed -n 's/.*"provider": *"\([^"]*\)".*/\1/p' "$f" 2>/dev/null | head -1 || true)"
    api_base="$(sed -n 's/.*"api_base": *"\([^"]*\)".*/\1/p' "$f" 2>/dev/null | head -1 || true)"
    model="$(sed -n 's/.*"model": *"\([^"]*\)".*/\1/p' "$f" 2>/dev/null | head -1 || true)"
    dim="$(sed -n 's/.*"dim": *\([0-9]*\).*/\1/p' "$f" 2>/dev/null | head -1 || true)"
    provider="${provider:-local}"

    echo -e "${BRIGHT_BLUE}ainish-rag Embedding Provider${RESET}"
    echo -e "  Config:    ${f}"
    echo -e "  Provider:  ${provider}"
    if [[ "$provider" == "api" ]]; then
        echo -e "  API Base:  ${api_base:-<unset>}"
        echo -e "  Model:     ${model:-<unset>}"
        echo -e "  Dim:       ${dim:-768 (store width; the native model width is wider)}"
        echo -e "  Key:       ${GREEN}resolved at runtime${RESET} (environment or PQC store — never stored on disk)"
        if [[ -z "$api_base" || -z "$model" ]]; then
            echo -e "  ${RED}⚠ Incomplete: api-base and model are required for API mode${RESET}"
            return 1
        fi
        echo -e "  ${GREEN}Local llama server: SKIPPED (no resident embedding server)${RESET}"
    else
        echo -e "  Local llama server: used on demand, then stopped (override with --keep-server)"
    fi

    local det dep dip dm dsrc
    det="$(embed_config_delegate "$target_dir" --json 2>/dev/null || true)"
    if [[ -n "$det" ]]; then
        dep="$(_embed_config_json_field "$det" provider)"
        dip="$(_embed_config_json_field "$det" provider_id)"
        dm="$(_embed_config_json_field "$det" model)"
        dsrc="$(_embed_config_json_field "$det" source)"
        echo -e "  Detected:  ${dep:-unknown}${dip:+ (${dip})}${dm:+ model=${dm}}${dsrc:+ source=${dsrc}}  ${GREEN}[env + PQC auto-detection]${RESET}"
    fi
    return 0
}

embed_config() {
    local provider="local" api_base="" model="" dim="" target_dir="."
    local show_status=false detect=false json_out=false write=false clear=false
    local a
    # Two passes: collect every option/positional first so `--status DIR` works in any order.
    while [[ $# -gt 0 ]]; do
        a="$1"; shift
        case "$a" in
            --provider) provider="${1:-local}"; shift || true ;;
            --api-base) api_base="${1:-}"; shift || true ;;
            --model)    model="${1:-}"; shift || true ;;
            --dim)      dim="${1:-}"; shift || true ;;
            --status)   show_status=true ;;
            --detect)   detect=true ;;
            --json)     json_out=true ;;
            --write)    write=true ;;
            --clear)    clear=true ;;
            -*)         echo -e "${YELLOW}Unknown option: $a${RESET}" >&2 ;;
            *)          target_dir="$a" ;;
        esac
    done

    if [[ "$show_status" == "true" ]]; then
        embed_config_status "$target_dir"
        return $?
    fi

    validate_target_dir "$target_dir" || return 1
    local manifest
    manifest="$(embed_config_file "$target_dir")"

    if [[ "$clear" == "true" ]]; then
        local removed=false
        if [[ -f "$manifest" ]]; then
            rm -f "$manifest"
            removed=true
        fi
        if [[ "$removed" == "true" ]]; then
            echo -e "${GREEN}✓ Removed ${manifest} — embeddings fall back to env/PQC auto-detection${RESET}"
        else
            echo -e "  No persisted embedding provider config at ${manifest}"
        fi
        return 0
    fi

    local normalized
    normalized="$(echo "$provider" | tr '[:upper:]' '[:lower:]')"

    # Explicit provider ids, `auto`, and API mode without a base/model are resolved by the
    # engine (which owns the PQC key resolution and catalog defaults).
    if [[ "$detect" == "true" ]]; then
        local args=()
        [[ "$write" == "true" ]] && args+=(--write)
        [[ "$json_out" == "true" ]] && args+=(--json)
        embed_config_delegate "$target_dir" ${args[@]+"${args[@]}"}
        return $?
    fi

    if [[ "$normalized" == "auto" || "$normalized" == "openrouter" || "$normalized" == "zenmux" ]]; then
        embed_config_delegate "$target_dir" --provider "$normalized" --write
        return $?
    fi

    if [[ "$normalized" == "api" && ( -z "$api_base" || -z "$model" ) ]]; then
        echo -e "${YELLOW}ℹ Resolving API base/model from environment + PQC detection...${RESET}"
        embed_config_delegate "$target_dir" --provider api --write
        return $?
    fi

    mkdir -p "$(dirname "$manifest")" 2>/dev/null || return 1

    case "$normalized" in
        api|openai|remote)
            if [[ -z "$api_base" || -z "$model" ]]; then
                print_error "--embed-config --provider api requires --api-base <url> and --model <name>"
                return 1
            fi
            cat > "$manifest" <<CFG_EOF
{
  "format": "ainish-rag/embed-provider/v1",
  "provider": "api",
  "api_base": "${api_base}",
  "model": "${model}",
  "dim": ${dim:-null},
  "key_source": "AINISH_EMBED_API_KEY",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
CFG_EOF
            echo -e "${GREEN}✓ API embedding provider configured → ${manifest}${RESET}"
            echo -e "${BRIGHT_GREEN}🌐 ainish-rag will now embed via ${api_base} (model ${model}) — no local llama server${RESET}"
            echo -e "${YELLOW}🔑 Set the key in your shell/vault: AINISH_EMBED_API_KEY (it is never written to disk)${RESET}"
            if [[ -n "$dim" ]]; then
                echo -e "${YELLOW}⚠ Dim=${dim} must match your existing LanceDB store; re-run 'ainish-coder --rag index' if it differs from the old model${RESET}"
            fi
            ;;
        local|llama|none|"")
            cat > "$manifest" <<CFG_EOF
{
  "format": "ainish-rag/embed-provider/v1",
  "provider": "local",
  "api_base": "",
  "model": "",
  "dim": null,
  "key_source": null,
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
CFG_EOF
            echo -e "${GREEN}✓ Local llama embedding provider restored → ${manifest}${RESET}"
            echo -e "${BRIGHT_GREEN}🖥  ainish-rag will spawn the local server on demand and stop it after the command${RESET}"
            ;;
        *)
            print_error "Unknown provider '${provider}'. Use: api | local | auto | openrouter | zenmux"
            return 1
            ;;
    esac
    return 0
}
