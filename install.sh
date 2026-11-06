#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
agents=()
options=()
skip_tools=false
tools_only=false
config_only=false
for arg in "$@"; do
  case "$arg" in
    --claude) agents+=(claude) ;;
    --codex) agents+=(codex) ;;
    --opencode) agents+=(opencode) ;;
    --all) agents+=(claude codex opencode) ;;
    --config-only) options+=(--config-only); config_only=true ;;
    --skip-tools) skip_tools=true ;;
    --tools-only) tools_only=true ;;
    -h|--help)
      echo 'Usage: ./install.sh [--all | --claude --codex --opencode] [--config-only | --skip-tools | --tools-only]'
      echo 'Default: install/update all three agents to latest, then apply baseline configs.'
      exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
if $tools_only && { $skip_tools || $config_only || [[ ${#agents[@]} -gt 0 ]]; }; then
  echo '--tools-only cannot be combined with agent selection, --skip-tools or --config-only.' >&2; exit 2
fi
if ! $skip_tools && ! $config_only; then
  # Source so newly installed runtime locations are available to agent installers.
  install_tools() { . "$root/tools/install.sh"; }
  install_tools
fi
if $tools_only; then node "$root/lib/doctor.mjs" --agents none --manifest auto; exit; fi
if [[ ${#agents[@]} -eq 0 ]]; then agents=(claude codex opencode); fi
seen=' '
for agent in "${agents[@]}"; do
  [[ "$seen" == *" $agent "* ]] && continue
  seen+="$agent "
  bash "$root/$agent/install.sh" ${options[@]+"${options[@]}"}
  if ! $config_only; then
    if [[ "$agent" == claude ]]; then export PATH="$HOME/.local/bin:$PATH"
    else export PATH="$(npm prefix --global)/bin:$PATH"; fi
  fi
done
if ! $config_only; then
  selected=$(IFS=,; echo "${agents[*]}")
  node "$root/lib/doctor.mjs" --agents "$selected" --manifest auto
fi
