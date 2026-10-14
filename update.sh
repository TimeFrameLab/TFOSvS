#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -gt 1 ]]; then
  echo "Usage: ./update.sh [UPDATE/<AKA>-<AKA>-...]" >&2
  exit 2
fi

COMMAND="${1:-UPDATE}"
AKA_PATTERN='^UPDATE/[A-Za-z0-9][A-Za-z0-9._&-]*(-[A-Za-z0-9][A-Za-z0-9._&-]*)*$'
if [[ "$COMMAND" != "UPDATE" && ! "$COMMAND" =~ $AKA_PATTERN ]]; then
  echo "รูปแบบคำสั่งไม่ถูกต้อง" >&2
  echo "Usage: ./update.sh [UPDATE/<AKA>-<AKA>-...]" >&2
  exit 2
fi

exec "$SCRIPT_DIR/tfos.sh" "$COMMAND"
