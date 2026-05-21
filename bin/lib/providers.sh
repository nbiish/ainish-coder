#!/usr/bin/env bash
# Shared provider config reader for ainish-coder wrappers
# Source this file, then call: provider_read <provider_name> <field>
# Fields: baseUrl, apiKey, defaultModel, envKey, wireApi
set -euo pipefail

PROVIDERS_FILE="${AINISH_PROVIDERS:-$HOME/.config/ainish-coder/providers.json}"

# Usage: provider_read <provider> <field>
# Outputs the value to stdout
provider_read() {
  local provider="${1:?provider name required}"
  local field="${2:?field required (baseUrl|apiKey|defaultModel|envKey|wireApi)}"
  python3 -c "
import sys, json
with open('${PROVIDERS_FILE}') as f:
    data = json.load(f)
p = data.get('${provider}', {})
print(p.get('${field}', ''))
"
}

# Usage: provider_list
# Outputs one provider name per line
provider_list() {
  python3 -c "
import json
with open('${PROVIDERS_FILE}') as f:
    for k in json.load(f):
        print(k)
"
}

# Usage: provider_has <provider>
# Returns 0 if provider exists in config, 1 otherwise
provider_has() {
  local provider="${1:-}"
  [[ -n "$provider" ]] || return 1
  [[ "$(provider_read "$provider" "baseUrl")" != "" ]]
}

# Usage: provider_supports <provider> <tool>
# Returns 0 if the provider supports the given tool, 1 otherwise
provider_supports() {
  local provider="${1:-}"
  local tool="${2:-}"
  local supported
  supported="$(python3 -c "
import json
with open('${PROVIDERS_FILE}') as f:
    data = json.load(f)
print(str(data.get('${provider}', {}).get('tools', {}).get('${tool}', False)).lower())
")"
  [[ "$supported" == "true" ]]
}
