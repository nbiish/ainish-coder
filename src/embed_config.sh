#!/bin/bash
# MOLECULE: Embedding provider configuration
# Lets an operator switch ainish-rag from the local llama server to a remote, API-based
# embedding model (any OpenAI-compatible /embeddings endpoint) — and back — without
# touching code. Writes non-secret settings to .agents/rag/embed-provider.json; the API
# key is NEVER persisted (resolved from AINISH_EMBED_API_KEY / PQC vault at runtime).
#
#   ainish-coder --embed-config --provider api --api-base URL --model NAME [--dim N] [DIR]
#   ainish-coder --embed-config --provider local [DIR]     # revert to the local llama server
#   ainish-coder --embed-config --status                   # show active provider
#
# When a remote provider is active, ainish-rag skips spawning llama entirely, which
# eliminates its multi-GB resident footprint.

embed_config_file() {
    local target_dir="${1:-.}"
    printf '%s\n' "${target_dir}/.agents/rag/embed-provider.json"
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
        echo -e "  Dim:       ${dim:-<from model>}"
        echo -e "  Key:       ${GREEN}resolved at runtime${RESET} (AINISH_EMBED_API_KEY — never stored on disk)"
        if [[ -z "$api_base" || -z "$model" ]]; then
            echo -e "  ${RED}⚠ Incomplete: api-base and model are required for API mode${RESET}"
            return 1
        fi
        echo -e "  ${GREEN}Local llama server: SKIPPED (no resident embedding server)${RESET}"
    else
        echo -e "  Local llama server: used (sized by --max-mem / AINISH_RAG_CTX)"
    fi
    return 0
}

embed_config() {
    local provider="local" api_base="" model="" dim="" target_dir="."
    local show_status=false
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
    mkdir -p "$(dirname "$manifest")" 2>/dev/null || return 1

    case "$(echo "$provider" | tr '[:upper:]' '[:lower:]')" in
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
            echo -e "${BRIGHT_GREEN}🖥  ainish-rag will spawn the local server (context sized by --max-mem)${RESET}"
            ;;
        *)
            print_error "Unknown provider '${provider}'. Use: api | local"
            return 1
            ;;
    esac
    return 0
}
