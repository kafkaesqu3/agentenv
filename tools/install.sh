#!/usr/bin/env bash
set -euo pipefail
dry=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=true ;;
    --help|-h) echo 'Usage: tools/install.sh [--dry-run] (Homebrew on macOS; apt on Debian/Ubuntu)'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
run() { if $dry; then printf '%q ' "$@"; printf '\n'; else "$@"; fi; }
case "$(uname -s)" in
  Darwin)
    command -v brew >/dev/null || { echo 'Install Homebrew first: https://brew.sh' >&2; exit 1; }
    export HOMEBREW_NO_ANALYTICS=1
    run brew install git curl ca-certificates ripgrep fd jq node@24 python uv bash gnu-tar gzip unzip
    if ! $dry; then
      export PATH="$(brew --prefix node@24)/bin:$(brew --prefix)/bin:$PATH"
      export AGENTENV_TOOL_PATH="$(brew --prefix)/bin:$HOME/.local/bin"
    fi
    ;;
  Linux)
    command -v apt-get >/dev/null || { echo 'Supported Linux baseline: Debian/Ubuntu with apt-get.' >&2; exit 1; }
    elevate=()
    if [[ $(id -u) -ne 0 ]]; then
      command -v sudo >/dev/null || { echo 'Run as root or install sudo.' >&2; exit 1; }
      elevate=(sudo)
    fi
    run ${elevate[@]+"${elevate[@]}"} apt-get update
    run ${elevate[@]+"${elevate[@]}"} apt-get install -y git curl ca-certificates ripgrep fd-find jq nodejs npm python3 python3-venv bash tar gzip unzip
    if ! $dry; then
      # uv's official installer does not require pip or modify system Python.
      scratch=$(mktemp -d)
      trap 'rm -f "$scratch/uv.sh"; rmdir "$scratch"' EXIT
      curl --fail --silent --show-error --location https://astral.sh/uv/install.sh -o "$scratch/uv.sh"
      UV_NO_MODIFY_PATH=1 sh "$scratch/uv.sh"
      export PATH="$HOME/.local/bin:$PATH"
      export AGENTENV_TOOL_PATH="$HOME/.local/bin"
    else
      echo 'Download and run https://astral.sh/uv/install.sh (UV_NO_MODIFY_PATH=1)'
    fi
    ;;
  *) echo 'Unsupported OS; use tools/install.ps1 on Windows.' >&2; exit 1 ;;
esac
if ! $dry; then
  node -e 'if(Number(process.versions.node.split(".")[0])<22){console.error("Node.js 22+ required. Install a supported Node LTS release, then rerun; system repositories were not changed.");process.exit(1)}'
  node "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/tools-env.mjs"
  echo 'Shared tools installed. Debian names fd as fdfind. Open a new shell after installation.'
fi
