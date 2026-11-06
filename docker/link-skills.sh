#!/usr/bin/env bash
# Expose shared skills from ~/.agents/skills to Claude Code at launch.
# Codex and OpenCode read ~/.agents/skills natively; Claude only reads its own
# skills directory, and documents per-skill symlinks as the supported way in.
# Offline and idempotent: safe to run on every container start.
set -euo pipefail

shared="$HOME/.agents/skills"
target="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"

# No shared skills mounted or baked in: nothing to link.
[[ -d "$shared" ]] || exit 0
mkdir -p "$target"

# Drop links we created earlier whose shared skill has since been removed.
for link in "$target"/*; do
  if [[ -L "$link" && ! -e "$link" && "$(readlink "$link")" == "$shared"/* ]]; then
    rm -- "$link"
  fi
done

for skill in "$shared"/*/; do
  [[ -f "$skill/SKILL.md" ]] || continue
  name="$(basename "$skill")"
  if [[ -e "$target/$name" && ! -L "$target/$name" ]]; then
    echo "agentenv: not linking shared skill '$name': $target/$name already exists." >&2
    continue
  fi
  ln -sfn "${skill%/}" "$target/$name"
done
