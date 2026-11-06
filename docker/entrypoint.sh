#!/usr/bin/env bash
set -euo pipefail

for environment in \
  "${AGENTENV_STATE_DIR:-$HOME/.local/state/agentenv}/env.sh" \
  "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/env.sh" \
  "${CODEX_HOME:-$HOME/.codex}/env.sh" \
  "${OPENCODE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}/env.sh"; do
  if [[ ! -r "$environment" ]]; then
    echo "agentenv: missing environment: $environment; provision this configuration before launching." >&2
    exit 1
  fi
  # shellcheck source=/dev/null
  . "$environment"
done

bash "$(dirname "${BASH_SOURCE[0]}")/link-skills.sh"

if [[ $# -eq 0 ]]; then set -- bash; fi
exec "$@"
