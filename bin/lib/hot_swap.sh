#!/usr/bin/env bash
# Hot-swap config files for agentic coding tools
# Source this file, then call: hot_swap_<tool> <provider>
# Each function backs up the tool's config, rewrites it for the provider,
# and registers a trap to restore the original on exit.
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/providers.sh"

# ─── Shared helpers ───────────────────────────────────────────────────────────

# Track which tools have been swapped so we only restore once
_AINISH_SWAPPED_TOOLS=()

# Restore all swapped configs (called via EXIT trap)
_ainish_restore_all() {
  for tool in "${_AINISH_SWAPPED_TOOLS[@]}"; do
    case "$tool" in
      mini)  _ainish_restore_mini ;;
      pi)    _ainish_restore_pi ;;
      qwen)  _ainish_restore_qwen ;;
      codex) _ainish_restore_codex ;;
    esac
  done
  _AINISH_SWAPPED_TOOLS=()
}

# Register the exit trap once
_ainish_ensure_trap() {
  if [[ -z "${_AINISH_TRAP_SET:-}" ]]; then
    trap _ainish_restore_all EXIT
    _AINISH_TRAP_SET=1
  fi
}

# ─── mini (mini-swe-agent) ───────────────────────────────────────────────────
# Config: ~/.config/mini-swe-agent/.env
# Reads: OPENAI_API_BASE, OPENAI_API_KEY, MSWEA_MODEL_NAME

MINI_ENV_FILE="${HOME}/.config/mini-swe-agent/.env"
MINI_ENV_BACKUP=""

_ainish_restore_mini() {
  if [[ -n "${MINI_ENV_BACKUP}" && -f "${MINI_ENV_BACKUP}" ]]; then
    mv "${MINI_ENV_BACKUP}" "${MINI_ENV_FILE}"
    MINI_ENV_BACKUP=""
  fi
}

hot_swap_mini() {
  local provider="${1:?provider name required}"
  provider_has "$provider" || { echo "error: unknown provider '$provider'" >&2; return 1; }

  local base_url api_key model
  base_url="$(provider_read "$provider" "baseUrl")"
  api_key="$(provider_read "$provider" "apiKey")"
  model="$(provider_read "$provider" "defaultModel")"

  # Back up original
  if [[ -z "${MINI_ENV_BACKUP}" ]]; then
    MINI_ENV_BACKUP="${MINI_ENV_FILE}.ainish-backup"
    cp "${MINI_ENV_FILE}" "${MINI_ENV_BACKUP}"
  fi

  # Rewrite .env with provider settings
  cat > "${MINI_ENV_FILE}" << ENV
MSWEA_CONFIGURED='true'
MSWEA_COST_TRACKING=ignore_errors
OPENAI_API_BASE="${base_url}"
OPENAI_API_KEY='${api_key}'
MSWEA_MODEL_NAME='openai/${model}'
ENV

  _ainish_ensure_trap
  _AINISH_SWAPPED_TOOLS+=(mini)
}

# ─── pi (pi-coding-agent) ────────────────────────────────────────────────────
# Config: ~/.pi/agent/settings.json + ~/.pi/agent/auth.json + ~/.pi/agent/models.json
# settings.json: defaultProvider, defaultModel (NO provider prefix), enabledModels (WITH prefix)
# auth.json: provider API keys
# models.json: provider definitions with baseUrl, apiKey, models list

PI_SETTINGS_FILE="${HOME}/.pi/agent/settings.json"
PI_AUTH_FILE="${HOME}/.pi/agent/auth.json"
PI_MODELS_FILE="${HOME}/.pi/agent/models.json"
PI_SETTINGS_BACKUP=""
PI_AUTH_BACKUP=""
PI_MODELS_BACKUP=""

_ainish_restore_pi() {
  if [[ -n "${PI_SETTINGS_BACKUP}" && -f "${PI_SETTINGS_BACKUP}" ]]; then
    mv "${PI_SETTINGS_BACKUP}" "${PI_SETTINGS_FILE}"
    PI_SETTINGS_BACKUP=""
  fi
  if [[ -n "${PI_AUTH_BACKUP}" && -f "${PI_AUTH_BACKUP}" ]]; then
    mv "${PI_AUTH_BACKUP}" "${PI_AUTH_FILE}"
    PI_AUTH_BACKUP=""
  fi
  if [[ -n "${PI_MODELS_BACKUP}" && -f "${PI_MODELS_BACKUP}" ]]; then
    mv "${PI_MODELS_BACKUP}" "${PI_MODELS_FILE}"
    PI_MODELS_BACKUP=""
  fi
}

