#!/usr/bin/env bash
# Shared mechanics only; agent-specific assets live beside their installers.
set -euo pipefail
agentenv_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

install_agent() {
  local agent=$1 config_only=false arg package prefix binary scratch
  shift
  for arg in "$@"; do
    case "$arg" in
      --config-only) config_only=true ;;
      -h|--help) echo "Usage: $agent/install.sh [--config-only]"; return 0 ;;
      *) echo "Unknown option: $arg" >&2; return 2 ;;
    esac
  done
  command -v node >/dev/null || { echo 'Node.js 22+ is required.' >&2; return 1; }
  node -e 'if (Number(process.versions.node.split(".")[0]) < 22) { console.error("Node.js 22+ is required"); process.exit(1); }'
  prefix=''
  if [[ "$config_only" == false ]]; then
    case "$agent" in
      claude)
        command -v curl >/dev/null || { echo 'curl is required.' >&2; return 1; }
        scratch=$(mktemp -d)
        # Download fully before execution; propagate download and vendor failures.
        if ! curl --fail --silent --show-error --location https://claude.ai/install.sh -o "$scratch/install.sh"; then
          rm -f "$scratch/install.sh"; rmdir "$scratch"; return 1
        fi
        if ! DISABLE_TELEMETRY=1 DISABLE_ERROR_REPORTING=1 bash "$scratch/install.sh" latest; then
          rm -f "$scratch/install.sh"; rmdir "$scratch"; return 1
        fi
        rm -f "$scratch/install.sh"; rmdir "$scratch"
        prefix="$HOME/.local/bin"
        binary="$prefix/claude"
        ;;
      codex|opencode)
        command -v npm >/dev/null || { echo 'npm is required.' >&2; return 1; }
        if [[ "$agent" == codex ]]; then package='@openai/codex@latest'; else package='@opencode/cli@latest'; fi
        # Keep native installs writable without sudo or changing npm configuration.
        npm install --global --prefix "$HOME/.local" "$package"
        prefix="$HOME/.local/bin"
        binary="$prefix/$agent"
        ;;
    esac
    [[ -x "$binary" ]] || { echo "Installed binary not found: $binary" >&2; return 1; }
    "$binary" --version
  fi
  node "$agentenv_root/lib/configure.mjs" "$agent" --bin "$prefix"
  echo "$agent baseline installed. Open a new shell to load PATH and environment changes."
}
