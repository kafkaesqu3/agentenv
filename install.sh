#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
agents=()
options=()
for arg in "$@"; do
  case "$arg" in
    --claude) agents+=(claude) ;;
    --codex) agents+=(codex) ;;
    --opencode) agents+=(opencode) ;;
    --all) agents+=(claude codex opencode) ;;
    --config-only) options+=(--config-only) ;;
    -h|--help)
      echo 'Usage: ./install.sh [--all | --claude --codex --opencode] [--config-only]'
      echo 'Default: install/update all three agents to latest, then apply baseline configs.'
      exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
if [[ ${#agents[@]} -eq 0 ]]; then agents=(claude codex opencode); fi
seen=' '
for agent in "${agents[@]}"; do
  [[ "$seen" == *" $agent "* ]] && continue
  seen+="$agent "
  bash "$root/$agent/install.sh" ${options[@]+"${options[@]}"}
done