hot_swap_pi() {
  local provider="${1:?provider name required}"
  provider_has "$provider" || { echo "error: unknown provider '$provider'" >&2; return 1; }

  local base_url api_key model
  base_url="$(provider_read "$provider" "baseUrl")"
  api_key="$(provider_read "$provider" "apiKey")"
  model="$(provider_read "$provider" "defaultModel")"

  # Pi's defaultModel should NOT include the provider prefix
  # (pi combines defaultProvider + defaultModel internally)
  local bare_model="${model#*/}"  # strip "provider/" prefix if present

  # Back up originals
  if [[ -z "${PI_SETTINGS_BACKUP}" ]]; then
    PI_SETTINGS_BACKUP="${PI_SETTINGS_FILE}.ainish-backup"
    cp "${PI_SETTINGS_FILE}" "${PI_SETTINGS_BACKUP}"
  fi
  if [[ -z "${PI_AUTH_BACKUP}" ]]; then
    PI_AUTH_BACKUP="${PI_AUTH_FILE}.ainish-backup"
    cp "${PI_AUTH_FILE}" "${PI_AUTH_BACKUP}"
  fi
  if [[ -z "${PI_MODELS_BACKUP}" ]]; then
    PI_MODELS_BACKUP="${PI_MODELS_FILE}.ainish-backup"
    cp "${PI_MODELS_FILE}" "${PI_MODELS_BACKUP}"
  fi

  # Rewrite settings.json — update defaultProvider and defaultModel
  python3 -c "
import sys, json
with open('${PI_SETTINGS_FILE}') as f:
    data = json.load(f)
data['defaultProvider'] = '${provider}'
data['defaultModel'] = '${bare_model}'
# Ensure the model is in enabledModels if not already
em = data.get('enabledModels', [])
model_id = '${provider}/${bare_model}'
if model_id not in em:
    em.insert(0, model_id)
data['enabledModels'] = em
with open('${PI_SETTINGS_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
"

  # Rewrite auth.json — add/update provider entry
  python3 -c "
import sys, json
with open('${PI_AUTH_FILE}') as f:
    data = json.load(f)
data['${provider}'] = {'type': 'api_key', 'key': '${api_key}'}
with open('${PI_AUTH_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
"

  # Rewrite models.json — add/update provider with baseUrl, apiKey, and model entry
  python3 -c "
import sys, json
with open('${PI_MODELS_FILE}') as f:
    data = json.load(f)
providers = data.setdefault('providers', {})
providers['${provider}'] = {
    'baseUrl': '${base_url}',
    'api': 'openai-completions',
    'apiKey': '${api_key}',
    'models': [
        {
            'id': '${bare_model}',
            'name': '${bare_model}',
            'input': ['text'],
            'contextWindow': 1000000,
            'maxTokens': 32000,
            'cost': {'input': 0.0, 'output': 0.0, 'cacheRead': 0.0, 'cacheWrite': 0.0}
        }
    ]
}
with open('${PI_MODELS_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
"

  _ainish_ensure_trap
  _AINISH_SWAPPED_TOOLS+=(pi)
}

# ─── qwen (qwen-code) ────────────────────────────────────────────────────────
# Config: ~/.qwen/settings.json
# Uses: model.name, security.auth.selectedType, modelProviders.openai[].baseUrl/envKey
# Also needs env var for the API key

QWEN_SETTINGS_FILE="${HOME}/.qwen/settings.json"
QWEN_SETTINGS_BACKUP=""

_ainish_restore_qwen() {
  if [[ -n "${QWEN_SETTINGS_BACKUP}" && -f "${QWEN_SETTINGS_BACKUP}" ]]; then
    mv "${QWEN_SETTINGS_BACKUP}" "${QWEN_SETTINGS_FILE}"
    QWEN_SETTINGS_BACKUP=""
  fi
}

hot_swap_qwen() {
  local provider="${1:?provider name required}"
  provider_has "$provider" || { echo "error: unknown provider '$provider'" >&2; return 1; }

  local base_url api_key model env_key
  base_url="$(provider_read "$provider" "baseUrl")"
  api_key="$(provider_read "$provider" "apiKey")"
  model="$(provider_read "$provider" "defaultModel")"
  env_key="$(provider_read "$provider" "envKey")"

  # Back up original
  if [[ -z "${QWEN_SETTINGS_BACKUP}" ]]; then
    QWEN_SETTINGS_BACKUP="${QWEN_SETTINGS_FILE}.ainish-backup"
    cp "${QWEN_SETTINGS_FILE}" "${QWEN_SETTINGS_BACKUP}"
  fi

  # Generate a deterministic env key name from the base URL
  local safe_url env_var_name
  safe_url="$(echo "$base_url" | tr '/:.' '_' | tr '[:lower:]' '[:upper:]')"
  env_var_name="QWEN_CUSTOM_API_KEY_OPENAI_${safe_url}"

  # Rewrite settings.json with provider config
  python3 -c "
import sys, json
with open('${QWEN_SETTINGS_FILE}') as f:
    data = json.load(f)
data['model'] = {'name': '${model}'}
data['security'] = {'auth': {'selectedType': 'openai'}}
# Set the API key in the env section
data.setdefault('env', {})
data['env']['${env_var_name}'] = '${api_key}'
# Add/update the model provider entry
providers = data.get('modelProviders', {}).get('openai', [])
# Remove any existing entry with the same model id
providers = [p for p in providers if p.get('id') != '${model}']
providers.insert(0, {
    'id': '${model}',
    'name': '${model}',
    'baseUrl': '${base_url}',
    'envKey': '${env_var_name}',
    'generationConfig': {
        'extra_body': {'enable_thinking': True},
        'modalities': {'image': False, 'video': False, 'audio': False, 'pdf': False},
        'contextWindowSize': 1000000
    }
})
data.setdefault('modelProviders', {})
data['modelProviders']['openai'] = providers
with open('${QWEN_SETTINGS_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
"

  # Also export the env var for the current process
  export "${env_var_name}=${api_key}"

  _ainish_ensure_trap
  _AINISH_SWAPPED_TOOLS+=(qwen)
}

# ─── codex (openai-codex) ────────────────────────────────────────────────────
# Config: ~/.codex/config.toml + per-profile ~/.codex/<name>.config.toml
# Uses: model, model_providers.<name>.base_url/env_key/wire_api

CODEX_CONFIG_FILE="${HOME}/.codex/config.toml"
CODEX_CONFIG_BACKUP=""

_ainish_restore_codex() {
  if [[ -n "${CODEX_CONFIG_BACKUP}" && -f "${CODEX_CONFIG_BACKUP}" ]]; then
    mv "${CODEX_CONFIG_BACKUP}" "${CODEX_CONFIG_FILE}"
    CODEX_CONFIG_BACKUP=""
  fi
}

hot_swap_codex() {
  local provider="${1:?provider name required}"
  provider_has "$provider" || { echo "error: unknown provider '$provider'" >&2; return 1; }
  provider_supports "$provider" "codex" || {
    echo "error: ${provider} does not support codex (missing /responses endpoint)" >&2
    return 1
  }

  local base_url api_key model env_key
  base_url="$(provider_read "$provider" "baseUrl")"
  api_key="$(provider_read "$provider" "apiKey")"
  model="$(provider_read "$provider" "defaultModel")"
  env_key="$(provider_read "$provider" "envKey")"

  # Back up original
  if [[ -z "${CODEX_CONFIG_BACKUP}" ]]; then
    CODEX_CONFIG_BACKUP="${CODEX_CONFIG_FILE}.ainish-backup"
    cp "${CODEX_CONFIG_FILE}" "${CODEX_CONFIG_BACKUP}"
  fi

  # Rewrite config.toml — update model and add model_provider
  python3 -c "
import sys
# Read the existing TOML file
with open('${CODEX_CONFIG_FILE}') as f:
    content = f.read()

# Update the model line
lines = []
in_provider = False
provider_name = '${provider}'
for line in content.split('\n'):
    # Skip old model_provider section for this provider if it exists
    if line.strip().startswith('[model_providers.') and provider_name in line:
        in_provider = True
        continue
    if in_provider and (line.strip() == '' or line.strip().startswith('[')):
        in_provider = False
    if in_provider:
        continue
    # Replace model = line
    if line.strip().startswith('model ='):
        lines.append('model = \"${model}\"')
    else:
        lines.append(line)

# Append the new model_provider section
lines.append('')
lines.append('[model_providers.${provider}]')
lines.append('name = \"${provider}\"')
lines.append('base_url = \"${base_url}\"')
lines.append('env_key = \"${env_key}\"')
lines.append('wire_api = \"responses\"')

with open('${CODEX_CONFIG_FILE}', 'w') as f:
    f.write('\n'.join(lines))
"

  # Export the API key env var
  export "${env_key}=${api_key}"

  _ainish_ensure_trap
  _AINISH_SWAPPED_TOOLS+=(codex)
}
