#!/usr/bin/env bash
set -euo pipefail
command -v node >/dev/null || { echo 'doctor requires Node.js 22+; run tools/install.sh first.' >&2; exit 1; }
exec node "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/doctor.mjs" "$@"
