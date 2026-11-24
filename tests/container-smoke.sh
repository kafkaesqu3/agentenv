#!/usr/bin/env bash
set -euo pipefail
image=${1:-agentenv-base}
docker run --rm "$image" bash -ec '
  test "$(id -un)" = agent
  test "$(id -u)" = 1000
  test "$(id -g)" = 1000
  test "$HOME" = /home/agent
  test "$PWD" = /workspace
  touch "$HOME/write-test" /workspace/write-test
  test "$(sudo -n id -u)" = 0
  test ! -d "$HOME/.codex/tmp"
  for file in "$HOME/.claude/AGENTS.md" "$HOME/.codex/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"; do
    cmp /opt/agentenv/instructions/AGENTS.md "$file"
  done
  test "$(cat "$HOME/.claude/CLAUDE.md")" = "@AGENTS.md"
  claude --version
  codex --version
  claude-yolo --help >/dev/null
  codex-yolo --help >/dev/null
  opencode --version
  bash /opt/agentenv/doctor.sh
  test -n "$(ls "$HOME/.local/state/agentenv/manifests/")"
  grep -Fq "Docker Hardened Images (Debian)" /etc/os-release
'
docker run --rm --user root "$image" bash -ec 'test "$(id -u)" = 0; codex --version'
docker run --rm "$image" bash -ec 'test "$1" = "a b"; test "$2" = ""' -- 'a b' ''
status=0
docker run --rm "$image" bash -c 'exit 37' || status=$?
test "$status" = 37
printf '%s\n' "test -n \"\$BASH_VERSION\"" | docker run --rm -i "$image"
scratch=$(mktemp -d "${PWD}/.test-mount-XXXXXX")
trap 'rmdir "$scratch"' EXIT
before=$(ls -nd "$scratch")
docker run --rm -v "$scratch:/workspace" "$image" bash -ec 'test -d /workspace'
test "$(ls -nd "$scratch")" = "$before"
echo 'Container smoke checks passed.'
